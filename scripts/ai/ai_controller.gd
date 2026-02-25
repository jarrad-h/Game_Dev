extends Node
## AI opponent controller. Listens for ai_turn_started, takes actions, emits ai_turn_finished.
## Uses a simple priority-based decision system.

var game_map: Node2D = null
var systems_node: Node = null
var ai_player: int = Constants.Player.AI

func _ready() -> void:
	EventBus.ai_turn_started.connect(_on_ai_turn_started)

func set_references(map: Node2D, systems: Node) -> void:
	game_map = map
	systems_node = systems

func _on_ai_turn_started() -> void:
	if not game_map or not systems_node:
		EventBus.ai_turn_finished.emit()
		return

	# Execute AI decisions in priority order
	_do_economy_decisions()
	_do_research_decisions()
	_do_production_decisions()
	_do_logistics_decisions()
	_do_military_decisions()

	EventBus.ai_turn_finished.emit()

func _do_economy_decisions() -> void:
	var ai_econ: Node = get_node_or_null("AIEconomy")
	if ai_econ and ai_econ.has_method("make_decisions"):
		ai_econ.make_decisions(game_map, systems_node, ai_player)

func _do_research_decisions() -> void:
	var tech_mgr: Node = systems_node.get_node_or_null("TechManager")
	if not tech_mgr:
		return
	# Only research if not already researching
	if GameState.current_research[ai_player] != null:
		return
	if tech_mgr.has_method("get_available_techs"):
		var available: Array = tech_mgr.get_available_techs(ai_player)
		if available.size() > 0 and tech_mgr.has_method("start_research"):
			# Pick the first affordable tech
			for tech_id in available:
				var def: Dictionary = GameData.get_tech_def(tech_id)
				var cost: Dictionary = def.get("cost", {})
				if GameState.can_afford(ai_player, cost):
					tech_mgr.start_research(ai_player, tech_id)
					break

func _do_production_decisions() -> void:
	if not game_map:
		return
	var buildings_container: Node2D = game_map.get_node_or_null("Buildings")
	var prod_sys: Node = systems_node.get_node_or_null("ProductionSystem")
	if not buildings_container or not prod_sys:
		return

	for building in buildings_container.get_children():
		if building.owner_id != ai_player:
			continue
		if not building.can_produce_units or not building.is_operational():
			continue
		if building.production_queue.size() >= building.production_slots:
			continue
		# Decide what to produce
		var unit_to_produce: String = _pick_unit_to_produce()
		if unit_to_produce != "" and prod_sys.has_method("queue_unit"):
			prod_sys.queue_unit(building, unit_to_produce)

func _pick_unit_to_produce() -> String:
	var available: Array = GameData.get_available_units(GameState.researched_techs[ai_player])
	if available.size() == 0:
		return ""
	# Prefer infantry, then mix in armor/artillery
	var unit_counts: Dictionary = _count_units()
	var total: int = 0
	for id in unit_counts:
		total += unit_counts[id]

	# Favor infantry until we have a decent force
	if total < 5 or "infantry" not in available:
		if "infantry" in available:
			return "infantry"
		return available[0]

	# Mix: 60% infantry, 25% armor, 15% artillery
	var roll: float = randf()
	if roll < 0.15 and "artillery" in available:
		return "artillery"
	elif roll < 0.40 and "armor" in available:
		return "armor"
	return "infantry"

func _count_units() -> Dictionary:
	var counts: Dictionary = {}
	if not game_map:
		return counts
	var units_container: Node2D = game_map.get_node_or_null("Units")
	if not units_container:
		return counts
	for unit in units_container.get_children():
		if unit.owner_id == ai_player:
			if not counts.has(unit.unit_id):
				counts[unit.unit_id] = 0
			counts[unit.unit_id] += 1
	return counts

func _do_logistics_decisions() -> void:
	# Set rally points toward the player and create transport routes
	if not game_map:
		return
	var buildings_container: Node2D = game_map.get_node_or_null("Buildings")
	var logistics: Node = systems_node.get_node_or_null("LogisticsSystem")
	if not buildings_container or not logistics:
		return

	var player_hq_pos: Vector2i = _find_player_hq_pos()
	if player_hq_pos == Vector2i(-999, -999):
		return

	for building in buildings_container.get_children():
		if building.owner_id != ai_player:
			continue
		if not building.can_produce_units:
			continue
		# Set rally point toward the player (midpoint)
		if not building.has_rally_point:
			var mid: Vector2i = Vector2i(
				(building.hex_pos.x + player_hq_pos.x) / 2,
				(building.hex_pos.y + player_hq_pos.y) / 2
			)
			if game_map.hex_grid.is_valid(mid) and game_map.hex_grid.is_passable(mid):
				building.set_rally(mid)
			# Create a transport route from this building toward the front
			if logistics.has_method("create_route"):
				logistics.create_route(building, mid)

func _do_military_decisions() -> void:
	var ai_military: Node = get_node_or_null("AIMilitary")
	if ai_military and ai_military.has_method("make_decisions"):
		ai_military.make_decisions(game_map, systems_node, ai_player)

func _find_player_hq_pos() -> Vector2i:
	if not game_map:
		return Vector2i(-999, -999)
	var buildings_container: Node2D = game_map.get_node_or_null("Buildings")
	if not buildings_container:
		return Vector2i(-999, -999)
	for building in buildings_container.get_children():
		if building.owner_id == Constants.Player.PLAYER and building.building_id == "headquarters":
			return building.hex_pos
	return Vector2i(-999, -999)
