extends Control

const Look = preload("res://scenes/ui/ui_look.gd")

signal closed

const RUN_WARNING := "本局未结算的灵石和装备不会保留，下次从洞府开始。"

@onready var _title: Label = $Center/Panel/Content/Title
@onready var _hint: Label = $Center/Panel/Content/Hint
@onready var _save: Button = $Center/Panel/Content/Save
@onready var _exit: Button = $Center/Panel/Content/Exit
@onready var _back: Button = $Center/Panel/Content/Back

var _in_battle := false
var _confirming := false


func _ready() -> void:
	Look.animate_panel(self, $Center)


func open(in_battle: bool) -> void:
	_in_battle = in_battle
	_show_actions()
	show()
	_back.grab_focus()


func _show_actions() -> void:
	_confirming = false
	_title.text = "战斗暂停" if _in_battle else "游戏菜单"
	_hint.text = "仅保存洞府进度，不保存本局战斗。" if _in_battle else "突破、加点和换装后会自动存档。"
	_save.show()
	_exit.text = "退出游戏"
	_back.text = "继续战斗" if _in_battle else "关闭菜单"


func _save_progress() -> void:
	if SaveManager.save_profile() == OK:
		_hint.text = "洞府进度已保存。本局战斗未保存。" if _in_battle else "洞府进度已保存。"
	else:
		_hint.text = "保存失败，原有存档未修改。请重试。"


func _exit_pressed() -> void:
	if not _confirming:
		_confirming = true
		_title.text = "确认退出？"
		_hint.text = RUN_WARNING if _in_battle else "保存洞府进度后退出游戏。"
		_save.hide()
		_exit.text = "保存并退出"
		_back.text = "取消"
		_back.grab_focus()
	elif SaveManager.save_profile() == OK:
		get_tree().quit()
	else:
		_hint.text = "保存失败，游戏未退出。请重试。"
		if _in_battle:
			_hint.text += "\n" + RUN_WARNING


func _back_pressed() -> void:
	if _confirming:
		_show_actions()
		_back.grab_focus()
	else:
		hide()
		closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_back_pressed()
