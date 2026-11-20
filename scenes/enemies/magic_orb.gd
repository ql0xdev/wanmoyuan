extends Node2D

signal finished(orb: Node2D)

const Player = preload("res://scenes/player.gd")
const SPEED := 150.0
const LIFETIME := 8.0
const HIT_RADIUS := Player.BODY_RADIUS + 9.0
const DEFAULT_TINT := Color("#eb87ed")

@onready var _body: Polygon2D = $Orb
var _target: Player
var _direction := Vector2.ZERO
var _damage := 0
var _time_left := 0.0


func launch(at: Vector2, direction: Vector2, damage: int, target: Player, tint := DEFAULT_TINT) -> void:
	global_position = at
	_direction = direction if direction != Vector2.ZERO else Vector2.RIGHT
	_damage = damage
	_target = target
	_time_left = LIFETIME
	_body.color = tint


func _physics_process(delta: float) -> void:
	var start := global_position
	var end := start + _direction * SPEED * minf(delta, _time_left)
	# 法球按发射时的方向直飞，只检测玩家，不会打到别的敌人。
	var closest := Geometry2D.get_closest_point_to_segment(_target.global_position, start, end)
	if closest.distance_squared_to(_target.global_position) <= HIT_RADIUS * HIT_RADIUS:
		_target.take_damage(_damage)
		_finish()
		return

	global_position = end
	_time_left -= delta
	if _time_left <= 0.0:
		_finish()


func _finish() -> void:
	_target = null
	finished.emit(self)
