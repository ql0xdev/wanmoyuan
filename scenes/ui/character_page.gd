extends VBoxContainer

const Catalog = preload("res://scripts/cultivation_catalog.gd")
const Equipment = preload("res://scripts/equipment_catalog.gd")
const Stats = preload("res://scripts/stats_manager.gd")
const Tooltip = preload("res://scenes/ui/equipment_tooltip.gd")
const GearMenu = preload("res://scenes/ui/equipment_menu.gd")
const Look = preload("res://scenes/ui/ui_look.gd")
const Portrait = preload("res://scenes/ui/character_portrait.gd")
const Icons = preload("res://scenes/ui/character_icons.gd")

const LEFT := ["hat", "weapon", "gloves"]
const RIGHT := ["accessory", "armor", "pants"]
const STAT_ORDER := [1, 0, 2, 4, 3, 5, 6, 7]

signal wear_requested(id: int, equip: bool)
signal salvage_requested(id: int)
signal star_requested(id: int)

var _slots := {}
var _slot_icons := {}
var _slot_names := {}
var _stars := {}
var _learned: VBoxContainer
var _stats: Array[Label] = []
var _worn := {}
var _spares := {}
var _skill_ids: Array = []
var _realm_value: Label
var _power_value: Label
var _compare: CheckButton
var _portrait: Portrait
var _sidebar: ScrollContainer
var _status: Label
var _tip: Tooltip
var _gear: GearMenu
var _selected_slot := ""
var _selected_id := 0


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_build_header()
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	columns.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(columns)
	_build_equipment(columns)
	_build_sidebar(columns)


func _build_header() -> void:
	var plaque := _card(self, Color("#14242b"), Color("#756747"), 12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	plaque.add_child(row)
	var realm := VBoxContainer.new()
	realm.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(realm)
	_label(realm, "当 前 境 界", 17, Look.MUTED)
	_realm_value = _label(realm, "", 34, Look.GOLD)
	var power := VBoxContainer.new()
	row.add_child(power)
	_label(power, "攻 击 倍 率", 17, Look.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_power_value = _label(power, "", 34, Look.CYAN)
	_power_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _build_equipment(parent: Control) -> void:
	# Only this column scrolls on a short screen. The attribute rail has its own scroll.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.scroll_deadzone = 10
	scroll.follow_focus = true
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var card := _card(scroll, Color("#101b21"), Color("#345354"), 7)
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.size_flags_vertical = SIZE_EXPAND_FILL
	var deck := VBoxContainer.new()
	deck.add_theme_constant_override("separation", 8)
	card.add_child(deck)
	_label(deck, "七 部 位 · 穿 戴", 20, Look.GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var rig := HBoxContainer.new()
	rig.add_theme_constant_override("separation", 6)
	rig.custom_minimum_size.y = 408
	rig.size_flags_vertical = SIZE_EXPAND_FILL
	deck.add_child(rig)
	rig.add_child(_slot_column(LEFT))
	_portrait = Portrait.new()
	_portrait.size_flags_horizontal = SIZE_EXPAND_FILL
	_portrait.custom_minimum_size.x = 128
	rig.add_child(_portrait)
	rig.add_child(_slot_column(RIGHT))

	var feet := HBoxContainer.new()
	feet.alignment = BoxContainer.ALIGNMENT_CENTER
	deck.add_child(feet)
	_make_slot(feet, "boots")
	_compare = CheckButton.new()
	_compare.text = "对比备用"
	_compare.add_theme_font_size_override("font_size", 20)
	_compare.size_flags_horizontal = SIZE_SHRINK_CENTER
	_compare.tooltip_text = "优先查看同部位的最佳备用装备，并和当前穿戴对比。"
	_compare.toggled.connect(func(_active: bool) -> void: _refresh_compare_style())
	deck.add_child(_compare)
	_status = _label(deck, "", 17, Look.MUTED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 28
	_status.text = "点装备格查看详情"
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_status.text = "点装备格查看详情")


func _slot_column(ids: Array) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	# Reserve the same width on both sides so the portrait and boots share an axis.
	for id: String in ids:
		_make_slot(column, id).size_flags_vertical = SIZE_EXPAND_FILL
	return column


func _make_slot(parent: Control, slot: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(98, 104)
	button.pressed.connect(_inspect.bind(slot))
	parent.add_child(button)
	Look.skin_button(button)
	_slots[slot] = button

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 6)
	stack.mouse_filter = MOUSE_FILTER_IGNORE
	button.add_child(stack)
	stack.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	stack.offset_top = 16
	var icon := TextureRect.new()
	icon.texture = Icons.slot(slot)
	icon.custom_minimum_size = Vector2(38, 38)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	stack.add_child(icon)
	_slot_icons[slot] = icon
	var caption := _label(stack, "", 17, Look.MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_names[slot] = caption

	var stars := _label(button, "", 15, Look.GOLD)
	stars.position = Vector2(7, 5)
	_stars[slot] = stars
	return button


func _build_sidebar(parent: Control) -> void:
	var card := _card(parent, Color("#131c25"), Color("#324450"), 9)
	card.custom_minimum_size.x = 220
	_sidebar = ScrollContainer.new()
	_sidebar.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sidebar.scroll_deadzone = 10
	_sidebar.follow_focus = true
	card.add_child(_sidebar)
	var rail := VBoxContainer.new()
	rail.size_flags_horizontal = SIZE_EXPAND_FILL
	rail.add_theme_constant_override("separation", 7)
	_sidebar.add_child(rail)
	_label(rail, "最 终 属 性", 22, Look.GOLD)
	_stats.resize(Stats.PANEL_LABELS.size())
	for i: int in STAT_ORDER:
		var panel := _card(rail, Color("#1a252e"), Color("#293d47"), 5)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		panel.add_child(row)
		var caption := _label(row, Stats.PANEL_LABELS[i], 15, Look.MUTED)
		caption.size_flags_horizontal = SIZE_EXPAND_FILL
		var value := _label(row, "", 18, Look.CYAN)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_stats[i] = value
	rail.add_child(HSeparator.new())
	_label(rail, "已 领 悟 功 法", 20, Look.GOLD)
	_label(rail, "等级每局重置", 15, Look.MUTED)
	_learned = VBoxContainer.new()
	_learned.add_theme_constant_override("separation", 6)
	rail.add_child(_learned)


func attach(host: Control, storage: GearMenu) -> void:
	_gear = storage
	_tip = Tooltip.new()
	host.add_child(_tip)
	_tip.wear_requested.connect(func() -> void:
		if _selected_id > 0:
			var worn: Dictionary = _worn.get(_selected_slot, {})
			wear_requested.emit(_selected_id, worn.get("id", 0) != _selected_id))
	_tip.salvage_requested.connect(func() -> void:
		if _selected_id > 0:
			salvage_requested.emit(_selected_id))
	_tip.star_requested.connect(func() -> void:
		if _selected_id > 0:
			star_requested.emit(_selected_id))
	_tip.dismissed.connect(func() -> void:
		_selected_slot = ""
		_selected_id = 0)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_tip.close())


func refresh(stats: Stats, worn: Dictionary) -> void:
	_worn = worn
	_spares.clear()
	var storage := SaveManager.storage()
	storage.sort_custom(Equipment.higher_quality)
	var retained := {}
	for item: Dictionary in storage:
		if not _spares.has(item.slot) and _worn.get(item.slot, {}).get("id", 0) != item.id:
			_spares[item.slot] = item
		if item.id == _selected_id:
			retained = item
	_refresh_slots()
	_refresh_skills()
	var values := stats.panel_values()
	_realm_value.text = SaveManager.realm_name()
	_power_value.text = values[1]
	for i in range(_stats.size()):
		_stats[i].text = values[i]
	if _tip != null and _tip.visible:
		if retained.is_empty():
			_tip.close()
		else:
			_show_item(retained)


func _refresh_skills() -> void:
	var ids := SaveManager.learned_skills()
	if ids == _skill_ids:
		return
	_skill_ids = ids
	for child: Node in _learned.get_children():
		_learned.remove_child(child)
		child.queue_free()
	for id: String in ids:
		var rule: Dictionary = Catalog.SKILL_DATA[id]
		var ink := Look.CYAN if rule.attack else Look.GOLD
		var panel := _card(_learned, Color("#1a252e"), Color("#293d47"), 6)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 3)
		panel.add_child(info)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		info.add_child(row)
		var icon := TextureRect.new()
		icon.texture = Icons.skill(id)
		icon.modulate = ink
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(22, 22)
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var title := _label(row, rule.name, 17, Look.TEXT)
		title.size_flags_horizontal = SIZE_EXPAND_FILL
		_label(row, "Lv1" if id == "sword" else "Lv0", 14, ink)
		var detail := _label(info, rule.detail, 16, Look.MUTED)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _refresh_slots() -> void:
	for slot: String in _slots:
		var button: Button = _slots[slot]
		var worn: Dictionary = _worn.get(slot, {})
		var info: Dictionary = Equipment.SLOTS[slot]
		var empty := worn.is_empty()
		var edge := Color("#43505a") if empty else Equipment.COLORS[worn.quality] as Color
		var ink := Look.MUTED if empty else edge.lightened(0.29)
		_slot_names[slot].text = info.name if empty else "%s·%s" % [Equipment.TIERS[worn.tier], info.item]
		_slot_names[slot].add_theme_color_override("font_color", ink)
		_slot_icons[slot].modulate = ink
		_stars[slot].text = "" if empty else "★".repeat(worn.star) + "☆".repeat(5 - worn.star)
		button.disabled = empty and not _spares.has(slot)
		button.tooltip_text = info.name if empty else Equipment.title(worn)
		button.add_theme_stylebox_override("normal", Look.box(Look.PANEL.lerp(edge, 0.08), edge, 2, 8, 0))
		button.add_theme_stylebox_override("hover", Look.box(Look.PANEL.lerp(edge, 0.18), edge.lightened(0.30), 2, 8, 0))
		button.add_theme_stylebox_override("pressed", Look.box(Look.PANEL.lerp(edge, 0.27), edge, 2, 8, 0))
		button.add_theme_stylebox_override("disabled", Look.box(Color("#172128"), edge, 1, 8, 0))
	_refresh_compare_style()


func _refresh_compare_style() -> void:
	_compare.self_modulate = Look.CYAN if _compare.button_pressed else Look.TEXT


func _inspect(slot: String) -> void:
	var worn: Dictionary = _worn.get(slot, {})
	var spare: Dictionary = _spares.get(slot, {})
	var item := spare if worn.is_empty() or (_compare.button_pressed and not spare.is_empty()) else worn
	if item.is_empty():
		return
	_selected_slot = slot
	_selected_id = item.id
	_show_item(item)


func _show_item(item: Dictionary) -> void:
	var button: Button = _slots[_selected_slot]
	var anchor := button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, button.size)
	var worn: Dictionary = _worn.get(_selected_slot, {})
	_tip.inspect(item, worn, anchor, _gear.actions_for(item))


func show_status(text: String) -> void:
	_status.text = text


func _label(parent: Control, title: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = title
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _card(parent: Control, fill: Color, edge: Color, padding: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Look.box(fill, edge, 1, 10, padding))
	parent.add_child(panel)
	return panel
