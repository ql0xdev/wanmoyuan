extends RefCounted

const Catalog = preload("res://scripts/cultivation_catalog.gd")
const Equipment = preload("res://scripts/equipment_catalog.gd")
const BASE_HEALTH := 100
const BASE_MOVE_SPEED := 200.0
const BASE_MAGNET_RADIUS := 80.0
const COOLDOWN_CAP := 0.40
const MITIGATION_CAP := 0.8

var cooldown_multiplier := 1.0
var magnet_radius := BASE_MAGNET_RADIUS
var _realm: Dictionary = Catalog.REALMS["qi_refining"]
var _passive := {}
var _gear := {}
var _pills := {}


func configure(realm: String, passives: Dictionary, equipment: Dictionary) -> void:
	_realm = Catalog.REALMS[realm]
	_passive.clear()
	for id: String in passives:
		var node: Dictionary = Catalog.PASSIVES[id]
		_passive[node.stat] = node.amount * passives[id]
	rebuild_equipment(equipment)


func rebuild_equipment(equipment: Dictionary) -> void:
	_gear.clear()
	for item: Dictionary in equipment.values():
		for group: Dictionary in [Equipment.base_stats(item), item.affixes]:
			for stat: String in group:
				_gear[stat] = _gear.get(stat, 0.0) + group[stat]
	cooldown_multiplier = maxf(1.0 - COOLDOWN_CAP, _factor("cooldown", -1.0))
	magnet_radius = BASE_MAGNET_RADIUS * _factor("magnet")


func max_health(run_bonus := 0) -> int:
	return roundi((BASE_HEALTH + _passive.get("health_flat", 0.0) + _gear.get("health_flat", 0.0))
		* _realm.power * _factor("health")) + run_bonus


func attack_multiplier() -> float:
	return _realm.power * _factor("damage") * (1.3 if has_pill("rage") else 1.0)


func damage(base: int) -> int:
	return roundi(base * attack_multiplier())


func damage_taken_multiplier() -> float:
	return maxf(1.0 - MITIGATION_CAP, _factor("mitigation", -1.0) * (0.8 if has_pill("guard") else 1.0))


func incoming_damage(base: int) -> int:
	return maxi(1, roundi(base * damage_taken_multiplier()))


func move_speed() -> float:
	return BASE_MOVE_SPEED * _realm.speed * _factor("move_speed")


func stone_multiplier() -> float:
	return _factor("stone_amount") * (1.5 if has_pill("fortune") else 1.0)


func stone_amount(base: int) -> int:
	return roundi(base * stone_multiplier())


func kill_heal() -> int:
	return int(_gear.get("kill_heal", 0))


func has_pill(id: String) -> bool:
	return _pills.has(id)


func use_pill(id: String) -> void:
	_pills[id] = true


func _factor(stat: String, direction := 1.0) -> float:
	return (1.0 + direction * _passive.get(stat, 0.0)) * (1.0 + direction * _gear.get(stat, 0.0))
