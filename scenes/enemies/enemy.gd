extends CharacterBody3D

const Player = preload("res://scenes/player.gd")
const BattlePlane = preload("res://scripts/battle_plane.gd")
const FLASH_MATERIAL := preload("res://scenes/world/flash_material.tres")

signal died(enemy: CharacterBody3D)
signal death_finished(enemy: CharacterBody3D)
signal health_changed(current: int)
signal damaged(at: Vector3, amount: int, critical: bool)
signal death_burst(at: Vector3, radius: float, tint: Color)

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

@onready var _body: MeshInstance3D = $Body
@onready var _base_scale := _body.scale
@onready var _base_material: StandardMaterial3D = _body.material_override
@onready var _visual_bounds := _body.transform * _body.get_aabb()

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


func apply_difficulty(health_multiplier: float, damage_multiplier: float, size_multiplier: float,
		tint: Color, visual_cache: Dictionary, shape_cache: Dictionary) -> void:
	max_health = roundi(max_health * health_multiplier)
	damage = roundi(damage * damage_multiplier)
	if is_equal_approx(size_multiplier, 1.0):
		return
	body_radius *= size_multiplier
	var collider: CollisionShape3D = $CollisionShape3D
	var original := collider.shape
	if not shape_cache.has(original):
		var shape := original.duplicate() as CylinderShape3D
		shape.radius = body_radius
		shape_cache[original] = shape
	collider.shape = shape_cache[original]
	if not visual_cache.has(_base_material):
		var material := _base_material.duplicate() as StandardMaterial3D
		material.albedo_color = material.albedo_color.lerp(tint, 0.65)
		if material.emission_enabled:
			material.emission = tint * 0.42
		visual_cache[_base_material] = material
	_base_material = visual_cache[_base_material]
	_body.material_override = _base_material
	_body.position *= size_multiplier
	_base_scale *= size_multiplier
	_body.scale = _base_scale
	_visual_bounds = _body.transform * _body.get_aabb()


func visual_bounds() -> AABB:
	return _visual_bounds


func spawn(at: Vector3, target: Player) -> void:
	global_position = at
	_target = target
	_health = max_health
	spawn_id += 1
	speed_multiplier = 1.0
	_slow_left = 0.0
	_frozen_left = 0.0
	_shock_left = 0.0
	_dots.clear()
	velocity = Vector3.ZERO
	_body.scale = _base_scale
	_body.material_override = _base_material
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
		velocity = Vector3.ZERO
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


func _move_velocity(_delta: float) -> Vector3:
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
	damaged.emit(_body.global_position + Vector3.UP * (body_radius + 5.0), amount, critical)
	if _health > 0:
		return

	# 死亡后先退出碰撞和索敌、触发掉落，缩放消失后再回收到池中。
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	_target = null
	died.emit(self)

	death_burst.emit(_body.global_position, body_radius, _base_material.albedo_color)
	_body.material_override = FLASH_MATERIAL
	var tween := create_tween().set_parallel()
	tween.tween_property(_body, "scale", _base_scale * 1.25, 0.07)
	tween.tween_callback(_restore_material).set_delay(0.055)
	tween.chain().tween_property(_body, "scale", _base_scale * 0.01, DEATH_DURATION - 0.07)
	tween.chain().tween_callback(death_finished.emit.bind(self))


func _restore_material() -> void:
	_body.material_override = _base_material
