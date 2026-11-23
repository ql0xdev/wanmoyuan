extends Node2D

const BattlePlane = preload("res://scripts/battle_plane.gd")
const Rock = preload("res://scenes/world/rock_art.gd")
const CHUNK_SIZE := 1152.0
const CHUNK_RADIUS := 3

@onready var _floor: Polygon2D = $GroundInk
@onready var _rocks: Node2D = $Rocks
var _obstacles: Array[CollisionShape2D] = []
var _chunk := Vector2i(2147483647, 2147483647)


func _ready() -> void:
	for i in range((2 * CHUNK_RADIUS + 1) ** 2):
		var obstacle := Rock.new()
		obstacle.collision_layer = BattlePlane.OBSTACLE_LAYER
		obstacle.collision_mask = 0
		_rocks.add_child(obstacle)
		var collider := CollisionShape2D.new()
		collider.shape = RectangleShape2D.new()
		obstacle.add_child(collider)
		_obstacles.append(collider)


func follow(focus: Vector2) -> void:
	# 背景始终覆盖镜头；坐标由着色器取世界位置，移动时网格不漂移。
	_floor.position = focus
	var chunk := Vector2i((focus / CHUNK_SIZE).floor())
	if chunk == _chunk:
		return
	_chunk = chunk
	_rocks.position = Vector2(chunk) * CHUNK_SIZE
	var i := 0
	for y in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
		for x in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
			var key := hash(chunk + Vector2i(x, y))
			var variation := float(posmod(key, 120)) - 60.0
			var footprint := Vector2(54.0 + absf(variation) * 0.5, 56.0)
			var center := Vector2(x * CHUNK_SIZE + variation, y * CHUNK_SIZE + 330.0 + variation)
			var collider := _obstacles[i]
			var box := collider.shape as RectangleShape2D
			box.size = footprint
			var obstacle := collider.get_parent() as Rock
			# 从 X/Z 映射到 X/Y，因此原绕 Y 的转向在此取反。
			obstacle.transform = Transform2D(-variation * 0.02, center)
			obstacle.footprint = footprint
			obstacle.queue_redraw()
			i += 1


func set_abyss_tint(tint: Color) -> void:
	var material := _floor.material as ShaderMaterial
	material.set_shader_parameter("ground_tint", Color("#141f29").lerp(tint.darkened(0.80), 0.28) if tint != Color.WHITE else Color("#111d24"))
