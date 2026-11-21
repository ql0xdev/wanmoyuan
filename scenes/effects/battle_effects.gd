extends Node2D

const DAMAGE_DURATION := 0.65
const BURST_DURATION := 0.22
const FONT_SIZE := 24
const MAX_NUMBERS := 96
const MAX_BURSTS := 64

class DamageNumber:
	var position: Vector2
	var text: String
	var width: float
	var color: Color
	var elapsed := 0.0

class DeathBurst:
	var position: Vector2
	var radius: float
	var color: Color
	var elapsed := 0.0

var _numbers: Array[DamageNumber] = []
var _bursts: Array[DeathBurst] = []


func _ready() -> void:
	set_process(false)


func show_damage(at: Vector2, amount: int, critical := false) -> void:
	if _numbers.size() >= MAX_NUMBERS:
		_numbers.pop_front()
	var number := DamageNumber.new()
	# 同一帧多次命中错开一点，不动战斗随机数。
	var shift := float(_numbers.size() % 5 - 2) * 7.0
	number.position = to_local(at) + Vector2(shift, 0.0)
	number.text = str(amount)
	number.width = ThemeDB.fallback_font.get_string_size(number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	number.color = Color("#ffae58") if critical else Color.WHITE
	_numbers.append(number)
	set_process(true)
	queue_redraw()


func show_burst(at: Vector2, radius: float, tint: Color) -> void:
	if _bursts.size() >= MAX_BURSTS:
		_bursts.pop_front()
	var burst := DeathBurst.new()
	burst.position = to_local(at)
	burst.radius = radius
	burst.color = tint
	_bursts.append(burst)
	set_process(true)
	queue_redraw()


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
	queue_redraw()


func _draw() -> void:
	for burst in _bursts:
		var progress := burst.elapsed / BURST_DURATION
		var color := Color(burst.color, 1.0 - progress)
		for i in range(6):
			var direction := Vector2.from_angle(TAU * i / 6.0 + 0.32)
			var radial := burst.radius * (0.4 + progress * 1.5)
			draw_circle(burst.position + direction * radial, 4.0 * (1.0 - progress), color, true, -1.0, true)
	var font := ThemeDB.fallback_font
	for number in _numbers:
		var progress := number.elapsed / DAMAGE_DURATION
		var alpha := 1.0 - smoothstep(0.35, 1.0, progress)
		var at := number.position - Vector2(number.width * 0.5, 52.0 * progress)
		font.draw_string_outline(get_canvas_item(), at, number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 5, Color(0.03, 0.04, 0.05, alpha))
		draw_string(font, at, number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(number.color, alpha))
