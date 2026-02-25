extends Node
## Manages resource income and expenditure each turn.

var game_map: Node2D = null

func set_game_map(map: Node2D) -> void:
	game_map = map

## Called during Upkeep phase — collect resources from all operational buildings.
func process_turn() -> void:
	if not game_map:
		return
	var buildings_container: Node2D = game_map.get_node_or_null("Buildings")
	if not buildings_container:
		return

	for player in [Constants.Player.PLAYER, Constants.Player.AI]:
		var income: Dictionary = _calculate_income(buildings_container, player)
		for res_id in income:
			GameState.add_resource(player, res_id, income[res_id])

func _calculate_income(buildings_container: Node2D, player: int) -> Dictionary:
	var income: Dictionary = {}
	for building in buildings_container.get_children():
		if building.owner_id != player:
			continue
		if not building.is_operational():
			continue
		for res_id in building.resource_production:
			if not income.has(res_id):
				income[res_id] = 0
			income[res_id] += building.resource_production[res_id]
	return income

## Get projected income for a player (for UI display).
func get_income(player: int) -> Dictionary:
	if not game_map:
		return {}
	var buildings_container: Node2D = game_map.get_node_or_null("Buildings")
	if not buildings_container:
		return {}
	return _calculate_income(buildings_container, player)
