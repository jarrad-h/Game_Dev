extends Node
## Manages the turn cycle and phase progression.
## Turn order: Player Input → AI → Combat Resolution → Production → Logistics → Upkeep

var game_map: Node2D = null

func _ready() -> void:
	EventBus.ai_turn_finished.connect(_on_ai_turn_finished)

func set_game_map(map: Node2D) -> void:
	game_map = map

func start_game() -> void:
	GameState.init_game()
	EventBus.turn_started.emit(GameState.turn_number)
	_start_phase(Constants.TurnPhase.PLAYER_INPUT)

func end_player_turn() -> void:
	if GameState.current_phase != Constants.TurnPhase.PLAYER_INPUT:
		return
	_advance_phase()

func _start_phase(phase: int) -> void:
	GameState.current_phase = phase
	EventBus.phase_changed.emit(phase)

	match phase:
		Constants.TurnPhase.PLAYER_INPUT:
			_start_player_input()
		Constants.TurnPhase.AI_TURN:
			_start_ai_turn()
		Constants.TurnPhase.COMBAT_RESOLUTION:
			_resolve_combat()
		Constants.TurnPhase.PRODUCTION:
			_process_production()
		Constants.TurnPhase.LOGISTICS:
			_process_logistics()
		Constants.TurnPhase.UPKEEP:
			_process_upkeep()

func _advance_phase() -> void:
	var next_phase: int = GameState.current_phase + 1
	if next_phase > Constants.TurnPhase.UPKEEP:
		# Turn is complete, start new turn
		GameState.turn_number += 1
		EventBus.turn_ended.emit(GameState.turn_number - 1)
		EventBus.turn_started.emit(GameState.turn_number)
		_start_phase(Constants.TurnPhase.PLAYER_INPUT)
	else:
		_start_phase(next_phase)

func _start_player_input() -> void:
	EventBus.player_turn_started.emit()
	# Reset unit movement for player
	_reset_units_for_turn(Constants.Player.PLAYER)

func _start_ai_turn() -> void:
	# Reset AI units
	_reset_units_for_turn(Constants.Player.AI)
	EventBus.ai_turn_started.emit()
	# AI controller listens for ai_turn_started and emits ai_turn_finished when done

func _on_ai_turn_finished() -> void:
	if GameState.current_phase == Constants.TurnPhase.AI_TURN:
		_advance_phase()

func _resolve_combat() -> void:
	# Delegate to CombatSystem — it will process all engagements
	var combat_system: Node = get_parent().get_node_or_null("CombatSystem")
	if combat_system and combat_system.has_method("resolve_all_combat"):
		combat_system.resolve_all_combat()
	_advance_phase()

func _process_production() -> void:
	var production_system: Node = get_parent().get_node_or_null("ProductionSystem")
	if production_system and production_system.has_method("process_turn"):
		production_system.process_turn()
	_advance_phase()

func _process_logistics() -> void:
	var logistics_system: Node = get_parent().get_node_or_null("LogisticsSystem")
	if logistics_system and logistics_system.has_method("process_turn"):
		logistics_system.process_turn()
	_advance_phase()

func _process_upkeep() -> void:
	var resource_manager: Node = get_parent().get_node_or_null("ResourceManager")
	if resource_manager and resource_manager.has_method("process_turn"):
		resource_manager.process_turn()
	# Advance tech research
	var tech_manager: Node = get_parent().get_node_or_null("TechManager")
	if tech_manager and tech_manager.has_method("process_turn"):
		tech_manager.process_turn()
	# Check win conditions
	_check_win_conditions()
	_advance_phase()

func _reset_units_for_turn(player: int) -> void:
	if not game_map:
		return
	var units_container: Node2D = game_map.get_node_or_null("Units")
	if not units_container:
		return
	for unit in units_container.get_children():
		if unit.owner_id == player:
			unit.start_turn()

func _check_win_conditions() -> void:
	if not game_map:
		return
	var player_has_hq: bool = false
	var ai_has_hq: bool = false
	var buildings_container: Node2D = game_map.get_node_or_null("Buildings")
	if not buildings_container:
		return
	for building in buildings_container.get_children():
		if building.building_id == "headquarters":
			if building.owner_id == Constants.Player.PLAYER:
				player_has_hq = true
			elif building.owner_id == Constants.Player.AI:
				ai_has_hq = true
	if not ai_has_hq:
		EventBus.game_over.emit(Constants.Player.PLAYER)
		GameState.game_active = false
	elif not player_has_hq:
		EventBus.game_over.emit(Constants.Player.AI)
		GameState.game_active = false
