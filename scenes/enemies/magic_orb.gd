extends Node3D

signal finished(orb: Node3D)

const Player = preload("res://scenes/player.gd")
const SPEED := 150.0
const LIFETIME := 8.0
const HIT_RADIUS := Player.BODY_RADIUS + 9.0
const FLAME_MATERIAL := preload("res://scenes/world/boss_flame_material.tres")

@onready var _body: MeshInstance3D = $Orb
@onready var _base_material := _body.material_override
var _target: Player
var _direction := Vector3.ZERO
var _damage := 0
var _time_left := 0.0


func launch(at: Vector3, direction: Vector3, damage: int, target: Player, boss_flame := false) -> void:
	global_position = at
	_direction = direction if direction != Vector3.ZERO else Vector3.RIGHT
	_damage = damage
	_target = target
	_time_left = LIFETIME
	_body.material_override = FLAME_MATERIAL if boss_flame else _base_material


func _physics_process(delta: float) -> void:
	var start := global_position
	var end := start + _direction * SPEED * minf(delta, _time_left)
	# 法球按发射时的方向直飞，只检测玩家，不会打到别的敌人。
	var closest := Geometry3D.get_closest_point_to_segment(_target.global_position, start, end)
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
