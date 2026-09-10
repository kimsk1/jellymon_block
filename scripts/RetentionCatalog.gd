class_name RetentionCatalog

const PATH := "res://assets/data/retention_systems.json"
static var _cache := {}


static func data() -> Dictionary:
	if not _cache.is_empty(): return _cache
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary: _cache = parsed
	return _cache


static func requests() -> Array:
	return data().get("resident_requests", [])


static func request_line(color_id: String) -> String:
	return String(data().get("request_lines", {}).get(color_id, "함께해 줘서 고마워!"))


static func season() -> Dictionary:
	return data().get("season", {})


static func season_days_remaining() -> int:
	var duration := maxi(1, int(season().get("duration_days", 28)))
	var day_index := int(Time.get_unix_time_from_system()) / (24 * 60 * 60)
	return duration - posmod(day_index, duration)


static func modifiers() -> Array:
	return data().get("challenge_modifiers", [])


static func modifier_for_seed(seed: int) -> Dictionary:
	var values := modifiers()
	return values[posmod(seed, values.size())] if not values.is_empty() else {}


static func towns() -> Array:
	return data().get("town_districts", [])


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if requests().size() < 5: errors.append("주민 부탁 템플릿 부족")
	if int(season().get("levels", 0)) != 20 or int(season().get("duration_days", 0)) != 28: errors.append("28일 시즌 구성 오류")
	if modifiers().size() < 4: errors.append("특별 구조 규칙 부족")
	if towns().size() != 5: errors.append("마을 복구 구역 부족")
	return errors
