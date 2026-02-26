extends Node2D
## Root game node. Initializes all systems, wires references, and starts the game.

@onready var game_map: Node2D = $GameMap
@onready var hud: CanvasLayer = $HUD
@onready var systems: Node = $Systems
@onready var turn_manager: Node = $Systems/TurnManager
@onready var combat_system: Node = $Systems/CombatSystem
@onready var resource_manager: Node = $Systems/ResourceManager
@onready var production_system: Node = $Systems/ProductionSystem
@onready var logistics_system: Node = $Systems/LogisticsSystem
@onready var tech_manager: Node = $Systems/TechManager
@onready var fog_of_war: Node = $Systems/FogOfWar
@onready var ai_controller: Node = $Systems/AIController

func _ready() -> void:
	# Wire up game map references to all systems
	turn_manager.set_game_map(game_map)
	combat_system.set_game_map(game_map)
	resource_manager.set_game_map(game_map)
	production_system.set_game_map(game_map)
	logistics_system.set_game_map(game_map)
	tech_manager.set_game_map(game_map)
	fog_of_war.set_game_map(game_map)
	ai_controller.set_references(game_map, systems)

	# Wire up HUD
	hud.set_references(game_map, systems)

	# Connect HUD buttons
	var build_button: Button = hud.get_node_or_null("TopBar/BuildButton")
	if build_button:
		build_button.pressed.connect(func(): hud.show_build_menu())
	var tech_button: Button = hud.get_node_or_null("TopBar/TechButton")
	if tech_button:
		tech_button.pressed.connect(func(): hud.toggle_tech_tree())
	var tech_close: Button = hud.get_node_or_null("TechTreePanel/MarginContainer/CloseButton")
	if tech_close:
		tech_close.pressed.connect(func(): hud.tech_tree_panel.visible = false)

	# Connect combat events from map clicks
	EventBus.unit_attacked.connect(_on_unit_attack_requested)
	EventBus.building_placed.connect(_on_building_place_requested)

	# Connect fog of war updates
	EventBus.unit_moved.connect(func(_u, _f, _t): _update_fog())
	EventBus.unit_spawned.connect(func(_u, _h): _update_fog())
	EventBus.building_placed.connect(func(_b, _h): _update_fog())
	EventBus.turn_started.connect(func(_t): _update_fog())

	# Generate and display the map
	game_map.initialize_map(Constants.DEFAULT_MAP_WIDTH, Constants.DEFAULT_MAP_HEIGHT)

	# Place starting buildings and units
	_place_starting_entities()

	# Start the game
	turn_manager.start_game()
	_update_fog()

func _place_starting_entities() -> void:
	# Player HQ + starting units
	var player_hq: Node2D = UnitFactory.create_building("headquarters", Constants.Player.PLAYER, game_map.player_spawn)
	game_map.get_node("Buildings").add_child(player_hq)
	game_map.hex_grid.place_building(game_map.player_spawn, player_hq)

	# Place 2 starting infantry near player HQ
	var player_infantry_hexes: Array[Vector2i] = HexUtils.get_neighbors(game_map.player_spawn)
	var placed: int = 0
	for hex in player_infantry_hexes:
		if placed >= 2:
			break
		if game_map.hex_grid.is_passable(hex) and game_map.hex_grid.get_unit_at(hex) == null:
			var unit: Node2D = UnitFactory.create_unit("infantry", Constants.Player.PLAYER, hex)
			game_map.get_node("Units").add_child(unit)
			game_map.hex_grid.place_unit(hex, unit)
			placed += 1

	# AI HQ + starting units
	var ai_hq: Node2D = UnitFactory.create_building("headquarters", Constants.Player.AI, game_map.ai_spawn)
	game_map.get_node("Buildings").add_child(ai_hq)
	game_map.hex_grid.place_building(game_map.ai_spawn, ai_hq)

	var ai_infantry_hexes: Array[Vector2i] = HexUtils.get_neighbors(game_map.ai_spawn)
	placed = 0
	for hex in ai_infantry_hexes:
		if placed >= 2:
			break
		if game_map.hex_grid.is_passable(hex) and game_map.hex_grid.get_unit_at(hex) == null:
			var unit: Node2D = UnitFactory.create_unit("infantry", Constants.Player.AI, hex)
			game_map.get_node("Units").add_child(unit)
			game_map.hex_grid.place_unit(hex, unit)
			placed += 1

func _on_unit_attack_requested(attacker: Node2D, defender: Node2D) -> void:
	if combat_system and combat_system.has_method("resolve_attack"):
		combat_system.resolve_attack(attacker, defender)

func _on_building_place_requested(_building: Node2D, hex_pos: Vector2i) -> void:
	# This is called when the player clicks in build mode
	if game_map.pending_building_id != "":
		production_system.place_building(game_map.pending_building_id, Constants.Player.PLAYER, hex_pos)
		game_map.pending_building_id = ""

func _update_fog() -> void:
	fog_of_war.update_visibility()
	fog_of_war.apply_fog()
