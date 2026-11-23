extends Node3D

const Player = preload("res://scenes/player.gd")
const Enemy = preload("res://scenes/enemies/enemy.gd")
const BattlePlane = preload("res://scripts/battle_plane.gd")
const BattleCamera = preload("res://scenes/world/battle_camera.gd")
const SkillVisuals = preload("res://scenes/skills/skill_visuals.gd")
const AscensionSkills = preload("res://scenes/skills/ascension_skills.gd")
const Catalog = preload("res://scripts/cultivation_catalog.gd")
const Skill = Catalog.Skill

signal swords_cast
signal lightning_cast

const SWORD_DAMAGE := [10, 15, 20]
const LIGHTNING_DAMAGE := [15, 22, 30]
const ORB_DAMAGE := [8, 12, 16]
const ICE_SLOW_PERCENT := [30, 40, 50]
const HEAL_INTERVAL := [5.0, 4.0, 3.0]
const HEAL_AMOUNT := [3, 5, 8]
const CAP := 3
const HEALTH_BONUS := 20
const EVOLUTION_START := Skill.MAX_HEALTH + 1

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
const STORM_DAMAGE := [15, 22, 30]
const FIRE_INTERVAL := 4.0
const FIRE_RADIUS := 92.0
const FIRE_DURATION := 3
const FIRE_DAMAGE := [12, 17, 23]
const BLINK_DISTANCE := 300.0
const BLINK_CHANCE_PERCENT := [10, 15, 20]

@onready var _visuals: SkillVisuals = $Visuals

var _levels: Array[int] = []
var _selected: Array[int] = []
var _loadout: Array = []
var _passives: Dictionary
var _evolved := {}
var _ascension: AscensionSkills
var _player: Player
var _camera: BattleCamera
var _enemies: Array[Enemy]
var _launch_sword: Callable
var _sword_left := SWORD_INTERVAL
var _lightning_left := LIGHTNING_INTERVAL
var _heal_left := 0.0
var _flash_left := 0.0
var _lightning_points := PackedVector3Array()
var _orbit_angle := 0.0
var _orb_offsets := PackedVector3Array()
var _orb_contacts: Dictionary[int, int] = {}
var _next_contacts: Dictionary[int, int] = {}
var _storm_left := STORM_INTERVAL
var _fire_left := FIRE_INTERVAL
var _fire_zones: Array[Dictionary] = []
var _fire_mesh: CylinderMesh


func configure(player: Player, enemies: Array[Enemy], launch_sword: Callable, camera: BattleCamera,
		loadout: Array, passives := {}) -> void:
	_player = player
	_enemies = enemies
	_launch_sword = launch_sword
	_camera = camera
	_loadout = loadout.duplicate()
	_passives = passives.duplicate()
	_levels.resize(Catalog.SKILLS.size())
	_levels.fill(0)
	_selected.clear()
	for id: String in loadout:
		_selected.append(Catalog.SKILLS.find(id))
	var first := Catalog.SKILLS.find(Catalog.first_attack(loadout))
	if first >= 0:
		_levels[first] = 1
	_visuals.setup(ORB_RADIUS, ICE_RADIUS, LIGHTNING_RADIUS, CAP + 2, CAP)
	_ascension = AscensionSkills.new(_player, _enemies, _visuals)
	_player.dashed.connect(_ascension.on_dash_step)
	if _selected.has(Skill.BLINK):
		_player.hit.connect(_try_blink)


func roll_choices() -> Array[int]:
	var available: Array[int] = []
	var evolutions: Array[int] = []
	for skill in _selected:
		if _levels[skill] < CAP:
			available.append(skill)
		elif _can_evolve(skill):
			evolutions.append(skill + EVOLUTION_START)
	if available.is_empty() and evolutions.is_empty():
		return [Skill.MAX_HEALTH]
	available.shuffle()
	if not evolutions.is_empty():
		available.push_front(evolutions.pick_random())
	available.resize(mini(available.size(), 3))
	return available


func card_text(skill: int) -> String:
	if skill == Skill.MAX_HEALTH:
		return "+%d 生命上限" % HEALTH_BONUS
	if is_evolution_card(skill):
		var evolution: Dictionary = Catalog.EVOLUTIONS[Catalog.SKILLS[skill - EVOLUTION_START]]
		return "进化 · %s\n\n%s" % [evolution.name, evolution.card]
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
		Skill.SWORD_STORM:
			effect = "每 5 秒齐射 8 剑\n每剑 %d 伤害" % STORM_DAMAGE[tier]
		Skill.FIRE:
			effect = "每 4 秒生火 3 秒\n每秒 %d 伤害" % FIRE_DAMAGE[tier]
		Skill.BLINK:
			effect = "受击时 %d%%\n概率瞬移 300" % BLINK_CHANCE_PERCENT[tier]
		_:
			effect = _ascension.card_detail(Catalog.SKILLS[skill], tier)
	var action := "习得" if next_level == 1 else "升级"
	return "%s · %s\nLv%d\n\n%s" % [action, Catalog.SKILL_DATA[Catalog.SKILLS[skill]].name, next_level, effect]


func apply_upgrade(skill: int) -> void:
	if skill == Skill.MAX_HEALTH:
		_player.increase_max_health(HEALTH_BONUS)
		return
	if is_evolution_card(skill):
		var base := skill - EVOLUTION_START
		if _can_evolve(base):
			_evolved[base] = true
			_ascension.evolve(Catalog.SKILLS[base])
			if base == Skill.ICE:
				for enemy in _enemies:
					enemy.speed_multiplier = 1.0
				_visuals.hide_ice()
			if base == Skill.ORBS:
				_orb_offsets.clear()
				_visuals.update_orbs(_player.global_position, _orb_offsets)
		return
	if not _selected.has(skill) or _levels[skill] >= CAP:
		return
	_levels[skill] += 1
	if skill == Skill.HEAL:
		_heal_left = HEAL_INTERVAL[_levels[skill] - 1]


func is_evolution_card(choice: int) -> bool:
	return choice >= EVOLUTION_START


func _can_evolve(skill: int) -> bool:
	return _selected.has(skill) and _levels[skill] == CAP and not _evolved.has(skill) \
		and Catalog.evolution_matches(Catalog.SKILLS[skill], _loadout, _passives)


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
		_ascension.update_blades(delta, SWORD_DAMAGE[CAP - 1], ORBIT_RADIUS, ORBIT_SPEED)
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
	if orb_level > 0 and not _evolved.has(Skill.ORBS):
		_update_orbs(delta, orb_level)
		_visuals.update_orbs(_player.global_position, _orb_offsets)

	var ice_level := _levels[Skill.ICE]
	if ice_level > 0 and not _evolved.has(Skill.ICE):
		_update_ice(ice_level)
		_visuals.update_ice(_player.global_position)

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
			_cast_fire()


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
	var count := level
	var damage := _player.stats.damage(SWORD_DAMAGE[level - 1])
	# 多把剑错开出剑位置，但仍瞄准同一个最近的敌人。
	for i in range(count):
		var lateral := (float(i) - (count - 1) * 0.5) * 18.0
		var start := origin + direction.cross(Vector3.UP) * lateral - direction * (i * 22.0)
		_launch_sword.call(start, start.direction_to(target), damage)
	swords_cast.emit()


func _cast_lightning(level: int) -> void:
	var view := get_viewport().get_visible_rect()
	var candidates := PackedVector3Array()
	for enemy in _enemies:
		if not _camera.is_position_behind(enemy.global_position) and view.has_point(_camera.unproject_position(enemy.global_position)):
			candidates.append(enemy.global_position)
	var damage := _player.stats.damage(LIGHTNING_DAMAGE[level - 1])
	_lightning_points.clear()
	# 随机选屏内敌人落雷；可用目标不足时，余下的雷随机落在屏内。
	for i in range(level):
		var point: Vector3
		if not candidates.is_empty():
			var index := randi_range(0, candidates.size() - 1)
			point = candidates[index]
			candidates.remove_at(index)
		else:
			var screen_point := Vector2(randf_range(view.position.x, view.end.x), randf_range(view.position.y, view.end.y))
			point = _camera.ground_at(screen_point)
		_lightning_points.append(point)
		for j in range(_enemies.size() - 1, -1, -1):
			var enemy := _enemies[j]
			if point.distance_squared_to(enemy.global_position) <= LIGHTNING_RADIUS * LIGHTNING_RADIUS:
				enemy.take_damage(damage)
	_flash_left = LIGHTNING_FLASH_TIME
	_visuals.show_lightning(_lightning_points)
	_visuals.update_lightning(1.0)
	lightning_cast.emit()


func _update_orbs(delta: float, level: int) -> void:
	_orbit_angle = fposmod(_orbit_angle + ORBIT_SPEED * delta, TAU)
	var count := level + 2
	_orb_offsets.resize(count)
	for i in range(count):
		_orb_offsets[i] = BattlePlane.direction(_orbit_angle + TAU * i / count) * ORBIT_RADIUS

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


func _cast_storm(level: int) -> void:
	var origin := _player.global_position
	var damage := _player.stats.damage(STORM_DAMAGE[level - 1])
	for i in range(STORM_SWORDS):
		_launch_sword.call(origin, BattlePlane.direction(TAU * i / STORM_SWORDS), damage)
	swords_cast.emit()


func _cast_fire() -> void:
	if _enemies.is_empty():
		return
	if _fire_mesh == null:
		_fire_mesh = CylinderMesh.new()
		_fire_mesh.top_radius = FIRE_RADIUS
		_fire_mesh.bottom_radius = FIRE_RADIUS
		_fire_mesh.height = 0.8
		_fire_mesh.radial_segments = 32
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color("#ff7b38")
		material.albedo_color.a = 0.38
		_fire_mesh.material = material
	var target := _enemies[randi_range(0, _enemies.size() - 1)].global_position
	var visual := MeshInstance3D.new()
	visual.mesh = _fire_mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	visual.global_position = target + Vector3.UP
	_fire_zones.append({"center": target, "visual": visual, "seconds": 0.0, "ticks": 0})


func _update_fire(delta: float, level: int) -> void:
	for i in range(_fire_zones.size() - 1, -1, -1):
		var zone := _fire_zones[i]
		zone.seconds += delta
		while zone.ticks < FIRE_DURATION and zone.seconds + 0.000001 >= zone.ticks + 1:
			zone.ticks += 1
			var damage := _player.stats.damage(FIRE_DAMAGE[level - 1])
			for j in range(_enemies.size() - 1, -1, -1):
				var enemy := _enemies[j]
				if enemy.global_position.distance_squared_to(zone.center) <= FIRE_RADIUS * FIRE_RADIUS:
					enemy.take_damage(damage)
		if zone.ticks == FIRE_DURATION:
			zone.visual.queue_free()
			_fire_zones.remove_at(i)


func _try_blink() -> void:
	var level := _levels[Skill.BLINK]
	if level > 0 and _player.is_alive() and randf() < BLINK_CHANCE_PERCENT[level - 1] / 100.0:
		_player.blink(BLINK_DISTANCE)
