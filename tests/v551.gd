extends SceneTree

const Catalog = preload("res://scripts/cultivation_catalog.gd")
const Skill = Catalog.Skill
const Enemy = preload("res://scenes/enemies/enemy.gd")
const Sword = preload("res://scenes/skills/flying_sword.gd")
const BATTLE := "res://scenes/main.tscn"

var _out := ""
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var data := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if not data.contains("/wanmoyuan-v551-test-"):
		printerr("需要隔离的 wanmoyuan-v551-test-* APPDATA")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and DisplayServer.get_name() != "headless":
		_out = args[0]
		if DirAccess.make_dir_recursive_absolute(_out) != OK:
			quit(1)
			return
	await _test_aura()
	await _test_volley()
	if _failures == 0:
		print("V5.5.1 PASS: evolution, aura reach and real homing projectile damage")
	quit(mini(1, _failures))


func _test_aura() -> void:
	var battle := await _battle()
	var skills: Node = battle._skills
	skills._learned.append("sword_storm")
	skills.apply_upgrade(Skill.SWORD, Catalog.RUN_SKILL_CAP - 1)
	skills.apply_upgrade(Skill.SWORD_STORM)
	battle._xp = battle._xp_required
	battle._show_level_up()
	_check(battle._choices[0].type == "evolution" and "每 2.5 秒齐射 12 剑" in battle._upgrade_menu._buttons[0].text,
		"用真实三选一金卡说明强化效果")
	await _shot("01-万剑归宗进化卡")
	battle._on_upgrade_chosen(0)
	_check(skills.slots().size() == 1 and skills.slots()[0].name == "万剑归宗", "两门功法仍按原规则替换为一个槽")
	var inside := _enemy(battle, battle._golem_pool, Vector2(166, -52))
	var outside := _enemy(battle, battle._golem_pool, Vector2(-214, -50))
	skills._ascension.update_blades(0.0, 30, skills.ORBIT_SPEED)
	skills._ascension.update_blades(0.49, 30, skills.ORBIT_SPEED)
	_check(inside._health == 120, "0.5 秒前不跳伤")
	skills._ascension.update_blades(0.01, 30, skills.ORBIT_SPEED)
	_check(inside._health == 48 and outside._health == 120 and skills._visuals._blades.size() == 12
		and is_equal_approx(skills._visuals._auras["blades"].radius, 195.0), "半径 195，旧圈以外真实掉 72 HP，新圈外不伤")
	_caption(battle, "剑阵半径 195 · 内侧石傀 120 → 48")
	await _shot("02-扩大剑阵击中旧范围之外")


func _test_volley() -> void:
	var battle := await _battle()
	var skills: Node = battle._skills
	skills._learned.append("sword_storm")
	skills.apply_upgrade(Skill.SWORD, Catalog.RUN_SKILL_CAP - 1)
	skills.apply_upgrade(Skill.SWORD_STORM)
	skills._apply_evolution(Skill.SWORD)
	var crows: Array[Enemy] = []
	for at in [Vector2(-310, -260), Vector2(330, -260), Vector2(-320, 180), Vector2(320, 185)]:
		var enemy := _enemy(battle, battle._crow_pool, at)
		enemy._health = 250
		crows.append(enemy)
	var boss := _enemy(battle, battle._boss_pool, Vector2(0, -440))
	battle._hud.show_boss("魔尊·外相", boss.max_health)
	battle._hud._boss_notice.hide()
	battle._hud.set_skills(skills.slots())
	skills._physics_process(0.02)
	_check(_live_swords(battle) == 12 and is_equal_approx(skills._divine_volley_left, 2.5), "进化后第一次更新立刻发射十二把金剑")
	skills._update_divine_volley(2.49)
	_check(_live_swords(battle) == 12 and skills._divine_volley_left > 0.0, "不足冷却时间不重复发射")
	crows[0].global_position += Vector2(-40, 80)
	for i in range(18):
		await physics_frame
	_caption(battle, "十二把金剑齐射 · 追击剑阵外目标")
	await _shot("03-金剑齐射追击远处鸦妖和魔尊")
	for i in range(61):
		await physics_frame
	_check(crows.all(func(enemy: Enemy) -> bool: return enemy._health > 0 and enemy._health < 250),
		"四个远程目标均受实体飞剑伤害")
	_check(boss._health < 800 and boss._health > 0, "圈外魔尊实扣血")
	print("V5.5.1 REAL HITS: crows %s, boss %d/800" % [str(crows.map(func(enemy: Enemy) -> int: return enemy._health)), boss._health])
	_caption(battle, "圈外实际命中 · 魔尊 800 → %d" % boss._health)
	await _shot("04-圈外魔尊实扣血")
	skills._update_divine_volley(0.02)
	_check(_live_swords(battle) >= 12 and is_equal_approx(skills._divine_volley_left, 2.5), "冷却到期继续齐射")


func _battle() -> Node:
	paused = false
	change_scene_to_file(BATTLE)
	await scene_changed
	var battle := current_scene
	battle.set_physics_process(false)
	battle._skills.set_physics_process(false)
	return battle


func _enemy(battle: Node, pool: RefCounted, origin: Vector2) -> Enemy:
	var enemy: Enemy = battle._spawn_enemy_at(pool, origin)
	enemy.set_physics_process(false)
	enemy.collision_layer = Enemy.ENEMY_LAYER
	return enemy


func _live_swords(battle: Node) -> int:
	return battle.get_node("Projectiles").get_children().filter(func(node: Node) -> bool:
		return node is Sword and node.visible and node._divine).size()


func _caption(battle: Node, text: String) -> void:
	if _out.is_empty():
		return
	for child: Node in battle.get_node("TouchUI/SafeArea").get_children():
		if child.name == "SwordTestCaption":
			child.text = text
			return
	var label := Label.new()
	label.name = "SwordTestCaption"
	label.position = Vector2(30, 308)
	label.add_theme_font_size_override("font_size", 23)
	label.add_theme_constant_override("outline_size", 7)
	label.text = text
	battle.get_node("TouchUI/SafeArea").add_child(label)


func _shot(name: String) -> void:
	if not _out.is_empty():
		await process_frame
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png(_out.path_join(name + ".png")) == OK, name)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		printerr("FAIL: ", message)
