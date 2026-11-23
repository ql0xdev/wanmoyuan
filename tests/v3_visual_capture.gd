extends SceneTree
## 在 v3.0 和 v3.1 用同一脚本、同一窗口尺寸生成画面对照与逻辑投影采样。

const Gear = preload("res://scripts/equipment_catalog.gd")
const START := "res://scenes/ui/start_menu.tscn"
const VIEW := "SafeArea/Margin/Content/"

var _output: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var data_dir := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if DisplayServer.get_name() == "headless" or args.size() != 1 or not data_dir.contains("/wanmoyuan-v3-test-"):
		printerr("需要渲染窗口、隔离测试数据目录和一个截图输出目录。")
		quit(1)
		return
	_output = args[0]
	if DirAccess.make_dir_recursive_absolute(_output) != OK:
		quit(1)
		return
	var watchdog := Timer.new()
	watchdog.process_mode = Node.PROCESS_MODE_ALWAYS
	watchdog.ignore_time_scale = true
	watchdog.one_shot = true
	root.add_child(watchdog)
	watchdog.timeout.connect(func() -> void:
		printerr("画面对照采集超时")
		quit(1))
	watchdog.start(20.0)
	var save := root.get_node("SaveManager")
	if save.has_profile() or save.load_error() != OK:
		printerr("需要空测试目录。")
		quit(1)
		return
	change_scene_to_file(START)
	await scene_changed
	await _capture("01-start")
	var start_button := _button("Center/Content/Start")
	if start_button.has_meta(&"visual_feedback"):
		if not await _check_button_feedback(start_button):
			quit(1)
			return
	start_button.pressed.emit()
	await scene_changed
	var cave := current_scene
	var items := _fixture_gear()
	if save.settle_run(650, false, "outer", items) != OK or save.change_equipment(2, true) != OK:
		printerr("无法建立截图用测试进度。")
		quit(1)
		return
	cave._refresh()
	await _capture("02-cultivation")
	cave._breakthrough.pressed.emit()
	await _capture("03-breakthrough")
	await create_timer(1.90).timeout
	cave._skill_nodes.sword_storm.button.pressed.emit()
	cave._passive_nodes.body.button.pressed.emit()
	cave._tabs.current_tab = 1
	await _capture("04-skills")
	var scroll := cave._skill_tree.get_parent() as ScrollContainer
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _capture("05-passives")
	cave._tabs.current_tab = 2
	cave._storage._select(4)
	await _capture("06-storage")
	_button(VIEW + "Enter").pressed.emit()
	cave._abyss_buttons.middle.pressed.emit()
	await _capture("07-preparation")
	_button(VIEW + "Enter").pressed.emit()
	await scene_changed

	var battle := current_scene
	battle.set_physics_process(false)
	battle._skills.set_physics_process(false)
	battle._player.take_damage(59)
	battle._player.accepts_damage = false
	battle._spirit_stones = 170
	battle._hud.set_spirit_stones(170)
	battle._hud.set_survival_time(106)
	battle._xp = 3
	battle._refresh_hud()
	for i in range(6):
		var pool: RefCounted = battle._crow_pool if i % 3 == 0 else battle._wolf_pool
		battle._spawn_enemy_at(pool, Vector3((i % 3 - 1) * 166, 0, -450 + (i / 3.0) * 130))
	var golem: Node = battle._spawn_enemy_at(battle._golem_pool, Vector3(-122, 0, -112))
	battle._loot_rng.seed = 3104
	golem.take_damage(golem.max_health)
	_write_projection(battle)
	await _capture("08-battle-and-loot")
	if battle.has_method("_drop_equipment"):
		var loot_positions := [
			Vector3(-210, 0, -270), Vector3(210, 0, -270),
			Vector3(-230, 0, 180), Vector3(230, 0, 180),
		]
		for i in range(4):
			battle._drop_equipment(loot_positions[i], items[i].duplicate(true))
		await _capture("15-ground-gear")
	var currency: int = battle._spirit_stones
	battle._open_shop()
	await create_timer(0.23, true).timeout
	await _capture("09-alchemy")
	if battle._spirit_stones != currency:
		printerr("仅打开面板不应消耗灵石。")
		quit(1)
		return
	battle._close_shop()
	for item: Dictionary in items.slice(0, 8):
		battle._inventory.collect(item.duplicate(true))
	battle._open_bag()
	battle._gear_menu._select(-3)
	await create_timer(0.23, true).timeout
	await _capture("10-bag")
	battle._close_gear()
	battle._xp = battle._xp_required
	battle._show_level_up()
	await _capture("11-upgrade")
	battle._upgrade_menu.choice_selected.emit(0)
	battle._spawn_boss()
	var boss: Node3D = battle._living_enemies.back()
	boss.global_position = Vector3(95.0, 0.0, -360.0)
	await _capture("12-boss")
	battle._open_game_menu()
	await create_timer(0.23, true).timeout
	await _capture("13-pause")
	battle._game_menu._back.pressed.emit()
	if battle.has_method("_start_victory_loot"):
		boss.take_damage(boss.max_health)
		await create_timer(0.65, true, false, true).timeout
		await _capture("16-evacuation")
	battle._elapsed = 185.7
	battle._show_result(true)
	await _capture("14-result")
	await create_timer(0.55, true).timeout
	watchdog.stop()
	print("V3 VISUAL PASS: ", _output)
	quit()


func _fixture_gear() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31041
	var gear: Array = []
	for i in range(12):
		var quality := i % 4
		var item := Gear.roll(i % 3, 1.0 if quality == 3 else 0.0, rng)
		while item.quality != quality:
			item = Gear.roll(i % 3, 0.0, rng)
		gear.append(item)
	return gear


func _write_projection(battle: Node) -> void:
	var camera: Camera3D = battle._camera
	var render := root.get_camera_3d()
	var viewport := root.get_visible_rect().size
	var back_projections := PackedStringArray()
	for ratios in [Vector2(0.5, 0.5), Vector2(0.1, 0.12), Vector2(0.88, 0.85)]:
		var point: Vector3 = battle._camera.ground_at(ratios * viewport)
		back_projections.append("%0.3f %0.3f" % [point.x, point.z])
	seed(310)
	for i in range(8):
		var point: Vector3 = battle._outside_screen_position()
		back_projections.append("%0.3f %0.3f" % [point.x, point.z])
	var marker: Vector3 = battle._player.global_position
	var file := FileAccess.open(_output.path_join("projection.txt"), FileAccess.WRITE)
	file.store_line("logic=%s" % "|".join(back_projections))
	file.store_line("logic_y=%.4f" % (camera.unproject_position(marker).y / viewport.y))
	file.store_line("render_y=%.4f" % (render.unproject_position(marker).y / viewport.y))
	file.store_line("pitch=%.1f" % rad_to_deg(render.global_rotation.x))
	file.store_line("fog=%s" % bool(battle.get_node("BattleWorld/WorldEnvironment").environment.fog_enabled))


func _capture(id: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if frame.save_png(_output.path_join(id + ".png")) != OK:
		printerr("无法保存截图：", id)
		quit(1)


func _check_button_feedback(button: Button) -> bool:
	var hit_rect := button.get_global_rect()
	button.button_down.emit()
	await create_timer(0.13).timeout
	await process_frame
	var ink := button.material as ShaderMaterial
	var draw_scale: float = -1.0 if ink == null else ink.get_shader_parameter("press_scale")
	if not is_equal_approx(draw_scale, 0.94) or not hit_rect.is_equal_approx(button.get_global_rect()):
		printerr("按压反馈验证失败：缩放 ", draw_scale, "，按压前 ", hit_rect, "，按压后 ", button.get_global_rect())
		return false
	button.button_up.emit()
	await create_timer(0.13).timeout
	await process_frame
	if button.material != null or not hit_rect.is_equal_approx(button.get_global_rect()):
		printerr("按钮松开后未恢复绘制。")
		return false
	return true


func _button(path: String) -> Button:
	return current_scene.get_node(path)
