extends RefCounted

const Catalog = preload("res://scripts/cultivation_catalog.gd")
const Equipment = preload("res://scripts/equipment_catalog.gd")
const BASE_HEALTH := 100
const BASE_MOVE_SPEED := 200.0
const BASE_MAGNET_RADIUS := 80.0
const COOLDOWN_CAP := 0.40
const MITIGATION_CAP := 0.8
const PANEL_LABELS := ["气血上限", "攻击倍率", "移速", "拾取范围", "冷却缩减", "受伤减免", "灵石掉落倍率", "击杀回血"]

var cooldown_multiplier := 1.0
var magnet_radius := BASE_MAGNET_RADIUS
var _realm: Dictionary = Catalog.REALMS["qi_refining"]
var _layer_factor := 1.0
var _passive := {}
var _gear := {}
var _pills := {}
var _run := {}
var _run_remaining := {}


func configure(realm: String, passives: Dictionary, equipment: Dictionary, layer := 1) -> void:
	_realm = Catalog.REALMS[realm]
	_layer_factor = Catalog.layer_multiplier(layer)
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
	_refresh_derived()


func add_run_stat(stat: String, amount: float) -> void:
	_run[stat] = _run.get(stat, 0.0) + amount
	if stat in ["cooldown", "mitigation"]:
		_run_remaining[stat] = _run_remaining.get(stat, 1.0) * (1.0 - amount)
	_refresh_derived()


func _refresh_derived() -> void:
	cooldown_multiplier = maxf(0.000001, maxf(1.0 - COOLDOWN_CAP, _remaining("cooldown")) \
		* _run_remaining.get("cooldown", 1.0))
	magnet_radius = BASE_MAGNET_RADIUS * _factor("magnet")


func max_health() -> int:
	return roundi((BASE_HEALTH + _passive.get("health_flat", 0.0) + _gear.get("health_flat", 0.0))
		* _realm.power * _layer_factor * _factor("health")) + int(_run.get("health_flat", 0))


func attack_multiplier() -> float:
	return _realm.power * _layer_factor * _factor("damage") * (1.3 if has_pill("rage") else 1.0)


func damage(base: int) -> int:
	return roundi(base * attack_multiplier())


func damage_taken_multiplier() -> float:
	return maxf(1.0 - MITIGATION_CAP, _remaining("mitigation") * (0.8 if has_pill("guard") else 1.0)) \
		* _run_remaining.get("mitigation", 1.0)


func incoming_damage(base: int) -> int:
	return maxi(1, roundi(base * damage_taken_multiplier()))


func move_speed() -> float:
	return BASE_MOVE_SPEED * _realm.speed * _factor("move_speed")


func stone_multiplier() -> float:
	return _factor("stone_amount") * (1.5 if has_pill("fortune") else 1.0)


func stone_amount(base: int) -> int:
	return roundi(base * stone_multiplier())


func kill_heal() -> int:
	return int(_gear.get("kill_heal", 0.0) + _run.get("kill_heal", 0.0))


func panel_values() -> PackedStringArray:
	return PackedStringArray([str(max_health()), "×%.2f" % attack_multiplier(),
		str(roundi(move_speed())), str(roundi(magnet_radius)),
		"%d%%" % roundi((1.0 - cooldown_multiplier) * 100.0),
		"%d%%" % roundi((1.0 - damage_taken_multiplier()) * 100.0),
		"×%.2f" % stone_multiplier(), str(kill_heal())])


func has_pill(id: String) -> bool:
	return _pills.has(id)


func use_pill(id: String) -> void:
	_pills[id] = true


func _factor(stat: String) -> float:
	return (1.0 + _passive.get(stat, 0.0)) * (1.0 + _gear.get(stat, 0.0)) * (1.0 + _run.get(stat, 0.0))


func _remaining(stat: String) -> float:
	# 旧装备/心法上限不变；局内卡牌在其后每次按剩余比例叠乘。
	return maxf(0.0, 1.0 - _passive.get(stat, 0.0)) * maxf(0.0, 1.0 - _gear.get(stat, 0.0))
