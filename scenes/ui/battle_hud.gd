extends Control

const SkillBar = preload("res://scenes/ui/run_skill_bar.gd")
@onready var _realm_label: Label = $Top/Margin/Rows/Heading/Realm
@onready var _xp_bar: ProgressBar = $Top/Margin/Rows/Experience
@onready var _xp_label: Label = $Top/Margin/Rows/Experience/Value
@onready var _health_bar: ProgressBar = $Health
@onready var _health_label: Label = $Health/Value
@onready var _time_label: Label = $BattleCounters/SurvivalTime
@onready var _stone_label: Label = $BattleCounters/SpiritStones/Amount
@onready var shop_button: Button = $BattleCounters/ShopButton
@onready var bag_button: Button = $BattleCounters/BagButton
@onready var menu_button: Button = $Top/Margin/Rows/Heading/MenuButton
@onready var _boss_bar: ProgressBar = $BossHealth
@onready var _boss_label: Label = $BossHealth/Caption/Value
@onready var _boss_title: Label = $BossHealth/Caption/BossName
@onready var _boss_notice: PanelContainer = $BossNotice
@onready var _wave_notice: Label = $WaveNotice
@onready var _boss_action: Label = $BossAction
@onready var _victory_loot_panel: PanelContainer = $VictoryLoot
@onready var _victory_loot_label: Label = $VictoryLoot/Rows/Seconds
@onready var _loot_notice: Button = $LootNotice

var _loot_tween: Tween
var _boss_notice_tween: Tween
var _wave_tween: Tween
var _action_tween: Tween
var _boss_name := ""
var _shield := 0
var _skill_bar: SkillBar
var _shown_victory_loot_seconds := -1
var loot_item_id := 0


func _ready() -> void:
	_skill_bar = SkillBar.new()
	_skill_bar.name = "RunSkillBar"
	add_child(_skill_bar)
	_skill_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_skill_bar.offset_left = -243
	_skill_bar.offset_right = 243
	_skill_bar.offset_top = -65
	_skill_bar.offset_bottom = -13


func set_skills(skills: Array[Dictionary]) -> void:
	_skill_bar.display(skills)


func set_progress(level: int, abyss: String, realm: String, xp: int, required: int) -> void:
	_realm_label.text = "%s · %s · Lv%d" % [abyss, realm, level]
	_xp_bar.max_value = required
	_xp_bar.value = xp
	_xp_label.text = "修为灵石 %d / %d" % [mini(xp, required), required]


func set_health(current: int, maximum: int) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "生命 %d / %d%s" % [current, maximum, "  ·  护盾 %d" % _shield if _shield > 0 else ""]


func set_shield(amount: int) -> void:
	_shield = amount
	set_health(int(_health_bar.value), int(_health_bar.max_value))


func set_survival_time(seconds: int, duration: int) -> void:
	_time_label.text = "%02d:%02d / %02d:%02d" % [seconds / 60.0, seconds % 60, duration / 60.0, duration % 60]


func set_spirit_stones(amount: int) -> void:
	_stone_label.text = str(amount)


func show_boss(boss_name: String, maximum: int) -> void:
	_boss_name = boss_name
	set_boss_stage(1)
	_boss_bar.max_value = maximum
	set_boss_health(maximum)
	_boss_bar.show()
	if _boss_notice_tween != null:
		_boss_notice_tween.kill()
	_boss_notice.pivot_offset = _boss_notice.size * 0.5
	_boss_notice.scale = Vector2.ONE * 0.92
	_boss_notice.modulate.a = 0.35
	_boss_notice.show()
	_boss_notice_tween = create_tween().set_parallel()
	_boss_notice_tween.tween_property(_boss_notice, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_boss_notice_tween.tween_property(_boss_notice, "modulate:a", 1.0, 0.16)
	_boss_notice_tween.chain().tween_property(_boss_notice, "modulate:a", 0.0, 0.42).set_delay(2.2)
	_boss_notice_tween.chain().tween_callback(_boss_notice.hide)


func set_boss_health(current: int) -> void:
	_boss_bar.value = current
	_boss_label.text = "%d / %d" % [current, int(_boss_bar.max_value)]


func set_boss_stage(stage: int) -> void:
	_boss_title.text = "%s · %s" % [_boss_name, ["Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ"][stage - 1]]


func show_wave_warning() -> void:
	if _wave_tween != null:
		_wave_tween.kill()
	_wave_notice.show()
	_wave_notice.modulate.a = 1.0
	_wave_tween = create_tween()
	_wave_tween.tween_property(_wave_notice, "modulate:a", 0.0, 0.25).set_delay(2.75)
	_wave_tween.tween_callback(_wave_notice.hide)


func clear_wave_warning() -> void:
	if _wave_notice.visible:
		_wave_notice.hide()


func show_boss_action(action: String) -> void:
	if _action_tween != null:
		_action_tween.kill()
	_boss_action.text = action
	_boss_action.modulate.a = 1.0
	_boss_action.show()
	_action_tween = create_tween()
	_action_tween.tween_property(_boss_action, "modulate:a", 0.0, 0.24).set_delay(1.15)
	_action_tween.tween_callback(_boss_action.hide)


func show_victory_loot(seconds: int) -> void:
	_boss_bar.hide()
	_boss_notice.hide()
	_boss_action.hide()
	_wave_notice.hide()
	menu_button.hide()
	shop_button.hide()
	bag_button.hide()
	_loot_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_victory_loot_seconds(seconds)
	_victory_loot_panel.show()


func set_victory_loot_seconds(seconds: int) -> void:
	if seconds != _shown_victory_loot_seconds:
		_shown_victory_loot_seconds = seconds
		_victory_loot_label.text = "安全拾取 · %d 秒" % seconds


func show_loot(message: String, color: Color, item_id := 0) -> void:
	if _loot_tween != null:
		_loot_tween.kill()
	_loot_notice.text = message
	var width := minf(size.x, _loot_notice.get_combined_minimum_size().x + 36.0)
	_loot_notice.offset_left = -width * 0.5
	_loot_notice.offset_right = width * 0.5
	_loot_notice.offset_bottom = 48.0
	loot_item_id = item_id
	_loot_notice.mouse_filter = Control.MOUSE_FILTER_STOP if item_id != 0 else Control.MOUSE_FILTER_IGNORE
	_loot_notice.modulate = color
	_loot_notice.show()
	_loot_tween = create_tween()
	_loot_tween.tween_property(_loot_notice, "modulate:a", 0.0, 0.28).set_delay(1.8)
	_loot_tween.tween_callback(_loot_notice.hide)
