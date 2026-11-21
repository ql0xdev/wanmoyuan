extends CharacterBody2D

const StatsManager = preload("res://scripts/stats_manager.gd")

signal health_changed(current: int, maximum: int)
signal hit
signal died

const BODY_RADIUS := 16.0
const INVULNERABILITY := 0.5
const FLASH_INTERVAL := 0.08
const HIT_TINT := Color(1.0, 0.26, 0.22, 0.55)

@onready var _body: Polygon2D = $Body

var stats := StatsManager.new()
var _base_max_health := StatsManager.BASE_HEALTH
var max_health := StatsManager.BASE_HEALTH
var health := max_health
var accepts_damage := true
var _invulnerable_left := 0.0
var _speed_boost_left := 0.0
var _joystick_direction := Vector2.ZERO


func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	if _invulnerable_left > 0.0:
		_update_hit_flash(delta)
	_speed_boost_left = maxf(0.0, _speed_boost_left - delta)

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _joystick_direction != Vector2.ZERO:
		direction = _joystick_direction

	# 两种输入共用同一移动逻辑，斜向不加速，松手即停。
	velocity = direction * stats.move_speed(_speed_boost_left > 0.0)
	move_and_slide()


func _on_joystick_direction_changed(direction: Vector2) -> void:
	_joystick_direction = direction


func is_alive() -> bool:
	return health > 0


func take_damage(amount: int) -> void:
	if not accepts_damage or not is_alive() or amount <= 0 or _invulnerable_left > 0.0:
		return
	health = maxi(0, health - stats.incoming_damage(amount))
	health_changed.emit(health, max_health)
	hit.emit()
	if is_alive():
		_speed_boost_left = stats.hit_speed_duration
		_invulnerable_left = INVULNERABILITY
		_body.modulate = HIT_TINT
	else:
		velocity = Vector2.ZERO
		_body.modulate = Color(0.50, 0.20, 0.18)
		died.emit()


func _update_hit_flash(delta: float) -> void:
	# 无敌与闪烁共用战斗时间；升级暂停不消耗无敌时间。
	_invulnerable_left = maxf(0.0, _invulnerable_left - delta)
	if is_zero_approx(_invulnerable_left):
		_invulnerable_left = 0.0
		_body.modulate = Color.WHITE
		return
	var phase := floori((INVULNERABILITY - _invulnerable_left) / FLASH_INTERVAL)
	_body.modulate = HIT_TINT if phase % 2 == 0 else Color.WHITE


func heal(amount: int) -> void:
	if is_alive() and amount > 0 and health < max_health:
		health = mini(health + amount, max_health)
		health_changed.emit(health, max_health)


func increase_max_health(amount: int) -> void:
	_base_max_health += amount
	refresh_equipment()


func refresh_equipment(heal_on_buy := 0) -> void:
	max_health = _base_max_health + stats.max_health_bonus
	if is_alive():
		health = mini(health + heal_on_buy, max_health)
	health_changed.emit(health, max_health)
