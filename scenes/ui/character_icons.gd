extends RefCounted

const SLOT_PATHS := {
	"hat": "M5 21h22v5H5z M7 21l-2-12 7 6 4-8 4 8 7-6-2 12",
	"weapon": "M9 21 24 5l4-1-1 4-15 16 M6 19l7 7 M9 23l-5 5",
	"gloves": "M9 25 5 16l3-2 3 4V9a2 2 0 0 1 4 0v6-9a2 2 0 0 1 4 0v9-6a2 2 0 0 1 4 0v7-4a2 2 0 0 1 4 0v8l-4 5v3H10z M10 24h13",
	"accessory": "M9 5c0 5 7 8 7 9s7-4 7-9 M16 12l8 7-8 8-8-8z M16 17l3 2-3 4-3-4z",
	"armor": "M10 6 3 12l4 7 4-2 1 10h8l1-10 4 2 4-7-7-6-6 6z M16 12v15 M12 22h8",
	"pants": "M8 5h16l3 22h-8l-3-13-3 13H5z M8 9h16",
	"boots": "M7 5h11v12l8 3 2 4v3H5v-7l2-4z M5 23h22 M8 9h10 M8 13h10",
}
const SKILL_PATHS := {
	"sword": "M8 22 24 5l4-1-1 4-16 17 M5 20l8 8 M8 24l-4 4",
	"sword_storm": "M16 4v24 M9 11l7-7 7 7 M4 15l4 11m20-11-4 11 M11 24h10",
	"lightning": "M18 3 6 18h10l-2 11 12-16h-9z",
	"orbs": "M16 3 20 9 16 15 12 9z M7 15l4 6-4 6-4-6z M25 15l4 6-4 6-4-6z",
	"ice": "M16 3v26 M5 9l22 14 M5 23 27 9 M12 5l4 5 4-5 M12 27l4-5 4 5",
	"heal": "M13 5h6v8h8v6h-8v8h-6v-8H5v-6h8z",
	"fire": "M16 3c2 7-5 9-3 14 2 0 5-4 6-7 6 5 7 10 4 13-3 7-14 6-16-1-2-6 4-10 9-19z",
	"blink": "M4 14h22 M20 8l6 6-6 6 M28 22H6 M12 28l-6-6 6-6",
	"dash": "M5 8l8 8-8 8 M12 8l8 8-8 8 M19 8l8 8-8 8",
	"wisp": "M16 4c9 7 13 11 9 17-4 6-16 7-20 1-2-3 0-7 4-8-1 7 10 8 12 2 1-3-2-8-5-12z",
	"bell": "M8 22V12a8 8 0 0 1 16 0v10l3 3H5z M13 28h6 M16 5V3",
	"shield": "M16 3 27 7v10c0 4-7 10-11 12C12 27 5 21 5 17V7z M11 16l4 4 6-7",
}

static var _cache := {}


static func slot(id: String) -> Texture2D:
	return _icon("slot/" + id, SLOT_PATHS[id])


static func skill(id: String) -> Texture2D:
	return _icon("skill/" + id, SKILL_PATHS.get(id, "M16 4l12 12-12 12L4 16z"))


static func _icon(key: String, line: String) -> Texture2D:
	if not _cache.has(key):
		var image := Image.new()
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 32 32"><path d="%s" fill="none" stroke="white" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round"/></svg>' % line
		if image.load_svg_from_string(svg) == OK:
			_cache[key] = ImageTexture.create_from_image(image)
	return _cache.get(key)
