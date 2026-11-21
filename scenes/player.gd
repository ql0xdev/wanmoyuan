extends CharacterBody3D

const StatsManager = preload("res://scripts/stats_manager.gd")
const BattlePlane = preload("res://scripts/battle_plane.gd")

signal health_changed(current: int, maximum: int)
signal hit
signal died

const BODY_RADIUS := 16.0
const INVULNERABILITY := 0.5
const FLASH_INTERVAL := 0.08
const HIT_TINT := Color("#bc6356")
const DEATH_TINT := Color("#562a26")

@onready var _body: MeshInstance3D = $Body
@onready var _base_material := _body.material_override
var _hit_material := StandardMaterial3D.new()

var stats := StatsManager.new()
var _run_health_bonus := 0
var max_health := StatsManager.BASE_HEALTH
var health := max_health
var accepts_damage := true
var _invulnerable_left := 0.0
var _joystick_direction := Vector3.ZERO


func _ready() -> void:
	_hit_material.albedo_color = HIT_TINT
	collision_mask |= BattlePlane.OBSTACLE_LAYER


func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	if _invulnerable_left > 0.0:
		_update_hit_flash(delta)

	var direction := BattlePlane.from_input(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
	if _joystick_direction != Vector3.ZERO:
		direction = _joystick_direction

	# 两种输入共用同一移动逻辑，斜向不加速，松手即停。
	velocity = direction * stats.move_speed()
	move_and_slide()


func _on_joystick_direction_changed(direction: Vector2) -> void:
	_joystick_direction = BattlePlane.from_input(direction)


func is_alive() -> bool:
	return health > 0


func take_damage(amount: int) -> void:
	if not accepts_damage or not is_alive() or amount <= 0 or _invulnerable_left > 0.0:
		return
	health = maxi(0, health - stats.incoming_damage(amount))
	health_changed.emit(health, max_health)
	hit.emit()
	if is_alive():
		_invulnerable_left = INVULNERABILITY
		_body.material_override = _hit_material
	else:
		velocity = Vector3.ZERO
		_hit_material.albedo_color = DEATH_TINT
		_body.material_override = _hit_material
		died.emit()


func _update_hit_flash(delta: float) -> void:
	# 无敌与闪烁共用战斗时间；升级暂停不消耗无敌时间。
	_invulnerable_left = maxf(0.0, _invulnerable_left - delta)
	if is_zero_approx(_invulnerable_left):
		_invulnerable_left = 0.0
		_body.material_override = _base_material
		return
	var phase := floori((INVULNERABILITY - _invulnerable_left) / FLASH_INTERVAL)
	_body.material_override = _hit_material if phase % 2 == 0 else _base_material


func heal(amount: int) -> void:
	if is_alive() and amount > 0 and health < max_health:
		health = mini(health + amount, max_health)
		health_changed.emit(health, max_health)


func increase_max_health(amount: int) -> void:
	_run_health_bonus += amount
	refresh_equipment()


func refresh_equipment(refill := false) -> void:
	max_health = stats.max_health(_run_health_bonus)
	if is_alive():
		health = max_health if refill else mini(health, max_health)
	health_changed.emit(health, max_health)


func blink(distance: float) -> bool:
	var collider: CollisionShape3D = $CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.collision_mask = BattlePlane.OBSTACLE_LAYER | 2
	query.exclude = [get_rid()]
	var space := get_world_3d().direct_space_state
	var angle := randf() * TAU
	for i in range(12):
		var destination := global_position + BattlePlane.direction(angle + TAU * i / 12.0) * distance
		query.transform = Transform3D(collider.global_basis, destination + collider.position)
		if space.intersect_shape(query, 1).is_empty():
			global_position = destination
			velocity = Vector3.ZERO
			reset_physics_interpolation()
			return true
	return false
