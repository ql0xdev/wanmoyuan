extends RefCounted

const Catalog = preload("res://scripts/artifact_catalog.gd")
const CAPACITY := 6

class Offer:
	var cost := 0
	var slot := -1
	var materials: Array[int] = []
	var reason := ""

var slots: Array[StringName] = []


func _init() -> void:
	slots.resize(CAPACITY)
	slots.fill(&"")


func count(id: StringName) -> int:
	return slots.count(id)


func offer(id: StringName, balance: int) -> Offer:
	var result := Offer.new()
	if not Catalog.ITEMS.has(id):
		result.reason = "未知法宝"
		return result
	var item: Dictionary = Catalog.ITEMS[id]
	result.cost = Catalog.price(id)
	result.slot = slots.find(&"")
	if item.has("recipe"):
		if count(id) > 0:
			result.reason = "已持有"
			return result
		var remaining: Dictionary = item.recipe.duplicate()
		for i in range(CAPACITY):
			var material := slots[i]
			if int(remaining.get(material, 0)) > 0:
				remaining[material] -= 1
				result.materials.append(i)
				result.cost -= Catalog.price(material)
		if result.materials.is_empty():
			result.reason = "缺少材料"
			return result
		# 先消费已有材料再放入成装，所以满栏也可以合成。
		result.slot = result.materials[0]
	if result.slot < 0:
		result.reason = "法宝栏已满"
	elif balance < result.cost:
		result.reason = "灵石不足"
	return result


func purchase(id: StringName, balance: int) -> Offer:
	var result := offer(id, balance)
	if result.reason.is_empty():
		for index in result.materials:
			slots[index] = &""
		slots[result.slot] = id
	return result
