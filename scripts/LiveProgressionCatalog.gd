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


static func daily_challenge() -> Dictionary:
	var value = data().get("daily_challenge", {})
	return value if value is Dictionary else {}


static func weekly_expedition() -> Dictionary:
	var value = data().get("weekly_expedition", {})
	return value if value is Dictionary else {}


static func daily_challenge_level() -> int:
	var pool: Array = daily_challenge().get("level_pool", [])
	if pool.is_empty():
		return 0
	var date := Time.get_date_dict_from_system()
	var seed := int(date.get("year", 0)) * 372 + int(date.get("month", 0)) * 31 + int(date.get("day", 0))
	return maxi(1, int(pool[posmod(seed, pool.size())]))


static func weekly_expedition_level(step: int) -> int:
	var pools: Array = weekly_expedition().get("level_pools", [])
	if step < 0 or step >= pools.size() or not pools[step] is Array or pools[step].is_empty():
		return 0
	var week_seed := int(Time.get_unix_time_from_system()) / (7 * 24 * 60 * 60)
	var pool: Array = pools[step]
	return maxi(1, int(pool[posmod(week_seed + step * 3, pool.size())]))


static func season() -> Dictionary:
	var value = data().get("season", {})
	return value if value is Dictionary else {}


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if weekly().get("missions", []).size() < 3:
		errors.append("주간 미션은 3개 이상이어야 합니다")
	if daily_challenge().get("level_pool", []).size() < 7:
		errors.append("일일 특별 구조 레벨 풀이 부족합니다")
	if weekly_expedition().get("level_pools", []).size() != 5:
		errors.append("주간 원정은 5단계여야 합니다")
	if season().get("milestones", []).is_empty():
		errors.append("시즌 마일스톤이 비어 있습니다")
	return errors
