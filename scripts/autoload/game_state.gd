extends Node
## Global game state: turn tracking, player data, and game-wide state queries.

var turn_number: int = 1
var current_phase: int = Constants.TurnPhase.PLAYER_INPUT
var current_player: int = Constants.Player.PLAYER
var game_active: bool = false

# Per-player state
var player_resources: Dictionary = {
	Constants.Player.PLAYER: {},
	Constants.Player.AI: {}
}

var researched_techs: Dictionary = {
	Constants.Player.PLAYER: [],
	Constants.Player.AI: []
}

var current_research: Dictionary = {
	Constants.Player.PLAYER: null,  # { "tech_id": String, "turns_remaining": int } or null
	Constants.Player.AI: null
}

func _ready() -> void:
	pass

func init_game() -> void:
	turn_number = 1
	current_phase = Constants.TurnPhase.PLAYER_INPUT
	current_player = Constants.Player.PLAYER
	game_active = true
	# Initialize resources from data
	for player in [Constants.Player.PLAYER, Constants.Player.AI]:
		player_resources[player] = {}
		for res_id in GameData.resources:
			var def: Dictionary = GameData.resources[res_id]
			player_resources[player][res_id] = def.get("starting_amount", 0)
		researched_techs[player] = []
		current_research[player] = null

func get_resources(player: int) -> Dictionary:
	return player_resources.get(player, {})

func get_resource(player: int, resource_id: String) -> int:
	return player_resources.get(player, {}).get(resource_id, 0)

func add_resource(player: int, resource_id: String, amount: int) -> void:
	if not player_resources.has(player):
		return
	if not player_resources[player].has(resource_id):
		player_resources[player][resource_id] = 0
	player_resources[player][resource_id] += amount
	EventBus.resources_changed.emit(player, resource_id, player_resources[player][resource_id])

func spend_resource(player: int, resource_id: String, amount: int) -> bool:
	var current: int = get_resource(player, resource_id)
	if current < amount:
		EventBus.resources_insufficient.emit(player, resource_id)
		return false
	player_resources[player][resource_id] -= amount
	EventBus.resources_changed.emit(player, resource_id, player_resources[player][resource_id])
	return true

func can_afford(player: int, cost: Dictionary) -> bool:
	for res_id in cost:
		if get_resource(player, res_id) < cost[res_id]:
			return false
	return true

func spend_cost(player: int, cost: Dictionary) -> bool:
	if not can_afford(player, cost):
		return false
	for res_id in cost:
		spend_resource(player, res_id, cost[res_id])
	return true

func has_tech(player: int, tech_id: String) -> bool:
	return tech_id in researched_techs.get(player, [])

func complete_research(player: int, tech_id: String) -> void:
	if not researched_techs.has(player):
		return
	if tech_id not in researched_techs[player]:
		researched_techs[player].append(tech_id)
	current_research[player] = null
	EventBus.research_completed.emit(tech_id)
