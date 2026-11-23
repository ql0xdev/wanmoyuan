extends RefCounted

const Equipment = preload("res://scripts/equipment_catalog.gd")
const ITEM_COUNT := 6
const BASE_PRICES := [100, 250, 600, 1500]
const WEIGHTS := [40, 35, 20, 5]


static func price(tier: int, quality: int) -> int:
	return BASE_PRICES[quality] * (1 << tier)


static func quality_at(roll: int) -> int:
	for quality in range(WEIGHTS.size()):
		roll -= WEIGHTS[quality]
		if roll <= 0:
			return quality
	return WEIGHTS.size() - 1


static func roll_stock(tier: int, rng: RandomNumberGenerator) -> Array:
	var stock := []
	var slots := Equipment.SLOTS.keys()
	for i in range(ITEM_COUNT):
		var quality := quality_at(rng.randi_range(1, 100))
		var slot: String = slots[rng.randi_range(0, slots.size() - 1)]
		stock.append({"id": i + 1, "price": price(tier, quality), "sold": false,
			"item": Equipment.create_item(slot, tier, quality, rng)})
	return stock
