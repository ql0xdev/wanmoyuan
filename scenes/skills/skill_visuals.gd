extends Node3D

const SPHERE := preload("res://scenes/world/sphere_mesh.tres")
const HEAL_FLASH_TIME := 0.32
const WISP_SLOTS := 12
const PULSE_SLOTS := 12
const PULSE_TIME := 0.46

var _fire: Array[MeshInstance3D] = []
var _bolts: Array[MeshInstance3D] = []
var _impacts: Array[MeshInstance3D] = []
var _ice: MeshInstance3D
var _heal: MeshInstance3D
var _heal_left := 0.0
var _wisps: Array[MeshInstance3D] = []
var _blades: Array[MeshInstance3D] = []
var _pulses: Array[Dictionary] = []
var _pulse_index := 0
var _pulse_mesh: TorusMesh
var _wisp_material: StandardMaterial3D
var _blast_material: StandardMaterial3D
var _guard: MeshInstance3D
var _shield: MeshInstance3D
var _thunder: MeshInstance3D
var _thunder_left := 0.0


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


func hide_ice() -> void:
	_ice.hide()


func update_ascension(origin: Vector3, delta: float, shield: int, guard: bool) -> void:
	if guard:
		if _guard == null:
			_guard = _mesh(_ring(48.0, 5.0), _glow(Color("#fbc779")))
		_guard.global_position = origin + Vector3.UP * 8.0
		_guard.show()
	if shield > 0:
		if _shield == null:
			_shield = _mesh(_ring(41.0, 4.0), _glow(Color("#72f0d6")))
		_shield.global_position = origin + Vector3.UP * 24.0
		_shield.show()
	elif _shield != null:
		_shield.hide()
	for pulse_data in _pulses:
		if pulse_data.left <= 0.0:
			continue
		pulse_data.left -= delta
		if pulse_data.left <= 0.0:
			pulse_data.node.hide()
		else:
			var scale_at := lerpf(0.22, 1.0, 1.0 - pulse_data.left / PULSE_TIME) * float(pulse_data.radius)
			pulse_data.node.scale = Vector3(scale_at, 6.5, scale_at)
			pulse_data.color.albedo_color.a = 0.84 * pulse_data.left / PULSE_TIME
	if _thunder_left > 0.0:
		_thunder_left -= delta
		if _thunder_left <= 0.0:
			_thunder.hide()


func pulse(at: Vector3, radius: float, tint: Color, thunder := false) -> void:
	if _pulse_mesh == null:
		_pulse_mesh = _ring(1.0, 0.048)
		for i in range(PULSE_SLOTS):
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_pulses.append({"node": _mesh(_pulse_mesh, material), "color": material, "radius": 0.0, "left": 0.0})
	var entry := _pulses[_pulse_index]
	_pulse_index = (_pulse_index + 1) % _pulses.size()
	entry.left = PULSE_TIME
	entry.radius = radius
	entry.color.albedo_color = tint
	entry.node.global_position = at + Vector3.UP * 5.0
	entry.node.scale = Vector3(radius * 0.22, 6.5, radius * 0.22)
	entry.node.show()
	if thunder:
		if _thunder == null:
			var bolt := CylinderMesh.new()
			bolt.top_radius = 6.0
			bolt.bottom_radius = 11.0
			bolt.height = 270.0
			bolt.radial_segments = 8
			_thunder = _mesh(bolt, _glow(Color("#ffae64"), 1.5))
		_thunder.global_position = at + Vector3.UP * 135.0
		_thunder_left = 0.23
		_thunder.show()


func show_wisp(slot: int, at: Vector3, blast: bool) -> void:
	if _wisps.is_empty():
		_wisp_material = _glow(Color("#85efa9"), 1.3)
		_blast_material = _glow(Color("#dc83ff"), 1.5)
		for i in range(WISP_SLOTS):
			_wisps.append(_mesh(SPHERE, _wisp_material))
	var wisp := _wisps[slot]
	wisp.material_override = _blast_material if blast else _wisp_material
	wisp.scale = Vector3(12.0, 19.0, 12.0) if blast else Vector3(9.0, 15.0, 9.0)
	wisp.global_position = at + Vector3.UP * 26.0
	wisp.show()


func hide_wisp(slot: int) -> void:
	_wisps[slot].hide()


func show_blades(origin: Vector3, offsets: PackedVector3Array) -> void:
	if _blades.is_empty():
		var mesh := PrismMesh.new()
		mesh.size = Vector3(13.0, 32.0, 6.0)
		var material := _glow(Color("#fff4a3"), 1.35)
		for i in range(offsets.size()):
			_blades.append(_mesh(mesh, material))
	for i in range(offsets.size()):
		var blade := _blades[i]
		var offset := offsets[i]
		blade.global_position = origin + offset + Vector3.UP * 30.0
		blade.rotation = Vector3(deg_to_rad(28.0), -atan2(offset.z, offset.x), deg_to_rad(-24.0))
		blade.show()


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
