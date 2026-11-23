extends Node3D

signal finished(sword: Node3D)

const Enemy = preload("res://scenes/enemies/enemy.gd")
const SPEED := 600.0
const LIFETIME := 3.0

var _direction := Vector3.ZERO
var _time_left := 0.0
var _damage := 0
var _ray := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_ray.collision_mask = Enemy.ENEMY_LAYER
	_ray.hit_from_inside = true


func launch(at: Vector3, direction: Vector3, damage: int, reach := 1.0) -> void:
	global_position = at
	_direction = direction if direction != Vector3.ZERO else Vector3.RIGHT
	look_at(at + _direction)
	_time_left = LIFETIME * reach
	_damage = damage


func _physics_process(delta: float) -> void:
	var step := minf(delta, _time_left)
	_ray.from = global_position
	_ray.to = global_position + _direction * SPEED * step
	# 检测飞剑尖端本帧扫过的线段，只命中第一只活着的敌人。
	var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
	if not hit.is_empty():
		var enemy := hit.collider as Enemy
		enemy.take_damage(_damage)
		finished.emit(self)
		return

	global_position = _ray.to
	_time_left -= delta
	if _time_left <= 0.0:
		finished.emit(self)
