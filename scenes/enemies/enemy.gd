extends CharacterBody2D

const Player = preload("res://scenes/player.gd")

signal died(enemy: CharacterBody2D)
signal death_finished(enemy: CharacterBody2D)
signal health_changed(current: int)

const PLAYER_LAYER := 1
const ENEMY_LAYER := 2
const DEATH_DURATION := 0.20

@export var max_health := 20
@export var move_speed := 120.0
@export var damage := 10
@export var body_radius := 16.0
@export var crystal_count := 1

@onready var _body: Polygon2D = $Body

var speed_multiplier := 1.0
var _health := 0
var _target: Player


func spawn(at: Vector2, target: Player) -> void:
	global_position = at
	_target = target
	_health = max_health
	speed_multiplier = 1.0
	velocity = Vector2.ZERO
	_body.scale = Vector2.ONE
	_body.modulate = Color.WHITE
	collision_layer = 0
	collision_mask = PLAYER_LAYER
	_reset_behavior()


func _physics_process(delta: float) -> void:
	if _health <= 0 or not _target.is_alive():
		return
	velocity = _move_velocity(delta)
	move_and_slide()
	# 首次移动同步物理位置后才让玩家和飞剑检测到它，避免旧位置产生碰撞。
	if collision_layer == 0:
		collision_layer = ENEMY_LAYER
	_update_attack(delta)


func _reset_behavior() -> void:
	pass


func _move_velocity(_delta: float) -> Vector2:
	return global_position.direction_to(_target.global_position) * move_speed * speed_multiplier


func _update_attack(_delta: float) -> void:
	pass


func take_damage(amount: int) -> void:
	if _health <= 0 or amount <= 0:
		return
	_health = maxi(0, _health - amount)
	health_changed.emit(_health)
	if _health > 0:
		return

	# 死亡后先退出碰撞和索敌、掉落灵晶，缩放消失后再回收到池中。
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_target = null
	died.emit(self)

	var tween := create_tween().set_parallel()
	tween.tween_property(_body, "scale", Vector2.ZERO, DEATH_DURATION)
	tween.tween_property(_body, "modulate:a", 0.0, DEATH_DURATION)
	tween.chain().tween_callback(death_finished.emit.bind(self))
