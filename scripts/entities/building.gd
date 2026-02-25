extends Node2D
## A building on the hex map. Initialized from data definitions.
## Draws itself using _draw() — no external sprites needed.

# Identity
var building_id: String = ""
var building_name: String = ""
var owner_id: int = Constants.Player.PLAYER
var hex_pos: Vector2i = Vector2i.ZERO

# Stats
var max_hp: int = 200
var hp: int = 200
var resource_production: Dictionary = {}
var can_produce_units: bool = false
var production_slots: int = 0
var supply_range: int = 0

# Visual
var building_color: Color = Color.WHITE
var player_colors: Array[Color] = [Color("#3388FF"), Color("#FF4444")]

# Construction state
var state: int = Constants.BuildingState.OPERATIONAL
var build_turns_remaining: int = 0

# Production
var production_queue: Array = []  # Array of { "unit_id": String, "turns_remaining": int }

# Logistics
var rally_point: Vector2i = Vector2i(-999, -999)  # Where produced units go
var has_rally_point: bool = false

func setup(id: String, owner: int, pos: Vector2i) -> void:
	building_id = id
	owner_id = owner
	hex_pos = pos

	var def: Dictionary = GameData.get_building_def(building_id)
	building_name = def.get("name", "Building")
	max_hp = def.get("hp", 200)
	hp = max_hp
	resource_production = def.get("resource_production", {})
	can_produce_units = def.get("can_produce_units", false)
	production_slots = def.get("production_slots", 0)
	supply_range = def.get("supply_range", 0)
	building_color = Color(def.get("color", "#AAAAAA"))

	var build_time: int = def.get("build_time", 0)
	if build_time > 0:
		state = Constants.BuildingState.CONSTRUCTING
		build_turns_remaining = build_time
	else:
		state = Constants.BuildingState.OPERATIONAL

	position = HexUtils.axial_to_pixel(hex_pos)
	queue_redraw()

func is_operational() -> bool:
	return state == Constants.BuildingState.OPERATIONAL

func advance_construction() -> void:
	if state != Constants.BuildingState.CONSTRUCTING:
		return
	build_turns_remaining -= 1
	if build_turns_remaining <= 0:
		state = Constants.BuildingState.OPERATIONAL
		EventBus.building_completed.emit(self)
	queue_redraw()

func queue_production(unit_id: String) -> bool:
	if not can_produce_units or not is_operational():
		return false
	if production_queue.size() >= production_slots:
		return false
	var unit_def: Dictionary = GameData.get_unit_def(unit_id)
	if unit_def.is_empty():
		return false
	production_queue.append({
		"unit_id": unit_id,
		"turns_remaining": unit_def.get("build_time", 1)
	})
	EventBus.production_queued.emit(self, unit_id)
	queue_redraw()
	return true

func advance_production() -> Array:
	## Returns array of completed unit_ids
	var completed: Array = []
	var still_building: Array = []
	for item in production_queue:
		item["turns_remaining"] -= 1
		if item["turns_remaining"] <= 0:
			completed.append(item["unit_id"])
		else:
			still_building.append(item)
	production_queue = still_building
	queue_redraw()
	return completed

func set_rally(pos: Vector2i) -> void:
	rally_point = pos
	has_rally_point = true
	queue_redraw()

func get_rally_point() -> Vector2i:
	if has_rally_point:
		return rally_point
	return hex_pos  # Default to building's own hex

func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	if hp <= 0:
		EventBus.building_destroyed.emit(self)
	queue_redraw()

func _draw() -> void:
	var base_color: Color = player_colors[owner_id] if owner_id < player_colors.size() else Color.WHITE
	var size: float = Constants.HEX_SIZE * 0.5

	# Construction overlay
	if state == Constants.BuildingState.CONSTRUCTING:
		_draw_construction(base_color, size)
	else:
		match building_id:
			"headquarters":
				_draw_hq(base_color, size)
			"factory":
				_draw_factory(base_color, size)
			"extractor":
				_draw_extractor(building_color, size)
			"power_plant":
				_draw_power_plant(building_color, size)
			"supply_depot":
				_draw_depot(building_color, size)
			_:
				_draw_generic(base_color, size)

	# HP bar
	_draw_hp_bar(size)

	# Production indicator
	if production_queue.size() > 0:
		_draw_production_indicator(size)

	# Rally point indicator
	if has_rally_point:
		var rally_pixel: Vector2 = HexUtils.axial_to_pixel(rally_point) - position
		draw_dashed_line(Vector2.ZERO, rally_pixel, Color(0.2, 1.0, 0.2, 0.5), 1.5, 4.0)

func _draw_hq(color: Color, size: float) -> void:
	# Star shape for HQ
	var points := PackedVector2Array()
	for i in range(10):
		var angle: float = TAU * i / 10.0 - PI / 2.0
		var r: float = size if i % 2 == 0 else size * 0.5
		points.append(Vector2(cos(angle) * r, sin(angle) * r))
	draw_colored_polygon(points, color)
	draw_polyline(points, Color(0, 0, 0, 0.6), 1.0)

func _draw_factory(color: Color, size: float) -> void:
	# Building with chimney
	var body := Rect2(Vector2(-size * 0.5, -size * 0.2), Vector2(size, size * 0.6))
	draw_rect(body, color)
	# Chimney
	var chimney := Rect2(Vector2(size * 0.15, -size * 0.55), Vector2(size * 0.2, size * 0.4))
	draw_rect(chimney, color.darkened(0.2))
	# Roof
	var roof := PackedVector2Array([
		Vector2(-size * 0.55, -size * 0.2),
		Vector2(0, -size * 0.45),
		Vector2(size * 0.55, -size * 0.2)
	])
	draw_colored_polygon(roof, color.lightened(0.15))
	draw_rect(body, Color(0, 0, 0, 0.4), false, 1.0)

func _draw_extractor(color: Color, size: float) -> void:
	# Pickaxe / mine symbol
	draw_circle(Vector2.ZERO, size * 0.35, color)
	# X pattern inside
	draw_line(Vector2(-size * 0.2, -size * 0.2), Vector2(size * 0.2, size * 0.2), Color(0, 0, 0, 0.5), 2.0)
	draw_line(Vector2(size * 0.2, -size * 0.2), Vector2(-size * 0.2, size * 0.2), Color(0, 0, 0, 0.5), 2.0)

func _draw_power_plant(color: Color, size: float) -> void:
	# Lightning bolt
	var bolt := PackedVector2Array([
		Vector2(-size * 0.15, -size * 0.5),
		Vector2(size * 0.1, -size * 0.05),
		Vector2(-size * 0.05, -size * 0.05),
		Vector2(size * 0.15, size * 0.5),
		Vector2(-size * 0.1, size * 0.05),
		Vector2(size * 0.05, size * 0.05)
	])
	draw_colored_polygon(bolt, color)
	draw_polyline(bolt, Color(0, 0, 0, 0.5), 1.0)

func _draw_depot(color: Color, size: float) -> void:
	# Box/crate
	var box := Rect2(Vector2(-size * 0.35, -size * 0.35), Vector2(size * 0.7, size * 0.7))
	draw_rect(box, color)
	draw_rect(box, Color(0, 0, 0, 0.4), false, 1.5)
	# Cross lines on box
	draw_line(Vector2(-size * 0.35, 0), Vector2(size * 0.35, 0), Color(0, 0, 0, 0.3), 1.0)
	draw_line(Vector2(0, -size * 0.35), Vector2(0, size * 0.35), Color(0, 0, 0, 0.3), 1.0)

func _draw_generic(color: Color, size: float) -> void:
	var rect := Rect2(Vector2(-size * 0.4, -size * 0.4), Vector2(size * 0.8, size * 0.8))
	draw_rect(rect, color)
	draw_rect(rect, Color(0, 0, 0, 0.4), false, 1.0)

func _draw_construction(color: Color, size: float) -> void:
	# Partially built outline
	draw_rect(Rect2(Vector2(-size * 0.4, -size * 0.4), Vector2(size * 0.8, size * 0.8)), Color(color, 0.3))
	draw_rect(Rect2(Vector2(-size * 0.4, -size * 0.4), Vector2(size * 0.8, size * 0.8)), color, false, 1.5)
	# Progress text
	# (Godot _draw doesn't easily do text, so we draw a progress bar)
	var def: Dictionary = GameData.get_building_def(building_id)
	var total_time: int = def.get("build_time", 1)
	var progress: float = 1.0 - (float(build_turns_remaining) / float(total_time))
	var bar_w: float = size * 0.8
	draw_rect(Rect2(Vector2(-bar_w / 2, size * 0.3), Vector2(bar_w, 4)), Color(0.2, 0.2, 0.2, 0.8))
	draw_rect(Rect2(Vector2(-bar_w / 2, size * 0.3), Vector2(bar_w * progress, 4)), Color.ORANGE)

func _draw_hp_bar(size: float) -> void:
	if hp >= max_hp:
		return
	var bar_width: float = size * 1.0
	var bar_height: float = 3.0
	var bar_y: float = size * 0.6
	var hp_ratio: float = float(hp) / float(max_hp) if max_hp > 0 else 0.0
	draw_rect(Rect2(Vector2(-bar_width / 2, bar_y), Vector2(bar_width, bar_height)), Color(0.2, 0.2, 0.2, 0.8))
	var fill_color: Color = Color.GREEN if hp_ratio > 0.5 else (Color.YELLOW if hp_ratio > 0.25 else Color.RED)
	draw_rect(Rect2(Vector2(-bar_width / 2, bar_y), Vector2(bar_width * hp_ratio, bar_height)), fill_color)

func _draw_production_indicator(size: float) -> void:
	# Small gear icon near top-right
	draw_circle(Vector2(size * 0.45, -size * 0.45), 4.0, Color.ORANGE)
