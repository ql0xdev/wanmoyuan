extends Node2D

const Ink = preload("res://scenes/world/ink.gd")
const WISP_SLOTS := 15
const PULSE_SLOTS := 12
const PULSE_TIME := 0.46
const HEAL_FLASH_TIME := 0.32

var _orb_radius := 0.0
var _ice_radius := 0.0
var _lightning_radius := 0.0
var _origin := Vector2.ZERO
var _ice_at := Vector2.ZERO
var _ice_range := 0.0
var _fire := PackedVector2Array()
var _blades := PackedVector2Array()
var _bolts := PackedVector2Array()
var _bolt_alpha := 0.0
var _bolt_reach := 1.0
var _wisps := {}
var _auras := {}
var _pulses: Array[Dictionary] = []
var _pulse_index := 0
var _shield := false
var _heal_left := 0.0
var _heal_at := Vector2.ZERO


func setup(orb_radius: float, ice_radius: float, lightning_radius: float) -> void:
	_orb_radius = orb_radius
	_ice_radius = ice_radius
	_lightning_radius = lightning_radius
	for i in range(PULSE_SLOTS):
		_pulses.append({"left": 0.0})


func update_orbs(origin: Vector2, offsets: PackedVector2Array) -> void:
	_origin = origin
	_fire = offsets.duplicate()
	queue_redraw()


func update_ice(origin: Vector2, reach: float) -> void:
	_ice_at = origin
	_ice_range = _ice_radius * reach
	queue_redraw()


func hide_ice() -> void:
	_ice_range = 0.0
	queue_redraw()


func update_ascension(origin: Vector2, delta: float, shield: int) -> void:
	_origin = origin
	var previously_shielded := _shield
	_shield = shield > 0
	for pulse_data in _pulses:
		if pulse_data.left > 0.0:
			pulse_data.left -= delta
			queue_redraw()
	if _shield or previously_shielded:
		queue_redraw()


func pulse(at: Vector2, radius: float, tint: Color, thunder := false) -> void:
	_pulses[_pulse_index] = {"at": at, "radius": radius, "tint": tint, "left": PULSE_TIME, "thunder": thunder}
	_pulse_index = (_pulse_index + 1) % _pulses.size()
	queue_redraw()


func show_wisp(slot: int, at: Vector2, blast: bool) -> void:
	_wisps[slot] = [at, blast]
	queue_redraw()


func hide_wisp(slot: int) -> void:
	if _wisps.erase(slot):
		queue_redraw()


func show_aura(id: String, origin: Vector2, radius: float, tint: Color, delta: float) -> void:
	var phase: float = _auras[id].phase if _auras.has(id) else 0.0
	_auras[id] = {"at": origin, "radius": radius, "tint": tint, "phase": fposmod(phase + delta * TAU * 2.0, TAU)}
	queue_redraw()


func hide_aura(id: String) -> void:
	_auras.erase(id)
	queue_redraw()


func show_blades(origin: Vector2, offsets: PackedVector2Array) -> void:
	_origin = origin
	_blades = offsets.duplicate()
	queue_redraw()


func show_lightning(points: PackedVector2Array, reach: float) -> void:
	_bolts = points.duplicate()
	_bolt_reach = reach
	queue_redraw()


func update_lightning(fraction: float) -> void:
	_bolt_alpha = fraction
	queue_redraw()


func show_heal() -> void:
	_heal_left = HEAL_FLASH_TIME


func update_heal(origin: Vector2, delta: float) -> void:
	if _heal_left > 0:
		_heal_at = origin
		_heal_left = maxf(0.0, _heal_left - delta)
		queue_redraw()


func _draw() -> void:
	if _ice_range > 0.0:
		draw_circle(_ice_at, _ice_range, Color("#4279a018"), true, -1, true)
		Ink.ring(self, _ice_at, _ice_range, Color("#7ed5ef7e"), 1.8)
	if _shield:
		draw_circle(_origin, 39.0, Color("#6efdd81e"), true, -1, true)
		Ink.ring(self, _origin, 39.0, Color("#9bffdfd8"), 3.0)
	for id: String in _auras:
		var aura: Dictionary = _auras[id]
		var tint: Color = aura.tint
		var at: Vector2 = aura.at
		var radius: float = aura.radius
		var breathe: float = sin(aura.phase)
		draw_circle(at, radius, Ink.alpha(tint, 0.054 + 0.012 * breathe), true, -1, true)
		var opacity: float = 0.33 if id == "blades" else 0.66
		Ink.ring(self, at, radius, Ink.alpha(tint, opacity + 0.10 * breathe), 2.8)
		# 焰苗只改变绘制位置，不改变圆环实际判定半径。
		if id == "wisp":
			for i in range(12):
				var axis := Vector2.from_angle(i * TAU / 12.0)
				var tip := at + axis * (radius - 8.0 - 6.0 * sin(aura.phase + i))
				draw_line(at + axis * radius, tip, Ink.alpha(tint, 0.66), 3.2, true)
	for fx in _pulses:
		if fx.left <= 0.0:
			continue
		var fraction: float = fx.left / PULSE_TIME
		var radius := lerpf(0.22, 1.0, 1.0 - fraction) * float(fx.radius)
		Ink.ring(self, fx.at, radius, Ink.alpha(fx.tint, 0.8 * fraction), 3.5)
		if fx.thunder and fraction > 0.5:
			_draw_thunder(fx.at, radius, fx.tint, fraction, 180.0)
	for spot in _fire:
		var at := _origin + spot
		draw_circle(at, _orb_radius * 0.9, Color("#ff9a5672"), true, -1, true)
		Ink.diamond(self, at, Vector2(4.8, 6.8), Color("#ff7753"), Color("#ffdeb0"))
	for entry: Array in _wisps.values():
		var at: Vector2 = entry[0]
		var tint := Color("#efa2ff") if entry[1] else Color("#9cf2b5")
		draw_circle(at, 10.0, Ink.alpha(tint, 0.30), true, -1, true)
		Ink.diamond(self, at, Vector2(4.8, 6.5), Ink.alpha(tint, 0.82), tint)
	for spot in _blades:
		var dir := Vector2(-spot.y, spot.x).normalized()
		var at := _origin + spot
		draw_line(at - dir * 17.0, at + dir * 5.0, Color("#ffe8a953"), 5.0, true)
		Ink.sword(self, at, dir, Color("#ffe9a4"), 0.74)
	if _bolt_alpha > 0.0:
		for point in _bolts:
			_draw_thunder(point, _lightning_radius * _bolt_reach, Color("#a7cfff"), _bolt_alpha, 134.0)
	if _heal_left > 0.0:
		var fraction := _heal_left / HEAL_FLASH_TIME
		Ink.ring(self, _heal_at, lerpf(45.0, 23.0, fraction), Ink.alpha(Color("#a4f8b7"), fraction), 3)


func _draw_thunder(at: Vector2, radius: float, tint: Color, fraction: float, height: float) -> void:
	draw_circle(at, radius, Ink.alpha(tint, 0.13 * fraction), true, -1, true)
	Ink.ring(self, at, radius, Ink.alpha(tint, 0.62 * fraction))
	var zigzag := PackedVector2Array([at + Vector2(4, -height), at + Vector2(-8, -height * 0.65),
		at + Vector2(9, -height * 0.42), at + Vector2(-3, -height * 0.25), at])
	draw_polyline(zigzag, Ink.alpha(tint, 0.22 * fraction), 13.0, true)
	draw_polyline(zigzag, Ink.alpha(tint, 0.85 * fraction), 5.0, true)
	draw_polyline(zigzag, Ink.alpha(Color("#f4f9ff"), fraction), 2.0, true)
