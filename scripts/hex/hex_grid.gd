class_name HexGrid
extends RefCounted
## Core hex grid data structure with pathfinding.
## Stores tile data and provides A* pathfinding over the hex map.

var width: int
var height: int
var tiles: Dictionary = {}  # Vector2i -> tile data dict

func _init(w: int = 0, h: int = 0) -> void:
	width = w
	height = h

## Check if a hex coordinate is within map bounds.
func is_valid(hex: Vector2i) -> bool:
	return tiles.has(hex)

## Get tile data at a hex coordinate.
func get_tile(hex: Vector2i) -> Dictionary:
	return tiles.get(hex, {})

## Set tile data at a hex coordinate.
func set_tile(hex: Vector2i, data: Dictionary) -> void:
	tiles[hex] = data

## Get the terrain ID at a hex.
func get_terrain_id(hex: Vector2i) -> String:
	var tile: Dictionary = get_tile(hex)
	return tile.get("terrain", "plains")

## Get movement cost for a hex, factoring in terrain.
func get_movement_cost(hex: Vector2i) -> int:
	var terrain_id: String = get_terrain_id(hex)
	var terrain_def: Dictionary = GameData.get_terrain_def(terrain_id)
	return terrain_def.get("movement_cost", 1)

## Check if a hex is passable (movement_cost > 0).
func is_passable(hex: Vector2i) -> bool:
	return is_valid(hex) and get_movement_cost(hex) > 0

## Check if a hex can have a building placed on it.
func is_buildable(hex: Vector2i) -> bool:
	if not is_valid(hex):
		return false
	var terrain_id: String = get_terrain_id(hex)
	var terrain_def: Dictionary = GameData.get_terrain_def(terrain_id)
	if not terrain_def.get("buildable", false):
		return false
	var tile: Dictionary = get_tile(hex)
	return not tile.has("building")

## Get the unit on a hex, or null.
func get_unit_at(hex: Vector2i) -> Node2D:
	var tile: Dictionary = get_tile(hex)
	return tile.get("unit", null)

## Get the building on a hex, or null.
func get_building_at(hex: Vector2i) -> Node2D:
	var tile: Dictionary = get_tile(hex)
	return tile.get("building", null)

## Place a unit reference on a hex.
func place_unit(hex: Vector2i, unit: Node2D) -> void:
	if tiles.has(hex):
		tiles[hex]["unit"] = unit

## Remove a unit reference from a hex.
func remove_unit(hex: Vector2i) -> void:
	if tiles.has(hex) and tiles[hex].has("unit"):
		tiles[hex].erase("unit")

## Place a building reference on a hex.
func place_building(hex: Vector2i, building: Node2D) -> void:
	if tiles.has(hex):
		tiles[hex]["building"] = building

## Remove a building reference from a hex.
func remove_building(hex: Vector2i) -> void:
	if tiles.has(hex) and tiles[hex].has("building"):
		tiles[hex].erase("building")

## Set ownership of a hex.
func set_owner(hex: Vector2i, player: int) -> void:
	if tiles.has(hex):
		tiles[hex]["owner"] = player

func get_owner(hex: Vector2i) -> int:
	var tile: Dictionary = get_tile(hex)
	return tile.get("owner", -1)

## A* pathfinding from start to end hex.
## Returns array of Vector2i (path including start and end), or empty if no path.
## movement_budget: max total movement cost allowed (-1 for unlimited).
## blocked_hexes: set of hexes that cannot be traversed (e.g., occupied by enemies).
func find_path(start: Vector2i, end: Vector2i, movement_budget: int = -1, blocked_hexes: Array[Vector2i] = []) -> Array[Vector2i]:
	if not is_valid(start) or not is_valid(end):
		return []
	if not is_passable(end):
		return []

	var blocked_set: Dictionary = {}
	for h in blocked_hexes:
		blocked_set[h] = true

	# A* implementation
	var open_set: Array = [start]
	var came_from: Dictionary = {}
	var g_score: Dictionary = { start: 0 }
	var f_score: Dictionary = { start: HexUtils.hex_distance(start, end) }

	while open_set.size() > 0:
		# Find node in open_set with lowest f_score
		var current: Vector2i = open_set[0]
		var current_f: float = f_score.get(current, INF)
		for node in open_set:
			var nf: float = f_score.get(node, INF)
			if nf < current_f:
				current = node
				current_f = nf

		if current == end:
			return _reconstruct_path(came_from, current)

		open_set.erase(current)

		for neighbor in HexUtils.get_neighbors(current):
			if not is_passable(neighbor):
				continue
			if blocked_set.has(neighbor) and neighbor != end:
				continue

			var move_cost: int = get_movement_cost(neighbor)
			var tentative_g: int = g_score.get(current, 999999) + move_cost

			if movement_budget >= 0 and tentative_g > movement_budget:
				continue

			if tentative_g < g_score.get(neighbor, 999999):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + HexUtils.hex_distance(neighbor, end)
				if neighbor not in open_set:
					open_set.append(neighbor)

	return []  # No path found

func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path

## Get all hexes reachable from start within a movement budget.
## Returns dict of { Vector2i: cost_to_reach }.
func get_reachable(start: Vector2i, movement_budget: int, blocked_hexes: Array[Vector2i] = []) -> Dictionary:
	var blocked_set: Dictionary = {}
	for h in blocked_hexes:
		blocked_set[h] = true

	var reachable: Dictionary = { start: 0 }
	var frontier: Array = [start]

	while frontier.size() > 0:
		var current: Vector2i = frontier.pop_front()
		var current_cost: int = reachable[current]

		for neighbor in HexUtils.get_neighbors(current):
			if not is_passable(neighbor):
				continue
			if blocked_set.has(neighbor):
				continue
			var move_cost: int = get_movement_cost(neighbor)
			var total_cost: int = current_cost + move_cost
			if total_cost <= movement_budget:
				if not reachable.has(neighbor) or total_cost < reachable[neighbor]:
					reachable[neighbor] = total_cost
					frontier.append(neighbor)

	return reachable

## Get all hexes of a given terrain type.
func get_hexes_by_terrain(terrain_id: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for hex in tiles:
		if get_terrain_id(hex) == terrain_id:
			result.append(hex)
	return result

## Get all hexes owned by a player.
func get_hexes_by_owner(player: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for hex in tiles:
		if get_owner(hex) == player:
			result.append(hex)
	return result
