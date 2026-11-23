extends SceneTree
## Copy to a clean v4.1 snapshot to capture both builds with the same positions.

const BATTLE := "res://scenes/main.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var directory := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if not directory.contains("/wanmoyuan-v5-test-"):
		quit(1)
		return
	seed(540)
	change_scene_to_file(BATTLE)
	await scene_changed
	var battle := current_scene
	battle.set_physics_process(false)
	battle._skills.set_physics_process(false)
	var camera: Camera3D = battle._camera.presentation
	var view := root.get_visible_rect()
	var center := view.get_center()
	var plane := Plane(Vector3.UP, 0.0)
	var width := _ground(camera, plane, Vector2(view.end.x, center.y)).distance_to(
		_ground(camera, plane, Vector2(view.position.x, center.y)))
	var meshes: MeshInstance3D = battle._player.get_node("Body")
	var bounds: AABB = meshes.global_transform * meshes.get_aabb()
	var avatar := absf(camera.unproject_position(Vector3.UP * bounds.end.y).y
		- camera.unproject_position(Vector3.UP * bounds.position.y).y) / view.size.y
	var angle := -rad_to_deg(camera.global_rotation.x)
	var env: Environment = battle.get_node("BattleWorld/WorldEnvironment").environment
	var args := OS.get_cmdline_user_args()
	var title := args[0] if args.size() > 0 else "camera"
	var message := "%s · 同位置 / 同分辨率\n水平地面跨度 %.1f · 俯角 %.0f° · FOV %.0f°\n雾距 %.0f / %.0f · 主角高约 %.1f%%" % [
		title, width, angle, camera.fov, env.fog_depth_begin, env.fog_depth_end, avatar * 100.0]
	print("CAMERA ", width, " angle=", angle, " fov=", camera.fov, " fog=", env.fog_depth_begin, "/", env.fog_depth_end, " player=", avatar)
	for x in range(-2, 3):
		for z in range(-2, 3):
			if x == 0 and z == 0:
				continue
			var enemy: Node = battle._spawn_enemy_at(battle._wolf_pool, Vector3(x * 205.0, 0, z * 280.0))
			enemy.set_physics_process(false)
	if args.size() > 1 and DisplayServer.get_name() != "headless":
		if DirAccess.make_dir_recursive_absolute(args[1].get_base_dir()) != OK:
			quit(1)
			return
		var note := Label.new()
		note.position = Vector2(38, 700)
		note.text = message
		note.add_theme_font_size_override("font_size", 25)
		note.add_theme_constant_override("outline_size", 7)
		battle.get_node("TouchUI/SafeArea").add_child(note)
		await process_frame
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(args[1]) != OK:
			quit(1)
			return
		if args.size() > 2:
			var moved := Vector3(-3570.0, 0.0, 4630.0)
			battle._player.global_position = moved
			battle._camera.snap_to(moved)
			battle._ground.follow(moved)
			note.text = "移动后重新铺地 · 俯角 45°\n深度雾 %.0f → %.0f" % [env.fog_depth_begin, env.fog_depth_end]
			await process_frame
			await RenderingServer.frame_post_draw
			if root.get_texture().get_image().save_png(args[2]) != OK:
				quit(1)
				return
	quit()


func _ground(camera: Camera3D, plane: Plane, pixel: Vector2) -> Vector3:
	return plane.intersects_ray(camera.project_ray_origin(pixel), camera.project_ray_normal(pixel))
