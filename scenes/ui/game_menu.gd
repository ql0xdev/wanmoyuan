extends Control

const Look = preload("res://scenes/ui/ui_look.gd")

signal closed
signal retreat_requested

const RUN_WARNING := "本局未结算的灵石和装备不会保留，下次从洞府开始。"
const RETREAT_WARNING := "带回本局已获得的装备和剩余灵石。未拾取的掉落不带回，本局不计通关。"

enum Confirmation { NONE, RETREAT, QUIT_GAME }

@onready var _title: Label = $Center/Panel/Content/Title
@onready var _hint: Label = $Center/Panel/Content/Hint
@onready var _save: Button = $Center/Panel/Content/Save
@onready var _retreat: Button = $Center/Panel/Content/ExitActions/Retreat
@onready var _exit: Button = $Center/Panel/Content/ExitActions/Exit
@onready var _back: Button = $Center/Panel/Content/Back

var _in_battle := false
var _confirmation := Confirmation.NONE


func _ready() -> void:
	Look.animate_panel(self, $Center)


func open(in_battle: bool) -> void:
	_in_battle = in_battle
	_show_actions()
	show()
	_back.grab_focus()


func _show_actions() -> void:
	_confirmation = Confirmation.NONE
	_title.text = "战斗暂停" if _in_battle else "游戏菜单"
	_hint.text = "仅保存洞府进度，不保存本局战斗。" if _in_battle else "突破、加点和换装后会自动存档。"
	_save.show()
	_retreat.visible = _in_battle
	_retreat.text = "退出战斗"
	_exit.show()
	_exit.text = "退出游戏"
	_back.text = "继续战斗" if _in_battle else "关闭菜单"


func _save_progress() -> void:
	if SaveManager.save_profile() == OK:
		_hint.text = "洞府进度已保存。本局战斗未保存。" if _in_battle else "洞府进度已保存。"
	else:
		_hint.text = "保存失败，原有存档未修改。请重试。"


func _exit_pressed() -> void:
	if _confirmation == Confirmation.NONE:
		_exit.text = "保存并退出"
		_ask_confirmation(Confirmation.QUIT_GAME, "确认退出？", RUN_WARNING if _in_battle else "保存洞府进度后退出游戏。")
	elif _confirmation == Confirmation.QUIT_GAME:
		if SaveManager.save_profile() == OK:
			get_tree().quit()
		else:
			_hint.text = "保存失败，游戏未退出。请重试。"
			if _in_battle:
				_hint.text += "\n" + RUN_WARNING


func _retreat_pressed() -> void:
	if not _in_battle:
		return
	if _confirmation == Confirmation.NONE:
		_retreat.text = "撤离并结算"
		_ask_confirmation(Confirmation.RETREAT, "退出战斗？", RETREAT_WARNING)
	elif _confirmation == Confirmation.RETREAT:
		retreat_requested.emit()


func _ask_confirmation(action: Confirmation, title: String, hint: String) -> void:
	_confirmation = action
	_title.text = title
	_hint.text = hint
	_save.hide()
	_retreat.visible = action == Confirmation.RETREAT
	_exit.visible = action == Confirmation.QUIT_GAME
	_back.text = "取消"
	_back.grab_focus()


func _back_pressed() -> void:
	if _confirmation != Confirmation.NONE:
		_show_actions()
		_back.grab_focus()
	else:
		hide()
		closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_back_pressed()
