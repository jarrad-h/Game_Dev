extends Node
## Basic fog of war: hexes are visible if within sight range of owned units/buildings.

var game_map: Node2D = null
const UNIT_SIGHT_RANGE: int = 3
const BUILDING_SIGHT_RANGE: int = 2

var visible_hexes: Dictionary = {}  # Hex -> true for player-visible hexes

func set_game_map(map: Node2D) -> void:
	game_map = map

## Recalculate visibility for the human player.
func update_visibility() -> void:
	visible_hexes.clear()
	if not game_map or not game_map.hex_grid:
		return

	var player: int = Constants.Player.PLAYER

	# Units provide vision
	var units_container: Node2D = game_map.get_node_or_null("Units")
	if units_container:
		for unit in units_container.get_children():
			if unit.owner_id == player:
				var visible: Array[Vector2i] = HexUtils.hex_range(unit.hex_pos, UNIT_SIGHT_RANGE)
				for hex in visible:
					if game_map.hex_grid.is_valid(hex):
						visible_hexes[hex] = true

	# Buildings provide vision
	var buildings_container: Node2D = game_map.get_node_or_null("Buildings")
	if buildings_container:
		for building in buildings_container.get_children():
			if building.owner_id == player:
				var visible: Array[Vector2i] = HexUtils.hex_range(building.hex_pos, BUILDING_SIGHT_RANGE)
				for hex in visible:
					if game_map.hex_grid.is_valid(hex):
						visible_hexes[hex] = true

func is_hex_visible(hex: Vector2i) -> bool:
	return visible_hexes.has(hex)

## Apply fog overlay to tile nodes.
func apply_fog() -> void:
	if not game_map:
		return
	for hex_pos in game_map.tile_nodes:
		var tile_node: Node2D = game_map.tile_nodes[hex_pos]
		if visible_hexes.has(hex_pos):
			tile_node.modulate = Color.WHITE
		else:
			tile_node.modulate = Color(0.4, 0.4, 0.4, 1.0)

	# Hide enemy units/buildings in fog
	var units_container: Node2D = game_map.get_node_or_null("Units")
	if units_container:
		for unit in units_container.get_children():
			if unit.owner_id != Constants.Player.PLAYER:
				unit.visible = visible_hexes.has(unit.hex_pos)

	var buildings_container: Node2D = game_map.get_node_or_null("Buildings")
	if buildings_container:
		for building in buildings_container.get_children():
			if building.owner_id != Constants.Player.PLAYER:
				building.visible = visible_hexes.has(building.hex_pos)
