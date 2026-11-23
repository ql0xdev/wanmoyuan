extends StaticBody2D

const Ink = preload("res://scenes/world/ink.gd")
var footprint := Vector2(60, 56)


func _draw() -> void:
	var x := footprint.x * 0.50
	var y := footprint.y * 0.50
	var shape := PackedVector2Array([Vector2(-x, y * 0.52), Vector2(-x * 0.87, -y),
		Vector2(-x * 0.46, -y - 18), Vector2(x * 0.45, -y - 23), Vector2(x, -y * 0.30),
		Vector2(x * 0.96, y * 0.65), Vector2(x * 0.36, y), Vector2(-x * 0.48, y)])
	draw_rect(Rect2(-x + 4.0, -y + 7.0, x * 2.0, y * 2.0), Color("#070a10a0"))
	Ink.polygon(self, shape, Color("#232e3b"), Color("#586173"), 2.0)
	Ink.polygon(self, PackedVector2Array([shape[1], shape[2], shape[3], shape[4], Vector2(x * 0.17, -y * 0.02),
		Vector2(-x * 0.46, -y * 0.17)]), Color("#354556"), Color("#536271"), 1.2)
	draw_polyline(PackedVector2Array([shape[2], Vector2(-x * 0.30, -y * 0.71), Vector2(-x * 0.46, -y * 0.17), shape[7]]),
		Color("#8b9a9d71"), 1.4, true)
	draw_line(Vector2(x * 0.08, y * 0.22), Vector2(x * 0.50, y * 0.49), Color("#6daba67e"), 2.0, true)
