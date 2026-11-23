extends SceneTree

const Catalog = preload("res://scripts/cultivation_catalog.gd")
const Equipment = preload("res://scripts/equipment_catalog.gd")
const Shop = preload("res://scripts/cave_shop_catalog.gd")
const Stats = preload("res://scripts/stats_manager.gd")
const BATTLE := "res://scenes/main.tscn"
const CAVE := "res://scenes/ui/cave_menu.tscn"
const SAVE := "user://save.cfg"
const Skill = Catalog.Skill

var _save: Node
var _out := ""
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_save = root.get_node("SaveManager")
	var directory := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if not directory.contains("/wanmoyuan-v6-test-") or _save.has_profile() or _save.load_error() != OK:
		printerr("请提供空的万魔渊 V6 隔离目录")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and DisplayServer.get_name() != "headless":
		_out = args[0]
		if DirAccess.make_dir_recursive_absolute(_out) != OK:
			quit(1)
			return
	create_timer(95.0, true, false, true).timeout.connect(func() -> void:
		printerr("V6 测试超时")
		quit(1))
	await _migration(args[1] if args.size() >= 2 else "")
	await _layers()
	await _equipment()
	await _shop()
	await _guide_and_battle()
	_check_capacity()
	if _fails == 0:
		print("V6 PASS: realms, equipment, character, shop, guide, migration and battle")
	await create_timer(0.2, true, false, true).timeout
	quit(mini(1, _fails))


func _migration(path: String) -> void:
	var config := ConfigFile.new()
	if path.is_empty():
		config.set_value("save", "save_version", 6)
		var legacy := {"spirit_stones": 6650, "iron": 32, "forge_count": 7, "realm": "gold_core", "skill_points": 2,
			"learned_skills": Catalog.STARTER_SKILLS + ["sword_storm"], "passive_levels": {"body": 1},
			"equipment_storage": [{"id": 71, "slot": "weapon", "tier": 0, "quality": 0, "affixes": {}, "star": 0}],
			"equipped": {"weapon": 71}, "secret_realm_progress": {"outer": true}}
		for key: String in legacy:
			config.set_value("profile", key, legacy[key])
	else:
		_check(config.load(path) == OK and config.get_value("save", "save_version", 0) == 6, "加载真实 V5.5.2 档")
	_check(config.save(SAVE) == OK, "复制隔离旧档")
	var before := FileAccess.get_file_as_string(SAVE)
	_check(_save._load_profile() == OK and _save.realm_layer() == 1 and _save.shop_items().is_empty()
		and not _save.has_evolved("sword"), "旧档初始化一层，商店与图鉴为空")
	for key: String in config.get_section_keys("profile"):
		_check(_save._profile[key] == config.get_value("profile", key), "旧字段保留 " + key)
	var stats := Stats.new()
	stats.configure(_save.realm(), _save.passive_levels(), _save.equipped_items())
	var battle := await _battle()
	_check(battle._player.stats.panel_values() == stats.panel_values(), "旧档一层与原算法属性一致")
	_check(FileAccess.get_file_as_string(SAVE) == before, "读取不抢写档案")
	var cave := await _scene(CAVE)
	_check(cave._realm.text == "金丹·一层" and cave._stat_values[0].text == str(stats.max_health()), "旧档在洞府显示")
	await _shot("验收09a-V5.5.2旧档金丹一层")
	cave._tabs.current_tab = 2
	await _shot("验收09b-旧档装备完整")
	_check(_save.save_profile() == OK and "save_version=7" in FileAccess.get_file_as_string(SAVE)
		and _save._load_profile() == OK, "首次成功保存迁移 V7，并可重读")


func _layers() -> void:
	_check(_save.settle_run(100000, false, "outer", [], 1200) == OK, "测试资金")
	var cave := await _scene(CAVE)
	_check(cave._layer_tiles.size() == 9 and "640 灵石" in cave._breakthrough.text and _save.breakthrough() == ERR_UNAVAILABLE,
		"金丹九格，小突破 640，大突破被后端挡住")
	await _shot("验收01-金丹一层九格和费用")
	var base_attack := float(cave._stat_values[1].text.trim_prefix("×"))
	var base_health: int = cave._stat_values[0].text.to_int()
	var points: int = _save.skill_points()
	var balance: int = _save.spirit_stones()
	for i in range(1, 9):
		cave._breakthrough.pressed.emit()
		if i in [1, 2, 8]:
			var multiplier := Catalog.layer_multiplier(i + 1)
			_check(_save.realm_layer() == i + 1 and _save.spirit_stones() == balance - i * 640 and _save.skill_points() == points,
				"逐层扣费、不给功法点")
			_check(absf(cave._stat_values[1].text.trim_prefix("×").to_float() - base_attack * multiplier) <= 0.02
				and absi(cave._stat_values[0].text.to_int() - roundi(base_health * multiplier)) <= 1, "加法增长")
		if i == 2:
			await _shot("验收02a-金丹三层攻击气血加16")
	_check("突破·元婴" in cave._breakthrough.text and not cave._breakthrough.disabled
		and _save.advance_realm_layer() == ERR_UNAVAILABLE and is_equal_approx(Catalog.layer_multiplier(9), 1.64), "九层之后只可大突破")
	await _shot("验收02b-金丹九层攻击气血加64")
	var master_price: int = _save.spirit_stones()
	cave._breakthrough.pressed.emit()
	_check(cave._realm.text == "元婴·一层" and _save.spirit_stones() == master_price - 8000 and _save.skill_points() == points + 3,
		"大突破扣 8000 并回到新境一层")
	if not _out.is_empty():
		await create_timer(2.0).timeout
	await _shot("验收03-大突破元婴一层")


func _equipment() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 716
	var items := []
	for slot in ["hat", "gloves", "pants", "boots"]:
		items.append(Equipment.create_item(slot, 0, 0, rng))
	items.append(Equipment.create_item("hat", 1, 1, rng))
	var battle := await _battle()
	var golem: Node = battle._spawn_enemy_at(battle._golem_pool, Vector2(0, -385))
	golem.set_physics_process(false)
	battle._loot_rng.seed = 607
	var ground := battle.get_node("Pickups/EquipmentDrops")
	var distribution := {}
	for i in range(1400):
		battle._roll_equipment(golem)
		for drop: Node in ground.get_children():
			if drop.visible:
				distribution[drop._item.slot] = distribution.get(drop._item.slot, 0) + 1
				battle._effects.untrack_equipment(drop)
				battle._equipment_pool.release(drop)
	_check(distribution.size() == 7, "从实际战斗掉落函数检出七部位")
	for count: int in distribution.values():
		_check(count > 150 and count < 250, "七部位等概率采样")
	for n in range(200):
		battle._roll_equipment(golem)
		var found := false
		for drop: Node in ground.get_children():
			if drop.visible:
				if drop._item.slot in ["hat", "gloves", "pants", "boots"]:
					found = true
				else:
					battle._effects.untrack_equipment(drop)
					battle._equipment_pool.release(drop)
		if found:
			break
	await _shot("验收05a-怪物实际掉落新部位")

	_check(_save.settle_run(0, false, "outer", items) == OK, "装备仓储七部位")
	var cave := await _scene(CAVE)
	var old := _save.equipped_items() as Dictionary
	var base := Stats.new()
	base.configure(_save.realm(), _save.passive_levels(), old, _save.realm_layer())
	cave._tabs.current_tab = 2
	await process_frame
	for slot in ["hat", "gloves", "pants", "boots"]:
		var item: Dictionary = _save.storage().filter(func(data: Dictionary) -> bool: return data.slot == slot and data.quality == 0).front()
		cave._storage._select(item.id)
		cave._storage._popup._wear.pressed.emit()
		cave._storage._popup.close()
	var stats := Stats.new()
	var worn: Dictionary = _save.equipped_items()
	stats.configure(_save.realm(), _save.passive_levels(), worn, _save.realm_layer())
	_check(stats.max_health() > base.max_health() and stats.attack_multiplier() > base.attack_multiplier()
		and stats.damage_taken_multiplier() < base.damage_taken_multiplier() and stats.move_speed() > base.move_speed(), "四部位增益各自生效")
	cave._tabs.current_tab = 4
	_check(cave._character._slots.size() == 7 and cave._character._stats.size() == 8
		and cave._character._learned.get_child_count() == _save.learned_skills().size(), "角色面板各区")
	for i in range(8):
		_check(cave._character._stats[i].text == stats.panel_values()[i], "角色属性源与 StatsManager 相同")
	await _shot("验收04-角色七部位穿戴")
	await process_frame
	cave._character.scroll_vertical = int(cave._character.get_v_scroll_bar().max_value)
	await _shot("验收06-角色已领悟和最终属性")
	cave._character.scroll_vertical = 0
	cave._character._compare.button_pressed = true
	await process_frame
	cave._character._slots.hat.pressed.emit()
	_check(cave._character._tip._has_compare, "角色格打开原同部位对比浮窗")
	await _shot("验收06b-角色格详情与对比")
	cave._character._tip.close()

	cave._tabs.current_tab = 3
	var forge: Node = cave._forge_menu
	forge._tabs.get_child(1).pressed.emit()
	_check(forge._slot_buttons.get_child_count() == 7, "熔炉七部位按钮")
	forge._slot_buttons.get_child(3).pressed.emit()
	await _shot("验收05b-可打造帽子及七部位")
	forge._craft.pressed.emit()
	var made: Dictionary = _save.storage().back()
	_check(made.slot == "hat", "UI 打造新部位入库")
	var stars_before: int = _save.iron()
	_check(_save.star_equipment(worn.hat.id, [worn.boots.id]) != OK and _save.iron() == stars_before, "不能跨部位当祭品")
	_check(_save.star_equipment(worn.hat.id, [made.id]) == OK and _save.equipped_items().hat.star == 1, "同部位未穿戴祭品可升星")
	var extra: Dictionary = _save.storage().filter(func(item: Dictionary) -> bool: return item.slot == "hat" and item.quality == 1).front()
	var iron: int = _save.iron()
	_check(_save.salvage_equipment(extra.id) == OK and _save.iron() == iron + 6, "新部位可熔炼且给玄铁")


func _shop() -> void:
	var distribution := [0, 0, 0, 0]
	for roll in range(1, 101):
		distribution[Shop.quality_at(roll)] += 1
	_check(distribution == [40, 35, 20, 5] and Shop.BASE_PRICES == [100, 250, 600, 1500], "商店概率售价表")
	var rng := RandomNumberGenerator.new()
	var tier := int(Catalog.REALMS[_save.realm()].rank)
	var wanted_seed := 0
	for i in range(200):
		rng.seed = i
		var stock := Shop.roll_stock(tier, rng)
		if stock.any(func(x: Dictionary) -> bool: return x.item.quality == 0) \
			and stock.any(func(x: Dictionary) -> bool: return x.item.quality >= 2):
			wanted_seed = i
			break
	_save._shop_rng.seed = wanted_seed
	var battle := await _battle()
	battle._show_result(false, true)
	_check(_save.shop_items().is_empty(), "仅结算不刷新商品")
	battle._restart_battle()
	await scene_changed
	battle = current_scene
	_check(_save.shop_items().is_empty(), "直接再来一局不刷新")
	battle._show_result(false, true)
	battle._return_to_cave()
	await scene_changed
	var cave := current_scene
	cave._tabs.current_tab = 5
	var stock: Array = _save.shop_items()
	_check(stock.size() == 6 and cave._shop._offers.size() == 6, "实际返回洞府六件")
	if stock.size() != 6:
		return
	for offer: Dictionary in stock:
		_check(offer.item.tier == tier and offer.price == Shop.price(tier, offer.item.quality), "最高已解锁境界与售价")
	_save._profile.spirit_stones = Shop.price(tier, 1) # 隔离存档模拟买得起白装而买不起蓝装。
	cave._refresh()
	var cheap: Dictionary = stock.filter(func(offer: Dictionary) -> bool: return offer.item.quality == 0).front()
	var expensive: Dictionary = stock.filter(func(offer: Dictionary) -> bool: return offer.item.quality >= 2).front()
	_check(cave._shop._offers[expensive.id].buy.disabled and not cave._shop._offers[cheap.id].buy.disabled,
		"不足置灰，便宜可买")
	await _shot("验收07a-商店六件与灵石不足置灰")
	var before: int = _save.equipment_count()
	var gold: int = _save.spirit_stones()
	cave._shop._offers[cheap.id].buy.pressed.emit()
	_check(_save.equipment_count() == before + 1 and _save.spirit_stones() == gold - cheap.price
		and _save.shop_items()[cheap.id - 1].sold and _save.buy_shop_item(cheap.id) != OK, "买入库，不能重复购买")
	await _shot("验收07b-购买入库及售空")
	var purchased: Array = _save.shop_items()
	_check(_save._load_profile() == OK and purchased == _save.shop_items(), "商品及售出状态落盘")
	battle = await _battle()
	battle._show_result(false)
	battle._return_to_cave()
	await scene_changed
	_check(_save.shop_items() != purchased and _save.shop_items().all(func(item: Dictionary) -> bool: return not item.sold), "下一次返回确实换货")


func _guide_and_battle() -> void:
	var cave := current_scene
	cave._tabs.current_tab = 1
	cave._guide_tab.pressed.emit()
	_check(cave._guide._cards.size() == 9 and not cave._guide._cards.sword.reached
		and "万剑诀" in cave._guide._cards.sword.recipe.text, "图鉴初始公开未达成配方")
	await _shot("验收08a-图鉴全公开未点亮")
	await process_frame
	cave._guide.get_parent().get_parent().scroll_vertical = int(cave._guide.get_parent().get_parent().get_v_scroll_bar().max_value)
	await _shot("验收08d-图鉴下半及全部九条")
	cave._guide.get_parent().get_parent().scroll_vertical = 0
	var test_table := Catalog.EVOLUTIONS.duplicate(true)
	test_table.sword.partner = "fire"
	cave._guide.refresh(test_table)
	_check("离火印" in cave._guide._cards.sword.recipe.text and "万剑诀" not in cave._guide._cards.sword.recipe.text, "改配置副本自动更新")
	await _shot("验收08b-临时配置改搭档自动跟随")
	cave._guide.refresh()
	_check("万剑诀" in cave._guide._cards.sword.recipe.text, "恢复生产配方")
	if not _save.learned_skills().has("sword_storm"):
		_check(_save.learn_skill("sword_storm") == OK, "准备进化搭档")
	var battle := await _battle()
	battle._elapsed = 59.99
	battle._physics_process(0.02)
	_check(battle._living_enemies.size() == 28 and Catalog.RUN_SECONDS == 300, "V5.5.2 波次与时长未改")
	var skills: Node = battle._skills
	skills.apply_upgrade(Skill.SWORD, 2)
	skills.apply_upgrade(Skill.SWORD_STORM)
	battle._hud.set_skills(skills.slots())
	battle._xp = battle._xp_required
	battle._show_level_up()
	_check(battle._choices.size() == 3 and battle._choices[0].type == "evolution"
		and battle._hud._skill_bar._slots.size() == 6, "V5.5.2 三选一进化金卡与六格未变")
	await _shot("验收10a-局内六格三选一进化")
	battle._on_upgrade_chosen(0)
	_check(_save.has_evolved("sword") and _save._load_profile() == OK and _save.has_evolved("sword"), "真实进化后立即持久化")
	battle._elapsed = 239.99
	battle._physics_process(0.02)
	_check(battle._boss_spawned and battle._hud._time_label.text == "04:00 / 05:00", "Boss 240 秒登场")
	await _shot("验收10b-Boss240秒及05分总时长")
	cave = await _scene(CAVE)
	cave._tabs.current_tab = 1
	cave._guide_tab.pressed.emit()
	_check(cave._guide._cards.sword.reached and not cave._guide._cards.ice.reached, "进化一条点亮，其他保持灰色")
	await _shot("验收08c-实际进化后金色点亮")


func _check_capacity() -> void:
	_check(Equipment.STORAGE_CAPACITY == 300, "装备库 300")
	var padding: Array = []
	padding.resize(300 - _save.equipment_count())
	var rng := RandomNumberGenerator.new()
	padding.fill(Equipment.create_item("boots", 0, 0, rng))
	_check(_save.settle_run(0, false, "outer", padding) == OK and _save.equipment_count() == 300, "装满 300 可保存")
	_check(_save.settle_run(0, false, "outer", [padding[0]]) == ERR_OUT_OF_MEMORY, "301 不覆盖装备")


func _battle() -> Node:
	var battle := await _scene(BATTLE)
	battle.set_physics_process(false)
	battle._skills.set_physics_process(false)
	return battle


func _scene(path: String) -> Node:
	paused = false
	_check(change_scene_to_file(path) == OK, "切换场景 " + path)
	await scene_changed
	return current_scene


func _shot(name: String) -> void:
	if not _out.is_empty():
		await process_frame
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png(_out.path_join(name + ".png")) == OK, name)


func _check(ok: bool, description: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: ", description)
