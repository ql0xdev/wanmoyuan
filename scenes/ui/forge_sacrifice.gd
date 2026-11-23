extends Control

signal confirmed(ids: Array)

const Equipment = preload("res://scripts/equipment_catalog.gd")
const Look = preload("res://scenes/ui/ui_look.gd")
var _list: VBoxContainer
var _status: Label
var _title: Label
var _confirm: Button
var _scroll: ScrollContainer
var _checked := {}
var _cost := Vector2i.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color("#0d1117bf")
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 30
	panel.offset_right = -30
	panel.offset_top = 64
	panel.offset_bottom = -64
	panel.add_theme_stylebox_override("panel", Look.box(Look.PANEL, Look.GOLD, 2, 8, 16))
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 12)
	panel.add_child(contents)
	_title = _label(contents, 28, Look.GOLD)
	_status = _label(contents, 22, Look.CYAN)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 10
	contents.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_confirm = _button(contents, "确认熔掉祭品并升星", _commit)
	_button(contents, "返回", hide)
	hide()


func open(item: Dictionary, candidates: Array, cost: Vector2i) -> void:
	_cost = cost
	_checked.clear()
	_title.text = "升星 · %s → %d 星" % [Equipment.title(item), item.get("star", 0) + 1]
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for candidate: Dictionary in candidates:
		var button := CheckButton.new()
		button.custom_minimum_size.y = 56
		button.text = "%s · %d 星" % [Equipment.title(candidate), candidate.get("star", 0)]
		button.add_theme_color_override("font_color", Equipment.COLORS[candidate.quality])
		button.toggled.connect(_toggle.bind(candidate.id, button))
		_list.add_child(button)
	_refresh()
	show()
	_scroll.scroll_vertical = 0


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		hide()


func _toggle(pressed: bool, id: int, button: CheckButton) -> void:
	if pressed:
		if _checked.size() >= _cost.y:
			button.set_pressed_no_signal(false)
			return
		_checked[id] = true
	else:
		_checked.erase(id)
	_refresh()


func _refresh() -> void:
	_status.text = "玄铁 %d · 已选祭品 %d/%d\n勾选同部位装备。确认后祭品消失，不返还材料。" % [_cost.x, _checked.size(), _cost.y]
	_confirm.disabled = _checked.size() != _cost.y


func _commit() -> void:
	if not _confirm.disabled:
		hide()
		confirmed.emit(_checked.keys())


func _label(parent: Control, text_size: int, ink: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", text_size)
	label.add_theme_color_override("font_color", ink)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _button(parent: Control, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 56
	parent.add_child(button)
	Look.skin_button(button)
	button.pressed.connect(action)
	return button
