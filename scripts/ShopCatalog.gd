class_name ShopCatalog
## 상점 상품은 APK/PCK에도 원본이 포함되는 assets/data/item.json에서 관리한다.

const PATH := "res://assets/data/item.json"
const REQUIRED_IDS := ["stardust_50", "stardust_110", "heart_5", "remove_ads"]


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
	if items.size() != 4:
		errors.append("상점 상품이 4종이 아님")
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
	if int(item_by_id("remove_ads").get("price_krw", 0)) != 3000:
		errors.append("광고 제거 상품 구성 오류")
	if int(item_by_id("heart_5").get("amount", 0)) != 5 or int(item_by_id("heart_5").get("price_krw", 0)) != 500:
		errors.append("하트 5 상품 구성 오류")
	return errors
