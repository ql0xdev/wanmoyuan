extends Camera2D

const FOLLOW_SPEED := 7.0
const VIEW_WIDTH := 1122.1
const VIEW_ZOOM := 720.0 / VIEW_WIDTH
const Look = preload("res://scenes/ui/ui_look.gd")

var focus := Vector2.ZERO
var _framing := Vector2.ZERO
var _shake := Vector2.ZERO
var _shake_tween: Tween


func _ready() -> void:
	zoom = Vector2.ONE * VIEW_ZOOM
	get_viewport().size_changed.connect(_refresh_framing)
	_refresh_framing()


func _refresh_framing() -> void:
	_framing = Vector2.UP * get_viewport_rect().size.y * 0.12 / VIEW_ZOOM
	offset = _framing + _shake
	force_update_scroll()


func snap_to(target: Vector2) -> void:
	focus = target
	global_position = focus
	force_update_scroll()


func follow(target: Vector2, delta: float) -> void:
	snap_to(focus.lerp(target, minf(delta * FOLLOW_SPEED, 1.0)))


func shake_view() -> void:
	if _shake_tween != null:
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.tween_method(_apply_view_shake, 0.0, 1.0, 0.30)


func _apply_view_shake(progress: float) -> void:
	_shake = Look.shake_offset(progress, 24.0)
	offset = _framing + _shake
	force_update_scroll()


func screen_at(world_point: Vector2) -> Vector2:
	return get_canvas_transform() * world_point


func ground_at(screen_point: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_point


func world_view() -> Rect2:
	var view := get_viewport_rect()
	var start := ground_at(view.position)
	return Rect2(start, ground_at(view.end) - start)
