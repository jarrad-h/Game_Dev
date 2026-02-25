extends Node
## AI military decision-making: moves units, attacks, defends.

func make_decisions(game_map: Node2D, systems_node: Node, ai_player: int) -> void:
	if not game_map or not game_map.hex_grid:
		return

	var units_container: Node2D = game_map.get_node_or_null("Units")
	if not units_container:
		return

	var combat_sys: Node = systems_node.get_node_or_null("CombatSystem")
	var player_hq_pos: Vector2i = _find_player_hq(game_map)
	var ai_units: Array = _get_ai_units(units_container, ai_player)
	var unit_count: int = ai_units.size()

	# Keep a few units defending (nearest to own buildings)
	var defenders_needed: int = maxi(1, unit_count / 4)
	var defenders: Array = _pick_defenders(ai_units, game_map, ai_player, defenders_needed)

	for unit in ai_units:
		if unit.movement_remaining <= 0:
			continue

		if unit in defenders:
			_defend_behavior(unit, game_map, ai_player)
		else:
			_attack_behavior(unit, game_map, ai_player, player_hq_pos, combat_sys)

func _attack_behavior(unit: Node2D, game_map: Node2D, ai_player: int, target_pos: Vector2i, combat_sys: Node) -> void:
	# Check if we can attack an adjacent enemy
	var attacked: bool = _try_attack_adjacent(unit, game_map, ai_player, combat_sys)
	if attacked:
		return

	# Move toward the player's HQ or nearest enemy unit
	if target_pos == Vector2i(-999, -999):
		return

	var nearest_enemy: Vector2i = _find_nearest_enemy_unit(unit, game_map, ai_player)
	var move_target: Vector2i = nearest_enemy if nearest_enemy != Vector2i(-999, -999) else target_pos

	_move_toward(unit, move_target, game_map, ai_player)

	# Try attacking after moving
	_try_attack_adjacent(unit, game_map, ai_player, combat_sys)

func _defend_behavior(unit: Node2D, game_map: Node2D, ai_player: int) -> void:
	# Stay near own buildings, but attack adjacent enemies
	var nearest_building: Vector2i = _find_nearest_own_building(unit, game_map, ai_player)
	if nearest_building == Vector2i(-999, -999):
		return

	var dist: int = HexUtils.hex_distance(unit.hex_pos, nearest_building)
	if dist > 3:
		_move_toward(unit, nearest_building, game_map, ai_player)

func _try_attack_adjacent(unit: Node2D, game_map: Node2D, ai_player: int, combat_sys: Node) -> bool:
	if unit.has_attacked:
		return false
	if not combat_sys or not combat_sys.has_method("resolve_attack"):
		return false

	# Find adjacent enemy to attack
	for neighbor_hex in HexUtils.get_neighbors(unit.hex_pos):
		var target: Node2D = game_map.hex_grid.get_unit_at(neighbor_hex)
		if target and target.owner_id != ai_player:
			combat_sys.resolve_attack(unit, target)
			return true

	# Check ranged attack
	if unit.attack_range > 1:
		var in_range: Array[Vector2i] = HexUtils.hex_range(unit.hex_pos, unit.attack_range)
		for hex in in_range:
			var target: Node2D = game_map.hex_grid.get_unit_at(hex)
			if target and target.owner_id != ai_player:
				combat_sys.resolve_attack(unit, target)
				return true

	return false

func _move_toward(unit: Node2D, target: Vector2i, game_map: Node2D, ai_player: int) -> void:
	if unit.movement_remaining <= 0:
		return

	var blocked: Array[Vector2i] = _get_friendly_unit_hexes(game_map, ai_player, unit)
	var path: Array[Vector2i] = game_map.hex_grid.find_path(unit.hex_pos, target, unit.movement_remaining, blocked)
	if path.size() <= 1:
		return

	# Move to the farthest reachable hex on the path
	var best_hex: Vector2i = unit.hex_pos
	var budget: int = unit.movement_remaining
	for i in range(1, path.size()):
		var next: Vector2i = path[i]
		var cost: int = game_map.hex_grid.get_movement_cost(next)
		if cost > budget:
			break
		if game_map.hex_grid.get_unit_at(next) != null:
			break
		budget -= cost
		best_hex = next

	if best_hex != unit.hex_pos:
		var old_hex: Vector2i = unit.hex_pos
		game_map.hex_grid.remove_unit(old_hex)
		unit.move_to_hex(best_hex)
		game_map.hex_grid.place_unit(best_hex, unit)

func _find_nearest_enemy_unit(unit: Node2D, game_map: Node2D, ai_player: int) -> Vector2i:
	var nearest: Vector2i = Vector2i(-999, -999)
	var best_dist: int = 999
	var units_container: Node2D = game_map.get_node_or_null("Units")
	if not units_container:
		return nearest
	for other in units_container.get_children():
		if other.owner_id != ai_player:
			var dist: int = HexUtils.hex_distance(unit.hex_pos, other.hex_pos)
			if dist < best_dist:
				best_dist = dist
				nearest = other.hex_pos
	return nearest

func _find_nearest_own_building(unit: Node2D, game_map: Node2D, ai_player: int) -> Vector2i:
	var nearest: Vector2i = Vector2i(-999, -999)
	var best_dist: int = 999
	var buildings_container: Node2D = game_map.get_node_or_null("Buildings")
	if not buildings_container:
		return nearest
	for building in buildings_container.get_children():
		if building.owner_id == ai_player:
			var dist: int = HexUtils.hex_distance(unit.hex_pos, building.hex_pos)
			if dist < best_dist:
				best_dist = dist
				nearest = building.hex_pos
	return nearest

func _find_player_hq(game_map: Node2D) -> Vector2i:
	var buildings_container: Node2D = game_map.get_node_or_null("Buildings")
	if not buildings_container:
		return Vector2i(-999, -999)
	for building in buildings_container.get_children():
		if building.owner_id == Constants.Player.PLAYER and building.building_id == "headquarters":
			return building.hex_pos
	return Vector2i(-999, -999)

func _get_ai_units(units_container: Node2D, ai_player: int) -> Array:
	var units: Array = []
	for unit in units_container.get_children():
		if unit.owner_id == ai_player:
			units.append(unit)
	return units

func _pick_defenders(ai_units: Array, game_map: Node2D, ai_player: int, count: int) -> Array:
	# Pick units closest to own buildings as defenders
	var buildings_container: Node2D = game_map.get_node_or_null("Buildings")
	if not buildings_container:
		return []

	var building_positions: Array = []
	for building in buildings_container.get_children():
		if building.owner_id == ai_player:
			building_positions.append(building.hex_pos)

	if building_positions.size() == 0:
		return []

	# Sort units by minimum distance to any own building
	var scored: Array = []
	for unit in ai_units:
		var min_dist: int = 999
		for bpos in building_positions:
			var d: int = HexUtils.hex_distance(unit.hex_pos, bpos)
			if d < min_dist:
				min_dist = d
		scored.append({"unit": unit, "dist": min_dist})

	scored.sort_custom(func(a, b): return a["dist"] < b["dist"])

	var defenders: Array = []
	for i in range(mini(count, scored.size())):
		defenders.append(scored[i]["unit"])
	return defenders

func _get_friendly_unit_hexes(game_map: Node2D, ai_player: int, exclude_unit: Node2D) -> Array[Vector2i]:
	var hexes: Array[Vector2i] = []
	var units_container: Node2D = game_map.get_node_or_null("Units")
	if not units_container:
		return hexes
	for unit in units_container.get_children():
		if unit.owner_id == ai_player and unit != exclude_unit:
			hexes.append(unit.hex_pos)
	return hexes
