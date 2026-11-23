extends Node2D

const Ink = preload("res://scenes/world/ink.gd")

var _centers := PackedVector2Array()
var _radius := 0.0
var _progress := 0.0
var _impact := 0.0
var _tint := Color("#ff8262")
var _charge := Vector2.ZERO
var _charge_width := 0.0


func warn(centers: PackedVector2Array, radius: float, progress: float, tint: Color) -> void:
	_centers = centers
	_radius = radius
	_progress = progress
	_tint = tint
	_impact = 0.0
	queue_redraw()


func flash(remaining: float) -> void:
	_impact = remaining
	queue_redraw()


func clear_circles() -> void:
	_centers = PackedVector2Array()
	_impact = 0.0
	queue_redraw()


func charge(direction: Vector2, distance: float, half_width: float) -> void:
	_charge = direction * distance
	_charge_width = half_width
	queue_redraw()


func _draw() -> void:
	for center in _centers:
		var at := to_local(center)
		if _impact > 0.0:
			draw_circle(at, _radius, Ink.alpha(_tint, _impact * 0.55), true, -1, true)
			Ink.ring(self, at, _radius, Ink.alpha(Color("#ffecac"), _impact), 4.0)
			draw_circle(at, _radius * 0.72, Ink.alpha(_tint, _impact * 0.30), false, 5.0, true)
		else:
			draw_circle(at, _radius, Ink.alpha(_tint, 0.13 + _progress * 0.15), true, -1, true)
			Ink.ring(self, at, _radius, Ink.alpha(_tint, 0.84), 3.6)
			draw_circle(at, _radius * _progress, Ink.alpha(_tint.lightened(0.4), 0.76), false, 2.0, true)
	if _charge != Vector2.ZERO:
		var forward := _charge.normalized()
		var side := Vector2(-forward.y, forward.x) * _charge_width
		Ink.polygon(self, PackedVector2Array([side, _charge + side, _charge - side, -side]),
			Color("#ff99552c"), Color("#ff9955c9"), 2.0)
		draw_line(Vector2.ZERO, _charge, Color("#ffc06a93"), 3.0, true)
