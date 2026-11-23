extends Node2D

signal finished(sword: Node2D)

const Enemy = preload("res://scenes/enemies/enemy.gd")
const Ink = preload("res://scenes/world/ink.gd")
const SPEED := 600.0
const LIFETIME := 3.0

var _direction := Vector2.ZERO
var _time_left := 0.0
var _damage := 0
var _ray := PhysicsRayQueryParameters2D.new()
var _target: Enemy
var _target_generation := 0
var _divine := false


func _ready() -> void:
	_ray.collision_mask = Enemy.ENEMY_LAYER
	_ray.hit_from_inside = true


func launch(at: Vector2, direction: Vector2, damage: int, reach := 1.0, target: Enemy = null) -> void:
	global_position = at
	_direction = direction if direction != Vector2.ZERO else Vector2.RIGHT
	rotation = _direction.angle()
	_time_left = LIFETIME * reach
	_damage = damage
	_target = target
	_target_generation = target.spawn_id if target != null else 0
	var divine := target != null
	if divine != _divine:
		_divine = divine
		queue_redraw()


func _physics_process(delta: float) -> void:
	if is_instance_valid(_target) and _target.spawn_id == _target_generation and _target._health > 0:
		var toward := global_position.direction_to(_target.global_position)
		if toward != Vector2.ZERO:
			_direction = toward
			rotation = toward.angle()
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


func _draw() -> void:
	if _divine:
		draw_line(Vector2(-74, 0), Vector2(14, 0), Color("#f9bd5b54"), 13, true)
		draw_line(Vector2(-60, 0), Vector2(-8, 0), Color("#ffdf888f"), 4, true)
		Ink.sword(self, Vector2.ZERO, Vector2.RIGHT, Color("#ffe38a"), 1.23)
		return
	draw_line(Vector2(-51, 0), Vector2(12, 0), Color("#6ee8e733"), 8, true)
	draw_line(Vector2(-41, 0), Vector2(-7, 0), Color("#92f9e58a"), 2, true)
	Ink.sword(self, Vector2.ZERO, Vector2.RIGHT, Color("#9dfae3"), 0.86)
