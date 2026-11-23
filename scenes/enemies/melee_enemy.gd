extends "res://scenes/enemies/enemy.gd"

const ATTACK_INTERVAL := 1.0
const CONTACT_MARGIN := 0.25

var _attack_left := 0.0


func _reset_behavior() -> void:
	_attack_left = 0.0


func _update_attack(delta: float) -> void:
	_attack_left = maxf(0.0, _attack_left - delta)
	if not is_zero_approx(_attack_left):
		return

	# 两个圆形碰撞体接触时攻击，留少量余量覆盖 move_and_slide 的安全间距。
	var reach := body_radius + Player.BODY_RADIUS + CONTACT_MARGIN
	if global_position.distance_squared_to(_target.global_position) <= reach * reach:
		_attack_left = _contact_interval()
		_target.take_damage(damage, self)


func _contact_interval() -> float:
	return ATTACK_INTERVAL
