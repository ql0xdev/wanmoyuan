extends "res://scenes/enemies/melee_enemy.gd"

const HazardArt = preload("res://scenes/enemies/boss_hazard_art.gd")

signal flame_cast(origin: Vector2, direction: Vector2, damage: int)
signal minions_summoned(origin: Vector2)
signal stage_changed(stage: int)
signal action_started(action: String)

const FLAME_INTERVAL := 6.0
const SUMMON_INTERVAL := 20.0
const CHARGE_INTERVAL := 12.0
const BARRAGE_INTERVAL := 8.0
const WINDUP := 1.0
const CHARGE_DURATION := 0.72
const CHARGE_SPEED := 720.0
const CHARGE_EXTRA_REACH := 10.0
const FLAME_COUNT := 5
const FLAME_STEP := PI / 10.0
const BARRAGE_COUNT := 7
const FLAME_DAMAGE := 15
const QUAKE_DELAY := 1.3
const QUAKE_RADIUS := 230.0
const QUAKE_INTERVAL := 12.0
const METEOR_DELAY := 1.25
const METEOR_RADIUS := 95.0
const METEOR_SPACING := 155.0
const METEOR_INTERVAL := 14.0
const HAZARD_FLASH := 0.26
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
var _quake_left := 4.0
var _meteor_left := 6.0
var _hazard_left := 0.0
var _hazard_duration := 0.0
var _hazard_radius := 0.0
var _hazard_centers := PackedVector2Array()
var _hazard_color := Color.WHITE
var _hazard_damage := 0
var _impact_left := 0.0

@onready var _danger: HazardArt = $Danger


func _reset_behavior() -> void:
	super._reset_behavior()
	stage = 1
	_flame_left = FLAME_INTERVAL * period_multiplier
	_summon_left = 0.0
	_charge_left = 0.0
	_barrage_left = 0.0
	_motion = Motion.WALK
	_quake_left = 4.0
	_meteor_left = 6.0
	_charge_direction = Vector2.ZERO
	_danger.charge(Vector2.ZERO, 0.0, 0.0)
	_clear_hazard()


func take_damage(amount: int, critical := false) -> void:
	super.take_damage(amount, critical)
	if _health <= 0:
		_clear_hazard()
		_danger.charge(Vector2.ZERO, 0.0, 0.0)
		return
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
			_charge_hit = false
			_danger.charge(Vector2.ZERO, 0.0, 0.0)
			_body.windup = false
			_body.queue_redraw()
			action_started.emit("魔尊冲锋")
	else:
		var reach := _charge_reach()
		if not _charge_hit and global_position.distance_squared_to(_target.global_position) <= reach * reach:
			_charge_hit = true
			_target.take_damage(2 * damage, self)
		_motion_left -= delta
		if _motion_left <= 0.000001:
			_motion = Motion.WALK

	if not _target.is_alive():
		return
	_update_hazard(delta)
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
		if _charge_left <= 0.000001 and _motion == Motion.WALK and _hazard_left <= 0.0:
			_charge_left = CHARGE_INTERVAL
			_motion = Motion.WINDUP
			_motion_left = WINDUP
			_charge_direction = global_position.direction_to(_target.global_position)
			if _charge_direction == Vector2.ZERO:
				_charge_direction = Vector2.RIGHT
			_danger.charge(_charge_direction, CHARGE_SPEED * CHARGE_DURATION + _charge_reach(), _charge_reach())
			_body.windup = true
			_body.queue_redraw()
			action_started.emit("魔尊蓄力 · 冲锋")
	if stage >= 4:
		_barrage_left -= delta
		if _barrage_left <= 0.000001:
			_barrage_left = BARRAGE_INTERVAL
			_cast_flames(FLAME_STEP * 1.25, BARRAGE_COUNT)
			action_started.emit("魔焰弹幕")
	if stage >= 2:
		_quake_left -= delta
	if stage >= 4:
		_meteor_left -= delta
	if _motion != Motion.WALK or _hazard_left > 0.0:
		return
	if stage >= 4 and _meteor_left <= 0.0:
		_meteor_left = METEOR_INTERVAL
		_warn_meteors()
	elif stage >= 2 and _quake_left <= 0.0:
		_quake_left = QUAKE_INTERVAL
		_warn_quake()


func _charge_reach() -> float:
	return body_radius + Player.BODY_RADIUS + CONTACT_MARGIN + CHARGE_EXTRA_REACH


func _warn_quake() -> void:
	_warn_hazard(PackedVector2Array([global_position]), QUAKE_RADIUS, QUAKE_DELAY, damage, Color("#ff804f"))
	action_started.emit("裂地震荡 · 离开红圈")


func _warn_meteors() -> void:
	var target := _target.global_position
	var axis := global_position.direction_to(target)
	if axis == Vector2.ZERO:
		axis = Vector2.RIGHT
	var side := Vector2(-axis.y, axis.x) * METEOR_SPACING
	_warn_hazard(PackedVector2Array([target - side, target, target + side]), METEOR_RADIUS, METEOR_DELAY, roundi(damage * 1.2), Color("#e778b9"))
	action_started.emit("天魔陨火 · 躲开落点")


func _warn_hazard(centers: PackedVector2Array, radius: float, duration: float, amount: int, color: Color) -> void:
	_hazard_centers = centers
	_hazard_radius = radius
	_hazard_left = duration
	_hazard_duration = duration
	_hazard_damage = amount
	_hazard_color = color
	_impact_left = 0.0
	_danger.warn(centers, radius, 0.0, color)


func _update_hazard(delta: float) -> void:
	if _hazard_left > 0.0:
		_hazard_left = maxf(0.0, _hazard_left - delta)
		if _hazard_left > 0.000001:
			_danger.warn(_hazard_centers, _hazard_radius, 1.0 - _hazard_left / _hazard_duration, _hazard_color)
			return
		_hazard_left = 0.0
		var radius_squared := _hazard_radius * _hazard_radius
		for center in _hazard_centers:
			if center.distance_squared_to(_target.global_position) <= radius_squared:
				_target.take_damage(_hazard_damage, self)
				break # 多个落点重叠时也只算一次。
		_impact_left = HAZARD_FLASH
		_danger.flash(1.0)
	elif _impact_left > 0.0:
		_impact_left = maxf(0.0, _impact_left - delta)
		if _impact_left > 0.0:
			_danger.flash(_impact_left / HAZARD_FLASH)
		else:
			_danger.clear_circles()


func _clear_hazard() -> void:
	_hazard_left = 0.0
	_impact_left = 0.0
	_hazard_centers = PackedVector2Array()
	_danger.clear_circles()


func _cast_flames(step := FLAME_STEP, count := FLAME_COUNT) -> void:
	var toward := _target.global_position - global_position
	var angle := toward.angle()
	for i in range(count):
		flame_cast.emit(global_position, BattlePlane.direction(angle + (float(i) - (count - 1) * 0.5) * step), flame_damage)
