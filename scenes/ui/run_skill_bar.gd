extends HBoxContainer

const Catalog = preload("res://scripts/cultivation_catalog.gd")
const Look = preload("res://scenes/ui/ui_look.gd")
const MARKS := {
	"sword": "剑", "lightning": "雷", "orbs": "罡", "ice": "冰", "heal": "春", "sword_storm": "万",
	"fire": "火", "blink": "瞬", "dash": "影", "wisp": "焰", "bell": "铃", "shield": "盾",
}
const COLORS := ["7de7d2", "a9bcff", "ff995d", "81dcfb", "8ee89b", "b9e5d9",
	"ffa47b", "c3c7f6", "b5f5e6", "d9a0f0", "ddbbf7", "8cf5cb"]

var _slots: Array[PanelContainer] = []
var _icons: Array[Label] = []
var _ranks: Array[Label] = []
var _empty := Look.box(Color("#0d1117cf"), Look.BORDER, 1, 8, 2)
var _active := Look.box(Color("#162e31eb"), Color("#549a98"), 2, 8, 2)
var _gold := Look.box(Color("#342915f5"), Look.GOLD, 2, 8, 2)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	for i in range(Catalog.RUN_SKILL_SLOTS):
		var box := PanelContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.custom_minimum_size = Vector2(47, 52)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(box)
		_slots.append(box)
		var face := Control.new()
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(face)
		var icon := _make_label(face, 26, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
		icon.offset_left = 4
		var rank := _make_label(face, 15, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM)
		rank.offset_right = -2
		_icons.append(icon)
		_ranks.append(rank)
	display([])


func display(skills: Array[Dictionary]) -> void:
	for i in range(_slots.size()):
		var box := _slots[i]
		var info := skills[i] if i < skills.size() else {}
		var level: int = info.get("level", 0)
		var capped := level >= Catalog.RUN_SKILL_CAP
		box.add_theme_stylebox_override("panel", _gold if capped else (_active if level > 0 else _empty))
		if level > 0:
			var id: String = info.id
			_icons[i].text = "✦" if info.evolved else MARKS[id]
			_icons[i].modulate = Look.GOLD if info.evolved else Color.html(COLORS[Catalog.SKILLS.find(id)])
			_ranks[i].text = "Lv%d" % level
			_ranks[i].modulate = Look.GOLD if capped else Look.TEXT
			box.tooltip_text = "%s Lv%d" % [info.name, level]
		else:
			_icons[i].text = ""
			_ranks[i].text = ""
			box.tooltip_text = ""


func _make_label(parent: Control, font_size: int, alignment: int, vertical: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.vertical_alignment = vertical
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return label
