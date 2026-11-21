extends RefCounted

var _scene: PackedScene
var _container: Node3D
var _on_created: Callable
var _available: Array[Node3D] = []


func _init(scene: PackedScene, container: Node3D, reserve: int, on_created: Callable) -> void:
	_scene = scene
	_container = container
	_on_created = on_created
	for i in range(reserve):
		_available.append(_create())


func acquire() -> Node3D:
	var item: Node3D = _available.pop_back() if not _available.is_empty() else _create()
	item.process_mode = Node.PROCESS_MODE_INHERIT
	item.show()
	return item


func release(item: Node3D) -> void:
	_deactivate(item)
	_available.append(item)


func _create() -> Node3D:
	# 空闲节点保留在树内但不运行，信号仅在首次创建时连接。
	var item := _scene.instantiate() as Node3D
	_deactivate(item)
	_container.add_child(item)
	_on_created.call(item)
	return item


func _deactivate(item: Node3D) -> void:
	item.hide()
	item.process_mode = Node.PROCESS_MODE_DISABLED
