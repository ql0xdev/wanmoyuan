extends Node2D

signal finished(sword: Node2D)

const Enemy = preload("res://scenes/enemies/enemy.gd")
const SPEED := 600.0
const LIFETIME := 3.0

var _direction := Vector2.ZERO
var _time_left := 0.0
var _damage := 0
var _ray := PhysicsRayQueryParameters2D.new()


func _ready() -> void:
	_ray.collision_mask = Enemy.ENEMY_LAYER
	_ray.hit_from_inside = true


func launch(at: Vector2, direction: Vector2, damage: int) -> void:
	global_position = at
	_direction = direction if direction != Vector2.ZERO else Vector2.RIGHT
	rotation = _direction.angle()
	_time_left = LIFETIME
	_damage = damage


func _physics_process(delta: float) -> void:
	var step := minf(delta, _time_left)
	_ray.from = global_position
	_ray.to = global_position + _direction * SPEED * step
	# 检测飞剑尖端本帧扫过的线段，只命中第一只活着的敌人。
	var hit := get_world_2d().direct_space_state.intersect_ray(_ray)
	if not hit.is_empty():
		var enemy := hit.collider as Enemy
		enemy.take_damage(_damage)
		finished.emit(self)
		return

	global_position = _ray.to
	_time_left -= delta
	if _time_left <= 0.0:
		finished.emit(self)
