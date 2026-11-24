extends Node2D

const Ink = preload("res://scenes/world/ink.gd")
const EXTENT := Vector2(1040, 2048)
const WALL := 64.0
const TILE := 76
const STONE := Color("#24313c")
const SEAM := Color("#111923")
const BRONZE := Color("#685940")


func _ready() -> void:
	var walls := StaticBody2D.new()
	add_child(walls)
	_add_wall(walls, Rect2(0, 0, EXTENT.x, WALL))
	_add_wall(walls, Rect2(0, EXTENT.y - WALL, EXTENT.x, WALL))
	_add_wall(walls, Rect2(0, WALL, WALL, EXTENT.y - WALL * 2.0))
	_add_wall(walls, Rect2(EXTENT.x - WALL, WALL, WALL, EXTENT.y - WALL * 2.0))


func _add_wall(walls: StaticBody2D, rect: Rect2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collider := CollisionShape2D.new()
	collider.position = rect.get_center()
	collider.shape = shape
	walls.add_child(collider)


func _draw() -> void:
	var room := Rect2(Vector2.ZERO, EXTENT)
	var floor_rect := room.grow(-WALL)
	draw_rect(room.grow(4096), Color("#0b1119"))
	draw_rect(room, Color("#111720"))
	_draw_tiles(floor_rect)
	_draw_inlays()
	_draw_walls(room, floor_rect)


func _draw_tiles(floor_rect: Rect2) -> void:
	draw_rect(floor_rect, SEAM)
	var row := 0
	for y in range(int(floor_rect.position.y), int(floor_rect.end.y), TILE):
		var column := 0
		var offset := (row % 2) * (TILE / 2)
		for x in range(int(floor_rect.position.x) - offset, int(floor_rect.end.x), TILE):
			var slab := floor_rect.intersection(Rect2(x, y, TILE, TILE)).grow(-2)
			if not slab.has_area():
				continue
			var shade := posmod(row * 67 + column * 29 + row * column * 13, 19)
			var color := STONE.darkened(0.22).lerp(STONE, float(shade) / 18.0)
			draw_rect(slab, color)
			draw_line(slab.position, Vector2(slab.end.x, slab.position.y), color.lightened(0.045), 1.0)
			if shade < 4 and slab.size.x > 50:
				var start := slab.position + Vector2(8 + shade * 3, 16)
				draw_polyline(PackedVector2Array([start, start + Vector2(11, 7), start + Vector2(17, 24)]),
					SEAM, 1.5, true)
			column += 1
		row += 1


func _draw_inlays() -> void:
	# A faint central walk links the meditation dais and the departure court.
	var path := Rect2(406, 330, 228, 1458)
	draw_rect(path, Color(0.30, 0.41, 0.42, 0.10))
	for x in [path.position.x, path.end.x]:
		draw_line(Vector2(x, path.position.y), Vector2(x, path.end.y), Ink.alpha(BRONZE, 0.72), 2.0)
		draw_line(Vector2(x + 6, path.position.y), Vector2(x + 6, path.end.y), Ink.alpha(BRONZE, 0.39), 1.0)
		for y in range(540, 1620, 86):
			Ink.diamond(self, Vector2(x, y), Vector2(5, 8), SEAM, BRONZE)
	for center in [Vector2(520, 332), Vector2(520, 1788)]:
		var court := PackedVector2Array()
		for i in range(8):
			court.append(center + Vector2.from_angle(i * TAU / 8.0 + PI / 8.0) * 137.0)
		Ink.polygon(self, court, Color("#19282f"), BRONZE, 3.0)
		draw_arc(center, 112, 0, TAU, 64, Color("#395250"), 2.0, true)
		for i in range(8):
			var ray := Vector2.from_angle(i * TAU / 8.0)
			Ink.diamond(self, center + ray * 112.0, Vector2(5, 5), BRONZE, Color("#8a7854"))
	for y in [665, 900, 1145, 1390]:
		var center := Vector2(520, y)
		Ink.diamond(self, center, Vector2(22, 38), Color("#24343b"), Color("#4b5045"))
		Ink.diamond(self, center, Vector2(7, 14), BRONZE, Color("#8a7854"))


func _draw_walls(room: Rect2, floor_rect: Rect2) -> void:
	for inset in range(17, int(WALL) + 1, 15):
		draw_rect(room.grow(-inset), STONE.lightened(float(inset) * 0.0008), false, 13.0)
	for x in range(35, int(EXTENT.x), 80):
		for y in [32, int(EXTENT.y) - 32]:
			draw_line(Vector2(x, y - 22), Vector2(x + 12, y + 22), SEAM, 2.0)
	for y in range(75, int(EXTENT.y) - 65, 79):
		for x in [32, int(EXTENT.x) - 32]:
			draw_line(Vector2(x - 24, y), Vector2(x + 24, y + 11), SEAM, 2.0)
	draw_rect(floor_rect, Color("#101820"), false, 12.0)
	draw_rect(floor_rect.grow(-8), Color("#506064"), false, 2.0)
	for y in [172, 635, 1112, 1589, 1905]:
		_draw_lantern(Vector2(WALL, y))
		_draw_lantern(Vector2(EXTENT.x - WALL, y))


func _draw_lantern(at: Vector2) -> void:
	var light := Color("#71c3ae")
	for radius in [96, 76, 58, 42, 28]:
		draw_circle(at, radius, Ink.alpha(light, 0.018), true, -1.0, true)
	draw_rect(Rect2(at - Vector2(15, 25), Vector2(30, 50)), Color("#1a252b"))
	Ink.diamond(self, at, Vector2(10, 17), Color("#36766f"), light)
	Ink.diamond(self, at, Vector2(4, 10), Color("#c6fbe2"), light)
