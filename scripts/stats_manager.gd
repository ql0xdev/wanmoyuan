extends RefCounted

const Catalog = preload("res://scripts/artifact_catalog.gd")
const BASE_HEALTH := 100
const BASE_MOVE_SPEED := 200.0
const BASE_MAGNET_RADIUS := 80.0
const COOLDOWN_CAP := 0.40

var max_health_bonus := 0
var sword_count := 0
var lightning_count := 0
var hit_speed_duration := 0.0
var cooldown_multiplier := 1.0
var magnet_radius := BASE_MAGNET_RADIUS
var _bonuses: Dictionary[StringName, float] = {}


func rebuild(equipment: Array[StringName]) -> void:
	_bonuses.clear()
	for id in equipment:
		if id == &"":
			continue
		var bonuses: Dictionary = Catalog.ITEMS[id].stats
		for stat: StringName in bonuses:
			_bonuses[stat] = _get_bonus(stat) + float(bonuses[stat])
	max_health_bonus = int(_get_bonus(&"max_health"))
	sword_count = int(_get_bonus(&"sword_count"))
	lightning_count = int(_get_bonus(&"lightning_count"))
	hit_speed_duration = _get_bonus(&"hit_speed_duration")
	cooldown_multiplier = 1.0 - minf(COOLDOWN_CAP, _get_bonus(&"cooldown"))
	magnet_radius = BASE_MAGNET_RADIUS * (1.0 + _get_bonus(&"magnet"))


func damage(base: int) -> int:
	return roundi(base * (1.0 + _get_bonus(&"damage")))


func incoming_damage(base: int) -> int:
	return maxi(1, roundi(base * (1.0 - _get_bonus(&"mitigation"))))


func move_speed(boosted: bool) -> float:
	var extra := _get_bonus(&"hit_speed") if boosted else 0.0
	return BASE_MOVE_SPEED * (1.0 + _get_bonus(&"move_speed") + extra)


func stone_amount(base: int) -> int:
	return roundi(base * (1.0 + _get_bonus(&"stone_amount")))


func kill_heal(health: int, maximum: int) -> int:
	var amount := _get_bonus(&"kill_heal")
	if health < maximum * _get_bonus(&"low_health_threshold"):
		amount *= 1.0 + _get_bonus(&"low_health_kill_heal")
	return int(amount)


func _get_bonus(stat: StringName) -> float:
	return _bonuses.get(stat, 0.0)
