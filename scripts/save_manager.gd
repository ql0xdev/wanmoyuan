extends Node

const SAVE_PATH := "user://save.cfg"
const SAVE_VERSION := 5
const V4_SAVE_VERSION := 4
const LEGACY_VERSION := 1
const Catalog = preload("res://scripts/cultivation_catalog.gd")
const Equipment = preload("res://scripts/equipment_catalog.gd")
const Forge = preload("res://scripts/forge_catalog.gd")
const MAX_BALANCE := 9223372036854775807
const DEFAULT_PROFILE := {
	"spirit_stones": 0,
	"iron": 0,
	"forge_count": 0,
	"realm": "qi_refining",
	"skill_points": 0,
	"learned_skills": Catalog.STARTER_SKILLS,
	"passive_levels": {},
	"equipment_storage": [],
	"equipped": {},
	"secret_realm_progress": {},
}

var _profile := DEFAULT_PROFILE.duplicate(true)
var _has_profile := false
var _load_error: Error = OK
var _forge_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_forge_rng.randomize()
	_load_error = _load_profile()
	if _load_error != OK:
		push_warning("无法读取修行存档 %s：%s" % [SAVE_PATH, error_string(_load_error)])


func has_profile() -> bool:
	return _has_profile


func load_error() -> Error:
	return _load_error


func spirit_stones() -> int:
	return _profile["spirit_stones"]


func iron() -> int:
	return _profile.iron


func forge_count() -> int:
	return _profile.forge_count


func realm_name() -> String:
	return Catalog.REALMS[realm()].name


func realm() -> String:
	return _profile["realm"]


func skill_points() -> int:
	return _profile["skill_points"]


func learned_skills() -> Array:
	return _profile["learned_skills"].duplicate()


func passive_levels() -> Dictionary:
	return _profile["passive_levels"].duplicate()


func storage() -> Array:
	return _profile["equipment_storage"].duplicate(true)


func equipment_count() -> int:
	return _profile["equipment_storage"].size()


func equipped_items() -> Dictionary:
	var result := {}
	for item: Dictionary in _profile["equipment_storage"]:
		if _profile["equipped"].get(item.slot, 0) == item.id:
			result[item.slot] = item.duplicate(true)
	return result


func is_unlocked(secret_realm: String) -> bool:
	return Catalog.ABYSSES.has(secret_realm) and Catalog.realm_at_least(realm(), Catalog.ABYSSES[secret_realm].realm)


func valid_loadout(loadout: Array) -> bool:
	if loadout.size() > Catalog.MAX_LOADOUT or Catalog.first_attack(loadout).is_empty():
		return false
	var seen := {}
	for skill: Variant in loadout:
		if not skill is String or seen.has(skill) or not _profile["learned_skills"].has(skill):
			return false
		seen[skill] = true
	return true


func has_cleared(secret_realm: String) -> bool:
	return _profile["secret_realm_progress"].get(secret_realm, false)


func ensure_profile() -> Error:
	if _has_profile:
		return OK
	return save_profile()


func save_profile() -> Error:
	return _commit_profile(_profile)


func settle_run(stones: int, cleared: bool, abyss := Catalog.DEFAULT_ABYSS, loot: Array = [], gained_iron := 0) -> Error:
	if stones < 0 or stones > MAX_BALANCE - spirit_stones() or gained_iron < 0 \
			or gained_iron > MAX_BALANCE - iron() or not is_unlocked(abyss):
		return ERR_INVALID_PARAMETER
	if equipment_count() + loot.size() > Equipment.STORAGE_CAPACITY:
		return ERR_OUT_OF_MEMORY
	var next_profile := _profile.duplicate(true)
	next_profile["spirit_stones"] = spirit_stones() + stones
	next_profile["iron"] = iron() + gained_iron
	if cleared:
		next_profile["secret_realm_progress"][abyss] = true
	var used_ids := {}
	for item: Dictionary in next_profile["equipment_storage"]:
		used_ids[item.id] = true
	var next_id := 1
	for item: Variant in loot:
		if not Equipment.is_valid(item):
			return ERR_INVALID_DATA
		while used_ids.has(next_id):
			next_id += 1
		var stored: Dictionary = item.duplicate(true)
		stored["id"] = next_id
		stored["star"] = item.get("star", 0)
		next_id += 1
		next_profile["equipment_storage"].append(stored)
	return _commit_profile(next_profile)


func breakthrough() -> Error:
	var target: String = Catalog.REALMS[realm()].next
	if target.is_empty():
		return ERR_UNAVAILABLE
	var cost: int = Catalog.REALMS[target].cost
	if spirit_stones() < cost:
		return ERR_UNAVAILABLE
	var next_profile := _profile.duplicate(true)
	next_profile["spirit_stones"] -= cost
	next_profile["realm"] = target
	next_profile["skill_points"] += Catalog.BREAKTHROUGH_POINTS
	return _commit_profile(next_profile)


func learn_skill(id: String) -> Error:
	if not Catalog.SKILL_DATA.has(id) or _profile["learned_skills"].has(id):
		return ERR_INVALID_PARAMETER
	var cost: int = Catalog.SKILL_DATA[id].cost
	if skill_points() < cost:
		return ERR_UNAVAILABLE
	var next_profile := _profile.duplicate(true)
	next_profile["skill_points"] -= cost
	next_profile["learned_skills"].append(id)
	return _commit_profile(next_profile)


func train_passive(id: String) -> Error:
	if not Catalog.PASSIVES.has(id):
		return ERR_INVALID_PARAMETER
	var level: int = _profile["passive_levels"].get(id, 0)
	if skill_points() < 1 or level >= Catalog.PASSIVES[id].max:
		return ERR_UNAVAILABLE
	var next_profile := _profile.duplicate(true)
	next_profile["skill_points"] -= 1
	next_profile["passive_levels"][id] = level + 1
	return _commit_profile(next_profile)


func change_equipment(id: int, equip: bool) -> Error:
	var index := _equipment_index(id)
	if index < 0:
		return ERR_INVALID_PARAMETER
	var slot: String = _profile["equipment_storage"][index].slot
	var next_profile := _profile.duplicate(true)
	if equip:
		next_profile["equipped"][slot] = id
	elif next_profile["equipped"].get(slot) == id:
		next_profile["equipped"].erase(slot)
	else:
		return ERR_INVALID_PARAMETER
	return _commit_profile(next_profile)


func salvage_equipment(id: int) -> Error:
	var index := _equipment_index(id)
	if index < 0:
		return ERR_INVALID_PARAMETER
	var item: Dictionary = _profile["equipment_storage"][index]
	var value: int = Equipment.SALVAGE[item.quality]
	var iron_value: int = Forge.IRON_SALVAGE[item.quality]
	if spirit_stones() > MAX_BALANCE - value or iron() > MAX_BALANCE - iron_value:
		return ERR_INVALID_DATA
	var next_profile := _profile.duplicate(true)
	next_profile["equipment_storage"].remove_at(index)
	if next_profile["equipped"].get(item.slot) == id:
		next_profile["equipped"].erase(item.slot)
	next_profile["spirit_stones"] += value
	next_profile["iron"] += iron_value
	return _commit_profile(next_profile)


func forge_equipment(slot: String, tier: int) -> Dictionary:
	if not Equipment.SLOTS.has(slot) or tier < 0 or tier > Catalog.REALMS[realm()].rank:
		return {"error": ERR_INVALID_PARAMETER}
	if equipment_count() >= Equipment.STORAGE_CAPACITY:
		return {"error": ERR_OUT_OF_MEMORY}
	var cost: Vector2i = Forge.COSTS[tier]
	if iron() < cost.x or spirit_stones() < cost.y or forge_count() >= MAX_BALANCE:
		return {"error": ERR_UNAVAILABLE}
	var roll := Forge.craft(slot, tier, forge_count(), _forge_rng)
	var next_profile := _profile.duplicate(true)
	var next_id := 1
	var existing := {}
	for item: Dictionary in next_profile.equipment_storage:
		existing[item.id] = true
	while existing.has(next_id):
		next_id += 1
	roll.item["id"] = next_id
	next_profile.equipment_storage.append(roll.item)
	next_profile.spirit_stones -= cost.y
	next_profile.iron -= cost.x
	next_profile.forge_count += 1
	var error := _commit_profile(next_profile)
	if error != OK:
		return {"error": error}
	return {"error": OK, "item": roll.item.duplicate(true), "masterwork": roll.masterwork}


func star_equipment(id: int, ids: Array) -> Error:
	var index := _equipment_index(id)
	if index < 0:
		return ERR_INVALID_PARAMETER
	var item: Dictionary = _profile.equipment_storage[index]
	var cost := Forge.star_cost(item)
	if not Forge.can_star(cost, iron(), ids.size()):
		return ERR_UNAVAILABLE
	if ids.size() != cost.y:
		return ERR_INVALID_PARAMETER
	var eligible := {}
	for candidate: Dictionary in Forge.sacrifices(item, _profile.equipment_storage, equipped_items()):
		eligible[candidate.id] = true
	for sacrifice: Variant in ids:
		if not sacrifice is int or not eligible.erase(sacrifice):
			return ERR_INVALID_PARAMETER
	var next_profile := _profile.duplicate(true)
	next_profile.equipment_storage[index].star += 1
	for i in range(next_profile.equipment_storage.size() - 1, -1, -1):
		if ids.has(next_profile.equipment_storage[i].id):
			next_profile.equipment_storage.remove_at(i)
	next_profile.iron -= cost.x
	return _commit_profile(next_profile)


func _equipment_index(id: int) -> int:
	for i in range(equipment_count()):
		if _profile["equipment_storage"][i].id == id:
			return i
	return -1


func _load_profile() -> Error:
	if not FileAccess.file_exists(SAVE_PATH) and not DirAccess.dir_exists_absolute(SAVE_PATH):
		return OK
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		return error
	var legacy := not config.has_section_key("save", "save_version")
	var version: Variant = config.get_value("save", "version" if legacy else "save_version", 0)
	if not version is int or (version != LEGACY_VERSION if legacy else version not in [V4_SAVE_VERSION, SAVE_VERSION]):
		return ERR_INVALID_DATA

	var loaded := {}
	for key: String in DEFAULT_PROFILE:
		var value: Variant = config.get_value("profile", key, 0 if version < SAVE_VERSION and key in ["iron", "forge_count"] else null)
		if typeof(value) != typeof(DEFAULT_PROFILE[key]):
			return ERR_INVALID_DATA
		loaded[key] = value
	if version < SAVE_VERSION:
		for item: Variant in loaded.equipment_storage:
			if item is Dictionary and not item.has("star"):
				item["star"] = 0
	if not _valid_profile(loaded):
		return ERR_INVALID_DATA
	_profile = loaded
	_has_profile = true
	return OK


func _valid_profile(profile: Dictionary) -> bool:
	if not Catalog.REALMS.has(profile.realm) or profile.spirit_stones < 0 or profile.skill_points < 0 \
			or profile.iron < 0 or profile.forge_count < 0:
		return false
	if profile.skill_points > (Catalog.REALMS.size() - 1) * Catalog.BREAKTHROUGH_POINTS:
		return false
	var seen := {}
	for skill: Variant in profile.learned_skills:
		if not skill is String or not Catalog.SKILL_DATA.has(skill) or seen.has(skill):
			return false
		seen[skill] = true
	for skill: String in Catalog.STARTER_SKILLS:
		if not seen.has(skill):
			return false
	for id: Variant in profile.passive_levels:
		var level: Variant = profile.passive_levels[id]
		if not Catalog.PASSIVES.has(id) or not level is int or level < 1 or level > Catalog.PASSIVES[id].max:
			return false
	for abyss: Variant in profile.secret_realm_progress:
		if not Catalog.ABYSSES.has(abyss) or not profile.secret_realm_progress[abyss] is bool:
			return false
	if profile.equipment_storage.size() > Equipment.STORAGE_CAPACITY:
		return false
	var slots_by_id := {}
	for item: Variant in profile.equipment_storage:
		if not Equipment.is_valid(item) or not item.has("star") or not item.get("id") is int or item.id < 1 or slots_by_id.has(item.id):
			return false
		slots_by_id[item.id] = item.slot
	for slot: Variant in profile.equipped:
		if not Equipment.SLOTS.has(slot) or slots_by_id.get(profile.equipped[slot]) != slot:
			return false
	return true


func _commit_profile(next_profile: Dictionary) -> Error:
	# 读档失败时保留原文件；写失败时保留旧档和内存数据，允许本局重试。
	if _load_error != OK:
		return _load_error
	var config := ConfigFile.new()
	config.set_value("save", "save_version", SAVE_VERSION)
	for key: String in next_profile:
		config.set_value("profile", key, next_profile[key])
	var temp_path := SAVE_PATH + ".tmp"
	var error := config.save(temp_path)
	if error == OK:
		error = DirAccess.rename_absolute(temp_path, SAVE_PATH)
	if error != OK:
		push_warning("无法保存修行存档 %s：%s" % [SAVE_PATH, error_string(error)])
		return error
	_profile = next_profile
	_has_profile = true
	return OK
