extends Node
## Handles combat resolution with battle line mechanics.
## Features: adjacency bonuses, flanking, zone of control, ranged support.

var game_map: Node2D = null

func set_game_map(map: Node2D) -> void:
	game_map = map

## Resolve a single attack between two units.
func resolve_attack(attacker: Node2D, defender: Node2D) -> Dictionary:
	var atk_bonus: float = _get_adjacency_bonus(attacker)
	var def_bonus: float = _get_adjacency_bonus(defender)
	var flank_mult: float = _get_flank_multiplier(defender)

	var atk_roll: float = randf_range(Constants.COMBAT_RANDOM_MIN, Constants.COMBAT_RANDOM_MAX)
	var effective_attack: float = (attacker.attack_power + atk_bonus) * atk_roll
	var effective_defense: float = defender.get_effective_defense() + def_bonus

	# Terrain defense bonus
	if game_map and game_map.hex_grid:
		var terrain_id: String = game_map.hex_grid.get_terrain_id(defender.hex_pos)
		var terrain_def: Dictionary = GameData.get_terrain_def(terrain_id)
		effective_defense += terrain_def.get("defense_bonus", 0)

	var damage: int = maxi(1, roundi(effective_attack * flank_mult - effective_defense))

	# Counterattack (if defender is in range)
	var counter_damage: int = 0
	var distance: int = HexUtils.hex_distance(attacker.hex_pos, defender.hex_pos)
	if distance <= defender.attack_range:
		var def_roll: float = randf_range(Constants.COMBAT_RANDOM_MIN, Constants.COMBAT_RANDOM_MAX)
		var counter_attack: float = (defender.attack_power + def_bonus) * def_roll * 0.5  # Counter at half strength
		var counter_defense: float = attacker.get_effective_defense() + atk_bonus
		counter_damage = maxi(0, roundi(counter_attack - counter_defense))

	defender.take_damage(damage)
	if counter_damage > 0:
		attacker.take_damage(counter_damage)

	attacker.has_attacked = true
	attacker.movement_remaining = 0

	var result: Dictionary = {
		"damage_dealt": damage,
		"counter_damage": counter_damage,
		"attacker_alive": attacker.hp > 0,
		"defender_alive": defender.hp > 0
	}
	EventBus.combat_resolved.emit(attacker, defender, result)
	return result

## Resolve all combat engagements at the end of turn.
## Auto-combat: all units adjacent to enemies exchange fire.
func resolve_all_combat() -> void:
	if not game_map or not game_map.hex_grid:
		return
	var units_container: Node2D = game_map.get_node_or_null("Units")
	if not units_container:
		return

	# Collect all engagement pairs to avoid double-processing
	var processed: Dictionary = {}
	var engagements: Array = []

	for unit in units_container.get_children():
		for neighbor_hex in HexUtils.get_neighbors(unit.hex_pos):
			var other: Node2D = game_map.hex_grid.get_unit_at(neighbor_hex)
			if other and other.owner_id != unit.owner_id:
				var pair_key: String = _pair_key(unit, other)
				if not processed.has(pair_key):
					processed[pair_key] = true
					engagements.append([unit, other])

	# Resolve all engagements (damage is applied immediately, but all are calculated)
	for pair in engagements:
		var a: Node2D = pair[0]
		var b: Node2D = pair[1]
		if a.hp > 0 and b.hp > 0:
			_resolve_engagement(a, b)

func _resolve_engagement(unit_a: Node2D, unit_b: Node2D) -> void:
	## Simultaneous exchange of fire between two adjacent enemy units.
	var a_bonus: float = _get_adjacency_bonus(unit_a)
	var b_bonus: float = _get_adjacency_bonus(unit_b)
	var a_flank: float = _get_flank_multiplier(unit_a)
	var b_flank: float = _get_flank_multiplier(unit_b)

	var a_roll: float = randf_range(Constants.COMBAT_RANDOM_MIN, Constants.COMBAT_RANDOM_MAX)
	var b_roll: float = randf_range(Constants.COMBAT_RANDOM_MIN, Constants.COMBAT_RANDOM_MAX)

	var a_terrain_def: int = 0
	var b_terrain_def: int = 0
	if game_map and game_map.hex_grid:
		a_terrain_def = GameData.get_terrain_def(game_map.hex_grid.get_terrain_id(unit_a.hex_pos)).get("defense_bonus", 0)
		b_terrain_def = GameData.get_terrain_def(game_map.hex_grid.get_terrain_id(unit_b.hex_pos)).get("defense_bonus", 0)

	var damage_to_b: int = maxi(1, roundi(
		(unit_a.attack_power + a_bonus) * a_roll * b_flank
		- (unit_b.get_effective_defense() + b_bonus + b_terrain_def)
	))
	var damage_to_a: int = maxi(1, roundi(
		(unit_b.attack_power + b_bonus) * b_roll * a_flank
		- (unit_a.get_effective_defense() + a_bonus + a_terrain_def)
	))

	# Apply damage to both simultaneously
	unit_a.take_damage(damage_to_a)
	unit_b.take_damage(damage_to_b)

## Count adjacent friendly units for the battle line bonus.
func _get_adjacency_bonus(unit: Node2D) -> float:
	if not game_map or not game_map.hex_grid:
		return 0.0
	var bonus: float = 0.0
	for neighbor_hex in HexUtils.get_neighbors(unit.hex_pos):
		var other: Node2D = game_map.hex_grid.get_unit_at(neighbor_hex)
		if other and other.owner_id == unit.owner_id:
			bonus += Constants.ADJACENCY_BONUS
	return bonus

## Check if a unit is flanked (enemies on 3+ sides).
func _get_flank_multiplier(unit: Node2D) -> float:
	if not game_map or not game_map.hex_grid:
		return 1.0
	var enemy_sides: int = 0
	for neighbor_hex in HexUtils.get_neighbors(unit.hex_pos):
		var other: Node2D = game_map.hex_grid.get_unit_at(neighbor_hex)
		if other and other.owner_id != unit.owner_id:
			enemy_sides += 1
	if enemy_sides >= Constants.FLANK_THRESHOLD:
		return Constants.FLANK_DAMAGE_MULTIPLIER
	return 1.0

## Get all hexes in a player's zone of control (adjacent to their units).
func get_zoc_hexes(player: int) -> Dictionary:
	var zoc: Dictionary = {}
	if not game_map or not game_map.hex_grid:
		return zoc
	var units_container: Node2D = game_map.get_node_or_null("Units")
	if not units_container:
		return zoc
	for unit in units_container.get_children():
		if unit.owner_id == player:
			for neighbor_hex in HexUtils.get_neighbors(unit.hex_pos):
				zoc[neighbor_hex] = true
	return zoc

func _pair_key(a: Node2D, b: Node2D) -> String:
	var id_a: int = a.get_instance_id()
	var id_b: int = b.get_instance_id()
	if id_a < id_b:
		return "%d_%d" % [id_a, id_b]
	return "%d_%d" % [id_b, id_a]
