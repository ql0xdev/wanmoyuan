extends Control

signal direction_changed(direction: Vector2)

const BASE_RADIUS := 48.0
const KNOB_RADIUS := 18.0
const DEADZONE := 8.0

var _finger_index := -1
var _touch_origin := Vector2.ZERO
var _knob_offset := Vector2.ZERO
var _direction := Vector2.ZERO


func _ready() -> void:
	resized.connect(queue_redraw)
	set_notify_transform(true)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.index == _finger_index and (not event.pressed or event.canceled):
			reset()
		elif _finger_index == -1 and event.pressed and not event.canceled:
			if not get_viewport().get_visible_rect().has_point(event.position):
				return
			# 整个战斗画面都能唤出摇杆，只跟踪第一个按下的手指。
			_finger_index = event.index
			_touch_origin = event.position
			queue_redraw()
		else:
			return
	elif event is InputEventScreenDrag and event.index == _finger_index:
		var to_local := get_global_transform_with_canvas().affine_inverse()
		var offset := to_local.basis_xform(event.position - _touch_origin)
		_knob_offset = offset.limit_length(BASE_RADIUS - KNOB_RADIUS)
		var direction := Vector2.ZERO
		if offset.length_squared() > DEADZONE * DEADZONE:
			direction = offset.normalized()
		_set_direction(direction)
		queue_redraw()
	else:
		return

	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		reset()
	elif what == NOTIFICATION_TRANSFORM_CHANGED and _finger_index != -1:
		queue_redraw()


func _set_direction(direction: Vector2) -> void:
	if _direction != direction:
		_direction = direction
		direction_changed.emit(_direction)


func reset() -> void:
	if _finger_index == -1:
		return
	_finger_index = -1
	_knob_offset = Vector2.ZERO
	_set_direction(Vector2.ZERO)
	queue_redraw()


func _draw() -> void:
	if _finger_index != -1:
		var center := _display_center()
		draw_circle(center, BASE_RADIUS, Color(0.6, 0.85, 0.78, 0.22), true, -1.0, true)
		draw_circle(center + _knob_offset, KNOB_RADIUS, Color(0.7, 0.95, 0.87, 0.7), true, -1.0, true)


func _display_center() -> Vector2:
	# 只移动显示的圆盘，拖动仍相对于真正的按下位置计算。
	var origin := get_global_transform_with_canvas().affine_inverse() * _touch_origin
	var inset := Vector2.ONE * (BASE_RADIUS + 1.0)
	return origin.clamp(inset, size - inset)
