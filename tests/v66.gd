extends SceneTree

const Catalog = preload("res://scripts/cultivation_catalog.gd")
const Equipment = preload("res://scripts/equipment_catalog.gd")
const Forge = preload("res://scripts/forge_catalog.gd")
const Stats = preload("res://scripts/stats_manager.gd")
const START := "res://scenes/ui/start_menu.tscn"
const CAVE := "res://scenes/cave/cave.tscn"
const BATTLE := "res://scenes/main.tscn"
const SAVE := "user://save.cfg"
const PORTRAIT := "res://assets/character/portrait.png"

var _save: Node
var _cave: Node
var _panels: Control
var _page: Control
var _out := ""
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_save = root.get_node("SaveManager")
	if not OS.get_user_data_dir().replace("\\", "/").to_lower().contains("/wanmoyuan-v66-test-") \
			or _save.has_profile() or _save.load_error() != OK:
		printerr("请提供空的万魔渊 V6.6 隔离目录")
		quit(1)
		return
	create_timer(45.0, true, false, true).timeout.connect(func() -> void:
		printerr("V6.6 测试超时")
		quit(1))
	var args := OS.get_cmdline_user_args()
	# This mode runs on the unmodified V6.5 baseline to write an actual old save.
	if args.has("--fixture-only"):
		_write_fixture()
		print(ProjectSettings.globalize_path(SAVE))
		quit(mini(1, _fails))
		return
	var screenshot := _arg(args, "--shots")
	if not screenshot.is_empty() and DisplayServer.get_name() != "headless":
		_out = screenshot
		if DirAccess.make_dir_recursive_absolute(_out) != OK:
			quit(1)
			return
	var fixture := _arg(args, "--fixture")
	if fixture.is_empty():
		_write_fixture()
	else:
		_check(DirAccess.copy_absolute(fixture, ProjectSettings.globalize_path(SAVE)) == OK, "复制 V6.5 档")
		_check(_save._load_profile() == OK, "读入 V6.5 档")
	var before := FileAccess.get_file_as_string(SAVE)
	var profile: Dictionary = _save._profile.duplicate(true)
	await _continue_and_open_mirror()
	_check("save_version=7" in before and before == FileAccess.get_file_as_string(SAVE)
		and _save._profile == profile, "V7 继续和初次开铜镜不改档、不刷货")
	var expected := _arg(args, "--expect-portrait")
	if not expected.is_empty():
		var shown: Texture2D = _page._portrait._image.texture
		_check(shown.resource_path == PORTRAIT and _matches_png(shown.get_image(), expected), "替换 PNG 后显示同路径新图")
		await _shot("验收06b-替换同路径PNG后立绘改变")
		quit(mini(1, _fails))
		return
	await _layout_and_portrait()
	await _equipment_actions()
	await _regression_and_battle()
	if _fails == 0:
		print("V6.6 PASS: mirror, layout, stats, portrait asset, compare/wear/star/salvage, V7 and battle")
	quit(mini(1, _fails))


func _write_fixture() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 606
	_save._shop_rng.seed = 2026
	var loot: Array = []
	for data: Array in [["hat", 1, 0, 2], ["weapon", 1, 0, 0], ["weapon", 2, 3, 0], ["gloves", 1, 1, 1],
			["accessory", 1, 2, 0], ["armor", 1, 2, 0], ["pants", 1, 3, 3], ["boots", 0, 1, 0], ["weapon", 0, 0, 0]]:
		var item := Equipment.create_item(data[0], data[1], data[2], rng)
		item.star = data[3]
		loot.append(item)
	_check(_save.settle_run(20000, true, "outer", loot, 360) == OK, "V7 准备装备与材料")
	for realm in range(2):
		for layer in range(8):
			_check(_save.advance_realm_layer() == OK, "准备旧档炼气和筑基层数")
		_check(_save.breakthrough() == OK, "准备旧档金丹")
	for layer in range(2):
		_check(_save.advance_realm_layer() == OK, "准备旧档金丹三层")
	for id in [1, 2, 4, 5, 6, 7]:
		_check(_save.change_equipment(id, true) == OK, "准备旧档穿戴")
	_check(_save.learn_skill("sword_storm") == OK and _save.learn_skill("blink") == OK and _save.learn_skill("dash") == OK
		and _save.train_passive("body") == OK
		and _save.refresh_cave_shop() == OK, "准备原功法、心法与库存")


func _continue_and_open_mirror() -> void:
	change_scene_to_file(START)
	await scene_changed
	var start := current_scene
	_check(start._start.text == "继续修行", "原 V7 档允许继续")
	await _shot("验收07a-V6旧档继续修行")
	await _tap(start._start)
	if current_scene == null:
		await scene_changed
	_cave = current_scene
	_check(_cave.scene_file_path == CAVE, "主菜单进原洞府")
	_panels = _cave._panels
	await _station(4)
	_page = _panels._character
	_check(_page.is_visible_in_tree() and _panels._title.text == "角色"
		and not _panels._tabs.get_tab_bar().is_visible_in_tree(), "只有铜镜角色页，没有其他页签")


func _layout_and_portrait() -> void:
	var art: Control = _page._portrait
	var bounds := art.get_global_rect()
	var pad_y := -1.0
	for i in range(3):
		var left: Rect2 = _page._slots[["hat", "weapon", "gloves"][i]].get_global_rect()
		var right: Rect2 = _page._slots[["accessory", "armor", "pants"][i]].get_global_rect()
		_check(left.end.x <= bounds.position.x and right.position.x >= bounds.end.x
			and is_equal_approx(left.position.y, right.position.y) and left.position.y > pad_y, "左三右三物件顺序及几何位置")
		pad_y = left.position.y
	var boots: Rect2 = _page._slots.boots.get_global_rect()
	var rail: Rect2 = _page._sidebar.get_global_rect()
	_check(boots.position.y >= bounds.end.y and absf(boots.get_center().x - bounds.get_center().x) < 2.0, "鞋子在人物正下方")
	_check(rail.position.x > bounds.end.x and rail.size.x >= 190 and rail.size.x <= 240
		and _page._stats.size() == 8 and _page._learned.get_child_count() == _save.learned_skills().size(), "右侧栏尺寸和实际八项、功法数量")
	_check(_page._realm_value.text == _save.realm_name() and _page._power_value.text == _values()[1]
		and _page._power_value.get_theme_font_size("font_size") > _page._stats[1].get_theme_font_size("font_size"), "顶部真实境界和攻击倍率")
	await _shot("验收01a-七格和人物布局")
	await _shot("验收02-金丹三层真实攻击倍率")
	var top_of_deck := art.global_position
	var sidebar: ScrollContainer = _page._sidebar
	var bar := sidebar.get_v_scroll_bar()
	_check(bar.max_value > bar.page, "右栏内容可滚动")
	_scroll(sidebar, MOUSE_BUTTON_WHEEL_DOWN, 12)
	await process_frame
	_check(sidebar.scroll_vertical > 0 and art.global_position == top_of_deck, "实际滚动右栏不带动人物和装备")
	await _shot("验收01b-右栏独立滚动与功法")
	sidebar.scroll_vertical = 0
	for slot in ["hat", "gloves", "accessory", "pants"]:
		var item: Dictionary = _save.equipped_items()[slot]
		var frame: StyleBoxFlat = _page._slots[slot].get_theme_stylebox("normal")
		_check(frame.border_color == Equipment.COLORS[item.quality] and _page._slot_icons[slot].texture != null,
			"白绿蓝紫品质正确，具有部位图标")
	_check(_page._stars.hat.text == "★★☆☆☆" and _page._stars.pants.text == "★★★☆☆" and _page._stars.boots.text.is_empty()
		and _page._slot_names.boots.text == "鞋子" and _page._slots.boots.get_theme_stylebox("normal").border_color == Color("#43505a"),
		"装备左上星级与空槽灰字")
	await _shot("验收03-品质描边空槽与星级")
	var texture: Texture2D = _page._portrait._image.texture
	_check(texture.resource_path == PORTRAIT, "占位来自唯一 PNG 实际路径 " + texture.resource_path)
	_check(_matches_png(texture.get_image(), PORTRAIT), "占位图像内容与 PNG 相同")
	var phase: float = _page._portrait._phase
	await create_timer(0.32).timeout
	_check(not is_equal_approx(phase, _page._portrait._phase), "占位呼吸浮动运行")
	await _shot("验收06a-原始PNG占位")


func _equipment_actions() -> void:
	var tip: Control = _page._tip
	var values := _values()
	await _tap(_page._compare)
	await _tap(_page._slots.weapon)
	_check(tip.is_visible_in_tree() and tip._has_compare and tip._shown.item.id == 3 and tip._shown.worn.id == 2,
		"点击武器比较库存备用与当前")
	await _shot("验收04a-原装备详情与同部位对比")
	await _tap(tip._wear)
	_check(_save.equipped_items().weapon.id == 3 and _page._power_value.text != values[1]
		and _page._power_value.text == _values()[1] and _page._slots.weapon.get_theme_stylebox("normal").border_color == Equipment.COLORS[3]
		and _page._slot_names.weapon.text == "金丹·灵剑" and tip._wear.text == "卸下", "换装后本帧格子和属性及详情同步")
	await _tap(tip._close)
	await _shot("验收04b-换装后描边与攻击即时刷新")

	await _tap(_page._compare)
	await _tap(_page._slots.weapon)
	await _tap(tip._star)
	var picker: Control = _panels._picker
	_check(picker.visible and picker._list.get_child_count() == 2 and picker._confirm.disabled, "用原熔炉选择器，只提供两个未穿戴武器")
	var iron: int = _save.iron()
	values = _values()
	await _tap(picker._list.get_child(0)) # 先列最低阶的武器 ID 9。
	await _shot("验收04c-角色格打开原升星选择")
	await _tap(picker._confirm)
	_check(not picker.visible and _save.equipped_items().weapon.star == 1 and _save.iron() == iron - Forge.STAR_COSTS[0].x
		and not _has_item(9) and _page._stars.weapon.text == "★☆☆☆☆" and _page._power_value.text != values[1]
		and _page._power_value.text == _values()[1], "升星更新星标、攻击、原有扣费与祭品")
	await _tap(tip._close)
	await create_timer(1.15).timeout
	await _shot("验收04d-升星后角色格与攻击")

	await _tap(_page._slots.boots)
	_check(tip._shown.item.id == 8 and not tip._wear.disabled, "空槽也能查看并穿上备用装备")
	values = _values()
	await _tap(tip._wear)
	_check(_save.equipped_items().boots.id == 8 and _page._stats[2].text != values[2], "穿鞋即时改变移速")
	await _tap(tip._close)
	await _tap(_page._slots.armor)
	_check(tip._wear.text == "卸下" and not tip._salvage.disabled, "已穿戴装备保留原分解操作")
	values = _values()
	var coins: int = _save.spirit_stones()
	iron = _save.iron()
	await _tap(tip._salvage)
	_check(not tip.visible and not _has_item(6) and not _save.equipped_items().has("armor")
		and _save.iron() == iron + Forge.IRON_SALVAGE[2] and _save.spirit_stones() == coins + Equipment.SALVAGE[2]
		and _page._stats[0].text != values[0] and _page._slot_names.armor.text == "护甲", "分解扣道具并按原规则返材料，格子和气血即时刷新")
	await _shot("验收04e-分解后空格及返还材料")


func _regression_and_battle() -> void:
	var values := _values()
	for i in range(values.size()):
		_check(_page._stats[i].text == values[i], "右栏与统一属性源一致 " + Stats.PANEL_LABELS[i])
	await _shot("验收05a-右栏八项最终属性")
	var stock: Array = _save.shop_items()
	await _tap(_panels._close_button)
	for id in [2, 3, 5]:
		await _station(id)
		match id:
			2:
				_check(_panels._storage._items.size() == _save.storage().size(), "行囊与角色事务一致")
				await _shot("验收07b-行囊内容及独立面板")
			3:
				_check(_panels._forge_menu.gear.is_visible_in_tree(), "原熔炉页面")
				await _shot("验收07c-熔炉未改")
			5:
				_check(_panels._shop._offers.size() == 6 and _save.shop_items() == stock, "原商店库存未改")
				await _shot("验收07d-商店六件保持")
		await _tap(_panels._close_button)
	_check(_save._load_profile() == OK and _values() == values and "save_version=7" in FileAccess.get_file_as_string(SAVE), "装备事务仍落盘 V7")
	await _station(6)
	await _tap(_panels._abyss_buttons["outer"])
	await _tap(_panels._enter)
	if current_scene == null:
		await scene_changed
	var battle := current_scene
	_check(battle.scene_file_path == BATTLE and battle._abyss_id == "outer" and battle._player.stats.panel_values() == values,
		"真实入局属性与右侧八项一致")
	var stats: RefCounted = battle._player.stats
	_check(battle._player.max_health == int(values[0]) and stats.damage(100) == roundi(stats.attack_multiplier() * 100.0)
		and roundi(stats.move_speed()) == int(values[2]), "局内气血、攻击与移速实际读值")
	battle.set_physics_process(false)
	battle._skills.set_physics_process(false)
	await _shot("验收05b-入局原气血和战力对应")
	battle._elapsed = 59.99
	battle._physics_process(0.02)
	_check(battle._living_enemies.size() == 28 and Catalog.RUN_SECONDS == 300, "原兽潮和 300 秒不变")
	await _shot("验收07e-入局原兽潮与时长")


func _values() -> PackedStringArray:
	var stats := Stats.new()
	stats.configure(_save.realm(), _save.passive_levels(), _save.equipped_items(), _save.realm_layer())
	return stats.panel_values()


func _station(id: int) -> void:
	var station: StaticBody2D = _cave._stations[id]
	_cave._player.position = station.position + (Vector2.UP if id == 6 else Vector2.DOWN) * 73.0
	_cave._camera.reset_smoothing()
	_cave._camera.force_update_scroll()
	await physics_frame
	await physics_frame
	await _tap(station.hit_target)


func _has_item(id: int) -> bool:
	return _save.storage().any(func(item: Dictionary) -> bool: return item.id == id)


func _tap(target: Control) -> void:
	await process_frame
	var at := target.get_global_transform_with_canvas() * (target.size * 0.5)
	_mouse(at, MOUSE_BUTTON_LEFT, true)
	_mouse(at, MOUSE_BUTTON_LEFT, false)
	await process_frame


func _scroll(target: Control, wheel: MouseButton, times: int) -> void:
	var at := target.get_global_transform_with_canvas() * (target.size * 0.5)
	for i in range(times):
		_mouse(at, wheel, true)
		_mouse(at, wheel, false)


func _mouse(at: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.global_position = at
	event.pressed = pressed
	if button == MOUSE_BUTTON_LEFT and pressed:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)


func _matches_png(a: Image, path: String) -> bool:
	var b := Image.new()
	if a == null or b.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK or a.get_size() != b.get_size():
		return false
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var imported := a.get_data()
	var source := b.get_data()
	# The importer adjusts pixels along the alpha border to avoid filtering halos.
	var opaque := 0
	for i in range(0, source.size(), 4):
		if source[i + 3] == 255:
			opaque += 1
			for channel in range(4):
				if imported[i + channel] != source[i + channel]:
					return false
	return opaque > 0


func _shot(name: String) -> void:
	if not _out.is_empty():
		await process_frame
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png(_out.path_join(name + ".png")) == OK, name)


func _arg(args: PackedStringArray, key: String) -> String:
	var i := args.find(key)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else ""


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: ", label)
