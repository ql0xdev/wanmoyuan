extends SceneTree

const DemonLord = preload("res://scenes/enemies/demon_lord.gd")
## 用隔离的用户数据目录依次运行：play、exit、reload、invalid。

const Cultivation = preload("res://scripts/cultivation_catalog.gd")
const Equipment = preload("res://scripts/equipment_catalog.gd")
const Inventory = preload("res://scripts/run_inventory.gd")
const Stats = preload("res://scripts/stats_manager.gd")
const Skill = Cultivation.Skill
const START_MENU := "res://scenes/ui/start_menu.tscn"
const SAVE_PATH := "user://save.cfg"
const TEMP_PATH := SAVE_PATH + ".tmp"
const START_BUTTON := "Center/Content/Start"
const CAVE_CONTENT := "SafeArea/Margin/Content/"
const RESULT_CONTENT := "TouchUI/SafeArea/ResultMenu/Center/Panel/Margin/Content/"
const WHITE_WEAPON := {"slot": "weapon", "tier": 0, "quality": 0, "affixes": {}}

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var data_dir := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if not data_dir.contains("/wanmoyuan-v3-test-"):
		printerr("拒绝在非测试目录运行：", data_dir)
		quit(1)
		return
	create_timer(35.0, true, false, true).timeout.connect(_timeout)
	var save: Node = root.get_node("SaveManager")
	var args := OS.get_cmdline_user_args()
	match args[0] if args.size() == 1 else "":
		"play":
			if save.has_profile() or save.load_error() != OK:
				_expect(false, "play 需要空测试目录")
			else:
				_test_catalogs()
				await _test_play(save)
		"exit":
			await _test_exit(save)
		"retreat":
			await _test_retreat(save)
		"loot":
			await _test_ground_loot()
		"evacuation":
			await _test_evacuation(save)
		"reload":
			await _test_reload(save)
		"invalid":
			await _test_invalid(save)
		"stress":
			await _test_stress(save)
		_:
			_expect(false, "用法：--script res://tests/v3.gd -- play|exit|retreat|loot|evacuation|reload|invalid|stress")
	if _failures == 0:
		print("V3 PASS: ", args[0])
	quit(1 if _failures else 0)


func _test_catalogs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8128
	var rarity := [0, 0, 0, 0]
	for i in range(1000):
		var item := Equipment.roll(i % 3, 0.03, rng)
		if not Equipment.is_valid(item):
			_expect(false, "随机词条合法、条数随品质")
			return
		rarity[item.quality] += 1
	_expect(rarity[0] > rarity[1] and rarity[1] > rarity[2] and rarity[2] > rarity[3], "品质分布")
	var purple := Equipment.roll(2, 1.0, rng)
	_expect(purple.quality == 3 and purple.affixes.size() == 3, "紫装三条不重复词条")

	var bag := Inventory.new()
	var old_item := WHITE_WEAPON.duplicate()
	old_item.id = 7
	bag.setup({"weapon": old_item})
	for i in range(Equipment.BAG_CAPACITY):
		_expect(bag.collect(WHITE_WEAPON.duplicate()) == 0, "行囊接收前 12 件装备")
	_expect(bag.collect(purple) == 100, "满栏紫装自动分解")
	_expect(bag.equip(bag.bag[0].id) and bag.bag.size() == Equipment.BAG_CAPACITY, "满栏可交换装备")
	_expect(not bag.unequip(bag.worn.weapon.id), "不能卸入满栏")
	_expect(bag.new_loot().size() == Equipment.BAG_CAPACITY, "结算保留穿戴的新装、不重复带回旧装备")

	var stats := Stats.new()
	stats.configure("gold_core", {"body": 2, "spirit": 1, "wind": 1, "fortune": 1, "focus": 1}, {"weapon": WHITE_WEAPON})
	_expect(stats.max_health() == 325 and stats.damage(100) == 323, "金丹与心法、装备属性按乘法合成")
	_expect(is_equal_approx(stats.move_speed(), 228.8) and is_equal_approx(stats.cooldown_multiplier, 0.96)
		and is_equal_approx(stats.stone_multiplier(), 1.10), "移速、聚宝诀、凝神诀生效")
	stats.use_pill("rage")
	stats.use_pill("guard")
	stats.use_pill("fortune")
	_expect(stats.damage(100) == 420 and stats.incoming_damage(100) == 80 and stats.stone_amount(100) == 165, "三种增益丹药叠乘")


func _test_play(save: Node) -> void:
	await _open_start_menu()
	_expect(_button(START_BUTTON).text == "开始修行", "新玩家入口")
	_button(START_BUTTON).pressed.emit()
	await scene_changed
	var cave := current_scene
	_expect(save.has_profile() and FileAccess.file_exists(SAVE_PATH), "首次进入洞府立即存档")
	_expect(cave._tabs.get_tab_count() == 3 and cave._tabs.get_tab_title(1) == "功法", "洞府三页签")
	_expect(cave._breakthrough.disabled and save.breakthrough() != OK, "灵石不足不能突破")
	_button(CAVE_CONTENT + "Enter").pressed.emit()
	_expect(cave._abyss_buttons.middle.disabled and cave._abyss_buttons.inner.disabled, "高层秘境初始锁定")
	_expect(cave._loadout_buttons.heal.disabled, "限制最多携带四个功法")
	_button(CAVE_CONTENT + "Enter").pressed.emit()
	await scene_changed

	var battle := current_scene
	await process_frame
	_drop_stones(battle, 270, battle._player.global_position)
	_drop_stones(battle, 50, battle._player.global_position + Vector3(750, 0, 0))
	await _test_battle_menu(battle, save)
	var crystal: Node = battle._crystal_pool.acquire()
	crystal.drop(battle._player.global_position, battle._player)
	crystal._physics_process(1.0 / 60.0)
	battle._player.take_damage(70)
	_tap(battle, battle._hud.shop_button)
	_expect(paused and battle._shop_menu.visible, "触屏可打开炼丹房，不触发摇杆")
	battle._shop_menu.purchase_requested.emit("heal")
	battle._shop_menu.purchase_requested.emit("rage")
	battle._shop_menu.purchase_requested.emit("rage")
	battle._shop_menu.close_requested.emit()
	_expect(battle._spirit_stones == 120 and battle._xp == 1 and battle._player.health == 80
		and battle._player.stats.damage(100) == 130, "回血丹、狂暴丹与消费，未拾取灵石不入账")
	_expect(save.spirit_stones() == 0, "局内所得不提前入账")
	battle._inventory.collect(WHITE_WEAPON.duplicate(true))
	_tap(battle, battle._hud.bag_button)
	_expect(paused and battle._gear_overlay.visible, "触屏可打开行囊")
	var weapon_id: int = battle._inventory.bag[0].id
	battle._gear_menu._select(weapon_id)
	battle._gear_menu._equip.pressed.emit()
	_expect(battle._inventory.worn.weapon.id == weapon_id and battle._player.stats.damage(100) == 159, "局内换装立即生效")
	battle._gear_overlay.get_node("Content/Close").pressed.emit()

	var old_save := FileAccess.get_file_as_string(SAVE_PATH)
	_expect(DirAccess.make_dir_absolute(TEMP_PATH) == OK, "制造写入失败")
	battle._player._invulnerable_left = 0.0
	battle._player.take_damage(battle._player.max_health)
	_expect(paused and save.spirit_stones() == 0, "存档失败不入账")
	_expect(FileAccess.get_file_as_string(SAVE_PATH) == old_save, "旧档不受写入失败影响")
	_expect(_button(RESULT_CONTENT + "Retry").visible and _button(RESULT_CONTENT + "Restart").disabled
		and _button(RESULT_CONTENT + "Cave").disabled, "允许重试，未保存时不丢弃本局")
	_expect(DirAccess.remove_absolute(TEMP_PATH) == OK, "解除写入故障")
	_button(RESULT_CONTENT + "Retry").pressed.emit()
	battle._result_menu.save_retry_requested.emit()
	battle._show_result(false)
	_expect(save.spirit_stones() == 120 and save.equipment_count() == 1 and not save.has_cleared("outer"), "战败也带出装备，仅入账一次")

	_button(RESULT_CONTENT + "Restart").pressed.emit()
	await scene_changed
	battle = current_scene
	_expect(not paused and save.spirit_stones() == 120 and battle._spirit_stones == 0 and battle._xp == 0
		and battle._inventory.worn.is_empty() and battle._player.stats.damage(100) == 100, "重开清理局内状态")
	await _defeat_boss(battle, Vector3(750, 0, 0))
	_expect(save.spirit_stones() == 120 and save.has_cleared("outer") and save.equipment_count() == 1
		and _ground_gear(battle).size() == 2, "魔尊未拾取的两件装备和灵石都不自动带回")

	_button(RESULT_CONTENT + "Restart").pressed.emit()
	await scene_changed
	battle = current_scene
	_drop_stones(battle, 200, battle._player.global_position)
	await _defeat_boss(battle, Vector3.ZERO)
	_expect(save.spirit_stones() == 520 and save.equipment_count() == 3 and _ground_gear(battle).is_empty(),
		"胜利后实际拾到的魔尊灵石和两件装备带回")
	_button(RESULT_CONTENT + "Cave").pressed.emit()
	await scene_changed
	cave = current_scene
	_expect(not paused and cave._stones.text.ends_with("520"), "回洞府显示新余额")
	cave._breakthrough.pressed.emit()
	_expect(save.realm() == "foundation" and save.spirit_stones() == 20 and save.skill_points() == 3
		and cave._flash.visible and cave._notice.text == "突破·筑基", "突破、扣费、送点、金光")
	cave._storage._select(1)
	cave._storage._equip.pressed.emit()
	_expect(save.equipped_items().weapon.id == 1, "装备库选中穿戴")
	cave._storage._equip.pressed.emit()
	_expect(save.equipped_items().is_empty(), "装备库卸下")
	cave._storage._equip.pressed.emit()
	cave._skill_nodes.sword_storm.button.pressed.emit()
	cave._passive_nodes.body.button.pressed.emit()
	_expect(save.learned_skills().has("sword_storm") and save.passive_levels().body == 1 and save.skill_points() == 0, "领悟万剑诀并加锻体诀")
	_button(CAVE_CONTENT + "Enter").pressed.emit()
	_expect(not cave._abyss_buttons.middle.disabled and cave._abyss_buttons.inner.disabled, "筑基仅解锁中渊")
	for id: String in ["sword", "lightning", "orbs", "ice", "sword_storm", "heal"]:
		cave._loadout_buttons[id].pressed.emit()
	_button(CAVE_CONTENT + "Enter").pressed.emit()
	await scene_changed
	battle = current_scene
	_expect(battle._abyss_id == "outer" and battle._player.max_health == 230 and battle._player.health == 230
		and battle._player.stats.damage(100) == 244 and is_equal_approx(battle._player.stats.move_speed(), 220.0), "筑基回外渊享受攻击、血量、移速提升")
	_expect(battle._skills._levels[Skill.SWORD_STORM] == 1 and battle._skills._levels[Skill.HEAL] == 0, "首个攻击功法开局生效")
	_test_storm_and_card_pool(battle)
	battle._player.take_damage(1000)
	_button(RESULT_CONTENT + "Cave").pressed.emit()
	await scene_changed

	await _enter_abyss("middle")
	battle = current_scene
	var wolf: Node = battle._spawn_enemy(battle._wolf_pool)
	var golem: Node = battle._spawn_enemy(battle._golem_pool)
	_expect(wolf.max_health == 50 and wolf.damage == 20 and is_equal_approx(battle._spawn_interval(0.0), 1.25), "中渊血量、伤害及刷怪频率")
	golem.take_damage(golem.max_health)
	var drops := _ground_gear(battle)
	_expect(drops.size() == 1 and "筑基级" in drops[0].display_name and battle._inventory.new_loot().is_empty(),
		"中渊石傀必掉筑基装，先留在地上")
	_pick_ground_gear(battle, drops[0])
	_expect(battle._inventory.new_loot().size() == 1 and battle._inventory.new_loot()[0].tier == 1, "拾取后进入行囊")
	_drop_stones(battle, 1600, battle._player.global_position)
	await _defeat_boss(battle, Vector3.ZERO)
	_expect(save.spirit_stones() == 2020 and save.has_cleared("middle") and save.equipment_count() == 6, "中渊魔尊灵石倍率、通关进度与掉装")
	_button(RESULT_CONTENT + "Cave").pressed.emit()
	await scene_changed
	cave = current_scene
	cave._breakthrough.pressed.emit()
	_expect(save.realm() == "gold_core" and save.spirit_stones() == 20 and save.skill_points() == 3
		and cave._breakthrough.disabled and "元婴" in cave._breakthrough.text, "金丹突破后显示尚无足够灵石突破元婴")
	cave._skill_nodes.fire.button.pressed.emit()
	cave._skill_nodes.blink.button.pressed.emit()
	_expect(save.skill_points() == 0 and save.learned_skills().has("fire") and save.learned_skills().has("blink"), "领悟离火印和缩地成寸")
	await _enter_abyss("inner", ["sword", "lightning", "orbs", "ice", "fire", "blink"])
	battle = current_scene
	var inner_wolf: Node = battle._spawn_enemy(battle._wolf_pool)
	_expect(inner_wolf.max_health == 120 and inner_wolf.damage == 40 and is_equal_approx(battle._spawn_interval(0.0), 1.0), "内渊数值")
	_test_fire_and_blink(battle)
	await _defeat_boss(battle, Vector3.ZERO)
	_expect(save.spirit_stones() == 820 and save.has_cleared("inner") and save.equipment_count() == 8, "内渊结算与稀有层级")
	_button(RESULT_CONTENT + "Restart").pressed.emit()
	await scene_changed
	battle = current_scene
	_expect(battle._abyss_id == "inner" and battle._loadout == ["fire", "blink"], "重开沿用秘境和配功法")
	_test_storage_overflow(battle, save)
	_button(RESULT_CONTENT + "Cave").pressed.emit()
	await scene_changed
	cave = current_scene
	cave._storage._select(1)
	cave._storage._salvage.pressed.emit()
	_expect(save.equipment_count() == 199 and save.spirit_stones() == 830 and save.equipped_items().is_empty(), "洞府分解已穿戴装备，腾出库位")


func _test_battle_menu(battle: Node, save: Node) -> void:
	_tap(battle, battle._hud.menu_button)
	var menu: Control = battle._game_menu
	_expect(paused and menu.visible, "触屏菜单暂停战斗")
	var elapsed: float = battle._elapsed
	await create_timer(0.08, true).timeout
	_expect(battle._elapsed == elapsed, "菜单打开期间战斗计时停止")
	menu._save.pressed.emit()
	_expect("本局战斗未保存" in menu._hint.text and save.spirit_stones() == 0 and battle._spirit_stones == 270,
		"手动存档只保存洞府，不提前结算")
	menu._exit.pressed.emit()
	_expect(menu._exit.text == "保存并退出" and "不会保留" in menu._hint.text, "战斗退出确认提示未结算损失")
	menu._back.pressed.emit()
	_expect(paused and menu.visible and menu._exit.text == "退出游戏", "取消退出返回暂停菜单")
	menu._back.pressed.emit()
	_expect(not paused and not menu.visible, "继续战斗解除暂停")


func _test_storm_and_card_pool(battle: Node) -> void:
	var skills: Node = battle._skills
	var launches := []
	var initial_launch: Callable = skills._launch_sword
	skills._launch_sword = func(_origin: Vector3, direction: Vector3, amount: int) -> void:
		launches.append([direction, amount])
	skills._cast_storm(1)
	skills._launch_sword = initial_launch
	_expect(launches.size() == 8 and launches[0][1] == 37 and launches[0][0].dot(launches[4][0]) < -0.99, "万剑诀发射八剑并走统一伤害")
	var choices: Array = skills.roll_choices()
	_expect(choices.size() == 2 and choices.has(Skill.SWORD_STORM) and choices.has(Skill.HEAL), "卡池排除未携带功法")
	for i in range(3):
		skills.apply_upgrade(Skill.SWORD_STORM)
		skills.apply_upgrade(Skill.HEAL)
	_expect(skills.roll_choices() == [Skill.MAX_HEALTH], "全满级只出气血保底")
	skills.apply_upgrade(Skill.MAX_HEALTH)
	_expect(battle._player.max_health == 250, "保底气血 +20")


func _test_retreat(save: Node) -> void:
	if save.has_profile() or save.load_error() != OK:
		_expect(false, "retreat 需要空测试目录")
		return
	await _open_start_menu()
	_button(START_BUTTON).pressed.emit()
	await scene_changed
	_expect(save.settle_run(40, false, "outer", [WHITE_WEAPON]) == OK and save.change_equipment(1, true) == OK,
		"准备已有装备与灵石的测试存档")
	var cave := current_scene
	cave._open_game_menu()
	_expect(not cave._game_menu._retreat.visible, "洞府不显示退出战斗")
	cave._game_menu._back.pressed.emit()
	await _enter_abyss("outer")
	var battle := current_scene
	await process_frame
	_drop_stones(battle, 200, battle._player.global_position)
	_drop_stones(battle, 500, battle._player.global_position + Vector3(750, 0, 0))
	battle._open_shop()
	battle._shop_menu.purchase_requested.emit("rage")
	battle._close_shop()
	battle._inventory.collect(WHITE_WEAPON.duplicate())
	battle._open_bag()
	battle._gear_menu._select(-1)
	battle._gear_menu._equip.pressed.emit()
	battle._close_gear()
	var golem: Node = battle._spawn_enemy_at(battle._golem_pool, Vector3(600, 0, 0))
	golem.take_damage(golem.max_health)
	_pick_ground_gear(battle, _ground_gear(battle)[0])
	var uncollected_golem: Node = battle._spawn_enemy_at(battle._golem_pool, Vector3(760, 0, 0))
	uncollected_golem.take_damage(uncollected_golem.max_health)
	_expect(battle._inventory.new_loot().size() == 2 and battle._spirit_stones == 100,
		"本局有穿戴和行囊里的新装备，地上有未拾取的装备和灵石")

	_tap(battle, battle._hud.menu_button)
	var menu: Control = battle._game_menu
	_expect(paused and menu._retreat.visible and menu._exit.visible, "退出战斗与退出游戏分开")
	menu._retreat.pressed.emit()
	_expect(menu._retreat.text == "撤离并结算" and "不计通关" in menu._hint.text and not menu._exit.visible, "退出战斗前展示确认说明")
	menu._back.pressed.emit()
	menu._back.pressed.emit()
	_expect(not paused and not battle._result_menu.visible and save.spirit_stones() == 40, "取消可继续战斗，不结算")

	battle._open_game_menu()
	menu._retreat.pressed.emit()
	_expect(DirAccess.make_dir_absolute(TEMP_PATH) == OK, "模拟撤离结算写入失败")
	menu._retreat.pressed.emit()
	_expect(paused and not menu.visible and battle._result_menu._title.text == "提前撤离", "确认撤离打开结算，不退出游戏")
	_expect(_button(RESULT_CONTENT + "Retry").visible and _button(RESULT_CONTENT + "Cave").disabled
		and save.spirit_stones() == 40 and save.equipment_count() == 1, "撤离写入失败时保留战利品供重试")
	_expect(DirAccess.remove_absolute(TEMP_PATH) == OK, "解除写入故障")
	_button(RESULT_CONTENT + "Retry").pressed.emit()
	battle._result_menu.save_retry_requested.emit()
	menu.retreat_requested.emit()
	_expect(save.spirit_stones() == 140 and save.equipment_count() == 3 and not save.has_cleared("outer"),
		"只带回剩余灵石和两件新装备，不计通关、不重复入账")
	var config := ConfigFile.new()
	_expect(config.load(SAVE_PATH) == OK and config.get_value("profile", "spirit_stones", 0) == 140,
		"撤离结算立即写盘")
	_button(RESULT_CONTENT + "Cave").pressed.emit()
	await scene_changed
	_expect(not paused and current_scene._stones.text.ends_with("140"), "撤离后可返回洞府")


func _test_fire_and_blink(battle: Node) -> void:
	var skills: Node = battle._skills
	var enemy: Node3D = battle._living_enemies[0]
	var original: int = enemy._health
	skills._cast_fire()
	skills._update_fire(3.0, 1)
	_expect(enemy._health == original - 3 * battle._player.stats.damage(12) and skills._fire_zones.is_empty(), "离火印持续三秒、逐秒结算")
	skills.apply_upgrade(Skill.BLINK)
	var start: Vector3 = battle._player.global_position
	seed(765)
	for i in range(100):
		skills._try_blink()
		if battle._player.global_position != start:
			break
	_expect(is_equal_approx(start.distance_to(battle._player.global_position), 300.0), "缩地成寸受击时概率瞬移 300")
	battle._player.global_position = start


func _test_ground_loot() -> void:
	_expect(change_scene_to_file("res://scenes/main.tscn") == OK, "进入掉落实例测试")
	await scene_changed
	var battle := current_scene
	var drop_by_quality := {}
	for quality in range(Equipment.QUALITIES.size()):
		var item := WHITE_WEAPON.duplicate(true)
		item.quality = quality
		var stats := ["damage", "cooldown", "mitigation"]
		for i in range(quality):
			item.affixes[stats[i]] = 0.1
		battle._drop_equipment(Vector3(-180.0 + quality * 120.0, 0.0, -320.0), item)
	for drop: Node3D in _ground_gear(battle):
		var quality: int = drop._item.quality
		drop_by_quality[quality] = drop
		_expect(drop.display_name == Equipment.title(drop._item) and drop.quality_color == Equipment.COLORS[quality]
			and battle._effects._ground_equipment.has(drop), "地面装备有对应的品质色全名")
		_expect(drop._glow.visible == (quality > 0) and drop._marker.material_override.emission_enabled == (quality > 0),
			"白装无光柱也不自发光，绿蓝紫装发光")
		if quality > 0:
			_expect(drop._glow.material_override.get_shader_parameter("tint") == Equipment.COLORS[quality], "光柱使用对应品质色")
		drop._physics_process(3.0)
	_expect(drop_by_quality.size() == 4 and _ground_gear(battle).size() == 4
		and battle._inventory.bag.is_empty(), "站远处不拾取，落地三秒不会消失")
	var purple: Node3D = drop_by_quality[3]
	_pick_ground_gear(battle, purple)
	_expect(not purple.visible and not battle._effects._ground_equipment.has(purple)
		and battle._inventory.bag.size() == 1 and battle._inventory.bag[0].quality == 3,
		"靠近只拾取一次，拿走即移除名字和光柱")
	battle._drop_equipment(Vector3(240.0, 0.0, -320.0), WHITE_WEAPON.duplicate())
	_expect(purple.visible and not purple._glow.visible and purple._glow.material_override == null
		and not purple._marker.material_override.emission_enabled, "对象池复用紫装节点时不会让白装继承光效")
	while battle._inventory.bag.size() < Equipment.BAG_CAPACITY:
		battle._inventory.collect(WHITE_WEAPON.duplicate())
	var blue: Node3D = drop_by_quality[2]
	_expect(battle._spirit_stones == 0 and blue.visible, "满包时地面装备不提前分解")
	_pick_ground_gear(battle, blue)
	_expect(battle._spirit_stones == 40 and not blue.visible and battle._inventory.bag.size() == Equipment.BAG_CAPACITY,
		"满包时必须实际拾取才按原规则分解")


func _test_evacuation(save: Node) -> void:
	if save.has_profile() or save.load_error() != OK:
		_expect(false, "evacuation 需要空测试目录")
		return
	_expect(change_scene_to_file("res://scenes/main.tscn") == OK, "进入离场测试")
	await scene_changed
	var battle := current_scene
	battle._spawn_enemy_at(battle._wolf_pool, Vector3(-260, 0, -250))
	battle._drop_equipment(Vector3(1000, 0, 0), WHITE_WEAPON.duplicate())
	_drop_stones(battle, 500, Vector3(1000, 0, 0))
	_kill_boss(battle, Vector3(325, 0, 0))
	await create_timer(0.65, true, false, true).timeout
	_expect(not paused and is_equal_approx(Engine.time_scale, 1.0)
		and battle._hud._victory_loot_panel.visible and battle._hud._victory_loot_label.text == "10 秒",
		"魔尊慢动作后开始 10 秒倒计时，不立即结算")
	_expect(not battle._player.accepts_damage and not battle.get_node("Enemies").visible
		and not battle.get_node("Projectiles").visible and battle._skills.process_mode == Node.PROCESS_MODE_DISABLED,
		"倒计时内可安全拾取，不再刷怪或施法")
	var started := Time.get_ticks_msec()
	var ended_at: float = battle._elapsed
	battle._player._on_joystick_direction_changed(Vector2.RIGHT)
	await create_timer(1.60, true, true).timeout
	battle._player._on_joystick_direction_changed(Vector2.ZERO)
	_expect(battle._player.global_position.x > 270.0 and battle._inventory.new_loot().size() == 2
		and battle._spirit_stones == 200 and _ground_gear(battle).size() == 1,
		"倒计时内能走到远处，实际捡到魔尊的两件装备和灵石")
	_expect(battle._hud._shown_victory_loot_seconds < 10 and battle._elapsed == ended_at
		and not save.has_profile(), "倒计时递减，不计入战斗用时，也未提前入档")
	while battle._victory_loot_left > 0.30 and not paused:
		await physics_frame
	_expect(battle._victory_loot_left > 0.0 and not paused and not battle._result_menu.visible, "时间未到，不提前结算")
	while not paused:
		await physics_frame
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	_expect(seconds >= 8.8 and seconds <= 11.5, "实际等待约 10 秒（%.2f 秒）" % seconds)
	_expect(paused and battle._result_menu._title.text == "渡劫成功" and save.has_cleared("outer"),
		"时间到自动胜利结算")
	_expect(save.spirit_stones() == 200 and save.equipment_count() == 2,
		"只保存倒计时结束前已拾取的灵石和装备")


func _test_storage_overflow(battle: Node, save: Node) -> void:
	var fill: Array = []
	fill.resize(Equipment.STORAGE_CAPACITY - 1 - save.equipment_count())
	fill.fill(WHITE_WEAPON)
	_expect(save.settle_run(0, false, "inner", fill) == OK, "准备仅剩一格的装备库")
	battle._inventory.collect(WHITE_WEAPON.duplicate())
	battle._inventory.collect(WHITE_WEAPON.duplicate())
	battle._player.take_damage(2000)
	_expect(_button(RESULT_CONTENT + "Organize").visible and _button(RESULT_CONTENT + "Cave").disabled
		and save.equipment_count() == 199, "库满不静默丢装备、也不重复结算")
	_button(RESULT_CONTENT + "Organize").pressed.emit()
	battle._gear_menu._select(battle._inventory.bag[0].id)
	battle._gear_menu._salvage.pressed.emit()
	battle._gear_overlay.get_node("Content/Close").pressed.emit()
	_expect(save.equipment_count() == 200 and save.spirit_stones() == 825, "整理战利品后再结算")


func _test_reload(save: Node) -> void:
	await _open_start_menu()
	_expect(save.has_profile() and save.spirit_stones() == 830 and save.realm() == "gold_core", "重启自动读档")
	_expect(save.equipment_count() == 199 and save.equipped_items().is_empty()
		and save.has_cleared("outer") and save.has_cleared("middle") and save.has_cleared("inner"), "恢复装备库和三层通关")
	_expect(save.learned_skills().size() == 8 and save.passive_levels().body == 1 and save.skill_points() == 0, "恢复功法和心法")
	_expect(_button(START_BUTTON).text == "继续修行", "继续修行入口")
	_button(START_BUTTON).pressed.emit()
	await scene_changed
	_expect(current_scene._stones.text.ends_with("830"), "恢复洞府余额")


func _test_exit(save: Node) -> void:
	if save.spirit_stones() != 830:
		_expect(false, "exit 需要 play 生成的测试存档")
		return
	await _open_start_menu()
	_button(START_BUTTON).pressed.emit()
	await scene_changed
	_button(CAVE_CONTENT + "Header/MenuButton").pressed.emit()
	var menu: Control = current_scene._game_menu
	_expect(paused and menu.visible, "洞府可打开菜单")
	menu._exit.pressed.emit()
	var old_save := FileAccess.get_file_as_string(SAVE_PATH)
	_expect(DirAccess.make_dir_absolute(TEMP_PATH) == OK, "制造退出时写入失败")
	menu._exit.pressed.emit()
	_expect("游戏未退出" in menu._hint.text and FileAccess.get_file_as_string(SAVE_PATH) == old_save, "保存失败时保留旧档且不退出")
	_expect(DirAccess.remove_absolute(TEMP_PATH) == OK, "解除写入故障")
	# 移开旧档，验证确认退出确实重新写盘，而不是只退出游戏。
	_expect(DirAccess.rename_absolute(SAVE_PATH, SAVE_PATH + ".test-backup") == OK, "移开隔离测试存档")
	if _failures > 0:
		return
	menu._exit.pressed.emit()
	_expect(FileAccess.get_file_as_string(SAVE_PATH) == old_save, "退出前保存完整洞府进度")
	if _failures > 0:
		quit(1)
	else:
		print("V3 PASS: exit")
	await create_timer(0.2, true).timeout
	_expect(false, "确认保存后仍未退出进程")


func _test_invalid(save: Node) -> void:
	await _open_start_menu()
	var original := FileAccess.get_file_as_string(SAVE_PATH)
	_expect(not original.is_empty() and save.load_error() != OK, "不兼容存档标记为读取失败")
	_expect(_button(START_BUTTON).disabled and current_scene.get_node("Center/Content/Status").visible, "界面提示读档失败")
	_expect(save.ensure_profile() != OK and save.settle_run(10, true) != OK, "不能覆盖不可读的存档")
	_expect(FileAccess.get_file_as_string(SAVE_PATH) == original, "原文件未修改")


func _test_stress(save: Node) -> void:
	if save.has_profile() or save.load_error() != OK:
		_expect(false, "stress 需要空测试目录")
		return
	_expect(save.settle_run(2500, false) == OK and save.breakthrough() == OK and save.breakthrough() == OK,
		"准备内渊压测存档")
	var scene := load("res://scenes/main.tscn") as PackedScene
	var battle := scene.instantiate()
	_expect(battle.configure_run("inner", Cultivation.DEFAULT_LOADOUT) and change_scene_to_node(battle) == OK, "进入内渊")
	await scene_changed
	battle._player.accepts_damage = false
	# 保持刷怪和 3D 逻辑运行；关闭出剑，避免击杀影响固定同屏负载。
	battle._skills.set_physics_process(false)
	for i in range(100):
		var position_in_world := Vector3((i % 10 - 4.5) * 65.0, 0.0, (floori(i / 10.0) - 4.5) * 62.0)
		var pool: RefCounted = battle._crow_pool if i % 4 == 0 else battle._wolf_pool
		battle._spawn_enemy_at(pool, position_in_world)
	_expect(battle._active_enemy_count == 99, "怪满时为 180 秒魔尊预留位置")
	battle._spawn_boss()
	_expect(battle._active_enemy_count == 100 and battle._boss_spawned, "同屏 100 怪与魔尊预留")
	await create_timer(3.0).timeout
	var start := Time.get_ticks_usec()
	var frames := 0
	var worst_frame := 0
	var last := start
	while Time.get_ticks_usec() - start < 20000000:
		await process_frame
		var now := Time.get_ticks_usec()
		worst_frame = maxi(worst_frame, now - last)
		last = now
		frames += 1
	print("100 怪 / 内渊：%.1f FPS，最长帧 %.1f ms (%d 帧)" % [
		frames * 1000000.0 / (Time.get_ticks_usec() - start), worst_frame / 1000.0, frames,
	])
	_expect(battle._active_enemy_count == 100 and battle._player.is_alive(), "固定负载全程稳定在 100 怪")


func _enter_abyss(id: String, toggle: Array = []) -> void:
	var cave := current_scene
	_button(CAVE_CONTENT + "Enter").pressed.emit()
	cave._abyss_buttons[id].pressed.emit()
	for skill: String in toggle:
		cave._loadout_buttons[skill].pressed.emit()
	_button(CAVE_CONTENT + "Enter").pressed.emit()
	await scene_changed


func _tap(battle: Node, button: Control) -> void:
	var event := InputEventScreenTouch.new()
	event.position = (button.get_global_transform_with_canvas() * (button.size * 0.5))
	event.pressed = true
	battle._joystick._input(event)
	event.pressed = false
	battle._joystick._input(event)


func _drop_stones(battle: Node, amount: int, at: Vector3) -> void:
	var stone: Node = battle._stone_pool.acquire()
	stone.drop(at, battle._player, amount)
	stone._physics_process(1.0 / 60.0)


func _ground_gear(battle: Node) -> Array:
	return battle.get_node("Pickups/EquipmentDrops").get_children().filter(func(drop: Node3D) -> bool: return drop.visible)


func _pick_ground_gear(battle: Node, drop: Node3D) -> void:
	var before: Vector3 = battle._player.global_position
	battle._player.global_position = drop.global_position
	drop._physics_process(0.18)
	battle._player.global_position = before


func _defeat_boss(battle: Node, offset: Vector3) -> void:
	_kill_boss(battle, offset)
	await create_timer(0.63, true, false, true).timeout
	_expect(not paused and is_equal_approx(Engine.time_scale, 1.0) and battle._hud._victory_loot_panel.visible,
		"胜利慢动作结束后开始离场倒计时")
	# 这里跳过剩余倒计时；evacuation 测试另走一次完整 10 秒流程。
	battle._physics_process(10.0)
	_expect(paused and battle._result_menu.visible, "离场倒计时时间到结算")


func _kill_boss(battle: Node, offset: Vector3) -> void:
	battle._elapsed = 179.95
	battle._physics_process(0.02)
	_expect(not battle._boss_spawned, "180 秒之前不刷魔尊")
	battle._physics_process(0.04)
	var boss: Node3D = battle._living_enemies.filter(func(enemy: Node3D) -> bool: return enemy is DemonLord).front()
	var health: int = {"outer": 800, "middle": 2400, "inner": 6400}[battle._abyss_id]
	_expect(battle._boss_spawned and boss.max_health == health and boss.period_multiplier == battle._abyss.boss_period, "180 秒刷对应魔尊")
	boss.global_position = battle._player.global_position + offset
	boss.take_damage(boss.max_health)


func _open_start_menu() -> void:
	_expect(change_scene_to_file(START_MENU) == OK, "启动界面可加载")
	await scene_changed


func _button(path: String) -> Button:
	return current_scene.get_node(path)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		printerr("FAIL: ", description)
		_failures += 1


func _timeout() -> void:
	printerr("FAIL: 测试超时")
	quit(1)
