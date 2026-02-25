extends Node2D
## A unit on the hex map. Initialized from data definitions.
## Draws itself using _draw() — no external sprites needed.

# Identity
var unit_id: String = ""
var unit_name: String = ""
var owner_id: int = Constants.Player.PLAYER
var hex_pos: Vector2i = Vector2i.ZERO

# Stats (from data, may be modified by tech/buffs)
var max_hp: int = 100
var hp: int = 100
var attack_power: int = 15
var defense_power: int = 10
var max_movement: int = 2
var movement_remaining: int = 2
var attack_range: int = 1
var abilities: Array = []

# Visual
var unit_color: Color = Color.WHITE
var player_colors: Array[Color] = [Color("#3388FF"), Color("#FF4444")]

# State
var has_attacked: bool = false
var is_fortified: bool = false

# Logistics — if this unit is being transported via a route
var on_route: bool = false
var route_id: int = -1

func setup(id: String, owner: int, pos: Vector2i) -> void:
	unit_id = id
	owner_id = owner
	hex_pos = pos

	var def: Dictionary = GameData.get_unit_def(unit_id)
	unit_name = def.get("name", "Unit")
	max_hp = def.get("hp", 100)
	hp = max_hp
	attack_power = def.get("attack", 10)
	defense_power = def.get("defense", 5)
	max_movement = def.get("movement", 2)
	movement_remaining = max_movement
	attack_range = def.get("range", 1)
	abilities = def.get("abilities", [])
	unit_color = Color(def.get("color", "#FFFFFF"))

	position = HexUtils.axial_to_pixel(hex_pos)
	queue_redraw()

func get_movement_remaining() -> int:
	return movement_remaining

func move_to_hex(new_hex: Vector2i) -> void:
	var cost: int = HexUtils.hex_distance(hex_pos, new_hex)
	movement_remaining = maxi(0, movement_remaining - cost)
	hex_pos = new_hex
	position = HexUtils.axial_to_pixel(hex_pos)
	queue_redraw()

func start_turn() -> void:
	movement_remaining = max_movement
	has_attacked = false

func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	queue_redraw()
	if hp <= 0:
		EventBus.unit_destroyed.emit(self)

func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)
	queue_redraw()

func fortify() -> void:
	is_fortified = true
	movement_remaining = 0
	queue_redraw()

func get_effective_defense() -> int:
	var def: int = defense_power
	if is_fortified:
		def += 3
	# Tech bonus
	if GameState.has_tech(owner_id, "fortification"):
		def += 1
	return def

func _draw() -> void:
	var base_color: Color = player_colors[owner_id] if owner_id < player_colors.size() else Color.WHITE
	var size: float = Constants.HEX_SIZE * 0.4

	# Draw based on unit type
	match unit_id:
		"infantry":
			_draw_infantry(base_color, size)
		"armor":
			_draw_armor(base_color, size)
		"artillery":
			_draw_artillery(base_color, size)
		_:
			_draw_generic(base_color, size)

	# HP bar
	_draw_hp_bar(size)

	# Fortify indicator
	if is_fortified:
		draw_arc(Vector2.ZERO, size + 2, 0, TAU, 16, Color.CYAN, 1.5)

func _draw_infantry(color: Color, size: float) -> void:
	# Simple person shape: circle head + triangle body
	draw_circle(Vector2(0, -size * 0.4), size * 0.25, color)
	var body_points := PackedVector2Array([
		Vector2(-size * 0.35, size * 0.5),
		Vector2(size * 0.35, size * 0.5),
		Vector2(0, -size * 0.1)
	])
	draw_colored_polygon(body_points, color)
	# Dark outline
	draw_circle(Vector2(0, -size * 0.4), size * 0.25 + 1, Color(0, 0, 0, 0.5))

func _draw_armor(color: Color, size: float) -> void:
	# Tank shape: rectangle body + small turret
	var body := Rect2(Vector2(-size * 0.5, -size * 0.2), Vector2(size, size * 0.5))
	draw_rect(body, color)
	draw_rect(body, Color(0, 0, 0, 0.5), false, 1.0)
	# Turret
	var turret := Rect2(Vector2(-size * 0.2, -size * 0.45), Vector2(size * 0.4, size * 0.3))
	draw_rect(turret, color.lightened(0.2))
	# Barrel
	draw_line(Vector2(size * 0.2, -size * 0.3), Vector2(size * 0.6, -size * 0.3), color.darkened(0.2), 2.0)

func _draw_artillery(color: Color, size: float) -> void:
	# Cannon shape: base rectangle + angled barrel
	var base := Rect2(Vector2(-size * 0.4, 0), Vector2(size * 0.8, size * 0.3))
	draw_rect(base, color)
	# Wheels
	draw_circle(Vector2(-size * 0.25, size * 0.35), size * 0.12, color.darkened(0.3))
	draw_circle(Vector2(size * 0.25, size * 0.35), size * 0.12, color.darkened(0.3))
	# Barrel pointing up-right
	draw_line(Vector2(0, 0), Vector2(size * 0.5, -size * 0.6), color.lightened(0.1), 3.0)

func _draw_generic(color: Color, size: float) -> void:
	draw_circle(Vector2.ZERO, size * 0.4, color)
	draw_circle(Vector2.ZERO, size * 0.4 + 1, Color(0, 0, 0, 0.5))

func _draw_hp_bar(size: float) -> void:
	var bar_width: float = size * 1.2
	var bar_height: float = 3.0
	var bar_y: float = size * 0.65
	var hp_ratio: float = float(hp) / float(max_hp) if max_hp > 0 else 0.0
	# Background
	draw_rect(Rect2(Vector2(-bar_width / 2, bar_y), Vector2(bar_width, bar_height)), Color(0.2, 0.2, 0.2, 0.8))
	# Fill
	var fill_color: Color = Color.GREEN if hp_ratio > 0.5 else (Color.YELLOW if hp_ratio > 0.25 else Color.RED)
	draw_rect(Rect2(Vector2(-bar_width / 2, bar_y), Vector2(bar_width * hp_ratio, bar_height)), fill_color)
