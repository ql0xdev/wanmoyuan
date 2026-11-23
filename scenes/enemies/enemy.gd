extends CharacterBody2D

const Player = preload("res://scenes/player.gd")
const BattlePlane = preload("res://scripts/battle_plane.gd")
const ActorArt = preload("res://scenes/world/actor_art.gd")

signal died(enemy: CharacterBody2D)
signal death_finished(enemy: CharacterBody2D)
signal health_changed(current: int)
signal damaged(at: Vector2, amount: int, critical: bool)
signal death_burst(at: Vector2, radius: float, tint: Color)

const PLAYER_LAYER := 1
const ENEMY_LAYER := 2
const DEATH_DURATION := 0.20

@export var max_health := 20
@export var move_speed := 120.0
@export var damage := 10
@export var body_radius := 16.0
@export var crystal_count := 1
@export var stone_drop_amount := 0
@export_range(0.0, 1.0) var stone_drop_chance := 1.0
@export var equipment_count := 1
@export_range(0.0, 1.0) var equipment_chance := 0.01
@export_range(0.0, 1.0) var purple_chance := 0.03

@onready var _body: ActorArt = $Body

var speed_multiplier := 1.0
var spawn_id := 0
var _slow_left := 0.0
var _slow_factor := 1.0
var _frozen_left := 0.0
var _shock_left := 0.0
var _shock_amp := 0.0
var _dots := {}
var _health := 0
var _target: Player
var _hit_motion: Tween
var _art_clock := 0.0
var _art_kind := ActorArt.Kind.WOLF


func apply_difficulty(health_multiplier: float, damage_multiplier: float, size_multiplier: float,
		tint: Color, shape_cache: Dictionary) -> void:
	max_health = roundi(max_health * health_multiplier)
	damage = roundi(damage * damage_multiplier)
	_art_kind = _body.kind
	if not is_equal_approx(size_multiplier, 1.0):
		body_radius *= size_multiplier
		var collider: CollisionShape2D = $CollisionShape2D
		var original := collider.shape
		if not shape_cache.has(original):
			var shape := original.duplicate() as CircleShape2D
			shape.radius = body_radius
			shape_cache[original] = shape
		collider.shape = shape_cache[original]
	_body.radius = body_radius * (1.40 if _body.kind == ActorArt.Kind.BOSS else 1.0)
	if tint != Color.WHITE:
		_body.tint = _body.tint.lerp(tint, 0.16)


func visual_extent() -> float:
	return _body.radius * 1.6 + 36.0


func spawn(at: Vector2, target: Player) -> void:
	global_position = at
	_target = target
	_health = max_health
	spawn_id += 1
	speed_multiplier = 1.0
	_slow_left = 0.0
	_frozen_left = 0.0
	_shock_left = 0.0
	_dots.clear()
	velocity = Vector2.ZERO
	_body.position = Vector2.ZERO
	_body.rotation = 0.0
	_body.scale = Vector2.ONE
	_body.modulate.a = 1.0
	_body.hit_white = false
	_body.windup = false
	_body.boss_fraction = 1.0
	_body.boss_stage = 1
	_art_clock = float(spawn_id % 8) * 0.013
	_body.queue_redraw()
	collision_layer = 0
	collision_mask = PLAYER_LAYER | BattlePlane.OBSTACLE_LAYER
	_reset_behavior()


func _physics_process(delta: float) -> void:
	if _health <= 0 or not _target.is_alive():
		return
	_update_statuses(delta)
	if _health <= 0:
		return
	var frozen := _frozen_left > 0.0
	if frozen:
		_frozen_left = maxf(0.0, _frozen_left - delta)
		velocity = Vector2.ZERO
	else:
		velocity = _move_velocity(delta)
		if _slow_left > 0.0:
			velocity *= _slow_factor
		move_and_slide()
	# 首次移动同步物理位置后才让玩家和飞剑检测到它，避免旧位置产生碰撞。
	if collision_layer == 0:
		collision_layer = ENEMY_LAYER
	if not frozen:
		_update_attack(delta)
	_update_art(delta)


func _update_art(delta: float) -> void:
	if _target == null or (_art_kind != ActorArt.Kind.WOLF and _art_kind != ActorArt.Kind.CROW):
		return
	var toward := _target.global_position - global_position
	if toward.length_squared() > 0.01:
		_body.rotation = toward.angle()
	if _art_kind == ActorArt.Kind.CROW:
		_art_clock += delta
		# 翅膀动画只改 CanvasItem 变换，不在每只鸦妖上反复构建几何。
		_body.scale.y = 0.82 + 0.24 * sin(_art_clock * 16.0)


func apply_slow(factor: float, duration: float) -> void:
	_slow_factor = factor
	_slow_left = duration


func freeze(duration: float) -> void:
	_frozen_left = maxf(_frozen_left, duration)


func shock(amp: float, duration: float) -> void:
	_shock_amp = amp
	_shock_left = duration


func apply_dot(id: String, amount: int, ticks: int) -> void:
	_dots[id] = {"amount": amount, "remaining": ticks, "until_tick": 1.0}


func _update_statuses(delta: float) -> void:
	_slow_left = maxf(0.0, _slow_left - delta)
	if not _dots.is_empty():
		for id: String in _dots.keys():
			var dot: Dictionary = _dots[id]
			dot.until_tick -= delta
			while dot.until_tick <= 0.000001 and dot.remaining > 0:
				dot.until_tick += 1.0
				dot.remaining -= 1
				take_damage(dot.amount)
				if _health <= 0:
					return
			if dot.remaining == 0:
				_dots.erase(id)
	_shock_left = maxf(0.0, _shock_left - delta)


func reflect_damage(amount: int, generation: int) -> void:
	if spawn_id == generation and _target != null and _target.accepts_damage and _target.is_alive():
		take_damage(amount)


func _reset_behavior() -> void:
	pass


func _move_velocity(_delta: float) -> Vector2:
	return global_position.direction_to(_target.global_position) * move_speed * speed_multiplier


func _update_attack(_delta: float) -> void:
	pass


func take_damage(amount: int, critical := false) -> void:
	if _health <= 0 or amount <= 0:
		return
	if _shock_left > 0.0:
		amount = roundi(amount * (1.0 + _shock_amp))
	_health = maxi(0, _health - amount)
	health_changed.emit(_health)
	damaged.emit(global_position + Vector2.UP * (body_radius + 5.0), amount, critical)
	_body.boss_fraction = clampf(float(_health) / max_health, 0.0, 1.0)
	_body.hit_white = true
	_body.queue_redraw()
	if _hit_motion != null:
		_hit_motion.kill()
	if _health > 0:
		var away := _target.global_position.direction_to(global_position)
		if away == Vector2.ZERO:
			away = -_body.facing
		# 击退只动表现节点，不移动碰撞体、不影响索敌或拾取距离。
		_body.position = away * 8.0
		_hit_motion = create_tween().set_parallel()
		_hit_motion.tween_property(_body, "position", Vector2.ZERO, 0.11).set_trans(Tween.TRANS_QUAD)
		_hit_motion.tween_callback(_clear_hit).set_delay(0.05)
		return

	# 保留死亡当帧掉落与 0.20 秒回池时机，只更换动画。
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_target = null
	died.emit(self)

	death_burst.emit(global_position, body_radius, _body.tint)
	var tween := create_tween().set_parallel()
	tween.tween_property(_body, "scale", Vector2.ONE * 0.05, DEATH_DURATION).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_body, "modulate:a", 0.0, DEATH_DURATION)
	tween.tween_callback(_clear_hit).set_delay(0.055)
	tween.chain().tween_callback(death_finished.emit.bind(self))


func _clear_hit() -> void:
	_body.hit_white = false
	_body.queue_redraw()
