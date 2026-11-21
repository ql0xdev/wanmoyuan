extends Control

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
@onready var _boss_label: Label = $BossHealth/Value
@onready var _boss_notice: Label = $BossNotice
@onready var _loot_notice: Label = $LootNotice

var _boss_name := ""
var _loot_tween: Tween


func set_progress(level: int, abyss: String, realm: String, xp: int, required: int) -> void:
	_realm_label.text = "%s · %s · Lv%d" % [abyss, realm, level]
	_xp_bar.max_value = required
	_xp_bar.value = xp
	_xp_label.text = "%d / %d" % [mini(xp, required), required]


func set_health(current: int, maximum: int) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "生命 %d / %d" % [current, maximum]


func set_survival_time(seconds: int) -> void:
	_time_label.text = "%02d:%02d" % [seconds / 60.0, seconds % 60]


func set_spirit_stones(amount: int) -> void:
	_stone_label.text = str(amount)


func show_boss(boss_name: String, maximum: int) -> void:
	_boss_name = boss_name
	_boss_bar.max_value = maximum
	set_boss_health(maximum)
	_boss_bar.show()
	_boss_notice.modulate.a = 1.0
	_boss_notice.text = boss_name + " 现世"
	_boss_notice.show()
	var tween := create_tween()
	tween.tween_property(_boss_notice, "modulate:a", 0.0, 0.35).set_delay(1.6)
	tween.tween_callback(_boss_notice.hide)


func set_boss_health(current: int) -> void:
	_boss_bar.value = current
	_boss_label.text = "%s  %d / %d" % [_boss_name, current, int(_boss_bar.max_value)]


func show_loot(message: String, color: Color) -> void:
	if _loot_tween != null:
		_loot_tween.kill()
	_loot_notice.text = message
	_loot_notice.modulate = color
	_loot_notice.show()
	_loot_tween = create_tween()
	_loot_tween.tween_property(_loot_notice, "modulate:a", 0.0, 0.28).set_delay(1.8)
	_loot_tween.tween_callback(_loot_notice.hide)
