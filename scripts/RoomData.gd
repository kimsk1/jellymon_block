class_name RoomData
## 젤리 아지트의 수집·성장·가구 데이터. 외형은 FurnitureArt의 2D 가구 아틀라스를 사용한다.

const MetaProgressionCatalogLib = preload("res://scripts/MetaProgressionCatalog.gd")

const GRID_W := 8
const GRID_H := 6
const CELL := 76.0
# 기존 6칸 격자의 실제 위치는 유지하고 좌우에 한 칸씩 확장한다.
const ORIGIN := Vector2(56, 390)
const SCREEN_Y_OFFSET := 50.0

# 모든 테마는 같은 8×6 가구 좌표를 사용한다. 배경에는 가구가 포함되지 않는다.
const DEFAULT_ROOM_THEME := "b"
const ROOM_THEMES := [
	{"id":"b", "unlock_level":0, "name":"민트 아침", "asset":"res://assets/backgrounds/rooms/room_b.png", "wall_ratio":0.578, "canvas":"#f6edda"},
	{"id":"a", "unlock_level":20, "name":"햇살 크림", "asset":"res://assets/backgrounds/rooms/room_a.png", "wall_ratio":0.505, "canvas":"#f9dfb8"},
	{"id":"d", "unlock_level":40, "name":"달빛 아지트", "asset":"res://assets/backgrounds/rooms/room_d.png", "wall_ratio":0.504, "canvas":"#67425f"},
]

static func room_theme(id: String) -> Dictionary:
	for theme in ROOM_THEMES:
		if theme.id == id:
			return theme
	return ROOM_THEMES[0]


const STARTER_ITEM_IDS := ["cushion_r", "lamp_y", "table_b", "shelf_g"]
const FURNITURE_PRICES := {
	"sofa_p": 120, "bench_o": 180, "rug_r": 260, "cabinet_b": 340,
	"plant_g": 430, "screen_p": 540, "counter_y": 680, "slide_b": 840,
	"bed_r": 1000, "book_g": 1200, "tea_o": 1450, "piano_p": 1700,
	"fountain_b": 2000, "garden_g": 2350, "stage_y": 2700, "castle_p": 3000,
	"ach_first": 480, "ach_five": 700, "ach_ch1": 920, "ach_15": 1180,
	"ach_25": 1460, "ach_ch3": 1780, "ach_3x10": 2150, "ach_3x25": 2600,
	"ach_clear": 3200, "ach_perfect": 4000,
	"journey_lantern": 900, "journey_compass": 1100, "journey_radio": 1300,
	"journey_picnic": 1500, "journey_chime": 1700, "journey_portal": 2000,
	"journey_cloud": 2300, "journey_scope": 2600, "journey_banner": 2900,
	"journey_throne": 3400,
}

const REGULAR_ITEMS := [
	{"id":"cushion_r", "name":"딸기 쿠션", "shape":"S1", "color":"#ff788f", "stars":0, "mark":"♥"},
	{"id":"lamp_y", "name":"별빛 스탠드", "shape":"V2", "color":"#ffd45e", "stars":0, "mark":"★"},
	{"id":"table_b", "name":"소다 테이블", "shape":"H2", "color":"#66b9ff", "stars":0, "mark":"●"},
	{"id":"shelf_g", "name":"새싹 선반", "shape":"H3", "color":"#72d982", "stars":0, "mark":"▲"},
	{"id":"sofa_p", "name":"포도 소파", "shape":"LA", "color":"#b87aef", "stars":3, "mark":"◆"},
	{"id":"bench_o", "name":"귤 벤치", "shape":"H2", "color":"#ffad58", "stars":6, "mark":"✿"},
	{"id":"rug_r", "name":"하트 러그", "shape":"SQ", "color":"#ff91a6", "stars":9, "mark":"♥"},
	{"id":"cabinet_b", "name":"물방울 장", "shape":"V2", "color":"#5ea8ec", "stars":12, "mark":"●"},
	{"id":"plant_g", "name":"말랑 화분", "shape":"S1", "color":"#6ed17c", "stars":15, "mark":"▲"},
	{"id":"screen_p", "name":"보라 파티션", "shape":"V3", "color":"#a66cdd", "stars":18, "mark":"◆"},
	{"id":"counter_y", "name":"별 카운터", "shape":"L4A", "color":"#f6c94d", "stars":21, "mark":"★"},
	{"id":"slide_b", "name":"소다 미끄럼틀", "shape":"L4C", "color":"#63b7f3", "stars":24, "mark":"●"},
	{"id":"bed_r", "name":"딸기 침대", "shape":"H3", "color":"#ed6c82", "stars":30, "mark":"♥"},
	{"id":"book_g", "name":"숲 책장", "shape":"L4B", "color":"#63bd71", "stars":36, "mark":"▲"},
	{"id":"tea_o", "name":"귤 티세트", "shape":"TU", "color":"#f5a14c", "stars":42, "mark":"✿"},
	{"id":"piano_p", "name":"포도 피아노", "shape":"L4D", "color":"#9d63ce", "stars":50, "mark":"◆"},
	{"id":"fountain_b", "name":"방울 분수", "shape":"TD", "color":"#52aee8", "stars":60, "mark":"●"},
	{"id":"garden_g", "name":"젤리 정원", "shape":"SH", "color":"#74ce7b", "stars":75, "mark":"▲"},
	{"id":"stage_y", "name":"별빛 무대", "shape":"TU", "color":"#edc346", "stars":90, "mark":"★"},
	{"id":"castle_p", "name":"말랑 성채", "shape":"SQ", "color":"#ae73dc", "stars":110, "mark":"♛"},
]

const ACHIEVEMENT_ITEMS := [
	{"id":"ach_first", "name":"첫 구출 액자", "shape":"S1", "color":"#ff9eaa", "achievement":0, "mark":"1"},
	{"id":"ach_five", "name":"다섯 발자국", "shape":"H2", "color":"#ffba70", "achievement":1, "mark":"5"},
	{"id":"ach_ch1", "name":"젤리 마을 깃발", "shape":"V2", "color":"#ff778f", "achievement":2, "mark":"⚑"},
	{"id":"ach_15", "name":"구출 대원 선반", "shape":"H3", "color":"#6fbce9", "achievement":3, "mark":"15"},
	{"id":"ach_25", "name":"은빛 구조탑", "shape":"V3", "color":"#aab8d8", "achievement":4, "mark":"25"},
	{"id":"ach_ch3", "name":"소다 해변 창문", "shape":"SQ", "color":"#67c9ee", "achievement":5, "mark":"☀"},
	{"id":"ach_3x10", "name":"금별 트로피", "shape":"S1", "color":"#ffd64f", "achievement":6, "mark":"★"},
	{"id":"ach_3x25", "name":"왕관 소파", "shape":"LA", "color":"#f2bb45", "achievement":7, "mark":"♛"},
	{"id":"ach_clear", "name":"50 구출 기념문", "shape":"TD", "color":"#e9856c", "achievement":8, "mark":"50"},
	{"id":"ach_perfect", "name":"별의 성좌", "shape":"ZH", "color":"#8d71e8", "achievement":9, "mark":"✦"},
]

const JOURNEY_ITEMS := [
	{"id":"journey_lantern", "name":"유령숲 등불", "shape":"V2", "color":"#8b7bd7", "mark":"☾"},
	{"id":"journey_compass", "name":"시럽 나침반", "shape":"S1", "color":"#e49a58", "mark":"✥"},
	{"id":"journey_radio", "name":"구조대 무전기", "shape":"H2", "color":"#5da9d5", "mark":"⌁"},
	{"id":"journey_picnic", "name":"말랑 피크닉", "shape":"SQ", "color":"#ef7890", "mark":"♥"},
	{"id":"journey_chime", "name":"바람별 모빌", "shape":"V3", "color":"#83c9dc", "mark":"✦"},
	{"id":"journey_portal", "name":"작은 포털문", "shape":"TD", "color":"#9670d5", "mark":"◇"},
	{"id":"journey_cloud", "name":"구름 영사기", "shape":"H2", "color":"#80bce8", "mark":"☁"},
	{"id":"journey_scope", "name":"별빛 관측대", "shape":"L4A", "color":"#e5bd48", "mark":"☆"},
	{"id":"journey_banner", "name":"원정대 깃발", "shape":"V3", "color":"#67b877", "mark":"⚑"},
	{"id":"journey_throne", "name":"마음별 지휘석", "shape":"TU", "color":"#b274da", "mark":"♛"},
]

const EXCLUSIVE_ITEMS := [
	{"id":"vip_nameplate", "name":"VIP 별빛 명패", "shape":"H2", "color":"#f2c84b", "mark":"VIP", "package_exclusive":true, "animated":true, "reaction":"우리 구조대의 특별한 별빛이야!"},
	{"id":"premium_star_lounge", "name":"별구름 라운지", "shape":"LA", "color":"#cf83e8", "mark":"✦", "package_exclusive":true, "animated":true, "reaction":"구름 위에 누운 것처럼 폭신해!"},
	{"id":"premium_aurora_lamp", "name":"오로라 스탠드", "shape":"V2", "color":"#68d6dc", "mark":"◇", "package_exclusive":true, "animated":true, "reaction":"방 안에 오로라가 춤추고 있어!"},
	{"id":"premium_music_box", "name":"젤리 음악상자", "shape":"S1", "color":"#ef7fa6", "mark":"♪", "package_exclusive":true, "animated":true, "reaction":"내가 좋아하는 말랑말랑한 노래야!"},
	{"id":"premium_memory_projector", "name":"추억 프로젝터", "shape":"H2", "color":"#778ee8", "mark":"★", "package_exclusive":true, "animated":true, "reaction":"우리가 함께한 모험이 별처럼 떠올라!"},
	{"id":"season_welcome_sign", "name":"피크닉 환영 간판", "shape":"H2", "color":"#f0b75a", "mark":"S1", "package_exclusive":true, "animated":true, "reaction":"새 시즌 피크닉이 시작됐어!"},
	{"id":"season_picnic_mat", "name":"마음별 피크닉 매트", "shape":"SQ", "color":"#ef8ca8", "mark":"♥", "package_exclusive":true, "animated":true, "reaction":"다 같이 앉을 자리가 충분해!"},
	{"id":"season_balloon_arch", "name":"별풍선 아치", "shape":"TD", "color":"#78bfe2", "mark":"☆", "package_exclusive":true, "animated":true, "reaction":"풍선 사이로 달리면 축제가 시작돼!"},
	{"id":"season_star_table", "name":"별과자 테이블", "shape":"H2", "color":"#e8c84f", "mark":"★", "package_exclusive":true, "animated":true, "reaction":"별과자가 반짝반짝 맛있어 보여!"},
	{"id":"season_memory_tree", "name":"추억나무", "shape":"V3", "color":"#72c47f", "mark":"✦", "package_exclusive":true, "animated":true, "reaction":"우리 추억이 잎사귀마다 자라고 있어!"},
]

const ACHIEVEMENT_NAMES := [
	"첫 스테이지 클리어", "5개 스테이지 클리어", "챕터 1 완주", "15개 스테이지 클리어",
	"25개 스테이지 클리어", "챕터 3 완주", "3성 스테이지 10개", "3성 스테이지 25개",
	"50개 스테이지 완주", "별 150개 완전 수집",
]


static func all_items() -> Array:
	return REGULAR_ITEMS + ACHIEVEMENT_ITEMS + JOURNEY_ITEMS + EXCLUSIVE_ITEMS


static func starter_items() -> Array:
	## 현재 실제로 지급되는 가구 인벤토리. 별/업적 가구는 획득 시스템이 연결되기 전까지
	## 배치 목록에 잠금 미리보기로 노출하지 않는다.
	var items: Array = []
	for id in STARTER_ITEM_IDS:
		var item := item_by_id(id)
		if not item.is_empty():
			items.append(item)
	return items


static func purchasable_items() -> Array:
	var items: Array = []
	for item in all_items():
		if not STARTER_ITEM_IDS.has(String(item.id)) and not bool(item.get("package_exclusive", false)):
			items.append(item)
	return items


static func owned_items(save) -> Array:
	var items: Array = []
	for item in all_items():
		if save.has_furniture(String(item.id)):
			items.append(item)
	return items


static func furniture_price(id: String) -> int:
	return int(FURNITURE_PRICES.get(id, 0))


static func item_by_id(id: String) -> Dictionary:
	for item in all_items():
		if item.id == id:
			return item
	return {}


static func total_stars(save) -> int:
	var total := 0
	for value in save.stars.values():
		total += int(value)
	return total


static func clear_count(save) -> int:
	var count := 0
	for value in save.stars.values():
		if int(value) > 0:
			count += 1
	return count


static func three_star_count(save) -> int:
	var count := 0
	for value in save.stars.values():
		if int(value) >= 3:
			count += 1
	return count


static func achievement_unlocked(index: int, save) -> bool:
	var clears := clear_count(save)
	var perfects := three_star_count(save)
	match index:
		0: return clears >= 1
		1: return clears >= 5
		2: return save.get_stars(9) > 0
		3: return clears >= 15
		4: return clears >= 25
		5: return save.get_stars(29) > 0
		6: return perfects >= 10
		7: return perfects >= 25
		8: return clears >= 50
		9: return total_stars(save) >= 150
	return false


static func item_unlocked(item: Dictionary, save) -> bool:
	return save.has_furniture(String(item.get("id", "")))


static func growth_stage(save) -> int:
	return MetaProgressionCatalogLib.hero_stage(total_stars(save))


static func growth_name(stage: int) -> String:
	return String(MetaProgressionCatalogLib.hero_stage_data(stage).get("name", "젤리몬"))


static func next_growth_stars(stage: int) -> int:
	var next := MetaProgressionCatalogLib.hero_stage_data(stage + 1)
	return int(next.get("stars", -1))


static func max_growth_stage() -> int:
	return MetaProgressionCatalogLib.max_hero_stage()


static func growth_badge(stage: int) -> String:
	return String(MetaProgressionCatalogLib.hero_stage_data(stage).get("badge", ""))


static func default_placements() -> Array:
	return [
		{"id":"cushion_r", "x":1, "y":4, "rotation":0},
		{"id":"lamp_y", "x":6, "y":0, "rotation":0},
		{"id":"table_b", "x":3, "y":1, "rotation":0},
		{"id":"shelf_g", "x":0, "y":0, "rotation":0},
	]


static func rotated_cells(shape: String, turns: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for raw in G.SHAPES[shape]:
		var cell: Vector2i = raw
		for _i in range(posmod(turns, 4)):
			cell = Vector2i(-cell.y, cell.x)
		cells.append(cell)
	var min_x := 999
	var min_y := 999
	for cell in cells:
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
	for i in range(cells.size()):
		cells[i] -= Vector2i(min_x, min_y)
	return cells


static func validate_catalog() -> PackedStringArray:
	var errors := PackedStringArray()
	if REGULAR_ITEMS.size() != 20:
		errors.append("일반 아지트 가구가 20종이 아님")
	if ACHIEVEMENT_ITEMS.size() != 10:
		errors.append("업적 아지트 가구가 10종이 아님")
	if JOURNEY_ITEMS.size() != 10:
		errors.append("장기 원정 가구가 10종이 아님")
	if EXCLUSIVE_ITEMS.size() != 10:
		errors.append("VIP/꾸미기/시즌 한정 가구가 10종이 아님")
	var ids := {}
	for item in all_items():
		if ids.has(item.id):
			errors.append("중복 아지트 가구 ID: %s" % item.id)
		ids[item.id] = true
		if not G.SHAPES.has(item.shape):
			errors.append("알 수 없는 아지트 가구 모양: %s" % item.shape)
	for id in STARTER_ITEM_IDS:
		var item := item_by_id(id)
		if item.is_empty():
			errors.append("기본 지급 가구 ID 누락: %s" % id)
		elif item.has("achievement") or int(item.get("stars", -1)) != 0:
			errors.append("기본 지급 가구 조건 오류: %s" % id)
	for item in purchasable_items():
		if furniture_price(String(item.id)) <= 0:
			errors.append("가구 별가루 가격 누락: %s" % item.id)
	for item in EXCLUSIVE_ITEMS:
		if not bool(item.get("package_exclusive", false)) or not bool(item.get("animated", false)):
			errors.append("한정 가구 속성 오류: %s" % String(item.get("id", "")))
	return errors
