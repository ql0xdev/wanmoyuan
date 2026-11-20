extends Node2D

const ObjectPool = preload("res://scripts/object_pool.gd")
const Player = preload("res://scenes/player.gd")
const Enemy = preload("res://scenes/enemies/enemy.gd")
const CrowDemon = preload("res://scenes/enemies/crow_demon.gd")
const DemonLord = preload("res://scenes/enemies/demon_lord.gd")
const MagicOrb = preload("res://scenes/enemies/magic_orb.gd")
const FlyingSword = preload("res://scenes/skills/flying_sword.gd")
const SpiritCrystal = preload("res://scenes/pickups/spirit_crystal.gd")
const SkillController = preload("res://scenes/skills/skill_controller.gd")
const BattleHUD = preload("res://scenes/ui/battle_hud.gd")
const UpgradeMenu = preload("res://scenes/ui/upgrade_menu.gd")
const ResultMenu = preload("res://scenes/ui/result_menu.gd")
const JoystickControl = preload("res://scenes/ui/virtual_joystick.gd")
const WOLF_SCENE := preload("res://scenes/enemies/wolf_demon.tscn")
const CROW_SCENE := preload("res://scenes/enemies/crow_demon.tscn")
const GOLEM_SCENE := preload("res://scenes/enemies/stone_golem.tscn")
const BOSS_SCENE := preload("res://scenes/enemies/demon_lord.tscn")
const ORB_SCENE := preload("res://scenes/enemies/magic_orb.tscn")
const SWORD_SCENE := preload("res://scenes/skills/flying_sword.tscn")
const CRYSTAL_SCENE := preload("res://scenes/pickups/spirit_crystal.tscn")
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
const BOSS_FLAME_TINT := Color("#ff7d4d")
const SHAKE_DURATION := 0.48
const VICTORY_SLOW_DURATION := 0.5
const VICTORY_TIME_SCALE := 0.45
const TIME_EPSILON := 0.000001
const SPAWN_MARGIN := 48.0
const GRID_SIZE := 96
const GROUND_COLOR := Color("#192322")
const GRID_COLOR := Color("#2a3b37")

enum Phase { BATTLE, VICTORY_SLOW, RESULT }

@onready var _player: Player = $Player
@onready var _camera: Camera2D = $Player/Camera2D
@onready var _skills: SkillController = $SkillController
@onready var _hud: BattleHUD = $TouchUI/SafeArea/BattleHUD
@onready var _upgrade_menu: UpgradeMenu = $TouchUI/SafeArea/UpgradeMenu
@onready var _joystick: JoystickControl = $TouchUI/SafeArea/VirtualJoystick
@onready var _result_menu: ResultMenu = $TouchUI/SafeArea/ResultMenu

var _grid_bounds: Rect2i
var _wolf_pool: ObjectPool
var _crow_pool: ObjectPool
var _golem_pool: ObjectPool
var _boss_pool: ObjectPool
var _orb_pool: ObjectPool
var _sword_pool: ObjectPool
var _crystal_pool: ObjectPool
var _living_enemies: Array[Enemy] = []
var _elapsed := 0.0
var _spawn_progress := 0.0
var _spawn_mix_index := 0
var _next_golem_at := GOLEM_START
var _boss_spawned := false
var _shake_left := 0.0
var _phase := Phase.BATTLE
var _previous_time_scale := 1.0
var _kills := 0
var _shown_second := 0
var _level := 1
var _xp := 0
var _xp_required := 5
var _choices: Array[int] = []
var _pending_breakthrough := ""


func _ready() -> void:
	_wolf_pool = ObjectPool.new(WOLF_SCENE, $Enemies, 200, _connect_enemy.bind(_recycle_wolf))
	_crow_pool = ObjectPool.new(CROW_SCENE, $Enemies, 100, _connect_crow)
	_golem_pool = ObjectPool.new(GOLEM_SCENE, $Enemies, 8, _connect_enemy.bind(_recycle_golem))
	_boss_pool = ObjectPool.new(BOSS_SCENE, $Enemies, 1, _connect_boss)
	_orb_pool = ObjectPool.new(ORB_SCENE, $Projectiles, 100, _connect_orb)
	_sword_pool = ObjectPool.new(SWORD_SCENE, $Projectiles, 100, _connect_sword)
	_crystal_pool = ObjectPool.new(CRYSTAL_SCENE, $Pickups, 200, _connect_crystal)
	_skills.configure(_player, _living_enemies, _launch_sword)
	_hud.set_health(_player.health, _player.max_health)
	_refresh_hud()
	_update_grid_bounds()


func _process(delta: float) -> void:
	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - delta)
		var t := SHAKE_DURATION - _shake_left
		var strength := 12.0 * _shake_left / SHAKE_DURATION
		_camera.offset = Vector2(sin(t * 86.0), cos(t * 107.0)) * strength
	_update_grid_bounds()


func _physics_process(delta: float) -> void:
	if _phase != Phase.BATTLE:
		return
	# 只累计实际战斗时间，通过刷新进度在提速时保留本轮已经等待的时间。
	_spawn_progress += delta / _spawn_interval(_elapsed)
	_elapsed += delta
	while _spawn_progress + TIME_EPSILON >= 1.0:
		_spawn_progress -= 1.0
		if _elapsed + TIME_EPSILON >= CROW_START:
			_spawn_enemy(_crow_pool if _spawn_mix_index == 0 else _wolf_pool)
			_spawn_mix_index = (_spawn_mix_index + 1) % 3
		else:
			_spawn_enemy(_wolf_pool)

	while _elapsed + TIME_EPSILON >= _next_golem_at:
		_spawn_enemy(_golem_pool)
		_next_golem_at += GOLEM_INTERVAL

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


func _connect_crow(crow: CrowDemon) -> void:
	_connect_enemy(crow, _recycle_crow)
	crow.orb_cast.connect(_launch_orb)


func _connect_boss(boss: DemonLord) -> void:
	_connect_enemy(boss, _recycle_boss)
	boss.health_changed.connect(_hud.set_boss_health)
	boss.flame_cast.connect(_launch_orb.bind(BOSS_FLAME_TINT))
	boss.wolves_summoned.connect(_summon_wolves)


func _connect_orb(orb: MagicOrb) -> void:
	orb.finished.connect(_recycle_orb)


func _connect_sword(sword: FlyingSword) -> void:
	sword.finished.connect(_recycle_sword)


func _connect_crystal(crystal: SpiritCrystal) -> void:
	crystal.collected.connect(_on_crystal_collected)


func _spawn_enemy(pool: ObjectPool) -> Enemy:
	return _spawn_enemy_at(pool, _outside_screen_position())


func _spawn_enemy_at(pool: ObjectPool, position_in_world: Vector2) -> Enemy:
	var enemy := pool.acquire() as Enemy
	enemy.spawn(position_in_world, _player)
	_living_enemies.append(enemy)
	return enemy


func _spawn_boss() -> void:
	_boss_spawned = true
	var boss := _spawn_enemy(_boss_pool)
	_shake_left = SHAKE_DURATION
	_hud.show_boss(boss.max_health)


func _summon_wolves(origin: Vector2) -> void:
	if _phase != Phase.BATTLE:
		return
	for i in range(BOSS_SUMMON_COUNT):
		var offset := Vector2.from_angle(TAU * i / BOSS_SUMMON_COUNT) * BOSS_SUMMON_RADIUS
		_spawn_enemy_at(_wolf_pool, origin + offset)


func _outside_screen_position() -> Vector2:
	# 按实际画面边缘刷怪，摄像机滞后或窗口比例变化时也不在屏内生成。
	var view := get_viewport_rect()
	var point: Vector2
	match randi_range(0, 3):
		0:
			point = Vector2(view.position.x - SPAWN_MARGIN, randf_range(view.position.y, view.end.y))
		1:
			point = Vector2(view.end.x + SPAWN_MARGIN, randf_range(view.position.y, view.end.y))
		2:
			point = Vector2(randf_range(view.position.x, view.end.x), view.position.y - SPAWN_MARGIN)
		3:
			point = Vector2(randf_range(view.position.x, view.end.x), view.end.y + SPAWN_MARGIN)
	return get_viewport().get_canvas_transform().affine_inverse() * point


func _launch_sword(origin: Vector2, direction: Vector2, damage: int) -> void:
	var sword := _sword_pool.acquire() as FlyingSword
	sword.launch(origin, direction, damage)


func _launch_orb(origin: Vector2, direction: Vector2, damage: int, tint := MagicOrb.DEFAULT_TINT) -> void:
	var orb := _orb_pool.acquire() as MagicOrb
	orb.launch(origin, direction, damage, _player, tint)


func _on_enemy_died(enemy: Enemy) -> void:
	_living_enemies.erase(enemy)
	if _phase != Phase.BATTLE:
		return
	_kills += 1
	if enemy is DemonLord:
		_begin_victory()
		return
	for i in range(enemy.crystal_count):
		# 多颗灵晶稍微错开；沿用靠近后才磁吸的规则。
		var offset := Vector2.ZERO
		if i > 0:
			offset = Vector2.from_angle(TAU * (i - 1) / (enemy.crystal_count - 1)) * 21.0
		var crystal := _crystal_pool.acquire() as SpiritCrystal
		crystal.drop(enemy.global_position + offset, _player)


func _recycle_wolf(enemy: Enemy) -> void:
	_wolf_pool.release(enemy)


func _recycle_crow(enemy: Enemy) -> void:
	_crow_pool.release(enemy)


func _recycle_golem(enemy: Enemy) -> void:
	_golem_pool.release(enemy)


func _recycle_boss(enemy: Enemy) -> void:
	_boss_pool.release(enemy)


func _recycle_orb(orb: MagicOrb) -> void:
	_orb_pool.release(orb)


func _recycle_sword(sword: FlyingSword) -> void:
	_sword_pool.release(sword)


func _on_crystal_collected(crystal: SpiritCrystal) -> void:
	_crystal_pool.release(crystal)
	if _phase != Phase.BATTLE or not _player.is_alive():
		return
	_xp += 1
	_refresh_hud()
	if _xp >= _xp_required and not _upgrade_menu.visible:
		_show_level_up()


func _show_level_up() -> void:
	_choices = _skills.roll_choices()
	var cards := PackedStringArray()
	for skill in _choices:
		cards.append(_skills.card_text(skill))
	# 暂停前清除旧触点，防止松手发生在暂停期间、恢复后角色仍在移动。
	_joystick.reset()
	get_tree().paused = true
	_upgrade_menu.open(cards)


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


func _update_grid_bounds() -> void:
	# 网格固定在世界坐标中，只绘制镜头可见范围和一格余量。
	var half_view := get_viewport_rect().size * 0.5
	var center := _camera.get_screen_center_position()
	var start := Vector2i(((center - half_view) / GRID_SIZE).floor()) - Vector2i.ONE
	var end := Vector2i(((center + half_view) / GRID_SIZE).ceil()) + Vector2i.ONE
	var bounds := Rect2i(start, end - start)

	if bounds != _grid_bounds:
		_grid_bounds = bounds
		queue_redraw()


func _draw() -> void:
	var start := _grid_bounds.position * GRID_SIZE
	var end := _grid_bounds.end * GRID_SIZE
	draw_rect(Rect2(Vector2(start), Vector2(end - start)), GROUND_COLOR)

	for x in range(start.x, end.x + 1, GRID_SIZE):
		draw_line(Vector2(x, start.y), Vector2(x, end.y), GRID_COLOR, 2.0)
	for y in range(start.y, end.y + 1, GRID_SIZE):
		draw_line(Vector2(start.x, y), Vector2(end.x, y), GRID_COLOR, 2.0)
