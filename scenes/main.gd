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
const ArtifactCatalog = preload("res://scripts/artifact_catalog.gd")
const ArtifactInventory = preload("res://scripts/artifact_inventory.gd")
const BattleEffects = preload("res://scenes/effects/battle_effects.gd")
const BattleAudio = preload("res://scenes/effects/battle_audio.gd")
const WOLF_SCENE := preload("res://scenes/enemies/wolf_demon.tscn")
const CROW_SCENE := preload("res://scenes/enemies/crow_demon.tscn")
const GOLEM_SCENE := preload("res://scenes/enemies/stone_golem.tscn")
const BOSS_SCENE := preload("res://scenes/enemies/demon_lord.tscn")
const ORB_SCENE := preload("res://scenes/enemies/magic_orb.tscn")
const SWORD_SCENE := preload("res://scenes/skills/flying_sword.tscn")
const CRYSTAL_SCENE := preload("res://scenes/pickups/spirit_crystal.tscn")
const STONE_SCENE := preload("res://scenes/pickups/spirit_stone.tscn")
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
var _inventory := ArtifactInventory.new()
var _choices: Array[int] = []
var _pending_breakthrough := ""


func _ready() -> void:
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
	_effects.configure(_camera, $DeathBursts)
	_skills.configure(_player, _living_enemies, _launch_sword, _camera)
	_joystick.reserved_button = _hud.shop_button
	_joystick.reserved_button_tapped.connect(_open_shop)
	_hud.shop_button.pressed.connect(_open_shop)
	_shop_menu.close_requested.connect(_close_shop)
	_shop_menu.purchase_requested.connect(_purchase_artifact)
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
		_next_golem_at += GOLEM_INTERVAL * (1 + floori((_elapsed + TIME_EPSILON - _next_golem_at) / GOLEM_INTERVAL))

	if not _boss_spawned and _elapsed + TIME_EPSILON >= BOSS_START:
		_spawn_boss()

	var whole_second := floori(_elapsed + TIME_EPSILON)
	if whole_second != _shown_second:
		_shown_second = whole_second
		_hud.set_survival_time(whole_second)


func _spawn_interval(elapsed: float) -> float:
	var ramps := floori((elapsed + TIME_EPSILON) / RAMP_STEP)
	# 频率按阶段乘 1.2，对应的刷新间隔按阶段缩短。
	return maxf(MIN_SPAWN_INTERVAL, BASE_SPAWN_INTERVAL / pow(RAMP_MULTIPLIER, ramps))


func _connect_enemy(enemy: Enemy, recycle: Callable) -> void:
	enemy.died.connect(_on_enemy_died)
	enemy.death_finished.connect(recycle)
	enemy.damaged.connect(_effects.show_damage)
	enemy.death_burst.connect(_effects.show_burst)


func _connect_crow(crow: CrowDemon) -> void:
	_connect_enemy(crow, _recycle_crow)
	crow.orb_cast.connect(_launch_orb)


func _connect_boss(boss: DemonLord) -> void:
	_connect_enemy(boss, _recycle_boss)
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
	_hud.show_boss(boss.max_health)


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
	_player.heal(_player.stats.kill_heal(_player.health, _player.max_health))
	_drop_spirit_stone(enemy)
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
	stone.drop(enemy.global_position + offset, _player, _player.stats.stone_amount(enemy.stone_drop_amount))


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
	if _xp >= _xp_required and not _upgrade_menu.visible and not _shop_menu.visible:
		_show_level_up()


func _on_stone_collected(stone: MagnetPickup) -> void:
	var amount := stone.amount
	_stone_pool.release(stone)
	# 胜利慢动作中仍按实际拾取入账，结算不等待也不补发。
	if _phase == Phase.RESULT or not _player.is_alive():
		return
	_spirit_stones += amount
	_hud.set_spirit_stones(_spirit_stones)


func _open_shop() -> void:
	if _phase != Phase.BATTLE or get_tree().paused:
		return
	_joystick.reset()
	get_tree().paused = true
	_shop_menu.open(_inventory, _spirit_stones)


func _close_shop() -> void:
	if _phase != Phase.BATTLE or not _shop_menu.visible:
		return
	_shop_menu.hide()
	if _xp >= _xp_required:
		_show_level_up()
	else:
		get_tree().paused = false


func _purchase_artifact(id: StringName) -> void:
	if _phase != Phase.BATTLE or not _shop_menu.visible:
		return
	var transaction := _inventory.purchase(id, _spirit_stones)
	if not transaction.reason.is_empty():
		_shop_menu.show_status(transaction.reason)
		return
	_spirit_stones -= transaction.cost
	_player.stats.rebuild(_inventory.slots)
	_player.refresh_equipment(ArtifactCatalog.ITEMS[id].get("heal_on_buy", 0))
	_hud.set_spirit_stones(_spirit_stones)
	_shop_menu.refresh(_inventory, _spirit_stones)
	_shop_menu.show_success(id, transaction.slot, transaction.cost, _inventory.count(&"") == 0)
	_audio.play_cue(BattleAudio.Cue.PURCHASE)


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
	var previous_realm := _realm_name()
	_level += 1
	_xp -= _xp_required
	_xp_required = floori(_xp_required * 1.3)
	if _realm_name() != previous_realm:
		_pending_breakthrough = _realm_name()
	_refresh_hud()

	# 同一帧拾到的多余经验可继续升级，不丢失也不跳过选牌。
	if _xp >= _xp_required:
		_show_level_up()
	else:
		_upgrade_menu.hide()
		_choices.clear()
		get_tree().paused = false
		if not _pending_breakthrough.is_empty():
			_hud.show_breakthrough(_pending_breakthrough)
			_pending_breakthrough = ""


func _on_player_died() -> void:
	if _phase == Phase.BATTLE:
		_show_result(false)


func _begin_victory() -> void:
	# 魔尊一死就锁定胜利与统计，慢动作期间不能再受伤或触发升级。
	_phase = Phase.VICTORY_SLOW
	_player.accepts_damage = false
	_upgrade_menu.hide()
	_shop_menu.hide()
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
	_phase = Phase.RESULT
	_joystick.reset()
	_upgrade_menu.hide()
	_shop_menu.hide()
	_hud.hide()
	get_tree().paused = true
	_result_menu.open(won, floori(_elapsed + TIME_EPSILON), _kills, _realm_name())


func _restart_battle() -> void:
	if _phase != Phase.RESULT:
		return
	var tree := get_tree()
	if tree.reload_current_scene() == OK:
		tree.paused = false


func _refresh_hud() -> void:
	_hud.set_progress(_level, _realm_name(), _xp, _xp_required)


func _realm_name() -> String:
	if _level >= 15:
		return "元婴"
	if _level >= 10:
		return "金丹"
	if _level >= 5:
		return "筑基"
	return "炼气"
