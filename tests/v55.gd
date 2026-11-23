extends SceneTree

const BATTLE := "res://scenes/main.tscn"
const CAVE := "res://scenes/ui/cave_menu.tscn"
const SAVE := "user://save.cfg"
const Enemy = preload("res://scenes/enemies/enemy.gd")
const Camera = preload("res://scenes/world/battle_camera.gd")
const Cultivation = preload("res://scripts/cultivation_catalog.gd")
const Equipment = preload("res://scripts/equipment_catalog.gd")
const Rock = preload("res://scenes/world/rock_art.gd")
const Skill = Cultivation.Skill

var _out := ""
var _failures := 0
var _note: Label


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var path := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if not path.contains("/wanmoyuan-v55-test-"):
		printerr("需要隔离的 wanmoyuan-v55-test-* APPDATA")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and DisplayServer.get_name() != "headless":
		_out = args[0]
		if DirAccess.make_dir_recursive_absolute(_out) != OK:
			quit(1)
			return
	create_timer(40.0, true, false, true).timeout.connect(func() -> void:
		printerr("V5.5 验收超时")
		quit(1))
	seed(540)
	await _camera()
	await _actors_and_order()
	await _planar_physics()
	await _power()
	await _drops_and_stop()
	if args.size() > 1:
		await _old_save(args[1])
	if _failures == 0:
		print("V5.5 PASS: scene, camera, 2D art, and play invariants")
	await create_timer(0.25, true, false, true).timeout
	quit(mini(_failures, 1))


func _camera() -> void:
	var battle := await _battle()
	var cam: Camera = battle._camera
	var width := cam.world_view().size.x
	var projected_width := Camera.VIEW_WIDTH * root.get_visible_rect().size.x / 720.0
	_expect(cam.is_current() and cam.global_rotation == 0.0 and absf(width - projected_width) < 0.1, "Camera2D 正俯视宽度与缩放")
	var before := cam.focus
	var target := Vector2(180.0, -50.0)
	cam.follow(target, 0.03)
	_expect(cam.focus.is_equal_approx(before.lerp(target, 0.21)), "沿用真实跟随插值")
	cam.snap_to(Vector2.ZERO)
	for x in range(-2, 3):
		for y in range(-2, 3):
			if x != 0 or y != 0:
				_enemy(battle, battle._wolf_pool, Vector2(x * 205.0, y * 280.0))
	print("V5.5 CAMERA: logical %.0fx%.0f, width %.3f, zoom %.6f" % [
		root.get_visible_rect().size.x, root.get_visible_rect().size.y, width, cam.zoom.x])
	await _shot("验收01b-V5.5同位置俯视对比", "同地点 · 外渊 (0, 0) · 世界宽度 %.0f" % width)
	var far := Vector2(-3570.0, 4630.0)
	battle._player.global_position = far
	cam.snap_to(far)
	battle._ground.follow(far)
	await _shot("验收02-暗角网格和远处地面", "跨区地面 · 细网格 / 边缘压暗")


func _actors_and_order() -> void:
	var battle := await _battle()
	var player: Node2D = battle._player
	var initial: Vector2 = player.global_position
	player._on_joystick_direction_changed(Vector2.RIGHT)
	player.set_physics_process(true)
	for i in range(8):
		await physics_frame
	player._on_joystick_direction_changed(Vector2.ZERO)
	player.set_physics_process(false)
	_expect(player._body.facing == Vector2.RIGHT and player.global_position.x > initial.x + 10.0, "移动与指向一致")
	var origin: Vector2 = player.global_position
	var wolf := _enemy(battle, battle._wolf_pool, origin + Vector2(-165, -44))
	_enemy(battle, battle._crow_pool, origin + Vector2(175, -36))
	_enemy(battle, battle._golem_pool, origin + Vector2(140, 110))
	var boss := _enemy(battle, battle._boss_pool, origin + Vector2(0, -270))
	boss.take_damage(600)
	battle._hud.show_boss("魔尊·外相", 800)
	battle._hud.set_boss_health(boss._health)
	battle._hud.set_boss_stage(4)
	battle._hud._boss_notice.hide()
	if not _out.is_empty():
		await create_timer(0.36).timeout
	await _shot("验收03-四类怪物同屏辨识", "红圆 · 紫翼 · 石傀 · 魔尊 Ⅳ")
	var wolf_at := wolf.global_position
	wolf.take_damage(3)
	_expect(wolf._body.hit_white and wolf._body.position.length() > 0.0 and wolf.global_position == wolf_at,
		"受击白闪与纯视觉击退，不改变碰撞位置")
	await _shot("验收04a-朝向指示和受击白闪", "向右走 · 白闪和击退不移动判定体")
	wolf.stone_drop_chance = 0.0
	wolf.take_damage(wolf.max_health)
	var crystal: Node = null
	for node: Node in battle.get_node("Pickups").get_children():
		if node.visible and node.scene_file_path.ends_with("spirit_crystal.tscn"):
			crystal = node
	_expect(crystal != null and not crystal.get_node("Ink").visible, "掉落已可判定，表现等待消散")
	await create_timer(0.115, true).timeout
	_expect(wolf.visible and wolf._body.scale.x < 1.0 and wolf._body.modulate.a < 1.0, "缩小淡出同时发生")
	await _shot("验收04b-怪物缩小和淡出", "死亡消散 · 原回池时序 0.20 秒")
	await create_timer(0.16, true).timeout
	_expect(not wolf.visible and crystal != null and crystal.get_node("Ink").visible, "消散结束回池和显示掉落")

	battle = await _battle()
	player = battle._player
	var rock: Rock = battle.get_node("BattleWorld/Rocks").get_children().filter(
		func(item: Rock) -> bool: return item.global_position.length() < 450.0).front()
	rock.global_rotation = 0.0
	var behind := rock.global_position + Vector2(0, -43)
	var in_front := rock.global_position + Vector2(0, 43)
	battle._camera.snap_to(rock.global_position)
	battle.set_process(false)
	player.global_position = behind
	await _shot("验收05a-石后玩家被遮挡", "同一石头：角色在北侧，遮住身体")
	if not _out.is_empty():
		var pixel := _screen_pixel(battle._camera.screen_at(behind))
		_expect(pixel.g < 0.45, "北侧岩石挡住角色中心像素")
	player.global_position = in_front
	await _shot("验收05b-石前玩家不被遮挡", "同一石头：角色在南侧，显示在前")
	if not _out.is_empty():
		var pixel := _screen_pixel(battle._camera.screen_at(in_front))
		_expect(pixel.g > 0.62, "南侧能看到青色角色中心")
	_expect(battle.y_sort_enabled and battle.get_node("BattleWorld/Rocks").y_sort_enabled, "真实 y-sort 而非手动隐藏")


func _planar_physics() -> void:
	var battle := await _battle()
	battle.set_process(false) # 保持当前测试岩石的区块索引，不影响碰撞步进。
	var player: CharacterBody2D = battle._player
	var rock: Rock = battle.get_node("BattleWorld/Rocks").get_children().filter(
		func(item: Rock) -> bool: return item.global_position.length() < 450.0).front()
	rock.global_rotation = 0.0
	player.global_position = rock.global_position + Vector2(0, -67)
	player._on_joystick_direction_changed(Vector2.DOWN)
	player.set_physics_process(true)
	for i in range(18):
		await physics_frame
	player._on_joystick_direction_changed(Vector2.ZERO)
	player.set_physics_process(false)
	print("V5.5 GROUND: player=", player.global_position, " rock=", rock.global_position,
		" mask=", player.collision_mask, " layer=", rock.collision_layer)
	_expect(player.global_position.y <= rock.global_position.y - 43.5 and player.global_position.y >= rock.global_position.y - 45.0,
		"真实地形接触：矩形半深 28 + 玩家半径 16")
	var a := _enemy(battle, battle._wolf_pool, rock.global_position + Vector2(0, 65))
	var b := _enemy(battle, battle._wolf_pool, rock.global_position + Vector2(0, 105))
	a.collision_layer = Enemy.ENEMY_LAYER
	b.collision_layer = Enemy.ENEMY_LAYER
	battle._launch_sword(player.global_position, Vector2.DOWN, 7)
	for i in range(32):
		await physics_frame
	_expect(a._health == a.max_health - 7 and b._health == b.max_health,
		"真实射线穿石，只命中第一只怪 (%d/%d)" % [a._health, b._health])


func _power() -> void:
	var battle := await _battle()
	var skills: Node = battle._skills
	var pool: RefCounted = battle._wolf_pool
	_enemy(battle, pool, Vector2(195, -350))
	skills.apply_upgrade(Skill.SWORD, Cultivation.RUN_SKILL_CAP - 1)
	skills._cast_swords(Cultivation.RUN_SKILL_CAP)
	var projectiles := battle.get_node("Projectiles").get_children().filter(
		func(item: Node2D) -> bool: return item.visible and item.scene_file_path.ends_with("flying_sword.tscn"))
	_expect(projectiles.size() == 8, "御剑术 Lv3 仍发射八剑")
	for sword: Node2D in projectiles:
		sword.set_physics_process(false)
		sword.global_position += sword._direction * 245.0
	await _shot("验收06a-柳叶飞剑和短拖尾", "御剑术 Lv3 · 柳叶剑与拖尾")
	for sword: Node2D in projectiles:
		battle._recycle_sword(sword)
		sword.set_physics_process(true)
	skills.apply_upgrade(Skill.ORBS)
	var target := _enemy(battle, pool, Vector2(52, -10))
	skills._update_orbs(0.0, 1)
	skills._update_orbs(0.49, 1)
	_expect(target._health == target.max_health, "圈内不到 0.5 秒不伤")
	skills._update_orbs(0.01, 1)
	_expect(target._health == target.max_health - 5, "半秒 60% 跳伤")
	var visuals: Node = skills._visuals
	_expect(visuals._auras.has("orbs") and visuals._pulses.any(func(pulse: Dictionary) -> bool: return pulse.left > 0.0),
		"真实跳伤事件触发圆环脉动")
	await _shot("验收06b-护体罡气跳伤脉动", "护体罡气 · 0.50 秒首跳")
	skills._learned = Cultivation.SKILLS
	skills.apply_upgrade(Skill.SWORD_STORM)
	battle._xp = battle._xp_required
	battle._show_level_up()
	_expect(battle._choices[0].type == "evolution" and Cultivation.evolution_recipe("sword") in battle._upgrade_menu._buttons[0].text,
		"进化卡在第一位并附配方")
	await _shot("验收11a-三选一和进化配方", "")
	battle._on_upgrade_chosen(0)
	skills._physics_process(0.01)
	_expect(skills._ascension._blade_offsets.size() == 12 and visuals._blades.size() == 12, "逻辑与显示均 12 把环绕剑")
	await _shot("验收06c-万剑归宗十二把环绕飞剑", "万剑归宗 · 12 把")
	battle._open_game_menu()
	await create_timer(0.36, true, false, true).timeout
	_expect(battle._game_menu._skill_bar._slots.size() == 6 and battle._game_menu._recipes.visible, "暂停六格和进化提示")
	await _shot("验收11b-暂停功法栏和进化提示", "")
	battle._game_menu._back_pressed()


func _drops_and_stop() -> void:
	var battle := await _battle()
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for quality in range(4):
		battle._drop_equipment(Vector2((quality - 1.5) * 170.0, -210.0 + quality * 20.0),
			Equipment.create_item("weapon", 0, quality, rng))
	var pickup: Node = battle._stone_pool.acquire()
	pickup.drop(Vector2(0, -90), battle._player, 10)
	await _shot("验收07-青色灵石和蓝紫装备光柱", "青菱为灵石 · 蓝 / 紫光柱沿用原品质色")
	var screen := root.get_visible_rect()
	battle._camera._apply_view_shake(0.4)
	_expect(battle._camera._shake.length() > 0.0 and battle._camera.world_view().size.x >= screen.size.x,
		"屏幕震动生效且保持视野宽度")
	battle._camera._apply_view_shake(1.0)
	var events := []
	battle.hit_stop_triggered.connect(func(kills: int) -> void: events.append(kills))
	for i in range(5):
		var enemy := _enemy(battle, battle._wolf_pool, Vector2(-95.0 + i * 36.0, -100.0))
		enemy._health = 1
	battle._skills._ascension._cast_bell(0)
	_expect(events == [5] and Engine.time_scale == 0.05, "实际一次摄魂铃五杀触发顿帧")
	print("V5.5 HIT STOP: kills=5 time_scale=%.2f / %.3fs shake=24" % [Engine.time_scale, battle.HIT_STOP_SECONDS])
	await _shot("验收09-顿帧五杀触发日志与震屏", "单次五杀 · time_scale = 0.05 / 0.060s")
	await create_timer(0.085, true, false, true).timeout
	_expect(Engine.time_scale == 1.0, "真实秒结束后恢复全局时间")


func _old_save(source: String) -> void:
	var original := FileAccess.get_file_as_string(source)
	var config := ConfigFile.new()
	_expect(config.load(source) == OK and config.get_value("save", "save_version", 0) == 6, "真实 V5.0 存档")
	if original.is_empty():
		return
	var written := FileAccess.open(SAVE, FileAccess.WRITE)
	written.store_string(original)
	written.close()
	var save: Node = root.get_node("SaveManager")
	_expect(save._load_profile() == OK and FileAccess.get_file_as_string(SAVE) == original, "V6 旧档只读不迁移")
	for key: String in config.get_section_keys("profile"):
		_expect(config.get_value("profile", key) == save._profile.get(key), "旧档字段一致: " + key)
	var cave := (load(CAVE) as PackedScene).instantiate()
	change_scene_to_node(cave)
	await scene_changed
	_note = null
	await _shot("验收12-V5旧档直接读取", "")


func _battle() -> Node:
	var scene := (load(BATTLE) as PackedScene).instantiate()
	change_scene_to_node(scene)
	paused = false
	await scene_changed
	_note = null
	scene.set_physics_process(false)
	scene._player.set_physics_process(false)
	scene._player.accepts_damage = false
	scene._skills.set_physics_process(false)
	return scene


func _enemy(battle: Node, pool: RefCounted, at: Vector2) -> Enemy:
	var enemy: Enemy = battle._spawn_enemy_at(pool, at)
	enemy.set_physics_process(false)
	enemy._update_art(0.0)
	return enemy


func _shot(filename: String, caption: String) -> void:
	if _out.is_empty():
		return
	if is_instance_valid(_note):
		_note.hide()
		_note.queue_free()
	if not caption.is_empty():
		_note = Label.new()
		_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_note.position = Vector2(35, 305)
		_note.text = caption
		_note.add_theme_font_size_override("font_size", 20)
		_note.add_theme_constant_override("outline_size", 7)
		current_scene.get_node("TouchUI/SafeArea").add_child(_note)
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(_out.path_join(filename + ".png")) == OK, filename)


func _screen_pixel(point: Vector2) -> Color:
	var image := root.get_texture().get_image()
	var screen := root.get_visible_rect().size
	var pixel := Vector2i(point / screen * Vector2(image.get_size()))
	return image.get_pixelv(pixel)


func _expect(ok: bool, text: String) -> void:
	if not ok:
		_failures += 1
		printerr("FAIL: ", text)
