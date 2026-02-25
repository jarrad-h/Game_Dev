extends Node
## Global event bus for decoupled communication between systems.
## All game-wide signals are defined here. Systems emit and connect to these
## without needing direct references to each other.

# --- Turn Signals ---
signal turn_started(turn_number: int)
signal phase_changed(phase: int)  # Constants.TurnPhase
signal turn_ended(turn_number: int)
signal player_turn_started()
signal ai_turn_started()
signal ai_turn_finished()

# --- Selection / Input ---
signal hex_clicked(hex_pos: Vector2i, button: int)
signal hex_hovered(hex_pos: Vector2i)
signal unit_selected(unit: Node2D)
signal unit_deselected()
signal building_selected(building: Node2D)
signal building_deselected()

# --- Unit Signals ---
signal unit_moved(unit: Node2D, from_hex: Vector2i, to_hex: Vector2i)
signal unit_attacked(attacker: Node2D, defender: Node2D)
signal unit_destroyed(unit: Node2D)
signal unit_spawned(unit: Node2D, hex_pos: Vector2i)

# --- Building Signals ---
signal building_placed(building: Node2D, hex_pos: Vector2i)
signal building_destroyed(building: Node2D)
signal building_completed(building: Node2D)

# --- Production Signals ---
signal production_queued(building: Node2D, unit_id: String)
signal production_completed(building: Node2D, unit_id: String)
signal rally_point_set(building: Node2D, hex_pos: Vector2i)

# --- Logistics Signals ---
signal route_created(route_id: int, source: Node2D, dest_hex: Vector2i)
signal route_removed(route_id: int)
signal transport_departed(unit: Node2D, route_id: int)
signal transport_arrived(unit: Node2D, route_id: int)

# --- Resource Signals ---
signal resources_changed(player: int, resource_id: String, new_amount: int)
signal resources_insufficient(player: int, resource_id: String)

# --- Tech Signals ---
signal research_started(tech_id: String)
signal research_completed(tech_id: String)

# --- Combat Signals ---
signal combat_resolved(attacker: Node2D, defender: Node2D, result: Dictionary)

# --- Game State ---
signal game_over(winner: int)  # Constants.Player
