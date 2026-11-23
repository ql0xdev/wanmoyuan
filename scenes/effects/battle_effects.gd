extends Node2D

const DAMAGE_DURATION := 0.6
const BURST_DURATION := 0.22
const HIT_FONT_SIZE := 36
const CRITICAL_FONT_SIZE := 52
const HIT_INK := Color.WHITE
const CRITICAL_INK := Color("#ffcf60")
const HIT_OUTLINE := Color("#101219")
const CRITICAL_OUTLINE := Color("#522a13")
const MAX_NUMBERS := 96
const MAX_BURSTS := 64
const BURST_POINTS := 6
const BURST_SHAPE := preload("res://scenes/world/sphere_mesh.tres")
const EquipmentPickup = preload("res://scenes/pickups/equipment_pickup.gd")
const LOOT_FONT_SIZE := 22
const LOOT_LABEL_HEIGHT := 33.0
const LOOT_LABEL_PADDING := 8.0
const LOOT_LABEL_BACKGROUND := Color("#0d1117eb")

class DamageNumber:
	var position: Vector3
	var shift: float
	var text: String
	var width: float
	var critical: bool
	var font_size: int
	var elapsed := 0.0

class DeathBurst:
	var position: Vector3
	var radius: float
	var color: Color
	var elapsed := 0.0

var _numbers: Array[DamageNumber] = []
var _bursts: Array[DeathBurst] = []
var _ground_equipment: Dictionary[EquipmentPickup, float] = {}
var _camera: Camera3D
var _damage_font: FontVariation
var _burst_mesh: MultiMesh
var _burst_axes: Array[Vector3] = []


func _ready() -> void:
	_damage_font = FontVariation.new()
	_damage_font.base_font = ThemeDB.fallback_font
	_damage_font.variation_embolden = 1.0
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


func track_equipment(pickup: EquipmentPickup) -> void:
	var font := ThemeDB.fallback_font
	_ground_equipment[pickup] = font.get_string_size(pickup.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, LOOT_FONT_SIZE).x
	set_process(true)
	queue_redraw()


func untrack_equipment(pickup: EquipmentPickup) -> void:
	_ground_equipment.erase(pickup)
	queue_redraw()


func show_damage(at: Vector3, amount: int, critical := false) -> void:
	if _numbers.size() >= MAX_NUMBERS:
		_numbers.pop_front()
	var number := DamageNumber.new()
	# 同一帧多次命中错开一点，不动战斗随机数。
	number.shift = float(_numbers.size() % 5 - 2) * 9.0
	number.position = at
	number.text = str(amount)
	number.critical = critical
	number.font_size = CRITICAL_FONT_SIZE if critical else HIT_FONT_SIZE
	number.width = _damage_font.get_string_size(number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, number.font_size).x
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
	set_process(not _numbers.is_empty() or not _bursts.is_empty() or not _ground_equipment.is_empty())
	if had_bursts:
		_update_burst_mesh()
	if had_numbers or not _ground_equipment.is_empty():
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
	if not _ground_equipment.is_empty():
		_draw_equipment_names(font)
	for number in _numbers:
		if _camera.is_position_behind(number.position):
			continue
		var progress := number.elapsed / DAMAGE_DURATION
		var alpha := 1.0 - smoothstep(0.32, 1.0, progress)
		var at := _camera.unproject_position(number.position) + Vector2(number.shift, -52.0 * progress)
		var pop := lerpf(1.16 if number.critical else 1.10, 1.0, smoothstep(0.0, 0.24, progress))
		draw_set_transform(at, 0.0, Vector2.ONE * pop)
		var start := Vector2(-number.width * 0.5, 0.0)
		var edge := Color(CRITICAL_OUTLINE if number.critical else HIT_OUTLINE, alpha)
		var ink := Color(CRITICAL_INK if number.critical else HIT_INK, alpha)
		_damage_font.draw_string_outline(get_canvas_item(), start, number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, number.font_size,
			9 if number.critical else 7, edge)
		draw_string(_damage_font, start, number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, number.font_size, ink)
	draw_set_transform(Vector2.ZERO)


func _draw_equipment_names(font: Font) -> void:
	var view := get_viewport_rect()
	var occupied: Array[Rect2] = []
	for pickup: EquipmentPickup in _ground_equipment:
		var label_point := pickup.name_anchor()
		if _camera.is_position_behind(label_point):
			continue
		var anchor := _camera.unproject_position(label_point)
		if not view.grow(LOOT_LABEL_HEIGHT).has_point(anchor):
			continue
		var width := _ground_equipment[pickup] + LOOT_LABEL_PADDING * 2.0
		var left := clampf(anchor.x - width * 0.5, view.position.x + 8.0, view.end.x - width - 8.0)
		var label := Rect2(left, anchor.y - LOOT_LABEL_HEIGHT, width, LOOT_LABEL_HEIGHT)
		# 同处掉多件时向上排，不让装备名字彼此盖住。
		while true:
			var top := label.position.y
			for other in occupied:
				if label.grow(3.0).intersects(other):
					top = minf(top, other.position.y - LOOT_LABEL_HEIGHT - 4.0)
			if top >= label.position.y:
				break
			label.position.y = top
		if label.end.y <= view.position.y:
			continue
		occupied.append(label)
		var ink := pickup.quality_color
		var leader := Vector2(clampf(anchor.x, label.position.x + 3.0, label.end.x - 3.0), label.end.y - 1.0)
		var marker := _camera.unproject_position(pickup.global_position + Vector3.UP * 16.0)
		draw_line(marker, leader, Color(ink, 0.7), 1.0, true)
		draw_rect(label, LOOT_LABEL_BACKGROUND)
		draw_rect(label, Color(ink, 0.48), false, 1.0)
		var baseline := label.position + Vector2(LOOT_LABEL_PADDING, (LOOT_LABEL_HEIGHT - font.get_height(LOOT_FONT_SIZE)) * 0.5
			+ font.get_ascent(LOOT_FONT_SIZE))
		draw_string(font, baseline, pickup.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, LOOT_FONT_SIZE, ink)
