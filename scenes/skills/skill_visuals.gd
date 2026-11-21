extends Node3D

const SPHERE := preload("res://scenes/world/sphere_mesh.tres")
const HEAL_FLASH_TIME := 0.32

var _fire: Array[MeshInstance3D] = []
var _bolts: Array[MeshInstance3D] = []
var _impacts: Array[MeshInstance3D] = []
var _ice: MeshInstance3D
var _heal: MeshInstance3D
var _heal_left := 0.0


func setup(orb_radius: float, ice_radius: float, lightning_radius: float, max_orbs: int, max_bolts: int) -> void:
	var fire_material := _glow(Color("#ff7134"))
	for i in range(max_orbs):
		var orb := _mesh(SPHERE, fire_material)
		orb.scale = Vector3.ONE * orb_radius
		_fire.append(orb)

	var bolt := CylinderMesh.new()
	bolt.top_radius = 2.6
	bolt.bottom_radius = 3.8
	bolt.height = 182.0
	bolt.radial_segments = 8
	bolt.rings = 0
	var bolt_material := _glow(Color("#bcdeff"))
	var impact := _ring(lightning_radius, 2.6)
	var impact_material := _glow(Color("#81a7e7"), 0.35)
	for i in range(max_bolts):
		_bolts.append(_mesh(bolt, bolt_material))
		_impacts.append(_mesh(impact, impact_material))
	_ice = _mesh(_ring(ice_radius, 2.7), _glow(Color("#5aa4ce"), 0.25))
	_heal = _mesh(_ring(25.0, 2.4), _glow(Color("#76e09f")))


func update_orbs(origin: Vector3, offsets: PackedVector3Array) -> void:
	for i in range(_fire.size()):
		var orb := _fire[i]
		orb.visible = i < offsets.size()
		if orb.visible:
			orb.global_position = origin + offsets[i] + Vector3.UP * 22.0


func update_ice(origin: Vector3) -> void:
	_ice.global_position = origin + Vector3.UP * 1.0
	_ice.show()


func show_lightning(points: PackedVector3Array) -> void:
	for i in range(points.size()):
		_bolts[i].global_position = points[i] + Vector3.UP * 91.0
		_bolts[i].show()
		_impacts[i].global_position = points[i] + Vector3.UP * 2.0
		_impacts[i].show()


func update_lightning(fraction: float) -> void:
	for i in range(_bolts.size()):
		var bolt := _bolts[i]
		if bolt.visible:
			if fraction <= 0.0:
				bolt.hide()
				_impacts[i].hide()
			else:
				var width := lerpf(0.28, 1.0, fraction)
				bolt.scale = Vector3(width, 1.0, width)


func show_heal() -> void:
	_heal_left = HEAL_FLASH_TIME


func update_heal(origin: Vector3, delta: float) -> void:
	if _heal_left <= 0.0:
		_heal.hide()
		return
	var progress := 1.0 - _heal_left / HEAL_FLASH_TIME
	_heal.global_position = origin + Vector3.UP * lerpf(1.0, 44.0, progress)
	_heal.scale = Vector3(1.0 + progress * 0.5, 1.0 - progress * 0.75, 1.0 + progress * 0.5)
	_heal.show()
	_heal_left = maxf(0.0, _heal_left - delta)


func _mesh(mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.hide()
	add_child(instance)
	return instance


func _ring(radius: float, width: float) -> TorusMesh:
	var ring := TorusMesh.new()
	ring.inner_radius = radius - width
	ring.outer_radius = radius
	ring.rings = 40
	ring.ring_segments = 6
	return ring


func _glow(color: Color, energy := 0.65) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
