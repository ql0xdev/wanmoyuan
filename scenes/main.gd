extends Node3D

const ObjectPool = preload("res://scripts/object_pool.gd")
const BattlePlane = preload("res://scripts/battle_plane.gd")
const BattleCamera = preload("res://scenes/world/battle_camera.gd")
const BattleGround = preload("res://scenes/world/battle_ground.gd")
const Player = preload("res://scenes/player.gd")
const Enemy = preload("res://scenes/enemies/enemy.gd")
const CrowDemon = preload("res://scenes/enemies/crow_demon.gd")
const DemonLord = preload("res://scenes/enemies/demon_lord.gd")
const MagicOrb = preload("res://scenes/enemies/magic_orb.gd")
const FlyingSword = preload("res://scenes/skills/flying_sword.gd")
const MagnetPickup = preload("res://scenes/pickups/magnet_pickup.gd")
const SkillController = preload("res://scenes/skills/skill_controller.gd")
const BattleHUD = preload("res://scenes/ui/battle_hud.gd")
const UpgradeMenu = preload("res://scenes/ui/upgrade_menu.gd")
const ResultMenu = preload("res://scenes/ui/result_menu.gd")
const JoystickControl = preload("res://scenes/ui/virtual_joystick.gd")
const ShopMenu = preload("res://scenes/ui/shop_menu.gd")
const GearMenu = preload("res://scenes/ui/equipment_menu.gd")
const GameMenu = preload("res://scenes/ui/game_menu.gd")
const Cultivation = preload("res://scripts/cultivation_catalog.gd")
const Equipment = preload("res://scripts/equipment_catalog.gd")
const RunInventory = preload("res://scripts/run_inventory.gd")
const Pills = preload("res://scripts/pill_catalog.gd")
const BattleEffects = preload("res://scenes/effects/battle_effects.gd")
const BattleAudio = preload("res://scenes/effects/battle_audio.gd")
const Look = preload("res://scenes/ui/ui_look.gd")
const WOLF_SCENE := preload("res://scenes/enemies/wolf_demon.tscn")
const CROW_SCENE := preload("res://scenes/enemies/crow_demon.tscn")
const GOLEM_SCENE := preload("res://scenes/enemies/stone_golem.tscn")
const BOSS_SCENE := preload("res://scenes/enemies/demon_lord.tscn")
const ORB_SCENE := preload("res://scenes/enemies/magic_orb.tscn")
const SWORD_SCENE := preload("res://scenes/skills/flying_sword.tscn")
const CRYSTAL_SCENE := preload("res://scenes/pickups/spirit_crystal.tscn")
const STONE_SCENE := preload("res://scenes/pickups/spirit_stone.tscn")
const CAVE_SCENE := "res://scenes/ui/cave_menu.tscn"
const STONE_DROP_OFFSET := Vector3(24.0, 0.0, -24.0)
const MAX_ENEMIES := 100
const BASE_SPAWN_INTERVAL := 1.5
const MIN_SPAWN_INTERVAL := 0.4
const RAMP_STEP := 30.0
const RAMP_MULTIPLIER := 1.20
const CROW_START := 40.0
const GOLEM_START := 90.0
const GOLEM_INTERVAL := 30.0
const BOSS_START := 180.0
const BOSS_SUMMON_COUNT := 4
const BOSS_SUMMON_RADIUS := 66.0
const VICTORY_SLOW_DURATION := 0.5
const VICTORY_TIME_SCALE := 0.45
const TIME_EPSILON := 0.000001
const SPAWN_MARGIN := 48.0

enum Phase { BATTLE, VICTORY_SLOW, RESULT }

@onready var _player: Player = $Player
@onready var _camera: BattleCamera = $Camera
@onready var _ground: BattleGround = $BattleWorld
@onready var _skills: SkillController = $SkillController
@onready var _hud: BattleHUD = $TouchUI/SafeArea/BattleHUD
@onready var _upgrade_menu: UpgradeMenu = $TouchUI/SafeArea/UpgradeMenu
@onready var _joystick: JoystickControl = $TouchUI/SafeArea/VirtualJoystick
@onready var _result_menu: ResultMenu = $TouchUI/SafeArea/ResultMenu
@onready var _shop_menu: ShopMenu = $TouchUI/SafeArea/ShopMenu
@onready var _gear_overlay: PanelContainer = $TouchUI/SafeArea/GearOverlay
@onready var _gear_menu: GearMenu = $TouchUI/SafeArea/GearOverlay/Content/EquipmentMenu
@onready var _game_menu: GameMenu = $TouchUI/SafeArea/GameMenu
@onready var _effects: BattleEffects = $EffectsLayer/BattleEffects
@onready var _audio: BattleAudio = $BattleAudio

var _wolf_pool: ObjectPool
var _crow_pool: ObjectPool
var _golem_pool: ObjectPool
var _boss_pool: ObjectPool
var _orb_pool: ObjectPool
var _sword_pool: ObjectPool
var _crystal_pool: ObjectPool
var _stone_pool: ObjectPool
var _living_enemies: Array[Enemy] = []
var _active_enemy_count := 0
var _elapsed := 0.0
var _spawn_progress := 0.0
var _spawn_mix_index := 0
var _next_golem_at := GOLEM_START
var _boss_spawned := false
var _phase := Phase.BATTLE
var _previous_time_scale := 1.0
var _kills := 0
var _shown_second := 0
var _level := 1
var _xp := 0
var _xp_required := 5
var _spirit_stones := 0
var _inventory := RunInventory.new()
var _choices: Array[int] = []
var _run_won := false
var _settlement_saved := false
var _settlement_error: Error = OK
var _abyss_id := Cultivation.DEFAULT_ABYSS
var _abyss: Dictionary
var _loadout: Array = Cultivation.DEFAULT_LOADOUT.duplicate()
var _enemy_visuals := {}
var _enemy_shapes := {}
var _loot_rng := RandomNumberGenerator.new()


func configure_run(abyss: String, loadout: Array) -> bool:
	if is_inside_tree() or not SaveManager.is_unlocked(abyss) or not SaveManager.valid_loadout(loadout):
		return false
	_abyss_id = abyss
	_loadout = loadout.duplicate()
	return true


func _ready() -> void:
	Look.skin_buttons($TouchUI/SafeArea)
	Look.animate_panel(_gear_overlay, _gear_overlay)
	_abyss = Cultivation.ABYSSES[_abyss_id]
	_inventory.setup(SaveManager.equipped_items())
	_player.stats.configure(SaveManager.realm(), SaveManager.passive_levels(), _inventory.worn)
	_player.refresh_equipment(true)
	_loot_rng.randomize()
	_wolf_pool = ObjectPool.new(WOLF_SCENE, $Enemies, 64, _connect_enemy.bind(_recycle_wolf))
	_crow_pool = ObjectPool.new(CROW_SCENE, $Enemies, 24, _connect_crow)
	_golem_pool = ObjectPool.new(GOLEM_SCENE, $Enemies, 8, _connect_enemy.bind(_recycle_golem))
	_boss_pool = ObjectPool.new(BOSS_SCENE, $Enemies, 1, _connect_boss)
	_orb_pool = ObjectPool.new(ORB_SCENE, $Projectiles, 100, _connect_orb)
	_sword_pool = ObjectPool.new(SWORD_SCENE, $Projectiles, 100, _connect_sword)
	_crystal_pool = ObjectPool.new(CRYSTAL_SCENE, $Pickups, 200, _connect_crystal)
	_stone_pool = ObjectPool.new(STONE_SCENE, $Pickups, 32, _connect_stone)
	_camera.snap_to(_player.global_position)
	_ground.follow(_camera.focus)
	_ground.set_abyss_tint(_abyss.color)
	_effects.configure(_camera.presentation, $DeathBursts, $LootBeams)
	_skills.configure(_player, _living_enemies, _launch_sword, _camera, _loadout)
	_joystick.reserved_buttons.assign([_hud.shop_button, _hud.bag_button, _hud.menu_button])
	_joystick.reserved_button_tapped.connect(_on_battle_button_tapped)
	_hud.shop_button.pressed.connect(_open_shop)
	_hud.bag_button.pressed.connect(_open_bag)
	_hud.menu_button.pressed.connect(_open_game_menu)
	_game_menu.closed.connect(_resume_battle)
	_shop_menu.close_requested.connect(_close_shop)
	_shop_menu.purchase_requested.connect(_purchase_pill)
	_gear_overlay.get_node("Content/Close").pressed.connect(_close_gear)
	_gear_menu.wear_requested.connect(_change_run_equipment)
	_gear_menu.salvage_requested.connect(_salvage_loot)
	_skills.swords_cast.connect(_audio.play_cue.bind(BattleAudio.Cue.SWORD))
	_skills.lightning_cast.connect(_audio.play_cue.bind(BattleAudio.Cue.LIGHTNING))
	_player.hit.connect(_audio.play_cue.bind(BattleAudio.Cue.HIT))
	_hud.set_health(_player.health, _player.max_health)
	_hud.set_spirit_stones(_spirit_stones)
	_refresh_hud()


func _process(delta: float) -> void:
	_camera.follow(_player.global_position, delta)
	_ground.follow(_camera.focus)


func _physics_process(delta: float) -> void:
	if _phase != Phase.BATTLE:
		return
	# 只累计实际战斗时间，通过刷新进度在提速时保留本轮已经等待的时间。
	_spawn_progress += delta / _spawn_interval(_elapsed)
	_elapsed += delta
	while _spawn_progress + TIME_EPSILON >= 1.0 and _can_spawn_regular():
		_spawn_progress -= 1.0
		if _elapsed + TIME_EPSILON >= CROW_START:
			_spawn_enemy(_crow_pool if _spawn_mix_index == 0 else _wolf_pool)
			_spawn_mix_index = (_spawn_mix_index + 1) % 3
		else:
			_spawn_enemy(_wolf_pool)

	# 满员只保留一次待刷，避免腾出位置后连续补刷。
	_spawn_progress = minf(_spawn_progress, 1.0)
	if _elapsed + TIME_EPSILON >= _next_golem_at and _active_enemy_count < _enemy_limit(_golem_pool):
		_spawn_enemy(_golem_pool)
		var interval: float = GOLEM_INTERVAL / _abyss.density
		_next_golem_at += interval * (1 + floori((_elapsed + TIME_EPSILON - _next_golem_at) / interval))

	if not _boss_spawned and _elapsed + TIME_EPSILON >= BOSS_START:
		_spawn_boss()

	var whole_second := floori(_elapsed + TIME_EPSILON)
	if whole_second != _shown_second:
		_shown_second = whole_second
		_hud.set_survival_time(whole_second)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo() and _phase == Phase.BATTLE:
		get_viewport().set_input_as_handled()
		_open_game_menu()


func _spawn_interval(elapsed: float) -> float:
	var ramps := floori((elapsed + TIME_EPSILON) / RAMP_STEP)
	# 频率按阶段乘 1.2，对应的刷新间隔按阶段缩短。
	return maxf(MIN_SPAWN_INTERVAL, BASE_SPAWN_INTERVAL / pow(RAMP_MULTIPLIER, ramps)) / _abyss.density


func _connect_enemy(enemy: Enemy, recycle: Callable) -> void:
	var health_scale: float = _abyss.boss_health if enemy is DemonLord else _abyss.health
	enemy.apply_difficulty(health_scale, _abyss.damage, _abyss.scale, _abyss.color, _enemy_visuals, _enemy_shapes)
	enemy.died.connect(_on_enemy_died)
	enemy.death_finished.connect(recycle)
	enemy.damaged.connect(_effects.show_damage)
	enemy.death_burst.connect(_effects.show_burst)


func _connect_crow(crow: CrowDemon) -> void:
	_connect_enemy(crow, _recycle_crow)
	crow.orb_cast.connect(_launch_orb)


func _connect_boss(boss: DemonLord) -> void:
	_connect_enemy(boss, _recycle_boss)
	boss.period_multiplier = _abyss.boss_period
	boss.flame_damage = roundi(DemonLord.FLAME_DAMAGE * _abyss.damage)
	boss.health_changed.connect(_hud.set_boss_health)
	boss.flame_cast.connect(_launch_orb.bind(true))
	boss.wolves_summoned.connect(_summon_wolves)


func _connect_orb(orb: MagicOrb) -> void:
	orb.finished.connect(_recycle_orb)


func _connect_sword(sword: FlyingSword) -> void:
	sword.finished.connect(_recycle_sword)


func _connect_crystal(crystal: MagnetPickup) -> void:
	crystal.collected.connect(_on_crystal_collected)


func _connect_stone(stone: MagnetPickup) -> void:
	stone.collected.connect(_on_stone_collected)


func _spawn_enemy(pool: ObjectPool) -> Enemy:
	if _active_enemy_count >= _enemy_limit(pool):
		return null
	var enemy := pool.acquire() as Enemy
	return _activate_enemy(enemy, _outside_screen_position(enemy.visual_bounds()))


func _enemy_limit(pool: ObjectPool) -> int:
	# 开场提前给第 180 秒出现的魔尊预留一格，不抢占或回收活怪。
	return MAX_ENEMIES if _boss_spawned or pool == _boss_pool else MAX_ENEMIES - 1


func _can_spawn_regular() -> bool:
	var limit := _enemy_limit(_wolf_pool)
	if _elapsed + TIME_EPSILON >= _next_golem_at:
		limit -= 1
	return _active_enemy_count < limit


func _spawn_enemy_at(pool: ObjectPool, position_in_world: Vector3) -> Enemy:
	if _active_enemy_count >= _enemy_limit(pool):
		return null
	return _activate_enemy(pool.acquire() as Enemy, position_in_world)


func _activate_enemy(enemy: Enemy, position_in_world: Vector3) -> Enemy:
	enemy.spawn(position_in_world, _player)
	_living_enemies.append(enemy)
	_active_enemy_count += 1
	return enemy


func _spawn_boss() -> void:
	var boss := _spawn_enemy(_boss_pool)
	if boss == null:
		return
	_boss_spawned = true
	_hud.show_boss(_abyss.boss, boss.max_health)
	_camera.shake_view()


func _summon_wolves(origin: Vector3) -> void:
	if _phase != Phase.BATTLE:
		return
	var available := mini(BOSS_SUMMON_COUNT, _enemy_limit(_wolf_pool) - _active_enemy_count)
	for i in range(available):
		var offset := BattlePlane.direction(TAU * i / BOSS_SUMMON_COUNT) * BOSS_SUMMON_RADIUS
		_spawn_enemy_at(_wolf_pool, origin + offset)


func _outside_screen_position(model_bounds := AABB()) -> Vector3:
	# 按实际画面边缘刷怪，摄像机滞后或窗口比例变化时也不在屏内生成。
	var view := get_viewport().get_visible_rect()
	var point: Vector2
	var outward: Vector2
	match randi_range(0, 3):
		0:
			point = Vector2(view.position.x - SPAWN_MARGIN, randf_range(view.position.y, view.end.y))
			outward = Vector2.LEFT
		1:
			point = Vector2(view.end.x + SPAWN_MARGIN, randf_range(view.position.y, view.end.y))
			outward = Vector2.RIGHT
		2:
			point = Vector2(randf_range(view.position.x, view.end.x), view.position.y - SPAWN_MARGIN)
			outward = Vector2.UP
		3:
			point = Vector2(randf_range(view.position.x, view.end.x), view.end.y + SPAWN_MARGIN)
			outward = Vector2.DOWN
	var at := _camera.ground_at(point)
	# 透视下脚在屏外但高模型的上半身可能还在屏内，沿同一侧向外微调。
	var edge := point.dot(outward) - SPAWN_MARGIN
	for i in range(4):
		var model_is_outside := true
		for corner in range(8):
			var world_corner := at + model_bounds.get_endpoint(corner)
			if not _camera.is_position_behind(world_corner) and _camera.unproject_position(world_corner).dot(outward) < edge:
				model_is_outside = false
				break
		if model_is_outside:
			break
		at = _camera.ground_at(point + outward * (i + 1) * SPAWN_MARGIN)
	return at


func _launch_sword(origin: Vector3, direction: Vector3, damage: int) -> void:
	var sword := _sword_pool.acquire() as FlyingSword
	sword.launch(origin, direction, damage)


func _launch_orb(origin: Vector3, direction: Vector3, damage: int, boss_flame := false) -> void:
	var orb := _orb_pool.acquire() as MagicOrb
	orb.launch(origin, direction, damage, _player, boss_flame)


func _on_enemy_died(enemy: Enemy) -> void:
	_living_enemies.erase(enemy)
	if _phase != Phase.BATTLE:
		return
	_kills += 1
	_player.heal(_player.stats.kill_heal())
	_drop_spirit_stone(enemy)
	_roll_equipment(enemy)
	if enemy is DemonLord:
		_begin_victory()
		return
	for i in range(enemy.crystal_count):
		# 多颗灵晶稍微错开；沿用靠近后才磁吸的规则。
		var offset := Vector3.ZERO
		if i > 0:
			offset = BattlePlane.direction(TAU * (i - 1) / (enemy.crystal_count - 1)) * 21.0
		var crystal := _crystal_pool.acquire() as MagnetPickup
		crystal.drop(enemy.global_position + offset, _player)


func _drop_spirit_stone(enemy: Enemy) -> void:
	if enemy.stone_drop_amount <= 0:
		return
	if enemy.stone_drop_chance < 1.0 and randf() >= enemy.stone_drop_chance:
		return
	# 普通怪的两种掉落错开放置，魔尊的灵石则落在死亡位置。
	var offset := STONE_DROP_OFFSET if enemy.crystal_count > 0 else Vector3.ZERO
	var stone := _stone_pool.acquire() as MagnetPickup
	stone.drop(enemy.global_position + offset, _player, _player.stats.stone_amount(enemy.stone_drop_amount * int(_abyss.stones)))


func _roll_equipment(enemy: Enemy) -> void:
	if enemy.equipment_chance < 1.0 and _loot_rng.randf() >= enemy.equipment_chance:
		return
	for i in range(enemy.equipment_count):
		var item := Equipment.roll(_abyss.tier, enemy.purple_chance, _loot_rng)
		var quality_color: Color = Equipment.COLORS[item.quality]
		var visual_offset := (i - (enemy.equipment_count - 1) * 0.5) * 22.0
		_effects.show_loot_beam(enemy.global_position + Vector3.RIGHT * visual_offset, quality_color)
		var stone_value := _inventory.collect(item)
		if stone_value > 0:
			_spirit_stones += stone_value
			_hud.set_spirit_stones(_spirit_stones)
			_hud.show_loot("行囊已满 · 自动分解 +%d 灵石" % stone_value, Color("#ffda91"))
		else:
			_hud.show_loot("获得 %s" % Equipment.title(item), quality_color)


func _recycle_wolf(enemy: Enemy) -> void:
	_wolf_pool.release(enemy)
	_active_enemy_count -= 1


func _recycle_crow(enemy: Enemy) -> void:
	_crow_pool.release(enemy)
	_active_enemy_count -= 1


func _recycle_golem(enemy: Enemy) -> void:
	_golem_pool.release(enemy)
	_active_enemy_count -= 1


func _recycle_boss(enemy: Enemy) -> void:
	_boss_pool.release(enemy)
	_active_enemy_count -= 1


func _recycle_orb(orb: MagicOrb) -> void:
	_orb_pool.release(orb)


func _recycle_sword(sword: FlyingSword) -> void:
	_sword_pool.release(sword)


func _on_crystal_collected(crystal: MagnetPickup) -> void:
	_crystal_pool.release(crystal)
	if _phase != Phase.BATTLE or not _player.is_alive():
		return
	_xp += 1
	_refresh_hud()
	if _xp >= _xp_required and not _upgrade_menu.visible and not _shop_menu.visible and not _gear_overlay.visible and not _game_menu.visible:
		_show_level_up()


func _on_stone_collected(stone: MagnetPickup) -> void:
	var amount := stone.amount
	_stone_pool.release(stone)
	# 胜利慢动作中仍按实际拾取入账，结算不等待也不补发。
	if _phase == Phase.RESULT or not _player.is_alive():
		return
	_spirit_stones += amount
	_hud.set_spirit_stones(_spirit_stones)


func _on_battle_button_tapped(button: Control) -> void:
	if button == _hud.shop_button:
		_open_shop()
	elif button == _hud.bag_button:
		_open_bag()
	elif button == _hud.menu_button:
		_open_game_menu()


func _open_game_menu() -> void:
	if _phase != Phase.BATTLE or get_tree().paused:
		return
	_joystick.reset()
	get_tree().paused = true
	_game_menu.open(true)


func _open_shop() -> void:
	if _phase != Phase.BATTLE or get_tree().paused:
		return
	_joystick.reset()
	get_tree().paused = true
	_shop_menu.open(_spirit_stones, _player.health, _player.max_health, _player.stats)


func _close_shop() -> void:
	if _phase != Phase.BATTLE or not _shop_menu.visible:
		return
	_shop_menu.hide()
	_resume_battle()


func _resume_battle() -> void:
	if _xp >= _xp_required:
		_show_level_up()
	else:
		get_tree().paused = false


func _purchase_pill(id: String) -> void:
	if _phase != Phase.BATTLE or not _shop_menu.visible or not Pills.ITEMS.has(id):
		return
	var reason := Pills.unavailable_reason(id, _spirit_stones, _player.health, _player.max_health, _player.stats.has_pill(id))
	if not reason.is_empty():
		_shop_menu.show_status(reason)
		return
	var pill: Dictionary = Pills.ITEMS[id]
	_spirit_stones -= pill.cost
	if id == "heal":
		_player.heal(roundi(_player.max_health * 0.5))
	else:
		_player.stats.use_pill(id)
	_hud.set_spirit_stones(_spirit_stones)
	_shop_menu.refresh(_spirit_stones, _player.health, _player.max_health, _player.stats)
	_shop_menu.show_status("已服用 %s · 消耗 %d 灵石" % [pill.name, pill.cost])
	_audio.play_cue(BattleAudio.Cue.PURCHASE)


func _open_bag() -> void:
	if _phase != Phase.BATTLE or get_tree().paused:
		return
	_joystick.reset()
	get_tree().paused = true
	_gear_menu.display(GearMenu.Mode.BAG, _inventory.bag, _inventory.worn)
	_gear_overlay.show()


func _close_gear() -> void:
	if not _gear_overlay.visible:
		return
	_gear_overlay.hide()
	if _phase == Phase.BATTLE:
		_resume_battle()
	elif _phase == Phase.RESULT and _settlement_error == ERR_OUT_OF_MEMORY:
		_result_menu.show()
		_save_run_result()


func _change_run_equipment(id: int, equip: bool) -> void:
	if _phase != Phase.BATTLE or not _gear_overlay.visible:
		return
	var changed := _inventory.equip(id) if equip else _inventory.unequip(id)
	if changed:
		_player.stats.rebuild_equipment(_inventory.worn)
		_player.refresh_equipment()
		_gear_menu.display(GearMenu.Mode.BAG, _inventory.bag, _inventory.worn)


func _organize_loot() -> void:
	if _phase != Phase.RESULT or _settlement_error != ERR_OUT_OF_MEMORY:
		return
	_gear_menu.display(GearMenu.Mode.SETTLEMENT, _inventory.new_loot(), {}, SaveManager.equipment_count())
	_result_menu.hide()
	_gear_overlay.show()


func _salvage_loot(id: int) -> void:
	if _phase != Phase.RESULT or not _gear_overlay.visible or _settlement_error != ERR_OUT_OF_MEMORY:
		return
	var amount := _inventory.salvage(id)
	if amount > 0:
		_spirit_stones += amount
		_gear_menu.display(GearMenu.Mode.SETTLEMENT, _inventory.new_loot(), {}, SaveManager.equipment_count())
		_gear_menu.show_status("已分解 +%d 灵石；关闭后结算。" % amount)


func _show_level_up() -> void:
	_choices = _skills.roll_choices()
	var cards := PackedStringArray()
	for skill in _choices:
		cards.append(_skills.card_text(skill))
	# 暂停前清除旧触点，防止松手发生在暂停期间、恢复后角色仍在移动。
	_joystick.reset()
	get_tree().paused = true
	_upgrade_menu.open(cards)
	_audio.play_cue(BattleAudio.Cue.LEVEL_UP)


func _on_upgrade_chosen(index: int) -> void:
	if _phase != Phase.BATTLE or not _upgrade_menu.visible or index < 0 or index >= _choices.size():
		return
	_skills.apply_upgrade(_choices[index])
	_level += 1
	_xp -= _xp_required
	_xp_required = floori(_xp_required * 1.3)
	_refresh_hud()

	# 同一帧拾到的多余经验可继续升级，不丢失也不跳过选牌。
	if _xp >= _xp_required:
		_show_level_up()
	else:
		_upgrade_menu.hide()
		_choices.clear()
		get_tree().paused = false


func _on_player_died() -> void:
	if _phase == Phase.BATTLE:
		_show_result(false)


func _begin_victory() -> void:
	# 魔尊一死就锁定胜利与统计，慢动作期间不能再受伤或触发升级。
	_phase = Phase.VICTORY_SLOW
	_player.accepts_damage = false
	_upgrade_menu.hide()
	_shop_menu.hide()
	_gear_overlay.hide()
	get_tree().paused = false
	_previous_time_scale = Engine.time_scale
	Engine.time_scale = VICTORY_TIME_SCALE
	get_tree().create_timer(VICTORY_SLOW_DURATION, false, false, true).timeout.connect(_finish_victory)


func _finish_victory() -> void:
	Engine.time_scale = _previous_time_scale
	_show_result(true)


func _exit_tree() -> void:
	if _phase == Phase.VICTORY_SLOW:
		Engine.time_scale = _previous_time_scale


func _show_result(won: bool) -> void:
	if _phase == Phase.RESULT:
		return
	_phase = Phase.RESULT
	_run_won = won
	_joystick.reset()
	_upgrade_menu.hide()
	_shop_menu.hide()
	_gear_overlay.hide()
	_hud.hide()
	get_tree().paused = true
	_result_menu.open(won, floori(_elapsed + TIME_EPSILON), _kills, _level)
	_save_run_result()


func _save_run_result() -> void:
	if _phase != Phase.RESULT or _settlement_saved:
		return
	var loot := _inventory.new_loot()
	_settlement_error = SaveManager.settle_run(_spirit_stones, _run_won, _abyss_id, loot)
	_settlement_saved = _settlement_error == OK
	_result_menu.show_settlement(_settlement_error, _spirit_stones, SaveManager.spirit_stones(), loot.size())


func _restart_battle() -> void:
	if _phase != Phase.RESULT or not _settlement_saved:
		return
	var tree := get_tree()
	var scene := load(scene_file_path) as PackedScene
	var next_battle := scene.instantiate()
	if next_battle.configure_run(_abyss_id, _loadout) and tree.change_scene_to_node(next_battle) == OK:
		tree.paused = false
	else:
		next_battle.free()


func _return_to_cave() -> void:
	if _phase != Phase.RESULT or not _settlement_saved:
		return
	var tree := get_tree()
	if tree.change_scene_to_file(CAVE_SCENE) == OK:
		tree.paused = false


func _refresh_hud() -> void:
	_hud.set_progress(_level, _abyss.name, SaveManager.realm_name(), _xp, _xp_required)
