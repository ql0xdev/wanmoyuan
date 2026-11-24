extends SceneTree

const Map = preload("res://scenes/cave/cave_map.gd")
const Station = preload("res://scenes/cave/cave_station.gd")
const Catalog = preload("res://scripts/cultivation_catalog.gd")
const Stats = preload("res://scripts/stats_manager.gd")
const Equipment = preload("res://scripts/equipment_catalog.gd")
const Forge = preload("res://scripts/forge_catalog.gd")
const START := "res://scenes/ui/start_menu.tscn"
const CAVE := "res://scenes/cave/cave.tscn"
const SAVE := "user://save.cfg"

var _save: Node
var _cave: Node
var _out := ""
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_save = root.get_node("SaveManager")
	if not OS.get_user_data_dir().replace("\\", "/").to_lower().contains("/wanmoyuan-v65-test-") \
			or _save.has_profile() or _save.load_error() != OK:
		printerr("请提供空的万魔渊 V6.5 隔离目录")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and DisplayServer.get_name() != "headless":
		_out = args[0]
		if DirAccess.make_dir_recursive_absolute(_out) != OK:
			quit(1)
			return
	create_timer(80.0, true, false, true).timeout.connect(func() -> void:
		printerr("V6.5 测试超时")
		quit(1))
	await _continue_v7(args[1] if args.size() >= 2 else "")
	if _cave == null or _cave._stations.size() != 7:
		printerr("洞府或七个物件未加载")
		quit(1)
		return
	await _movement()
	await _panorama()
	await _stations_and_panels()
	await _departure_and_return()
	await _transactions()
	await _animations()
	if _fails == 0:
		print("V6.5 PASS: cave movement, camera, 11 colliders, touch/mouse, tabs, portal, settlement, transactions and V7/battle regression")
	quit(mini(_fails, 1))


func _continue_v7(fixture: String) -> void:
	if fixture.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 65
		var hat := Equipment.create_item("hat", 0, 0, rng)
		_check(_save.settle_run(20000, false, "outer", [hat], 120) == OK, "准备隔离 V7 档")
		for layer in range(8):
			_check(_save.advance_realm_layer() == OK, "隔离档准备功法点")
		_check(_save.breakthrough() == OK and _save.learn_skill("sword_storm") == OK, "隔离档已领悟进化搭档")
		_check(_save.change_equipment(_save.storage()[0].id, true) == OK, "准备旧档装备")
		_check(_save.refresh_cave_shop() == OK, "准备旧商店库存")
	else:
		_check(DirAccess.copy_absolute(fixture, ProjectSettings.globalize_path(SAVE)) == OK, "复制 V6.0 存档")
	_check(_save._load_profile() == OK, "加载 V7 档")
	var before := FileAccess.get_file_as_string(SAVE)
	var stock: Array = _save.shop_items()
	var profile: Dictionary = _save._profile.duplicate(true)
	_check("save_version=7" in before, "验收档为 V7")
	change_scene_to_file(START)
	await scene_changed
	var start := current_scene
	_check(start._start.text == "继续修行", "主菜单显示继续")
	await _shot("验收10a-旧档继续修行")
	await _tap(start._start)
	await _scene_ready()
	_cave = current_scene if current_scene.scene_file_path == CAVE else null
	_check(_cave != null and _cave._player.position == Vector2(520, 1714) and not _cave._panels.visible, "主菜单进入出生点")
	_check(before == FileAccess.get_file_as_string(SAVE) and _save._profile == profile and _save.shop_items() == stock,
		"继续不改档、不刷商店，旧资料原样")
	await _shot("验收10b-旧档直接进入洞府")


func _movement() -> void:
	var player: CharacterBody2D = _cave._player
	var camera: Camera2D = _cave._camera
	var joy_point := Vector2(356, 656)
	var before := player.position
	var camera_before := camera.get_screen_center_position()
	_touch(joy_point, 0, true)
	_drag(joy_point + Vector2(0, -76), 0)
	await _physics(145)
	_check(player.position.y < before.y - 600 and _cave._touch_direction == Vector2.UP, "实际摇杆拖动")
	_check(camera.get_screen_center_position().y < camera_before.y - 250, "镜头确实随主角移动")
	await _shot("验收01a-摇杆移动与镜头跟随")
	_touch(joy_point + Vector2(0, -76), 0, false)
	before = player.position
	await _physics(3)
	_check(player.position.is_equal_approx(before) and _cave._touch_direction == Vector2.ZERO, "释放摇杆立即停止")
	_key(KEY_RIGHT, true)
	await _physics(10)
	_key(KEY_RIGHT, false)
	_check(player.position.x > before.x + 40, "实际方向键可移动")
	var size := Map.EXTENT
	for wall: Vector2 in [Vector2(0, size.y * 0.5), Vector2(size.x, size.y * 0.5), Vector2(size.x * 0.5, 0), Vector2(size.x * 0.5, size.y)]:
		var from_wall := (size * 0.5 - wall).normalized()
		player.position = wall + from_wall * 105.0
		await _physics(2)
		_check(player.test_move(player.global_transform, -from_wall * 60), "四边洞壁物理碰撞")
	for station: Station in _cave._stations:
		player.position = station.position + Vector2.DOWN * 72.0
		await _physics(2)
		_check(player.test_move(player.global_transform, Vector2.UP * 74.0), "物件实体阻挡 " + station.bubble.text)
	var left := Vector2(97, 1190)
	player.position = left
	_touch(joy_point, 0, true)
	_drag(joy_point + Vector2(-65, 0), 0)
	await _physics(24)
	_check(player.position.x > 79.0 and player.position.x < 82.0 and player.get_slide_collision_count() > 0, "持续推墙出不去")
	await _shot("验收01b-持续推墙不穿出")
	_touch(joy_point + Vector2(-65, 0), 0, false)
	var mat: Station = _cave._stations[Station.Kind.MAT]
	player.position = mat.position + Vector2.DOWN * 75.0
	_cave._camera.reset_smoothing()
	_touch(joy_point, 0, true)
	_drag(joy_point + Vector2(0, -65), 0)
	await _physics(22)
	_check(player.position.distance_to(mat.position) >= Station.RADII[0] + 15.9
		and player.get_slide_collision_count() > 0, "持续推动时蒲团确实挡住主角")
	await _shot("验收01c-蒲团实体碰撞")
	_touch(joy_point + Vector2(0, -65), 0, false)


func _panorama() -> void:
	if _out.is_empty():
		return
	var camera: Camera2D = _cave._camera
	camera.position = Map.EXTENT * 0.5 - _cave._player.position
	camera.limit_left = -4000
	camera.limit_top = -4000
	camera.limit_right = 4000
	camera.limit_bottom = 4000
	camera.zoom = Vector2.ONE * 0.60
	camera.reset_smoothing()
	_cave._hud.hide()
	_cave._stations[0].set_near(false)
	_cave.set_physics_process(false)
	await _shot("验收02-洞府全景七个物件")
	_cave.set_physics_process(true)
	_cave._hud.show()
	camera.position = Vector2.ZERO
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(Map.EXTENT.x)
	camera.limit_bottom = int(Map.EXTENT.y)
	_cave._fit_camera()


func _stations_and_panels() -> void:
	var player: CharacterBody2D = _cave._player
	var panels: Control = _cave._panels
	var stats := Stats.new()
	stats.configure(_save.realm(), _save.passive_levels(), _save.equipped_items(), _save.realm_layer())
	var names := ["修行", "功法", "行囊", "熔炉", "角色", "商店"]
	for i in range(names.size()):
		var station: Station = _cave._stations[i]
		await _at_station(station, 81.0)
		_check(not station.bubble.visible, "81 像素无提示")
		await _tap(station.hit_target)
		_check(not panels.visible, "远处点击物件不能打开")
		await _at_station(station, 80.0)
		_check(station.bubble.visible and station.bubble.text == Station.LABELS[i], "80 像素含边界点")
		if i == Station.Kind.MAT:
			await _shot("验收03a-靠近蒲团提示")
		elif i == Station.Kind.FORGE:
			await _shot("验收03b-靠近熔炉提示")
		if i == Station.Kind.MAT:
			# 第二指点气泡时第一指还在摇杆上；关闭后原手势不得继续推动主角。
			_touch(Vector2(320, 660), 0, true)
			await _tap(station.bubble, 1)
		else:
			await _tap(station.hit_target)
		if not panels.visible or panels._tabs.get_current_tab_control().name != names[i]:
			_check(false, "点击物件或提示打开 " + names[i])
			return
		_check(not panels._tabs.get_tab_bar().is_visible_in_tree() and panels._title.text == names[i],
			"只显示当前物件标题，不显示其他入口")
		for tab in range(names.size()):
			_check(panels._tabs.get_tab_control(tab).is_visible_in_tree() == (tab == i),
				"%s入口仅显示%s对应内容" % [names[i], names[i]])
		if i == Station.Kind.PILLAR:
			await _tap(panels._guide_tab)
			_check(panels._guide.visible and panels._guide._cards.size() == Catalog.EVOLUTIONS.size(), "组合图鉴内容")
		elif i == Station.Kind.MAT:
			_check(panels._realm.text == _save.realm_name() and panels._stat_values[0].text == stats.panel_values()[0],
				"修行读原始属性")
		elif i == Station.Kind.MIRROR:
			_check(panels._character._slots.size() == 7 and panels._character._stats[1].text == stats.panel_values()[1], "角色读原始七槽属性")
		elif i == Station.Kind.SHOP:
			_check(panels._shop._offers.size() == _save.shop_items().size(), "商店显示原库存")
		await _shot("验收04%s-%s面板" % [char(97 + i), names[i]])
		if i == Station.Kind.MAT:
			var at := player.position
			_key(KEY_DOWN, true)
			await _physics(8)
			_check(player.position == at, "面板期间键盘不能走")
			_key(KEY_DOWN, false)
			await _tap(panels._close_button)
			_drag(Vector2(320, 760), 0)
			await _physics(4)
			_check(player.position == at, "关闭不恢复旧触指")
			_touch(Vector2(320, 760), 0, false)
			_touch(Vector2(320, 660), 0, true)
			_drag(Vector2(320, 760), 0)
			await _physics(25)
			_check(player.position.y > at.y + 100 and not station.bubble.visible, "关面板恢复移动，离远提示消失")
			await _shot("验收05b-关闭面板后恢复移动")
			_touch(Vector2(320, 760), 0, false)
		elif i == Station.Kind.PILLAR:
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
			await process_frame
			_check(not panels.visible, "Esc 关闭面板回场景")
		else:
			if i == Station.Kind.CHEST:
				await _shot("验收05a-宝箱只显示行囊")
			await _tap(panels._close_button)
	_check(not panels.visible and _cave._hud.visible, "关闭后场景 HUD 恢复")
	await _tap(_cave._menu_button, 0)
	_check(paused and panels._game_menu.is_visible_in_tree() and not panels._cave_layout.visible, "世界菜单复用原菜单")
	await create_timer(0.23, true, false, true).timeout
	await _tap(panels._game_menu._save)
	_check("洞府进度已保存" in panels._game_menu._hint.text, "菜单保存生效")
	await _tap(panels._game_menu._back)
	_check(not paused and not panels.visible, "关闭世界菜单恢复场景")


func _departure_and_return() -> void:
	var portal: Station = _cave._stations[Station.Kind.PORTAL]
	await _at_station(portal, 73.0, Vector2.UP)
	await _shot("验收03c-靠近传送阵提示")
	await _tap(portal.bubble, 0)
	var panels: Control = _cave._panels
	_check(panels._preparation.is_visible_in_tree() and not panels._tabs.visible, "传送阵打开原秘境准备")
	await _tap(panels._back)
	_check(not panels.visible, "从秘境准备返回场景")
	await _tap(portal.hit_target)
	await _tap(panels._abyss_buttons["outer"])
	_check(panels._abyss_buttons["outer"].button_pressed and "300 秒" in panels._abyss_buttons["outer"].text, "可选外渊")
	await _shot("验收06a-传送阵打开准备并选择秘境")
	var stock_before: Array = _save.shop_items()
	var rng_before: int = _save._shop_rng.state
	await _tap(panels._enter)
	await _scene_ready()
	var battle := current_scene
	_check(battle.scene_file_path == "res://scenes/main.tscn" and battle._abyss_id == "outer", "传送阵确实开战")
	battle.set_physics_process(false)
	battle._skills.set_physics_process(false)
	await _shot("验收06b-传送阵进入原战斗")
	if not _save.learned_skills().has("sword_storm"):
		_check(_save.learn_skill("sword_storm") == OK, "隔离档准备进化搭档")
	battle._elapsed = 59.99
	battle._physics_process(0.02)
	_check(battle._living_enemies.size() == 28 and Catalog.RUN_SECONDS == 300, "原 60 秒兽潮与 300 秒上限")
	await _shot("验收10c-原兽潮与五分钟时长")
	battle._skills.apply_upgrade(Catalog.Skill.SWORD, 2)
	battle._skills.apply_upgrade(Catalog.Skill.SWORD_STORM)
	battle._hud.set_skills(battle._skills.slots())
	battle._xp = battle._xp_required
	battle._show_level_up()
	_check(battle._choices.size() == 3 and battle._choices[0].type == "evolution"
		and battle._hud._skill_bar._slots.size() == 6, "六格与三选一进化")
	await _shot("验收10d-六格抽卡与进化")
	battle._on_upgrade_chosen(0)
	_check(_save.has_evolved("sword"), "进化点亮图鉴")
	battle._elapsed = 239.99
	battle._physics_process(0.02)
	_check(battle._boss_spawned and battle._hud._time_label.text == "04:00 / 05:00", "240 秒魔尊")
	await _shot("验收10e-魔尊240秒")
	battle._show_result(false, true)
	_check(_save._shop_rng.state == rng_before and _save.shop_items() == stock_before, "仅结算不刷新")
	battle._restart_battle()
	await scene_changed
	battle = current_scene
	_check(_save._shop_rng.state == rng_before and _save.shop_items() == stock_before, "再来一局不刷新")
	battle._show_result(false, true)
	await _shot("验收07a-秘境结算")
	battle._return_to_cave()
	await scene_changed
	_cave = current_scene if current_scene.scene_file_path == CAVE else null
	_check(_cave != null and _cave._player.position == Vector2(520, 1714) and not _cave._panels.visible, "结算返回场景出生点")
	_check(_save._shop_rng.state != rng_before and _save.shop_items().size() == 6
		and _save.shop_items().all(func(offer: Dictionary) -> bool: return not offer.sold), "实际返回六件新货")
	await _shot("验收07b-返回同一出生点")
	await _at_station(_cave._stations[Station.Kind.SHOP])
	await _tap(_cave._stations[Station.Kind.SHOP].hit_target)
	_check(_cave._panels._shop._offers.size() == 6, "货架显示新货")
	await _shot("验收07c-商店刷新六件")
	await _tap(_cave._panels._close_button)


func _transactions() -> void:
	var panels: Control = _cave._panels
	# Walk the actual route rather than relocating between the three transactions.
	await _walk_to(Vector2(520, 1495))
	await _walk_to(_cave._stations[Station.Kind.MAT].position + Vector2.DOWN * 73.0)
	await _tap(_cave._stations[Station.Kind.MAT].hit_target)
	var layer: int = _save.realm_layer()
	var balance: int = _save.spirit_stones()
	var cost := Catalog.layer_cost(_save.realm())
	await _tap(panels._breakthrough)
	_check(_save.realm_layer() == layer + 1 and _save.spirit_stones() == balance - cost
		and panels._realm.text == _save.realm_name(), "小突破即时显示与扣费")
	await _shot("验收08a-小突破即时生效")
	await _tap(panels._close_button)
	var furnace: Station = _cave._stations[Station.Kind.FORGE]
	await _walk_to(Vector2(520, furnace.position.y + 73.0))
	await _walk_to(furnace.position + Vector2.DOWN * 73.0)
	await _tap(_cave._stations[Station.Kind.FORGE].hit_target)
	var forge: Node = panels._forge_menu
	await _tap(forge._tabs.get_child(1))
	var used := Forge.COSTS[0] as Vector2i
	balance = _save.spirit_stones()
	var iron: int = _save.iron()
	var count: int = _save.equipment_count()
	await _tap(forge._craft)
	_check(_save.equipment_count() == count + 1 and _save.spirit_stones() == balance - used.y
		and _save.iron() == iron - used.x and "出炉" in forge._output.text, "打造扣费即时入库")
	await _shot("验收08b-熔炉打造即时入库")
	await _tap(panels._close_button)
	var shop: Station = _cave._stations[Station.Kind.SHOP]
	await _walk_to(Vector2(520, furnace.position.y + 73.0))
	await _walk_to(Vector2(520, shop.position.y + 73.0))
	await _walk_to(shop.position + Vector2.DOWN * 73.0)
	await _tap(_cave._stations[Station.Kind.SHOP].hit_target)
	var offer: Dictionary = _save.shop_items().front()
	balance = _save.spirit_stones()
	count = _save.equipment_count()
	await _tap(panels._shop._offers[offer.id].buy)
	_check(_save.equipment_count() == count + 1 and _save.spirit_stones() == balance - offer.price
		and _save.shop_items().front().sold and panels._shop._offers[offer.id].buy.disabled, "购买立即入库、扣费、售空")
	await _shot("验收08c-商店购买即时生效")
	await _tap(panels._close_button)


func _animations() -> void:
	for id in [Station.Kind.MAT, Station.Kind.PILLAR, Station.Kind.FORGE, Station.Kind.PORTAL]:
		var station: Station = _cave._stations[id]
		await _at_station(station, 76.0, Vector2.UP if id == Station.Kind.PORTAL else Vector2.DOWN)
		var phase := station._phase
		await _shot("验收09%d-%s动效第一帧" % [id, station.bubble.text.split(" · ")[0]])
		await create_timer(0.38).timeout
		_check(station._phase > phase, "循环动效推进 " + station.bubble.text)
		await _shot("验收09%d-%s动效第二帧" % [id, station.bubble.text.split(" · ")[0]])
	if not _out.is_empty():
		var start := Time.get_ticks_usec()
		for i in range(90):
			await RenderingServer.frame_post_draw
		var fps := 90.0 * 1000000.0 / float(Time.get_ticks_usec() - start)
		print("V6.5 desktop cave at 540x960: %.1f render frames/s across 90 frames" % fps)
		_check(fps >= 30.0, "桌面验收场景达到 30 FPS")


func _walk_to(target: Vector2) -> void:
	var player: CharacterBody2D = _cave._player
	var origin := Vector2(335, 615)
	_touch(origin, 0, true)
	for i in range(265):
		var offset := target - player.position
		if offset.length() <= 5.5:
			break
		_drag(origin + offset.normalized() * 70.0, 0)
		await physics_frame
	_touch(origin, 0, false)
	_check(player.position.distance_to(target) <= 5.5, "实际摇杆走到 %s" % target)
	await _physics(2)


func _at_station(station: Station, distance := 73.0, side := Vector2.DOWN) -> void:
	_cave._player.position = station.position + side * distance
	_cave._camera.reset_smoothing()
	_cave._camera.force_update_scroll()
	await _physics(3)


func _physics(frames: int) -> void:
	for i in range(frames):
		await physics_frame
	await process_frame


func _scene_ready() -> void:
	# Input can swap the scene before or after the next process frame depending on rendering.
	if current_scene == null:
		await scene_changed
	await process_frame


func _tap(control: Control, finger := -1) -> void:
	await process_frame
	var at := control.get_global_transform_with_canvas() * (control.size * 0.5)
	if finger == -1:
		_mouse(at, true)
		_mouse(at, false)
	else:
		_touch(at, finger, true)
		_touch(at, finger, false)
	await process_frame


func _mouse(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event, true)


func _touch(at: Vector2, finger: int, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.index = finger
	event.pressed = pressed
	root.push_input(event, true)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _drag(at: Vector2, finger: int) -> void:
	var event := InputEventScreenDrag.new()
	event.position = at
	event.index = finger
	root.push_input(event, true)


func _shot(name: String) -> void:
	if not _out.is_empty():
		await process_frame
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png(_out.path_join(name + ".png")) == OK, name)


func _check(ok: bool, description: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: ", description)
