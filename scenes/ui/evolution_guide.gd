extends VBoxContainer

const Catalog = preload("res://scripts/cultivation_catalog.gd")
const Look = preload("res://scenes/ui/ui_look.gd")

var _cards := {}


func refresh(table := Catalog.EVOLUTIONS) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_cards.clear()
	_label(self, "全部配方公开 · 局内完成进化后点亮", 21, Look.MUTED)
	for id: String in table:
		var rule: Dictionary = table[id]
		var reached := SaveManager.has_evolved(id)
		var ink := Look.GOLD if reached else Look.MUTED
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", Look.box(Look.PANEL, ink, 1, 8, 10))
		add_child(panel)
		var lines := VBoxContainer.new()
		panel.add_child(lines)
		_label(lines, "%s　·　%s" % [rule.name, "已达成" if reached else "未达成"], 25, ink)
		var recipe := _label(lines, Catalog.evolution_recipe(id, table), 22, ink)
		_label(lines, str(rule.card).replace("\n", " · "), 20, Look.TEXT if reached else Look.MUTED)
		_cards[id] = {"panel": panel, "recipe": recipe, "reached": reached}


func _label(parent: Control, text: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate = tint
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
