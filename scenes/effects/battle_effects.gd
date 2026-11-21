extends Node2D

const DAMAGE_DURATION := 0.65
const BURST_DURATION := 0.22
const FONT_SIZE := 24
const MAX_NUMBERS := 96
const MAX_BURSTS := 64
const BURST_POINTS := 6
const BURST_SHAPE := preload("res://scenes/world/sphere_mesh.tres")

class DamageNumber:
	var position: Vector3
	var shift: float
	var text: String
	var width: float
	var color: Color
	var elapsed := 0.0

class DeathBurst:
	var position: Vector3
	var radius: float
	var color: Color
	var elapsed := 0.0

var _numbers: Array[DamageNumber] = []
var _bursts: Array[DeathBurst] = []
var _camera: Camera3D
var _burst_mesh: MultiMesh
var _burst_axes: Array[Vector3] = []


func _ready() -> void:
	set_process(false)


func configure(camera: Camera3D, bursts: MultiMeshInstance3D) -> void:
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


func show_damage(at: Vector3, amount: int, critical := false) -> void:
	if _numbers.size() >= MAX_NUMBERS:
		_numbers.pop_front()
	var number := DamageNumber.new()
	# 同一帧多次命中错开一点，不动战斗随机数。
	number.shift = float(_numbers.size() % 5 - 2) * 7.0
	number.position = at
	number.text = str(amount)
	number.width = ThemeDB.fallback_font.get_string_size(number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	number.color = Color("#ffae58") if critical else Color.WHITE
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
	for i in range(_numbers.size() - 1, -1, -1):
		_numbers[i].elapsed += delta
		if _numbers[i].elapsed >= DAMAGE_DURATION:
			_numbers.remove_at(i)
	for i in range(_bursts.size() - 1, -1, -1):
		_bursts[i].elapsed += delta
		if _bursts[i].elapsed >= BURST_DURATION:
			_bursts.remove_at(i)
	set_process(not _numbers.is_empty() or not _bursts.is_empty())
	_update_burst_mesh()
	queue_redraw()


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
		var alpha := 1.0 - smoothstep(0.35, 1.0, progress)
		var at := _camera.unproject_position(number.position) + Vector2(number.shift - number.width * 0.5, -52.0 * progress)
		font.draw_string_outline(get_canvas_item(), at, number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 5, Color(0.03, 0.04, 0.05, alpha))
		draw_string(font, at, number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(number.color, alpha))
