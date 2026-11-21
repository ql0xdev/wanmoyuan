extends Node2D

const DAMAGE_DURATION := 0.6
const BURST_DURATION := 0.22
const FONT_SIZE := 24
const MAX_NUMBERS := 96
const MAX_BURSTS := 64
const BURST_POINTS := 6
const BURST_SHAPE := preload("res://scenes/world/sphere_mesh.tres")
const LOOT_SHADER := preload("res://scenes/effects/loot_beam.gdshader")
const BEAM_DURATION := 2.0
const BEAM_HEIGHT := 84.0
const MAX_BEAMS := 36

class DamageNumber:
	var position: Vector3
	var shift: float
	var text: String
	var width: float
	var elapsed := 0.0

class DeathBurst:
	var position: Vector3
	var radius: float
	var color: Color
	var elapsed := 0.0

class LootBeam:
	var center: Vector3
	var color: Color
	var elapsed := 0.0

var _numbers: Array[DamageNumber] = []
var _bursts: Array[DeathBurst] = []
var _beams: Array[LootBeam] = []
var _camera: Camera3D
var _burst_mesh: MultiMesh
var _beam_mesh: MultiMesh
var _burst_axes: Array[Vector3] = []


func _ready() -> void:
	set_process(false)


func configure(camera: Camera3D, bursts: MultiMeshInstance3D, loot: MultiMeshInstance3D) -> void:
	_camera = camera
	_burst_mesh = MultiMesh.new()
	_burst_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_burst_mesh.use_colors = true
	_burst_mesh.mesh = BURST_SHAPE
	_burst_mesh.instance_count = MAX_BURSTS * BURST_POINTS
	_burst_mesh.visible_instance_count = 0
	bursts.multimesh = _burst_mesh
	for i in range(BURST_POINTS):
		var angle := TAU * i / BURST_POINTS + 0.32
		_burst_axes.append(Vector3(cos(angle), 0.4 if i % 2 == 0 else -0.32, sin(angle)))
	var cylinder := CylinderMesh.new()
	cylinder.height = BEAM_HEIGHT
	cylinder.top_radius = 8.0
	cylinder.bottom_radius = 8.0
	cylinder.radial_segments = 12
	cylinder.rings = 0
	var glow := ShaderMaterial.new()
	glow.shader = LOOT_SHADER
	cylinder.material = glow
	_beam_mesh = MultiMesh.new()
	_beam_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_beam_mesh.use_colors = true
	_beam_mesh.mesh = cylinder
	_beam_mesh.instance_count = MAX_BEAMS
	_beam_mesh.visible_instance_count = 0
	loot.multimesh = _beam_mesh


func show_loot_beam(at: Vector3, color: Color) -> void:
	if _beams.size() >= MAX_BEAMS:
		_beams.pop_front()
	var beam := LootBeam.new()
	beam.center = at + Vector3.UP * (BEAM_HEIGHT * 0.5)
	beam.color = color
	_beams.append(beam)
	_update_beams(0.0)
	set_process(true)


func show_damage(at: Vector3, amount: int, _critical := false) -> void:
	if _numbers.size() >= MAX_NUMBERS:
		_numbers.pop_front()
	var number := DamageNumber.new()
	# 同一帧多次命中错开一点，不动战斗随机数。
	number.shift = float(_numbers.size() % 5 - 2) * 7.0
	number.position = at
	number.text = str(amount)
	number.width = ThemeDB.fallback_font.get_string_size(number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	_numbers.append(number)
	set_process(true)
	queue_redraw()


func show_burst(at: Vector3, radius: float, tint: Color) -> void:
	if _bursts.size() >= MAX_BURSTS:
		_bursts.pop_front()
	var burst := DeathBurst.new()
	burst.position = at
	burst.radius = radius
	burst.color = tint
	_bursts.append(burst)
	set_process(true)


func _process(delta: float) -> void:
	var had_numbers := not _numbers.is_empty()
	var had_bursts := not _bursts.is_empty()
	for i in range(_numbers.size() - 1, -1, -1):
		_numbers[i].elapsed += delta
		if _numbers[i].elapsed >= DAMAGE_DURATION:
			_numbers.remove_at(i)
	for i in range(_bursts.size() - 1, -1, -1):
		_bursts[i].elapsed += delta
		if _bursts[i].elapsed >= BURST_DURATION:
			_bursts.remove_at(i)
	if not _beams.is_empty():
		_update_beams(delta)
	set_process(not _numbers.is_empty() or not _bursts.is_empty() or not _beams.is_empty())
	if had_bursts:
		_update_burst_mesh()
	if had_numbers:
		queue_redraw()


func _update_beams(delta: float) -> void:
	for i in range(_beams.size() - 1, -1, -1):
		_beams[i].elapsed += delta
		if _beams[i].elapsed >= BEAM_DURATION:
			_beams.remove_at(i)
	for i in range(_beams.size()):
		var beam := _beams[i]
		var color := beam.color
		color.a = 0.68 * (1.0 - beam.elapsed / BEAM_DURATION)
		_beam_mesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, beam.center))
		_beam_mesh.set_instance_color(i, color)
	_beam_mesh.visible_instance_count = _beams.size()


func _update_burst_mesh() -> void:
	var index := 0
	for burst in _bursts:
		var progress := burst.elapsed / BURST_DURATION
		var radial := burst.radius * (0.4 + progress * 1.5)
		var basis := Basis.from_scale(Vector3.ONE * maxf(0.01, 4.0 * (1.0 - progress)))
		for direction in _burst_axes:
			_burst_mesh.set_instance_transform(index, Transform3D(basis, burst.position + direction * radial))
			_burst_mesh.set_instance_color(index, burst.color)
			index += 1
	_burst_mesh.visible_instance_count = index


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for number in _numbers:
		if _camera.is_position_behind(number.position):
			continue
		var progress := number.elapsed / DAMAGE_DURATION
		var alpha := 1.0 - progress
		var at := _camera.unproject_position(number.position) + Vector2(number.shift - number.width * 0.5, -42.0 * progress)
		font.draw_string_outline(get_canvas_item(), at, number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Color(0.05, 0.07, 0.09, alpha))
		draw_string(font, at, number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(Color.WHITE, alpha))
