extends Node2D

const Player = preload("res://scenes/player.gd")

signal collected(pickup: Node2D)

const PICKUP_RADIUS := 16.0
const MAGNET_DURATION := 0.35

var amount := 1
var _target: Player
var _drop_position := Vector2.ZERO
var _magnet_elapsed := 0.0
var _magnet_active := false


func drop(at: Vector2, target: Player, value := 1) -> void:
	global_position = at
	amount = value
	_target = target
	_drop_position = at
	_magnet_elapsed = 0.0
	_magnet_active = false


func _physics_process(delta: float) -> void:
	if _target == null:
		return

	var target_position := _target.global_position
	if not _magnet_active:
		# 触发磁吸前始终停在掉落点，不随玩家移动，也不按掉落时长触发。
		var radius := _target.stats.magnet_radius
		if _drop_position.distance_squared_to(target_position) > radius * radius:
			return
		_magnet_active = true

	_magnet_elapsed = minf(_magnet_elapsed + delta, MAGNET_DURATION)
	var progress := _magnet_elapsed / MAGNET_DURATION
	global_position = _drop_position.lerp(target_position, progress * progress)
	if global_position.distance_squared_to(target_position) <= PICKUP_RADIUS * PICKUP_RADIUS:
		_target = null
		collected.emit(self)
