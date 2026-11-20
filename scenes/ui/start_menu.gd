extends Control

const BATTLE_SCENE := "res://scenes/main.tscn"


func _start_battle() -> void:
	var button: Button = $Center/Content/Start
	button.disabled = true
	if get_tree().change_scene_to_file(BATTLE_SCENE) != OK:
		button.disabled = false
