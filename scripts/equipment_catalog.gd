extends RefCounted

const SLOTS := {
	"weapon": {"name": "武器", "item": "灵剑", "base": {"damage": 0.22}},
	"armor": {"name": "护甲", "item": "道袍", "base": {"health": 0.18, "mitigation": 0.04}},
	"accessory": {"name": "饰品", "item": "灵佩", "base": {"move_speed": 0.05, "cooldown": 0.04, "stone_amount": 0.08}},
}
const TIERS := ["炼气", "筑基", "金丹", "元婴", "化神", "渡劫"]
const QUALITIES := ["法器", "灵器", "宝器", "仙器"]
const COLORS := [Color("#b0b8c0"), Color("#4caf50"), Color("#42a5f5"), Color("#ab47bc")]
const SALVAGE := [5, 15, 40, 100]
const BAG_CAPACITY := 12
const STORAGE_CAPACITY := 200
const AFFIXES := {
	"damage": {"name": "攻击", "min": 0.08, "max": 0.14},
	"health_flat": {"name": "气血上限", "min": 8.0, "max": 15.0},
	"move_speed": {"name": "移速", "min": 0.03, "max": 0.06},
	"cooldown": {"name": "冷却缩减", "min": 0.03, "max": 0.06},
	"magnet": {"name": "灵晶拾取范围", "min": 0.10, "max": 0.18},
	"kill_heal": {"name": "击杀回血", "min": 1.0, "max": 2.0},
	"stone_amount": {"name": "灵石掉落", "min": 0.12, "max": 0.22},
	"mitigation": {"name": "受伤减免", "min": 0.03, "max": 0.06},
}


static func roll(tier: int, purple_chance: float, rng: RandomNumberGenerator) -> Dictionary:
	var slot: String = SLOTS.keys()[rng.randi_range(0, SLOTS.size() - 1)]
	var quality := 3
	if rng.randf() >= purple_chance:
		var roll_value := rng.randi_range(1, 97)
		quality = 0 if roll_value <= 55 else (1 if roll_value <= 85 else 2)
	return create_item(slot, tier, quality, rng)


static func create_item(slot: String, tier: int, quality: int, rng: RandomNumberGenerator) -> Dictionary:
	var choices := AFFIXES.keys()
	var affixes := {}
	var scale := float(1 << tier)
	for i in range(quality):
		var index := rng.randi_range(0, choices.size() - 1)
		var stat: String = choices.pop_at(index)
		var rule: Dictionary = AFFIXES[stat]
		var value := rng.randf_range(rule.min, rule.max) * scale
		affixes[stat] = roundf(value) if _flat(stat) else snappedf(value, 0.01)
	return {"slot": slot, "tier": tier, "quality": quality, "affixes": affixes, "star": 0}


static func is_valid(item: Variant) -> bool:
	if not item is Dictionary:
		return false
	var star: Variant = item.get("star", 0)
	if not star is int or star < 0 or star > 5:
		return false
	var tier: Variant = item.get("tier")
	var quality: Variant = item.get("quality")
	var affixes: Variant = item.get("affixes")
	if not SLOTS.has(item.get("slot")) or not tier is int or tier < 0 or tier >= TIERS.size():
		return false
	if not quality is int or quality < 0 or quality >= QUALITIES.size() or not affixes is Dictionary or affixes.size() != quality:
		return false
	for stat: Variant in affixes:
		var value: Variant = affixes[stat]
		if not AFFIXES.has(stat) or not (value is float or value is int):
			return false
		# 保留旧档的宽松上限，同时允许高阶百分比词条大于 100%。
		var limit := 1000.0 if _flat(stat) else maxf(1.0, snappedf(AFFIXES[stat].max * (1 << int(tier)), 0.01))
		if not is_finite(value) or value <= 0.0 or float(value) > limit + 0.000001:
			return false
	return true


static func base_stats(item: Dictionary) -> Dictionary:
	var result: Dictionary = SLOTS[item.slot].base.duplicate()
	var factor := float(1 << int(item.tier)) * (1.0 + 0.15 * int(item.get("star", 0)))
	for stat: String in result:
		result[stat] *= factor
	return result


static func title(item: Dictionary) -> String:
	return "%s级 · %s · %s" % [TIERS[item.tier], QUALITIES[item.quality], SLOTS[item.slot].item]


static func describe(item: Dictionary) -> String:
	var details := PackedStringArray()
	for group: Dictionary in [base_stats(item), item.affixes]:
		var parts := PackedStringArray()
		for stat: String in group:
			var name: String = AFFIXES[stat].name if AFFIXES.has(stat) else "气血上限"
			var amount := ("+%d" if _flat(stat) else "+%d%%") % roundi(group[stat] * (1.0 if _flat(stat) else 100.0))
			parts.append("[color=#56d4dd]%s[/color] [color=#f0c674]%s[/color]" % [name, amount])
		if not parts.is_empty():
			details.append(("基础：" if details.is_empty() else "词条：") + "　".join(parts))
	return "\n".join(details)


static func _flat(stat: String) -> bool:
	return stat in ["health_flat", "kill_heal"]


static func higher_quality(a: Dictionary, b: Dictionary) -> bool:
	if a.quality != b.quality:
		return a.quality > b.quality
	if a.tier != b.tier:
		return a.tier > b.tier
	return a.id < b.id
