extends SceneTree
## 桌面渲染验收：真实胜利前计时跑到 180，再截图，不改战斗计时字段。

const START := "res://scenes/ui/start_menu.tscn"
const DemonLord = preload("res://scenes/enemies/demon_lord.gd")
const CAVE_ENTER := "SafeArea/Margin/Content/Enter"

var _output: String
var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var profile_path := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if args.size() != 1 or DisplayServer.get_name() == "headless" or not profile_path.contains("/wanmoyuan-v3-test-"):
		printerr("需要有渲染的窗口、空的隔离测试数据目录和截图输出目录。")
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
		printerr("视觉验收超时")
		quit(1))
	watchdog.start(110.0)

	var save := root.get_node("SaveManager")
	if save.has_profile() or save.load_error() != OK:
		printerr("隔离测试目录不为空。")
		quit(1)
		return
	change_scene_to_file(START)
	await scene_changed
	var start: Button = current_scene.get_node("Center/Content/Start")
	start.pressed.emit()
	await scene_changed
	var cave := current_scene
	_expect(save.settle_run(500, false) == OK, "建立突破用测试进度")
	cave._refresh()
	cave._breakthrough.pressed.emit()
	await create_timer(0.065, true, false, true).timeout
	for i in range(4):
		if cave._cave_layout.position.length() > 1.0:
			break
		await process_frame
	_expect(cave._flash.visible and cave._flash.modulate.a >= 0.70
		and cave._flash.get_global_rect().encloses(root.get_visible_rect()), "亮金光覆盖整屏")
	_expect(cave._notice.text == "突破·筑基" and save.realm() == "foundation", "由洞府按钮实际触发筑基")
	_expect(cave._cave_layout.position.length() > 1.0
		and cave._backdrop.ornament_offset.is_equal_approx(cave._cave_layout.position), "洞府和背景同步震动")
	await _capture("01-breakthrough")
	await cave._flash_tween.finished
	_expect(not cave._flash.visible and not cave._notice.visible
		and cave._cave_layout.position.is_zero_approx(), "震动结束归位")

	var enter: Button = cave.get_node(CAVE_ENTER)
	enter.pressed.emit()
	enter.pressed.emit()
	await scene_changed
	var battle := current_scene
	await process_frame
	await process_frame
	await _verify_slide(battle._gear_overlay, battle._hud.bag_button, battle._close_gear, "04-bag-slide")
	await _verify_slide(battle._shop_menu.get_node("Panel"), battle._hud.shop_button, battle._close_shop, "05-alchemy-slide")
	await _run_to_boss(battle)
	if not is_instance_valid(battle) or not battle._boss_spawned:
		quit(1)
		return
	var enemy: Node3D = battle._living_enemies.filter(func(node: Node3D) -> bool: return node is DemonLord).front()
	_expect(enemy.max_health == 800 and is_equal_approx(battle._hud._boss_bar.max_value, 800.0)
		and battle._hud._boss_bar.size.y >= 70.0, "外渊原有 Boss 血量不变，血条已加粗")
	var shake_seen := false
	var shake_until := Time.get_ticks_msec() + 270
	while Time.get_ticks_msec() < shake_until:
		var cam: Camera3D = battle._camera
		shake_seen = shake_seen or absf(cam.presentation.h_offset) > 1.0 or absf(cam.presentation.v_offset - cam._view_offset) > 1.0
		_auto_upgrade(battle)
		await process_frame
	_expect(shake_seen and battle._camera.h_offset == 0.0 and battle._camera.v_offset == 0.0, "Boss 只震动表现镜头")
	_expect(battle._hud._boss_notice.visible and battle._hud._boss_notice.modulate.a > 0.8, "180 秒触发顶部大字横幅")
	await _capture("02-boss-arrival")

	await _approach_boss(battle, enemy)
	var before: int = enemy._health
	if before <= 100:
		printerr("截图时 Boss 剩余气血不足以演示两个命中。")
		quit(1)
		return
	enemy.take_damage(28)
	var regular_hit: RefCounted = battle._effects._numbers.back()
	_expect(regular_hit.font_size == 36 and not regular_hit.critical, "普通飘字加大")
	await _capture("03-boss-fight")
	battle._effects._numbers.clear()
	enemy.take_damage(62, true) # 仅演示带暴击标记的表现，不给正式玩法增加判定或倍率。
	var critical_hit: RefCounted = battle._effects._numbers.back()
	_expect(critical_hit.font_size == 52 and critical_hit.critical and enemy._health == before - 90,
		"暴击标记改变颜色与字号，不改变传入的伤害")
	await _capture("06-critical-preview")

	watchdog.stop()
	if not _failed:
		print("V3 POLISH PASS: ", _output)
	quit(1 if _failed else 0)


func _run_to_boss(battle: Node) -> void:
	seed(3104180)
	battle._loot_rng.seed = 3104
	battle._player.accepts_damage = false
	var previous_ticks := Engine.physics_ticks_per_second
	var previous_steps := Engine.max_physics_steps_per_frame
	Engine.physics_ticks_per_second = 240
	Engine.max_physics_steps_per_frame = 24
	Engine.time_scale = 6.0
	var previous_elapsed := 0.0
	var time_limit := Time.get_ticks_msec() + 80000
	while not battle._boss_spawned and Time.get_ticks_msec() < time_limit:
		previous_elapsed = battle._elapsed
		_auto_upgrade(battle)
		await physics_frame
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = previous_ticks
	Engine.max_physics_steps_per_frame = previous_steps
	_expect(previous_elapsed < 180.0 and battle._elapsed + 0.000001 >= 180.0 and battle._elapsed < 180.15
		and battle._boss_spawned and battle._kills > 0, "实跑战斗计时过 180 秒才刷出 Boss")
	print("BOSS TIMING: %.3f -> %.3f game seconds; %d normal kills" % [previous_elapsed, battle._elapsed, battle._kills])


func _approach_boss(battle: Node, enemy: Node3D) -> void:
	var view := root.get_visible_rect()
	var screen_area := Rect2(view.size * Vector2(0.16, 0.40), view.size * Vector2(0.68, 0.36))
	var time_limit := Time.get_ticks_msec() + 16000
	while Time.get_ticks_msec() < time_limit and enemy._health > 0:
		var at: Vector3 = enemy.get_node("Body").global_position
		var camera: Camera3D = battle._camera.presentation
		if not camera.is_position_behind(at) and screen_area.has_point(camera.unproject_position(at)):
			battle._player._on_joystick_direction_changed(Vector2.ZERO)
			return
		var to: Vector3 = enemy.global_position - battle._player.global_position
		var direction := Vector2(to.x, to.z).normalized()
		direction = direction.rotated(sin(Time.get_ticks_msec() * 0.003) * 0.34)
		battle._player._on_joystick_direction_changed(direction)
		_auto_upgrade(battle)
		await process_frame
	battle._player._on_joystick_direction_changed(Vector2.ZERO)
	_expect(false, "Boss 模型实际进入画面供截图")


func _verify_slide(panel: Control, opener: Button, close: Callable, shot: String) -> void:
	var rest := panel.position.y
	opener.pressed.emit()
	var start_y := panel.position.y
	var size_at_start := panel.size
	_expect(paused and start_y >= (panel.get_parent() as Control).size.y - 2.0, shot + " 从底部开始")
	var tween: Tween = panel.get_meta("panel_tween")
	var in_between := false
	while tween.is_running():
		await process_frame
		var y := panel.position.y
		if not in_between and y < start_y - 30.0 and y > rest + 30.0:
			in_between = true
			_expect(panel.size.is_equal_approx(size_at_start), shot + " 平移时面板未被拉伸")
			await _capture(shot)
	_expect(in_between and is_equal_approx(panel.position.y, rest) and paused, shot + " 暂停中滑入并停在原位")
	close.call()
	_expect(not paused, shot + " 关闭后恢复战斗")


func _auto_upgrade(battle: Node) -> void:
	if battle._upgrade_menu.visible:
		battle._upgrade_menu.choice_selected.emit(0)


func _capture(id: String) -> void:
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	_expect(frame.save_png(_output.path_join(id + ".png")) == OK, "截图 " + id)


func _expect(ok: bool, label: String) -> void:
	if not ok:
		printerr("FAIL: ", label)
		_failed = true
