extends VBoxContainer

const Equipment = preload("res://scripts/equipment_catalog.gd")
const Tooltip = preload("res://scenes/ui/equipment_tooltip.gd")
const Look = preload("res://scenes/ui/ui_look.gd")

signal purchased

var _stock: VBoxContainer
var _balance: Label
var _status: Label
var _offers := {}
var _tip: Tooltip


func _ready() -> void:
	add_theme_constant_override("separation", 9)
	_label(self, "洞府商店 · 只买不卖", 28, Look.GOLD)
	_balance = _label(self, "", 22, Look.CYAN)
	_label(self, "每次从秘境返回刷新六件 · 装备可在熔炉分解", 20, Look.MUTED)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 10
	add_child(scroll)
	_stock = VBoxContainer.new()
	_stock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stock.add_theme_constant_override("separation", 8)
	scroll.add_child(_stock)
	_status = _label(self, "", 20, Look.GOLD)
	_status.hide()


func attach(host: Control) -> void:
	_tip = Tooltip.new()
	host.add_child(_tip)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_tip.close())


func refresh() -> void:
	var stones := SaveManager.spirit_stones()
	_balance.text = "持有灵石 %d　·　装备库 %d/%d" % [stones, SaveManager.equipment_count(), Equipment.STORAGE_CAPACITY]
	for child: Node in _stock.get_children():
		_stock.remove_child(child)
		child.queue_free()
	_offers.clear()
	var offers := SaveManager.shop_items()
	if offers.is_empty():
		_label(_stock, "尚未上货，下一次从秘境返回时刷新。", 21, Look.MUTED)
	for offer: Dictionary in offers:
		var item: Dictionary = offer.item
		var ink: Color = Equipment.COLORS[item.quality]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_stock.add_child(row)
		var info := _button(row, "%s\n%s" % [Equipment.title(item), "已售出" if offer.sold else "查看属性"], 20)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_color_override("font_color", ink if not offer.sold else Look.MUTED)
		info.pressed.connect(_inspect.bind(offer, info))
		var buy := _button(row, "已售出" if offer.sold else "买 · %d" % offer.price, 22)
		buy.custom_minimum_size.x = 142
		buy.disabled = offer.sold or offer.price > stones or SaveManager.equipment_count() >= Equipment.STORAGE_CAPACITY
		buy.pressed.connect(_buy.bind(offer.id))
		_offers[offer.id] = {"buy": buy, "info": info}


func _inspect(offer: Dictionary, button: Button) -> void:
	var item: Dictionary = offer.item.duplicate(true)
	item.id = -offer.id
	var worn: Dictionary = SaveManager.equipped_items().get(item.slot, {})
	var anchor := button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, button.size)
	_tip.inspect(item, worn, anchor, {"hint": "已售出" if offer.sold else "售价 %d 灵石" % offer.price})


func _buy(id: int) -> void:
	var result := SaveManager.buy_shop_item(id)
	_status.text = "购买成功，装备已入库。" if result == OK else "未能购买，灵石未扣除。"
	_status.show()
	if result == OK:
		purchased.emit()
	else:
		refresh()


func _label(parent: Control, text: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate = tint
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Control, text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 65
	button.add_theme_font_size_override("font_size", font_size)
	parent.add_child(button)
	Look.skin_button(button)
	return button
