extends RefCounted

const Catalog = preload("res://scripts/cultivation_catalog.gd")
const Player = preload("res://scenes/player.gd")
const Enemy = preload("res://scenes/enemies/enemy.gd")
const Visuals = preload("res://scenes/skills/skill_visuals.gd")
const BattlePlane = preload("res://scripts/battle_plane.gd")
const Skill = Catalog.Skill
const EPSILON := 0.000001

var _player: Player
var _enemies: Array[Enemy]
var _visuals: Visuals
var _evolved := {}
var _clocks := {}
var _dash_hits := {}
var _dash_damage := 0
var _wisps: Array[Dictionary] = []
var _wisp_free: Array[int] = []
var _blade_angle := 0.0
var _blade_offsets := PackedVector3Array()
var _blade_contacts: Dictionary[int, int] = {}
var _blade_next: Dictionary[int, int] = {}


func _init(player: Player, enemies: Array[Enemy], visuals: Visuals) -> void:
	_player = player
	_enemies = enemies
	_visuals = visuals
	for id: String in ["dash", "wisp", "bell", "shield"]:
		_clocks[id] = Catalog.SKILL_DATA[id].interval
	for i in range(Visuals.WISP_SLOTS):
		_wisp_free.append(i)


func evolve(id: String) -> void:
	_evolved[id] = true
	var rule: Dictionary = Catalog.EVOLUTIONS[id]
	if rule.has("interval"):
		_clocks[id] = rule.interval
	match id:
		"orbs":
			_player.guard_mitigation = rule.mitigation
			_player.guard_reflection = rule.reflect
		"heal":
			_player.hit_heal = rule.hit_heal


func card_detail(id: String, tier: int) -> String:
	var data: Dictionary = Catalog.SKILL_DATA[id]
	match id:
		"dash": return "每 3 秒突进\n路径伤害 %d" % data.damage[tier]
		"wisp": return "每 2.5 秒放 %d 团\n每团追踪伤害 %d" % [data.count[tier], data.damage]
		"bell": return "300 范围减速 40%%\n震荡伤害 %d" % data.damage[tier]
		"shield": return "护盾 %d 点\n持续 5 秒" % data.absorb[tier]
	return ""


func update(delta: float, step: float, levels: Array[int]) -> void:
	_visuals.update_ascension(_player.global_position, delta, _player.shield, _evolved.has("orbs"))
	if levels[Skill.DASH] > 0 and _ready_to_cast("dash", step):
		_cast_dash(levels[Skill.DASH] - 1)
	if levels[Skill.WISP] > 0:
		_update_wisps(delta)
		if _ready_to_cast("wisp", step):
			_cast_wisps(levels[Skill.WISP] - 1)
	if levels[Skill.BELL] > 0 and _ready_to_cast("bell", step):
		_cast_bell(levels[Skill.BELL] - 1)
	if levels[Skill.SHIELD] > 0 and _ready_to_cast("shield", step):
		_cast_shield(levels[Skill.SHIELD] - 1)
	if _evolved.has("lightning") and _ready_to_cast("lightning", step):
		_cast_thunderfire()
	if _evolved.has("ice") and _ready_to_cast("ice", step):
		_cast_freeze()


func _ready_to_cast(id: String, step: float) -> bool:
	_clocks[id] -= step
	if _clocks[id] > EPSILON:
		return false
	var interval: float = Catalog.EVOLUTIONS[id].interval if _evolved.has(id) and Catalog.EVOLUTIONS[id].has("interval") \
		else Catalog.SKILL_DATA[id].interval
	_clocks[id] += interval
	return true


func _cast_dash(tier: int) -> void:
	var data: Dictionary = Catalog.SKILL_DATA.dash
	var evolved := _evolved.has("dash")
	if _player.begin_dash(data.distance, data.duration, evolved):
		_dash_damage = _player.stats.damage(data.damage[tier] * (int(Catalog.EVOLUTIONS.dash.power) if evolved else 1))
		_dash_hits.clear()
		_visuals.pulse(_player.global_position, 75.0, Color("#ffe5a2") if evolved else Color("#a4ecdd"))


func on_dash_step(from: Vector3, to: Vector3) -> void:
	if not _player.accepts_damage:
		return
	var base_radius: float = Catalog.SKILL_DATA.dash.radius
	for i in range(_enemies.size() - 1, -1, -1):
		var enemy := _enemies[i]
		var id := enemy.get_instance_id()
		if _dash_hits.get(id, -1) == enemy.spawn_id:
			continue
		var radius := base_radius + enemy.body_radius
		var nearest := Geometry3D.get_closest_point_to_segment(enemy.global_position, from, to)
		if nearest.distance_squared_to(enemy.global_position) <= radius * radius:
			_dash_hits[id] = enemy.spawn_id
			enemy.take_damage(_dash_damage)


func _cast_wisps(tier: int) -> void:
	if _enemies.is_empty():
		return
	var data: Dictionary = Catalog.SKILL_DATA.wisp
	var evolved := _evolved.has("wisp")
	var count: int = data.count[tier] * (int(Catalog.EVOLUTIONS.wisp.count) if evolved else 1)
	var origin := _player.global_position
	for i in range(mini(count, _wisp_free.size())):
		var slot: int = _wisp_free.pop_back()
		var at := origin + BattlePlane.direction(TAU * i / count) * 44.0
		_wisps.append({"slot": slot, "at": at, "life": data.lifetime, "blast": evolved})
		_visuals.show_wisp(slot, at, evolved)


func _update_wisps(delta: float) -> void:
	var data: Dictionary = Catalog.SKILL_DATA.wisp
	for i in range(_wisps.size() - 1, -1, -1):
		var wisp := _wisps[i]
		var target := _nearest(wisp.at)
		wisp.life -= delta
		if target == null or wisp.life <= EPSILON:
			_recycle_wisp(i)
			continue
		var from: Vector3 = wisp.at
		var to := from.move_toward(target.global_position, data.speed * delta)
		var radius := target.body_radius + 11.0
		if to.distance_squared_to(target.global_position) <= radius * radius:
			var impact := target.global_position
			target.take_damage(_player.stats.damage(data.damage))
			if wisp.blast:
				var rule: Dictionary = Catalog.EVOLUTIONS.wisp
				_damage_area(impact, rule.radius, _player.stats.damage(rule.blast_damage))
				_visuals.pulse(impact, rule.radius, Color("#df80ff"))
			_recycle_wisp(i)
		else:
			wisp.at = to
			_visuals.show_wisp(wisp.slot, to, wisp.blast)


func _recycle_wisp(index: int) -> void:
	var slot: int = _wisps[index].slot
	_visuals.hide_wisp(slot)
	_wisp_free.append(slot)
	_wisps.remove_at(index)


func _nearest(origin: Vector3) -> Enemy:
	var best: Enemy
	var nearest := INF
	for enemy in _enemies:
		var distance := origin.distance_squared_to(enemy.global_position)
		if distance < nearest:
			nearest = distance
			best = enemy
	return best


func _cast_bell(tier: int) -> void:
	var data: Dictionary = Catalog.SKILL_DATA.bell
	var evolved := _evolved.has("bell")
	var rule: Dictionary = Catalog.EVOLUTIONS.bell if evolved else data
	var origin := _player.global_position
	_visuals.pulse(origin, rule.radius, Color("#db81ed") if evolved else Color("#d8b6f9"))
	var damage := _player.stats.damage(data.damage[tier])
	var dot := _player.stats.damage(rule.dot_damage) if evolved else 0
	for i in range(_enemies.size() - 1, -1, -1):
		var enemy := _enemies[i]
		if origin.distance_squared_to(enemy.global_position) <= rule.radius * rule.radius:
			enemy.apply_slow(1.0 - rule.slow, rule.duration)
			if evolved:
				enemy.apply_dot("bell", dot, int(rule.duration))
			enemy.take_damage(damage)


func _cast_shield(tier: int) -> void:
	var data: Dictionary = Catalog.SKILL_DATA.shield
	var rule: Dictionary = Catalog.EVOLUTIONS.shield
	var evolved := _evolved.has("shield")
	_player.grant_shield(data.absorb[tier] * (int(rule.power) if evolved else 1), data.duration, rule.heal if evolved else 0.0)
	_visuals.pulse(_player.global_position, 93.0, Color("#8fffcf"))


func _cast_thunderfire() -> void:
	var enemy := _nearest(_player.global_position)
	if enemy == null:
		return
	var center := enemy.global_position
	var rule: Dictionary = Catalog.EVOLUTIONS.lightning
	var damage := _player.stats.damage(30)
	var burn := _player.stats.damage(rule.burn_damage)
	for i in range(_enemies.size() - 1, -1, -1):
		var victim := _enemies[i]
		if center.distance_squared_to(victim.global_position) <= rule.radius * rule.radius:
			victim.take_damage(damage)
			if victim._health > 0:
				victim.shock(rule.amp, rule.shock)
				victim.apply_dot("thunderfire", burn, rule.burn_seconds)
	_visuals.pulse(center, rule.radius, Color("#ffa359"), true)


func _cast_freeze() -> void:
	var rule: Dictionary = Catalog.EVOLUTIONS.ice
	var origin := _player.global_position
	for enemy in _enemies:
		if origin.distance_squared_to(enemy.global_position) <= rule.radius * rule.radius:
			enemy.freeze(rule.duration)
	_visuals.pulse(origin, rule.radius, Color("#9defff"))


func _damage_area(center: Vector3, radius: float, damage: int) -> void:
	for i in range(_enemies.size() - 1, -1, -1):
		var enemy := _enemies[i]
		if center.distance_squared_to(enemy.global_position) <= radius * radius:
			enemy.take_damage(damage)


func update_blades(delta: float, base_damage: int, radius: float, speed: float) -> void:
	var rule: Dictionary = Catalog.EVOLUTIONS.sword
	var count: int = rule.count
	var origin := _player.global_position
	_blade_angle = fposmod(_blade_angle + speed * delta, TAU)
	_blade_offsets.resize(count)
	for i in range(count):
		_blade_offsets[i] = BattlePlane.direction(_blade_angle + TAU * i / count) * radius
	_visuals.show_blades(origin, _blade_offsets)
	var damage_per_blade := _player.stats.damage(roundi(base_damage * rule.power))
	_blade_next.clear()
	for i in range(_enemies.size() - 1, -1, -1):
		var enemy := _enemies[i]
		var at := enemy.global_position - origin
		var reach := enemy.body_radius + 16.0
		if at.length_squared() > (radius + reach) * (radius + reach):
			continue
		var mask := 0
		for j in range(count):
			if _blade_offsets[j].distance_squared_to(at) <= reach * reach:
				mask |= 1 << j
		if mask == 0:
			continue
		var id := enemy.get_instance_id()
		_blade_next[id] = mask
		var hits: int = mask & ~_blade_contacts.get(id, 0)
		var damage := 0
		while hits != 0:
			damage += damage_per_blade
			hits &= hits - 1
		enemy.take_damage(damage)
	var prior := _blade_contacts
	_blade_contacts = _blade_next
	_blade_next = prior
