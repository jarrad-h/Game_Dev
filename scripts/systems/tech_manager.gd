extends Node
## Manages technology research for all players.

var game_map: Node2D = null

func set_game_map(map: Node2D) -> void:
	game_map = map

## Start researching a tech for a player.
func start_research(player: int, tech_id: String) -> bool:
	# Already researching something
	if GameState.current_research[player] != null:
		return false
	# Already researched
	if GameState.has_tech(player, tech_id):
		return false

	var def: Dictionary = GameData.get_tech_def(tech_id)
	if def.is_empty():
		return false

	# Check prerequisites
	var prereqs: Array = def.get("prerequisites", [])
	for prereq in prereqs:
		if not GameState.has_tech(player, prereq):
			return false

	# Check cost
	var cost: Dictionary = def.get("cost", {})
	if not GameState.can_afford(player, cost):
		return false

	# Pay cost
	GameState.spend_cost(player, cost)

	# Start research
	GameState.current_research[player] = {
		"tech_id": tech_id,
		"turns_remaining": def.get("research_time", 1)
	}
	EventBus.research_started.emit(tech_id)
	return true

## Called during Upkeep phase — advance research timers.
func process_turn() -> void:
	for player in [Constants.Player.PLAYER, Constants.Player.AI]:
		var research = GameState.current_research[player]
		if research == null:
			continue
		research["turns_remaining"] -= 1
		if research["turns_remaining"] <= 0:
			var tech_id: String = research["tech_id"]
			GameState.complete_research(player, tech_id)

## Get available techs for a player (not yet researched, prerequisites met).
func get_available_techs(player: int) -> Array:
	var available: Array = []
	for tech_id in GameData.tech_tree:
		if GameState.has_tech(player, tech_id):
			continue
		var def: Dictionary = GameData.tech_tree[tech_id]
		var prereqs: Array = def.get("prerequisites", [])
		var prereqs_met: bool = true
		for prereq in prereqs:
			if not GameState.has_tech(player, prereq):
				prereqs_met = false
				break
		if prereqs_met:
			available.append(tech_id)
	return available

## Get research progress string for UI.
func get_research_status(player: int) -> String:
	var research = GameState.current_research[player]
	if research == null:
		return "None"
	var def: Dictionary = GameData.get_tech_def(research["tech_id"])
	return "%s (%d turns)" % [def.get("name", "???"), research["turns_remaining"]]
