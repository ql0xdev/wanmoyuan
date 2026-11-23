extends Control

const Look = preload("res://scenes/ui/ui_look.gd")

signal restart_requested
signal cave_requested
signal save_retry_requested
signal organize_requested

@onready var _title: Label = $Center/Panel/Margin/Content/Title
@onready var _stats: Label = $Center/Panel/Margin/Content/Stats
@onready var _settlement: Label = $Center/Panel/Margin/Content/Settlement
@onready var _retry: Button = $Center/Panel/Margin/Content/Retry
@onready var _restart: Button = $Center/Panel/Margin/Content/Restart
@onready var _cave: Button = $Center/Panel/Margin/Content/Cave
@onready var _organize: Button = $Center/Panel/Margin/Content/Organize


func open(won: bool, seconds: int, kills: int, level: int, retreated := false, survived := false) -> void:
	_title.text = "存活结算" if survived else ("提前撤离" if retreated else ("渡劫成功" if won else "身死道消"))
	_title.modulate = Look.GOLD
	var time := "%02d:%02d" % [seconds / 60.0, seconds % 60]
	_stats.text = "存活时间  %s\n击杀数  %d\n局内等级  %d" % [time, kills, level]
	show()


func show_settlement(error: Error, stones: int, total: int, loot_count: int, iron := 0) -> void:
	if error == OK:
		_settlement.text = "本局带出  +%d 灵石 · +%d 玄铁 · %d 件装备\n洞府灵石  %d" % [stones, iron, loot_count, total]
		_settlement.modulate = Look.CYAN
	elif error == ERR_OUT_OF_MEMORY:
		_settlement.text = "装备库空间不足\n请先分解多出的战利品"
		_settlement.modulate = Look.MUTED
	else:
		_settlement.text = "存档失败 · %d 灵石与 %d 玄铁尚未带出\n请重试保存" % [stones, iron]
		_settlement.modulate = Look.MUTED
	_retry.visible = error != OK and error != ERR_OUT_OF_MEMORY
	_organize.visible = error == ERR_OUT_OF_MEMORY
	_restart.disabled = error != OK
	_cave.disabled = error != OK


func _on_restart_pressed() -> void:
	restart_requested.emit()


func show_cave_error() -> void:
	_settlement.text = "战利品已保存。洞府商品刷新失败，请重试返回洞府。"


func _on_cave_pressed() -> void:
	cave_requested.emit()


func _on_retry_pressed() -> void:
	save_retry_requested.emit()


func _on_organize_pressed() -> void:
	organize_requested.emit()
