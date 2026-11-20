extends Control

signal restart_requested

@onready var _title: Label = $Center/Panel/Margin/Content/Title
@onready var _stats: Label = $Center/Panel/Margin/Content/Stats


func open(won: bool, seconds: int, kills: int, realm: String) -> void:
	_title.text = "渡劫成功" if won else "身死道消"
	_title.modulate = Color("#ffda91") if won else Color("#ffa39c")
	var time := "%02d:%02d" % [seconds / 60.0, seconds % 60]
	_stats.text = "存活时间  %s\n击杀数  %d" % [time, kills]
	if won:
		_stats.text += "\n最终境界  %s" % realm
	show()


func _on_restart_pressed() -> void:
	restart_requested.emit()
