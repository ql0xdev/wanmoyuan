extends SceneTree
## 可复制到 v4.0 干净快照。对两版本的真实掉落函数做固定种子指纹对照。

const Catalog = preload("res://scripts/cultivation_catalog.gd")
const BATTLE := "res://scenes/main.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var data := OS.get_user_data_dir().replace("\\", "/").to_lower()
	var save := root.get_node("SaveManager")
	if not data.contains("/wanmoyuan-v41-test-") or save.has_profile() or save.load_error() != OK:
		quit(1)
		return
	var layered := save.has_method("advance_realm_layer")
	if save.settle_run(230420 if layered else 140500, false) != OK:
		quit(1)
		return
	for i in range(5):
		if layered:
			for level in range(8):
				if save.advance_realm_layer() != OK:
					quit(1)
					return
		if save.breakthrough() != OK:
			quit(1)
			return
	var fingerprint := HashingContext.new()
	fingerprint.start(HashingContext.HASH_SHA256)
	var calls := 0
	var outputs := 0
	for id: String in Catalog.ABYSSES:
		var battle := (load(BATTLE) as PackedScene).instantiate()
		var args := [id]
		for method: Dictionary in battle.get_method_list():
			if method.name == "configure_run" and method.args.size() == 2:
				args.append(["sword", "lightning", "orbs", "ice"])
				break
		if not battle.callv("configure_run", args) or change_scene_to_node(battle) != OK:
			quit(1)
			return
		await scene_changed
		battle.set_physics_process(false)
		battle._skills.set_physics_process(false)
		battle._loot_rng.seed = 41001
		var container := battle.get_node("Pickups/EquipmentDrops")
		for pool in [battle._wolf_pool, battle._crow_pool, battle._golem_pool, battle._boss_pool]:
			var enemy: Node = battle._spawn_enemy(pool)
			enemy.set_physics_process(false)
			var rules := [id, enemy.equipment_count, enemy.equipment_chance, enemy.purple_chance]
			fingerprint.update(JSON.stringify(rules).to_utf8_buffer())
			for i in range(200):
				battle._roll_equipment(enemy)
				calls += 1
				var rolled := []
				for item: Node in container.get_children():
					if not item.visible:
						continue
					# 新字段 star=0 不计入掉落判定指纹；其余逐项对照。
					var base: Dictionary = item._item.duplicate(true)
					base.erase("star")
					rolled.append([base, item.display_name, item.quality_color.to_html(), item._glow.visible])
					battle._effects.untrack_equipment(item)
					battle._equipment_pool.release(item)
					outputs += 1
				fingerprint.update(JSON.stringify(rolled).to_utf8_buffer())
	print("EQUIPMENT DROPS: %d rolls, %d drops, sha256 %s" % [calls, outputs, fingerprint.finish().hex_encode()])
	quit()
