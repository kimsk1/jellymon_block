class_name FurnitureRewardCatalog
## 10레벨 단위 가구 보상. 라이브 데이터 수정이 쉽도록 JSON만 원본으로 사용한다.

const PATH := "res://assets/data/furniture_rewards.json"


static func load_rewards() -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	var file := FileAccess.open(PATH, FileAccess.READ)
	if not file:
		push_error("가구 보상 JSON을 열 수 없습니다: %s" % PATH)
		return rewards
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or typeof(parsed.get("rewards", [])) != TYPE_ARRAY:
		push_error("가구 보상 JSON 형식이 올바르지 않습니다: %s" % PATH)
		return rewards
	for raw in parsed.rewards:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var reward: Dictionary = raw.duplicate(true)
		reward["level"] = int(reward.get("level", 0))
		reward["furniture_id"] = String(reward.get("furniture_id", ""))
		rewards.append(reward)
	return rewards


static func reward_for_level(level_number: int) -> Dictionary:
	for reward in load_rewards():
		if int(reward.level) == level_number:
			return reward
	return {}


static func reward_item_ids() -> Array[String]:
	var ids: Array[String] = []
	for reward in load_rewards():
		var id := String(reward.furniture_id)
		if not id.is_empty() and not ids.has(id):
			ids.append(id)
	return ids


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var rewards := load_rewards()
	if rewards.size() != 10:
		errors.append("10단위 가구 보상이 10종이 아님")
	var levels := {}
	var ids := {}
	for reward in rewards:
		var level := int(reward.level)
		var id := String(reward.furniture_id)
		if level < 10 or level > 100 or level % 10 != 0 or levels.has(level):
			errors.append("가구 보상 레벨 오류/중복: %d" % level)
		levels[level] = true
		if id.is_empty() or ids.has(id) or RoomData.item_by_id(id).is_empty():
			errors.append("가구 보상 ID 오류/중복: %s" % id)
		ids[id] = true
	for level in range(10, 101, 10):
		if not levels.has(level):
			errors.append("가구 보상 레벨 누락: %d" % level)
	return errors
