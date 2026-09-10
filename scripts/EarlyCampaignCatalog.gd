class_name EarlyCampaignCatalog

const PATH := "res://assets/data/early_campaign.json"
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


static func chapter_plan(chapter_number: int) -> Dictionary:
	for plan in data().get("chapters", []):
		if int(plan.get("chapter", 0)) == chapter_number:
			return plan
	return {}


static func design_for_level(level_number: int) -> Dictionary:
	if level_number < 1 or level_number > 50:
		return {}
	var chapter := (level_number - 1) / 10 + 1
	var local := (level_number - 1) % 10
	var plan := chapter_plan(chapter)
	if plan.is_empty():
		return {}
	var roles: Array = plan.get("roles", [])
	var result := {
		"arc": String(plan.get("arc", "")),
		"role": String(roles[local]) if local < roles.size() else "구조 원정",
	}
	var signature: Dictionary = plan.get("signature", {}).get(str(level_number), {})
	if not signature.is_empty():
		result["signature"] = signature.duplicate(true)
	return result


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if data().is_empty():
		errors.append("초반 캠페인 데이터를 읽을 수 없습니다")
		return errors
	for chapter in range(1, 6):
		var plan := chapter_plan(chapter)
		if plan.is_empty() or (plan.get("roles", []) as Array).size() != 10:
			errors.append("초반 챕터 %d의 10레벨 역할이 완성되지 않았습니다" % chapter)
	for level_number in range(5, 51, 5):
		if design_for_level(level_number).get("signature", {}).is_empty():
			errors.append("LEVEL %d 시그니처 장면이 없습니다" % level_number)
	return errors
