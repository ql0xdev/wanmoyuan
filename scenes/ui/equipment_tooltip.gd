extends Control

signal dismissed
signal wear_requested
signal salvage_requested
signal star_requested

const Equipment = preload("res://scripts/equipment_catalog.gd")
const Look = preload("res://scenes/ui/ui_look.gd")
const GAIN := Color("#72de9a")
const LOSS := Color("#ff858b")
const INSET := 10.0

var _panel: PanelContainer
var _rows: VBoxContainer
var _primary: VBoxContainer
var _comparison: VBoxContainer
var _scroll: ScrollContainer
var _status: Label
var _wear: Button
var _star: Button
var _salvage: Button
var _close: Button
var _anchor := Rect2()
var _has_compare := false
var _shown := {}


func _ready() -> void:
	hide()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	add_child(_panel)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 9)
	_panel.add_child(_rows)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 10
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows.add_child(_scroll)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(columns)
	_primary = _make_column(columns)
	var divider := VSeparator.new()
	columns.add_child(divider)
	_comparison = _make_column(columns)
	_comparison.visibility_changed.connect(func() -> void: divider.visible = _comparison.visible)
	_status = _label(_rows, "", 20, Look.MUTED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	_rows.add_child(buttons)
	_wear = _action(buttons, "穿戴", wear_requested.emit)
	_star = _action(buttons, "升星", star_requested.emit)
	_salvage = _action(buttons, "分解", salvage_requested.emit)
	_close = _action(buttons, "关闭", close)
	resized.connect(_arrange)


func inspect(item: Dictionary, worn: Dictionary, anchor: Rect2, actions: Dictionary) -> void:
	var first_open := not visible
	_anchor = anchor
	var stamp := {"item": item, "worn": worn, "actions": actions}
	if _shown == stamp:
		_status.text = actions.get("hint", "")
		_status.add_theme_color_override("font_color", Look.MUTED)
		_status.visible = not _status.text.is_empty()
		show()
		if first_open:
			_scroll.scroll_vertical = 0
		_arrange()
		return
	_shown = stamp.duplicate(true)
	_has_compare = not worn.is_empty() and worn.id != item.id
	var fill := Look.BACKGROUND
	fill.a = 0.92
	var style := Look.box(fill, Equipment.COLORS[item.quality], 2, 8, 14)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 6
	_panel.add_theme_stylebox_override("panel", style)
	_clear(_primary)
	_clear(_comparison)
	_comparison.visible = _has_compare
	_heading(_primary, item, "查看装备" if not actions.get("worn", false) else "当前穿戴")
	if _has_compare:
		_heading(_comparison, worn, "当前穿戴 · 对比")
	_show_group("基础属性", Equipment.base_stats(item), Equipment.base_stats(worn) if _has_compare else {})
	_show_group("词条", item.affixes, worn.affixes if _has_compare else {})
	_wear.text = "卸下" if actions.get("worn", false) else "穿戴"
	_wear.disabled = not actions.get("wear", false)
	_star.disabled = not actions.get("star", false)
	_salvage.disabled = not actions.get("salvage", false)
	show_status(actions.get("hint", ""))
	show()
	if first_open:
		_scroll.scroll_vertical = 0
	_arrange()


func show_status(message: String, tint := Look.MUTED) -> void:
	_status.text = message
	_status.add_theme_color_override("font_color", tint)
	_status.visible = not message.is_empty()
	_arrange()


func close() -> void:
	if visible:
		hide()
		dismissed.emit()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		close()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()


func _arrange() -> void:
	if not visible or size.x <= 0.0:
		return
	var transform_to_local := get_global_transform_with_canvas().affine_inverse()
	var anchor: Rect2 = transform_to_local * _anchor
	var size_hint := Vector2(minf(size.x - INSET * 2.0, 646.0 if _has_compare else 452.0), 0.0)
	_scroll.custom_minimum_size.y = minf(maxf(_primary.get_combined_minimum_size().y, _comparison.get_combined_minimum_size().y),
		maxf(120.0, size.y - 176.0))
	_panel.size = size_hint
	var wanted := anchor.end + Vector2(INSET, -anchor.size.y)
	if wanted.x + _panel.size.x > size.x - INSET:
		wanted.x = anchor.position.x - _panel.size.x - INSET
	if wanted.x < INSET:
		wanted = Vector2(anchor.get_center().x - _panel.size.x * 0.5, anchor.end.y + INSET)
		if wanted.y + _panel.size.y > size.y - INSET:
			wanted.y = anchor.position.y - _panel.size.y - INSET
	_panel.position = wanted.clamp(Vector2.ONE * INSET, (size - _panel.size - Vector2.ONE * INSET).max(Vector2.ONE * INSET))


func _make_column(parent: Control) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	parent.add_child(column)
	return column


func _heading(column: VBoxContainer, item: Dictionary, caption: String) -> void:
	_label(column, caption, 20, Look.GOLD)
	_label(column, Equipment.title(item), 23, Equipment.COLORS[item.quality])
	var stars: int = item.get("star", 0)
	_label(column, "★".repeat(stars) + "☆".repeat(5 - stars) + "  %d 星" % stars, 22, Look.GOLD)
	_label(column, "%s · %s级" % [Equipment.SLOTS[item.slot].name, Equipment.TIERS[item.tier]], 20, Look.MUTED)


func _show_group(title: String, values: Dictionary, prior: Dictionary) -> void:
	_label(_primary, title, 20, Look.GOLD)
	if _has_compare:
		_label(_comparison, title, 20, Look.GOLD)
	var keys := values.keys()
	for stat: String in prior:
		if not values.has(stat):
			keys.append(stat)
	if keys.is_empty():
		_label(_primary, "无", 20, Look.MUTED)
		if _has_compare:
			_label(_comparison, "无", 20, Look.MUTED)
	for stat: String in keys:
		var new: float = values.get(stat, 0.0)
		var current: float = prior.get(stat, 0.0)
		_stat_row(_primary, stat, new, new - current if _has_compare else 0.0)
		if _has_compare:
			_stat_row(_comparison, stat, current)


func _stat_row(parent: Control, stat: String, amount: float, delta := 0.0) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var name: String = Equipment.AFFIXES.get(stat, {"name": "气血上限"}).name
	var caption := _label(row, name, 20, Look.TEXT)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(row, _amount(stat, amount, false), 20, Look.CYAN)
	if not is_zero_approx(delta):
		_label(row, _amount(stat, delta, true), 20, GAIN if delta > 0.0 else LOSS)


func _amount(stat: String, value: float, signed: bool) -> String:
	var flat := stat in ["health_flat", "kill_heal"]
	var number := ("%.2f" % (absf(value) * (1.0 if flat else 100.0))).rstrip("0").rstrip(".")
	return ("+" if value > 0.0 and signed else ("−" if value < 0.0 else "")) + number + ("" if flat else "%")


func _label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _action(parent: Control, text: String, press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(76, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	Look.skin_button(button)
	button.pressed.connect(press)
	return button


func _clear(node: Control) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
