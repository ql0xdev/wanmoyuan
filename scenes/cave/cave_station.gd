extends StaticBody2D

const Ink = preload("res://scenes/world/ink.gd")
const Look = preload("res://scenes/ui/ui_look.gd")

signal activated

enum Kind { MAT, PILLAR, CHEST, FORGE, MIRROR, SHOP, PORTAL }
const LABELS := ["蒲团 · 修行", "功法柱 · 功法", "宝箱 · 行囊", "熔炉 · 熔炉", "铜镜 · 角色", "货架 · 商店", "传送阵 · 秘境准备"]
const COLORS := [
	Color("#63dcb0"), Color("#f2c56e"), Color("#db984e"), Color("#ff8655"),
	Color("#7bc3ff"), Color("#c58bfa"), Color("#54e5e1"),
]
const RADII := [35.0, 32.0, 39.0, 40.0, 34.0, 46.0, 52.0]
const BUBBLE_WIDTH := 210.0

var bubble: Button
var hit_target: Button
var _kind: Kind
var _tint: Color
var _near := false
var _phase := 0.0


func configure(id: Kind, at: Vector2) -> void:
	_kind = id
	_tint = COLORS[id]
	position = at


func _ready() -> void:
	var collider := CollisionShape2D.new()
	var footprint := CircleShape2D.new()
	footprint.radius = RADII[_kind]
	collider.shape = footprint
	add_child(collider)
	var hit_size := maxf(48.0, footprint.radius)
	hit_target = _make_target(Rect2(-hit_size, -hit_size - 19.0, hit_size * 2.0, hit_size * 2.0 + 19.0))
	hit_target.flat = true
	var bubble_y := -146.0 if _kind == Kind.PORTAL else -126.0
	bubble = _make_target(Rect2(-BUBBLE_WIDTH * 0.5, bubble_y, BUBBLE_WIDTH, 45))
	bubble.text = LABELS[_kind]
	bubble.add_theme_font_size_override("font_size", 22)
	bubble.add_theme_color_override("font_color", _tint.lightened(0.38))
	bubble.add_theme_stylebox_override("normal", Look.box(Color("#101c26"), _tint, 2, 10, 4))
	bubble.add_theme_stylebox_override("hover", Look.box(Color("#1f323c"), _tint.lightened(0.38), 2, 10, 4))
	bubble.add_theme_stylebox_override("pressed", Look.box(Color("#233d45"), _tint, 2, 10, 4))
	bubble.z_index = 20
	set_process(_kind in [Kind.MAT, Kind.PILLAR, Kind.FORGE, Kind.PORTAL])


func _make_target(rect: Rect2) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.hide()
	add_child(button)
	button.pressed.connect(func() -> void: activated.emit())
	return button


func set_near(near: bool) -> void:
	if near == _near:
		return
	_near = near
	bubble.visible = near
	hit_target.visible = near
	queue_redraw()


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta, TAU * 16.0)
	queue_redraw()


func _draw() -> void:
	var r: float = RADII[_kind]
	var breathe := 0.73 + 0.21 * sin(_phase * 2.0) if _kind == Kind.MAT else 0.82
	for halo in [25, 16, 7]:
		draw_circle(Vector2.ZERO, r + halo, Ink.alpha(_tint, 0.035 * breathe), true, -1.0, true)
	draw_circle(Vector2(0, 4), r + 6.0, Color("#0d141d"), true, -1.0, true)
	Ink.ring(self, Vector2.ZERO, r + 5.0, Ink.alpha(_tint, 0.82 if _near else 0.38), 1.8)
	match _kind:
		Kind.MAT: _draw_mat(breathe)
		Kind.PILLAR: _draw_pillar()
		Kind.CHEST: _draw_chest()
		Kind.FORGE: _draw_forge()
		Kind.MIRROR: _draw_mirror()
		Kind.SHOP: _draw_shop()
		Kind.PORTAL: _draw_portal()
	if _near:
		Ink.diamond(self, Vector2(0, -97 if _kind == Kind.PORTAL else -77), Vector2(5, 5), _tint, _tint)


func _draw_mat(breathe: float) -> void:
	draw_circle(Vector2.ZERO, 33.0, Color("#22534f"), true, -1.0, true)
	Ink.ring(self, Vector2.ZERO, 31, Ink.alpha(_tint, breathe))
	Ink.ring(self, Vector2.ZERO, 24, Ink.alpha(_tint, 0.49), 1.2)
	for i in range(12):
		var ray := Vector2.from_angle(i * TAU / 12.0)
		draw_line(ray * 25, ray * 28, _tint, 1.3, true)
	Ink.diamond(self, Vector2.ZERO, Vector2(10, 14), Color("#276b63"), Ink.alpha(_tint, breathe))


func _draw_pillar() -> void:
	_plate(Rect2(-27, 7, 54, 19), Color("#4e463e"), _tint)
	Ink.polygon(self, PackedVector2Array([Vector2(-19, 17), Vector2(-15, -51), Vector2(15, -51), Vector2(19, 17)]),
		Color("#655034"), _tint)
	draw_line(Vector2(-8, 12), Vector2(-8, -44), Color("#a67d44"), 2.0, true)
	Ink.diamond(self, Vector2(0, -50), Vector2(19, 9), Color("#b08147"), _tint)
	for i in range(3):
		var at := Vector2(5.0 + sin(_phase * 1.5 + i) * 6.0, -7.0 - i * 13.0 + sin(_phase * 1.25 + i) * 4.0)
		Ink.diamond(self, at, Vector2(6, 4), _tint, _tint.lightened(0.35))


func _draw_chest() -> void:
	var gold := Color("#ebbb71")
	_plate(Rect2(-37, -12, 74, 36), Color("#58362c"), gold)
	Ink.polygon(self, PackedVector2Array([Vector2(-37, -12), Vector2(-29, -32), Vector2(29, -32), Vector2(37, -12),
		Vector2(37, 0), Vector2(-37, 0)]), Color("#9a5f37"), gold)
	for x in [-25, 25]:
		draw_line(Vector2(x, -31), Vector2(x, 23), gold, 3.0, true)
	_plate(Rect2(-7, -6, 14, 14), Color("#352515"), gold)
	draw_circle(Vector2.ZERO, 2.0, gold)


func _draw_forge() -> void:
	Ink.polygon(self, PackedVector2Array([Vector2(-40, 20), Vector2(-34, -19), Vector2(-21, -37), Vector2(22, -37),
		Vector2(35, -19), Vector2(40, 20)]), Color("#523832"), _tint, 2.5)
	_plate(Rect2(-24, -13, 48, 30), Color("#4d1f21"), Color("#e76c48"))
	Ink.polygon(self, PackedVector2Array([Vector2(-18, 12), Vector2(-11, -1), Vector2(-3, 6), Vector2(5, -9),
		Vector2(15, 1), Vector2(19, 12)]), Color("#e5663f"), Color("#ffc87d"))
	for i in range(7):
		var travel := fposmod(_phase * 0.875 + float(i) / 7.0, 1.0)
		var at := Vector2(sin(i * 6.3 + travel * 5.0) * (7.0 + travel * 20.0), -5 - travel * 64)
		draw_circle(at, 3.5 - travel * 2.4, Ink.alpha(_tint.lightened(0.53), 1.0 - travel), true, -1.0, true)


func _draw_mirror() -> void:
	_plate(Rect2(-24, 13, 48, 12), Color("#344554"), Color("#b1936a"))
	draw_set_transform(Vector2(0, -18), 0.0, Vector2(0.84, 1.15))
	draw_circle(Vector2.ZERO, 34, Color("#594c40"), true, -1.0, true)
	draw_circle(Vector2.ZERO, 29, Color("#2c5a76"), true, -1.0, true)
	Ink.ring(self, Vector2.ZERO, 32, Color("#b79c70"), 2.3)
	Ink.ring(self, Vector2.ZERO, 27, _tint, 1.0)
	draw_line(Vector2(-16, 7), Vector2(6, -15), Ink.alpha(_tint, 0.65), 3.0, true)
	draw_line(Vector2(-10, 15), Vector2(13, -8), Ink.alpha(_tint, 0.40), 1.6, true)
	draw_set_transform(Vector2.ZERO)


func _draw_shop() -> void:
	_plate(Rect2(-43, -15, 86, 38), Color("#483052"), _tint)
	_plate(Rect2(-38, -6, 76, 19), Color("#5e4466"), Color("#8c6d9c"))
	for i in range(4):
		Ink.diamond(self, Vector2(-25 + i * 17, 4), Vector2(5, 6), Color("#694f85"), _tint)
	Ink.polygon(self, PackedVector2Array([Vector2(-48, -19), Vector2(-36, -48), Vector2(36, -48), Vector2(48, -19)]),
		Color("#74499a"), _tint, 2.0)
	for x in [-27, -9, 9, 27]:
		draw_line(Vector2(x, -46), Vector2(x * 1.27, -21), Color("#bd81dc"), 5.0, true)


func _draw_portal() -> void:
	draw_circle(Vector2.ZERO, 51, Color("#153c43"), true, -1.0, true)
	Ink.ring(self, Vector2.ZERO, 49, Ink.alpha(_tint, 0.85), 2.4)
	Ink.ring(self, Vector2.ZERO, 39, Ink.alpha(_tint, 0.48), 1.4)
	for i in range(8):
		var angle := _phase * 0.5 + i * TAU / 8.0
		Ink.diamond(self, Vector2.from_angle(angle) * 46.0, Vector2(4, 4), _tint, _tint)
	for i in range(3):
		var arc := PackedVector2Array()
		for step in range(25):
			var t := float(step) / 24.0
			arc.append(Vector2.from_angle(_phase * 1.25 + t * 3.1 + i * TAU / 3.0) * lerpf(7, 36, t))
		draw_polyline(arc, Ink.alpha(_tint, 0.21), 7.0, true)
		draw_polyline(arc, _tint, 2.2, true)
	draw_circle(Vector2.ZERO, 4, Color("#d6fff7"), true, -1.0, true)


func _plate(rect: Rect2, fill: Color, edge: Color) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, edge, false, 2.0)
