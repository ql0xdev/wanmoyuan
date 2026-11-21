extends Control

const Catalog = preload("res://scripts/artifact_catalog.gd")
const Inventory = preload("res://scripts/artifact_inventory.gd")
const FILLED_SLOT := Color("#223b39")
const EMPTY_SLOT := Color("#152429")

signal close_requested
signal purchase_requested(id: StringName)

@onready var _balance_label: Label = $Panel/Margin/Content/Header/Balance
@onready var _scroll: ScrollContainer = $Panel/Margin/Content/Products
@onready var _products: VBoxContainer = $Panel/Margin/Content/Products/List
@onready var _slots: GridContainer = $Panel/Margin/Content/Slots
@onready var _inventory_title: Label = $Panel/Margin/Content/InventoryTitle
@onready var _status: Label = $Panel/Margin/Content/Status

var _owned_labels: Dictionary[StringName, Label] = {}
var _buttons: Dictionary[StringName, Button] = {}
var _slot_colors: Array[ColorRect] = []
var _slot_labels: Array[Label] = []
var _slot_flashes: Dictionary[int, Tween] = {}


func _ready() -> void:
	for id: StringName in Catalog.ITEMS:
		_add_product(id)
	for i in range(Inventory.CAPACITY):
		var slot := ColorRect.new()
		slot.custom_minimum_size = Vector2(0, 50)
		slot.size_flags_horizontal = SIZE_EXPAND_FILL
		slot.mouse_filter = MOUSE_FILTER_IGNORE
		_slots.add_child(slot)
		var title := _label(23)
		slot.add_child(title)
		title.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_slot_colors.append(slot)
		_slot_labels.append(title)


func open(inventory: Inventory, balance: int) -> void:
	refresh(inventory, balance)
	_status.text = "法宝栏已满" if inventory.count(&"") == 0 else " "
	show()
	_scroll.set_deferred("scroll_vertical", 0)


func refresh(inventory: Inventory, balance: int) -> void:
	_balance_label.text = "灵石 %d" % balance
	var used := Inventory.CAPACITY - inventory.count(&"")
	_inventory_title.text = "法宝栏　%d / %d" % [used, Inventory.CAPACITY]
	for id: StringName in Catalog.ITEMS:
		var stock := inventory.count(id)
		_owned_labels[id].text = "持有 %d" % stock
		var offer := inventory.offer(id, balance)
		var button := _buttons[id]
		button.disabled = not offer.reason.is_empty()
		if button.disabled:
			button.text = offer.reason
		elif not Catalog.ITEMS[id].has("recipe"):
			button.text = "购买"
		else:
			button.text = "合成" if offer.cost == 0 else "补 %d 合成" % offer.cost
	for i in range(Inventory.CAPACITY):
		var id := inventory.slots[i]
		_slot_labels[i].text = "空" if id == &"" else Catalog.ITEMS[id].name
		_slot_labels[i].add_theme_color_override(
			"font_color", Color("#97a5a6") if id == &"" else Catalog.ITEMS[id].color
		)
		if id == &"" and _slot_flashes.has(i):
			_slot_flashes[i].kill()
			_slot_flashes.erase(i)
		if not _slot_flashes.has(i):
			_slot_colors[i].color = EMPTY_SLOT if id == &"" else FILLED_SLOT


func show_status(text: String) -> void:
	_status.text = text


func show_success(id: StringName, slot: int, cost: int, full: bool) -> void:
	var item: Dictionary = Catalog.ITEMS[id]
	var action := "合成" if item.has("recipe") else "购买"
	_status.text = "%s成功：%s" % [action, item.name]
	if cost > 0:
		_status.text += "　灵石 -%d" % cost
	if full:
		_status.text += "　法宝栏已满"
	if _slot_flashes.has(slot):
		_slot_flashes[slot].kill()
	var cell := _slot_colors[slot]
	cell.color = Color("#a7742f")
	var tween := create_tween()
	_slot_flashes[slot] = tween
	tween.tween_property(cell, "color", FILLED_SLOT, 0.35)
	tween.tween_callback(_finish_slot_flash.bind(slot))


func _finish_slot_flash(slot: int) -> void:
	_slot_flashes.erase(slot)


func _add_product(id: StringName) -> void:
	var item: Dictionary = Catalog.ITEMS[id]
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 84
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	_products.add_child(row)

	var icon := ColorRect.new()
	icon.color = item.color
	icon.custom_minimum_size = Vector2(34, 34)
	icon.size_flags_vertical = SIZE_SHRINK_CENTER
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = SIZE_EXPAND_FILL
	details.size_flags_vertical = SIZE_SHRINK_CENTER
	details.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(details)
	var title := _label(24)
	title.text = "%s　%d 灵石" % [item.name, Catalog.price(id)]
	details.add_child(title)
	var effect := _label(21)
	effect.text = item.effect
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(effect)
	if item.has("recipe"):
		var recipe := _label(19)
		recipe.text = "配方：%s" % Catalog.recipe_text(id)
		recipe.add_theme_color_override("font_color", Color("#a4b7b6"))
		details.add_child(recipe)

	var actions := VBoxContainer.new()
	actions.size_flags_vertical = SIZE_SHRINK_CENTER
	actions.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(actions)
	var owned := _label(19)
	owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	actions.add_child(owned)
	_owned_labels[id] = owned
	var button := Button.new()
	button.custom_minimum_size = Vector2(140, 48)
	button.focus_mode = FOCUS_NONE
	button.mouse_filter = MOUSE_FILTER_PASS
	button.add_theme_font_size_override("font_size", 21)
	button.pressed.connect(purchase_requested.emit.bind(id))
	actions.add_child(button)
	_buttons[id] = button


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	return label


func _close() -> void:
	close_requested.emit()
