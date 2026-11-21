extends Control

const CAVE_SCENE := "res://scenes/ui/cave_menu.tscn"

@onready var _start: Button = $Center/Content/Start
@onready var _status: Label = $Center/Content/Status


func _ready() -> void:
	if SaveManager.load_error() != OK:
		_start.disabled = true
		_status.text = "无法读取存档，原文件未修改。"
		_status.show()
	elif SaveManager.has_profile():
		_start.text = "继续修行"


func _enter_cave() -> void:
	_start.disabled = true
	if SaveManager.ensure_profile() != OK:
		_status.text = "无法建立存档，请重试。"
	elif get_tree().change_scene_to_file(CAVE_SCENE) == OK:
		return
	else:
		_start.text = "继续修行"
		_status.text = "无法进入洞府，请重试。"
	_status.show()
	_start.disabled = false
