extends Control

const Look = preload("res://scenes/ui/ui_look.gd")

@export var emblem := false
var ornament_offset := Vector2.ZERO:
	set(value):
		ornament_offset = value
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Look.BACKGROUND)
	draw_set_transform(ornament_offset)
	var center := Vector2(size.x * 0.5, size.y * (0.39 if emblem else 0.14))
	var radius := minf(size.x * 0.42, 320.0)
	var gold := Color(Look.GOLD, 0.25 if emblem else 0.10)
	var jade := Color(Look.CYAN, 0.18 if emblem else 0.09)
	for i in range(10, 0, -1):
		draw_circle(center, radius * i * 0.14, Color(Look.CYAN, 0.012))
	for factor: float in [0.58, 0.83, 1.0]:
		draw_arc(center, maxf(1.0, radius * factor), 0.0, TAU, 72, jade, 1.0, true)
	for i in range(16):
		var axis := Vector2.from_angle(TAU * i / 16.0)
		draw_line(center + axis * radius * 0.86, center + axis * radius * 0.95, gold, 1.0, true)
	var inset := 24.0
	draw_rect(Rect2(Vector2.ONE * inset, (size - Vector2.ONE * inset * 2.0).max(Vector2.ZERO)), gold, false)
	for y: float in [inset, size.y - inset]:
		for x: float in [inset, size.x - inset]:
			var at := Vector2(x, y)
			draw_circle(at, 3.0, gold, true, -1.0, true)
