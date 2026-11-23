extends "res://scenes/enemies/melee_enemy.gd"

signal flame_cast(origin: Vector2, direction: Vector2, damage: int)
signal minions_summoned(origin: Vector2)
signal stage_changed(stage: int)
signal action_started(action: String)

const FLAME_INTERVAL := 6.0
const SUMMON_INTERVAL := 20.0
const CHARGE_INTERVAL := 12.0
const BARRAGE_INTERVAL := 8.0
const WINDUP := 1.0
const CHARGE_DURATION := 0.60
const CHARGE_SPEED := 720.0
const FLAME_COUNT := 5
const FLAME_STEP := PI / 12.0
const FLAME_DAMAGE := 15
const THRESHOLDS := [0.75, 0.50, 0.25]

enum Motion { WALK, WINDUP, CHARGE }

var stage := 1
var period_multiplier := 1.0
var flame_damage := FLAME_DAMAGE
var _flame_left := FLAME_INTERVAL
var _summon_left := 0.0
var _charge_left := 0.0
var _barrage_left := 0.0
var _motion := Motion.WALK
var _motion_left := 0.0
var _charge_direction := Vector2.ZERO
var _charge_hit := false


func _reset_behavior() -> void:
	super._reset_behavior()
	stage = 1
	_flame_left = FLAME_INTERVAL * period_multiplier
	_summon_left = 0.0
	_charge_left = 0.0
	_barrage_left = 0.0
	_motion = Motion.WALK


func take_damage(amount: int, critical := false) -> void:
	super.take_damage(amount, critical)
	while _health > 0 and stage <= THRESHOLDS.size() and float(_health) / max_health <= THRESHOLDS[stage - 1]:
		stage += 1
		_body.boss_stage = stage
		_body.queue_redraw()
		_flame_left /= 1.15
		_attack_left /= 1.15
		stage_changed.emit(stage)


func _contact_interval() -> float:
	return ATTACK_INTERVAL / pow(1.15, stage - 1)


func _move_velocity(delta: float) -> Vector2:
	match _motion:
		Motion.WINDUP: return Vector2.ZERO
		Motion.CHARGE: return _charge_direction * CHARGE_SPEED * speed_multiplier
		_: return super._move_velocity(delta)


func _update_attack(delta: float) -> void:
	if _motion == Motion.WALK:
		super._update_attack(delta)
	elif _motion == Motion.WINDUP:
		_motion_left -= delta
		if _motion_left <= 0.000001:
			_motion = Motion.CHARGE
			_motion_left = CHARGE_DURATION
			_charge_direction = global_position.direction_to(_target.global_position)
			_charge_hit = false
			_body.windup = false
			_body.queue_redraw()
			action_started.emit("魔尊冲锋")
	else:
		var reach := body_radius + Player.BODY_RADIUS + CONTACT_MARGIN
		if not _charge_hit and global_position.distance_squared_to(_target.global_position) <= reach * reach:
			_charge_hit = true
			_target.take_damage(2 * damage, self)
		_motion_left -= delta
		if _motion_left <= 0.000001:
			_motion = Motion.WALK

	if not _target.is_alive():
		return
	_flame_left -= delta
	if _flame_left <= 0.000001:
		_flame_left += FLAME_INTERVAL * period_multiplier / pow(1.15, stage - 1)
		_cast_flames()
	if stage >= 2:
		_summon_left -= delta
		if _summon_left <= 0.000001:
			_summon_left = SUMMON_INTERVAL
			minions_summoned.emit(global_position)
			action_started.emit("魔尊召唤")
	if stage >= 3:
		_charge_left -= delta
		if _charge_left <= 0.000001 and _motion == Motion.WALK:
			_charge_left = CHARGE_INTERVAL
			_motion = Motion.WINDUP
			_motion_left = WINDUP
			_body.windup = true
			_body.queue_redraw()
			action_started.emit("魔尊蓄力 · 冲锋")
	if stage >= 4:
		_barrage_left -= delta
		if _barrage_left <= 0.000001:
			_barrage_left = BARRAGE_INTERVAL
			_cast_flames(FLAME_STEP * 1.4)
			action_started.emit("魔焰弹幕")


func _cast_flames(step := FLAME_STEP) -> void:
	var toward := _target.global_position - global_position
	var angle := toward.angle()
	for i in range(FLAME_COUNT):
		flame_cast.emit(global_position, BattlePlane.direction(angle + (float(i) - 2.0) * step), flame_damage)
