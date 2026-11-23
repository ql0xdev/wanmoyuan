extends ScrollContainer

const Catalog = preload("res://scripts/cultivation_catalog.gd")
const Equipment = preload("res://scripts/equipment_catalog.gd")
const Stats = preload("res://scripts/stats_manager.gd")
const Tooltip = preload("res://scenes/ui/equipment_tooltip.gd")
const Look = preload("res://scenes/ui/ui_look.gd")

var _slots := {}
var _learned: VBoxContainer
var _stats: Array[Label] = []
var _worn := {}
var _spares := {}
var _compare: CheckButton
var _tip: Tooltip


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_deadzone = 10
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	add_child(body)
	_label(body, "穿戴总览 · 七部位", 28, Look.GOLD)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	body.add_child(grid)
	for slot: String in Equipment.SLOTS:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 76
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_inspect.bind(slot))
		grid.add_child(button)
		Look.skin_button(button)
		_slots[slot] = button
	_compare = CheckButton.new()
	_compare.text = "点格子对比库内同部位备用装备"
	body.add_child(_compare)
	_compare.toggled.connect(func(_active: bool) -> void: _refresh_slots())
	_label(body, "已领悟功法 · 等级每局重置", 26, Look.GOLD)
	_learned = VBoxContainer.new()
	_learned.add_theme_constant_override("separation", 3)
	body.add_child(_learned)
	_label(body, "最终属性", 26, Look.GOLD)
	var attributes := GridContainer.new()
	attributes.columns = 2
	attributes.add_theme_constant_override("h_separation", 8)
	attributes.add_theme_constant_override("v_separation", 6)
	body.add_child(attributes)
	for title: String in Stats.PANEL_LABELS:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", Look.box(Look.PANEL, Look.BORDER, 1, 6, 8))
		attributes.add_child(panel)
		var row := HBoxContainer.new()
		panel.add_child(row)
		var caption := _label(row, title, 19, Look.MUTED)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		var value := _label(row, "", 21, Look.CYAN)
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_stats.append(value)


func attach(host: Control) -> void:
	_tip = Tooltip.new()
	host.add_child(_tip)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_tip.close())


func refresh(stats: Stats, worn: Dictionary) -> void:
	_worn = worn
	_spares.clear()
	var storage := SaveManager.storage()
	storage.sort_custom(Equipment.higher_quality)
	for item: Dictionary in storage:
		if not _spares.has(item.slot) and _worn.get(item.slot, {}).get("id", 0) != item.id:
			_spares[item.slot] = item
	_refresh_slots()
	for child: Node in _learned.get_children():
		_learned.remove_child(child)
		child.queue_free()
	for id: String in SaveManager.learned_skills():
		var rule: Dictionary = Catalog.SKILL_DATA[id]
		_label(_learned, "%s · %s　%s" % [rule.name, "入场 Lv1" if id == "sword" else "入场 Lv0", rule.detail], 18, Look.TEXT)
	var values := stats.panel_values()
	for i in range(_stats.size()):
		_stats[i].text = values[i]


func _refresh_slots() -> void:
	for slot: String in _slots:
		var button: Button = _slots[slot]
		var worn: Dictionary = _worn.get(slot, {})
		var info: Dictionary = Equipment.SLOTS[slot]
		var color: Color = Look.MUTED if worn.is_empty() else Equipment.COLORS[worn.quality]
		var name := "空" if worn.is_empty() else "%s·%s" % [Equipment.QUALITIES[worn.quality], info.item]
		button.text = "%s\n%s" % [info.name, name]
		button.disabled = worn.is_empty() and (not _compare.button_pressed or not _spares.has(slot))
		for state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, Look.box(Look.PANEL, color, 2, 7, 5))
		button.add_theme_color_override("font_color", color)


func _inspect(slot: String) -> void:
	var button: Button = _slots[slot]
	var worn: Dictionary = _worn.get(slot, {})
	var spare: Dictionary = _spares.get(slot, {}) if _compare.button_pressed else {}
	var item := worn if spare.is_empty() else spare
	if item.is_empty():
		return
	var anchor := button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, button.size)
	_tip.inspect(item, worn, anchor, {"worn": spare.is_empty(), "hint": "在装备库，可换装、熔炼与升星。"})


func _label(parent: Control, title: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = title
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size_px)
	label.modulate = color
	parent.add_child(label)
	return label
