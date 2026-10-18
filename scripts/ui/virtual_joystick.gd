class_name VirtualJoystick
extends Control
## Multi-touch-safe analog movement stick. Other touches remain free for attack/special.

signal direction_changed(direction: Vector2)

@export_range(0.0, 0.8, 0.01) var dead_zone := 0.18
@export_range(36.0, 120.0, 1.0) var max_radius := 68.0

var direction := Vector2.ZERO
var _pointer_id := -1
var _mouse_active := false
var _center := Vector2.ZERO
var _knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_recenter)
	_recenter()
	queue_redraw()


func _recenter() -> void:
	_center = size * 0.5
	if _pointer_id < 0 and not _mouse_active:
		_knob = _center
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _pointer_id < 0:
			_pointer_id = event.index
			_update_from_position(event.position)
			accept_event()
		elif not event.pressed and event.index == _pointer_id:
			_pointer_id = -1
			_release()
			accept_event()
	elif event is InputEventScreenDrag and event.index == _pointer_id:
		_update_from_position(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_active = event.pressed
		if _mouse_active:
			_update_from_position(event.position)
		else:
			_release()
		accept_event()
	elif event is InputEventMouseMotion and _mouse_active:
		_update_from_position(event.position)
		accept_event()


func _update_from_position(local_pos: Vector2) -> void:
	var offset := local_pos - _center
	var radius := minf(max_radius, minf(size.x, size.y) * 0.42)
	if radius <= 1.0:
		_release()
		return
	var length_ratio := clampf(offset.length() / radius, 0.0, 1.0)
	_knob = _center + offset.limit_length(radius)
	if length_ratio <= dead_zone:
		_set_direction(Vector2.ZERO)
	else:
		var strength := (length_ratio - dead_zone) / maxf(0.001, 1.0 - dead_zone)
		_set_direction(offset.normalized() * strength)
	queue_redraw()


func _release() -> void:
	_knob = _center
	_set_direction(Vector2.ZERO)
	queue_redraw()


func _set_direction(value: Vector2) -> void:
	var next := value.limit_length(1.0)
	if next.is_equal_approx(direction):
		return
	direction = next
	direction_changed.emit(direction)


func _draw() -> void:
	var radius := minf(max_radius, minf(size.x, size.y) * 0.42)
	draw_circle(_center, radius, Color(0.08, 0.08, 0.1, 0.62))
	draw_circle(_center, radius * 0.72, Color(0.25, 0.22, 0.18, 0.34))
	draw_arc(_center, radius, 0.0, TAU, 48, Color(0.86, 0.68, 0.34, 0.66), 3.0, true)
	draw_circle(_knob, radius * 0.37, Color(0.82, 0.69, 0.48, 0.88))
	draw_arc(_knob, radius * 0.37, 0.0, TAU, 36, Color(1.0, 0.9, 0.68, 0.92), 2.0, true)
