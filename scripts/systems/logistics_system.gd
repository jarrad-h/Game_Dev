extends Node
## Supreme Commander-style automated logistics system.
## Manages transport routes from factories/rally points to front-line destinations.
##
## How it works:
## 1. Player sets a rally point on a factory (where produced units gather).
## 2. Player creates a transport route: (source building → destination hex).
## 3. Each turn during Logistics phase, units at rally points that match a route
##    are automatically moved along the path toward the destination.
## 4. Units move their full movement range each logistics turn along the route path.
## 5. Supply depots along the route increase capacity (units processed per turn).

var game_map: Node2D = null
var routes: Array = []  # Array of route dictionaries
var next_route_id: int = 1

func set_game_map(map: Node2D) -> void:
	game_map = map

func _ready() -> void:
	EventBus.route_created.connect(_on_route_created)
	EventBus.route_removed.connect(_on_route_removed)
	EventBus.rally_point_set.connect(_on_rally_point_set)
	EventBus.building_destroyed.connect(_on_building_destroyed)

## Create a transport route from a source building to a destination hex.
func create_route(source_building: Node2D, dest_hex: Vector2i) -> int:
	var route_id: int = next_route_id
	next_route_id += 1

	var route: Dictionary = {
		"id": route_id,
		"source_building": source_building,
		"destination": dest_hex,
		"owner": source_building.owner_id,
		"active": true,
		"path": [],  # Computed path from rally point to destination
	}

	# Compute the initial path
	_update_route_path(route)
	routes.append(route)
	return route_id

## Remove a transport route by ID.
func remove_route(route_id: int) -> void:
	for i in range(routes.size() - 1, -1, -1):
		if routes[i]["id"] == route_id:
			routes.remove_at(i)
			break

## Get all routes for a player.
func get_routes_for_player(player: int) -> Array:
	var result: Array = []
	for route in routes:
		if route["owner"] == player:
			result.append(route)
	return result

## Get all routes sourced from a specific building.
func get_routes_for_building(building: Node2D) -> Array:
	var result: Array = []
	for route in routes:
		if route["source_building"] == building:
			result.append(route)
	return result

## Called during Logistics phase — move units along their routes.
func process_turn() -> void:
	if not game_map or not game_map.hex_grid:
		return

	for route in routes:
		if not route["active"]:
			continue
		if not is_instance_valid(route["source_building"]):
			route["active"] = false
			continue
		_process_route(route)

func _process_route(route: Dictionary) -> void:
	var source: Node2D = route["source_building"]
	var dest: Vector2i = route["destination"]
	var capacity: int = _get_route_capacity(route)

	# Find units at or near the rally point that belong to this building's owner
	# and are marked as on-route or are newly produced at the rally point
	var rally: Vector2i = source.get_rally_point()
	var units_to_move: Array = _find_units_for_route(rally, dest, source.owner_id, capacity)

	for unit in units_to_move:
		_move_unit_along_route(unit, dest)

func _find_units_for_route(rally: Vector2i, dest: Vector2i, owner: int, capacity: int) -> Array:
	var units: Array = []
	if not game_map or not game_map.hex_grid:
		return units

	var units_container: Node2D = game_map.get_node_or_null("Units")
	if not units_container:
		return units

	# Look for units near the rally point (within 2 hexes) that are idle
	var search_area: Array[Vector2i] = HexUtils.hex_range(rally, 2)
	for hex in search_area:
		var unit: Node2D = game_map.hex_grid.get_unit_at(hex)
		if unit and unit.owner_id == owner and unit.movement_remaining > 0:
			# Don't move units that are already at or near the destination
			if HexUtils.hex_distance(unit.hex_pos, dest) <= 1:
				continue
			units.append(unit)
			if units.size() >= capacity:
				break

	return units

func _move_unit_along_route(unit: Node2D, dest: Vector2i) -> void:
	if not game_map or not game_map.hex_grid:
		return

	# Find path from unit's current position to destination
	var blocked: Array[Vector2i] = []
	var path: Array[Vector2i] = game_map.hex_grid.find_path(unit.hex_pos, dest, -1, blocked)
	if path.size() <= 1:
		return

	# Move the unit along the path up to its movement range
	var steps: int = 0
	var move_budget: int = unit.movement_remaining
	for i in range(1, path.size()):
		var next_hex: Vector2i = path[i]
		var cost: int = game_map.hex_grid.get_movement_cost(next_hex)
		if cost > move_budget:
			break
		# Check if hex is occupied
		if game_map.hex_grid.get_unit_at(next_hex) != null:
			break
		move_budget -= cost
		steps = i

	if steps > 0:
		var target_hex: Vector2i = path[steps]
		var old_hex: Vector2i = unit.hex_pos
		game_map.hex_grid.remove_unit(old_hex)
		unit.move_to_hex(target_hex)
		game_map.hex_grid.place_unit(target_hex, unit)
		EventBus.unit_moved.emit(unit, old_hex, target_hex)

## Calculate route capacity (base + depot bonuses).
func _get_route_capacity(route: Dictionary) -> int:
	var capacity: int = Constants.DEFAULT_ROUTE_CAPACITY

	# Tech bonus
	if GameState.has_tech(route["owner"], "advanced_logistics"):
		var tech_def: Dictionary = GameData.get_tech_def("advanced_logistics")
		capacity = tech_def.get("effects", {}).get("transport_capacity", capacity)

	# Supply depot bonus: check if any depots are along the route path
	if game_map and game_map.hex_grid and route["path"].size() > 0:
		for hex in route["path"]:
			var building: Node2D = game_map.hex_grid.get_building_at(hex)
			if building and building.building_id == "supply_depot" and building.owner_id == route["owner"]:
				capacity += Constants.DEPOT_CAPACITY_BONUS

	return capacity

func _update_route_path(route: Dictionary) -> void:
	if not game_map or not game_map.hex_grid:
		return
	var source: Node2D = route["source_building"]
	var rally: Vector2i = source.get_rally_point()
	var dest: Vector2i = route["destination"]
	route["path"] = game_map.hex_grid.find_path(rally, dest)

func _on_route_created(_route_id: int, source: Node2D, dest_hex: Vector2i) -> void:
	if source:
		create_route(source, dest_hex)

func _on_route_removed(route_id: int) -> void:
	remove_route(route_id)

func _on_rally_point_set(building: Node2D, hex_pos: Vector2i) -> void:
	building.set_rally(hex_pos)
	# Update routes for this building
	for route in routes:
		if route["source_building"] == building:
			_update_route_path(route)

func _on_building_destroyed(building: Node2D) -> void:
	# Deactivate all routes from this building
	for route in routes:
		if route["source_building"] == building:
			route["active"] = false
