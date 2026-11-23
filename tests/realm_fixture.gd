extends RefCounted

const Catalog = preload("res://scripts/cultivation_catalog.gd")
const TRIBULATION_BUDGET := 230420


static func advance(save: Node) -> bool:
	while save.realm_layer() < Catalog.REALM_LAYER_CAP:
		if save.advance_realm_layer() != OK:
			return false
	return save.breakthrough() == OK


static func migrations(profile: Dictionary) -> void:
	profile.realm_layer = 1
	profile.cave_shop = []
	profile.evolutions = {}
