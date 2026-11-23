extends Node2D

signal finished(orb: Node2D)

const Player = preload("res://scenes/player.gd")
const SPEED := 150.0
const LIFETIME := 8.0
const HIT_RADIUS := Player.BODY_RADIUS + 9.0
var _target: Player
var _source: Node2D
var _source_id := 0
var _direction := Vector2.ZERO
var _damage := 0
var _time_left := 0.0
var _tint := Color("#e495ef")


func launch(at: Vector2, direction: Vector2, damage: int, target: Player, boss_flame := false, source: Node2D = null) -> void:
	global_position = at
	_direction = direction if direction != Vector2.ZERO else Vector2.RIGHT
	rotation = _direction.angle()
	_damage = damage
	_target = target
	_source = source
	_source_id = source.spawn_id if source != null else 0
	_time_left = LIFETIME
	_tint = Color("#ff9363") if boss_flame else Color("#e495ef")
	queue_redraw()


func _physics_process(delta: float) -> void:
	var start := global_position
	var end := start + _direction * SPEED * minf(delta, _time_left)
	# 法球按发射时的方向直飞，只检测玩家，不会打到别的敌人。
	var closest := Geometry2D.get_closest_point_to_segment(_target.global_position, start, end)
	if closest.distance_squared_to(_target.global_position) <= HIT_RADIUS * HIT_RADIUS:
		var source := _source if is_instance_valid(_source) and _source.spawn_id == _source_id else null
		_target.take_damage(_damage, source)
		_finish()
		return

	global_position = end
	_time_left -= delta
	if _time_left <= 0.0:
		_finish()


func _finish() -> void:
	_target = null
	_source = null
	finished.emit(self)


func _draw() -> void:
	draw_line(Vector2(-19, 0), Vector2.ZERO, Color(_tint, 0.28), 7, true)
	draw_circle(Vector2.ZERO, 11.0, Color(_tint, 0.22), true, -1, true)
	draw_circle(Vector2.ZERO, 6.5, _tint, true, -1, true)
	draw_circle(Vector2(1, -1), 2.5, Color("#fff1db"), true, -1, true)
