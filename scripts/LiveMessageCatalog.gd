class_name LiveMessageCatalog

const PATH := "res://assets/data/live_messages.json"
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


static func notices() -> Array:
	var value = data().get("notices", [])
	return value if value is Array else []


static func mail() -> Array:
	var value = data().get("mail", [])
	return value if value is Array else []


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	for group in [notices(), mail()]:
		for item in group:
			var id := String(item.get("id", ""))
			if id.is_empty() or ids.has(id):
				errors.append("공지/우편 ID 누락 또는 중복: %s" % id)
			ids[id] = true
	return errors
