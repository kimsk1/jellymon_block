class_name JellyDexCatalog

const PATH := "res://assets/data/jelly_dex.json"
static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_cache = parsed
	return _cache


static func entries() -> Array:
	var value = data().get("entries", [])
	return value if value is Array else []


static func milestones() -> Array:
	var value = data().get("milestones", [])
	return value if value is Array else []


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var colors := {}
	for entry in entries():
		var color := String(entry.get("color", ""))
		if not G.COLORS.has(color) or colors.has(color):
			errors.append("젤리 도감 색상 오류: %s" % color)
		colors[color] = true
	if entries().size() != G.COLORS.size():
		errors.append("젤리 도감 종류 수 오류")
	return errors
