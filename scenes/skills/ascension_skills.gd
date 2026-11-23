extends RefCounted

const Catalog = preload("res://scripts/cultivation_catalog.gd")
const Player = preload("res://scenes/player.gd")
const Enemy = preload("res://scenes/enemies/enemy.gd")
const Visuals = preload("res://scenes/skills/skill_visuals.gd")
const BattlePlane = preload("res://scripts/battle_plane.gd")
const Aura = preload("res://scenes/skills/aura_damage.gd")
const DamageBatch = preload("res://scenes/skills/damage_batch.gd")
const Skill = Catalog.Skill
const EPSILON := 0.000001

var _player: Player
var _enemies: Array[Enemy]
var _visuals: Visuals
var _evolved := {}
var _clocks := {}
var _dash_hits := {}
var _dash_damage := 0
var _dash_reach := 1.0
var _batch: DamageBatch
var _wisp_aura := Aura.new()
var _blade_aura := Aura.new()
var _bell_aura := Aura.new()
var _bell_center := Vector2.ZERO
var _bell_left := 0.0
var _wisp_angle := 0.0
var _blade_angle := 0.0
var _blade_offsets := PackedVector2Array()


func _init(player: Player, enemies: Array[Enemy], visuals: Visuals, batch: DamageBatch) -> void:
	_player = player
	_enemies = enemies
	_visuals = visuals
	_batch = batch
	for id: String in ["dash", "bell", "shield"]:
		_clocks[id] = Catalog.SKILL_DATA[id].interval


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
		"wisp":
			_wisp_aura.clear()


func card_detail(id: String, tier: int) -> String:
	var data: Dictionary = Catalog.SKILL_DATA[id]
	var level := tier + 1
	match id:
		"dash": return "每 3 秒突进\n路径伤害 %d" % data.damage[tier]
		"wisp": return "%d 团鬼火环绕\n每 0.5 秒伤害 %d" % [Catalog.cast_count(data.count[tier], level), roundi(data.damage * Aura.POWER)]
		"bell": return "%d 范围减速 40%%\n震荡伤害 %d" % [int(data.radius * Catalog.range_factor(level)), data.damage[tier]]
		"shield": return "护盾 %d 点\n持续 5 秒" % data.absorb[tier]
	return ""


func update(delta: float, step: float, levels: Array[int]) -> void:
	_visuals.update_ascension(_player.global_position, delta, _player.shield)
	if levels[Skill.DASH] > 0 and _ready_to_cast("dash", step):
		_cast_dash(levels[Skill.DASH] - 1)
	if levels[Skill.WISP] > 0:
		_update_wisps(delta, levels[Skill.WISP])
	if _bell_left > EPSILON:
		_update_bell(delta)
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
	if _player.begin_dash(data.distance * Catalog.range_factor(tier + 1), data.duration, evolved):
		_dash_reach = Catalog.range_factor(tier + 1)
		_dash_damage = _player.stats.damage(data.damage[tier] * (int(Catalog.EVOLUTIONS.dash.power) if evolved else 1))
		_dash_hits.clear()
		_visuals.pulse(_player.global_position, 75.0, Color("#ffe5a2") if evolved else Color("#a4ecdd"))


func on_dash_step(from: Vector2, to: Vector2) -> void:
	if not _player.accepts_damage:
		return
	var base_radius: float = Catalog.SKILL_DATA.dash.radius * _dash_reach
	_batch.begin()
	for i in range(_enemies.size() - 1, -1, -1):
		var enemy := _enemies[i]
		var id := enemy.get_instance_id()
		if _dash_hits.get(id, -1) == enemy.spawn_id:
			continue
		var radius := base_radius + enemy.body_radius
		var nearest := Geometry2D.get_closest_point_to_segment(enemy.global_position, from, to)
		if nearest.distance_squared_to(enemy.global_position) <= radius * radius:
			_dash_hits[id] = enemy.spawn_id
			enemy.take_damage(_dash_damage)
	_batch.finish()


func _update_wisps(delta: float, level: int) -> void:
	var data: Dictionary = Catalog.SKILL_DATA.wisp
	var evolved := _evolved.has("wisp")
	var rule: Dictionary = Catalog.EVOLUTIONS.wisp
	var count := Catalog.cast_count(int(data.count[level - 1]) * (int(rule.count) if evolved else 1), level)
	var radius: float = (data.radius + (rule.radius if evolved else 0.0)) * Catalog.range_factor(level)
	var original: int = rule.blast_damage if evolved else data.damage
	var origin := _player.global_position
	_wisp_angle = fposmod(_wisp_angle + delta * 1.6, TAU)
	for i in range(Visuals.WISP_SLOTS):
		if i < count:
			var at := origin + BattlePlane.direction(_wisp_angle + TAU * i / count) * radius
			_visuals.show_wisp(i, at, evolved)
		else:
			_visuals.hide_wisp(i)
	var tint := Color("#df80ff") if evolved else Color("#85efa9")
	_visuals.show_aura("wisp", origin, radius, tint, delta)
	if _wisp_aura.step(delta, origin, radius, Aura.tick_amount(_player.stats.damage(original)), _enemies, _batch):
		_visuals.pulse(origin, radius, tint)


func _nearest(origin: Vector2) -> Enemy:
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
	var radius: float = rule.radius * Catalog.range_factor(tier + 1)
	_visuals.pulse(origin, radius, Color("#db81ed") if evolved else Color("#d8b6f9"))
	var damage := _player.stats.damage(data.damage[tier])
	_batch.begin()
	for i in range(_enemies.size() - 1, -1, -1):
		var enemy := _enemies[i]
		if origin.distance_squared_to(enemy.global_position) <= radius * radius:
			enemy.apply_slow(1.0 - rule.slow, rule.duration)
			enemy.take_damage(damage)
	_batch.finish()
	if evolved:
		_bell_center = origin
		_bell_left = rule.duration
		_bell_aura.clear()
		_update_bell(0.0)


func _update_bell(delta: float) -> void:
	var rule: Dictionary = Catalog.EVOLUTIONS.bell
	var radius: float = rule.radius * Catalog.range_factor(Catalog.RUN_SKILL_CAP)
	var damage := Aura.tick_amount(_player.stats.damage(rule.dot_damage))
	var tint := Color("#db81ed")
	_visuals.show_aura("bell", _bell_center, radius, tint, delta)
	if _bell_aura.step(minf(delta, _bell_left), _bell_center, radius, damage, _enemies, _batch):
		_visuals.pulse(_bell_center, radius, tint)
	_bell_left -= delta
	if _bell_left <= EPSILON:
		_visuals.hide_aura("bell")


func _cast_shield(tier: int) -> void:
	var data: Dictionary = Catalog.SKILL_DATA.shield
	var rule: Dictionary = Catalog.EVOLUTIONS.shield
	var evolved := _evolved.has("shield")
	_player.grant_shield(data.absorb[tier] * (int(rule.power) if evolved else 1), data.duration, rule.heal if evolved else 0.0)
	_visuals.pulse(_player.global_position, 93.0 * Catalog.range_factor(tier + 1), Color("#8fffcf"))


func _cast_thunderfire() -> void:
	var enemy := _nearest(_player.global_position)
	if enemy == null:
		return
	var center := enemy.global_position
	var rule: Dictionary = Catalog.EVOLUTIONS.lightning
	var damage := _player.stats.damage(30)
	var burn := _player.stats.damage(rule.burn_damage)
	var radius: float = rule.radius * Catalog.range_factor(Catalog.RUN_SKILL_CAP)
	_batch.begin()
	for i in range(_enemies.size() - 1, -1, -1):
		var victim := _enemies[i]
		if center.distance_squared_to(victim.global_position) <= radius * radius:
			victim.take_damage(damage)
			if victim._health > 0:
				victim.shock(rule.amp, rule.shock)
				victim.apply_dot("thunderfire", burn, rule.burn_seconds)
	_batch.finish()
	_visuals.pulse(center, radius, Color("#ffa359"), true)


func _cast_freeze() -> void:
	var rule: Dictionary = Catalog.EVOLUTIONS.ice
	var origin := _player.global_position
	var radius: float = rule.radius * Catalog.range_factor(Catalog.RUN_SKILL_CAP)
	for enemy in _enemies:
		if origin.distance_squared_to(enemy.global_position) <= radius * radius:
			enemy.freeze(rule.duration)
	_visuals.pulse(origin, radius, Color("#9defff"))


func update_blades(delta: float, base_damage: int, speed: float) -> void:
	var rule: Dictionary = Catalog.EVOLUTIONS.sword
	var count := Catalog.cast_count(rule.count, Catalog.RUN_SKILL_CAP)
	var radius: float = rule.radius * Catalog.range_factor(Catalog.RUN_SKILL_CAP)
	var origin := _player.global_position
	_blade_angle = fposmod(_blade_angle + speed * delta, TAU)
	_blade_offsets.resize(count)
	for i in range(count):
		_blade_offsets[i] = BattlePlane.direction(_blade_angle + TAU * i / count) * radius
	_visuals.show_blades(origin, _blade_offsets)
	var tint := Color("#fff4a3")
	var damage := Aura.tick_amount(_player.stats.damage(roundi(base_damage * rule.aura_power)))
	_visuals.show_aura("blades", origin, radius, tint, delta)
	if _blade_aura.step(delta, origin, radius, damage, _enemies, _batch):
		_visuals.pulse(origin, radius, tint)
