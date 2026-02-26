extends Node
## Loads and provides access to all JSON data files.
## This is the single source of truth for game content definitions.

var units: Dictionary = {}
var buildings: Dictionary = {}
var terrain: Dictionary = {}
var resources: Dictionary = {}
var tech_tree: Dictionary = {}

func _ready() -> void:
	_load_all_data()

func _load_all_data() -> void:
	units = _load_json("res://data/units.json")
	buildings = _load_json("res://data/buildings.json")
	terrain = _load_json("res://data/terrain.json")
	resources = _load_json("res://data/resources.json")
	tech_tree = _load_json("res://data/tech_tree.json")

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Data file not found: " + path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var json_text := file.get_as_text()
	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		push_error("JSON parse error in %s at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	return json.data

func get_unit_def(unit_id: String) -> Dictionary:
	if units.has(unit_id):
		return units[unit_id]
	push_error("Unknown unit type: " + unit_id)
	return {}

func get_building_def(building_id: String) -> Dictionary:
	if buildings.has(building_id):
		return buildings[building_id]
	push_error("Unknown building type: " + building_id)
	return {}

func get_terrain_def(terrain_id: String) -> Dictionary:
	if terrain.has(terrain_id):
		return terrain[terrain_id]
	push_error("Unknown terrain type: " + terrain_id)
	return {}

func get_resource_def(resource_id: String) -> Dictionary:
	if resources.has(resource_id):
		return resources[resource_id]
	push_error("Unknown resource type: " + resource_id)
	return {}

func get_tech_def(tech_id: String) -> Dictionary:
	if tech_tree.has(tech_id):
		return tech_tree[tech_id]
	push_error("Unknown tech: " + tech_id)
	return {}

func get_available_units(researched_techs: Array) -> Array:
	var available: Array = []
	for unit_id in units:
		var def: Dictionary = units[unit_id]
		var req = def.get("tech_required")
		if req == null or req in researched_techs:
			available.append(unit_id)
	return available

func get_available_buildings(researched_techs: Array) -> Array:
	var available: Array = []
	for building_id in buildings:
		var def: Dictionary = buildings[building_id]
		var req = def.get("tech_required")
		if req == null or req in researched_techs:
			available.append(building_id)
	return available
