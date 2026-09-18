class_name ShopCatalog
## 상점 상품은 APK/PCK에도 원본이 포함되는 assets/data/item.json에서 관리한다.

const PATH := "res://assets/data/item.json"
const REQUIRED_IDS := ["stardust_50", "stardust_110", "heart_5", "remove_ads", "supporter_pack", "starter_rescue_pack", "chapter_rescue_pack", "hideout_decor_pack", "season_heart_star_pass"]


static func load_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var file := FileAccess.open(PATH, FileAccess.READ)
	if not file:
		push_error("상점 상품 JSON을 열 수 없습니다: %s" % PATH)
		return items
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("상점 상품 JSON 최상위 형식이 올바르지 않습니다: %s" % PATH)
		return items
	var raw_items = parsed.get("items", [])
	if typeof(raw_items) != TYPE_ARRAY:
		push_error("상점 상품 JSON의 items가 배열이 아닙니다: %s" % PATH)
		return items
	for raw_item in raw_items:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw_item.duplicate(true)
		item["amount"] = int(item.get("amount", 0))
		item["price_krw"] = int(item.get("price_krw", 0))
		item["consumable"] = bool(item.get("consumable", false))
		items.append(item)
	return items


static func item_by_id(id: String) -> Dictionary:
	for item in load_items():
		if String(item.get("id", "")) == id:
			return item
	return {}


static func validate_catalog() -> PackedStringArray:
	var errors := PackedStringArray()
	var items := load_items()
	if items.size() < REQUIRED_IDS.size():
		errors.append("필수 상점 상품 수가 부족함")
	var ids := {}
	for item in items:
		var id := String(item.get("id", ""))
		if id.is_empty() or ids.has(id):
			errors.append("상점 상품 ID가 없거나 중복됨: %s" % id)
		ids[id] = true
		if int(item.get("price_krw", 0)) <= 0:
			errors.append("상점 상품 가격 오류: %s" % id)
	for required_id in REQUIRED_IDS:
		if not ids.has(required_id):
			errors.append("필수 상점 상품 누락: %s" % required_id)
	if int(item_by_id("stardust_50").get("amount", 0)) != 50 or int(item_by_id("stardust_50").get("price_krw", 0)) != 1000:
		errors.append("별가루 50 상품 구성 오류")
	if int(item_by_id("stardust_110").get("amount", 0)) != 110 or int(item_by_id("stardust_110").get("price_krw", 0)) != 2000:
		errors.append("별가루 110 상품 구성 오류")
	var legacy_vip := item_by_id("remove_ads")
	if int(legacy_vip.get("price_krw", 0)) != 3000 or not bool(legacy_vip.get("legacy", false)) or not bool(legacy_vip.get("sale_ended", false)):
		errors.append("레거시 VIP 상품 구성 오류")
	var supporter := item_by_id("supporter_pack")
	if String(supporter.get("type", "")) != "supporter" or bool(supporter.get("consumable", true)) or supporter.has("stardust") or supporter.has("energy") or supporter.has("boosters") or bool(supporter.get("sale_ended", false)):
		errors.append("후원 팩 상품 구성 오류")
	if int(item_by_id("heart_5").get("amount", 0)) != 5 or int(item_by_id("heart_5").get("price_krw", 0)) != 500:
		errors.append("하트 5 상품 구성 오류")
	for bundle_id in ["starter_rescue_pack", "chapter_rescue_pack", "hideout_decor_pack"]:
		var bundle := item_by_id(bundle_id)
		if String(bundle.get("type", "")) != "bundle" or bundle.get("boosters", {}).is_empty():
			errors.append("패키지 상품 구성 오류: %s" % bundle_id)
	var season_pass := item_by_id("season_heart_star_pass")
	if String(season_pass.get("type", "")) != "season_pass":
		errors.append("28일 프리미엄 시즌 상품 구성 오류")
	if int(season_pass.get("daily_support", {}).get("stardust", 0)) <= 0 or int(season_pass.get("clear_reward_ad_multiplier", 0)) < 2:
		errors.append("시즌 프리미엄 일일 지원/광고 배수 구성 오류")
	for exclusive_id in ["remove_ads", "supporter_pack", "hideout_decor_pack", "season_heart_star_pass"]:
		var exclusive_item := item_by_id(exclusive_id)
		if not bool(exclusive_item.get("exclusive", false)) or exclusive_item.get("furniture_ids", []).is_empty():
			errors.append("독점 보상 상품 구성 오류: %s" % exclusive_id)
		for raw_furniture_id in exclusive_item.get("furniture_ids", []):
			var furniture := RoomData.item_by_id(String(raw_furniture_id))
			if furniture.is_empty() or not bool(furniture.get("package_exclusive", false)):
				errors.append("상품 전용 가구 연결 오류: %s" % String(raw_furniture_id))
	return errors
