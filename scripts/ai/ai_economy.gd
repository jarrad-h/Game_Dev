extends Node
## AI economic decision-making: builds resource structures and factories.

func make_decisions(game_map: Node2D, systems_node: Node, ai_player: int) -> void:
	if not game_map or not systems_node:
		return
	var prod_sys: Node = systems_node.get_node_or_null("ProductionSystem")
	if not prod_sys or not prod_sys.has_method("place_building"):
		return

	var income: Dictionary = _get_income(game_map, ai_player)
	var mat_income: int = income.get("materials", 0)
	var eng_income: int = income.get("energy", 0)
	var building_counts: Dictionary = _count_buildings(game_map, ai_player)

	# Priority 1: Ensure at least 1 extractor and 1 power plant
	if building_counts.get("extractor", 0) == 0 and GameState.can_afford(ai_player, {"materials": 40, "energy": 10}):
		_try_build(prod_sys, "extractor", ai_player, game_map)
		return

	if building_counts.get("power_plant", 0) == 0 and GameState.can_afford(ai_player, {"materials": 40, "energy": 5}):
		_try_build(prod_sys, "power_plant", ai_player, game_map)
		return

	# Priority 2: Build factory if we don't have one
	if building_counts.get("factory", 0) == 0 and GameState.can_afford(ai_player, {"materials": 80, "energy": 30}):
		_try_build(prod_sys, "factory", ai_player, game_map)
		return

	# Priority 3: Balance economy — aim for 2:1 ratio extractors to power plants
	if mat_income < eng_income * 2 and GameState.can_afford(ai_player, {"materials": 40, "energy": 10}):
		_try_build(prod_sys, "extractor", ai_player, game_map)
		return

	if eng_income < 10 and GameState.can_afford(ai_player, {"materials": 40, "energy": 5}):
		_try_build(prod_sys, "power_plant", ai_player, game_map)
		return

	# Priority 4: More factories for production throughput
	if building_counts.get("factory", 0) < 2 and GameState.can_afford(ai_player, {"materials": 80, "energy": 30}):
		_try_build(prod_sys, "factory", ai_player, game_map)

func _try_build(prod_sys: Node, building_id: String, ai_player: int, game_map: Node2D) -> void:
	# Find a buildable hex near the AI HQ
	var hq_pos: Vector2i = _find_hq(game_map, ai_player)
	if hq_pos == Vector2i(-999, -999):
		return

	# Search outward from HQ for a buildable spot
	for radius in range(1, 6):
		var ring: Array[Vector2i] = HexUtils.hex_ring(hq_pos, radius)
		for hex in ring:
			if game_map.hex_grid.is_buildable(hex):
				prod_sys.place_building(building_id, ai_player, hex)
				return

func _find_hq(game_map: Node2D, ai_player: int) -> Vector2i:
	var buildings_container: Node2D = game_map.get_node_or_null("Buildings")
	if not buildings_container:
		return Vector2i(-999, -999)
	for building in buildings_container.get_children():
		if building.owner_id == ai_player and building.building_id == "headquarters":
			return building.hex_pos
	return Vector2i(-999, -999)

func _count_buildings(game_map: Node2D, ai_player: int) -> Dictionary:
	var counts: Dictionary = {}
	var buildings_container: Node2D = game_map.get_node_or_null("Buildings")
	if not buildings_container:
		return counts
	for building in buildings_container.get_children():
		if building.owner_id == ai_player:
			if not counts.has(building.building_id):
				counts[building.building_id] = 0
			counts[building.building_id] += 1
	return counts

func _get_income(game_map: Node2D, ai_player: int) -> Dictionary:
	var income: Dictionary = {}
	var buildings_container: Node2D = game_map.get_node_or_null("Buildings")
	if not buildings_container:
		return income
	for building in buildings_container.get_children():
		if building.owner_id != ai_player or not building.is_operational():
			continue
		for res_id in building.resource_production:
			if not income.has(res_id):
				income[res_id] = 0
			income[res_id] += building.resource_production[res_id]
	return income
