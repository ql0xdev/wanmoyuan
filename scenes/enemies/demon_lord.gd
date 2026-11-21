extends "res://scenes/enemies/melee_enemy.gd"

signal flame_cast(origin: Vector3, direction: Vector3, damage: int)
signal wolves_summoned(origin: Vector3)

const FLAME_INTERVAL := 6.0
const SUMMON_INTERVAL := 15.0
const FLAME_COUNT := 5
const FLAME_STEP := PI / 12.0
const FLAME_DAMAGE := 15

var _flame_left := FLAME_INTERVAL
var _summon_left := SUMMON_INTERVAL
var period_multiplier := 1.0
var flame_damage := FLAME_DAMAGE


func _reset_behavior() -> void:
	super._reset_behavior()
	_flame_left = FLAME_INTERVAL * period_multiplier
	_summon_left = SUMMON_INTERVAL * period_multiplier


func _update_attack(delta: float) -> void:
	super._update_attack(delta)
	if not _target.is_alive():
		return
	_flame_left -= delta
	if _flame_left <= 0.000001:
		_flame_left += FLAME_INTERVAL * period_multiplier
		_cast_flames()
	_summon_left -= delta
	if _summon_left <= 0.000001:
		_summon_left += SUMMON_INTERVAL * period_multiplier
		wolves_summoned.emit(global_position)


func _cast_flames() -> void:
	# 以玩家方向为扇形中轴，五颗法球均匀展开。
	var toward := _target.global_position - global_position
	var angle := atan2(toward.z, toward.x)
	for i in range(FLAME_COUNT):
		var direction := BattlePlane.direction(angle + (float(i) - 2.0) * FLAME_STEP)
		flame_cast.emit(global_position, direction, flame_damage)
