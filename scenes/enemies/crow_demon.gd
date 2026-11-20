extends "res://scenes/enemies/enemy.gd"

signal orb_cast(origin: Vector2, direction: Vector2, damage: int)

const PREFERRED_DISTANCE := 300.0
const CAST_INTERVAL := 3.0

var _cast_left := CAST_INTERVAL


func _reset_behavior() -> void:
	_cast_left = CAST_INTERVAL


func _move_velocity(delta: float) -> Vector2:
	# 离得太远就靠近，太近就后撤，抵达 300 像素后停住。
	var offset := _target.global_position - global_position
	var distance := offset.length()
	var toward := offset / distance if distance > 0.0 else Vector2.RIGHT
	var speed := move_speed * speed_multiplier
	return toward * clampf((distance - PREFERRED_DISTANCE) / delta, -speed, speed)


func _update_attack(delta: float) -> void:
	_cast_left -= delta
	if _cast_left <= 0.000001:
		_cast_left += CAST_INTERVAL
		orb_cast.emit(global_position, global_position.direction_to(_target.global_position), damage)
