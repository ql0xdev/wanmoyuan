extends Control

const Ink = preload("res://scenes/world/ink.gd")
const Look = preload("res://scenes/ui/ui_look.gd")
const PORTRAIT: Texture2D = preload("res://assets/character/portrait.png")

var _image: TextureRect
var _phase := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_image = TextureRect.new()
	_image.texture = PORTRAIT
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_image)
	resized.connect(_arrange)
	visibility_changed.connect(_update_activity)
	_update_activity()
	_arrange()


func _update_activity() -> void:
	set_process(is_visible_in_tree())


func _process(delta: float) -> void:
	_phase = fposmod(_phase + delta * 2.15, TAU)
	var breath := sin(_phase)
	_image.scale = Vector2.ONE * (1.0 + breath * 0.027)
	_image.position.y = (size.y - _image.size.y) * 0.5 - 5.0 + breath * 5.0


func _arrange() -> void:
	_image.size = Vector2(size.x, size.y * 0.90)
	_image.pivot_offset = _image.size * 0.5
	_image.position = (size - _image.size) * 0.5 - Vector2(0, 5)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := size.x * 0.44
	if radius < 1.0:
		return
	var pale := Color("#507a78")
	draw_line(Vector2(center.x, 15), Vector2(center.x, size.y - 15), Ink.alpha(pale, 0.36), 1, true)
	for step in range(2, 8):
		var at := Vector2(center.x, size.y * float(step) / 9.0)
		Ink.diamond(self, at, Vector2(4, 8), Color("#192e31"), Ink.alpha(pale, 0.63))
	for i in range(4, 0, -1):
		draw_circle(center, radius * (0.62 + i * 0.09), Ink.alpha(Ink.JADE, 0.035), true, -1, true)
	Ink.ring(self, center, radius, Ink.alpha(pale, 0.84), 1.4)
	draw_arc(center, radius * 0.75, -0.85, 1.45, 26, Ink.alpha(pale, 0.50), 1, true)
	draw_arc(center, radius * 0.75, 2.29, 4.59, 26, Ink.alpha(pale, 0.50), 1, true)
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		Ink.diamond(self, center + direction * radius, Vector2(4, 4), Look.BACKGROUND, Look.GOLD)
