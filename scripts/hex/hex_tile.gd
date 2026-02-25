extends Node2D
## Visual representation of a single hex tile.
## Draws a colored hexagon based on terrain type and shows ownership/selection overlays.

var hex_pos: Vector2i = Vector2i.ZERO
var terrain_id: String = "plains"
var terrain_color: Color = Color("#7EC850")
var is_hovered: bool = false
var is_in_range: bool = false
var is_in_path: bool = false
var owner_id: int = -1  # -1 = unclaimed

var _hex_corners: PackedVector2Array

func _ready() -> void:
	_hex_corners = HexUtils.get_hex_corners_local(Constants.HEX_SIZE)

func setup(pos: Vector2i, t_id: String) -> void:
	hex_pos = pos
	terrain_id = t_id
	var terrain_def: Dictionary = GameData.get_terrain_def(terrain_id)
	terrain_color = Color(terrain_def.get("color", "#7EC850"))
	position = HexUtils.axial_to_pixel(hex_pos)
	queue_redraw()

func set_hovered(hovered: bool) -> void:
	if is_hovered != hovered:
		is_hovered = hovered
		queue_redraw()

func set_in_range(in_range: bool) -> void:
	if is_in_range != in_range:
		is_in_range = in_range
		queue_redraw()

func set_in_path(in_path: bool) -> void:
	if is_in_path != in_path:
		is_in_path = in_path
		queue_redraw()

func set_owner_id(new_owner: int) -> void:
	if owner_id != new_owner:
		owner_id = new_owner
		queue_redraw()

func _draw() -> void:
	# Fill hex with terrain color
	draw_colored_polygon(_hex_corners, terrain_color)

	# Ownership tint
	if owner_id == Constants.Player.PLAYER:
		draw_colored_polygon(_hex_corners, Color(0.0, 0.3, 0.8, 0.12))
	elif owner_id == Constants.Player.AI:
		draw_colored_polygon(_hex_corners, Color(0.8, 0.1, 0.1, 0.12))

	# Movement range overlay
	if is_in_range:
		draw_colored_polygon(_hex_corners, Color(0.2, 0.6, 1.0, 0.2))

	# Path overlay
	if is_in_path:
		draw_colored_polygon(_hex_corners, Color(1.0, 1.0, 0.2, 0.25))

	# Hover highlight
	if is_hovered:
		draw_colored_polygon(_hex_corners, Color(1.0, 1.0, 1.0, 0.15))

	# Hex outline
	var outline_color := Color(0.0, 0.0, 0.0, 0.3)
	for i in range(_hex_corners.size()):
		var from: Vector2 = _hex_corners[i]
		var to: Vector2 = _hex_corners[(i + 1) % _hex_corners.size()]
		draw_line(from, to, outline_color, 1.0)
