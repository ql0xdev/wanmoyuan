extends Node2D

const Ink = preload("res://scenes/world/ink.gd")
var _radius := 0.0
var _seconds := 0.0


func display(radius: float, seconds: float) -> void:
	_radius = radius
	_seconds = seconds
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius, Color("#a9482633"), true, -1, true)
	Ink.ring(self, Vector2.ZERO, _radius, Color("#ff9967b5"), 3.0)
	for i in range(14):
		var angle := TAU * i / 14.0
		var ray := Vector2.from_angle(angle)
		var at := ray * _radius
		var tip := at - ray * (10.0 + 9.0 * (0.5 + 0.5 * sin(_seconds * 10.0 + i * 2.4)))
		draw_colored_polygon(PackedVector2Array([at + ray.orthogonal() * 5.0, tip, at - ray.orthogonal() * 5.0]), Color("#ffc178d7"))
