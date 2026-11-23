extends RefCounted

const Equipment = preload("res://scripts/equipment_catalog.gd")
const IRON_SALVAGE := [2, 6, 16, 40]
const COSTS := [
	Vector2i(30, 200), Vector2i(40, 500), Vector2i(50, 1000),
	Vector2i(80, 2000), Vector2i(120, 4000), Vector2i(200, 8000),
]
const RANKS := [
	{"name": "学徒", "minimum": 0, "weights": [50, 32, 15, 3]},
	{"name": "工匠", "minimum": 20, "weights": [35, 35, 22, 8]},
	{"name": "大师", "minimum": 50, "weights": [20, 35, 30, 15]},
	{"name": "宗师", "minimum": 100, "weights": [5, 30, 40, 25]},
]
const MASTERWORK_CHANCE := 5
const STAR_COSTS := [Vector2i(20, 1), Vector2i(40, 1), Vector2i(80, 2), Vector2i(160, 2), Vector2i(300, 3)]


static func rank_index(count: int) -> int:
	for i in range(RANKS.size() - 1, -1, -1):
		if count >= RANKS[i].minimum:
			return i
	return 0


static func rank_text(count: int) -> String:
	var i := rank_index(count)
	if i == RANKS.size() - 1:
		return "%s %d 次" % [RANKS[i].name, count]
	return "%s %d/%d" % [RANKS[i].name, count, RANKS[i + 1].minimum]


static func quality_at(count: int, draw: int) -> int:
	var weights: Array = RANKS[rank_index(count)].weights
	for quality in range(weights.size()):
		if draw <= weights[quality]:
			return quality
		draw -= weights[quality]
	return Equipment.QUALITIES.size() - 1


static func craft(slot: String, tier: int, count: int, rng: RandomNumberGenerator) -> Dictionary:
	var natural := quality_at(count, rng.randi_range(1, 100))
	var masterwork := rng.randi_range(1, 100) <= MASTERWORK_CHANCE
	var quality := mini(natural + int(masterwork), Equipment.QUALITIES.size() - 1)
	return {"item": Equipment.create_item(slot, tier, quality, rng), "masterwork": masterwork, "natural_quality": natural}


static func salvage_text(quality: int) -> String:
	return "灵石+%d　玄铁+%d" % [Equipment.SALVAGE[quality], IRON_SALVAGE[quality]]


static func star_cost(item: Dictionary) -> Vector2i:
	var stars: int = item.get("star", 0)
	return STAR_COSTS[stars] if stars < STAR_COSTS.size() else Vector2i.ZERO


static func sacrifices(item: Dictionary, items: Array, worn: Dictionary) -> Array:
	var result := items.filter(func(candidate: Dictionary) -> bool:
		return candidate.id != item.id and candidate.slot == item.slot \
			and worn.get(candidate.slot, {}).get("id", 0) != candidate.id)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		# 低品质、低星、低等级优先；相同项用 ID 保持稳定。
		if a.quality != b.quality:
			return a.quality < b.quality
		if a.get("star", 0) != b.get("star", 0):
			return a.get("star", 0) < b.get("star", 0)
		return a.tier < b.tier if a.tier != b.tier else a.id < b.id)
	return result


static func can_star(cost: Vector2i, iron: int, count: int) -> bool:
	return cost != Vector2i.ZERO and iron >= cost.x and count >= cost.y


static func star_hint(cost: Vector2i, iron: int, count: int) -> String:
	if cost == Vector2i.ZERO:
		return "已达 5 星"
	if not can_star(cost, iron, count):
		return "升星缺材料：玄铁 %d/%d · 同部位祭品 %d/%d" % [iron, cost.x, count, cost.y]
	return "升星需玄铁 %d · 同部位祭品 %d 件" % [cost.x, cost.y]
