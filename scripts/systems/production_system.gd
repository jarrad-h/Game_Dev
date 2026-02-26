extends Node
## Manages building construction and unit production queues.

var game_map: Node2D = null

func set_game_map(map: Node2D) -> void:
	game_map = map

func _ready() -> void:
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.production_queued.connect(_on_production_queued)

## Called during Production phase.
func process_turn() -> void:
	if not game_map:
		return
	var buildings_container: Node2D = game_map.get_node_or_null("Buildings")
	if not buildings_container:
		return

	for building in buildings_container.get_children():
		# Advance construction
		if not building.is_operational():
			building.advance_construction()
			continue

		# Advance production queues
		var completed: Array = building.advance_production()
		for unit_id in completed:
			_spawn_produced_unit(building, unit_id)

func _spawn_produced_unit(building: Node2D, unit_id: String) -> void:
	var spawn_hex: Vector2i = building.get_rally_point()
	# Find nearest free hex to the rally point
	spawn_hex = _find_free_hex_near(spawn_hex, building.owner_id)
	if spawn_hex == Vector2i(-999, -999):
		return  # No space to spawn

	var unit: Node2D = UnitFactory.create_unit(unit_id, building.owner_id, spawn_hex)
	var units_container: Node2D = game_map.get_node_or_null("Units")
	if units_container:
		units_container.add_child(unit)
		game_map.hex_grid.place_unit(spawn_hex, unit)
		EventBus.unit_spawned.emit(unit, spawn_hex)
		EventBus.production_completed.emit(building, unit_id)

func _find_free_hex_near(target: Vector2i, _owner: int) -> Vector2i:
	if not game_map or not game_map.hex_grid:
		return Vector2i(-999, -999)
	# Check target first
	if game_map.hex_grid.is_passable(target) and game_map.hex_grid.get_unit_at(target) == null:
		return target
	# Spiral outward
	for radius in range(1, 5):
		var ring: Array[Vector2i] = HexUtils.hex_ring(target, radius)
		for hex in ring:
			if game_map.hex_grid.is_valid(hex) and game_map.hex_grid.is_passable(hex):
				if game_map.hex_grid.get_unit_at(hex) == null:
					return hex
	return Vector2i(-999, -999)

## Request to place a building for a player.
func place_building(building_id: String, player: int, hex_pos: Vector2i) -> bool:
	if not game_map or not game_map.hex_grid:
		return false
	if not game_map.hex_grid.is_buildable(hex_pos):
		return false

	var def: Dictionary = GameData.get_building_def(building_id)
	if def.is_empty():
		return false

	# Check cost
	var cost: Dictionary = def.get("cost", {})
	if not GameState.can_afford(player, cost):
		return false

	# Check tech requirement
	var tech_req = def.get("tech_required")
	if tech_req != null and not GameState.has_tech(player, tech_req):
		return false

	# Spend resources
	GameState.spend_cost(player, cost)

	# Create building
	var building: Node2D = UnitFactory.create_building(building_id, player, hex_pos)
	var buildings_container: Node2D = game_map.get_node_or_null("Buildings")
	if buildings_container:
		buildings_container.add_child(building)
		game_map.hex_grid.place_building(hex_pos, building)
		EventBus.building_placed.emit(building, hex_pos)
	return true

## Request to queue a unit at a building.
func queue_unit(building: Node2D, unit_id: String) -> bool:
	var def: Dictionary = GameData.get_unit_def(unit_id)
	if def.is_empty():
		return false

	# Check tech requirement
	var tech_req = def.get("tech_required")
	if tech_req != null and not GameState.has_tech(building.owner_id, tech_req):
		return false

	# Check cost
	var cost: Dictionary = def.get("cost", {})
	if not GameState.can_afford(building.owner_id, cost):
		return false

	# Try to queue
	if building.queue_production(unit_id):
		GameState.spend_cost(building.owner_id, cost)
		return true
	return false

func _on_building_placed(_building: Node2D, _hex_pos: Vector2i) -> void:
	pass

func _on_production_queued(_building: Node2D, _unit_id: String) -> void:
	pass
