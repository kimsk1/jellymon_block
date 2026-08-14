class_name MetaProgressionCatalog

const PATH := "res://assets/data/meta_progression.json"
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


static func hero_stages() -> Array:
	var value = data().get("hero_growth", [])
	return value if value is Array else []


static func hero_stage(total_stars: int) -> int:
	var result := 1
	for entry in hero_stages():
		if total_stars >= int(entry.get("stars", 0)):
			result = int(entry.get("stage", result))
	return result


static func hero_stage_data(stage: int) -> Dictionary:
	for entry in hero_stages():
		if int(entry.get("stage", 0)) == stage:
			return entry
	return {}


static func max_hero_stage() -> int:
	return hero_stages().size()


static func bond_levels() -> Array:
	var value = data().get("resident_bond", [])
	return value if value is Array else []


static func bond_level(affection: int) -> int:
	var result := 1
	for entry in bond_levels():
		if affection >= int(entry.get("affection", 0)):
			result = int(entry.get("level", result))
	return result


static func bond_level_data(level: int) -> Dictionary:
	for entry in bond_levels():
		if int(entry.get("level", 0)) == level:
			return entry
	return {}


static func next_bond_affection(level: int) -> int:
	var next := bond_level_data(level + 1)
	return int(next.get("affection", -1))


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var previous_stars := -1
	for entry in hero_stages():
		var stars := int(entry.get("stars", -1))
		if stars <= previous_stars:
			errors.append("대표 젤리몬 성장 별 기준은 오름차순이어야 합니다")
		previous_stars = stars
	if hero_stages().size() < 6:
		errors.append("대표 젤리몬 성장은 6단계 이상이어야 합니다")
	var previous_affection := -1
	for entry in bond_levels():
		var affection := int(entry.get("affection", -1))
		if affection <= previous_affection:
			errors.append("주민 친밀도 기준은 오름차순이어야 합니다")
		previous_affection = affection
	if bond_levels().size() < 10:
		errors.append("주민 친밀도는 10단계 이상이어야 합니다")
	return errors
