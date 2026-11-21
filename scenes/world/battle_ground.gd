extends Node3D

const BattlePlane = preload("res://scripts/battle_plane.gd")
const CHUNK_SIZE := 1152.0
const CHUNK_RADIUS := 2

@onready var _plane: MeshInstance3D = $Plane
@onready var _rocks: MultiMeshInstance3D = $Rocks
var _obstacles: Array[CollisionShape3D] = []
var _chunk := Vector2i(2147483647, 2147483647)


func _ready() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = (2 * CHUNK_RADIUS + 1) ** 2
	_rocks.multimesh = instances
	# 碰撞体和网格实例共用索引，区块移动时复用节点。
	for i in range(instances.instance_count):
		var obstacle := StaticBody3D.new()
		obstacle.collision_layer = BattlePlane.OBSTACLE_LAYER
		obstacle.collision_mask = 0
		_rocks.add_child(obstacle)
		var collider := CollisionShape3D.new()
		collider.shape = BoxShape3D.new()
		obstacle.add_child(collider)
		_obstacles.append(collider)


func follow(focus: Vector3) -> void:
	var chunk := Vector2i((Vector2(focus.x, focus.z) / CHUNK_SIZE).floor())
	if chunk == _chunk:
		return
	_chunk = chunk
	_plane.position = Vector3((chunk.x + 0.5) * CHUNK_SIZE, -0.5, (chunk.y + 0.5) * CHUNK_SIZE)
	_rocks.position = Vector3(chunk.x * CHUNK_SIZE, 0.0, chunk.y * CHUNK_SIZE)
	var i := 0
	for z in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
		for x in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
			# 视觉和碰撞使用同一尺寸、朝向和中心，不消耗战斗随机数。
			var key := hash(chunk + Vector2i(x, z))
			var variation := float(posmod(key, 120)) - 60.0
			var size := Vector3(54.0 + absf(variation) * 0.5, 40.0 + absf(variation), 56.0)
			var center := Vector3(x * CHUNK_SIZE + variation, size.y * 0.5, z * CHUNK_SIZE + 330.0 + variation)
			var axes := Basis(Vector3.UP, variation * 0.02)
			_rocks.multimesh.set_instance_transform(i, Transform3D(axes.scaled_local(size), center))
			var collider := _obstacles[i]
			var box := collider.shape as BoxShape3D
			box.size = size
			var obstacle := collider.get_parent() as StaticBody3D
			obstacle.transform = Transform3D(axes, center)
			i += 1
