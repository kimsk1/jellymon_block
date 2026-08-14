class_name GameBalanceCatalog

const PATH := "res://assets/data/game_balance.json"
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


static func economy(key: String, fallback: int = 0) -> int:
	return int(data().get("economy", {}).get(key, fallback))


static func retention(key: String, fallback: int = 0) -> int:
	return int(data().get("retention", {}).get(key, fallback))


static func analytics(key: String, fallback: int = 0) -> int:
	return int(data().get("analytics", {}).get(key, fallback))


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if economy("max_energy") <= 0:
		errors.append("최대 하트는 1 이상이어야 합니다")
	if economy("energy_regen_seconds") <= 0:
		errors.append("하트 회복 시간은 1초 이상이어야 합니다")
	if economy("continue_stardust_cost") <= 0:
		errors.append("이어하기 비용은 1 이상이어야 합니다")
	if retention("resident_affection_daily_cap") <= 0:
		errors.append("주민 일일 친밀도 상한은 1 이상이어야 합니다")
	return errors
