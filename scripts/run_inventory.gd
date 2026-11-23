extends RefCounted

const Equipment = preload("res://scripts/equipment_catalog.gd")
const Forge = preload("res://scripts/forge_catalog.gd")

var worn := {}
var bag: Array = []
var _next_id := -1


func setup(equipped: Dictionary) -> void:
	worn = equipped.duplicate(true)


func collect(item: Dictionary) -> int:
	if bag.size() >= Equipment.BAG_CAPACITY:
		return Equipment.SALVAGE[item.quality]
	item["id"] = _next_id
	_next_id -= 1
	bag.append(item)
	return 0


func equip(id: int) -> bool:
	for i in range(bag.size()):
		var item: Dictionary = bag[i]
		if item.id != id:
			continue
		bag.remove_at(i)
		if worn.has(item.slot):
			bag.append(worn[item.slot])
		worn[item.slot] = item
		return true
	return false


func unequip(id: int) -> bool:
	if bag.size() >= Equipment.BAG_CAPACITY:
		return false
	for slot: String in worn:
		if worn[slot].id == id:
			bag.append(worn[slot])
			worn.erase(slot)
			return true
	return false


func new_loot() -> Array:
	var found: Array = []
	for item: Dictionary in bag + worn.values():
		if item.id < 0:
			found.append(item)
	return found


func find(id: int) -> Dictionary:
	for item: Dictionary in bag:
		if item.id == id:
			return item
	for item: Dictionary in worn.values():
		if item.id == id:
			return item
	return {}


func star_equipment(id: int, ids: Array, iron: int) -> bool:
	var item := find(id)
	if id >= 0 or item.is_empty():
		return false
	var cost := Forge.star_cost(item)
	if not Forge.can_star(cost, iron, ids.size()) or ids.size() != cost.y:
		return false
	var eligible := {}
	for candidate: Dictionary in Forge.sacrifices(item, bag, worn):
		if candidate.id < 0:
			eligible[candidate.id] = true
	for sacrifice: Variant in ids:
		if not eligible.erase(sacrifice):
			return false
	item["star"] = item.get("star", 0) + 1
	for i in range(bag.size() - 1, -1, -1):
		if ids.has(bag[i].id):
			bag.remove_at(i)
	return true


func salvage(id: int) -> int:
	if id >= 0:
		return 0
	for i in range(bag.size()):
		if bag[i].id == id:
			var item: Dictionary = bag.pop_at(i)
			return Equipment.SALVAGE[item.quality]
	for slot: String in worn:
		if worn[slot].id == id:
			var item: Dictionary = worn[slot]
			worn.erase(slot)
			return Equipment.SALVAGE[item.quality]
	return 0
