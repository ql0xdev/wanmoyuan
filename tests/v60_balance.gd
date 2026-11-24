extends SceneTree

const Catalog = preload("res://scripts/cultivation_catalog.gd")
const Stats = preload("res://scripts/stats_manager.gd")
const Equipment = preload("res://scripts/equipment_catalog.gd")
const Fixture = preload("res://tests/realm_fixture.gd")
const POWERS := [1.0, 2.0, 4.0, 8.0, 16.0, 32.0]
const COSTS := [500, 2000, 8000, 30000, 100000]

var _failures := 0
var _directory := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var user_dir := OS.get_user_data_dir().replace("\\", "/").to_lower()
	var save := root.get_node("SaveManager")
	if not user_dir.contains("/wanmoyuan-v60-balance-test-") or save.has_profile() or save.load_error() != OK:
		printerr("需要空的 wanmoyuan-v60-balance-test-* 隔离目录")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and DisplayServer.get_name() != "headless":
		_directory = args[0]
		if DirAccess.make_dir_recursive_absolute(_directory) != OK:
			quit(1)
			return
	create_timer(60.0, true, false, true).timeout.connect(func() -> void: quit(1))
	_check(save.settle_run(Fixture.TRIBULATION_BUDGET, false) == OK, "准备原价覆盖全部大、小突破的隔离存档")
	change_scene_to_file("res://scenes/ui/cave_menu.tscn")
	await scene_changed
	var cave := current_scene
	var keys := Catalog.REALMS.keys()
	_check(keys.size() == POWERS.size(), "六个大境界")
	for i in range(keys.size()):
		_check(Catalog.REALMS[keys[i]].power == POWERS[i], "基础倍率 " + str(keys[i]))
	for i in range(COSTS.size()):
		var source: String = keys[i]
		var target: String = keys[i + 1]
		var points: int = save.skill_points()
		_check(save.realm() == source and save.realm_layer() == 1 and save.breakthrough() == ERR_UNAVAILABLE, "一层不能大突破")
		var balance: int = save.spirit_stones()
		var cost := Catalog.layer_cost(source)
		_check(cost == roundi(COSTS[i] * 0.08), "小突破仍为原费用的 8%")
		for step in range(1, 9):
			cave._breakthrough.pressed.emit()
			_check(save.realm_layer() == step + 1 and save.spirit_stones() == balance - cost * step
				and save.skill_points() == points, "小突破逐层扣费且不给点")
		var stats_before := _copy_stats(save)
		_check(stats_before.max_health() == roundi(100 * POWERS[i] * 1.64)
			and is_equal_approx(stats_before.attack_multiplier(), POWERS[i] * 1.64)
			and _matches_panel(cave, stats_before), "九层实际攻击与气血和面板一致")
		var from: String = save.realm_name()
		var shot_before := await _screen()
		cave._breakthrough.pressed.emit()
		# 先在按下的同一帧断言，不让任何动画或延迟更新掩盖回退。
		var stats_after := _copy_stats(save)
		var to: String = save.realm_name()
		_check(save.realm() == target and save.realm_layer() == 1 and save.spirit_stones() == balance - 8 * cost - COSTS[i]
			and save.skill_points() == points + 3, "原大突破价、回一层、送三点")
		_check(_matches_panel(cave, stats_after) and stats_after.max_health() == roundi(100 * POWERS[i + 1])
			and is_equal_approx(stats_after.attack_multiplier(), POWERS[i + 1]), "大突破同帧更新面板")
		_check(stats_after.attack_multiplier() > stats_before.attack_multiplier()
			and stats_after.max_health() > stats_before.max_health(), "气血和攻击均严格上涨 " + from + " → " + to)
		_check(is_equal_approx(stats_after.attack_multiplier() / stats_before.attack_multiplier(), 2.0 / 1.64)
			and is_equal_approx(float(stats_after.max_health()) / stats_before.max_health(), 2.0 / 1.64), "空装面板两项涨幅约 21.95%")
		_check_equipped(source, target)
		print("%s -> %s: %d / x%.2f -> %d / x%.2f" % [
			from, to, stats_before.max_health(), stats_before.attack_multiplier(), stats_after.max_health(), stats_after.attack_multiplier()])
		if not _directory.is_empty():
			await create_timer(2.05).timeout
			var shot_after := await _screen()
			_write_comparison(i + 1, from, to, shot_before, shot_after)

	_check(save.realm() == "tribulation" and save.spirit_stones() == 0 and save.skill_points() == 15, "五次正常突破总价、奖励不变")
	_check(int(save.SAVE_VERSION) == 7 and "save_version=7" in FileAccess.get_file_as_string("user://save.cfg"), "存档格式不变")
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	var player: Node = current_scene._player
	_check(player.max_health == 3200 and player.stats.damage(10) == 320, "顶境实际战斗同步新倍率")
	if _failures == 0:
		print("V6.0 BALANCE PASS: all five major breakthroughs strictly increase HP and attack")
	quit(mini(_failures, 1))


func _copy_stats(save: Node) -> Stats:
	var stats := Stats.new()
	stats.configure(save.realm(), save.passive_levels(), save.equipped_items(), save.realm_layer())
	return stats


func _matches_panel(cave: Node, stats: Stats) -> bool:
	return cave._stat_values[0].text == str(stats.max_health()) and cave._stat_values[1].text == "×%.2f" % stats.attack_multiplier()


func _check_equipped(source: String, target: String) -> void:
	var rng := RandomNumberGenerator.new()
	var gear := {}
	for id: String in Equipment.SLOTS:
		gear[id] = Equipment.create_item(id, 2, 3, rng)
	var before := Stats.new()
	var after := Stats.new()
	var passives := {"body": 5, "spirit": 5}
	before.configure(source, passives, gear, Catalog.REALM_LAYER_CAP)
	after.configure(target, passives, gear, 1)
	_check(after.max_health() > before.max_health() and after.attack_multiplier() > before.attack_multiplier(),
		"固定同一套七部位与心法也严格上涨")


func _screen() -> Image:
	if _directory.is_empty():
		return null
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _write_comparison(index: int, from: String, to: String, left: Image, right: Image) -> void:
	var prefix := "%02d-%s至%s" % [index, from, to]
	_check(left.save_png(_directory.path_join(prefix + "-突破前.png")) == OK, prefix + "前图")
	_check(right.save_png(_directory.path_join(prefix + "-突破后.png")) == OK, prefix + "后图")
	left.convert(Image.FORMAT_RGBA8)
	right.convert(Image.FORMAT_RGBA8)
	var size := left.get_size()
	var pair := Image.create_empty(size.x * 2, size.y, false, Image.FORMAT_RGBA8)
	pair.blit_rect(left, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	pair.blit_rect(right, Rect2i(Vector2i.ZERO, size), Vector2i(size.x, 0))
	_check(pair.save_png(_directory.path_join(prefix + "-对比.png")) == OK, prefix + "并排图")


func _check(ok: bool, description: String) -> void:
	if not ok:
		_failures += 1
		printerr("FAIL: ", description)
