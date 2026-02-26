extends Node2D
## Main game map: renders hex grid, handles input routing, manages entity containers.

var hex_grid: HexGrid
var tile_nodes: Dictionary = {}  # Vector2i -> HexTile node
var hex_tile_scene: PackedScene

var player_spawn: Vector2i
var ai_spawn: Vector2i

var hovered_hex: Vector2i = Vector2i(-999, -999)
var selected_unit: Node2D = null
var selected_building: Node2D = null
var reachable_hexes: Dictionary = {}
var current_path: Array[Vector2i] = []

# Interaction mode
enum Mode { NORMAL, MOVE_UNIT, PLACE_BUILDING, SET_RALLY_POINT, SET_ROUTE_DEST }
var mode: int = Mode.NORMAL
var pending_building_id: String = ""

@onready var hex_grid_container: Node2D = $HexGrid
@onready var buildings_container: Node2D = $Buildings
@onready var units_container: Node2D = $Units
@onready var route_overlay: Node2D = $RouteOverlay
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	hex_tile_scene = load("res://scenes/hex_tile.tscn")
	EventBus.unit_destroyed.connect(_on_unit_destroyed)
	EventBus.building_destroyed.connect(_on_building_destroyed)

func initialize_map(width: int, height: int) -> void:
	var generator := MapGenerator.new()
	var result: Dictionary = generator.generate(width, height)
	hex_grid = result["grid"]
	player_spawn = result["player_spawn"]
	ai_spawn = result["ai_spawn"]
	_render_tiles()
	# Center camera on player spawn
	camera.position = HexUtils.axial_to_pixel(player_spawn)

func _render_tiles() -> void:
	for hex_pos in hex_grid.tiles:
		var tile_node: Node2D = hex_tile_scene.instantiate()
		hex_grid_container.add_child(tile_node)
		tile_node.setup(hex_pos, hex_grid.get_terrain_id(hex_pos))
		tile_nodes[hex_pos] = tile_node

func get_tile_node(hex_pos: Vector2i) -> Node2D:
	return tile_nodes.get(hex_pos, null)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var world_pos: Vector2 = _screen_to_world(event.position)
		var hex_pos: Vector2i = HexUtils.pixel_to_axial(world_pos)
		if hex_grid and hex_grid.is_valid(hex_pos):
			EventBus.hex_clicked.emit(hex_pos, event.button_index)
			_handle_click(hex_pos, event.button_index)
	elif event is InputEventMouseMotion:
		var world_pos: Vector2 = _screen_to_world(event.position)
		var hex_pos: Vector2i = HexUtils.pixel_to_axial(world_pos)
		if hex_pos != hovered_hex:
			_update_hover(hex_pos)

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return camera.get_screen_transform().affine_inverse() * screen_pos

func _update_hover(new_hex: Vector2i) -> void:
	# Clear old hover
	if tile_nodes.has(hovered_hex):
		tile_nodes[hovered_hex].set_hovered(false)
	hovered_hex = new_hex
	if tile_nodes.has(hovered_hex):
		tile_nodes[hovered_hex].set_hovered(true)
		EventBus.hex_hovered.emit(hovered_hex)
	# Update path preview when in move mode
	if mode == Mode.MOVE_UNIT and selected_unit and hex_grid.is_valid(new_hex):
		_update_path_preview(new_hex)

func _handle_click(hex_pos: Vector2i, button: int) -> void:
	if button == MOUSE_BUTTON_RIGHT:
		_cancel_mode()
		return

	match mode:
		Mode.NORMAL:
			_handle_normal_click(hex_pos)
		Mode.MOVE_UNIT:
			_handle_move_click(hex_pos)
		Mode.PLACE_BUILDING:
			_handle_place_building_click(hex_pos)
		Mode.SET_RALLY_POINT:
			_handle_set_rally_point_click(hex_pos)
		Mode.SET_ROUTE_DEST:
			_handle_set_route_dest_click(hex_pos)

func _handle_normal_click(hex_pos: Vector2i) -> void:
	var unit: Node2D = hex_grid.get_unit_at(hex_pos)
	var building: Node2D = hex_grid.get_building_at(hex_pos)

	if unit and unit.owner_id == Constants.Player.PLAYER:
		select_unit(unit)
	elif building and building.owner_id == Constants.Player.PLAYER:
		select_building(building)
	else:
		deselect_all()

func select_unit(unit: Node2D) -> void:
	deselect_all()
	selected_unit = unit
	mode = Mode.MOVE_UNIT
	EventBus.unit_selected.emit(unit)
	# Show reachable hexes
	_show_reachable(unit)

func select_building(building: Node2D) -> void:
	deselect_all()
	selected_building = building
	EventBus.building_selected.emit(building)

func deselect_all() -> void:
	_clear_overlays()
	if selected_unit:
		selected_unit = null
		EventBus.unit_deselected.emit()
	if selected_building:
		selected_building = null
		EventBus.building_deselected.emit()
	mode = Mode.NORMAL

func _cancel_mode() -> void:
	deselect_all()

func _show_reachable(unit: Node2D) -> void:
	_clear_overlays()
	if not unit.has_method("get_movement_remaining"):
		return
	var blocked: Array[Vector2i] = _get_enemy_unit_hexes(unit.owner_id)
	reachable_hexes = hex_grid.get_reachable(unit.hex_pos, unit.get_movement_remaining(), blocked)
	for hex in reachable_hexes:
		if tile_nodes.has(hex):
			tile_nodes[hex].set_in_range(true)

func _update_path_preview(target: Vector2i) -> void:
	# Clear old path
	for hex in current_path:
		if tile_nodes.has(hex):
			tile_nodes[hex].set_in_path(false)
	current_path = []
	if not selected_unit:
		return
	if not reachable_hexes.has(target):
		return
	var blocked: Array[Vector2i] = _get_enemy_unit_hexes(selected_unit.owner_id)
	current_path = hex_grid.find_path(selected_unit.hex_pos, target, selected_unit.get_movement_remaining(), blocked)
	for hex in current_path:
		if tile_nodes.has(hex):
			tile_nodes[hex].set_in_path(true)

func _handle_move_click(hex_pos: Vector2i) -> void:
	if not selected_unit:
		_cancel_mode()
		return
	# Check if clicking an enemy unit (attack)
	var target_unit: Node2D = hex_grid.get_unit_at(hex_pos)
	if target_unit and target_unit.owner_id != selected_unit.owner_id:
		if HexUtils.hex_distance(selected_unit.hex_pos, hex_pos) <= selected_unit.attack_range:
			EventBus.unit_attacked.emit(selected_unit, target_unit)
			deselect_all()
			return
	# Move
	if reachable_hexes.has(hex_pos) and hex_pos != selected_unit.hex_pos:
		var old_hex: Vector2i = selected_unit.hex_pos
		hex_grid.remove_unit(old_hex)
		selected_unit.move_to_hex(hex_pos)
		hex_grid.place_unit(hex_pos, selected_unit)
		EventBus.unit_moved.emit(selected_unit, old_hex, hex_pos)
		deselect_all()
	else:
		# Clicked invalid tile — try normal click
		_cancel_mode()
		_handle_normal_click(hex_pos)

func _handle_place_building_click(hex_pos: Vector2i) -> void:
	if hex_grid.is_buildable(hex_pos):
		EventBus.building_placed.emit(null, hex_pos)  # Systems will handle actual placement
		_cancel_mode()

func _handle_set_rally_point_click(hex_pos: Vector2i) -> void:
	if selected_building and hex_grid.is_valid(hex_pos):
		EventBus.rally_point_set.emit(selected_building, hex_pos)
		_cancel_mode()

func _handle_set_route_dest_click(hex_pos: Vector2i) -> void:
	if selected_building and hex_grid.is_valid(hex_pos):
		EventBus.route_created.emit(-1, selected_building, hex_pos)
		_cancel_mode()

func enter_build_mode(building_id: String) -> void:
	deselect_all()
	mode = Mode.PLACE_BUILDING
	pending_building_id = building_id

func enter_rally_point_mode() -> void:
	if selected_building:
		mode = Mode.SET_RALLY_POINT

func enter_route_mode() -> void:
	if selected_building:
		mode = Mode.SET_ROUTE_DEST

func _clear_overlays() -> void:
	for hex in reachable_hexes:
		if tile_nodes.has(hex):
			tile_nodes[hex].set_in_range(false)
	for hex in current_path:
		if tile_nodes.has(hex):
			tile_nodes[hex].set_in_path(false)
	reachable_hexes = {}
	current_path = []

func _get_enemy_unit_hexes(player: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for hex in hex_grid.tiles:
		var unit: Node2D = hex_grid.get_unit_at(hex)
		if unit and unit.owner_id != player:
			result.append(hex)
	return result

func _on_unit_destroyed(unit: Node2D) -> void:
	if unit == selected_unit:
		deselect_all()
	hex_grid.remove_unit(unit.hex_pos)
	unit.queue_free()

func _on_building_destroyed(building: Node2D) -> void:
	if building == selected_building:
		deselect_all()
	hex_grid.remove_building(building.hex_pos)
	building.queue_free()
