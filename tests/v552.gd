extends SceneTree

const Catalog = preload("res://scripts/cultivation_catalog.gd")
const DemonLord = preload("res://scenes/enemies/demon_lord.gd")
const Orb = preload("res://scenes/enemies/magic_orb.gd")
const Player = preload("res://scenes/player.gd")
const BATTLE := "res://scenes/main.tscn"

var _out := ""
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var data := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if not data.contains("/wanmoyuan-v552-test-"):
		printerr("需要隔离的 wanmoyuan-v552-test-* APPDATA")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and DisplayServer.get_name() != "headless":
		_out = args[0]
		if DirAccess.make_dir_recursive_absolute(_out) != OK:
			quit(1)
			return
	change_scene_to_file(BATTLE)
	await scene_changed
	var battle := current_scene
	battle.set_physics_process(false)
	battle._player.set_physics_process(false)
	battle._skills.set_physics_process(false)
	await _six_skills(battle)
	await _boss(battle)
	if _failures == 0:
		print("V5.5.2 PASS: six slots, Lv3 and tiered boss attacks")
	quit(mini(1, _failures))


func _six_skills(battle: Node) -> void:
	var skills: Node = battle._skills
	var skill = Catalog.Skill
	skills._learned = Catalog.SKILLS.duplicate()
	_check(battle._hud._skill_bar._slots.size() == 6 and skills.slots().size() == 1, "开局六格，只有御剑 Lv1")
	skills.apply_upgrade(skill.SWORD)
	skills.apply_upgrade(skill.SWORD_STORM)
	_check(skills._levels[skill.SWORD] == 2 and not skills._can_evolve(skill.SWORD), "Lv2 不可进化")
	for id: int in [skill.SWORD, skill.LIGHTNING, skill.ORBS, skill.ICE, skill.HEAL]:
		skills.apply_upgrade(id)
	skills.apply_upgrade(skill.FIRE)
	_check(skills.slots().size() == 6 and skills._levels[skill.SWORD] == 3 and skills._levels[skill.FIRE] == 0,
		"Lv3 封顶且不允许第七门")
	skills.apply_upgrade(skill.SWORD, 9)
	_check(skills._levels[skill.SWORD] == 3, "不能超过 Lv3")
	battle._hud.set_skills(skills.slots())
	await _shot("01-局内六格御剑三级")
	battle._xp = battle._xp_required
	battle._show_level_up()
	_check(battle._choices[0].type == "evolution" and battle._choices[0].id == skill.SWORD
		and battle._choices.all(func(card: Dictionary) -> bool: return card.type != "new"), "满六格仍可出进化，不出新功法")
	await _shot("02-三级出现万剑归宗金卡")
	battle._on_upgrade_chosen(0)
	_check(skills.slots().size() == 5 and skills.slots()[0].name == "万剑归宗", "进化释放一个槽")
	skills.apply_upgrade(skill.FIRE)
	_check(skills.slots().size() == 6 and skills._levels[skill.FIRE] == 1, "释放的槽能学新功法")


func _boss(battle: Node) -> void:
	var player: Player = battle._player
	battle._spawn_boss()
	var boss: DemonLord = battle._living_enemies[0]
	boss.set_physics_process(false)
	boss.global_position = Vector2(0, -220)
	player.global_position = Vector2(0, -12)
	var initial_hp := player.health
	var directions: Array[Vector2] = []
	boss.flame_cast.connect(func(_at: Vector2, direction: Vector2, _amount: int): directions.append(direction))
	boss._cast_flames()
	_check(directions.size() == 5 and absf(rad_to_deg(directions[0].angle_to(directions[4])) - 72.0) < 0.01,
		"常规魔焰扇面从 60 度扩到 72 度")
	for node: Node in battle.get_node("Projectiles").get_children():
		if node is Orb and node.visible:
			_check(node._hit_radius == Player.BODY_RADIUS + 14.0 and node._time_left == Orb.BOSS_LIFETIME, "Boss 弹体加宽、行程增长")
			battle._recycle_orb(node)
	boss._quake_left = 0.0
	boss._update_attack(0.01)
	_check(boss._hazard_centers.is_empty(), "一阶段不放二阶段震荡")
	boss.take_damage(200)
	boss._update_attack(0.01)
	_check(boss.stage == 2 and boss._hazard_duration == 1.3 and boss._hazard_radius == 230.0 and player.health == initial_hp,
		"75% 解锁裂地震荡，先预警不扣血")
	await _shot("03-裂地震荡橙色预警")
	player.global_position = Vector2(0, 15)
	boss._update_hazard(1.3)
	_check(player.health == initial_hp, "离开震荡边界即可躲避")
	player.global_position = Vector2(0, -10)
	boss._warn_quake()
	boss._update_hazard(1.299)
	_check(player.health == initial_hp, "预警结束前不掉血")
	boss._update_hazard(0.0011)
	_check(player.health == initial_hp - 30, "震荡到点后对圈内玩家实际造成伤害")
	player._invulnerable_left = 0.0
	boss.take_damage(200)
	boss._update_attack(0.01)
	var charge_direction := boss._charge_direction
	player.global_position.x += 120.0
	boss._update_attack(1.0)
	_check(boss._charge_direction == charge_direction and boss._motion_left == 0.72, "冲锋预警锁定方向，冲程提高 20%")
	boss._motion = DemonLord.Motion.WALK
	boss._charge_left = 99.0
	boss._quake_left = 99.0
	directions.clear()
	boss.take_damage(200)
	boss._meteor_left = 0.0
	boss._update_attack(0.01)
	_check(directions.size() == 7 and absf(rad_to_deg(directions[0].angle_to(directions[6])) - 135.0) < 0.01,
		"四阶段弹幕七发，扇面 135 度")
	for node: Node in battle.get_node("Projectiles").get_children():
		if node is Orb and node.visible:
			battle._recycle_orb(node)
	var marked := boss._hazard_centers
	_check(marked.size() == 3 and marked[1] == player.global_position and boss._hazard_radius == 95.0
		and boss._hazard_duration == 1.25, "25% 解锁天魔陨火，三个固定落点")
	await _shot("04-天魔陨火三个紫色落点")
	player.global_position = marked[1].lerp(marked[0], 0.5)
	var before := player.health
	boss._update_hazard(1.25)
	_check(player.health == before - 36, "陨火实际命中，两个预警圈重叠也只扣一次")
	await _shot("05-天魔陨火落地实际扣血")
	boss._warn_meteors()
	boss.take_damage(200)
	_check(boss._hazard_centers.is_empty() and boss._danger._centers.is_empty() and not player.accepts_damage,
		"Boss 一死取消地面攻击，不影响安全拾取")


func _shot(name: String) -> void:
	if not _out.is_empty():
		await process_frame
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png(_out.path_join(name + ".png")) == OK, name)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		printerr("FAIL: ", message)
