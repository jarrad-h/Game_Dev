extends CanvasLayer
## Main HUD: resource display, turn info, contextual panels, end turn button.

@onready var top_bar: HBoxContainer = $TopBar
@onready var materials_label: Label = $TopBar/MaterialsLabel
@onready var energy_label: Label = $TopBar/EnergyLabel
@onready var turn_label: Label = $TopBar/TurnLabel
@onready var phase_label: Label = $TopBar/PhaseLabel
@onready var income_label: Label = $TopBar/IncomeLabel

@onready var bottom_panel: PanelContainer = $BottomPanel
@onready var unit_info_panel: VBoxContainer = $BottomPanel/MarginContainer/Panels/UnitInfoPanel
@onready var build_menu: VBoxContainer = $BottomPanel/MarginContainer/Panels/BuildMenu
@onready var production_menu: VBoxContainer = $BottomPanel/MarginContainer/Panels/ProductionMenu
@onready var logistics_panel: VBoxContainer = $BottomPanel/MarginContainer/Panels/LogisticsPanel

@onready var tech_tree_panel: PanelContainer = $TechTreePanel
@onready var end_turn_button: Button = $EndTurnButton
@onready var game_over_label: Label = $GameOverLabel

var game_map: Node2D = null
var systems_node: Node = null

func _ready() -> void:
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.unit_selected.connect(_on_unit_selected)
	EventBus.unit_deselected.connect(_on_unit_deselected)
	EventBus.building_selected.connect(_on_building_selected)
	EventBus.building_deselected.connect(_on_building_deselected)
	EventBus.game_over.connect(_on_game_over)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	game_over_label.visible = false
	_hide_all_panels()
	_update_resources()

func set_references(map: Node2D, systems: Node) -> void:
	game_map = map
	systems_node = systems

func _process(_delta: float) -> void:
	_update_resources()

func _update_resources() -> void:
	var mat: int = GameState.get_resource(Constants.Player.PLAYER, "materials")
	var energy: int = GameState.get_resource(Constants.Player.PLAYER, "energy")
	materials_label.text = "Mat: %d" % mat
	energy_label.text = "Eng: %d" % energy
	turn_label.text = "Turn: %d" % GameState.turn_number

	# Show income
	if systems_node:
		var res_mgr: Node = systems_node.get_node_or_null("ResourceManager")
		if res_mgr and res_mgr.has_method("get_income"):
			var income: Dictionary = res_mgr.get_income(Constants.Player.PLAYER)
			var mat_inc: int = income.get("materials", 0)
			var eng_inc: int = income.get("energy", 0)
			income_label.text = "(+%d/+%d)" % [mat_inc, eng_inc]

func _on_resources_changed(_player: int, _res_id: String, _amount: int) -> void:
	_update_resources()

func _on_turn_started(_turn: int) -> void:
	_update_resources()

func _on_phase_changed(phase: int) -> void:
	var phase_names: Array = ["Your Turn", "AI Turn", "Combat", "Production", "Logistics", "Upkeep"]
	if phase < phase_names.size():
		phase_label.text = phase_names[phase]
	end_turn_button.disabled = (phase != Constants.TurnPhase.PLAYER_INPUT)

func _on_end_turn_pressed() -> void:
	if not systems_node:
		return
	var turn_mgr: Node = systems_node.get_node_or_null("TurnManager")
	if turn_mgr and turn_mgr.has_method("end_player_turn"):
		turn_mgr.end_player_turn()

func _hide_all_panels() -> void:
	unit_info_panel.visible = false
	build_menu.visible = false
	production_menu.visible = false
	logistics_panel.visible = false
	tech_tree_panel.visible = false

func _on_unit_selected(unit: Node2D) -> void:
	_hide_all_panels()
	unit_info_panel.visible = true
	_update_unit_info(unit)

func _on_unit_deselected() -> void:
	unit_info_panel.visible = false

func _on_building_selected(building: Node2D) -> void:
	_hide_all_panels()
	if building.can_produce_units and building.is_operational():
		production_menu.visible = true
		_update_production_menu(building)
	else:
		build_menu.visible = true

func _on_building_deselected() -> void:
	_hide_all_panels()

func _update_unit_info(unit: Node2D) -> void:
	var info_label: Label = unit_info_panel.get_node_or_null("InfoLabel")
	if info_label:
		info_label.text = "%s\nHP: %d/%d\nATK: %d  DEF: %d\nMove: %d/%d  Range: %d" % [
			unit.unit_name, unit.hp, unit.max_hp,
			unit.attack_power, unit.defense_power,
			unit.movement_remaining, unit.max_movement, unit.attack_range
		]

func _update_production_menu(building: Node2D) -> void:
	# Clear existing buttons
	var button_container: VBoxContainer = production_menu.get_node_or_null("ButtonContainer")
	if not button_container:
		return
	for child in button_container.get_children():
		child.queue_free()

	# Show queue status
	var queue_label: Label = production_menu.get_node_or_null("QueueLabel")
	if queue_label:
		var queue_text: String = "Queue: %d/%d" % [building.production_queue.size(), building.production_slots]
		if building.production_queue.size() > 0:
			for item in building.production_queue:
				var unit_def: Dictionary = GameData.get_unit_def(item["unit_id"])
				queue_text += "\n  - %s (%d turns)" % [unit_def.get("name", "?"), item["turns_remaining"]]
		queue_label.text = queue_text

	# Add produce buttons for available units
	var available: Array = GameData.get_available_units(GameState.researched_techs[Constants.Player.PLAYER])
	for unit_id in available:
		var def: Dictionary = GameData.get_unit_def(unit_id)
		var cost: Dictionary = def.get("cost", {})
		var cost_str: String = ""
		for res_id in cost:
			cost_str += "%s:%d " % [res_id.substr(0, 3), cost[res_id]]
		var btn := Button.new()
		btn.text = "%s (%s)" % [def.get("name", unit_id), cost_str.strip_edges()]
		btn.pressed.connect(_on_produce_pressed.bind(building, unit_id))
		button_container.add_child(btn)

	# Rally point button
	var rally_btn := Button.new()
	rally_btn.text = "Set Rally Point"
	rally_btn.pressed.connect(_on_rally_point_pressed)
	button_container.add_child(rally_btn)

	# Route button
	var route_btn := Button.new()
	route_btn.text = "Create Transport Route"
	route_btn.pressed.connect(_on_route_pressed)
	button_container.add_child(route_btn)

func _on_produce_pressed(building: Node2D, unit_id: String) -> void:
	if not systems_node:
		return
	var prod_sys: Node = systems_node.get_node_or_null("ProductionSystem")
	if prod_sys and prod_sys.has_method("queue_unit"):
		prod_sys.queue_unit(building, unit_id)
		_update_production_menu(building)

func _on_rally_point_pressed() -> void:
	if game_map and game_map.has_method("enter_rally_point_mode"):
		game_map.enter_rally_point_mode()

func _on_route_pressed() -> void:
	if game_map and game_map.has_method("enter_route_mode"):
		game_map.enter_route_mode()

## Toggle the build menu (called from a build button in the HUD).
func show_build_menu() -> void:
	_hide_all_panels()
	build_menu.visible = true
	_populate_build_menu()

func _populate_build_menu() -> void:
	var button_container: VBoxContainer = build_menu.get_node_or_null("ButtonContainer")
	if not button_container:
		return
	for child in button_container.get_children():
		child.queue_free()

	var available: Array = GameData.get_available_buildings(GameState.researched_techs[Constants.Player.PLAYER])
	for building_id in available:
		var def: Dictionary = GameData.get_building_def(building_id)
		if building_id == "headquarters":
			continue  # Can't build additional HQs
		var cost: Dictionary = def.get("cost", {})
		var cost_str: String = ""
		for res_id in cost:
			cost_str += "%s:%d " % [res_id.substr(0, 3), cost[res_id]]
		var btn := Button.new()
		btn.text = "%s (%s)" % [def.get("name", building_id), cost_str.strip_edges()]
		btn.pressed.connect(_on_build_pressed.bind(building_id))
		button_container.add_child(btn)

func _on_build_pressed(building_id: String) -> void:
	if game_map and game_map.has_method("enter_build_mode"):
		game_map.enter_build_mode(building_id)

## Toggle tech tree panel.
func toggle_tech_tree() -> void:
	tech_tree_panel.visible = not tech_tree_panel.visible
	if tech_tree_panel.visible:
		_populate_tech_tree()

func _populate_tech_tree() -> void:
	var container: VBoxContainer = tech_tree_panel.get_node_or_null("MarginContainer/TechContainer")
	if not container:
		return
	for child in container.get_children():
		child.queue_free()

	# Current research
	var status_label := Label.new()
	if systems_node:
		var tech_mgr: Node = systems_node.get_node_or_null("TechManager")
		if tech_mgr and tech_mgr.has_method("get_research_status"):
			status_label.text = "Researching: " + tech_mgr.get_research_status(Constants.Player.PLAYER)
	container.add_child(status_label)

	# Available techs
	if systems_node:
		var tech_mgr: Node = systems_node.get_node_or_null("TechManager")
		if tech_mgr and tech_mgr.has_method("get_available_techs"):
			var available: Array = tech_mgr.get_available_techs(Constants.Player.PLAYER)
			for tech_id in available:
				var def: Dictionary = GameData.get_tech_def(tech_id)
				var cost: Dictionary = def.get("cost", {})
				var cost_str: String = ""
				for res_id in cost:
					cost_str += "%s:%d " % [res_id.substr(0, 3), cost[res_id]]
				var btn := Button.new()
				btn.text = "%s (%s- %d turns)" % [def.get("name", tech_id), cost_str, def.get("research_time", 1)]
				btn.pressed.connect(_on_research_pressed.bind(tech_id))
				container.add_child(btn)

				var desc := Label.new()
				desc.text = "  " + def.get("description", "")
				desc.add_theme_font_size_override("font_size", 12)
				container.add_child(desc)

	# Researched techs
	var researched_label := Label.new()
	researched_label.text = "\nCompleted:"
	container.add_child(researched_label)
	for tech_id in GameState.researched_techs[Constants.Player.PLAYER]:
		var def: Dictionary = GameData.get_tech_def(tech_id)
		var label := Label.new()
		label.text = "  [done] " + def.get("name", tech_id)
		label.add_theme_color_override("font_color", Color.GREEN)
		container.add_child(label)

func _on_research_pressed(tech_id: String) -> void:
	if not systems_node:
		return
	var tech_mgr: Node = systems_node.get_node_or_null("TechManager")
	if tech_mgr and tech_mgr.has_method("start_research"):
		tech_mgr.start_research(Constants.Player.PLAYER, tech_id)
		_populate_tech_tree()

func _on_game_over(winner: int) -> void:
	game_over_label.visible = true
	if winner == Constants.Player.PLAYER:
		game_over_label.text = "VICTORY!\nEnemy HQ Destroyed"
		game_over_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		game_over_label.text = "DEFEAT!\nYour HQ was Destroyed"
		game_over_label.add_theme_color_override("font_color", Color.RED)
