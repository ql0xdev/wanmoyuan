extends VBoxContainer

const Equipment = preload("res://scripts/equipment_catalog.gd")

signal wear_requested(id: int, equip: bool)
signal salvage_requested(id: int)

enum Mode { STORAGE, BAG, SETTLEMENT }

var _mode := Mode.STORAGE
var _items := {}
var _worn := {}
var _selected := 0
var _bag_size := 0
var _summary: Label
var _detail: Label
var _status: Label
var _equip: Button
var _salvage: Button
var _list: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_summary = _make_label(23)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 10
	scroll.follow_focus = true
	scroll.custom_minimum_size.y = 40
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_detail = _make_label(21)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	_equip = _make_button(row, "穿戴")
	_equip.pressed.connect(_toggle_equip)
	_salvage = _make_button(row, "分解")
	_salvage.pressed.connect(_salvage_selected)
	_status = _make_label(19)
	_status.modulate = Color("#ffda91")


func display(mode: Mode, items: Array, worn: Dictionary, storage_count := 0) -> void:
	_mode = mode
	_worn = worn
	_bag_size = items.size()
	var sorted := items.duplicate()
	if mode == Mode.BAG:
		sorted.append_array(worn.values())
	sorted.sort_custom(Equipment.higher_quality)
	_items.clear()
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for item: Dictionary in sorted:
		var id: int = item.id
		_items[id] = item
		var button := _make_button(_list, Equipment.title(item) + ("　[穿戴中]" if _is_worn(item) else ""))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_color_override("font_color", Equipment.COLORS[item.quality])
		button.pressed.connect(_select.bind(id))

	match mode:
		Mode.STORAGE:
			_summary.text = "装备库 · %d / %d" % [items.size(), Equipment.STORAGE_CAPACITY]
		Mode.BAG:
			_summary.text = "行囊 · %d / %d" % [items.size(), Equipment.BAG_CAPACITY]
		Mode.SETTLEMENT:
			_summary.text = "还能入库 %d 件 · 战利品 %d 件" % [Equipment.STORAGE_CAPACITY - storage_count, items.size()]
	if mode != Mode.SETTLEMENT:
		var slots := PackedStringArray()
		for slot: String in Equipment.SLOTS:
			var marker := "空"
			if worn.has(slot):
				var item: Dictionary = worn[slot]
				marker = "%s·%s" % [Equipment.TIERS[item.tier], Equipment.QUALITIES[item.quality]]
			slots.append("%s %s" % [Equipment.SLOTS[slot].name, marker])
		_summary.text += "\n" + "　".join(slots)
	if mode == Mode.SETTLEMENT:
		show_status("请分解多出的战利品，关闭后重新结算。")
	elif mode == Mode.BAG and _bag_size >= Equipment.BAG_CAPACITY:
		show_status("行囊已满，新装备将自动分解。")
	else:
		show_status("")
	_select(_selected if _items.has(_selected) else 0)


func show_status(message: String) -> void:
	_status.text = message
	_status.visible = not message.is_empty()


func _select(id: int) -> void:
	_selected = id
	var item: Dictionary = _items.get(id, {})
	_detail.text = "点选装备查看属性" if item.is_empty() else Equipment.describe(item)
	_detail.modulate = Color.WHITE if item.is_empty() else Equipment.COLORS[item.quality]
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


func _make_button(parent: Control, title: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 23)
	button.text = title
	parent.add_child(button)
	return button
