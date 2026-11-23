extends CharacterBody2D

const StatsManager = preload("res://scripts/stats_manager.gd")
const BattlePlane = preload("res://scripts/battle_plane.gd")
const ActorArt = preload("res://scenes/world/actor_art.gd")
const Ink = preload("res://scenes/world/ink.gd")

signal health_changed(current: int, maximum: int)
signal hit
signal died
signal dashed(from: Vector2, to: Vector2)
signal shield_changed(amount: int)

const BODY_RADIUS := 16.0
const INVULNERABILITY := 0.5
const FLASH_INTERVAL := 0.08
const DEATH_TINT := Color("#562a26")

@onready var _body: ActorArt = $Body
var _stride := 0.0

var stats := StatsManager.new()
var max_health := StatsManager.BASE_HEALTH
var health := max_health
var accepts_damage := true
var _invulnerable_left := 0.0
var _joystick_direction := Vector2.ZERO
var _last_direction := Vector2.RIGHT
var _dash_left := 0.0
var _dash_velocity := Vector2.ZERO
var _dash_invincible := false
var _dash_original_mask := 0
var shield := 0
var _shield_left := 0.0
var _shield_heal := 0.0
var _shield_tick := 0.0
var guard_mitigation := 0.0
var guard_reflection := 0.0
var hit_heal := 0.0


func _ready() -> void:
	_body.radius = 25.0
	_body.tint = Ink.JADE
	collision_mask |= BattlePlane.OBSTACLE_LAYER


func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	if _invulnerable_left > 0.0:
		_update_hit_flash(delta)
	_update_shield(delta)

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _joystick_direction != Vector2.ZERO:
		direction = _joystick_direction
	if direction != Vector2.ZERO:
		_last_direction = direction.normalized()

	# 两种输入共用同一移动逻辑，斜向不加速，松手即停。
	if _dash_left > 0.0:
		var start := global_position
		velocity = _dash_velocity * (minf(delta, _dash_left) / delta)
		move_and_slide()
		dashed.emit(start, global_position)
		_dash_left -= delta
		if _dash_left <= 0.000001:
			_dash_left = 0.0
			collision_mask = _dash_original_mask
		return
	velocity = direction * stats.move_speed()
	move_and_slide()


func _process(delta: float) -> void:
	if not is_alive():
		return
	var moving := velocity.length_squared() > 1.0
	_stride += delta * (15.0 if moving else 7.0)
	_body.facing = _last_direction
	var stretch := sin(_stride) * (0.060 if moving else 0.018)
	_body.scale = Vector2(1.0 + stretch, 1.0 - stretch * 0.65)
	_body.queue_redraw()


func begin_dash(distance: float, duration: float, invincible: bool) -> bool:
	if _dash_left > 0.0:
		return false
	_dash_original_mask = collision_mask
	collision_mask &= ~2  # 穿怪不穿地形。
	_dash_left = duration
	_dash_velocity = _last_direction * (distance / duration)
	_dash_invincible = invincible
	return true


func grant_shield(amount: int, duration: float, heal_fraction: float) -> void:
	shield = amount
	_shield_left = duration
	_shield_heal = heal_fraction
	_shield_tick = 1.0
	shield_changed.emit(shield)


func clear_shield() -> void:
	shield = 0
	_shield_left = 0.0
	shield_changed.emit(shield)


func _update_shield(delta: float) -> void:
	if shield <= 0:
		return
	_shield_tick -= minf(delta, _shield_left)
	_shield_left -= delta
	if _shield_tick <= 0.000001:
		_shield_tick += 1.0
		heal(roundi(max_health * _shield_heal))
	if _shield_left <= 0.000001:
		shield = 0
		shield_changed.emit(shield)


func _on_joystick_direction_changed(direction: Vector2) -> void:
	_joystick_direction = direction


func is_alive() -> bool:
	return health > 0


func take_damage(amount: int, source: Node2D = null) -> void:
	if not accepts_damage or not is_alive() or amount <= 0 or _invulnerable_left > 0.0 or (_dash_left > 0.0 and _dash_invincible):
		return
	var damage := maxi(1, roundi(stats.incoming_damage(amount) * (1.0 - guard_mitigation)))
	if guard_reflection > 0.0 and is_instance_valid(source):
		source.call_deferred("reflect_damage", roundi(amount * guard_reflection), source.spawn_id)
	if shield > 0:
		var blocked := mini(damage, shield)
		shield -= blocked
		damage -= blocked
		shield_changed.emit(shield)
	health = maxi(0, health - damage)
	if health > 0 and hit_heal > 0.0:
		health = mini(max_health, health + roundi(max_health * hit_heal))
	health_changed.emit(health, max_health)
	hit.emit()
	if is_alive():
		_invulnerable_left = INVULNERABILITY
		_body.hit_white = true
	else:
		velocity = Vector2.ZERO
		_body.hit_white = false
		_body.tint = DEATH_TINT
	_body.queue_redraw()
	if not is_alive():
		died.emit()


func _update_hit_flash(delta: float) -> void:
	# 无敌与闪烁共用战斗时间；升级暂停不消耗无敌时间。
	_invulnerable_left = maxf(0.0, _invulnerable_left - delta)
	if is_zero_approx(_invulnerable_left):
		_invulnerable_left = 0.0
		_body.hit_white = false
		return
	var phase := floori((INVULNERABILITY - _invulnerable_left) / FLASH_INTERVAL)
	_body.hit_white = phase % 2 == 0


func heal(amount: int) -> void:
	if is_alive() and amount > 0 and health < max_health:
		health = mini(health + amount, max_health)
		health_changed.emit(health, max_health)


func refresh_equipment(refill := false) -> void:
	max_health = stats.max_health()
	if is_alive():
		health = max_health if refill else mini(health, max_health)
	health_changed.emit(health, max_health)


func blink(distance: float) -> bool:
	var collider: CollisionShape2D = $CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collider.shape
	query.collision_mask = BattlePlane.OBSTACLE_LAYER | 2
	query.exclude = [get_rid()]
	var space := get_world_2d().direct_space_state
	var angle := randf() * TAU
	for i in range(12):
		var destination := global_position + BattlePlane.direction(angle + TAU * i / 12.0) * distance
		query.transform = Transform2D(collider.global_rotation, destination + collider.position)
		if space.intersect_shape(query, 1).is_empty():
			global_position = destination
			velocity = Vector2.ZERO
			reset_physics_interpolation()
			return true
	return false
