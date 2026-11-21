extends VBoxContainer

const Equipment = preload("res://scripts/equipment_catalog.gd")
const Look = preload("res://scenes/ui/ui_look.gd")
const CELL_GAP := 8
const IDEAL_CELL := 124.0
const SLOT_INK := {"weapon": Color("#3f787d"), "armor": Color("#8b6944"), "accessory": Color("#654d81")}

signal wear_requested(id: int, equip: bool)
signal salvage_requested(id: int)

enum Mode { STORAGE, BAG, SETTLEMENT }

var _mode := Mode.STORAGE
var _items := {}
var _cells: Dictionary[int, Button] = {}
var _icons := {}
var _worn := {}
var _selected := 0
var _bag_size := 0
var _summary: RichTextLabel
var _detail_title: Label
var _detail: RichTextLabel
var _detail_panel: PanelContainer
var _empty: Label
var _status: Label
var _equip: Button
var _salvage: Button
var _scroll: ScrollContainer
var _list: GridContainer


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_summary = _make_rich_text(self, 23)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 10
	_scroll.follow_focus = true
	_scroll.custom_minimum_size.y = 48
	add_child(_scroll)
	_list = GridContainer.new()
	_list.columns = 4
	_list.add_theme_constant_override("h_separation", CELL_GAP)
	_list.add_theme_constant_override("v_separation", CELL_GAP)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_scroll.resized.connect(_fit_grid)
	for slot: String in SLOT_INK:
		_icons[slot] = Look.swatch(SLOT_INK[slot], Vector2i(24, 16))

	_empty = _make_label(20)
	_empty.text = "点选装备查看属性"
	_empty.modulate = Look.MUTED
	_detail_panel = PanelContainer.new()
	_detail_panel.add_theme_stylebox_override("panel", Look.box(Look.BACKGROUND, Look.BORDER))
	add_child(_detail_panel)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 8)
	_detail_panel.add_child(details)
	_detail_title = Label.new()
	_detail_title.add_theme_font_size_override("font_size", 24)
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_detail_title)
	_detail = _make_rich_text(details, 20)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	details.add_child(row)
	_equip = _make_button(row, "穿戴")
	_equip.pressed.connect(_toggle_equip)
	_salvage = _make_button(row, "分解")
	_salvage.pressed.connect(_salvage_selected)
	_status = _make_label(20)
	_status.modulate = Look.GOLD


func display(mode: Mode, items: Array, worn: Dictionary, storage_count := 0) -> void:
	_mode = mode
	_worn = worn
	_bag_size = items.size()
	var sorted := items.duplicate()
	if mode == Mode.BAG:
		sorted.append_array(worn.values())
	sorted.sort_custom(Equipment.higher_quality)
	_items.clear()
	_cells.clear()
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for item: Dictionary in sorted:
		var id: int = item.id
		_items[id] = item
		var button := _make_button(_list, "%s级\n%s·%s" % [
			Equipment.TIERS[item.tier], Equipment.QUALITIES[item.quality], Equipment.SLOTS[item.slot].item,
		])
		button.add_theme_font_size_override("font_size", 20)
		button.icon = _icons[item.slot]
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		var quality_color: Color = Equipment.COLORS[item.quality]
		for state: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(state, quality_color)
		_cells[id] = button
		_style_cell(id, false)
		if _is_worn(item):
			button.draw.connect(_draw_worn.bind(button))
		button.pressed.connect(_select.bind(id))

	match mode:
		Mode.STORAGE:
			_summary.text = "装备库  [color=#56d4dd]%d/%d[/color]" % [items.size(), Equipment.STORAGE_CAPACITY]
		Mode.BAG:
			_summary.text = "行囊  [color=#56d4dd]%d/%d[/color]" % [items.size(), Equipment.BAG_CAPACITY]
		Mode.SETTLEMENT:
			_summary.text = "还能入库 [color=#56d4dd]%d[/color] 件 · 战利品 [color=#56d4dd]%d[/color] 件" % [Equipment.STORAGE_CAPACITY - storage_count, items.size()]
	if mode != Mode.SETTLEMENT:
		var slots := PackedStringArray()
		for slot: String in Equipment.SLOTS:
			var marker := "[color=#8b949e]空[/color]"
			if worn.has(slot):
				var item: Dictionary = worn[slot]
				marker = "[color=#%s]%s·%s[/color]" % [
					Equipment.COLORS[item.quality].to_html(false), Equipment.TIERS[item.tier], Equipment.QUALITIES[item.quality],
				]
			slots.append("%s %s" % [Equipment.SLOTS[slot].name, marker])
		_summary.text += "\n" + "　".join(slots)
	if mode == Mode.SETTLEMENT:
		show_status("请分解多出的战利品，关闭后重新结算。")
	elif mode == Mode.BAG and _bag_size >= Equipment.BAG_CAPACITY:
		show_status("行囊已满，新装备将自动分解。")
	else:
		show_status("")
	_select(_selected if _items.has(_selected) else 0)
	_fit_grid()


func _fit_grid() -> void:
	var width := _scroll.size.x - _scroll.get_v_scroll_bar().get_combined_minimum_size().x - CELL_GAP
	if width <= 0.0:
		return
	_list.columns = clampi(floori((width + CELL_GAP) / IDEAL_CELL), 4, 6)
	var side := floorf((width - (_list.columns - 1) * CELL_GAP) / _list.columns)
	for button: Button in _cells.values():
		button.custom_minimum_size = Vector2.ONE * side


func _style_cell(id: int, selected: bool) -> void:
	var color: Color = Equipment.COLORS[_items[id].quality]
	var button := _cells[id]
	var fill := Look.PANEL.lerp(color, 0.16 if selected else 0.04)
	button.add_theme_stylebox_override("normal", Look.box(fill, color, 2 if selected else 1, 8, 4))
	button.add_theme_stylebox_override("hover", Look.box(Look.PANEL.lerp(color, 0.22), color, 2, 8, 4))
	var pressed := Look.box(Look.PANEL.lerp(color, 0.30), color, 2, 8, 4)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)


func _draw_worn(button: Button) -> void:
	button.draw_circle(Vector2(12, 12), 5.0, Look.BACKGROUND, true, -1.0, true)
	button.draw_circle(Vector2(12, 12), 3.3, Look.GOLD, true, -1.0, true)


func show_status(message: String) -> void:
	_status.text = message
	_status.visible = not message.is_empty()


func _select(id: int) -> void:
	if _cells.has(_selected):
		_style_cell(_selected, false)
	_selected = id
	var item: Dictionary = _items.get(id, {})
	_empty.visible = item.is_empty()
	_detail_panel.visible = not item.is_empty()
	if not item.is_empty():
		_style_cell(id, true)
		_detail_title.text = Equipment.title(item)
		_detail_title.add_theme_color_override("font_color", Equipment.COLORS[item.quality])
		_detail.text = Equipment.describe(item)
	else:
		_detail.text = ""
	_equip.visible = _mode != Mode.SETTLEMENT
	_equip.disabled = item.is_empty() or (_mode == Mode.BAG and _is_worn(item) and _bag_size >= Equipment.BAG_CAPACITY)
	_equip.text = "卸下" if _is_worn(item) else "穿戴"
	_salvage.visible = _mode != Mode.BAG
	_salvage.disabled = item.is_empty()
	_salvage.text = "分解  +%d 灵石" % Equipment.SALVAGE[item.quality] if not item.is_empty() else "分解"


func _is_worn(item: Dictionary) -> bool:
	return not item.is_empty() and _worn.get(item.slot, {}).get("id", 0) == item.id


func _toggle_equip() -> void:
	if not _equip.disabled:
		wear_requested.emit(_selected, not _is_worn(_items[_selected]))


func _salvage_selected() -> void:
	if not _salvage.disabled:
		salvage_requested.emit(_selected)


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	return label


func _make_rich_text(parent: Control, font_size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", font_size)
	parent.add_child(label)
	return label


func _make_button(parent: Control, title: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 23)
	button.text = title
	parent.add_child(button)
	Look.skin_button(button)
	return button
