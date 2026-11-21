extends RefCounted

# 价格、配方、说明、图标与属性共用一张表。成装价格由直接配方递归计算。
const ITEMS := {
	&"iron_sword": {
		"name": "铁剑", "color": Color("#9bb1c6"), "price": 150,
		"effect": "全部功法伤害 +10%", "stats": {&"damage": 0.10},
	},
	&"thunder_talisman": {
		"name": "雷符", "color": Color("#cbc477"), "price": 150,
		"effect": "功法冷却 -10%（最多 -40%）", "stats": {&"cooldown": 0.10},
	},
	&"swift_boots": {
		"name": "神行靴", "color": Color("#7cc4a5"), "price": 150,
		"effect": "移动速度 +10%", "stats": {&"move_speed": 0.10},
	},
	&"ward": {
		"name": "护身符", "color": Color("#8fa5ce"), "price": 150,
		"effect": "生命上限 +25，立即回复 25 生命", "stats": {&"max_health": 25}, "heal_on_buy": 25,
	},
	&"jade": {
		"name": "聚灵佩", "color": Color("#82d5cc"), "price": 150,
		"effect": "拾取范围 +50%", "stats": {&"magnet": 0.50},
	},
	&"blood_bead": {
		"name": "饮血珠", "color": Color("#ce8188"), "price": 150,
		"effect": "每次击杀回复 1 点生命", "stats": {&"kill_heal": 1},
	},
	&"azure_sword": {
		"name": "青锋剑", "color": Color("#78bbf0"), "recipe": {&"iron_sword": 2},
		"effect": "全伤害 +25%；御剑术飞剑 +1", "stats": {&"damage": 0.25, &"sword_count": 1},
	},
	&"immortal_thunder_sword": {
		"name": "诛仙雷剑", "color": Color("#c49df9"), "recipe": {&"azure_sword": 1, &"thunder_talisman": 1},
		"effect": "全伤害 +30%；雷诀落雷 +1", "stats": {&"damage": 0.30, &"lightning_count": 1},
	},
	&"tortoise_armor": {
		"name": "玄武甲", "color": Color("#8fcaf0"), "recipe": {&"ward": 2},
		"effect": "生命上限 +60；受伤减免 15%", "stats": {&"max_health": 60, &"mitigation": 0.15},
	},
	&"cloud_boots": {
		"name": "追云履", "color": Color("#90e7ac"), "recipe": {&"swift_boots": 2},
		"effect": "移速 +25%；受击后 1.5 秒移速额外 +30%",
		"stats": {&"move_speed": 0.25, &"hit_speed": 0.30, &"hit_speed_duration": 1.5},
	},
	&"spirit_bag": {
		"name": "乾坤袋", "color": Color("#f5d393"), "recipe": {&"jade": 2},
		"effect": "拾取范围翻倍；灵石掉落量 +20%", "stats": {&"magnet": 1.0, &"stone_amount": 0.20},
	},
	&"blood_bodhi": {
		"name": "血菩提", "color": Color("#f3a0aa"), "recipe": {&"blood_bead": 2},
		"effect": "击杀回血 +3；生命低于 30% 时击杀回血翻倍",
		"stats": {&"kill_heal": 3, &"low_health_threshold": 0.30, &"low_health_kill_heal": 1.0},
	},
}


static func price(id: StringName) -> int:
	var item: Dictionary = ITEMS[id]
	if not item.has("recipe"):
		return item.price
	var total := 0
	for material: StringName in item.recipe:
		total += price(material) * int(item.recipe[material])
	return total


static func recipe_text(id: StringName) -> String:
	var parts := PackedStringArray()
	var recipe: Dictionary = ITEMS[id].get("recipe", {})
	for material: StringName in recipe:
		var count: int = recipe[material]
		var title: String = ITEMS[material].name
		parts.append("%s ×%d" % [title, count] if count > 1 else title)
	return " + ".join(parts)
