extends Node2D

const Ink = preload("res://scenes/world/ink.gd")
enum Motif { CRYSTAL, STONE, RECOVERY, GATHER, EQUIPMENT, BEAM }

@export var motif := Motif.CRYSTAL
var tint := Color.WHITE


func _draw() -> void:
	match motif:
		Motif.CRYSTAL:
			draw_circle(Vector2.ZERO, 17.0, Color("#5f9eff28"), true, -1, true)
			Ink.diamond(self, Vector2.ZERO, Vector2(11, 13), Color("#398dd6"), Color("#a8edff"))
			draw_line(Vector2(0, -11), Vector2(0, 7), Color("#82eaff"), 1.6, true)
		Motif.STONE:
			draw_circle(Vector2.ZERO, 16.0, Color("#56d4bc32"), true, -1, true)
			Ink.diamond(self, Vector2.ZERO, Vector2(10, 12), Color("#39c5b3"), Color("#d8fff0"))
			Ink.diamond(self, Vector2.ZERO, Vector2(3, 4), Ink.GOLD, Ink.GOLD)
		Motif.RECOVERY:
			draw_circle(Vector2.ZERO, 24.0, Color("#132f278f"), true, -1, true)
			Ink.ring(self, Vector2.ZERO, 22, Color("#66ce94"), 1.5)
			draw_rect(Rect2(-15, -5, 30, 10), Color("#a2ffc4"))
			draw_rect(Rect2(-5, -15, 10, 30), Color("#a2ffc4"))
		Motif.GATHER:
			draw_circle(Vector2.ZERO, 23.0, Color("#422765a1"), true, -1, true)
			Ink.ring(self, Vector2.ZERO, 21.0, Color("#e6a3ff"), 2.0)
			Ink.diamond(self, Vector2.ZERO, Vector2(8, 11), Color("#d591f1"), Color("#f7ddff"))
		Motif.EQUIPMENT:
			draw_circle(Vector2.ZERO, 14.0, Ink.alpha(tint, 0.17), true, -1, true)
			Ink.diamond(self, Vector2.ZERO, Vector2(9, 12), tint.darkened(0.24), tint.lightened(0.32))
		Motif.BEAM:
			Ink.ring(self, Vector2.ZERO, 16, Ink.alpha(tint, 0.82), 2.0)
			var points := PackedVector2Array([Vector2(-11, -3), Vector2(-7, -99), Vector2(7, -99), Vector2(11, -3)])
			var colors := PackedColorArray([Ink.alpha(tint, 0.70), Ink.alpha(tint, 0.01), Ink.alpha(tint, 0.01), Ink.alpha(tint, 0.70)])
			draw_polygon(points, colors)
			draw_line(Vector2(0, -3), Vector2(0, -63), Ink.alpha(tint.lightened(0.32), 0.82), 2, true)
			draw_circle(Vector2(0, -60), 3.6, tint.lightened(0.4), true, -1, true)
