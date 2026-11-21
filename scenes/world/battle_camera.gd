extends Camera3D

const FOLLOW_SPEED := 7.0
const FOLLOW_OFFSET := Vector3(0.0, 935.0, 935.0)
const GROUND := Plane(Vector3.UP, 0.0)
const VIEW_FRAMING := 1.0 / 3.0
const Look = preload("res://scenes/ui/ui_look.gd")

@onready var presentation: Camera3D = $Presentation
var focus := Vector3.ZERO
var _view_offset := 0.0
var _shake_tween: Tween


func _ready() -> void:
	# 渲染构图不参与刷怪或落雷的投影；这两个系统仍使用父镜头。
	_view_offset = FOLLOW_OFFSET.length() * tan(deg_to_rad(presentation.fov * 0.5)) * VIEW_FRAMING
	presentation.v_offset = _view_offset


func snap_to(target: Vector3) -> void:
	focus = target
	global_position = focus + FOLLOW_OFFSET


func follow(target: Vector3, delta: float) -> void:
	snap_to(focus.lerp(target, minf(delta * FOLLOW_SPEED, 1.0)))


func shake_view() -> void:
	if _shake_tween != null:
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.tween_method(_apply_view_shake, 0.0, 1.0, 0.30)


func _apply_view_shake(progress: float) -> void:
	var offset := Look.shake_offset(progress, 12.0)
	presentation.h_offset = offset.x
	presentation.v_offset = _view_offset + offset.y


func ground_at(screen: Vector2) -> Vector3:
	var ray_origin := project_ray_origin(screen)
	var ray_direction := project_ray_normal(screen)
	var hit: Variant = GROUND.intersects_ray(ray_origin, ray_direction)
	if hit is Vector3:
		# 不依赖浮点求交返回的 y 值，战斗实体都严格留在同一平面。
		return Vector3(hit.x, 0.0, hit.z)
	# 极端窗口尺寸下若射线越过地平线，仍落到镜头前方地面。
	return focus + Vector3(ray_direction.x, 0.0, ray_direction.z).normalized() * far * 0.5
