class_name UnitFactory
extends RefCounted
## Creates unit and building instances from data definitions.

static var unit_scene: PackedScene = null
static var building_scene: PackedScene = null

static func _ensure_loaded() -> void:
	if unit_scene == null:
		unit_scene = load("res://scenes/unit.tscn")
	if building_scene == null:
		building_scene = load("res://scenes/building.tscn")

static func create_unit(unit_id: String, owner: int, hex_pos: Vector2i) -> Node2D:
	_ensure_loaded()
	var unit: Node2D = unit_scene.instantiate()
	unit.setup(unit_id, owner, hex_pos)
	return unit

static func create_building(building_id: String, owner: int, hex_pos: Vector2i) -> Node2D:
	_ensure_loaded()
	var building: Node2D = building_scene.instantiate()
	building.setup(building_id, owner, hex_pos)
	return building
