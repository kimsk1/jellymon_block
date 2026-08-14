class_name CharacterCatalog

const PATH := "res://assets/data/character_profiles.json"
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


static func profile(color_id: String) -> Dictionary:
	var value = data().get("profiles", {}).get(color_id, {})
	return value if value is Dictionary else {}


static func interactions() -> Array:
	var value = data().get("interactions", [])
	return value if value is Array else []


static func gimmick(id: String) -> Dictionary:
	var value = data().get("personality_gimmicks", {}).get(id, {})
	return value if value is Dictionary else {}


static func character_texture(color_id: String) -> Texture2D:
	## 성격·주민 데이터는 신규 시스템을 사용하되 원화는 기존 심플 세트를 공유한다.
	return G.jelly_tex(color_id)


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for color_id in G.COLORS:
		var item := profile(String(color_id))
		if item.is_empty():
			errors.append("캐릭터 프로필 누락: %s" % color_id)
		else:
			if item.get("idle", []).size() < 3 or item.get("touch", []).size() < 2:
				errors.append("캐릭터 행동 수 부족: %s" % color_id)
			if String(item.get("silhouette", "")).is_empty():
				errors.append("캐릭터 실루엣 키 누락: %s" % color_id)
			if item.get("favorite_furniture", []).is_empty():
				errors.append("선호 가구 누락: %s" % color_id)
	if interactions().size() < 10:
		errors.append("주민 상호작용은 10종 이상이어야 합니다")
	for gimmick_id in ["shy", "sleepy", "playful", "lonely"]:
		if gimmick(gimmick_id).is_empty():
			errors.append("성격 퍼즐 기믹 누락: %s" % gimmick_id)
	return errors
