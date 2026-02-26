class_name MapGenerator
extends RefCounted
## Procedural map generator for hex grids.
## Creates terrain layout with two spawn areas on opposite sides.

const TERRAIN_WEIGHTS: Dictionary = {
	"plains": 50,
	"forest": 20,
	"hills": 15,
	"mountain": 8,
	"water": 7
}

var rng: RandomNumberGenerator

func _init() -> void:
	rng = RandomNumberGenerator.new()
	rng.randomize()

## Generate a hex grid with the given dimensions.
## Returns the populated HexGrid and spawn positions for each player.
func generate(width: int, height: int) -> Dictionary:
	var grid := HexGrid.new(width, height)
	var player_spawn := Vector2i.ZERO
	var ai_spawn := Vector2i.ZERO

	# Use offset coordinates for generation, then convert to axial
	for col in range(width):
		for row in range(height):
			# Convert offset (col, row) to axial (q, r) for flat-top
			var q: int = col
			var r: int = row - (col / 2)  # Integer division
			var hex := Vector2i(q, r)
			var terrain_id: String = _pick_terrain(q, r, width, height)
			grid.set_tile(hex, {
				"terrain": terrain_id,
				"owner": -1
			})

	# Place spawns on opposite sides
	var mid_row: int = height / 2
	player_spawn = Vector2i(1, mid_row - (1 / 2))
	ai_spawn = Vector2i(width - 2, mid_row - ((width - 2) / 2))

	# Clear area around spawns (make plains)
	_clear_spawn_area(grid, player_spawn)
	_clear_spawn_area(grid, ai_spawn)

	return {
		"grid": grid,
		"player_spawn": player_spawn,
		"ai_spawn": ai_spawn
	}

func _pick_terrain(q: int, r: int, width: int, height: int) -> String:
	# Map edges tend toward water
	var edge_dist: int = mini(mini(q, width - 1 - q), mini(r + (q / 2), height - 1 - r - (q / 2)))
	if edge_dist <= 0:
		return "water"

	# Weighted random selection
	var total_weight: int = 0
	for w in TERRAIN_WEIGHTS.values():
		total_weight += w

	var roll: int = rng.randi_range(0, total_weight - 1)
	var cumulative: int = 0
	for terrain_id in TERRAIN_WEIGHTS:
		cumulative += TERRAIN_WEIGHTS[terrain_id]
		if roll < cumulative:
			return terrain_id

	return "plains"

func _clear_spawn_area(grid: HexGrid, center: Vector2i) -> void:
	# Make the spawn hex and immediate neighbors plains
	if grid.is_valid(center):
		grid.tiles[center]["terrain"] = "plains"
	for neighbor in HexUtils.get_neighbors(center):
		if grid.is_valid(neighbor):
			grid.tiles[neighbor]["terrain"] = "plains"
	# Also clear ring-2 partially
	var ring2: Array[Vector2i] = HexUtils.hex_ring(center, 2)
	for hex in ring2:
		if grid.is_valid(hex):
			var terrain_id: String = grid.get_terrain_id(hex)
			if terrain_id == "water" or terrain_id == "mountain":
				grid.tiles[hex]["terrain"] = "plains"
