extends Control

@onready var _realm_label: Label = $Top/Margin/Rows/Realm
@onready var _xp_bar: ProgressBar = $Top/Margin/Rows/Experience
@onready var _xp_label: Label = $Top/Margin/Rows/Experience/Value
@onready var _health_bar: ProgressBar = $Health
@onready var _health_label: Label = $Health/Value
@onready var _time_label: Label = $SurvivalTime
@onready var _boss_bar: ProgressBar = $BossHealth
@onready var _boss_label: Label = $BossHealth/Value
@onready var _boss_notice: Label = $BossNotice
@onready var _flash: ColorRect = $BreakthroughFlash
@onready var _notice: Label = $BreakthroughNotice

var _breakthrough_tween: Tween


func set_progress(level: int, realm: String, xp: int, required: int) -> void:
	_realm_label.text = "%s · Lv%d" % [realm, level]
	_xp_bar.max_value = required
	_xp_bar.value = xp
	_xp_label.text = "%d / %d" % [mini(xp, required), required]


func set_health(current: int, maximum: int) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "生命 %d / %d" % [current, maximum]


func set_survival_time(seconds: int) -> void:
	_time_label.text = "%02d:%02d" % [seconds / 60.0, seconds % 60]


func show_boss(maximum: int) -> void:
	_boss_bar.max_value = maximum
	set_boss_health(maximum)
	_boss_bar.show()
	_boss_notice.modulate.a = 1.0
	_boss_notice.show()
	var tween := create_tween()
	tween.tween_property(_boss_notice, "modulate:a", 0.0, 0.35).set_delay(1.6)
	tween.tween_callback(_boss_notice.hide)


func set_boss_health(current: int) -> void:
	_boss_bar.value = current
	_boss_label.text = "魔尊  %d / %d" % [current, int(_boss_bar.max_value)]


func show_breakthrough(realm: String) -> void:
	if _breakthrough_tween != null:
		_breakthrough_tween.kill()
	_flash.modulate.a = 1.0
	_notice.modulate.a = 1.0
	_notice.text = "突破·%s" % realm
	_flash.show()
	_notice.show()
	_breakthrough_tween = create_tween().set_parallel()
	_breakthrough_tween.tween_property(_flash, "modulate:a", 0.0, 0.45)
	_breakthrough_tween.tween_property(_notice, "modulate:a", 0.0, 0.4).set_delay(0.85)
	_breakthrough_tween.chain().tween_callback(_hide_breakthrough)


func _hide_breakthrough() -> void:
	_flash.hide()
	_notice.hide()
