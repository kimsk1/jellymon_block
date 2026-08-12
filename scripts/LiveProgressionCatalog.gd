class_name LiveProgressionCatalog

const PATH := "res://assets/data/live_progression.json"
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


static func weekly() -> Dictionary:
	var value = data().get("weekly", {})
	return value if value is Dictionary else {}


static func season() -> Dictionary:
	var value = data().get("season", {})
	return value if value is Dictionary else {}


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if weekly().get("missions", []).size() < 3:
		errors.append("주간 미션은 3개 이상이어야 합니다")
	if season().get("milestones", []).is_empty():
		errors.append("시즌 마일스톤이 비어 있습니다")
	return errors
