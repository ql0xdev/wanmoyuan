extends Control

const Pills = preload("res://scripts/pill_catalog.gd")
const Stats = preload("res://scripts/stats_manager.gd")
const Look = preload("res://scenes/ui/ui_look.gd")

signal close_requested
signal purchase_requested(id: String)

@onready var _balance: Label = $Panel/Margin/Content/Header/Balance
@onready var _products: VBoxContainer = $Panel/Margin/Content/Products/List
@onready var _status: Label = $Panel/Margin/Content/Status

var _buttons := {}


func _ready() -> void:
	Look.animate_panel(self, $Panel)
	var tile := Look.box(Look.BACKGROUND, Look.BORDER)
	for id: String in Pills.ITEMS:
		var pill: Dictionary = Pills.ITEMS[id]
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", tile)
		_products.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		panel.add_child(row)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		var title := Label.new()
		title.text = pill.name
		title.add_theme_font_size_override("font_size", 26)
		details.add_child(title)
		var cost := Label.new()
		cost.text = "%d 灵石" % pill.cost
		cost.modulate = Look.CYAN
		details.add_child(cost)
		var description := Label.new()
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.text = pill.detail
		description.modulate = Look.MUTED
		details.add_child(description)
		var button := Button.new()
		button.custom_minimum_size = Vector2(158, 54)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", 24)
		button.pressed.connect(purchase_requested.emit.bind(id))
		row.add_child(button)
		_buttons[id] = button


func open(stones: int, health: int, maximum: int, stats: Stats) -> void:
	refresh(stones, health, maximum, stats)
	_status.text = "丹药只在本局生效；剩余灵石可带回洞府。"
	show()


func refresh(stones: int, health: int, maximum: int, stats: Stats) -> void:
	_balance.text = "灵石 %d" % stones
	for id: String in Pills.ITEMS:
		var reason := Pills.unavailable_reason(id, stones, health, maximum, stats.has_pill(id))
		var button: Button = _buttons[id]
		button.disabled = not reason.is_empty()
		button.text = "购买并服用" if reason.is_empty() else reason


func show_status(text: String) -> void:
	_status.text = text


func _close() -> void:
	close_requested.emit()
