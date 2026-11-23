extends Control

signal choice_selected(index: int)

const Look = preload("res://scenes/ui/ui_look.gd")
@onready var _cards: HBoxContainer = $Center/Content/Cards

var _buttons: Array[Button] = []
var _selecting := false
var _gold := Look.evolution_box()
var _gold_hover := Look.evolution_box(true)


func _ready() -> void:
	for child in _cards.get_children():
		var card := child as Button
		card.pressed.connect(_choose.bind(_buttons.size()))
		_buttons.append(card)


func open(choices: PackedStringArray, gold_index := -1) -> void:
	for i in range(_buttons.size()):
		var card := _buttons[i]
		card.visible = i < choices.size()
		if card.visible:
			card.text = "%d\n%s" % [i + 1, choices[i]]
			card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if i == gold_index:
				card.add_theme_stylebox_override("normal", _gold)
				card.add_theme_stylebox_override("hover", _gold_hover)
				card.add_theme_stylebox_override("pressed", _gold_hover)
				card.add_theme_color_override("font_color", Look.GOLD)
			else:
				for key in ["normal", "hover", "pressed"]:
					card.remove_theme_stylebox_override(key)
				card.remove_theme_color_override("font_color")
	_selecting = true
	show()


func _input(event: InputEvent) -> void:
	if not visible or not _selecting or not event is InputEventKey or not event.pressed or event.echo:
		return
	var index := -1
	match event.keycode:
		KEY_1, KEY_KP_1:
			index = 0
		KEY_2, KEY_KP_2:
			index = 1
		KEY_3, KEY_KP_3:
			index = 2
	if index >= 0:
		get_viewport().set_input_as_handled()
		_choose(index)


func _choose(index: int) -> void:
	if not _selecting or not _buttons[index].visible:
		return
	_selecting = false
	choice_selected.emit(index)
