extends Node2D

const Player = preload("res://scenes/player.gd")
const Enemy = preload("res://scenes/enemies/enemy.gd")

signal swords_cast
signal lightning_cast

enum Skill { SWORD, LIGHTNING, ORBS, ICE, HEAL, MAX_HEALTH }

const SKILL_NAMES := ["御剑术", "雷诀", "护体罡气", "冰心咒", "回春功"]
const SWORD_DAMAGE := [10, 15, 20]
const LIGHTNING_DAMAGE := [15, 22, 30]
const ORB_DAMAGE := [8, 12, 16]
const ICE_SLOW_PERCENT := [30, 40, 50]
const HEAL_INTERVAL := [5.0, 4.0, 3.0]
const HEAL_AMOUNT := [3, 5, 8]
const CAP := 3
const HEALTH_BONUS := 20

const SWORD_INTERVAL := 1.0
const LIGHTNING_INTERVAL := 3.0
const LIGHTNING_RADIUS := 64.0
const LIGHTNING_FLASH_TIME := 0.24
const ORBIT_RADIUS := 72.0
const ORBIT_SPEED := 2.4
const ORB_RADIUS := 11.0
const ICE_RADIUS := 200.0

var _levels: Array[int] = [1, 0, 0, 0, 0]
var _player: Player
var _enemies: Array[Enemy]
var _launch_sword: Callable
var _sword_left := SWORD_INTERVAL
var _lightning_left := LIGHTNING_INTERVAL
var _heal_left := 0.0
var _flash_left := 0.0
var _lightning_points := PackedVector2Array()
var _orbit_angle := 0.0
var _orb_offsets := PackedVector2Array()
var _orb_contacts: Dictionary[int, int] = {}
var _next_contacts: Dictionary[int, int] = {}


func configure(player: Player, enemies: Array[Enemy], launch_sword: Callable) -> void:
	_player = player
	_enemies = enemies
	_launch_sword = launch_sword


func roll_choices() -> Array[int]:
	var available: Array[int] = []
	for skill in range(_levels.size()):
		if _levels[skill] < CAP:
			available.append(skill)
	if available.is_empty():
		return [Skill.MAX_HEALTH]
	available.shuffle()
	available.resize(mini(available.size(), 3))
	return available


func card_text(skill: int) -> String:
	if skill == Skill.MAX_HEALTH:
		return "+%d 生命上限" % HEALTH_BONUS
	var next_level := _levels[skill] + 1
	var tier := next_level - 1
	var effect := ""
	match skill:
		Skill.SWORD:
			effect = "每秒 %d 把飞剑\n每剑 %d 伤害" % [next_level, SWORD_DAMAGE[tier]]
		Skill.LIGHTNING:
			effect = "每 3 秒 %d 道雷\n每道 %d 范围伤害" % [next_level, LIGHTNING_DAMAGE[tier]]
		Skill.ORBS:
			effect = "%d 颗环绕火珠\n每颗 %d 伤害" % [next_level + 2, ORB_DAMAGE[tier]]
		Skill.ICE:
			effect = "范围 %d 像素\n敌人减速 %d%%" % [int(ICE_RADIUS), ICE_SLOW_PERCENT[tier]]
		Skill.HEAL:
			effect = "每 %d 秒\n回复 %d 生命" % [int(HEAL_INTERVAL[tier]), HEAL_AMOUNT[tier]]
	var action := "习得" if next_level == 1 else "升级"
	return "%s · %s\nLv%d\n\n%s" % [action, SKILL_NAMES[skill], next_level, effect]


func apply_upgrade(skill: int) -> void:
	if skill == Skill.MAX_HEALTH:
		_player.increase_max_health(HEALTH_BONUS)
		return
	if _levels[skill] >= CAP:
		return
	_levels[skill] += 1
	if skill == Skill.HEAL:
		_heal_left = HEAL_INTERVAL[_levels[skill] - 1]


func _physics_process(delta: float) -> void:
	var redraw := _flash_left > 0.0
	_flash_left = maxf(0.0, _flash_left - delta)
	# 用基础冷却时间记录进度，换装后当前这轮也会按新速度推进。
	var cooldown_step := delta / _player.stats.cooldown_multiplier
	_sword_left -= cooldown_step
	if _sword_left <= 0.0:
		_sword_left += SWORD_INTERVAL
		_cast_swords(_levels[Skill.SWORD])

	var lightning_level := _levels[Skill.LIGHTNING]
	if lightning_level > 0:
		_lightning_left -= cooldown_step
		if _lightning_left <= 0.0:
			_lightning_left += LIGHTNING_INTERVAL
			_cast_lightning(lightning_level)
			redraw = true

	var orb_level := _levels[Skill.ORBS]
	if orb_level > 0:
		_update_orbs(delta, orb_level)
		redraw = true

	var ice_level := _levels[Skill.ICE]
	if ice_level > 0:
		_update_ice(ice_level)
		redraw = true

	var heal_level := _levels[Skill.HEAL]
	if heal_level > 0:
		_heal_left -= cooldown_step
		if _heal_left <= 0.0:
			_heal_left += HEAL_INTERVAL[heal_level - 1]
			_player.heal(HEAL_AMOUNT[heal_level - 1])

	if redraw:
		queue_redraw()


func _cast_swords(level: int) -> void:
	if _enemies.is_empty():
		return
	var origin := _player.global_position
	var nearest := _enemies[0]
	var nearest_distance := origin.distance_squared_to(nearest.global_position)
	for i in range(1, _enemies.size()):
		var enemy := _enemies[i]
		var distance := origin.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	var target := nearest.global_position
	var direction := origin.direction_to(target)
	var count := level + _player.stats.sword_count
	var damage := _player.stats.damage(SWORD_DAMAGE[level - 1])
	# 多把剑错开出剑位置，但仍瞄准同一个最近的敌人。
	for i in range(count):
		var lateral := (float(i) - (count - 1) * 0.5) * 18.0
		var start := origin + direction.orthogonal() * lateral - direction * (i * 22.0)
		_launch_sword.call(start, start.direction_to(target), damage)
	swords_cast.emit()


func _cast_lightning(level: int) -> void:
	var view := get_viewport_rect()
	var canvas := get_canvas_transform()
	var candidates := PackedVector2Array()
	for enemy in _enemies:
		if view.has_point(canvas * enemy.global_position):
			candidates.append(enemy.global_position)
	var to_world := canvas.affine_inverse()
	var damage := _player.stats.damage(LIGHTNING_DAMAGE[level - 1])
	_lightning_points.clear()
	# 随机选屏内敌人落雷；可用目标不足时，余下的雷随机落在屏内。
	for i in range(level + _player.stats.lightning_count):
		var point: Vector2
		if not candidates.is_empty():
			var index := randi_range(0, candidates.size() - 1)
			point = candidates[index]
			candidates.remove_at(index)
		else:
			var screen_point := Vector2(randf_range(view.position.x, view.end.x), randf_range(view.position.y, view.end.y))
			point = to_world * screen_point
		_lightning_points.append(point)
		for j in range(_enemies.size() - 1, -1, -1):
			var enemy := _enemies[j]
			if point.distance_squared_to(enemy.global_position) <= LIGHTNING_RADIUS * LIGHTNING_RADIUS:
				enemy.take_damage(damage)
	_flash_left = LIGHTNING_FLASH_TIME
	lightning_cast.emit()


func _update_orbs(delta: float, level: int) -> void:
	_orbit_angle = fposmod(_orbit_angle + ORBIT_SPEED * delta, TAU)
	var count := level + 2
	_orb_offsets.resize(count)
	for i in range(count):
		_orb_offsets[i] = Vector2.from_angle(_orbit_angle + TAU * i / count) * ORBIT_RADIUS

	var origin := _player.global_position
	var damage_per_orb := _player.stats.damage(ORB_DAMAGE[level - 1])
	_next_contacts.clear()
	for i in range(_enemies.size() - 1, -1, -1):
		var enemy := _enemies[i]
		var offset := enemy.global_position - origin
		var hit_radius := ORB_RADIUS + enemy.body_radius
		var reach := ORBIT_RADIUS + hit_radius
		if offset.length_squared() > reach * reach:
			continue
		var mask := 0
		for j in range(count):
			if _orb_offsets[j].distance_squared_to(offset) <= hit_radius * hit_radius:
				mask |= 1 << j
		if mask == 0:
			continue

		# 每颗火珠仅在碰到敌人的瞬间伤害一次，分离后可以再次命中。
		var id := enemy.get_instance_id()
		_next_contacts[id] = mask
		var new_hits: int = mask & ~_orb_contacts.get(id, 0)
		var damage := 0
		while new_hits != 0:
			damage += damage_per_orb
			new_hits &= new_hits - 1
		if damage > 0:
			enemy.take_damage(damage)
	var previous := _orb_contacts
	_orb_contacts = _next_contacts
	_next_contacts = previous


func _update_ice(level: int) -> void:
	var origin := _player.global_position
	var slowed_speed: float = 1.0 - ICE_SLOW_PERCENT[level - 1] / 100.0
	for enemy in _enemies:
		var inside := origin.distance_squared_to(enemy.global_position) <= ICE_RADIUS * ICE_RADIUS
		enemy.speed_multiplier = slowed_speed if inside else 1.0


func _draw() -> void:
	if _player == null:
		return
	var center := to_local(_player.global_position)
	if _levels[Skill.ICE] > 0:
		draw_circle(center, ICE_RADIUS, Color(0.38, 0.72, 1.0, 0.10))
		draw_arc(center, ICE_RADIUS, 0.0, TAU, 64, Color(0.52, 0.81, 1.0, 0.55), 2.0, true)
	for offset in _orb_offsets:
		draw_circle(center + offset, ORB_RADIUS, Color("#ff923c"), true, -1.0, true)
	if _flash_left > 0.0:
		var alpha := _flash_left / LIGHTNING_FLASH_TIME
		for point in _lightning_points:
			var impact := to_local(point)
			draw_circle(impact, LIGHTNING_RADIUS, Color(1.0, 0.89, 0.44, alpha * 0.35))
			draw_line(impact + Vector2(12, -82), impact + Vector2(-12, -44), Color(1, 0.95, 0.65, alpha), 5.0)
			draw_line(impact + Vector2(-12, -44), impact, Color(1, 0.95, 0.65, alpha), 5.0)
