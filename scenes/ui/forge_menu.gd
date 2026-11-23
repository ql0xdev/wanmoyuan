extends VBoxContainer

const Equipment = preload("res://scripts/equipment_catalog.gd")
const Forge = preload("res://scripts/forge_catalog.gd")
const Cultivation = preload("res://scripts/cultivation_catalog.gd")
const Look = preload("res://scenes/ui/ui_look.gd")
const GearMenu = preload("res://scenes/ui/equipment_menu.gd")

signal crafted
signal masterwork

var gear: GearMenu
var _header: Label
var _tabs: HBoxContainer
var _page := 0
var _workshop: VBoxContainer
var _slot_buttons: GridContainer
var _tiers: GridContainer
var _cost: Label
var _status: Label
var _output: Label
var _craft: Button
var _slot := "weapon"
var _tier := 0


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_header = _label(self, 25, Look.CYAN)
	_tabs = HBoxContainer.new()
	add_child(_tabs)
	for i in range(3):
		_button(_tabs, ["熔炼", "打造", "升星"][i], _switch.bind(i)).toggle_mode = true
	gear = GearMenu.new()
	gear.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(gear)
	_workshop = VBoxContainer.new()
	_workshop.add_theme_constant_override("separation", 12)
	_workshop.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_workshop)
	_label(_workshop, 23, Look.GOLD).text = "选择部位"
	_slot_buttons = GridContainer.new()
	_slot_buttons.columns = 4
	_slot_buttons.add_theme_constant_override("h_separation", 8)
	_slot_buttons.add_theme_constant_override("v_separation", 8)
	_workshop.add_child(_slot_buttons)
	for slot: String in Equipment.SLOTS:
		_button(_slot_buttons, Equipment.SLOTS[slot].name, _choose_slot.bind(slot)).toggle_mode = true
	_label(_workshop, 23, Look.GOLD).text = "选择装备等级"
	_tiers = GridContainer.new()
	_tiers.columns = 2
	_tiers.add_theme_constant_override("h_separation", 8)
	_tiers.add_theme_constant_override("v_separation", 8)
	_workshop.add_child(_tiers)
	for i in range(Equipment.TIERS.size()):
		_button(_tiers, Equipment.TIERS[i] + "级", _choose_tier.bind(i)).toggle_mode = true
	_cost = _label(_workshop, 24, Look.CYAN)
	_craft = _button(_workshop, "确认打造", _forge)
	_status = _label(_workshop, 22, Look.MUTED)
	_output = _label(_workshop, 27, Look.GOLD)
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree() and gear._popup != null:
			refresh())
	_switch(0)


func refresh() -> void:
	_header.text = "玄铁 %d　·　打造熟练度 %s" % [SaveManager.iron(), Forge.rank_text(SaveManager.forge_count())]
	if _page != 1:
		if not is_visible_in_tree():
			return
		gear.display(GearMenu.Mode.STORAGE, SaveManager.storage(), SaveManager.equipped_items(), 0, SaveManager.iron())
		gear.show_status("点选装备，在浮窗中分解为灵石和玄铁。" if _page == 0 else "点选装备，在浮窗中使用玄铁与同部位祭品升星。")
		return
	var rank: int = Cultivation.REALMS[SaveManager.realm()].rank
	for i in range(_slot_buttons.get_child_count()):
		_slot_buttons.get_child(i).set_pressed_no_signal(Equipment.SLOTS.keys()[i] == _slot)
	for i in range(_tiers.get_child_count()):
		var button: Button = _tiers.get_child(i)
		button.disabled = i > rank
		button.text = Equipment.TIERS[i] + ("级 · 境界未达" if i > rank else "级")
		button.set_pressed_no_signal(i == _tier)
	var cost: Vector2i = Forge.COSTS[_tier]
	_cost.text = "需玄铁 %d（持有 %d）\n需灵石 %d（持有 %d）" % [cost.x, SaveManager.iron(), cost.y, SaveManager.spirit_stones()]
	_craft.disabled = _tier > rank or SaveManager.equipment_count() >= Equipment.STORAGE_CAPACITY \
		or SaveManager.iron() < cost.x or SaveManager.spirit_stones() < cost.y
	_status.text = "装备库已满，请先熔炼。" if SaveManager.equipment_count() >= Equipment.STORAGE_CAPACITY else "装备存入装备库；品质按当前熟练度随机。"


func _switch(page: int) -> void:
	_page = page
	for i in range(_tabs.get_child_count()):
		_tabs.get_child(i).set_pressed_no_signal(i == page)
	gear.visible = page != 1
	_workshop.visible = page == 1
	# 宿主先挂好共用浮窗，之后再刷新装备列表。
	if gear._popup != null:
		refresh()


func _choose_slot(slot: String) -> void:
	_slot = slot
	refresh()


func _choose_tier(tier: int) -> void:
	if not _tiers.get_child(tier).disabled:
		_tier = tier
	refresh()


func _forge() -> void:
	var result := SaveManager.forge_equipment(_slot, _tier)
	if result.error != OK:
		_output.text = "无法打造，材料未扣除。"
		_output.modulate = Look.MUTED
		return
	var item: Dictionary = result.item
	_output.text = "出炉 · %s · 0 星" % Equipment.title(item)
	_output.modulate = Equipment.COLORS[item.quality]
	crafted.emit()
	if result.masterwork:
		masterwork.emit()


func _label(parent: Control, font_size: int, ink: Color) -> Label:
	var label := Label.new()
	label.modulate = ink
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Control, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 58
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 24)
	parent.add_child(button)
	button.pressed.connect(action)
	Look.skin_button(button)
	return button
