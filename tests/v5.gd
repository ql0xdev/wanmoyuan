extends SceneTree

const Catalog = preload("res://scripts/cultivation_catalog.gd")
const Spawns = preload("res://scripts/spawn_manager.gd")
const DemonLord = preload("res://scenes/enemies/demon_lord.gd")
const Enemy = preload("res://scenes/enemies/enemy.gd")
const MagnetPickup = preload("res://scenes/pickups/magnet_pickup.gd")
const Skill = Catalog.Skill
const CAVE := "res://scenes/ui/cave_menu.tscn"
const BATTLE := "res://scenes/main.tscn"
const SAVE := "user://save.cfg"
const V4_ITEM := {"slot": "weapon", "tier": 1, "quality": 1, "affixes": {"damage": 0.12}}
var _save: Node
var _out := ""
var _failures := 0
var _notes: Array[Node] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_save = root.get_node("SaveManager")
	var data := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if not data.contains("/wanmoyuan-v5-test-"):
		printerr("需要隔离的 wanmoyuan-v5-test-* APPDATA")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if not args.is_empty() else "full"
	if args.size() >= 2 and DisplayServer.get_name() != "headless":
		_out = args[1]
		if DirAccess.make_dir_recursive_absolute(_out) != OK:
			quit(1)
			return
	create_timer(85.0, true, false, true).timeout.connect(func() -> void:
		printerr("V5.0 测试超时")
		quit(1))
	seed(5500)
	match mode:
		"full", "capture":
			_expect(not _save.has_profile() and _save.load_error() == OK, "功能回归用空档")
			_check_tables()
			await _opening_and_cards()
			await _pickup_values()
			await _wave()
			await _auras_and_hit_stop()
			await _swords()
			await _all_evolutions()
			await _time_and_settlement()
		"legacy":
			await _legacy(args[2] if args.size() >= 3 else "")
		"pickup":
			await _opening_and_cards()
			await _pickup_values()
		"stress":
			await _stress()
		_:
			_expect(false, "full | capture <目录> | pickup <目录> | legacy <目录> [V4.1 存档路径] | stress <目录>")
	if _failures == 0:
		print("V5.0 PASS: ", mode)
	await create_timer(0.3, true, false, true).timeout
	quit(mini(_failures, 1))


func _check_tables() -> void:
	var i := 0
	for id: String in Catalog.ABYSSES:
		var abyss: Dictionary = Catalog.ABYSSES[id]
		_expect(abyss.duration == 300 and abyss.wave_count == [23, 27, 30, 33, 38][i]
			and abyss.wave_golems == [0, 0, 0, 1, 2][i] and abyss.golem_at == [120, 90, 60, 45, 30][i]
			and abyss.crow_percent == [20, 30, 40, 45, 50][i], id + " 时间与兽潮表")
		_expect(abyss.health == [1.0, 2.5, 6.0, 15.0, 40.0][i] and abyss.damage == [1.0, 2.0, 4.0, 8.0, 16.0][i]
			and abyss.stones == [1, 2, 4, 8, 16][i], id + " 怪物数值与倍率不变")
		var spawns := Spawns.new(abyss)
		_expect(is_equal_approx(spawns.interval_at(30), spawns.interval_at(0) / 1.2) and spawns.interval_at(300) == 0.4,
			id + " 刷怪坡度与下限")
		i += 1
	_expect(Catalog.EVOLUTIONS.size() == 9 and Catalog.BOSS_AT == 240, "九组进化和 240 秒魔尊")


func _opening_and_cards() -> void:
	_expect(_save.settle_run(2500, false) == OK and _save.breakthrough() == OK and _save.breakthrough() == OK, "准备洞府")
	for id: String in ["sword_storm", "fire", "blink", "dash"]:
		_expect(_save.learn_skill(id) == OK, "洞府实际领悟 " + id)
	var cave := await _scene(CAVE)
	cave._enter_battle()
	_expect(cave._prep_options.get_child_count() == Catalog.ABYSSES.size() + 1, "仅有秘境选择，不再挑选携带功法")
	await _capture("验收08a-开战只选择秘境")
	cave._enter_battle()
	await scene_changed
	var battle := current_scene
	battle.set_physics_process(false)
	battle._skills.set_physics_process(false)
	var skills: Node = battle._skills
	_expect(skills._selected == [Skill.SWORD] and skills._levels[Skill.SWORD] == 1
		and battle._hud._skill_bar._slots.size() == 8 and battle._hud._skill_bar._ranks[0].text == "Lv1"
		and battle._hud._skill_bar._ranks[1].text.is_empty(), "首格御剑术 Lv1，其余七格为空")
	await _capture("验收08b-默认御剑术和八格栏")
	var chosen_seed := -1
	for n in range(200):
		skills._upgrade_rng.seed = n
		if skills.roll_choices().any(func(card: Dictionary) -> bool: return card.type == "new" and card.id == Skill.SWORD_STORM):
			chosen_seed = n
			break
	skills._upgrade_rng.seed = chosen_seed
	var wolf: Enemy = battle._spawn_enemy_at(battle._wolf_pool, Vector3(250, 0, -170))
	wolf.stone_drop_chance = 0.0
	wolf.take_damage(wolf.max_health)
	var drops := _visible_pickups(battle, "spirit_crystal.tscn")
	_expect(drops.size() == 1 and drops[0].amount == 20, "妖狼死亡掉一颗价值 20 的修为灵石")
	_expect(battle._xp == 0 and not battle._upgrade_menu.visible, "击杀本身不涨修为")
	if drops.is_empty():
		return
	var crystal: MagnetPickup = drops[0]
	var drop_at := crystal.global_position
	crystal._physics_process(0.50)
	_expect(crystal.visible and crystal.global_position == drop_at and battle._xp == 0, "距离过远，灵石留在地上")
	if not _out.is_empty():
		await create_timer(0.65).timeout
	await _capture("返修01-击杀掉灵石但修为不涨")
	battle._player.global_position = drop_at + Vector3.RIGHT * 55
	crystal._physics_process(0.05)
	_expect(crystal._magnet_active and crystal.visible and battle._xp == 0, "进拾取范围开始磁吸，入身前不加修为")
	crystal._physics_process(0.35)
	await process_frame
	_expect(not crystal.visible and battle._upgrade_menu.visible and battle._xp == 20 and battle._spirit_stones == 0,
		"拾取完成才增加修为并弹牌，不计入可带走灵石")
	var index := -1
	for j in range(battle._choices.size()):
		if battle._choices[j].type == "new" and battle._choices[j].id == Skill.SWORD_STORM:
			index = j
	_expect(index >= 0 and battle._choices.size() == 3, "已领悟未学的万剑诀进入三选一")
	await _capture("返修02-拾取灵石后弹出三选一")
	if index >= 0:
		battle._upgrade_menu._buttons[index].pressed.emit()
	_expect(battle._level == 2 and battle._xp_required == 26 and battle._xp == 0 and skills._levels[Skill.SWORD_STORM] > 0,
		"实际选择后习得，当前等级指数重算")
	var levels := []
	for level in range(1, 8):
		levels.append(battle.cultivation_required(level))
	_expect(levels == [20, 26, 35, 46, 61, 80, 106], "按公式四舍五入，非上次整数累乘")
	skills._upgrade_rng.seed = 8040
	var rare := 0
	for n in range(1000):
		for card: Dictionary in skills.roll_choices():
			rare += int(card.rarity == "rare")
			_expect(card.type == "stat" or card.id not in [Skill.WISP, Skill.BELL, Skill.SHIELD], "未领悟永不入池")
	_expect(rare >= 200 and rare <= 285, "V4.1 每卡 8% 珍稀固定种子抽验")
	for id: int in [Skill.LIGHTNING, Skill.ORBS, Skill.ICE, Skill.HEAL, Skill.FIRE, Skill.BLINK, Skill.DASH]:
		skills.apply_upgrade(id)
	battle._hud.set_skills(skills.slots())
	_expect(skills._selected.size() == 8 and skills._levels[Skill.DASH] == 0, "满八格拒绝再学")
	for n in range(100):
		_expect(skills.roll_choices().all(func(card: Dictionary) -> bool: return card.type != "new"), "满栏不再给新功法")
	battle._xp = battle._xp_required
	battle._show_level_up()
	await _capture("验收09b-八格已满只抽升级和属性")
	battle._upgrade_menu.hide()
	battle._xp = 0
	paused = false
	skills.apply_upgrade(Skill.SWORD, 4)
	battle._hud.set_skills(skills.slots())
	battle._open_game_menu()
	_expect("可进化 · 万剑归宗" in battle._game_menu._recipes.text
		and battle._game_menu._skill_bar._ranks[0].text == "Lv5", "暂停菜单同步状态和配方")
	if not _out.is_empty():
		await create_timer(0.34, true, false, true).timeout
	await _capture("验收10a-暂停八格及进化配方")
	battle._game_menu._back_pressed()
	battle._xp = battle._xp_required
	battle._show_level_up()
	_expect(battle._choices[0] == {"type": "evolution", "id": Skill.SWORD, "rarity": "evolution"}
		and Catalog.evolution_recipe("sword") in battle._upgrade_menu._buttons[0].text, "下次升级必出万剑归宗及配方")
	await _capture("验收10b-金卡万剑归宗组合说明")
	battle._upgrade_menu._buttons[0].pressed.emit()
	_expect(skills._selected.size() == 7 and skills._levels[Skill.SWORD_STORM] == 0
		and skills.slots()[0].name == "万剑归宗", "以一个进化技能替换两项，释放一格")
	skills.apply_upgrade(Skill.DASH)
	_expect(skills._levels[Skill.DASH] == 1, "有空位后可重新学习另一门功法")
	skills._physics_process(0.01)
	_expect(skills._ascension._blade_offsets.size() == 12, "进化环绕剑实际 12 把")
	await _capture("验收10c-进化后十二剑和腾出一格")


func _pickup_values() -> void:
	var battle := await _battle("outer")
	var golem: Enemy = battle._spawn_enemy_at(battle._golem_pool, Vector3(320, 0, -170))
	golem.take_damage(golem.max_health)
	var gold := _visible_pickups(battle, "spirit_stone.tscn")
	var blue := _visible_pickups(battle, "spirit_crystal.tscn")
	_expect(gold.size() == 1 and gold[0].amount == 30 and blue.size() == 1 and blue[0].amount == 100, "石傀金色掉落原值，修为灵石合成一颗")
	if gold.is_empty() or blue.is_empty():
		return
	battle._player.global_position = gold[0].global_position
	gold[0]._physics_process(0.35)
	_expect(battle._spirit_stones == 30 and battle._xp == 0 and blue[0].visible, "金色灵石只入钱包，蓝色尚未拾取")
	battle._open_game_menu()
	battle._retreat_from_battle()
	_expect(battle._settlement_saved and battle._xp == 0 and not battle._upgrade_menu.visible, "未捡的蓝色灵石不会补发")
	var body := battle._player.get_node("Body") as MeshInstance3D
	var bounds := body.transform * body.get_aabb()
	var shape := battle._player.get_node("CollisionShape3D").shape as CylinderShape3D
	_expect(absf(bounds.position.y) < 0.01 and is_equal_approx(bounds.size.y, 108.0)
		and shape.radius == 16.0 and shape.height == 32.0, "角色模型贴地变矮，碰撞体原样")


func _visible_pickups(battle: Node, basename: String) -> Array[Node]:
	return battle.get_node("Pickups").get_children().filter(func(node: Node) -> bool:
		return node is MagnetPickup and node.visible and node.scene_file_path.ends_with(basename))


func _wave() -> void:
	var battle := await _battle("outer")
	battle._player.accepts_damage = false
	battle._elapsed = 56.99
	battle._physics_process(0.02)
	_expect(battle._hud._wave_notice.visible and battle._living_enemies.is_empty(), "57 秒预警，无提前刷怪")
	await _capture("验收03a-57秒兽潮预警")
	battle._elapsed = 59.99
	battle._physics_process(0.02)
	var enemies: Array = battle._living_enemies.duplicate()
	_expect(enemies.size() == 23 and not battle._hud._wave_notice.visible, "60 秒正好生成 23 只")
	var cam: Camera3D = battle._camera.presentation
	for enemy: Enemy in enemies:
		_expect(enemy.global_position.length() >= 699.9 and not root.get_visible_rect().has_point(cam.unproject_position(enemy.global_position)),
			"实际生成在镜头外，距离不少于 700")
	if not _out.is_empty():
		for enemy: Enemy in enemies:
			enemy.set_physics_process(false)
		# 用验收专用俯视机位拍刚生成的那批敌人，不移动或增减任何怪物。
		var rect := Rect2(Vector2(enemies[0].position.x, enemies[0].position.z), Vector2.ZERO)
		for enemy: Enemy in enemies:
			rect = rect.expand(Vector2(enemy.position.x, enemy.position.z))
		var overhead := Camera3D.new()
		overhead.projection = Camera3D.PROJECTION_ORTHOGONAL
		var viewport_size := root.get_visible_rect().size
		overhead.size = maxf(rect.size.x / (viewport_size.x / viewport_size.y), rect.size.y) * 1.52
		overhead.far = 9000.0
		battle.add_child(overhead)
		overhead.global_position = Vector3(rect.get_center().x, 2900.0, rect.get_center().y)
		overhead.rotation.x = -PI / 2.0
		overhead.make_current()
		battle._hud.hide()
		var numbered := 0
		for j in range(enemies.size()):
			var at := overhead.unproject_position(enemies[j].global_position) + Vector2(7, -12)
			_mark(battle, at, "%02d" % (j + 1))
			numbered += int(root.get_visible_rect().has_point(at))
		_expect(numbered == 23, "图内完整标注兽潮 01–23")
		_mark(battle, Vector2(42, 105), "01:00 · 外渊首波 23 只\n出生原位 · 验收俯视机位")
		_mark(battle, Vector2(42, viewport_size.y - 100), "01–23 = 实际生成的 23 个怪物节点")
	await _capture("验收03-兽潮第一波23只")
	_clear_marks()


func _auras_and_hit_stop() -> void:
	var battle := await _battle("outer")
	var skills: Node = battle._skills
	battle._player.stats.configure("qi_refining", {}, {})
	skills.apply_upgrade(Skill.ORBS)
	battle._hud.set_skills(skills.slots())
	var wolf: Enemy = battle._spawn_enemy_at(battle._wolf_pool, Vector3(45, 0, 4))
	wolf.set_physics_process(false)
	skills._update_orbs(0.0, 1)
	skills._update_orbs(0.49, 1)
	_expect(wolf._health == 20, "圈内不足 0.5 秒不跳")
	skills._update_orbs(0.01, 1)
	_expect(wolf._health == 15, "第一跳 8 × 60% 取整为 5")
	_enemy_health(battle, wolf, "0.50 秒 · 第一跳")
	await _capture("验收05a-护体罡气第一跳")
	_clear_marks()
	skills._update_orbs(0.50, 1)
	_expect(wolf._health == 10, "圈内站满第二间隔继续扣血")
	_enemy_health(battle, wolf, "1.00 秒 · 第二跳")
	await _capture("验收05b-护体罡气第二跳")
	_clear_marks()
	wolf.global_position = Vector3(230, 0, 4)
	skills._update_orbs(0.60, 1)
	_expect(wolf._health == 10, "出圈不再跳伤")
	_enemy_health(battle, wolf, "1.60 秒 · 出圈血量不变")
	await _capture("验收05c-出圈停止跳伤")
	_clear_marks()
	wolf.global_position = Vector3(45, 0, 4)
	skills._update_orbs(0.0, 1)
	skills._update_orbs(0.49, 1)
	_expect(wolf._health == 10, "重新进入重新计时")
	skills._update_orbs(0.01, 1)
	_expect(wolf._health == 5, "重新进入半秒再扣血")

	var hit_events := []
	battle.hit_stop_triggered.connect(func(kills: int): hit_events.append([kills, Time.get_ticks_usec()]))
	for i in range(5):
		var victim: Enemy = battle._spawn_enemy_at(battle._wolf_pool, Vector3(26, 0, -200) + Vector3.RIGHT * i * 5)
		victim.set_physics_process(false)
		victim._health = 1
	skills._cast_lightning(1)
	# 落雷随机点只在候选间随机；狼留在护体圈内可能被选中，故用明确的范围震荡补测。
	if hit_events.is_empty():
		skills._ascension._cast_bell(0)
	_expect(hit_events.size() == 1 and hit_events[0][0] >= 5 and Engine.time_scale == 0.05, "真实单次范围伤害五杀触发")
	_mark(battle, Vector2(42, 410), "顿帧触发日志\n单次伤害击杀 %d 只非 Boss\nEngine.time_scale = %.2f · 0.060 s" % [
		hit_events[0][0] if not hit_events.is_empty() else 0, Engine.time_scale])
	print("HIT STOP: event=", hit_events, " scale=", Engine.time_scale)
	battle._try_hit_stop(5)
	await _capture("验收07-五杀顿帧触发日志")
	await create_timer(0.085, true, false, true).timeout
	_expect(Engine.time_scale == 1.0 and hit_events.size() == 1, "实时时钟恢复并限制 0.5 秒内重复触发")
	_clear_marks()


func _swords() -> void:
	var battle := await _battle("outer")
	var skills: Node = battle._skills
	var wolf: Enemy = battle._spawn_enemy_at(battle._wolf_pool, Vector3(325, 0, -485))
	wolf.set_physics_process(false)
	var shots := []
	var launch: Callable = skills._launch_sword
	skills._launch_sword = func(at: Vector3, direction: Vector3, amount: int, reach: float):
		shots.append([at, direction, amount, reach])
		launch.call(at, direction, amount, reach)
	for level: int in [1, 5]:
		shots.clear()
		skills._levels[Skill.SWORD] = level
		battle._hud.set_skills(skills.slots())
		skills._cast_swords(level)
		var length := 1800 if level == 1 else 2340
		_expect(shots.size() == (1 if level == 1 else 8) and is_equal_approx(shots[0][3], 1.0 if level == 1 else 1.3),
			"发射数和真实射程系数")
		var swords := battle.get_node("Projectiles").get_children().filter(func(node: Node3D) -> bool:
			return node.visible and node.scene_file_path.ends_with("flying_sword.tscn"))
		for j in range(swords.size()):
			var sword: Node3D = swords[j]
			sword.set_physics_process(false)
			var reach: float = sword._time_left * sword.SPEED
			_expect(is_equal_approx(reach, length), "真实弹道生命周期对应距离")
			sword.global_position += sword._direction * 360.0
			if not _out.is_empty():
				_mark(battle, battle._camera.presentation.unproject_position(sword.global_position + Vector3.UP * 48.0), str(j + 1), 21)
		_mark(battle, Vector2(42, 375), "御剑术 Lv%d · 同一视角\n%02d 把飞剑 / 射程 %d" % [level, shots.size(), length])
		await _capture("验收06%s-御剑术Lv%d" % ["a" if level == 1 else "b", level])
		_clear_marks()
		for sword: Node3D in swords:
			sword.set_physics_process(true)
			battle._recycle_sword(sword)


func _all_evolutions() -> void:
	for id: String in Catalog.EVOLUTIONS:
		var battle := await _battle("outer")
		var skills: Node = battle._skills
		skills._learned = Catalog.SKILLS
		var base := Catalog.SKILLS.find(id)
		var rule: Dictionary = Catalog.EVOLUTIONS[id]
		skills._passives = {"body": 5, "spirit": 5, "wind": 3, "focus": 3}
		var partner := Catalog.SKILLS.find(rule.get("partner", ""))
		if partner >= 0:
			skills.apply_upgrade(partner)
		skills.apply_upgrade(base, 4 - skills._levels[base])
		_expect(not skills._can_evolve(base), id + " Lv4 不可进化")
		skills.apply_upgrade(base)
		var old: Dictionary = skills._passives
		if partner >= 0:
			skills._selected.erase(partner)
		else:
			skills._passives = {}
		_expect(not skills._can_evolve(base), id + " 缺搭档或满级心法不能进化")
		if partner >= 0:
			skills._selected.append(partner)
		skills._passives = old
		var size: int = skills._selected.size()
		var card: Dictionary = skills.roll_choices()[0]
		_expect(card.type == "evolution" and card.id == base, id + " 必出唯一进化卡")
		skills.apply_card(card)
		_expect(not skills._can_evolve(base) and skills._selected.size() == size - int(partner >= 0), id + " 替换槽位正确")


func _time_and_settlement() -> void:
	var battle := await _battle("outer")
	battle._elapsed = 239.95
	battle._physics_process(0.02)
	_expect(not battle._boss_spawned, "239.97 不刷 Boss")
	battle._physics_process(0.035)
	_expect(battle._boss_spawned and "04:00 / 05:00" == battle._hud._time_label.text, "240 秒刷 Boss；计时总长 300")
	var boss: DemonLord = battle._living_enemies.filter(func(enemy: Enemy) -> bool: return enemy is DemonLord)[0]
	boss.global_position = Vector3(180, 0, -310)
	boss.set_physics_process(false)
	await create_timer(0.20).timeout
	await _capture("验收11a-240秒魔尊登场总长300秒")
	var before: int = _save.spirit_stones()
	var gear: int = _save.equipment_count()
	var slow_hits := []
	battle.hit_stop_triggered.connect(func(kills: int): slow_hits.append(kills))
	boss.take_damage(boss.max_health)
	_expect(battle._settlement_saved and _save.spirit_stones() == before + 200 and _save.equipment_count() == gear + 2
		and _save.has_cleared("outer") and slow_hits.is_empty(), "Boss 当帧结算、奖励不丢、不触发五杀顿帧")
	await create_timer(0.61, true, false, true).timeout
	_expect(paused and battle._phase == battle.Phase.RESULT and battle._run_won and Engine.time_scale == 1.0, "胜利过场结束进入结果")
	await _capture("验收11b-击杀魔尊提前结算")
	battle = await _battle("middle")
	battle._elapsed = 299.95
	battle._boss_spawned = true
	battle._physics_process(0.02)
	_expect(not battle._result_menu.visible, "300 秒前不做存活结算")
	battle._physics_process(0.04)
	_expect(battle._result_menu._title.text == "存活结算" and "05:00" in battle._result_menu._stats.text
		and battle._settlement_saved and not _save.has_cleared("middle"), "300 秒存活结算，不当作击杀 Boss")
	await _capture("验收11c-满300秒存活结算")


func _legacy(path: String) -> void:
	var config := ConfigFile.new()
	if path.is_empty():
		var fixture := {
			"realm": "gold_core", "spirit_stones": 7381, "skill_points": 2, "iron": 42, "forge_count": 23,
			"learned_skills": Catalog.STARTER_SKILLS + ["sword_storm"], "passive_levels": {"body": 2},
			"equipment_storage": [V4_ITEM.merged({"id": 41, "star": 2})], "equipped": {"weapon": 41},
			"secret_realm_progress": {"outer": true}, "loadout": ["fire"],
		}
		config.set_value("save", "save_version", 5)
		for key: String in fixture:
			config.set_value("profile", key, fixture[key])
	else:
		_expect(config.load(path) == OK and config.get_value("save", "save_version", 0) == 5, "V4.1 实际写出的 V5 存档")
		config.set_value("profile", "loadout", ["fire"])
	var expected := {}
	for key: String in config.get_section_keys("profile"):
		if key != "loadout":
			expected[key] = config.get_value("profile", key)
	_expect(config.save(SAVE) == OK and _save._load_profile() == OK and _save._profile == expected, "所有有效字段完整加载")
	_expect("save_version=5" in FileAccess.get_file_as_string(SAVE) and _save.save_profile() == OK
		and "save_version=6" in FileAccess.get_file_as_string(SAVE) and _save._load_profile() == OK
		and _save._profile == expected and "loadout=" not in FileAccess.get_file_as_string(SAVE), "首次正常写档到 V6，弃用配置")
	var cave := await _scene(CAVE)
	await _capture("验收12a-旧档境界灵石及玄铁")
	cave._tabs.current_tab = 2
	await process_frame
	if not expected.equipment_storage.is_empty():
		cave._storage._select(expected.equipment_storage[0].id)
	await _capture("验收12b-旧档装备及星级")
	cave._tabs.current_tab = 1
	await _capture("验收12c-旧档功法点和已领悟")
	var battle := await _battle("outer")
	_expect(battle._skills._learned == expected.learned_skills and battle._skills._selected == [Skill.SWORD], "旧领悟进入卡池但旧携带字段不影响开局")


func _stress() -> void:
	_expect(_save.settle_run(140500, false) == OK, "压测资金")
	for j in range(5):
		_expect(_save.breakthrough() == OK, "压测解锁")
	var battle := await _battle("source")
	var player: Node3D = battle._player
	player.accepts_damage = false
	battle._elapsed = 239.99
	battle._physics_process(0.02)
	var boss: DemonLord = battle._living_enemies.filter(func(enemy: Enemy) -> bool: return enemy is DemonLord)[0]
	boss.global_position = Vector3(160, 0, -380)
	boss.take_damage(24000)
	var skills: Node = battle._skills
	skills._learned = Catalog.SKILLS
	skills._passives = {"body": 5, "spirit": 5, "focus": 3}
	skills.apply_upgrade(Skill.SWORD, 4)
	skills.apply_upgrade(Skill.SWORD_STORM)
	skills._apply_evolution(Skill.SWORD)
	for id: int in [Skill.LIGHTNING, Skill.ORBS, Skill.ICE, Skill.HEAL, Skill.WISP, Skill.BELL, Skill.FIRE]:
		skills.apply_upgrade(id, 5)
	for id: int in [Skill.WISP, Skill.ORBS]:
		skills._apply_evolution(id)
	battle._hud.set_skills(skills.slots())
	var enemies: Array = []
	for i in range(150):
		if battle._active_enemy_count >= battle.MAX_ENEMIES:
			break
		var at := Vector3((i % 11 - 5.0) * 42.0, 0.0, (floori(i / 11.0) - 7.0) * 49.0)
		var pool: RefCounted = battle._crow_pool if i % 3 == 0 else battle._wolf_pool
		var enemy: Enemy = battle._spawn_enemy_at(pool, at)
		enemies.append(enemy)
	_expect(battle._active_enemy_count == 150 and battle._spawn_enemy(battle._wolf_pool) == null, "真 150 怪，拒绝 151")
	# 压测不开无伤敌人开关；提高孤立测试血量，保证满载且可看到真实伤害与特效。
	for enemy: Enemy in battle._living_enemies:
		if enemy != boss:
			enemy._health = 100000
	boss._health = boss.max_health
	# 固定四阶段火力但不篡改 Boss 显示上限；压测中的调试修改不进入游戏包。
	player.health = player.max_health - 65
	skills._lightning_left = 0.05
	skills._fire_left = 0.04
	skills._heal_left = 0.12
	skills._ascension._clocks.bell = 0.20
	skills.set_physics_process(true)
	await create_timer(0.52).timeout
	var cam: Camera3D = battle._camera.presentation
	var start := Time.get_ticks_usec()
	var last := start
	var frames := PackedFloat32Array()
	while Time.get_ticks_usec() - start < 7000000:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
	frames.sort()
	var fps := float(frames.size()) * 1000000.0 / (last - start)
	var p95 := frames[floori((frames.size() - 1) * 0.95)]
	var visible_count: int = battle._living_enemies.filter(func(enemy: Enemy) -> bool:
		return root.get_visible_rect().has_point(cam.unproject_position(enemy.global_position))).size()
	print("V5 DESKTOP STRESS: active=%d visible=%d frames=%d mean=%.2f FPS p95=%.2f ms" % [
		battle._active_enemy_count, visible_count, frames.size(), fps, p95])
	_expect(battle._active_enemy_count == 150 and visible_count >= 145 and skills.slots().size() == 8,
		"150 活怪、至少 145 进入视口，八功法运行")
	skills._cast_lightning(5)
	skills._cast_fire(5)
	skills._ascension._cast_bell(4)
	_mark(battle, Vector2(42, 420), "Windows 150 怪 · 8 功法\n采样期平均 %.1f FPS / P95 %.1f ms\n活怪 %d · 视口 %d" % [
		fps, p95, battle._active_enemy_count, visible_count])
	await _capture("验收04-Windows百五十怪技能全开")


func _battle(id: String) -> Node:
	var scene := (load(BATTLE) as PackedScene).instantiate()
	_expect(scene.configure_run(id), "秘境可进入 " + id)
	var battle := await _change(scene)
	battle.set_physics_process(false)
	battle._skills.set_physics_process(false)
	return battle


func _scene(path: String) -> Node:
	return await _change((load(path) as PackedScene).instantiate())


func _change(scene: Node) -> Node:
	_clear_marks()
	_expect(change_scene_to_node(scene) == OK, "切换场景")
	paused = false
	await scene_changed
	return current_scene


func _enemy_health(battle: Node, enemy: Enemy, text: String) -> void:
	if _out.is_empty():
		return
	var at: Vector2 = battle._camera.presentation.unproject_position(enemy.global_position + Vector3.UP * 50)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.position = at + Vector2(5, -16)
	bar.size = Vector2(110, 14)
	bar.max_value = enemy.max_health
	bar.value = enemy._health
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle.get_node("TouchUI/SafeArea").add_child(bar)
	_notes.append(bar)
	_mark(battle, at + Vector2(8, 2), "%d / %d" % [enemy._health, enemy.max_health], 21)
	_mark(battle, Vector2(42, 385), text + "\n验收叠层 · 实时敌人血量")


func _mark(battle: Node, at: Vector2, text: String, font_size := 25) -> void:
	if _out.is_empty():
		return
	var label := Label.new()
	label.position = at - battle.get_node("TouchUI/SafeArea").position
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 7)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle.get_node("TouchUI/SafeArea").add_child(label)
	_notes.append(label)


func _clear_marks() -> void:
	for note: Node in _notes:
		if is_instance_valid(note):
			note.hide()
			note.queue_free()
	_notes.clear()


func _capture(name: String) -> void:
	if _out.is_empty():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(_out.path_join(name + ".png")) == OK, name)


func _expect(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		printerr("FAIL: ", message)
