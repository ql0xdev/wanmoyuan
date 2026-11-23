extends RefCounted

const NIGHT := Color("#0d1117")
const JADE := Color("#5ce9ce")
const GOLD := Color("#f0c674")


static func alpha(tint: Color, opacity: float) -> Color:
	return Color(tint, opacity)


static func polygon(canvas: CanvasItem, points: PackedVector2Array, fill: Color, edge: Color, width := 1.6) -> void:
	canvas.draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	canvas.draw_polyline(closed, edge, width, true)


static func diamond(canvas: CanvasItem, at: Vector2, radii: Vector2, fill: Color, edge: Color) -> void:
	polygon(canvas, PackedVector2Array([at + Vector2(-radii.x, 0), at + Vector2(0, -radii.y),
		at + Vector2(radii.x, 0), at + Vector2(0, radii.y)]), fill, edge)


static func ring(canvas: CanvasItem, center: Vector2, radius: float, tint: Color, width := 2.0) -> void:
	var steps := clampi(ceili(radius * 0.42), 20, 96)
	canvas.draw_arc(center, radius, 0.0, TAU, steps, alpha(tint, tint.a * 0.24), width + 5.0, true)
	canvas.draw_arc(center, radius, 0.0, TAU, steps, tint, width, true)


static func sword(canvas: CanvasItem, at: Vector2, direction: Vector2, tint: Color, size_factor := 1.0) -> void:
	var along := direction * size_factor
	var side := Vector2(-along.y, along.x)
	var tip := at + along * 22.0
	var tail := at - along * 16.0
	polygon(canvas, PackedVector2Array([tip, at + along * 3 + side * 5, tail, at + along * 3 - side * 5]),
		alpha(tint, 0.70), tint)
	canvas.draw_line(tail, tip, Color("#f1fff4"), 1.4, true)
	canvas.draw_line(at - along * 9 + side * 6, at - along * 9 - side * 6, GOLD, 2.0, true)
