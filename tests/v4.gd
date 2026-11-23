extends SceneTree

const Catalog = preload("res://scripts/cultivation_catalog.gd")
const Equipment = preload("res://scripts/equipment_catalog.gd")
const SpawnManager = preload("res://scripts/spawn_manager.gd")
const DemonLord = preload("res://scenes/enemies/demon_lord.gd")
const BATTLE := "res://scenes/main.tscn"
const CAVE := "res://scenes/ui/cave_menu.tscn"
const Player = preload("res://scenes/player.gd")
const Skill = Catalog.Skill
const SAVE_PATH := "user://save.cfg"

var _save: Node
var _output := ""
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_save = root.get_node("SaveManager")
	var args := OS.get_cmdline_user_args()
	var data := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if not data.contains("/wanmoyuan-v4-test-") or _save.has_profile() or _save.load_error() != OK:
		printerr("请提供空的 wanmoyuan-v4-test-* 隔离 APPDATA。")
		quit(1)
		return
	var mode: String = args[0] if not args.is_empty() else ""
	var rendering := DisplayServer.get_name() != "headless"
	if mode in ["capture", "legacy", "stress", "loadout"] and args.size() == 2 and rendering:
		_output = args[1]
		if DirAccess.make_dir_recursive_absolute(_output) != OK:
			quit(1)
			return
	elif mode not in ["full", "legacy"] and not (mode == "stress" and rendering):
		printerr("用法：-- full | legacy | capture <输出目录> | stress | loadout <输出目录>")
		quit(1)
		return
	create_timer(95.0, true, false, true).timeout.connect(func() -> void:
		printerr("V4 测试超时")
		quit(1))
	seed(43001)
	match mode:
		"legacy": await _test_legacy()
		"stress": await _test_stress()
		"loadout":
			_expect(_save.settle_run(140500, false) == OK, "配装截图测试资金")
			for i in range(5):
				_expect(_save.breakthrough() == OK, "配装截图解锁")
			await _test_loadout_hints("选功法-条件已满足", "选功法-还缺搭档")
		_:
			_test_spawn_rules()
			await _test_campaign()
			await _test_evolutions()
			await _test_base_skills()
	if _failures == 0:
		print("V4 PASS: ", mode)
	# Headless stub audio needs a short mixer cycle to release a just-triggered WAV on quit.
	await create_timer(0.55, true, false, true).timeout
	quit(mini(1, _failures))


func _test_spawn_rules() -> void:
	var index := 0
	for id: String in Catalog.ABYSSES:
		var abyss: Dictionary = Catalog.ABYSSES[id]
		var spawns := SpawnManager.new(abyss)
		var center := Vector3(123, 0, -187)
		var state := {"warnings": 0, "slots": 2}
		var ring: Array[Vector3] = []
		var mix: Array[int] = []
		var warnings := func() -> void: state.warnings += 1
		var deny := func(_kind: int) -> bool: return false
		var batch := func(kind: int, at: Vector3) -> bool:
			if ring.size() >= state.slots:
				return false
			ring.append(at)
			mix.append(kind)
			return true
		_expect(is_equal_approx(spawns.interval_at(30), spawns.interval_at(0) / 1.20)
			and is_equal_approx(spawns.interval_at(300), 0.4), id + " 频率爬坡和下限")
		spawns.advance(56.90, 56.99, center, warnings, deny, batch)
		_expect(state.warnings == 0, id + " 57 秒前没有预警")
		spawns.advance(56.99, 57, center, warnings, deny, batch)
		_expect(state.warnings == 1 and ring.is_empty(), id + " 57 秒预警且尚未刷新")
		spawns.advance(59.99, 60, center, warnings, deny, batch)
		var count: int = [23, 27, 30, 34, 40][index]
		_expect(ring.size() == 2 and spawns._waves.size() == count - 2, id + " 满员时超出的兽潮排队")
		state.slots = 100
		spawns.advance(60, 60.1, Vector3.ZERO, warnings, deny, batch)
		_expect(ring.size() == count and spawns._waves.is_empty(), id + " 补齐整波")
		for i in range(ring.size()):
			var expected := Vector3(cos(TAU * i / count), 0, sin(TAU * i / count)) * 700
			_expect((ring[i] - center).distance_to(expected) < 0.02, id + " 原玩家位置 700 环形等角")
		_expect(mix.count(SpawnManager.Kind.GOLEM) == [0, 0, 0, 1, 2][index]
			and mix.count(SpawnManager.Kind.CROW) == floori(float(abyss.wave_count * abyss.crow_percent) / 100), id + " 兽潮混编")

		var regular := SpawnManager.new(abyss)
		var regular_mixed: Array[int] = []
		var record := func(kind: int) -> bool:
			regular_mixed.append(kind)
			return true
		regular.advance(0, 100.01 * regular.interval_at(0), center, warnings, record, func(_k, _p): return false)
		_expect(regular_mixed.count(SpawnManager.Kind.CROW) == [20, 30, 40, 45, 50][index], id + " 百只基础小怪鸦妖配比")
		regular = SpawnManager.new(abyss)
		regular_mixed.clear()
		regular.advance(0, abyss.golem_at - 0.01, center, warnings, record, func(_k, _p): return false)
		_expect(not regular_mixed.has(SpawnManager.Kind.GOLEM), id + " 石傀不提前")
		regular.advance(abyss.golem_at - 0.01, abyss.golem_at, center, warnings, record, func(_k, _p): return false)
		_expect(regular_mixed.count(SpawnManager.Kind.GOLEM) == 1, id + " 石傀首次刷新")
		index += 1


func _test_campaign() -> void:
	var cave := await _open_cave()
	cave._show_preparation()
	_expect(cave._abyss_buttons.deep.disabled and "需突破元婴" in cave._abyss_buttons.deep.text
		and cave._abyss_buttons.source.disabled and "需突破化神" in cave._abyss_buttons.source.text, "低境界第五层与第四层为灰色锁定")
	await _capture("01-层数与解锁")
	cave._hide_preparation()
	_expect(_save.realm() == "qi_refining", "从炼气开始")
	await _test_layer("outer", true)
	cave = await _open_cave()
	await _breakthrough(cave, "foundation", 500, 2.0)
	await _test_layer("middle")
	cave = await _open_cave()
	await _breakthrough(cave, "gold_core", 2000, 2.5)
	await _test_layer("inner")
	cave = await _open_cave()
	await _breakthrough(cave, "nascent_soul", 8000, 3.0, "07-突破元婴")
	_expect(_save.is_unlocked("deep") and not _save.is_unlocked("source"), "元婴解锁四层")
	await _test_layer("deep", false, "10-四层地相", "11-四层元婴装")
	cave = await _open_cave()
	await _breakthrough(cave, "spirit_transformation", 30000, 3.5, "08-突破化神")
	_expect(_save.is_unlocked("source"), "化神解锁五层")
	await _test_layer("source", false, "12-五层天相", "13-五层化神装")
	cave = await _open_cave()
	await _breakthrough(cave, "tribulation", 100000, 4.0, "09-突破渡劫")
	_expect(_save.skill_points() == 15 and cave._breakthrough.disabled and "渡劫" in cave._breakthrough.text, "渡劫到顶，五次共 15 点")
	await _test_layer("source", false, "", "14-五层额外渡劫装")
	var loaded := ConfigFile.new()
	_expect(loaded.load(SAVE_PATH) == OK and loaded.get_value("save", "save_version", 0) == 6, "存档 schema 为 6")
	var copy := _save.get_script().new() as Node
	_expect(copy._load_profile() == OK and copy.realm() == "tribulation" and copy.skill_points() == 15 and copy.storage() == _save.storage(), "V4 高阶掉装和总点数可重新读取")
	copy.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	for tier in range(3, 6):
		var lower := {"slot": "weapon", "tier": tier - 1}
		var upper := {"slot": "weapon", "tier": tier}
		_expect(is_equal_approx(Equipment.base_stats(upper).damage, 2.0 * Equipment.base_stats(lower).damage), "相邻装备基础属性翻倍")
		for i in range(100):
			_expect(Equipment.is_valid(Equipment.roll(tier, 1.0, rng)), "高阶装备词条可保存")
	var overpower := await _battle("outer")
	var wolf: Node = overpower._spawn_enemy(overpower._wolf_pool)
	var sword: int = overpower._player.stats.damage(10)
	_expect(sword == 40 and sword >= wolf.max_health and overpower._player.max_health == 400, "渡劫回外渊：一级御剑单发可杀满血妖狼，基础气血四倍")


func _breakthrough(cave: Node, realm: String, cost: int, power: float, shot := "") -> void:
	_expect(_save.breakthrough() == ERR_UNAVAILABLE, "未达所需灵石前不得突破")
	_expect(_save.settle_run(cost - _save.spirit_stones(), false) == OK, "隔离测试补齐正式突破费用")
	cave._refresh()
	var old_points: int = _save.skill_points()
	cave._breakthrough.pressed.emit()
	_expect(_save.realm() == realm and _save.spirit_stones() == 0 and _save.skill_points() == old_points + 3, realm + " 实际洞府按钮突破与扣费")
	_expect(cave._stat_values[0].text == str(roundi(100 * power)) and cave._stat_values[1].text == "×%.2f" % power
		and cave._stat_values[2].text == "220", realm + " 气血、攻击与移速面板")
	_expect(cave._flash.visible and cave._notice.text == "突破·" + _save.realm_name(), realm + " 金光与大字")
	if not shot.is_empty() and not _output.is_empty():
		await create_timer(0.20).timeout
		await _capture(shot)


func _test_layer(id: String, stage_demo := false, arrival := "", loot := "") -> void:
	var battle := await _battle(id)
	var duration := Catalog.BOSS_AT
	var maximum: int = {"outer": 800, "middle": 2400, "inner": 6400, "deep": 15000, "source": 32000}[id]
	if stage_demo:
		await _show_wave(battle)
	battle._elapsed = duration - 0.05
	battle._physics_process(0.02)
	_expect(not battle._boss_spawned, id + " 未到时不刷 Boss")
	battle._physics_process(0.04)
	var boss := _boss(battle)
	_expect(battle._boss_spawned and boss.max_health == maximum and int(battle._hud._boss_bar.max_value) == maximum, id + " 按时生成 Boss 及精确血量")
	boss.global_position = battle._player.global_position + Vector3(30, 0, -250)
	boss.set_physics_process(false)
	if not arrival.is_empty() and not _output.is_empty():
		await create_timer(0.30).timeout
		await _capture(arrival)
	if stage_demo:
		await _test_boss_stages(battle, boss)
	var origin: Vector3 = battle._player.global_position
	boss.global_position = origin + Vector3(12, 0, -170)
	boss.take_damage(boss.max_health)
	var drops := _drops(battle)
	var base_tier: int = Catalog.ABYSSES[id].tier
	var expected_bonus := 1 if id == "source" and _save.realm() == "tribulation" else 0
	var tiers := drops.map(func(drop: Node) -> int: return drop._item.tier)
	_expect(tiers.size() == 2 + expected_bonus and tiers.count(base_tier) == 2 and tiers.count(5) == expected_bonus,
		id + " Boss 正式装备掉落：普通两件及渡劫时恰好一件追加")
	await _capture(loot)
	var amount: int = {"outer": 200, "middle": 400, "inner": 800, "deep": 1600, "source": 3200}[id]
	_expect(battle._inventory.new_loot().size() == 2 + expected_bonus and battle._spirit_stones == amount, id + " 正式 Boss 奖励到账，灵石倍率")
	_expect(battle._run_won and battle._settlement_saved and _save.has_cleared(id), id + " 当帧正式结算")
	await create_timer(0.57, true, false, true).timeout
	_expect(battle._phase == battle.Phase.RESULT, id + " 胜利慢镜之后直接显示结果")
	if id in ["deep", "source"]:
		var regular := await _battle(id)
		var golem: Node = regular._spawn_enemy(regular._golem_pool)
		golem.take_damage(golem.max_health)
		var regular_drops := _drops(regular)
		_expect(regular_drops.size() == 1 and regular_drops.front()._item.tier == base_tier, id + " 石傀也掉对应等级的普通装备")


func _show_wave(battle: Node) -> void:
	battle._elapsed = 56.99
	battle._physics_process(0.02)
	_expect(battle._hud._wave_notice.visible and battle._hud._wave_notice.text == "兽潮将至", "实战 HUD 接到 57 秒预警")
	await _capture("02-兽潮预警")
	battle._elapsed = 59.99
	var previous: int = battle._living_enemies.size()
	battle._physics_process(0.02)
	_expect(battle._living_enemies.size() == previous + 23 and not battle._hud._wave_notice.visible, "60 秒在实战生成 23 只并结束预警")
	if not _output.is_empty():
		# 让实际怪物 AI 从 700 圆环走向镜头内，不重摆兽潮位置。
		battle._elapsed = 63.6
		battle._hud.set_survival_time(63, Catalog.RUN_SECONDS)
		Engine.time_scale = 3.0
		await create_timer(3.6).timeout
		Engine.time_scale = 1.0
		await _capture("03-兽潮围拢")


func _test_boss_stages(battle: Node, boss: DemonLord) -> void:
	var events := {"flames": 0, "summons": 0}
	boss.flame_cast.connect(func(_o, _d, _n): events.flames += 1)
	boss.minions_summoned.connect(func(_o): events.summons += 1)
	boss._update_attack(0.01)
	_expect(boss.stage == 1 and events.summons == 0 and events.flames == 0, "P1 无新增技能")
	boss.take_damage(199)
	_expect(boss.stage == 1, "高于 75% 不提前")
	boss.take_damage(1)
	var before: int = battle._living_enemies.size()
	boss._update_attack(0.01)
	battle._physics_process(0.01)
	_expect(boss.stage == 2 and events.summons == 1 and battle._living_enemies.size() == before + 6
		and is_equal_approx(boss._summon_left, 20.0), "75% 召六只混编小怪，20 秒")
	await _capture("04-二阶段召唤")
	boss.take_damage(200)
	boss._update_attack(0.01)
	boss._update_attack(0.99)
	_expect(boss.stage == 3 and boss._motion == DemonLord.Motion.WINDUP and is_equal_approx(boss._charge_left, 11.01)
		and boss.get_node("Body").material_override == boss.FLASH_MATERIAL, "50% 冲锋预警发亮一秒")
	await _capture("05-三阶段冲锋蓄力")
	boss._update_attack(0.01)
	_expect(boss._motion == DemonLord.Motion.CHARGE, "满一秒后开始冲锋")
	var position_before: Vector3 = boss.global_position
	boss._physics_process(1.0 / 60.0)
	_expect(boss.global_position.distance_to(position_before) > 8.0, "冲锋实际位移")
	boss.global_position = battle._player.global_position + Vector3.RIGHT * 56.0
	battle._player._invulnerable_left = 0.0
	var health: int = battle._player.health
	boss._update_attack(0.015)
	_expect(health - battle._player.health == 60, "冲锋命中 2× 接触伤害")
	boss.global_position = battle._player.global_position + Vector3(30, 0, -255)
	boss.take_damage(200)
	var flames: int = events.flames
	boss._update_attack(0.01)
	_expect(boss.stage == 4 and events.flames == flames + 5 and is_equal_approx(boss._barrage_left, 8.0)
		and is_equal_approx(boss._contact_interval(), 1.0 / pow(1.15, 3)), "25% 追加五发扇形池化弹幕，每阶段原始攻击更快")
	if not _output.is_empty():
		await create_timer(0.52).timeout
	await _capture("06-四阶段弹幕")


func _test_loadout_hints(matched := "15-暂停进化提示", missing := "") -> void:
	for id: String in ["sword_storm", "fire", "dash", "wisp", "bell", "shield"]:
		_expect(_save.learn_skill(id) == OK, "正式领悟 " + id)
	for i in range(3):
		_expect(_save.train_passive("focus") == OK, "正式凝神诀，加点 " + str(i + 1))
	var battle := await _battle("outer", ["sword", "sword_storm", "wisp"])
	var skills: Node = battle._skills
	skills.apply_upgrade(Skill.SWORD, 4)
	battle._open_game_menu()
	_expect("可进化 · 万剑归宗 ← 御剑术·满 + 万剑诀" in battle._game_menu._recipes.text
		and "九幽焚天 ← 幽冥鬼火·满 + 凝神诀·满" in battle._game_menu._recipes.text, "新暂停界面说明技能搭档及满级心法")
	if not _output.is_empty():
		await create_timer(0.35, true, false, true).timeout
	await _capture(matched)
	skills._selected.erase(Skill.SWORD_STORM)
	battle._game_menu.open(true, skills.slots(), skills.evolution_hints())
	_expect("可进化 · 万剑归宗" not in battle._game_menu._recipes.text, "局内缺搭档时提示不标为已达成")
	await _capture(missing)


func _test_evolutions() -> void:
	await _test_loadout_hints()
	# 正式总点数不足以点满所有心法，这里按进化路线分别用测试夹具提供搭档，
	# 而非放宽正式存档、领悟成本或装备上限。
	var valid_passives := {"body": 5, "spirit": 5, "wind": 3, "focus": 3}
	for id: String in Catalog.EVOLUTIONS:
		var rule: Dictionary = Catalog.EVOLUTIONS[id]
		var loadout := [id]
		if rule.has("partner"):
			loadout.append(rule.partner)
		if not loadout.has("sword"):
			loadout.append("sword")
		var test_loadout := loadout.duplicate()
		if test_loadout.size() < 3 and not test_loadout.has("fire"):
			test_loadout.append("fire")
		var battle := await _battle("outer", test_loadout)
		var player: Player = battle._player
		player.stats.configure("qi_refining", {}, {})
		player.refresh_equipment(true)
		var skills: Node = battle._skills
		skills._passives.clear()
		var base: int = Catalog.SKILLS.find(id)
		var gold := {"type": "evolution", "id": base, "rarity": "evolution"}
		while skills._levels[base] < 4:
			skills.apply_upgrade(base)
		skills._passives = valid_passives.duplicate()
		_expect(gold not in skills.roll_choices(), id + " 四级不能进化")
		skills.apply_upgrade(base)
		skills._passives.clear()
		var partner := Catalog.SKILLS.find(rule.get("partner", ""))
		if partner >= 0:
			skills._selected.erase(partner)
		_expect(gold not in skills.roll_choices(), id + " 缺搭档不进化")
		if partner >= 0:
			skills._selected.append(partner)
		skills._passives = valid_passives.duplicate()
		battle._xp = battle._xp_required
		battle._show_level_up()
		var card: Button = battle._upgrade_menu._buttons[0]
		_expect(battle._choices.front() == gold and card.has_theme_stylebox_override("normal") and rule.name in card.text,
			id + " 下一次升级首张金卡")
		if id in ["sword", "orbs", "wisp"]:
			await _capture("16-进化卡-" + str(rule.name))
		card.pressed.emit()
		var after_pick: Array = skills.roll_choices()
		_expect(skills._evolved.has(base) and after_pick.all(func(choice: Dictionary) -> bool:
			return choice.type == "stat" or choice.id != base)
			and skills._selected.size() == test_loadout.size() - int(partner >= 0), id + " 结果替换正确释放槽位")
		await _test_effect(battle, id)
		for selected: int in skills._selected:
			skills._levels[selected] = skills.CAP
			skills._evolved[selected] = true
		skills._learned = []
		var filled: Array = skills.roll_choices()
		_expect(filled.size() == 3 and filled.all(func(card: Dictionary) -> bool: return card.type == "stat"), id + " 卡池耗尽补足三张属性卡")
	var multi := await _battle("outer", ["sword", "sword_storm", "orbs", "ice"])
	var pool: Node = multi._skills
	pool._passives = valid_passives.duplicate()
	for id: int in [Skill.SWORD, Skill.ORBS, Skill.ICE]:
		pool._levels[id] = pool.CAP
	var seen := {}
	for i in range(60):
		var choices: Array = pool.roll_choices()
		_expect(choices.filter(func(card: Dictionary) -> bool: return card.type == "evolution").size() == 1, "同时满足也只出一张进化")
		seen[choices[0].id] = true
	_expect(seen.size() == 3, "三条同时满足时随机抽取")


func _test_effect(battle: Node, id: String) -> void:
	var skills: Node = battle._skills
	var v4: RefCounted = skills._ascension
	var player: Player = battle._player
	var origin := player.global_position
	var wolf: Node = battle._spawn_enemy_at(battle._wolf_pool, origin + Vector3.RIGHT * 72)
	wolf.set_physics_process(false)
	wolf._health = 1000
	match id:
		"sword":
			v4.update_blades(0.0, 20, 72.0, 2.4)
			v4.update_blades(0.5, 20, 72.0, 2.4)
			_expect(wolf._health == 970 and skills._visuals._blades.size() == 12, "万剑十二把，实际周期伤 30")
			await _capture("17-效果-万剑归宗")
		"lightning":
			v4._cast_thunderfire()
			_expect(wolf._shock_amp == 0.20 and wolf._shock_left == 2.0 and wolf._dots.thunderfire.remaining == 3, "雷火感电和 3 秒灼烧")
			wolf.take_damage(10)
			_expect(wolf._health == 958, "感电额外 20%")
		"orbs":
			player.take_damage(20, wolf)
			await process_frame
			_expect(player.health == 86 and wolf._health == 990, "玄武实际减伤和反伤")
			v4.update(0.0, 0.0, skills._levels)
			await _capture("18-效果-玄武真罡")
		"ice":
			v4._cast_freeze()
			_expect(wolf._frozen_left == 2.0, "冰封实际冻结")
		"heal":
			player.take_damage(20)
			_expect(player.health == 82, "生生不息受击额外回血")
			skills._heal_left = 0.0
			skills._physics_process(0.01)
			_expect(player.health == 100, "满级生生不息周期回血翻倍")
		"dash":
			v4._cast_dash(2)
			v4.on_dash_step(origin, origin + Vector3.RIGHT * 80)
			player.take_damage(20)
			_expect(wolf._health == 865 and player.health == 100 and v4._clocks.dash == 1.5, "瞬影三倍伤害、1.5 秒、途中无敌")
		"wisp":
			v4._update_wisps(0.0, 5)
			_expect(skills._visuals._wisps.filter(func(node: Node3D): return node.visible).size() == 15, "满级九幽鬼火十五团")
			await _capture("19-效果-九幽焚天")
			v4._update_wisps(0.5, 5)
			_expect(wolf._health == 982, "九幽原爆伤 30 的 60% 每半秒")
		"bell":
			v4._cast_bell(2)
			_expect(wolf._slow_factor == 0.4 and wolf._slow_left == 3.0 and v4._bell_left == 3.0, "万魂减速与领域")
			v4._update_bell(3.0)
			_expect(wolf._health == 888, "万魂结算基础 40 加六跳 12")
		"shield":
			player.health = 50
			v4._cast_shield(2)
			player.take_damage(40)
			player._update_shield(1.0)
			_expect(player.shield == 200 and player.health == 53, "玄武降世 240 护盾吸收 40，持盾一秒回复 3%")


func _test_base_skills() -> void:
	var battle := await _battle("outer")
	var skills: Node = battle._skills
	var player: Player = battle._player
	player.stats.configure("qi_refining", {}, {})
	var origin := player.global_position
	var wolf: Node = battle._spawn_enemy_at(battle._wolf_pool, origin + Vector3.RIGHT * 72)
	wolf.set_physics_process(false)
	wolf._health = 1000
	for id: int in [Skill.DASH, Skill.WISP, Skill.BELL, Skill.SHIELD]:
		skills.apply_upgrade(id)
	var v4: RefCounted = skills._ascension
	v4.update(0.0, 2.5, skills._levels)
	_expect(skills._visuals._wisps[0].visible and player._dash_left == 0.0, "基础鬼火环绕")
	v4.update(0.5, 0.5, skills._levels)
	_expect(wolf._health == 989 and player._dash_left > 0.0 and not player._dash_invincible, "基础鬼火跳伤 11，基础突进 3 秒")
	v4.on_dash_step(origin, origin + Vector3.RIGHT * 90)
	v4.on_dash_step(origin, origin + Vector3.RIGHT * 95)
	_expect(wolf._health == 969, "基础突进路径单次 20 伤害")
	v4.update(0.0, 3.0, skills._levels)
	_expect(wolf._health == 954 and wolf._slow_factor == 0.6 and wolf._slow_left == 2.0, "基础铃铛第六秒伤害和减速")
	v4._clocks.shield = 0.01
	v4.update(0.0, 0.01, skills._levels)
	_expect(player.shield == 30 and is_equal_approx(v4._clocks.shield, 20.0), "基础护印 30，间隔 20 秒")
	player._update_shield(5.0)
	_expect(player.shield == 0, "基础护印五秒后清除")


func _test_legacy() -> void:
	var fixture := ConfigFile.new()
	fixture.set_value("save", "version", 1)
	var data := {
		"realm": "gold_core", "spirit_stones": 7819, "skill_points": 2,
		"learned_skills": ["sword", "lightning", "orbs", "ice", "heal", "fire"],
		"passive_levels": {"body": 2}, "secret_realm_progress": {"outer": true, "middle": true},
		"equipment_storage": [{"id": 41, "slot": "weapon", "tier": 1, "quality": 2, "affixes": {"damage": 0.22, "kill_heal": 2}}],
		"equipped": {"weapon": 41},
	}
	for key: String in data:
		fixture.set_value("profile", key, data[key])
	_expect(fixture.save(SAVE_PATH) == OK and _save._load_profile() == OK, "旧档完整载入")
	data["iron"] = 0
	data["forge_count"] = 0
	data.equipment_storage[0]["star"] = 0
	_expect(_save._profile == data, "仅补默认字段")
	_expect(not _save.is_unlocked("deep") and not _save.learned_skills().has("wisp") and not _save.has_cleared("source"), "新增内容默认未达成")
	var before := FileAccess.get_file_as_string(SAVE_PATH)
	_expect("version=1" in before and "save_version" not in before, "只读不重写旧档")
	_expect(_save.save_profile() == OK, "正常保存写入新版")
	var after := FileAccess.get_file_as_string(SAVE_PATH)
	_expect("save_version=6" in after and _save._load_profile() == OK and _save._profile == data, "新版格式重读不丢数据")
	print("LEGACY: 筑基武器 id=41、7819 灵石、金丹、2 功法点、离火印、锻体诀及通关进度均保留。")
	if not _output.is_empty():
		await _open_cave()
		await _capture("20-旧档迁移")


func _test_stress() -> void:
	_expect(_save.settle_run(140500, false) == OK, "测试资金")
	for i in range(5):
		_expect(_save.breakthrough() == OK, "压测解锁")
	var battle := await _battle("source", ["sword", "lightning", "orbs", "ice"])
	battle._skills.set_physics_process(true)
	battle._skills._levels[Skill.SWORD] = 0
	battle._player.accepts_damage = false # 固定模拟不因死亡结束；怪物及弹道依然真实运行。
	var center: Vector3 = battle._player.global_position
	battle._elapsed = 239.95
	battle._spawns._next_wave = 240.0
	battle._spawns._next_golem = 240.0
	battle._physics_process(0.02)
	battle._physics_process(0.04)
	var boss := _boss(battle)
	boss.global_position = center + Vector3(55, 0, -275)
	boss.take_damage(24000)
	while battle._active_enemy_count < 100:
		var i: int = battle._active_enemy_count
		var at := center + Vector3(cos(i * TAU / 73), 0, sin(i * TAU / 73)) * (280.0 + i % 4 * 115)
		battle._spawn_kind_at(SpawnManager.Kind.CROW if i % 2 == 0 else SpawnManager.Kind.WOLF, at)
	_expect(battle._active_enemy_count == 100 and boss.stage == 4, "五层 240 秒实际兽潮、100 怪及四阶段")
	var shots := {"barrages": 0}
	boss.action_started.connect(func(action: String): shots.barrages += int(action == "魔焰弹幕"))
	if not _output.is_empty():
		await create_timer(0.45).timeout
		await _capture("21-五层-兽潮与弹幕")
	var times := PackedFloat32Array()
	var start := Time.get_ticks_usec()
	var last := start
	while Time.get_ticks_usec() - start < 20000000:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	times.sort()
	_expect(battle._active_enemy_count == 100 and shots.barrages >= 2, "压测保持 100 怪，Boss 持续弹幕")
	print("DESKTOP STRESS: %d frames, %.2f average FPS, %.2f ms P95; %d barrages" % [
		times.size(), times.size() / ((last - start) / 1000000.0), times[floori((times.size() - 1) * 0.95)], shots.barrages])


func _boss(battle: Node) -> DemonLord:
	for enemy in battle._living_enemies:
		if enemy is DemonLord:
			return enemy
	return null


func _drops(battle: Node) -> Array[Node]:
	return battle.get_node("Pickups/EquipmentDrops").get_children().filter(func(drop: Node): return drop.visible)


func _battle(id: String, test_skills: Array = []) -> Node:
	var battle := (load(BATTLE) as PackedScene).instantiate()
	_expect(battle.configure_run(id), "可配置秘境 " + id)
	await _change(battle)
	battle.set_physics_process(false)
	battle._skills.set_physics_process(false)
	var skills: Node = battle._skills
	for active: String in test_skills:
		if active != "sword":
			skills.apply_upgrade(Catalog.SKILLS.find(active))
	battle._loot_rng.seed = 4300
	return battle


func _open_cave() -> Node:
	return await _change((load(CAVE) as PackedScene).instantiate())


func _change(next: Node) -> Node:
	_expect(change_scene_to_node(next) == OK, "切换场景")
	paused = false
	await scene_changed
	return current_scene


func _capture(name: String) -> void:
	if name.is_empty() or _output.is_empty():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(_output.path_join(name + ".png")) == OK, "截图 " + name)


func _expect(pass_: bool, description: String) -> void:
	if not pass_:
		_failures += 1
		printerr("FAIL: ", description)
