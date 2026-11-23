extends RefCounted

enum Kind { WOLF, CROW, GOLEM }

const WAVE_INTERVAL := 60.0
const WARNING_LEAD := 3.0
const WAVE_RADIUS := 700.0
const GOLEM_INTERVAL := 30.0
const EPSILON := 0.000001
const BattlePlane = preload("res://scripts/battle_plane.gd")

var _abyss: Dictionary
var _progress := 0.0
var _next_golem := 0.0
var _next_wave := WAVE_INTERVAL
var _warned := false
var _regular_mix := 0
var _wave_mix := 0
var _summon_mix := 0
var _waves: Array[Dictionary] = []
var _summons: Array[Dictionary] = []


func _init(abyss: Dictionary) -> void:
	_abyss = abyss
	_next_golem = abyss.golem_at


func interval_at(elapsed: float) -> float:
	return maxf(0.4, 1.5 / (float(_abyss.density) * pow(1.20, floori((elapsed + EPSILON) / 30.0))))


func warning_active() -> bool:
	return _warned


func advance(previous: float, now: float, center: Vector3, warn: Callable,
		spawn_regular: Callable, spawn_at: Callable) -> void:
	_progress += (now - previous) / interval_at(previous)
	while now + EPSILON >= _next_wave - WARNING_LEAD:
		if now + EPSILON < _next_wave:
			if not _warned:
				_warned = true
				warn.call()
			break
		var total: int = _abyss.wave_count + _abyss.wave_golems
		for i in range(total):
			var kind := Kind.GOLEM
			# 将额外石傀均匀分到同一个圆环，而不是先在某一侧刷完小怪。
			if (i * int(_abyss.wave_golems)) % total + int(_abyss.wave_golems) < total:
				_wave_mix += _abyss.crow_percent
				kind = Kind.CROW if _wave_mix >= 100 else Kind.WOLF
				_wave_mix %= 100
			_waves.append({"kind": kind, "at": center + BattlePlane.direction(TAU * i / total) * WAVE_RADIUS})
		_next_wave += WAVE_INTERVAL
		_warned = false

	if now + EPSILON >= _next_golem and spawn_regular.call(Kind.GOLEM):
		var step: float = GOLEM_INTERVAL / _abyss.density
		_next_golem += step * (1 + floori((now + EPSILON - _next_golem) / step))
	_flush(_waves, spawn_at)
	_flush(_summons, spawn_at)
	while _progress + EPSILON >= 1.0:
		var mix: int = _regular_mix + _abyss.crow_percent
		if not spawn_regular.call(Kind.CROW if mix >= 100 else Kind.WOLF):
			break
		_regular_mix = mix % 100
		_progress -= 1.0
	_progress = minf(_progress, 1.0)


func queue_summon(origin: Vector3) -> void:
	for i in range(6):
		_summon_mix += _abyss.crow_percent
		var kind := Kind.CROW if _summon_mix >= 100 else Kind.WOLF
		_summon_mix %= 100
		_summons.append({"kind": kind, "at": origin + BattlePlane.direction(TAU * i / 6.0) * 66.0})


func _flush(queue: Array[Dictionary], spawn_at: Callable) -> void:
	while not queue.is_empty():
		var entry := queue.front() as Dictionary
		if not spawn_at.call(entry.kind, entry.at):
			return
		queue.pop_front()
