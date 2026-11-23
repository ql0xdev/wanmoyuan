extends Node2D

const Player = preload("res://scenes/player.gd")
const Enemy = preload("res://scenes/enemies/enemy.gd")
const BattlePlane = preload("res://scripts/battle_plane.gd")
const BattleCamera = preload("res://scenes/world/battle_camera.gd")
const SkillVisuals = preload("res://scenes/skills/skill_visuals.gd")
const AscensionSkills = preload("res://scenes/skills/ascension_skills.gd")
const Catalog = preload("res://scripts/cultivation_catalog.gd")
const Upgrades = preload("res://scripts/upgrade_catalog.gd")
const Aura = preload("res://scenes/skills/aura_damage.gd")
const DamageBatch = preload("res://scenes/skills/damage_batch.gd")
const FireField = preload("res://scenes/skills/fire_field.gd")
const Skill = Catalog.Skill

signal swords_cast
signal lightning_cast

const SWORD_DAMAGE := [10, 15, 20, 25, 30]
const LIGHTNING_DAMAGE := [15, 22, 30, 38, 46]
const ORB_DAMAGE := [8, 12, 16, 20, 24]
const ICE_SLOW_PERCENT := [30, 40, 50, 55, 60]
const HEAL_INTERVAL := [5.0, 4.0, 3.0, 2.8, 2.5]
const HEAL_AMOUNT := [3, 5, 8, 10, 12]
const CAP := Catalog.RUN_SKILL_CAP

const SWORD_INTERVAL := 1.0
const LIGHTNING_INTERVAL := 3.0
const LIGHTNING_RADIUS := 64.0
const LIGHTNING_FLASH_TIME := 0.24
const ORBIT_RADIUS := 72.0
const ORBIT_SPEED := 2.4
const ORB_RADIUS := 11.0
const ICE_RADIUS := 200.0
const STORM_INTERVAL := 5.0
const STORM_SWORDS := 8
const STORM_DAMAGE := [15, 22, 30, 38, 46]
const FIRE_INTERVAL := 4.0
const FIRE_RADIUS := 92.0
const FIRE_DURATION := 3
const FIRE_DAMAGE := [12, 17, 23, 29, 35]
const BLINK_DISTANCE := 300.0
const BLINK_CHANCE_PERCENT := [10, 15, 20, 25, 30]

@onready var _visuals: SkillVisuals = $Visuals

var _levels: Array[int] = []
var _selected: Array[int] = []
var _learned: Array = []
var _passives: Dictionary
var _evolved := {}
var _consumed := {}
var _batch: DamageBatch
var _upgrade_rng := RandomNumberGenerator.new()
var _ascension: AscensionSkills
var _player: Player
var _camera: BattleCamera
var _enemies: Array[Enemy]
var _launch_sword: Callable
var _launch_divine_sword: Callable
var _sword_left := SWORD_INTERVAL
var _divine_volley_left := 0.0
var _lightning_left := LIGHTNING_INTERVAL
var _heal_left := 0.0
var _flash_left := 0.0
var _lightning_points := PackedVector2Array()
var _orbit_angle := 0.0
var _orb_offsets := PackedVector2Array()
var _orb_aura := Aura.new()
var _storm_left := STORM_INTERVAL
var _fire_left := FIRE_INTERVAL
var _fire_zones: Array[Dictionary] = []


func configure(player: Player, enemies: Array[Enemy], launch_sword: Callable, camera: BattleCamera,
		learned: Array, passives: Dictionary, batch: DamageBatch, launch_divine_sword: Callable) -> void:
	_player = player
	_enemies = enemies
	_launch_sword = launch_sword
	_launch_divine_sword = launch_divine_sword
	_camera = camera
	_learned = learned.duplicate()
	_passives = passives.duplicate()
	_batch = batch
	_upgrade_rng.randomize()
	_levels.resize(Catalog.SKILLS.size())
	_levels.fill(0)
	_selected.clear()
	_selected.append(Skill.SWORD)
	_levels[Skill.SWORD] = 1
	_visuals.setup(ORB_RADIUS, ICE_RADIUS, LIGHTNING_RADIUS)
	_ascension = AscensionSkills.new(_player, _enemies, _visuals, batch)
	_player.dashed.connect(_ascension.on_dash_step)
	_player.hit.connect(_try_blink)


func roll_choices() -> Array[Dictionary]:
	var upgrades: Array[Dictionary] = []
	var discoveries: Array[Dictionary] = []
	var stats: Array[Dictionary] = []
	var evolutions: Array[int] = []
	for skill in _selected:
		if _levels[skill] < CAP:
			upgrades.append({"type": "skill", "id": skill})
		elif _can_evolve(skill):
			evolutions.append(skill)
	if _selected.size() < Catalog.RUN_SKILL_SLOTS:
		for id: String in _learned:
			var skill := Catalog.SKILLS.find(id)
			if skill >= 0 and not _selected.has(skill) and not _consumed.has(skill):
				discoveries.append({"type": "new", "id": skill})
	for stat: String in Upgrades.STAT_CARDS:
		stats.append({"type": "stat", "id": stat})
	var result: Array[Dictionary] = []
	if not evolutions.is_empty():
		result.append({"type": "evolution", "id": evolutions[_upgrade_rng.randi_range(0, evolutions.size() - 1)], "rarity": "evolution"})
	# 两个功法位（进化占一个），优先保证能学新功法；第三个留给属性。
	if not discoveries.is_empty():
		result.append(_draw_upgrade(discoveries))
	if result.size() < 2 and not upgrades.is_empty():
		result.append(_draw_upgrade(upgrades))
	while result.size() < 2 and (not upgrades.is_empty() or not discoveries.is_empty()):
		result.append(_draw_upgrade(upgrades if not upgrades.is_empty() else discoveries))
	while result.size() < 3:
		result.append(_draw_upgrade(stats))
	return result


func _draw_upgrade(pool: Array[Dictionary]) -> Dictionary:
	var card: Dictionary = pool.pop_at(_upgrade_rng.randi_range(0, pool.size() - 1))
	card["rarity"] = "rare" if _upgrade_rng.randi_range(1, 100) <= Upgrades.RARE_PERCENT else "normal"
	return card


func card_text(card: Dictionary) -> String:
	var rare: bool = card.rarity == "rare"
	if card.type == "stat":
		return Upgrades.stat_card_text(card.id, rare)
	var skill: int = card.id
	if card.type == "evolution":
		var evolution: Dictionary = Catalog.EVOLUTIONS[Catalog.SKILLS[skill]]
		return "进化 · %s\n\n%s\n\n%s" % [evolution.name, Catalog.evolution_recipe(Catalog.SKILLS[skill]), evolution.card]
	var next_level := mini(CAP, _levels[skill] + (2 if rare else 1))
	var tier := next_level - 1
	var reach := Catalog.range_factor(next_level)
	var effect := ""
	match skill:
		Skill.SWORD:
			effect = "每秒 %d 把飞剑\n每剑 %d 伤害" % [Catalog.cast_count(next_level, next_level), SWORD_DAMAGE[tier]]
		Skill.LIGHTNING:
			effect = "每 3 秒 %d 道雷\n每道 %d 范围伤害" % [Catalog.cast_count(next_level, next_level), LIGHTNING_DAMAGE[tier]]
		Skill.ORBS:
			effect = "%d 颗环绕火珠\n每 0.5 秒伤害 %d" % [Catalog.cast_count(next_level + 2, next_level), roundi(ORB_DAMAGE[tier] * Aura.POWER)]
		Skill.ICE:
			effect = "范围 %d 像素\n敌人减速 %d%%" % [int(ICE_RADIUS * reach), ICE_SLOW_PERCENT[tier]]
		Skill.HEAL:
			effect = "每 %s 秒\n回复 %d 生命" % [str(HEAL_INTERVAL[tier]), HEAL_AMOUNT[tier]]
		Skill.SWORD_STORM:
			effect = "每 5 秒齐射 %d 剑\n每剑 %d 伤害" % [Catalog.cast_count(STORM_SWORDS, next_level), STORM_DAMAGE[tier]]
		Skill.FIRE:
			effect = "每 4 秒生火 3 秒\n每 0.5 秒伤害 %d" % roundi(FIRE_DAMAGE[tier] * Aura.POWER)
		Skill.BLINK:
			effect = "受击时 %d%%\n概率瞬移 %d" % [BLINK_CHANCE_PERCENT[tier], int(BLINK_DISTANCE * reach)]
		_:
			effect = _ascension.card_detail(Catalog.SKILLS[skill], tier)
	if next_level == CAP:
		effect += "\n满级质变"
	var action := ("珍稀新功法" if rare else "新功法") if card.type == "new" else ("珍稀" if rare else "升级")
	var progression := "Lv%d → Lv%d" % [_levels[skill], next_level] if rare else "Lv%d" % next_level
	return "%s · %s\n%s\n\n%s" % [action, Catalog.SKILL_DATA[Catalog.SKILLS[skill]].name, progression, effect]


func apply_card(card: Dictionary) -> void:
	var power := 2 if card.rarity == "rare" else 1
	match card.type:
		"skill", "new": apply_upgrade(card.id, power)
		"evolution": _apply_evolution(card.id)
		"stat":
			_player.stats.add_run_stat(card.id, Upgrades.STAT_CARDS[card.id].amount * power)
			if card.id == "health_flat":
				_player.refresh_equipment()


func apply_upgrade(skill: int, steps := 1) -> void:
	if skill < 0 or skill >= _levels.size() or _levels[skill] >= CAP or steps < 1:
		return
	if not _selected.has(skill):
		if _selected.size() >= Catalog.RUN_SKILL_SLOTS or _consumed.has(skill) or not _learned.has(Catalog.SKILLS[skill]):
			return
		_selected.append(skill)
	_levels[skill] = mini(CAP, _levels[skill] + steps)
	if skill == Skill.HEAL:
		_heal_left = HEAL_INTERVAL[_levels[skill] - 1]


func _apply_evolution(skill: int) -> void:
	if not _can_evolve(skill):
		return
	_evolved[skill] = true
	var id: String = Catalog.SKILLS[skill]
	var rule: Dictionary = Catalog.EVOLUTIONS[id]
	if rule.has("partner"):
		var partner := Catalog.SKILLS.find(rule.partner)
		_selected.erase(partner)
		_consumed[partner] = true
		_levels[partner] = 0
		if partner == Skill.FIRE:
			_clear_fire()
		if partner == Skill.SHIELD:
			_player.clear_shield()
	_ascension.evolve(id)
	if skill == Skill.ICE:
		for enemy in _enemies:
			enemy.speed_multiplier = 1.0
		_visuals.hide_ice()
	if skill == Skill.ORBS:
		_orb_aura.clear()


func _can_evolve(skill: int) -> bool:
	if not _selected.has(skill) or _levels[skill] != CAP or _evolved.has(skill):
		return false
	var active := []
	for known in _selected:
		if not _evolved.has(known):
			active.append(Catalog.SKILLS[known])
	return Catalog.evolution_matches(Catalog.SKILLS[skill], active, _passives)


func slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for skill in _selected:
		var id: String = Catalog.SKILLS[skill]
		var evolved := _evolved.has(skill)
		result.append({"id": id, "level": _levels[skill], "evolved": evolved,
			"name": Catalog.EVOLUTIONS[id].name if evolved else Catalog.SKILL_DATA[id].name})
	return result


func evolution_hints() -> PackedStringArray:
	var hints := PackedStringArray()
	for skill in _selected:
		var id: String = Catalog.SKILLS[skill]
		if not _evolved.has(skill) and Catalog.EVOLUTIONS.has(id):
			hints.append(("可进化 · " if _can_evolve(skill) else "") + Catalog.evolution_recipe(id))
	return hints


func _physics_process(delta: float) -> void:
	if _player == null or not _player.is_alive():
		return
	if _flash_left > 0.0:
		_flash_left = maxf(0.0, _flash_left - delta)
		_visuals.update_lightning(_flash_left / LIGHTNING_FLASH_TIME)
	# 用基础冷却时间记录进度，换装后当前这轮也会按新速度推进。
	var cooldown_step := delta / _player.stats.cooldown_multiplier
	_ascension.update(delta, cooldown_step, _levels)
	var sword_level := _levels[Skill.SWORD]
	if _evolved.has(Skill.SWORD):
		_ascension.update_blades(delta, SWORD_DAMAGE[CAP - 1], ORBIT_SPEED)
		_update_divine_volley(cooldown_step)
	elif sword_level > 0:
		_sword_left -= cooldown_step
		if _sword_left <= 0.0:
			_sword_left += SWORD_INTERVAL
			_cast_swords(sword_level)

	var lightning_level := _levels[Skill.LIGHTNING]
	if lightning_level > 0 and not _evolved.has(Skill.LIGHTNING):
		_lightning_left -= cooldown_step
		if _lightning_left <= 0.0:
			_lightning_left += LIGHTNING_INTERVAL
			_cast_lightning(lightning_level)

	var orb_level := _levels[Skill.ORBS]
	if orb_level > 0:
		_update_orbs(delta, orb_level)

	var ice_level := _levels[Skill.ICE]
	if ice_level > 0 and not _evolved.has(Skill.ICE):
		_update_ice(ice_level)
		_visuals.update_ice(_player.global_position, Catalog.range_factor(ice_level))

	var heal_level := _levels[Skill.HEAL]
	if heal_level > 0:
		_heal_left -= cooldown_step
		if _heal_left <= 0.0:
			_heal_left += HEAL_INTERVAL[heal_level - 1]
			var prior_health := _player.health
			var power: int = Catalog.EVOLUTIONS.heal.power if _evolved.has(Skill.HEAL) else 1
			_player.heal(HEAL_AMOUNT[heal_level - 1] * power)
			if _player.health > prior_health:
				_visuals.show_heal()
		_visuals.update_heal(_player.global_position, delta)

	var storm_level := _levels[Skill.SWORD_STORM]
	if storm_level > 0:
		_storm_left -= cooldown_step
		if _storm_left <= 0.0:
			_storm_left += STORM_INTERVAL
			_cast_storm(storm_level)

	var fire_level := _levels[Skill.FIRE]
	if fire_level > 0:
		_update_fire(delta, fire_level)
		_fire_left -= cooldown_step
		if _fire_left <= 0.0:
			_fire_left += FIRE_INTERVAL
			_cast_fire(fire_level)


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
	var count := Catalog.cast_count(level, level)
	var damage := _player.stats.damage(SWORD_DAMAGE[level - 1])
	# 多把剑错开出剑位置，但仍瞄准同一个最近的敌人。
	for i in range(count):
		var lateral := (float(i) - (count - 1) * 0.5) * 18.0
		var start := origin + Vector2(-direction.y, direction.x) * lateral - direction * (i * 22.0)
		_launch_sword.call(start, start.direction_to(target), damage, Catalog.range_factor(level))
	swords_cast.emit()


func _update_divine_volley(cooldown_step: float) -> void:
	_divine_volley_left = maxf(0.0, _divine_volley_left - cooldown_step)
	if _divine_volley_left > 0.0 or _enemies.is_empty():
		return
	var rule: Dictionary = Catalog.EVOLUTIONS.sword
	var origin := _player.global_position
	var range_squared: float = rule.target_range * rule.target_range
	var targets: Array[Enemy] = []
	for enemy in _enemies:
		if enemy._health > 0 and origin.distance_squared_to(enemy.global_position) <= range_squared:
			targets.append(enemy)
	if targets.is_empty():
		return
	targets.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position))
	var damage := _player.stats.damage(roundi(SWORD_DAMAGE[CAP - 1] * rule.volley_power))
	var reach := Catalog.range_factor(CAP)
	var offsets := _ascension._blade_offsets
	for i in range(offsets.size()):
		var target := targets[i % targets.size()]
		_launch_divine_sword.call(origin + offsets[i] * 0.52, target, damage, reach)
	_divine_volley_left = rule.volley_interval
	_visuals.flash_sword_volley(origin, rule.radius * reach)
	swords_cast.emit()


func _cast_lightning(level: int) -> void:
	var view := get_viewport().get_visible_rect()
	var world_view := _camera.world_view()
	var candidates := PackedVector2Array()
	for enemy in _enemies:
		if world_view.has_point(enemy.global_position):
			candidates.append(enemy.global_position)
	var damage := _player.stats.damage(LIGHTNING_DAMAGE[level - 1])
	_lightning_points.clear()
	var reach := Catalog.range_factor(level)
	var radius := LIGHTNING_RADIUS * reach
	# 随机选屏内敌人落雷；可用目标不足时，余下的雷随机落在屏内。
	for i in range(Catalog.cast_count(level, level)):
		var point: Vector2
		if not candidates.is_empty():
			var index := randi_range(0, candidates.size() - 1)
			point = candidates[index]
			candidates.remove_at(index)
		else:
			var screen_point := Vector2(randf_range(view.position.x, view.end.x), randf_range(view.position.y, view.end.y))
			point = _camera.ground_at(screen_point)
		_lightning_points.append(point)
		_batch.begin()
		for j in range(_enemies.size() - 1, -1, -1):
			var enemy := _enemies[j]
			if point.distance_squared_to(enemy.global_position) <= radius * radius:
				enemy.take_damage(damage)
		_batch.finish()
	_flash_left = LIGHTNING_FLASH_TIME
	_visuals.show_lightning(_lightning_points, reach)
	_visuals.update_lightning(1.0)
	lightning_cast.emit()


func _update_orbs(delta: float, level: int) -> void:
	_orbit_angle = fposmod(_orbit_angle + ORBIT_SPEED * delta, TAU)
	var evolved := _evolved.has(Skill.ORBS)
	var reach := Catalog.range_factor(level)
	var radius := ORBIT_RADIUS * reach
	var count := Catalog.cast_count(level + 2, level)
	_orb_offsets.resize(count)
	for i in range(count):
		_orb_offsets[i] = BattlePlane.direction(_orbit_angle + TAU * i / count) * radius

	var origin := _player.global_position
	var tint := Color("#fbc779") if evolved else Color("#ff7134")
	_visuals.update_orbs(origin, _orb_offsets)
	_visuals.show_aura("orbs", origin, radius, tint, delta)
	if _orb_aura.step(delta, origin, radius, Aura.tick_amount(_player.stats.damage(ORB_DAMAGE[level - 1])), _enemies, _batch):
		_visuals.pulse(origin, radius, tint)


func _update_ice(level: int) -> void:
	var origin := _player.global_position
	var radius := ICE_RADIUS * Catalog.range_factor(level)
	var slowed_speed: float = 1.0 - ICE_SLOW_PERCENT[level - 1] / 100.0
	for enemy in _enemies:
		var inside := origin.distance_squared_to(enemy.global_position) <= radius * radius
		enemy.speed_multiplier = slowed_speed if inside else 1.0


func _cast_storm(level: int) -> void:
	var origin := _player.global_position
	var damage := _player.stats.damage(STORM_DAMAGE[level - 1])
	var count := Catalog.cast_count(STORM_SWORDS, level)
	for i in range(count):
		_launch_sword.call(origin, BattlePlane.direction(TAU * i / count), damage, Catalog.range_factor(level))
	swords_cast.emit()


func _cast_fire(level: int) -> void:
	if _enemies.is_empty():
		return
	var target := _enemies[randi_range(0, _enemies.size() - 1)].global_position
	var visual := FireField.new()
	add_child(visual)
	visual.global_position = target
	visual.display(FIRE_RADIUS * Catalog.range_factor(level), 0.0)
	var aura := Aura.new()
	aura.step(0.0, target, FIRE_RADIUS * Catalog.range_factor(level), 0, _enemies, _batch)
	_fire_zones.append({"center": target, "visual": visual, "seconds": 0.0, "aura": aura})


func _update_fire(delta: float, level: int) -> void:
	for i in range(_fire_zones.size() - 1, -1, -1):
		var zone := _fire_zones[i]
		var reach := Catalog.range_factor(level)
		var radius := FIRE_RADIUS * reach
		var damage := Aura.tick_amount(_player.stats.damage(FIRE_DAMAGE[level - 1]))
		zone.visual.display(radius, zone.seconds)
		if zone.aura.step(minf(delta, FIRE_DURATION - zone.seconds), zone.center, radius, damage, _enemies, _batch):
			_visuals.pulse(zone.center, radius, Color("#ff9b58"))
		zone.seconds += delta
		if zone.seconds >= FIRE_DURATION:
			zone.visual.queue_free()
			_fire_zones.remove_at(i)


func _clear_fire() -> void:
	for zone in _fire_zones:
		zone.visual.queue_free()
	_fire_zones.clear()


func _try_blink() -> void:
	var level := _levels[Skill.BLINK]
	if level > 0 and _player.is_alive() and randf() < BLINK_CHANCE_PERCENT[level - 1] / 100.0:
		_player.blink(BLINK_DISTANCE * Catalog.range_factor(level))
