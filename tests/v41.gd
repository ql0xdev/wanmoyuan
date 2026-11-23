extends SceneTree

const Equipment = preload("res://scripts/equipment_catalog.gd")
const Forge = preload("res://scripts/forge_catalog.gd")
const Catalog = preload("res://scripts/cultivation_catalog.gd")
const Upgrades = preload("res://scripts/upgrade_catalog.gd")
const DemonLord = preload("res://scenes/enemies/demon_lord.gd")
const SpawnManager = preload("res://scripts/spawn_manager.gd")
const CAVE := "res://scenes/ui/cave_menu.tscn"
const BATTLE := "res://scenes/main.tscn"
const SAVE := "user://save.cfg"
const GREEN := {"slot": "armor", "tier": 1, "quality": 1, "affixes": {"move_speed": 0.08}}
const WHITE := {"slot": "armor", "tier": 0, "quality": 0, "affixes": {}}
const WORN := {"slot": "armor", "tier": 0, "quality": 2, "affixes": {"health_flat": 15.0, "damage": 0.14}}
const PURPLE := {"slot": "accessory", "tier": 0, "quality": 3, "affixes": {"move_speed": 0.04, "damage": 0.09, "magnet": 0.12}}
var _save: Node
var _out := ""
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_save = root.get_node("SaveManager")
	var data := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if not data.contains("/wanmoyuan-v41-test-") or _save.has_profile() or _save.load_error() != OK:
		printerr("需要空的 wanmoyuan-v41-test-* 隔离 APPDATA。")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if not args.is_empty() else "full"
	if args.size() == 2 and DisplayServer.get_name() != "headless":
		_out = args[1]
		if DirAccess.make_dir_recursive_absolute(_out) != OK:
			quit(1)
			return
	create_timer(90.0, true, false, true).timeout.connect(func() -> void:
		printerr("V4.1 测试超时")
		quit(1))
	match mode:
		"full", "capture":
			_test_tables()
			await _test_loot_and_bag()
			await _test_cave()
			await _test_cards()
		"legacy": await _test_legacy()
		"stress": await _test_stress()
		_: _expect(false, "用法：full | capture <目录> | legacy [目录] | stress [目录]")
	await create_timer(0.5, true, false, true).timeout
	if _failures == 0:
		print("V4.1 PASS: ", mode)
	quit(mini(_failures, 1))


func _test_tables() -> void:
	_expect(Equipment.SALVAGE == [5, 15, 40, 100] and Forge.IRON_SALVAGE == [2, 6, 16, 40], "熔炼双币表")
	_expect(Forge.COSTS == [Vector2i(30, 200), Vector2i(40, 500), Vector2i(50, 1000),
		Vector2i(80, 2000), Vector2i(120, 4000), Vector2i(200, 8000)], "六级打造价格")
	_expect(Forge.STAR_COSTS == [Vector2i(20, 1), Vector2i(40, 1), Vector2i(80, 2), Vector2i(160, 2), Vector2i(300, 3)], "五级升星价格")
	var expected := [[50, 32, 15, 3], [35, 35, 22, 8], [20, 35, 30, 15], [5, 30, 40, 25]]
	var levels := [0, 20, 50, 100]
	for i in range(levels.size()):
		var actual := [0, 0, 0, 0]
		for draw in range(1, 101):
			actual[Forge.quality_at(levels[i], draw)] += 1
		_expect(actual == expected[i], "逐点穷举判定正好等于段位表 " + str(i))
	_expect(Forge.rank_text(7) == "学徒 7/20" and Forge.rank_text(20) == "工匠 20/50"
		and Forge.rank_text(50) == "大师 50/100" and Forge.rank_text(100) == "宗师 100 次", "熟练度边界")
	var rng := RandomNumberGenerator.new()
	rng.seed = 541
	var procs := 0
	var purple_procs := 0
	for i in range(3000):
		var roll := Forge.craft("weapon", 5, 100, rng)
		procs += int(roll.masterwork)
		purple_procs += int(roll.masterwork and roll.natural_quality == 3)
		_expect(roll.item.quality == mini(roll.natural_quality + int(roll.masterwork), 3)
			and Equipment.is_valid(roll.item) and roll.item.star == 0, "神匠触发先升档后随机相应条数，紫封顶")
	_expect(Forge.MASTERWORK_CHANCE == 5 and procs > 110 and procs < 195 and purple_procs > 0, "固定种子验证神匠 5% 判定")


func _test_loot_and_bag() -> void:
	_expect(_save.settle_run(9500, false, "outer", [WORN, GREEN, GREEN, WHITE, PURPLE]) == OK
		and _save.change_equipment(1, true) == OK, "建立可对比的正式存档")
	_expect(_save.breakthrough() == OK and _save.breakthrough() == OK and _save.realm() == "gold_core", "金丹测试账号")
	var battle := await _battle("outer")
	var drop := _pickup(battle, GREEN)
	_expect(not drop.visible and battle._hud._loot_notice.visible and battle._hud.loot_item_id == -1, "拾取事件显示可点通知")
	await process_frame
	var at: Vector2 = battle._hud._loot_notice.get_global_transform_with_canvas() * (battle._hud._loot_notice.size * 0.5)
	_tap_touch(battle, at)
	_expect(battle._loot_tooltip.visible and paused and battle._loot_tooltip._has_compare, "触摸拾取通知打开对比窗")
	await _capture("01b-拾取提示浮窗")
	await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = battle._loot_tooltip.get_global_transform_with_canvas() * Vector2(3, 3)
	root.push_input(click, true)
	_expect(not battle._loot_tooltip.visible and not paused, "点浮窗外关闭并恢复战斗")
	for i in range(1, Equipment.BAG_CAPACITY):
		_pickup(battle, WHITE)
	var full := _pickup(battle, GREEN)
	_expect(not full.visible and battle._spirit_stones == 15 and battle._iron == 6
		and "灵石+15" in battle._hud._loot_notice.text and "玄铁+6" in battle._hud._loot_notice.text, "满包实际拾取一件绿装才自动分解")
	await _capture("03b-满包自动分解")
	battle._open_bag()
	battle._gear_menu._select(-1)
	_expect(battle._gear_menu._popup.visible and battle._gear_menu._popup._star.disabled, "行囊复用浮窗，当前玄铁不足禁用升星")
	# 用本局满包分解紫装赚玄铁，然后实际挑选一件未穿戴祭品。
	battle._gear_menu._popup.close()
	battle._close_gear()
	_pickup(battle, PURPLE)
	battle._open_bag()
	battle._gear_menu._select(-1)
	battle._gear_menu._popup._star.pressed.emit()
	_expect(battle._star_picker.visible, "可在行囊为本局新装升星")
	_check_first(battle._star_picker)
	battle._star_picker._confirm.pressed.emit()
	_expect(battle._iron == 26 and battle._inventory.find(-1).star == 1 and battle._inventory.bag.size() == 11,
		"本局分解与升星按同一套材料规则")
	battle._gear_menu._popup.close()
	battle._close_gear()
	battle._open_game_menu()
	battle._retreat_from_battle()
	_expect(battle._settlement_saved and _save.iron() == 26 and _save.storage().any(func(item: Dictionary) -> bool: return item.star == 1),
		"撤离仅结算本局剩余玄铁，并带回升星实例")


func _test_cave() -> void:
	var cave := await _scene(CAVE)
	cave._tabs.current_tab = 2
	var menu: Node = cave._storage
	await process_frame
	menu._cells[2].pressed.emit()
	var popup: Node = menu._popup
	var style: StyleBoxFlat = popup._panel.get_theme_stylebox("panel")
	_expect(popup.visible and style.border_width_left == 2 and style.corner_radius_top_left == 8
		and style.border_color == Equipment.COLORS[1] and is_equal_approx(style.bg_color.a, 0.92), "92% 底、品质色描边 2px、圆角 8")
	_expect(popup._has_compare and _has_label(popup._primary, "+18%", popup.GAIN) and _has_label(popup._primary, "−15", popup.LOSS),
		"并列比较实际差值，绿+红−")
	_expect(_has_label(popup._primary, "☆☆☆☆☆  0 星", Color("#f0c674")) and _has_label(popup._primary, "词条", Color("#f0c674"))
		and popup._wear.visible and popup._star.visible and popup._salvage.visible and popup._close.visible, "浮窗名称星级词条四按钮")
	await _capture("01-装备浮窗")
	await _capture("02-对比当前穿戴")

	var previous: int = _save.spirit_stones()
	popup._salvage.pressed.emit()
	_expect(_save.iron() == 32 and _save.spirit_stones() == previous + 15 and "灵石+15" in menu._status.text
		and "玄铁+6" in menu._status.text, "洞府分解绿装提示及实际到账")
	await _capture("03-绿装熔炼")

	cave._tabs.current_tab = 3
	var forge: Node = cave._forge_menu
	forge._tabs.get_child(1).pressed.emit()
	_expect(forge._tiers.get_child(3).disabled and "境界未达" in forge._tiers.get_child(3).text
		and _save.forge_equipment("weapon", 3).error == ERR_INVALID_PARAMETER, "金丹不能打造元婴，界面和服务均校验")
	forge._slot_buttons.get_child(1).pressed.emit()
	forge._tiers.get_child(0).pressed.emit()
	_expect("需玄铁 30" in forge._cost.text and "需灵石 200" in forge._cost.text and not forge._craft.disabled, "真实选择护甲、炼气")
	await _capture("04-打造选部位等级")
	var normal_seed := _forge_seed(false, 0, 0)
	_save._forge_rng.seed = normal_seed
	var stored: int = _save.equipment_count()
	previous = _save.spirit_stones()
	forge._craft.pressed.emit()
	var crafted: Dictionary = _save.storage().back()
	_expect(_save.iron() == 2 and _save.spirit_stones() == previous - 200 and _save.forge_count() == 1
		and _save.equipment_count() == stored + 1 and crafted.slot == "armor" and crafted.tier == 0 and crafted.star == 0,
		"真实出炉、扣费、熟练度 +1")
	_expect("学徒 1/20" in forge._header.text and "出炉" in forge._output.text, "显示熟练度和出炉结果")
	await _capture("05-出炉与熟练度")
	_expect(_save.forge_equipment("armor", 0).error == ERR_UNAVAILABLE and _save.forge_count() == 1, "材料不足，打造不计数也不扣钱")

	# 熔炼一件原有紫装，再通过真实打造按钮复现神匠金光。
	cave._tabs.current_tab = 2
	menu._cells[5].pressed.emit()
	popup._salvage.pressed.emit()
	cave._tabs.current_tab = 3
	var rare_seed := _forge_seed(true, 1, 0)
	_save._forge_rng.seed = rare_seed
	forge._craft.pressed.emit()
	var master: Dictionary = _save.storage().back()
	_expect(_save.forge_count() == 2 and master.quality == 1 and master.affixes.size() == 1 \
		and cave._forge_flash.visible and cave._forge_flash._caption.text == "神匠一击", "白→绿神匠一击及金光")
	await _capture("06-神匠一击")
	if not _out.is_empty():
		await create_timer(1.1).timeout

	cave._tabs.current_tab = 2
	menu._cells[3].pressed.emit()
	_expect(popup._star.disabled and "玄铁 12/20" in popup._status.text, "缺玄铁，按钮置灰提示缺口")
	await _capture("07a-升星材料不足")
	_expect(_save.settle_run(0, false, "outer", [], 50) == OK, "隔离测试补充后续星级材料")
	cave._refresh()
	await process_frame
	menu._cells[3].pressed.emit()
	popup._star.pressed.emit()
	_expect(cave._picker.visible and cave._picker._confirm.disabled and menu.star_candidates(menu._items[3])[0].quality == 0,
		"祭品需手选且低品质优先")
	var candidates: Array = menu.star_candidates(menu._items[3])
	_expect(candidates.all(func(item: Dictionary) -> bool: return item.id != 1 and item.id != 3 and item.slot == "armor"),
		"不列出穿戴中和目标本身")
	_expect(_save.star_equipment(3, [1]) == ERR_INVALID_PARAMETER and _save.iron() == 62, "服务端拒绝穿戴祭品，材料不扣")
	var sacrificed: int = candidates[0].id
	_check_first(cave._picker)
	await _capture("07b-选择祭品")
	var base: Dictionary = Equipment.base_stats(menu._items[3])
	cave._picker._confirm.pressed.emit()
	await process_frame
	var upgraded: Dictionary = menu._items[3]
	_expect(not menu._items.has(sacrificed) and upgraded.star == 1 and _save.iron() == 42
		and upgraded.affixes == GREEN.affixes and is_equal_approx(Equipment.base_stats(upgraded).health, base.health * 1.15)
		and _has_label(popup._primary, "★☆☆☆☆  1 星", Color("#f0c674")), "祭品消失，属性 ×1.15 并即时刷新")
	await _capture("07c-升星金光")
	if not _out.is_empty():
		await create_timer(1.1).timeout
	await _capture("07d-一星属性刷新")
	popup._wear.pressed.emit()
	_expect(_save.equipped_items().armor.id == 3 and _save.equipped_items().armor.star == 1, "对比后穿戴并保存一星装备")
	var copy := _save.get_script().new() as Node
	_expect(copy._load_profile() == OK and copy.iron() == 42 and copy.forge_count() == 2 and copy.equipped_items().armor.star == 1, "V5 重读星级、玄铁和熟练度")
	copy.free()


func _test_cards() -> void:
	var battle := await _battle("outer")
	var skills: Node = battle._skills
	var player: Node = battle._player
	player.stats.configure("qi_refining", {}, {})
	player.refresh_equipment(true)
	skills._upgrade_rng.seed = 541
	var rare_count := 0
	for i in range(2000):
		var drawn: Array = skills.roll_choices()
		_expect(drawn.size() == 3, "永远三选一")
		rare_count += drawn.filter(func(card: Dictionary) -> bool: return card.rarity == "rare").size()
	_expect(Upgrades.RARE_PERCENT == 8 and rare_count in range(425, 540), "普通卡独立 8% 金卡抽样")

	_open_cards(battle, _card_seed(skills, "stat", "normal"))
	_expect(battle._choices.any(func(card: Dictionary) -> bool: return card.type == "stat"), "普通局内升级可抽属性卡")
	await _capture("08a-混合卡池")
	_close_cards(battle)
	for id: int in skills._selected:
		skills._levels[id] = 3
	_open_cards(battle, _card_seed(skills, "stat", "normal"))
	_expect(battle._choices.size() == 3 and battle._choices.all(func(card: Dictionary) -> bool: return card.type == "stat"),
		"全满后仍有三张属性卡")
	await _capture("08b-满级三张属性卡")
	_close_cards(battle)
	skills._levels[Catalog.Skill.SWORD] = 1
	_open_cards(battle, _card_seed(skills, "skill", "rare"))
	var rare_skill := _rare_index(battle, "skill")
	_expect(rare_skill >= 0 and "Lv1 → Lv3" in battle._upgrade_menu._buttons[rare_skill].text, "一张稀有功法卡显示跨两级")
	await _capture("09a-珍稀功法卡")
	battle._upgrade_menu._buttons[rare_skill].pressed.emit()
	_expect(skills._levels[Catalog.Skill.SWORD] == 3, "选择稀有功法卡实升两级")
	_open_cards(battle, _card_seed(skills, "stat", "rare"))
	var rare_stat := _rare_index(battle, "stat")
	var card: Dictionary = battle._choices[rare_stat]
	var rule: Dictionary = Upgrades.STAT_CARDS[card.id]
	var rare_button: Button = battle._upgrade_menu._buttons[rare_stat]
	_expect("珍稀" in rare_button.text and rare_button.has_theme_stylebox_override("normal")
		and ("+%d" % roundi(rule.amount * 2 * (100 if rule.percent else 1))) in rare_button.text, "稀有属性值翻倍并金边")
	await _capture("09b-珍稀属性卡")
	rare_button.pressed.emit()
	_expect(is_equal_approx(player.stats._run[card.id], float(rule.amount) * 2), "稀有属性实际应用双倍")
	player.stats._run.clear()
	player.stats._run_remaining.clear()
	player.stats._refresh_derived()
	var expected := {"damage": 0.05, "health_flat": 20, "move_speed": 0.04, "cooldown": 0.04,
		"magnet": 0.10, "kill_heal": 2, "stone_amount": 0.08, "mitigation": 0.03}
	for id: String in expected:
		skills.apply_card({"type": "stat", "id": id, "rarity": "normal"})
		skills.apply_card({"type": "stat", "id": id, "rarity": "normal"})
		_expect(is_equal_approx(player.stats._run[id], 2.0 * expected[id]), "正确数值且可重复叠加：" + id)
	_expect(is_equal_approx(player.stats.attack_multiplier(), 1.1) and player.max_health == 140
		and is_equal_approx(player.stats.move_speed(), 216.0) and is_equal_approx(player.stats.cooldown_multiplier, 0.96 * 0.96)
		and is_equal_approx(player.stats.magnet_radius, 96.0) and player.stats.kill_heal() == 4
		and is_equal_approx(player.stats.stone_multiplier(), 1.16) and is_equal_approx(player.stats.damage_taken_multiplier(), 0.97 * 0.97),
		"八类属性均真的接入统一计算，而非仅改文案")


func _test_legacy() -> void:
	var fixture := ConfigFile.new()
	fixture.set_value("save", "save_version", 4)
	var data := {
		"realm": "gold_core", "spirit_stones": 9312, "skill_points": 2,
		"learned_skills": ["sword", "lightning", "orbs", "ice", "heal", "fire"],
		"passive_levels": {"body": 2}, "secret_realm_progress": {"outer": true, "middle": true},
		"equipment_storage": [{"id": 41, "slot": "weapon", "tier": 1, "quality": 2, "affixes": {"damage": 0.22, "kill_heal": 2}}],
		"equipped": {"weapon": 41},
	}
	for key: String in data:
		fixture.set_value("profile", key, data[key])
	_expect(fixture.save(SAVE) == OK and _save._load_profile() == OK, "V4 真正格式迁移")
	_expect(_save.iron() == 0 and _save.forge_count() == 0 and _save.equipped_items().weapon.star == 0, "新增字段补 0")
	var expected := data.duplicate(true)
	expected["iron"] = 0
	expected["forge_count"] = 0
	expected.equipment_storage[0]["star"] = 0
	_expect(_save._profile == expected, "存档原字段完全保留")
	_expect("save_version=4" in FileAccess.get_file_as_string(SAVE) and _save.save_profile() == OK
		and "save_version=5" in FileAccess.get_file_as_string(SAVE) and _save._load_profile() == OK
		and _save._profile == expected, "首次保存原子迁移并重读")
	var cave := await _scene(CAVE)
	cave._tabs.current_tab = 2
	await process_frame
	cave._storage._cells[41].pressed.emit()
	await _capture("10a-旧装默认零星")
	cave._storage._popup.close()
	cave._tabs.current_tab = 3
	cave._forge_menu._tabs.get_child(1).pressed.emit()
	await _capture("10b-旧档玄铁和熟练度零")


func _test_stress() -> void:
	_expect(_save.settle_run(140500, false, "outer", [WORN]) == OK and _save.change_equipment(1, true) == OK, "压测存档")
	for i in range(5):
		_expect(_save.breakthrough() == OK, "解锁五层")
	var battle := await _battle("source")
	battle._player.accepts_damage = false
	battle._elapsed = 299.95
	battle._spawns._next_wave = 300.0
	battle._spawns._next_golem = 300.0
	battle._physics_process(0.06)
	var center: Vector3 = battle._player.global_position
	for enemy in battle._living_enemies:
		if enemy is DemonLord:
			enemy.global_position = center + Vector3(55, 0, -285)
			enemy.take_damage(24000)
	while battle._active_enemy_count < 100:
		var i: int = battle._active_enemy_count
		var at := center + Vector3(cos(i * TAU / 73), 0, sin(i * TAU / 73)) * (280.0 + i % 4 * 115)
		battle._spawn_kind_at(SpawnManager.Kind.CROW if i % 2 == 0 else SpawnManager.Kind.WOLF, at)
	for i in range(Equipment.BAG_CAPACITY):
		_pickup(battle, GREEN)
	await create_timer(0.42).timeout
	await _capture("11a-五层百怪弹幕")
	var times := PackedFloat32Array()
	var cold := 0.0
	var cold_open := 0.0
	for i in range(24):
		var start := Time.get_ticks_usec()
		battle._open_bag()
		var opened := Time.get_ticks_usec() - start
		if i == 0:
			await create_timer(0.26, true).timeout
		start = Time.get_ticks_usec()
		battle._gear_menu._cells[-1].pressed.emit()
		var elapsed := (opened + Time.get_ticks_usec() - start) / 1000.0
		if i == 0:
			cold = elapsed
			cold_open = opened / 1000.0
		else:
			times.append(elapsed)
		_expect(battle._gear_menu._popup.visible and paused and battle._active_enemy_count == 100, "百怪负载中打开暂停行囊与比较")
		if i == 0:
			await _capture("11b-五层行囊装备浮窗")
		battle._gear_menu._popup.close()
		battle._close_gear()
		await process_frame
	times.sort()
	print("DESKTOP: cold %.2f ms (bag %.2f + inspect %.2f), 23 repeat median %.2f ms, P95 %.2f ms (script-side)." % [
		cold, cold_open, cold - cold_open, times[11], times[21]])


func _pickup(battle: Node, item: Dictionary) -> Node:
	battle._drop_equipment(battle._player.global_position, item.duplicate(true))
	var drop: Node
	for node in battle.get_node("Pickups/EquipmentDrops").get_children():
		if node.visible:
			drop = node
			break
	drop._physics_process(0.18)
	return drop


func _has_label(node: Node, text: String, color: Color) -> bool:
	if node is Label and node.text == text and node.get_theme_color("font_color") == color:
		return true
	for child in node.get_children():
		if _has_label(child, text, color):
			return true
	return false


func _forge_seed(proc: bool, count: int, quality: int) -> int:
	var rng := RandomNumberGenerator.new()
	for n in range(2000):
		rng.seed = n
		var roll := Forge.craft("armor", 0, count, rng)
		if roll.masterwork == proc and roll.natural_quality == quality:
			return n
	return -1


func _card_seed(skills: Node, type: String, rarity: String) -> int:
	for n in range(2000):
		skills._upgrade_rng.seed = n
		if skills.roll_choices().any(func(c: Dictionary) -> bool: return c.type == type and c.rarity == rarity):
			return n
	return -1


func _open_cards(battle: Node, seed_value: int) -> void:
	battle._skills._upgrade_rng.seed = seed_value
	battle._xp = battle._xp_required
	battle._show_level_up()


func _close_cards(battle: Node) -> void:
	battle._upgrade_menu.hide()
	battle._xp = 0
	paused = false


func _rare_index(battle: Node, type: String) -> int:
	for i in range(battle._choices.size()):
		if battle._choices[i].type == type and battle._choices[i].rarity == "rare":
			return i
	return -1


func _check_first(picker: Node) -> void:
	var button: CheckButton = picker._list.get_child(0)
	button.button_pressed = true


func _tap_touch(battle: Node, position: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = position
		event.pressed = pressed
		battle._joystick._input(event)


func _battle(abyss: String) -> Node:
	var battle := (load(BATTLE) as PackedScene).instantiate()
	_expect(battle.configure_run(abyss, Catalog.DEFAULT_LOADOUT), "配置战斗")
	await _change(battle)
	battle.set_physics_process(false)
	battle._skills.set_physics_process(false)
	return battle


func _scene(path: String) -> Node:
	return await _change((load(path) as PackedScene).instantiate())


func _change(scene: Node) -> Node:
	_expect(change_scene_to_node(scene) == OK, "切换场景")
	paused = false
	await scene_changed
	return current_scene


func _capture(name: String) -> void:
	if _out.is_empty():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(_out.path_join(name + ".png")) == OK, "截图 " + name)


func _expect(passed: bool, description: String) -> void:
	if not passed:
		_failures += 1
		printerr("FAIL: ", description)
