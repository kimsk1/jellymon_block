class_name DailyMissionCatalog
## 일일 미션을 APK/PCK에서도 읽을 수 있는 JSON 카탈로그.

const PATH := "res://assets/data/daily_missions.json"
static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("일일 미션 JSON을 열 수 없습니다: %s" % PATH)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_cache = parsed
	return _cache


static func missions() -> Array:
	var value = data().get("missions", [])
	return value if value is Array else []


static func reward() -> Dictionary:
	var value = data().get("chest_reward", {})
	return value if value is Dictionary else {}


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	for mission in missions():
		var id := String(mission.get("id", ""))
		if id.is_empty() or ids.has(id):
			errors.append("일일 미션 ID 누락/중복: %s" % id)
		ids[id] = true
		if int(mission.get("target", 0)) <= 0:
			errors.append("일일 미션 목표값 오류: %s" % id)
	if missions().size() != 3:
		errors.append("일일 미션이 3종이 아님")
	if int(reward().get("stardust", 0)) <= 0:
		errors.append("일일 미션 상자 보상 오류")
	return errors
