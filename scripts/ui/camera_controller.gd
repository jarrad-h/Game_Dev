extends Camera2D
## Camera with pan (WASD/arrow keys/middle-mouse drag) and zoom (scroll wheel).

const PAN_SPEED: float = 500.0
const ZOOM_MIN: float = 0.3
const ZOOM_MAX: float = 2.0
const ZOOM_STEP: float = 0.1

var _is_dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO

func _ready() -> void:
	zoom = Vector2(0.8, 0.8)

func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_action_pressed("ui_left"):
		move.x -= 1
	if Input.is_action_pressed("ui_right"):
		move.x += 1
	if Input.is_action_pressed("ui_up"):
		move.y -= 1
	if Input.is_action_pressed("ui_down"):
		move.y += 1

	# WASD
	if Input.is_key_pressed(KEY_A):
		move.x -= 1
	if Input.is_key_pressed(KEY_D):
		move.x += 1
	if Input.is_key_pressed(KEY_W):
		move.y -= 1
	if Input.is_key_pressed(KEY_S):
		move.y += 1

	if move != Vector2.ZERO:
		position += move.normalized() * PAN_SPEED * delta / zoom.x

func _unhandled_input(event: InputEvent) -> void:
	# Zoom with scroll wheel
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, -ZOOM_STEP)
		# Middle mouse drag
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_dragging = event.pressed
			if event.pressed:
				_drag_start = event.position
	elif event is InputEventMouseMotion and _is_dragging:
		position -= (event.relative / zoom.x)

func _zoom_at(mouse_pos: Vector2, step: float) -> void:
	var old_zoom := zoom
	var new_zoom_val: float = clampf(zoom.x + step, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(new_zoom_val, new_zoom_val)
	# Adjust position to zoom toward mouse
	var viewport_size: Vector2 = get_viewport_rect().size
	var mouse_offset: Vector2 = (mouse_pos - viewport_size / 2.0)
	position += mouse_offset * (1.0 / old_zoom.x - 1.0 / zoom.x)
