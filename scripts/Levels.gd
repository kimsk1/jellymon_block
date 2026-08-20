class_name Levels
## 1000개 레벨 캠페인 데이터 (100챕터 × 10레벨).
## 빠지냥식 규칙: 폴리오미노 캐처를 움직여 같은 색 젤리를 흡수하고,
## 다른 색 젤리/벽/캐처는 길을 막는다.
##
## 10레벨마다 보스 관문(왕젤리/분열/시간도둑)이 등장하고, 중반 이후에는
## 대체 승리 조건(제한 이동·지정 순서·호위)과 신규 기믹(유령·끈끈이·
## 일방통행·폭탄)이 순환 등장해 후반 단조로움을 막는다.

const TOTAL_LEVELS := 1000
const LEVELS_PER_CHAPTER := 10
const LEVEL_CHUNK_SIZE := 100
const LEVEL_CHUNK_CACHE_LIMIT := 3
const BOSS_TYPES := ["king", "splitter", "thief"]

const CHAPTER_NAMES := [
	"젤리 마을", "캔디 숲", "소다 해변", "아이스 설산", "초코 화산",
	"서리 정원", "오로라 동굴", "빙하 연구소", "별빛 극지", "영원의 빙궁",
	"마시멜로 구름", "시럽 늪지", "쿠키 사막", "젤라또 협곡", "반짝 유리성",
	"버블 항구", "카라멜 광산", "민트 계곡", "딸기 온실", "무지개 등대",
	"솜사탕 평원", "푸딩 습지", "도넛 고원", "셔벗 빙하", "크림 성채",
	"레몬 수로", "포도 미로", "복숭아 언덕", "블루베리 호수", "황금 사탕궁",
	"별사탕 정거장", "은하 젤리 벨트", "유성 캔디 밭", "혜성 시럽 강", "위성 젤리 기지",
	"오로라 시티", "크리스탈 회랑", "프리즘 탑", "홀로그램 정원", "무지개 관측소",
	"시간의 젤리 시계", "기억의 사탕 숲", "꿈결 젤리 바다", "그림자 캔디 성", "침묵의 빙원",
	"태초의 젤리 핵", "무한 젤리 회랑", "별의 심장", "영원의 문", "젤리몬 대성전",
	"차원 사탕역", "뒤집힌 젤리숲", "워프 크림항", "공간 설탕길", "쌍둥이 포털성",
	"별빛 순간이동로", "거울 젤리회랑", "소용돌이 도넛문", "성운 워프기지", "차원문의 성",
	"균열 쿠키광산", "부서지는 푸딩벽", "유리 젤리협곡", "크랙 캔디탑", "붕괴의 디저트성",
	"흔들리는 사탕다리", "금 간 젤리동굴", "낙석 초코광산", "무너진 크림성채", "대균열의 심장",
	"안개 마시멜로숲", "숨은 젤리호수", "몽환 소다거리", "구름 속 미로", "미지의 젤리궁",
	"짙은 안개회랑", "성운 안개숲", "달빛 구름항", "무한 몽환계", "안개의 왕궁",
	"바람 젤리초원", "회오리 캔디길", "급류 시럽운하", "폭풍 푸딩항", "천공의 젤리섬",
	"혜성 바람길", "역풍 크림협곡", "태풍 사탕기지", "영겁의 폭풍원", "바람의 대관문",
	"시간 사탕공방", "초침 젤리정원", "모래시계 사막", "멈춘 캔디도시", "시간 균열의 성",
	"시공의 젤리핵", "천년 시계탑", "운명의 시간길", "초월의 시간문", "천년 대성전",
]
const CHAPTER_COLORS := [
	Color("#ff8fa3"), Color("#77c66e"), Color("#63b9e8"), Color("#9caee8"), Color("#d88767"),
	Color("#55bfc2"), Color("#598bd8"), Color("#776bc7"), Color("#ca6ead"), Color("#5279ad"),
	Color("#f2a6c8"), Color("#8fbf6a"), Color("#e0b25f"), Color("#6fc3a8"), Color("#8ec6ea"),
	Color("#5fb4d4"), Color("#c98f5e"), Color("#6ec9a0"), Color("#f08a9c"), Color("#b98fd8"),
	Color("#f4b3cd"), Color("#d9b168"), Color("#c99a6a"), Color("#87c9dd"), Color("#e2a98c"),
	Color("#e6c95f"), Color("#a07ad0"), Color("#f0a173"), Color("#6f9fd8"), Color("#e0b64a"),
	Color("#8ea8e8"), Color("#7e7ad2"), Color("#c98fd6"), Color("#6fb8d6"), Color("#7fc0b2"),
	Color("#79a5e2"), Color("#8ad4e4"), Color("#a68ce0"), Color("#7fcfae"), Color("#6fb0e0"),
	Color("#c2a06a"), Color("#9ec47a"), Color("#6aa8d8"), Color("#8a7bb8"), Color("#93b7cc"),
	Color("#e08a76"), Color("#8f7ec8"), Color("#e5c065"), Color("#b57ad0"), Color("#d2a03f"),
	Color("#6c8fe8"), Color("#9b78df"), Color("#56b8d8"), Color("#7b73c9"), Color("#d06fbd"),
	Color("#d7866b"), Color("#c7a25f"), Color("#77b9b2"), Color("#b07179"), Color("#9a6cb7"),
	Color("#8ca7bd"), Color("#72a6c8"), Color("#9b8fc7"), Color("#75b5ae"), Color("#668da8"),
	Color("#6fbed2"), Color("#78a9df"), Color("#5c98c6"), Color("#8978d1"), Color("#657fc2"),
	Color("#d6a35d"), Color("#bd8d68"), Color("#d47b72"), Color("#a77a9e"), Color("#746db3"),
	Color("#778be0"), Color("#9c79cf"), Color("#658fc1"), Color("#6ba9bc"), Color("#b96aa9"),
	Color("#819be5"), Color("#aa82d8"), Color("#67b2c8"), Color("#7583cf"), Color("#c26fae"),
	Color("#e09367"), Color("#ccaa62"), Color("#7bc1ad"), Color("#9b7ac8"), Color("#6c91ce"),
	Color("#d67c94"), Color("#8b82d7"), Color("#62b3cf"), Color("#a46fc4"), Color("#d59b55"),
	Color("#738de2"), Color("#9872d6"), Color("#5ba9c9"), Color("#c16da7"), Color("#d3a13f"),
]

const BAKED_LEVELS_PATH := "res://assets/data/levels.json"
const LEVEL_INDEX_PATH := "res://assets/data/levels/index.json"
const LEVEL_CHUNK_ROOT := "res://assets/data/levels"

## 이번 실행에서 베이크 파일 대신 생성기로 만들었는지 표시한다.
static var _generated_at_startup := false

static var _level_index: Dictionary = _load_level_index()
static var _chunk_cache: Dictionary = {}
static var _chunk_cache_order: Array[int] = []
static var _legacy_levels: Array = []


static func generated_level_count() -> int:
	## 개발용: --gen-limit=N 으로 앞쪽 N개만 생성해 빠르게 검증할 수 있다.
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("--gen-limit="):
			return clampi(int(text.split("=")[1]), 10, TOTAL_LEVELS)
	return TOTAL_LEVELS


static func _load_level_index() -> Dictionary:
	if generated_level_count() != TOTAL_LEVELS or not FileAccess.file_exists(LEVEL_INDEX_PATH):
		return {}
	var file := FileAccess.open(LEVEL_INDEX_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and int(parsed.get("level_count", 0)) > 0 and int(parsed.get("level_count", 0)) <= TOTAL_LEVELS:
		return parsed
	return {}


static func level_count() -> int:
	if not _level_index.is_empty():
		return int(_level_index.get("level_count", 0))
	return _load_legacy_levels().size()


static func get_level(index: int) -> Dictionary:
	if index < 0 or index >= level_count():
		return {}
	if _level_index.is_empty():
		return _load_legacy_levels()[index]
	var chunk_size := int(_level_index.get("chunk_size", LEVEL_CHUNK_SIZE))
	var chunk_index := index / chunk_size
	var chunk := _load_chunk(chunk_index)
	var local_index := index % chunk_size
	return chunk[local_index] if local_index < chunk.size() else {}


static func all_levels() -> Array:
	if _level_index.is_empty():
		return _load_legacy_levels()
	var out: Array = []
	var chunks: Array = _level_index.get("chunks", [])
	for chunk_index in range(chunks.size()):
		out.append_array(_load_chunk(chunk_index))
	return out


static func _load_chunk(chunk_index: int) -> Array:
	if _chunk_cache.has(chunk_index):
		_chunk_cache_order.erase(chunk_index)
		_chunk_cache_order.append(chunk_index)
		return _chunk_cache[chunk_index]
	var chunks: Array = _level_index.get("chunks", [])
	if chunk_index < 0 or chunk_index >= chunks.size():
		return []
	var entry: Dictionary = chunks[chunk_index]
	var path := LEVEL_CHUNK_ROOT + "/" + String(entry.get("file", ""))
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
	var chunk: Array = parsed if parsed is Array else []
	_chunk_cache[chunk_index] = chunk
	_chunk_cache_order.append(chunk_index)
	while _chunk_cache_order.size() > LEVEL_CHUNK_CACHE_LIMIT:
		var expired: int = _chunk_cache_order.pop_front()
		_chunk_cache.erase(expired)
	return chunk


static func _load_legacy_levels() -> Array:
	if not _legacy_levels.is_empty():
		return _legacy_levels
	var wanted := generated_level_count()
	if wanted == TOTAL_LEVELS and FileAccess.file_exists(BAKED_LEVELS_PATH):
		var file := FileAccess.open(BAKED_LEVELS_PATH, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Array and parsed.size() == TOTAL_LEVELS:
			_legacy_levels = parsed
			return _legacy_levels
	_generated_at_startup = true
	_legacy_levels = _build_levels()
	return _legacy_levels


static func chapter_name(chapter: int) -> String:
	return CHAPTER_NAMES[clampi(chapter, 0, CHAPTER_NAMES.size() - 1)]


static func chapter_color(chapter: int) -> Color:
	return CHAPTER_COLORS[clampi(chapter, 0, CHAPTER_COLORS.size() - 1)]


static func boss_type_for(number: int) -> String:
	## 10레벨마다 등장하는 보스 종류. 세 종류가 순환한다.
	if not _is_milestone_challenge(number):
		return ""
	return BOSS_TYPES[(number / 10 - 1) % BOSS_TYPES.size()]


static func bake_current_levels() -> Error:
	var levels := all_levels()
	if levels.size() != TOTAL_LEVELS:
		push_error("[level bake] 부분 생성 상태(%d/%d)는 베이크하지 않습니다." % [levels.size(), TOTAL_LEVELS])
		return ERR_INVALID_DATA
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/data"))
	var file := FileAccess.open(BAKED_LEVELS_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(levels, "\t"))
	file.close()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LEVEL_CHUNK_ROOT))
	var chunks: Array = []
	for start in range(0, levels.size(), LEVEL_CHUNK_SIZE):
		var finish := mini(start + LEVEL_CHUNK_SIZE, levels.size())
		var chunk_file_name := "levels_%04d_%04d.json" % [start + 1, finish]
		var chunk_path := LEVEL_CHUNK_ROOT + "/" + chunk_file_name
		var chunk_file := FileAccess.open(chunk_path, FileAccess.WRITE)
		if chunk_file == null:
			return FileAccess.get_open_error()
		chunk_file.store_string(JSON.stringify(levels.slice(start, finish)))
		chunk_file.close()
		chunks.append({
			"file": chunk_file_name,
			"start": start + 1,
			"end": finish,
			"sha256": FileAccess.get_sha256(chunk_path),
		})
	var index_data := {
		"version": 1,
		"level_count": levels.size(),
		"chunk_size": LEVEL_CHUNK_SIZE,
		"chunks": chunks,
	}
	var index_file := FileAccess.open(LEVEL_INDEX_PATH, FileAccess.WRITE)
	if index_file == null:
		return FileAccess.get_open_error()
	index_file.store_string(JSON.stringify(index_data, "\t"))
	index_file.close()
	_level_index = index_data
	_chunk_cache.clear()
	_chunk_cache_order.clear()
	return OK


static func rebuild_and_bake_levels() -> Error:
	# 베이크는 기존 청크가 아닌 생성기를 원본으로 사용한다.
	_legacy_levels = _build_levels()
	_level_index = {}
	_chunk_cache.clear()
	_chunk_cache_order.clear()
	_generated_at_startup = true
	return bake_current_levels()


static func extend_and_bake_levels() -> Error:
	## 이미 검증·배포된 앞 레벨은 그대로 보존하고 뒤쪽 번호만 생성한다.
	var levels := all_levels()
	if levels.size() > TOTAL_LEVELS:
		return ERR_INVALID_DATA
	for number in range(levels.size() + 1, TOTAL_LEVELS + 1):
		levels.append(_generated_level(number))
	_legacy_levels = levels
	_level_index = {}
	_chunk_cache.clear()
	_chunk_cache_order.clear()
	_generated_at_startup = true
	return bake_current_levels()


static func repair_and_bake_levels() -> Error:
	var levels := all_levels()
	if levels.size() != TOTAL_LEVELS:
		return ERR_INVALID_DATA
	for index in range(500, levels.size()):
		var number := index + 1
		_refresh_level_chapter_name(levels[index], number)
		_finalize_level_integrity(levels[index], number)
		_ensure_expansion_feature(levels[index], number)
		_compose_objective_hint(levels[index], number)
	_legacy_levels = levels
	_level_index = {}
	_chunk_cache.clear()
	_chunk_cache_order.clear()
	return bake_current_levels()


static func _refresh_level_chapter_name(level: Dictionary, number: int) -> void:
	var current_name := String(level.get("name", ""))
	var separator := current_name.find(" · ")
	var suffix := current_name.substr(separator) if separator >= 0 else ""
	var chapter := (number - 1) / LEVELS_PER_CHAPTER
	level["name"] = CHAPTER_NAMES[chapter] + suffix


static func _build_levels() -> Array:
	var out: Array = []
	# 첫 세 레벨에서 기본 2×2 조작과 50레벨 이전 대표 기믹을 차례로 학습한다.
	var level_one := _level("첫 만남 · 2×2 구출", ["......", ".RR...", ".RR...", "......", "......", "......", "......"], [_c("R", "SQ", 2, 5, 4)], 70, "2×2 블록을 끌어 빨간 젤리몬 네 마리를 블록 안에 담아 주세요!")
	level_one["tutorial"] = "square_capture"
	out.append(level_one)
	var level_two := _level("오각 장벽과 모양 봉인", [".RR..", "..R.R", ".....", ".....", ".....", ".....", "....."], [_c("R", "H2", 1, 5, 4)], 90, "아래의 빛나는 두 칸에 블록을 맞추면 오각 장벽 5개가 모두 사라져요!")
	# 젤리 구역과 조작 구역 사이의 한 행 전체를 오각형 장벽으로 막는다.
	# 아래 빈 타일의 룬을 먼저 맞춰야 위쪽 젤리몬에게 접근할 수 있다.
	level_two["shape_seals"] = [{
		"color": "R", "shape": "H2",
		"cells": [[1, 4], [2, 4]],
		"gates": [[0, 2], [1, 2], [2, 2], [3, 2], [4, 2]],
	}]
	level_two["tutorial"] = "shape_seal"
	out.append(level_two)
	var level_three := _level("구출 배출구", ["......", ".RR...", ".RR...", "......", "......", "......", "......"], [_c("R", "SQ", 1, 4, 4)], 80, "젤리를 모두 담아 GO가 되면 오른쪽의 같은 색 출구로 내보내세요!")
	level_three["exits"] = [{"color": "R", "catcher": 0, "cell": [5, 5], "direction": [1, 0]}]
	level_three["tutorial"] = "rescue_exit"
	out.append(level_three)
	var level_four := _level("순서가 중요해", ["......", ".BBBB.", ".BBBB.", "RRRRRR", "......", "......", "......"], [_c("R", "S1", 0, 5), _c("B", "S1", 5, 5)], 90, "같은 색 젤리몬만 담을 수 있어요. 앞을 막은 색부터 치우세요!")
	level_four["tutorial"] = "color_match"
	out.append(level_four)
	for number in range(5, generated_level_count() + 1):
		out.append(_generated_level(number))
	return out


static func _generated_level(number: int) -> Dictionary:
	var chapter := (number - 1) / LEVELS_PER_CHAPTER
	var local := (number - 1) % LEVELS_PER_CHAPTER
	var challenge := _is_challenge_level(number)
	var milestone_challenge := _is_milestone_challenge(number)
	var w := mini(8, 6 + (chapter + 1) / 2)
	# 100레벨 이후에는 세로 한 칸을 더 열어 신규 기믹이 놓일 공간을 확보한다.
	var h := mini(10 if number >= 201 else 9, 7 + (chapter + 1) / 2)
	var palette := ["R", "Y", "B", "G", "P", "O"]
	var color_count := 2
	if number >= 9:
		color_count = 3
	if number >= 16:
		color_count = 4
	if number >= 26:
		color_count = 5
	if number >= 41:
		color_count = 6
	if number >= 101:
		# 후반은 5색과 6색을 번갈아 써서 읽기 부담이 매 레벨 최대치가 되지 않게 한다.
		color_count = 5 if (number / 10) % 3 == 1 else 6
	var colors: Array = palette.slice(0, color_count)
	# 각 챕터 후반은 새 색을 중심에 배치해 읽기 부담을 점진적으로 높인다.
	if chapter >= 1:
		colors[color_count - 1] = palette[mini(chapter + 2, 5)]
	var board: Array = []
	for y in range(h):
		board.append(".".repeat(w))

	var pattern := local % 4
	if milestone_challenge and number >= 20:
		# 모든 챕터 끝 레벨은 local=9라 기본값이 늘 세로 줄무늬였다.
		# 이 배치는 같은 색을 한 번에 쓸기 쉬우므로, L13에서 난도가 검증된
		# 고리/엇갈림 배치를 사용해 색이 서로의 길을 막게 한다.
		pattern = 2 if number in [20, 50, 70] else 3
	if pattern == 0:
		_fill_bands(board, colors, w, h)
	elif pattern == 1:
		_fill_columns(board, colors, w, h)
	elif pattern == 2:
		_fill_rings(board, colors, w, h)
	else:
		_fill_checker_lanes(board, colors, w, h)
	_carve_irregular_board(board, number, chapter, w, h)
	_add_walls(board, chapter, local, w, h)
	if number >= 51:
		_densify_late_board(board, colors, w, h, number, _density_target(number, w, h))
	if challenge:
		_densify_challenge_board(board, colors, w, h, number)

	var specs := _capacity_catchers(board, colors, w, h, number)

	# L1~4 이후는 색/밀도가 늘어나며, 얼음 구간에서는 63초에서 52초까지 다시 압축한다.
	var time_limit := maxf(63.0, 83.0 - float(number - 9) * 0.5)
	if number >= 51 and number <= 100:
		# 각 10레벨 구간 안에서 꾸준히 짧아지고, 다음 구간은 신규 기믹을
		# 학습할 약간의 시간을 돌려준다. 구간 기본 시간도 3초씩 감소한다.
		var late_tier := (number - 51) / 10
		var late_local := (number - 51) % 10
		time_limit = maxf(41.0, 60.0 - float(late_tier) * 3.0 - float(late_local) * 0.7)
	elif number >= 101:
		# 101레벨 이후는 밀도가 보드 상한에 닿으므로 시간 압박을 완만하게 이어가고,
		# 난도 상승은 신규 기믹과 대체 승리 조건이 담당한다.
		var deep_tier := (number - 101) / 10
		var deep_local := (number - 101) % 10
		time_limit = maxf(40.0, 58.0 - float(deep_tier) * 0.32 - float(deep_local) * 0.6)
	if number >= 501:
		# 확장 캠페인은 100레벨마다 기본 시간을 줄이고, 같은 10레벨 안에서도
		# 조금씩 압축한다. 신규 기믹 학습은 가능하되 후반으로 갈수록 우회 실수가 아프다.
		var advanced_century := (number - 501) / 100
		var advanced_local := (number - 501) % 10
		time_limit = maxf(34.0, 46.0 - float(advanced_century) * 1.5 - float(advanced_local) * 0.55)
	if challenge:
		time_limit = maxf(40.0 if number >= 51 else 48.0, time_limit - 4.0)
	if milestone_challenge:
		# 10단위 관문은 후반으로 갈수록 일반 도전보다 2~6초 더 촉박해진다.
		time_limit = maxf(42.0, time_limit - (2.0 + float(mini(number, 100) / 25)))
	if [20, 30, 40].has(number):
		# 초중반 보스 관문은 탐색할 여유는 주되, 무작정 전부 훑는 플레이는
		# 별 3개를 받을 수 없도록 별도 상한을 둔다.
		time_limit = minf(time_limit, 62.0 - float(number - 20) * 0.5)
	elif milestone_challenge and number >= 50 and number <= 100:
		# 후반 관문은 50레벨부터 2초씩 줄어 최종 100레벨이 가장 촉박하다.
		time_limit = minf(time_limit, 50.0 - float(number - 50) * 0.2)
	if number == 60:
		# 요청된 밸런스: 60레벨은 직전 59레벨과 동일한 제한 시간을 사용한다.
		time_limit = 54.4
	if milestone_challenge and number >= 110:
		# 보스 관문은 추가 규칙을 읽고 대응할 시간이 필요하므로 되돌려 준다.
		time_limit += 14.0 if boss_type_for(number) == "thief" else 8.0
	var chapter_name := chapter_name(chapter)
	var titles := ["길 열기", "엇갈린 줄", "색의 성", "굽은 통로", "한붓 쓸기", "갈림길", "큰 몸 작은 문", "색깔 미로", "연쇄 구출", "최종 관문"]
	var hint := "색의 층과 캐처 모양을 보고 구출 순서를 정하세요."
	if local == 9:
		hint = "%s의 모든 규칙이 섞인 하이라이트 레벨!" % chapter_name
	if milestone_challenge:
		hint = "★★ 대도전 · 이번 챕터의 모든 이동 순서와 기믹을 함께 풀어내세요!"
	elif challenge:
		hint = "★ 도전 스테이지 · 큰 블록과 뒤섞인 색의 이동 순서를 먼저 읽으세요!"
	var level_name := "%s · %s" % [chapter_name, titles[local]]
	if milestone_challenge:
		level_name += " ★★대도전"
	elif challenge:
		level_name += " ★도전"
	var star_targets := [0.47, 0.22] if challenge else ([0.45, 0.2] if local == 9 else [0.5, 0.25])
	if milestone_challenge:
		star_targets = [0.50 + minf(0.05, float(number) / 2000.0), 0.24 + minf(0.03, float(number) / 3000.0)]
	var result := _level(level_name, board, specs, time_limit, hint, star_targets)
	if challenge:
		result["challenge"] = true
	if milestone_challenge:
		result["milestone_challenge"] = true
		result["difficulty_tier"] = number / 10
	if number >= 51:
		result["late_difficulty_tier"] = 1 + (number - 51) / 10
		result["density_target"] = _density_target(number, w, h)
	if number >= 501:
		result["advanced_difficulty_tier"] = 1 + (number - 501) / 100
		result["mechanic_generation"] = 1 + (number - 501) / 100
	if not _is_greedily_solvable(result):
		var changed := true
		while changed and not _is_greedily_solvable(result):
			changed = false
			for i in range(specs.size() - 1, -1, -1):
				var simpler := _simpler_shape(specs[i].shape)
				if simpler != specs[i].shape:
					specs[i].shape = simpler
					changed = true
					if _is_greedily_solvable(result):
						break
	# 승격 목표는 100레벨 수준에서 멈춘다. 그 이상 강제하면 후반 보드에서
	# 큰 블록이 놓일 자리가 사라지고 생성 비용만 커진다.
	_promote_tetrominoes(result, _level_shape_pool(number), 2 + mini(number, 100) / 12 + (2 if challenge else 0))
	if challenge:
		# 대도전은 50·100레벨에서 큰 블록 최소치가 한 단계씩 상승한다.
		# 그 이상 강제하면 후반 복합 기믹의 이동 공간이 사라지므로 자동 승격분은 그대로 둔다.
		var minimum_large := mini(1 + number / 50, 3) if milestone_challenge else 2
		_ensure_challenge_tetrominoes(result, _level_shape_pool(number), minimum_large)
	if _is_greedily_solvable(result):
		_intermix_level(result, number)
		if milestone_challenge and number >= 20:
			_pack_milestone_catchers(result, _milestone_target_moves(number))
		_add_shape_seal(result, number)
		_reduce_empty_space(result, number)
		if milestone_challenge:
			_tighten_milestone_start(result, number)
		_remove_unused_islands(result)
		_fix_known_mobility_traps(result, number)
		_validate_shape_seal(result)
		_add_rescue_exits(result, number)
		# 보스는 기믹 표식보다 먼저 자리를 잡아야 후반 관문에서도 항상 배치된다.
		_add_boss(result, number)
		_add_late_gimmicks(result, number)
		_add_alt_win_condition(result, number)
		_repair_unsolvable(result, number)
		_sanitize_advanced_gimmicks(result)
		_finalize_level_integrity(result, number)
		_ensure_expansion_feature(result, number)
		_compose_objective_hint(result, number)
	return result


static func _finalize_level_integrity(level: Dictionary, number: int) -> void:
	## 모든 후처리가 끝난 최종 데이터에서 다시 검사해 조합 순서에 따른 드문 막힘을 제거한다.
	if level.has("shape_seals") and not _shape_seal_is_valid(level):
		level.erase("shape_seals")
	if not _is_greedily_solvable(level):
		for key in ["one_ways", "color_order", "escort", "shape_seals", "key_locks"]:
			if not level.has(key):
				continue
			level.erase(key)
			_refresh_gimmick_record(level)
			if _is_greedily_solvable(level):
				break
	if not _is_greedily_solvable(level):
		_repair_unsolvable(level, number)
	_sanitize_advanced_gimmicks(level)


static func _ensure_expansion_feature(level: Dictionary, number: int) -> void:
	## 각 100레벨 확장 구간의 첫 스테이지는 신규 규칙을 반드시 소개한다.
	## 이후 생성 순서가 달라져도 튜토리얼 경계가 조용히 사라지지 않게 보증한다.
	match number:
		501:
			if not level.has("portals"):
				_add_portals(level, number)
		601:
			if not level.has("fragile_walls"):
				_add_fragile_walls(level, number)
		701:
			if not level.has("fog"):
				_add_fog_jellies(level, number)
		801:
			if not level.has("currents"):
				_add_current_tiles(level, number)
		901:
			if not level.has("time_rifts"):
				_add_time_rifts(level, number)
	_sanitize_advanced_gimmicks(level)


static func _repair_unsolvable(level: Dictionary, _number: int) -> void:
	## 여러 규칙이 겹쳐 드물게 풀이가 막히면, 제약이 강한 선택 요소부터 되돌린다.
	## 콘텐츠를 조금 잃더라도 클리어 불가능한 레벨은 절대 남기지 않는다.
	if _is_greedily_solvable(level):
		return
	for key in ["one_ways", "color_order", "escort", "boss"]:
		if not level.has(key):
			continue
		var removed = level[key]
		level.erase(key)
		if key == "boss" and String(removed.get("type", "")) == "splitter":
			_revoke_extra_capacity(level, String(removed.get("color", "")), int(removed.get("splits", 0)))
		_refresh_gimmick_record(level)
		if _is_greedily_solvable(level):
			return
	# 그래도 막히면 시작 압축 단계에서 세운 내부 벽을 누적으로 되돌린다.
	# 하나씩 넣었다 뺐다 하면 두 칸 이상 열어야 하는 경우를 못 고친다.
	var board: Array = level.grid
	var opened := false
	for y in range(board.size()):
		for x in range(board[y].length()):
			if board[y][x] != "#":
				continue
			_put(board, x, y, ".")
			opened = true
			if _is_greedily_solvable(level):
				break
		if opened and _is_greedily_solvable(level):
			break
	if opened:
		level["initial_move_options"] = _initial_move_options(level)
		level["initial_empty_spaces"] = _count_free_empty(level)
	if _is_greedily_solvable(level):
		return
	# 마지막 수단: 어떤 블록도 끝내 닿지 못하는 젤리를 그 색 수용량과 함께 덜어낸다.
	# 한 번에 다 풀리지 않는 경우가 있어 몇 차례 반복한다.
	for _round in range(3):
		_drop_unreachable_jellies(level)
		if _is_greedily_solvable(level):
			break
	# 젤리를 덜어냈다면 기록된 밀도 목표도 실제 값에 맞춰 낮춘다.
	if level.has("density_target"):
		level["density_target"] = mini(int(level.density_target), _level_jelly_count(level))


static func _drop_unreachable_jellies(level: Dictionary) -> void:
	## 그리디 풀이가 끝까지 남기는 젤리를 제거하고, 같은 색 블록의 수용량도 함께
	## 줄여 "용량 합 = 젤리 수" 규칙을 유지한다. 용량이 0이 된 블록은 삭제한다.
	# 캐처 우선순위를 모두 시도해 가장 적게 남기는 결과를 고른다.
	var leftover: Array = []
	var first := true
	for shift in range(maxi(1, level.catchers.size())):
		var attempt := _solve_with_shift(level, shift)
		if bool(attempt.ok):
			return
		var candidate: Array = attempt.get("leftover", [])
		if first or candidate.size() < leftover.size():
			leftover = candidate
			first = false
	if leftover.is_empty():
		return
	var board: Array = level.grid
	# 보드 대부분을 지워 빈 판을 만들지 않도록 한 번에 덜어낼 양을 제한한다.
	# 반복 호출되므로 한도를 넘으면 가장 고립된 쪽부터 일부만 덜어낸다.
	var total_jellies := _level_jelly_count(level)
	var cap := maxi(4, total_jellies / 3)
	if leftover.size() > cap:
		leftover = leftover.slice(0, cap)
	var removed := {}
	for cell in leftover:
		var color := String(board[cell.y][cell.x])
		if not G.COLORS.has(color):
			continue
		_put(board, cell.x, cell.y, ".")
		removed[color] = int(removed.get(color, 0)) + 1
	for color in removed:
		var left: int = int(removed[color])
		for spec in level.catchers:
			if left <= 0:
				break
			if String(spec.color) != color:
				continue
			var take: int = mini(left, int(spec.get("capacity", 0)))
			spec["capacity"] = int(spec.get("capacity", 0)) - take
			left -= take
	# 담당할 젤리가 없어진 블록은 제거한다. 인덱스를 참조하는 규칙도 함께 정리한다.
	var survivors: Array = []
	var dropped := false
	for spec in level.catchers:
		if int(spec.get("capacity", 0)) > 0:
			survivors.append(spec)
		else:
			dropped = true
	if dropped:
		level["catchers"] = survivors
		level.erase("key_locks")
		level.erase("escort")
		for exit in level.get("exits", []):
			exit["catcher"] = -1
	_prune_jelly_markers(level)
	_refresh_gimmick_record(level)


static func _prune_jelly_markers(level: Dictionary) -> void:
	## 젤리를 덜어낸 뒤 빈 칸을 가리키게 된 표식들을 정리한다.
	var board: Array = level.grid
	var is_jelly := func(pair) -> bool:
		var x := int(pair[0])
		var y := int(pair[1])
		return y >= 0 and y < board.size() and x >= 0 and x < board[y].length() and G.COLORS.has(board[y][x])
	for key in ["ghosts", "bombs", "sealed_jellies", "fog"]:
		if not level.has(key):
			continue
		var kept: Array = []
		for pair in level[key]:
			if is_jelly.call(pair):
				kept.append(pair)
		if kept.is_empty():
			level.erase(key)
			if key == "sealed_jellies":
				level.erase("switches")
		else:
			level[key] = kept
	if level.has("frozen"):
		var frozen_kept: Array = []
		for raw in level.frozen:
			if is_jelly.call(raw):
				frozen_kept.append(raw)
		if frozen_kept.is_empty():
			level.erase("frozen")
		else:
			level["frozen"] = frozen_kept
	if level.has("chains"):
		var chains_kept: Array = []
		for chain in level.chains:
			var cells_kept: Array = []
			for pair in chain.get("cells", []):
				if is_jelly.call(pair) and board[int(pair[1])][int(pair[0])] == String(chain.color):
					cells_kept.append(pair)
			if cells_kept.size() >= 2:
				chain["cells"] = cells_kept
				chains_kept.append(chain)
		if chains_kept.is_empty():
			level.erase("chains")
		else:
			level["chains"] = chains_kept
	if level.has("escort") and not is_jelly.call(level.escort.cell):
		level.erase("escort")
	if level.has("boss") and not is_jelly.call(level.boss.cell):
		var boss: Dictionary = level.boss
		level.erase("boss")
		if String(boss.get("type", "")) == "splitter":
			_revoke_extra_capacity(level, String(boss.get("color", "")), int(boss.get("splits", 0)))


static func _sanitize_advanced_gimmicks(level: Dictionary) -> void:
	var board: Array = level.grid
	var valid_cell := func(pair: Array, expected: String) -> bool:
		if pair.size() < 2:
			return false
		var x := int(pair[0])
		var y := int(pair[1])
		return y >= 0 and y < board.size() and x >= 0 and x < board[y].length() and board[y][x] == expected
	var fragile: Array = []
	for raw in level.get("fragile_walls", []):
		if raw is Array and raw.size() >= 3 and valid_cell.call(raw, "#"):
			fragile.append(raw)
	if fragile.is_empty():
		level.erase("fragile_walls")
	else:
		level["fragile_walls"] = fragile
	var portals: Array = []
	for raw in level.get("portals", []):
		if valid_cell.call(raw.get("a", []), ".") and valid_cell.call(raw.get("b", []), "."):
			portals.append(raw)
	if portals.is_empty():
		level.erase("portals")
	else:
		level["portals"] = portals
	for key in ["currents", "time_rifts"]:
		var kept: Array = []
		for raw in level.get(key, []):
			var pair: Array = raw.cell if key == "currents" else raw
			if valid_cell.call(pair, "."):
				kept.append(raw)
		if kept.is_empty():
			level.erase(key)
		else:
			level[key] = kept
	_refresh_gimmick_record(level)


static func _refresh_gimmick_record(level: Dictionary) -> void:
	if not level.has("gimmicks"):
		return
	var active: Array[String] = []
	for name in GIMMICK_ORDER:
		if _level_has_gimmick(level, name):
			active.append(name)
	level["gimmicks"] = active
	level["gimmick_count"] = active.size()


static func _density_target(number: int, w: int, h: int) -> int:
	## 51레벨 26마리에서 시작해 약 6레벨마다 한 마리씩 늘리되, 보드가 가득 차
	## 캐처 시작 자리가 사라지지 않도록 실제 플레이 면적으로 상한을 둔다.
	## 밀도가 상한에 닿은 뒤부터는 신규 기믹과 대체 승리 조건이 난도를 담당한다.
	if number < 51:
		return 0
	var play_cells := w * maxi(1, h - 2)
	# 100레벨까지는 기존 곡선을 그대로 쓰고, 이후에는 캐처가 실제로 놓일 빈칸이
	# 남도록 상한을 낮춘다. 후반 난도는 신규 기믹과 대체 승리 조건이 담당한다.
	var ceiling := int(float(play_cells) * (0.62 if number <= 100 else 0.46))
	return mini(26 + (number - 51) / 6, ceiling)

static func _is_challenge_level(number: int) -> bool:
	return number >= 10 and number % 5 == 0


static func _is_milestone_challenge(number: int) -> bool:
	return number >= 10 and number % 10 == 0


static func _milestone_target_moves(number: int) -> int:
	if number >= 100:
		# 12개 캐처와 네 기믹이 겹쳐 네 방향 중에서도 정답 순서가 제한된다.
		return 4
	if number >= 90:
		# 열쇠로 첫 순서가 한 번 더 제한되므로 세 방향 안에서도 선택 함정이 생긴다.
		return 3
	if number >= 80:
		return 3
	return 3


static func _level_jelly_count(level: Dictionary) -> int:
	var count := 0
	for row in level.get("grid", []):
		for x in range(String(row).length()):
			if G.COLORS.has(String(row)[x]):
				count += 1
	return count


static func _densify_late_board(board: Array, colors: Array, w: int, h: int, number: int, target: int) -> void:
	## 후반 일반 레벨도 빈 통로를 한 번에 훑지 못하도록 색 젤리를 교차 배치한다.
	var current := 0
	for row in board:
		for ch in row:
			if G.COLORS.has(ch):
				current += 1
	var needed := maxi(0, target - current)
	if needed <= 0:
		return
	var candidates: Array[Vector2i] = []
	# 블록 시작 공간을 완전히 없애지 않도록 마지막 두 행은 보존한다.
	for y in range(maxi(0, h - 2)):
		for x in range(w):
			if board[y][x] == ".":
				candidates.append(Vector2i(x, y))
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_score := (a.x * 37 + a.y * 23 + number * 11) % 127
		var b_score := (b.x * 37 + b.y * 23 + number * 11) % 127
		return a_score < b_score
	)
	for i in range(mini(needed, candidates.size())):
		var cell := candidates[i]
		# 연속된 같은 색 띠 대신 모든 활성 색을 회전시켜 서로 길을 막게 한다.
		var color_index := (i * 2 + number + cell.x + cell.y) % colors.size()
		_put(board, cell.x, cell.y, colors[color_index])


static func _densify_challenge_board(board: Array, colors: Array, w: int, h: int, number: int) -> void:
	## L13처럼 한 색이 여러 블록으로 나뉘고 서로 얽히도록 플레이 영역에 젤리를 추가한다.
	## 캐처 배치용 하단 3행은 건드리지 않아 큰 블록의 시작 공간을 보존한다.
	var candidates: Array[Vector2i] = []
	for y in range(maxi(0, h - 3)):
		for x in range(w):
			if board[y][x] == ".":
				candidates.append(Vector2i(x, y))
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_score := (a.x * 19 + a.y * 31 + number * 7) % 101
		var b_score := (b.x * 19 + b.y * 31 + number * 7) % 101
		return a_score < b_score
	)
	# 100레벨 이후에는 보드가 이미 가득 차 있으므로 추가 밀도를 100레벨 수준으로 고정한다.
	var scale_number := mini(number, 100)
	var extra_count := 2 + mini(2, scale_number / 40)
	if _is_milestone_challenge(number):
		# 10단위 관문은 3개에서 시작해 최종 관문에서 최대 8개까지 추가한다.
		extra_count += 1 + scale_number / 30
	if _is_milestone_challenge(number) and number >= 20:
		# 초중반 핵심 관문은 벽을 나중에 두르는 대신 생성 시점부터 색을 촘촘히
		# 교차시켜, 젤리가 길을 막고 같은 색도 여러 블록으로 갈라지게 한다.
		# 이후 10단위 관문도 같은 밀도 보너스를 유지해 난도가 역전되지 않게 한다.
		extra_count += 4
		if number >= 60:
			extra_count += mini(3, 1 + (scale_number - 60) / 20)
		if number == 100:
			extra_count += 3
		if number == 50:
			# L40의 고밀도 관문 다음 단계가 젤리 수에서 역전되지 않도록 추가 보강한다.
			extra_count += 2
	if number == 100:
		# 후반 기본 밀도 보강과 합쳐 정확히 42마리가 되도록 제한한다.
		# 이보다 높으면 12개 캐처의 시작 자리가 사라져 유효한 퍼즐이 되지 않는다.
		extra_count = 8
	if number > 100:
		# 101레벨 이후 보드는 이미 상한 밀도라, 도전 보너스를 조금만 얹어야
		# 캐처가 놓일 빈칸이 남는다. 난도는 보스와 대체 승리 조건이 담당한다.
		extra_count = 3 if _is_milestone_challenge(number) else 2
	var extra := mini(candidates.size(), extra_count)
	if extra <= 0 or colors.is_empty():
		return
	var focus_index := (number / 5) % colors.size()
	for i in range(extra):
		var color_index := focus_index if i < extra - 1 else (focus_index + 1) % colors.size()
		var cell := candidates[i]
		_put(board, cell.x, cell.y, colors[color_index])


const GIMMICK_ORDER := [
	"frost", "chain", "switch", "key", "ghost", "sticky", "one_way", "bomb",
	"portal", "fragile", "fog", "current", "time_rift",
]
const GIMMICK_LABELS := {
	"frost": "❄얼음", "chain": "⛓순서", "switch": "◆스위치", "key": "🔑열쇠",
	"ghost": "👻유령", "sticky": "🍯끈끈이", "one_way": "➤일방통행", "bomb": "💣폭탄",
	"portal": "🌀포털", "fragile": "◇균열벽", "fog": "☁안개", "current": "≋바람길", "time_rift": "⌛시간균열",
}


static func gimmick_unlock_level(name: String) -> int:
	match name:
		"frost": return 51
		"chain": return 61
		"switch": return 71
		"key": return 81
		"ghost": return 101
		"sticky": return 131
		"one_way": return 161
		"bomb": return 191
		"portal": return 501
		"fragile": return 601
		"fog": return 701
		"current": return 801
		"time_rift": return 901
	return 9999


static func _deterministic_shuffle(items: Array, number: int) -> Array:
	## 레벨 번호만으로 재현되는 섞기. 베이크와 검증이 항상 같은 결과를 얻는다.
	var out := items.duplicate()
	var state := number * 2654435761 + 12345
	for i in range(out.size() - 1, 0, -1):
		state = (state * 1103515245 + 12345) & 0x3fffffff
		var j: int = state % (i + 1)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


static func _add_late_gimmicks(level: Dictionary, number: int) -> void:
	if number < 51:
		return
	var flags := _gimmick_flags(number)
	# 실제 이동 경로를 요구하는 스위치/일방통행을 먼저 잡고, 젤리 표식인 얼음과
	# 체인을 나중에 얹어 후보 칸 선점 때문에 필수 기믹이 누락되지 않게 한다.
	if flags.switch:
		_add_rescue_switch(level, number)
	if flags.one_way:
		_add_one_way_tiles(level, number)
	if flags.sticky:
		_add_sticky_tiles(level, number)
	if flags.portal:
		_add_portals(level, number)
	if flags.current:
		_add_current_tiles(level, number)
	if flags.time_rift:
		_add_time_rifts(level, number)
	if flags.fragile:
		_add_fragile_walls(level, number)
	if flags.key:
		_add_key_lock(level, number)
	if flags.frost:
		_add_frozen_jellies(level, number)
	if flags.chain:
		_add_rescue_chain(level, number)
	if flags.ghost:
		_add_ghost_jellies(level, number)
	if flags.bomb:
		_add_bomb_jellies(level, number)
	if flags.fog:
		_add_fog_jellies(level, number)
	var active: Array[String] = []
	for name in GIMMICK_ORDER:
		if _level_has_gimmick(level, name):
			active.append(name)
	level["gimmicks"] = active
	level["gimmick_count"] = active.size()


static func _level_has_gimmick(level: Dictionary, name: String) -> bool:
	match name:
		"frost": return level.has("frozen")
		"chain": return level.has("chains")
		"switch": return level.has("switches") and level.has("sealed_jellies")
		"key": return level.has("key_locks")
		"ghost": return level.has("ghosts")
		"sticky": return level.has("sticky")
		"one_way": return level.has("one_ways")
		"bomb": return level.has("bombs")
		"portal": return level.has("portals")
		"fragile": return level.has("fragile_walls")
		"fog": return level.has("fog")
		"current": return level.has("currents")
		"time_rift": return level.has("time_rifts")
	return false


static func _gimmick_flags(number: int) -> Dictionary:
	var flags := {
		"frost": false, "chain": false, "switch": false, "key": false,
		"ghost": false, "sticky": false, "one_way": false, "bomb": false,
		"portal": false, "fragile": false, "fog": false, "current": false, "time_rift": false,
	}
	# 1~100레벨은 기존에 검증된 학습 순서를 그대로 유지한다.
	if number <= 100:
		if number >= 51 and number <= 60:
			flags.frost = true
		elif number >= 61 and number <= 70:
			flags.chain = true
			flags.frost = number >= 62
		elif number >= 71 and number <= 80:
			flags.switch = true
			flags.frost = number == 72 or number >= 74
			flags.chain = number == 73 or number >= 74
		elif number >= 81 and number <= 90:
			flags.key = true
			flags.frost = number == 82 or number >= 85
			flags.chain = number == 83 or number >= 85
			flags.switch = number == 84 or number >= 85
		elif number >= 91 and number <= 100:
			var mixes := [
				[true, true, true, false], [true, true, false, true],
				[true, false, true, true], [false, true, true, true],
				[true, true, true, true], [true, true, true, false],
				[true, true, false, true], [true, false, true, true],
				[false, true, true, true], [true, true, true, true],
			]
			var mix: Array = mixes[number - 91]
			flags.frost = mix[0]
			flags.chain = mix[1]
			flags.switch = mix[2]
			flags.key = mix[3]
		return flags
	# 101레벨 이후: 신규 기믹은 도입 구간 10레벨 동안 매판 등장해 학습시키고,
	# 그 뒤로는 해금된 기믹들이 결정적 순서로 조합돼 반복감을 줄인다.
	var pool: Array = []
	for name in GIMMICK_ORDER:
		if number >= gimmick_unlock_level(name):
			pool.append(name)
	var featured := ""
	if number <= 110:
		featured = "ghost"
	elif number >= 131 and number <= 140:
		featured = "sticky"
	elif number >= 161 and number <= 170:
		featured = "one_way"
	elif number >= 191 and number <= 200:
		featured = "bomb"
	elif number >= 501 and number <= 510:
		featured = "portal"
	elif number >= 601 and number <= 610:
		featured = "fragile"
	elif number >= 701 and number <= 710:
		featured = "fog"
	elif number >= 801 and number <= 810:
		featured = "current"
	elif number >= 901 and number <= 910:
		featured = "time_rift"
	var want := clampi(2 + (number - 101) / 130, 2, 6)
	if not featured.is_empty():
		flags[featured] = true
		want -= 1
	for name in _deterministic_shuffle(pool, number):
		if want <= 0:
			break
		if not bool(flags[name]):
			flags[name] = true
			want -= 1
	return flags


# ────────────────────────── 신규 기믹 (101레벨 이후) ──────────────────────────

static func _gimmick_candidate_jellies(level: Dictionary, number: int, salt: int) -> Array[Vector2i]:
	var board: Array = level.grid
	var taken := _special_cells(level)
	var cells: Array[Vector2i] = []
	for y in range(board.size()):
		for x in range(board[y].length()):
			var cell := Vector2i(x, y)
			if G.COLORS.has(board[y][x]) and not taken.has(cell):
				cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return ((a.x * 23 + a.y * 41 + number * salt) % 199) < ((b.x * 23 + b.y * 41 + number * salt) % 199)
	)
	return cells


static func _add_ghost_jellies(level: Dictionary, number: int) -> void:
	## 유령 젤리는 다른 색 캐처가 그대로 통과할 수 있어 막힌 길이 열린다.
	## 제약을 푸는 방향이라 기존 풀이를 절대 막지 않는다.
	var candidates := _gimmick_candidate_jellies(level, number, 13)
	if candidates.is_empty():
		return
	var count := mini(candidates.size(), 2 + (number - 101) / 90)
	var ghosts: Array = []
	for i in range(count):
		ghosts.append([candidates[i].x, candidates[i].y])
	if ghosts.is_empty():
		return
	level["ghosts"] = ghosts


static func _add_bomb_jellies(level: Dictionary, number: int) -> void:
	## 폭탄 젤리를 구조하면 인접한 장벽이 부서져 새 길이 열린다.
	## 역시 제약을 푸는 방향이므로 풀이 가능성을 해치지 않는다.
	var board: Array = level.grid
	var candidates := _gimmick_candidate_jellies(level, number, 29)
	var useful: Array[Vector2i] = []
	for cell in candidates:
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var near: Vector2i = cell + dir
			if near.x >= 0 and near.y >= 0 and near.y < board.size() and near.x < board[near.y].length() and board[near.y][near.x] == "#":
				useful.append(cell)
				break
	var picks := useful if not useful.is_empty() else candidates
	if picks.is_empty():
		return
	var count := mini(picks.size(), 1 + (number - 191) / 120)
	var bombs: Array = []
	for i in range(count):
		bombs.append([picks[i].x, picks[i].y])
	if bombs.is_empty():
		return
	level["bombs"] = bombs


static func _add_sticky_tiles(level: Dictionary, number: int) -> void:
	## 끈끈이 바닥은 통과 자체를 막지 않고 이동을 지연시켜 동선 비용만 올린다.
	var board: Array = level.grid
	var taken := _special_cells(level)
	var occupied := {}
	for spec in level.catchers:
		var origin := Vector2i(int(spec.cell[0]), int(spec.cell[1]))
		for off in G.SHAPES[spec.shape]:
			occupied[origin + off] = true
	var candidates: Array[Vector2i] = []
	for y in range(board.size()):
		for x in range(board[y].length()):
			var cell := Vector2i(x, y)
			if board[y][x] == "." and not taken.has(cell) and not occupied.has(cell):
				candidates.append(cell)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return ((a.x * 31 + a.y * 17 + number * 11) % 151) < ((b.x * 31 + b.y * 17 + number * 11) % 151)
	)
	var count := mini(candidates.size(), 2 + (number - 131) / 100)
	var sticky: Array = []
	for i in range(count):
		sticky.append([candidates[i].x, candidates[i].y])
	if sticky.is_empty():
		return
	level["sticky"] = sticky


static func _add_one_way_tiles(level: Dictionary, number: int) -> void:
	## 일방통행 타일은 지정 방향으로만 진입할 수 있어 동선을 강하게 제한한다.
	## 제약을 조이는 기믹이므로 배치할 때마다 전체 풀이를 다시 검사한다.
	var board: Array = level.grid
	var taken := _special_cells(level)
	var occupied := {}
	for spec in level.catchers:
		var origin := Vector2i(int(spec.cell[0]), int(spec.cell[1]))
		for off in G.SHAPES[spec.shape]:
			occupied[origin + off] = true
	var candidates: Array[Vector2i] = []
	for y in range(board.size()):
		for x in range(board[y].length()):
			var cell := Vector2i(x, y)
			if board[y][x] == "." and not taken.has(cell) and not occupied.has(cell):
				candidates.append(cell)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return ((a.x * 37 + a.y * 19 + number * 7) % 173) < ((b.x * 37 + b.y * 19 + number * 7) % 173)
	)
	var target := mini(2, 1 + (number - 161) / 150)
	var placed: Array = []
	var budget := 14
	for cell in candidates:
		if placed.size() >= target or budget <= 0:
			break
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if budget <= 0:
				break
			budget -= 1
			placed.append({"cell": [cell.x, cell.y], "dir": [dir.x, dir.y]})
			level["one_ways"] = placed
			if _is_greedily_solvable(level):
				break
			placed.pop_back()
			level.erase("one_ways")
	if placed.is_empty():
		level.erase("one_ways")
	else:
		level["one_ways"] = placed


static func _gimmick_candidate_floor(level: Dictionary, number: int, salt: int) -> Array[Vector2i]:
	var board: Array = level.grid
	var taken := _special_cells(level)
	var occupied := {}
	for spec in level.catchers:
		var origin := Vector2i(int(spec.cell[0]), int(spec.cell[1]))
		for off in G.SHAPES[spec.shape]:
			occupied[origin + off] = true
	var candidates: Array[Vector2i] = []
	for y in range(board.size()):
		for x in range(board[y].length()):
			var cell := Vector2i(x, y)
			if board[y][x] == "." and not taken.has(cell) and not occupied.has(cell):
				candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return ((a.x * 43 + a.y * 61 + number * salt) % 257) < ((b.x * 43 + b.y * 61 + number * salt) % 257)
	)
	return candidates


static func _add_portals(level: Dictionary, number: int) -> void:
	## 두 포털은 블록의 모양을 유지한 채 반대편으로 순간 이동시킨다.
	var candidates := _gimmick_candidate_floor(level, number, 17)
	var pair_count := mini(2 if number >= 751 else 1, candidates.size() / 2)
	if pair_count <= 0:
		return
	var portals: Array = []
	for i in range(pair_count):
		var a: Vector2i = candidates[i * 2]
		var b: Vector2i = candidates[i * 2 + 1]
		portals.append({"a": [a.x, a.y], "b": [b.x, b.y]})
	if not portals.is_empty():
		level["portals"] = portals


static func _add_fragile_walls(level: Dictionary, number: int) -> void:
	## 균열벽은 몇 번 이동하면 무너져 후반 동선이 열리는 시간차 지형이다.
	var board: Array = level.grid
	var candidates: Array[Vector2i] = []
	for y in range(board.size()):
		for x in range(board[y].length()):
			if board[y][x] == "#":
				candidates.append(Vector2i(x, y))
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return ((a.x * 31 + a.y * 47 + number * 23) % 211) < ((b.x * 31 + b.y * 47 + number * 23) % 211)
	)
	var fragile: Array = []
	var count := mini(candidates.size(), 1 + (number - 601) / 180)
	for i in range(count):
		var cell := candidates[i]
		fragile.append([cell.x, cell.y, 4 + posmod(number + i, 4)])
	if not fragile.is_empty():
		level["fragile_walls"] = fragile


static func _add_fog_jellies(level: Dictionary, number: int) -> void:
	## 안개 젤리는 블록이 가까이 오기 전까지 색을 감춰 경로 기억을 요구한다.
	var candidates := _gimmick_candidate_jellies(level, number, 37)
	var fog: Array = []
	var count := mini(candidates.size(), 3 + (number - 701) / 90)
	for i in range(count):
		fog.append([candidates[i].x, candidates[i].y])
	if not fog.is_empty():
		level["fog"] = fog


static func _add_current_tiles(level: Dictionary, number: int) -> void:
	## 바람길은 화살표 방향 이동에는 시간을 돌려주고 역풍 이동에는 시간을 빼앗는다.
	var candidates := _gimmick_candidate_floor(level, number, 41)
	var directions := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	var currents: Array = []
	var count := mini(candidates.size(), 2 + (number - 801) / 100)
	for i in range(count):
		var cell: Vector2i = candidates[i]
		var dir: Vector2i = directions[posmod(number + i * 3, directions.size())]
		currents.append({"cell": [cell.x, cell.y], "dir": [dir.x, dir.y]})
	if not currents.is_empty():
		level["currents"] = currents


static func _add_time_rifts(level: Dictionary, number: int) -> void:
	## 시간균열은 처음 밟을 때만 시간을 훔쳐 안전한 우회로 선택을 요구한다.
	var candidates := _gimmick_candidate_floor(level, number, 53)
	var rifts: Array = []
	var count := mini(candidates.size(), 2 + (number - 901) / 80)
	for i in range(count):
		var cell: Vector2i = candidates[i]
		rifts.append([cell.x, cell.y, 3.0 + float((number + i) % 3)])
	if not rifts.is_empty():
		level["time_rifts"] = rifts


# ────────────────────────── 보스 관문 (10레벨마다) ──────────────────────────

static func _add_boss(level: Dictionary, number: int) -> void:
	## 10레벨마다 등장하는 관문 보스. 세 종류가 순환하며 각각 다른 대응을 요구한다.
	##   king     — 왕관 젤리. 같은 색 블록으로 여러 번 두드려야 구조된다.
	##   splitter — 구조하는 순간 분열해 같은 색 미니 젤리를 흩뿌린다.
	##   thief    — 살아 있는 동안 계속 시간을 훔친다. 우선순위 판단을 강제한다.
	var boss_type := boss_type_for(number)
	if boss_type.is_empty() or number < 10:
		return
	var board: Array = level.grid
	var taken := _special_cells(level)
	# 분열 보스는 미니 젤리가 나올 빈칸이 필요하므로 주변이 열린 젤리를 우선한다.
	var scored: Array[Dictionary] = []
	for y in range(board.size()):
		for x in range(board[y].length()):
			var cell := Vector2i(x, y)
			if not G.COLORS.has(board[y][x]) or taken.has(cell):
				continue
			var open_neighbors := 0
			for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var near: Vector2i = cell + dir
				if near.x < 0 or near.y < 0 or near.y >= board.size() or near.x >= board[near.y].length():
					continue
				if board[near.y][near.x] == ".":
					open_neighbors += 1
			scored.append({"x": x, "y": y, "score": open_neighbors * 10 + ((x * 13 + y * 29 + number) % 7)})
	if scored.is_empty():
		return
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.score) > int(b.score)
	)
	scored = scored.slice(0, 10)
	# 후보를 여러 개 준비해 순서대로 시도한다. 분열 보스는 여유 수용량을 어느
	# 블록에 얹느냐에 따라 풀이 가능 여부가 갈리므로 블록도 함께 바꿔 가며 찾는다.
	var ranked: Array[Vector2i] = []
	for entry in scored:
		ranked.append(Vector2i(int(entry.x), int(entry.y)))
	for cell in ranked:
		var color := String(board[cell.y][cell.x])
		var boss := {"type": boss_type, "cell": [cell.x, cell.y], "color": color}
		match boss_type:
			"king":
				boss["hp"] = clampi(2 + number / 150, 2, 4)
			"thief":
				boss["steal_interval"] = 6.0
				boss["steal_amount"] = 2.0 + float(mini(number, 400)) / 200.0
				boss["bounty"] = 12.0
			"splitter":
				var room := 0
				for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var near: Vector2i = cell + dir
					if near.x >= 0 and near.y >= 0 and near.y < board.size() and near.x < board[near.y].length() and board[near.y][near.x] == ".":
						room += 1
				var splits := mini(room, clampi(1 + number / 200, 1, 3))
				if splits <= 0:
					continue
				boss["splits"] = splits
		level["boss"] = boss
		if boss_type != "splitter":
			if _is_greedily_solvable(level):
				return
			level.erase("boss")
			continue
		# 분열분을 담을 여유 수용량을 같은 색 블록에 하나씩 얹어 보며 검증한다.
		var splits_amount := int(boss.splits)
		var granted := false
		for spec in level.catchers:
			if String(spec.color) != color:
				continue
			spec["capacity"] = int(spec.get("capacity", 0)) + splits_amount
			if _is_greedily_solvable(level):
				granted = true
				break
			spec["capacity"] = int(spec.get("capacity", 0)) - splits_amount
		if granted:
			return
		level.erase("boss")


static func _grant_extra_capacity(level: Dictionary, color: String, amount: int) -> bool:
	for spec in level.catchers:
		if String(spec.color) == color:
			spec["capacity"] = int(spec.get("capacity", 0)) + amount
			return true
	return false


static func _revoke_extra_capacity(level: Dictionary, color: String, amount: int) -> void:
	for spec in level.catchers:
		if String(spec.color) == color:
			spec["capacity"] = maxi(0, int(spec.get("capacity", 0)) - amount)
			return


# ────────────────────────── 대체 승리 조건 ──────────────────────────

static func _add_alt_win_condition(level: Dictionary, number: int) -> void:
	## 후반 단조로움을 막는 목표 변주. 세 종류가 정해진 간격으로 순환 등장한다.
	##   move_limit  — 제한된 이동 수 안에 전원 구조
	##   color_order — 지정된 색 순서대로만 구조 가능
	##   escort      — 호위 대상 젤리는 지정된 전담 블록만 구조 가능
	if number < 111 or _is_milestone_challenge(number):
		return
	var kind := ""
	if number % 10 == 3 and number >= 111:
		kind = "move_limit"
	elif number % 10 == 6 and number >= 141:
		kind = "color_order"
	elif number % 10 == 8 and number >= 171:
		kind = "escort"
	if kind.is_empty():
		return
	match kind:
		"move_limit":
			var moves := _solve_move_cost(level)
			if moves <= 0:
				return
			# 기준이 되는 자동 풀이는 최적해가 아니라 넉넉한 상한이므로, 그 위에
			# 40% 정도만 여유를 준다. 이보다 크면 제한 이동 규칙이 사실상 무의미해진다.
			var slack := 1.4 - minf(0.15, float(number - 111) / 2000.0)
			level["move_limit"] = int(ceil(float(moves) * slack)) + 6
		"color_order":
			var order := _color_order_for(level, number)
			if order.size() < 2:
				return
			level["color_order"] = order
			if not _is_greedily_solvable(level):
				level.erase("color_order")
		"escort":
			if not _assign_escort(level, number):
				return


static func _color_order_for(level: Dictionary, number: int) -> Array:
	## 여섯 색 전부를 줄 세우면 나머지 색이 전부 장애물이 되어 사실상 풀 수 없다.
	## 실제 풀이 흐름에서 앞쪽 두세 색만 뽑아 "이 색부터 먼저" 규칙으로 쓴다.
	var colors: Array = []
	for spec in level.catchers:
		var color := String(spec.color)
		if not colors.has(color):
			colors.append(color)
	if colors.size() < 2:
		return []
	var natural := _natural_clear_order(level)
	if natural.size() < 2:
		natural = _deterministic_shuffle(colors, number)
	var wanted := 3 if number >= 300 else 2
	return natural.slice(0, mini(wanted, natural.size()))


static func _assign_escort(level: Dictionary, number: int) -> bool:
	## 같은 색 캐처가 둘 이상일 때만 의미가 있다. 전담 블록이 실제로 도달할 수 있는
	## 젤리만 호위 대상으로 삼고, 배정 후 전체 풀이를 다시 검증한다.
	var board: Array = level.grid
	var specs: Array = level.catchers
	var by_color := {}
	for i in range(specs.size()):
		var color := String(specs[i].color)
		var list: Array = by_color.get(color, [])
		list.append(i)
		by_color[color] = list
	var taken := _special_cells(level)
	var positions: Array[Vector2i] = []
	var active: Array[bool] = []
	for spec in specs:
		positions.append(Vector2i(int(spec.cell[0]), int(spec.cell[1])))
		active.append(true)
	var budget := 10
	for color in by_color:
		var indices: Array = by_color[color]
		if indices.size() < 2:
			continue
		var guard := int(indices[0])
		for y in range(board.size()):
			for x in range(board[y].length()):
				if budget <= 0:
					return false
				var cell := Vector2i(x, y)
				if board[y][x] != color or taken.has(cell):
					continue
				for off in G.SHAPES[specs[guard].shape]:
					if not _can_reach_origin(board, specs, positions, active, guard, cell - off):
						continue
					budget -= 1
					level["escort"] = {"cell": [cell.x, cell.y], "catcher": guard, "color": color}
					if _is_greedily_solvable(level):
						return true
					level.erase("escort")
					break
	return false


static func _compose_objective_hint(level: Dictionary, number: int) -> void:
	## 보스/대체 승리 조건/복합 기믹이 겹칠 때 플레이어가 먼저 읽어야 할 규칙을 안내한다.
	var lines: Array[String] = []
	if level.has("boss"):
		match String(level.boss.type):
			"king":
				lines.append("👑 왕젤리는 같은 색 블록으로 %d번 두드려야 구조돼요!" % int(level.boss.get("hp", 2)))
			"splitter":
				lines.append("🌀 분열 젤리는 구조하는 순간 %d마리로 갈라져요. 담을 자리를 남겨 두세요!" % (int(level.boss.get("splits", 1)) + 1))
			"thief":
				lines.append("⏳ 시간 도둑이 계속 시간을 훔쳐요. 먼저 잡을지 나중에 잡을지 결정하세요!")
	if level.has("move_limit"):
		lines.append("🎯 이동 %d회 안에 모두 구조하세요!" % int(level.move_limit))
	if level.has("color_order"):
		var names: Array[String] = []
		for color in level.color_order:
			names.append(String(G.COLOR_NAMES.get(String(color), String(color))))
		lines.append("🔢 %s 순서를 먼저 지켜 구조하세요! (나머지 색은 자유)" % " → ".join(names))
	if level.has("escort"):
		lines.append("🛡 호위 대상 젤리는 표시된 전담 블록만 구조할 수 있어요!")
	if level.has("shape_seals"):
		lines.append("빛나는 모양 봉인에 같은 색 블록을 정확히 포개 장벽을 여세요!")
	if level.has("exits"):
		lines.append("가득 찬 블록은 같은 색 화살표 출구로 내보내세요!")
	var gimmicks: Array = level.get("gimmicks", [])
	if gimmicks.size() >= 2:
		var labels: Array[String] = []
		for name in gimmicks:
			labels.append(String(GIMMICK_LABELS.get(String(name), String(name))))
		lines.append("복합 관문 · %s의 우선순위를 읽고 구출하세요." % " / ".join(labels))
	elif gimmicks.size() == 1:
		var only := String(gimmicks[0])
		var solo := {
			"frost": "❄ 얼음 젤리는 같은 색 블록으로 얼음을 깨고 다시 지나가야 구출돼요.",
			"chain": "⛓ 번호가 붙은 젤리는 1번부터 차례대로 구출하세요.",
			"switch": "◆ 바닥 스위치를 먼저 밟아 보랏빛 봉인 젤리를 깨우세요.",
			"key": "🔑 열쇠 젤리를 먼저 구출하면 자물쇠 블록이 움직여요.",
			"ghost": "👻 유령 젤리는 다른 색 블록이 그대로 지나갈 수 있어요.",
			"sticky": "🍯 끈끈이 바닥을 지나면 블록이 잠시 느려져요.",
			"one_way": "➤ 화살표 타일은 표시된 방향으로만 들어갈 수 있어요.",
			"bomb": "💣 폭탄 젤리를 구조하면 옆의 장벽이 부서져 길이 열려요.",
			"portal": "🌀 포털을 밟은 블록은 짝이 된 반대편 포털로 순간 이동해요.",
			"fragile": "◇ 균열벽은 표시된 이동 횟수가 지나면 무너져 새 길이 열려요.",
			"fog": "☁ 안개 젤리는 블록이 가까이 가야 색이 보여요.",
			"current": "≋ 바람 방향으로 움직이면 시간을 얻고, 역풍으로 가면 시간을 잃어요.",
			"time_rift": "⌛ 시간균열은 처음 밟을 때 시간을 훔쳐요. 안전한 길로 우회하세요.",
		}
		if solo.has(only):
			lines.append(String(solo[only]))
	if lines.is_empty():
		return
	level["hint"] = "\n".join(lines)


static func _special_cells(level: Dictionary) -> Dictionary:
	var taken := {}
	for raw in level.get("frozen", []):
		taken[Vector2i(int(raw[0]), int(raw[1]))] = true
	for chain in level.get("chains", []):
		for pair in chain.cells:
			taken[Vector2i(int(pair[0]), int(pair[1]))] = true
	for pair in level.get("sealed_jellies", []):
		taken[Vector2i(int(pair[0]), int(pair[1]))] = true
	for pair in level.get("switches", []):
		taken[Vector2i(int(pair[0]), int(pair[1]))] = true
	for lock in level.get("key_locks", []):
		var pair: Array = lock.key
		taken[Vector2i(int(pair[0]), int(pair[1]))] = true
	for exit in level.get("exits", []):
		var pair: Array = exit.cell
		taken[Vector2i(int(pair[0]), int(pair[1]))] = true
	for seal in level.get("shape_seals", []):
		for pair in seal.get("cells", []):
			taken[Vector2i(int(pair[0]), int(pair[1]))] = true
		for pair in seal.get("gates", []):
			taken[Vector2i(int(pair[0]), int(pair[1]))] = true
	# 101레벨 이후 신규 기믹과 보스/호위 표식도 서로 겹치지 않게 한다.
	for pair in level.get("ghosts", []):
		taken[Vector2i(int(pair[0]), int(pair[1]))] = true
	for pair in level.get("bombs", []):
		taken[Vector2i(int(pair[0]), int(pair[1]))] = true
	for pair in level.get("sticky", []):
		taken[Vector2i(int(pair[0]), int(pair[1]))] = true
	for raw in level.get("one_ways", []):
		taken[Vector2i(int(raw.cell[0]), int(raw.cell[1]))] = true
	for portal in level.get("portals", []):
		for key in ["a", "b"]:
			var pair: Array = portal[key]
			taken[Vector2i(int(pair[0]), int(pair[1]))] = true
	for raw in level.get("fragile_walls", []):
		taken[Vector2i(int(raw[0]), int(raw[1]))] = true
	for pair in level.get("fog", []):
		taken[Vector2i(int(pair[0]), int(pair[1]))] = true
	for raw in level.get("currents", []):
		taken[Vector2i(int(raw.cell[0]), int(raw.cell[1]))] = true
	for raw in level.get("time_rifts", []):
		taken[Vector2i(int(raw[0]), int(raw[1]))] = true
	if level.has("boss"):
		taken[Vector2i(int(level.boss.cell[0]), int(level.boss.cell[1]))] = true
	if level.has("escort"):
		taken[Vector2i(int(level.escort.cell[0]), int(level.escort.cell[1]))] = true
	return taken


static func _add_frozen_jellies(level: Dictionary, number: int) -> void:
	## L51부터 같은 색 블록으로 먼저 얼음을 깨고 다시 지나가야 흡수되는 신규 기믹.
	if number < 51:
		return
	var board: Array = level.grid
	var candidates: Array[Vector2i] = []
	for y in range(board.size()):
		for x in range(board[y].length()):
			if not G.COLORS.has(board[y][x]):
				continue
			var open_neighbors := 0
			for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next: Vector2i = Vector2i(x, y) + dir
				if next.x >= 0 and next.y >= 0 and next.x < board[y].length() and next.y < board.size() and board[next.y][next.x] != "_" and board[next.y][next.x] != "#":
					open_neighbors += 1
			# 막다른 한 칸은 재진입이 애매하므로 얼리지 않는다.
			if open_neighbors >= 2:
				candidates.append(Vector2i(x, y))
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return ((a.x * 17 + a.y * 31 + number * 7) % 101) < ((b.x * 17 + b.y * 31 + number * 7) % 101)
	)
	var local := (number - 1) % 10
	var target_count := mini(candidates.size(), 2 + (number - 51) / 15 + local / 4)
	var frozen: Array = []
	for i in range(target_count):
		var cell := candidates[i]
		var layers := 2 if number >= 71 and (i + number) % 3 == 0 else 1
		frozen.append([cell.x, cell.y, layers])
	if frozen.is_empty():
		return
	level["frozen"] = frozen
	var frost_hint := "❄ 얼음 젤리는 같은 색 블록으로 얼음을 깨고 다시 지나가야 구출돼요."
	if number >= 71:
		frost_hint = "❄ 숫자 얼음은 표시된 횟수만큼 깨뜨린 뒤 다시 지나가야 구출돼요."
	level.hint = String(level.get("hint", "")) + "\n" + frost_hint


static func _add_rescue_chain(level: Dictionary, number: int) -> void:
	## 같은 색 젤리를 표시된 번호 순서대로 구조해야 하는 경로 계획 기믹.
	var board: Array = level.grid
	var by_color := {}
	var taken := _special_cells(level)
	for y in range(board.size()):
		for x in range(board[y].length()):
			var color: String = board[y][x]
			var cell := Vector2i(x, y)
			if G.COLORS.has(color) and not taken.has(cell):
				var cells: Array = by_color.get(color, [])
				cells.append(cell)
				by_color[color] = cells
	var chosen_color := ""
	for color in G.COLORS.keys():
		if by_color.has(color) and by_color[color].size() >= 3:
			chosen_color = color
			break
	# 복합 관문에서 후보가 겹쳤다면 체인은 다른 표식과 겹쳐도 진행 가능하다.
	if chosen_color.is_empty():
		for color in G.COLORS.keys():
			var fallback: Array = []
			for y in range(board.size()):
				for x in range(board[y].length()):
					if board[y][x] == color:
						fallback.append(Vector2i(x, y))
			if fallback.size() >= 2:
				chosen_color = color
				by_color[color] = fallback
				break
	if chosen_color.is_empty():
		return
	var candidates: Array = by_color[chosen_color]
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return ((a.x * 13 + a.y * 29 + number) % 97) < ((b.x * 13 + b.y * 29 + number) % 97)
	)
	var count := mini(candidates.size(), 3 if number >= 66 else 2)
	var cells: Array = []
	for i in range(count):
		cells.append([candidates[i].x, candidates[i].y])
	level["chains"] = [{"color": chosen_color, "cells": cells}]
	level.hint = String(level.get("hint", "")) + "\n⛓ 번호가 붙은 젤리는 1번부터 차례대로 구출하세요."


static func _find_initial_switch_cell(level: Dictionary) -> Vector2i:
	var board: Array = level.grid
	var specs: Array = level.catchers
	var positions: Array[Vector2i] = []
	var active: Array[bool] = []
	for spec in specs:
		positions.append(Vector2i(int(spec.cell[0]), int(spec.cell[1])))
		active.append(true)
	var taken := _special_cells(level)
	for si in range(specs.size()):
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var target: Vector2i = positions[si] + dir
			if not _test_can_place(board, specs, positions, active, si, target):
				continue
			for off in G.SHAPES[specs[si].shape]:
				var cell: Vector2i = target + off
				if board[cell.y][cell.x] == "." and not taken.has(cell):
					return cell
	# 첫 한 칸이 막힌 레벨은 정지한 다른 블록을 통과하지 않고 도달 가능한 모든 원점을 검사한다.
	for si in range(specs.size()):
		for y in range(board.size()):
			for x in range(board[y].length()):
				var target := Vector2i(x, y)
				if not _can_reach_origin(board, specs, positions, active, si, target):
					continue
				for off in G.SHAPES[specs[si].shape]:
					var cell: Vector2i = target + off
					if board[cell.y][cell.x] == "." and not taken.has(cell):
						return cell
	return Vector2i(-1, -1)


static func _add_rescue_switch(level: Dictionary, number: int) -> void:
	## 시작 위치에서 한 칸 이동해 반드시 누를 수 있는 스위치만 배치한다.
	var switch_cell := _find_initial_switch_cell(level)
	if switch_cell.x < 0:
		return
	var board: Array = level.grid
	var taken := _special_cells(level)
	taken[switch_cell] = true
	var candidates: Array[Vector2i] = []
	for y in range(board.size()):
		for x in range(board[y].length()):
			var cell := Vector2i(x, y)
			if G.COLORS.has(board[y][x]) and not taken.has(cell):
				candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(switch_cell) > b.distance_squared_to(switch_cell)
	)
	if candidates.is_empty():
		return
	var sealed: Array = []
	var count := mini(candidates.size(), 2 + maxi(0, number - 71) / 3)
	for i in range(count):
		sealed.append([candidates[i].x, candidates[i].y])
	level["switches"] = [[switch_cell.x, switch_cell.y]]
	level["sealed_jellies"] = sealed
	level.hint = String(level.get("hint", "")) + "\n◆ 바닥 스위치를 먼저 밟아 보랏빛 봉인 젤리를 깨우세요."


static func _add_key_lock(level: Dictionary, number: int) -> void:
	## 다른 블록으로 즉시 획득 가능한 열쇠만 사용해 시작부터 막히는 경우를 방지한다.
	var board: Array = level.grid
	var specs: Array = level.catchers
	if specs.size() < 2:
		return
	var positions: Array[Vector2i] = []
	var active: Array[bool] = []
	for spec in specs:
		positions.append(Vector2i(int(spec.cell[0]), int(spec.cell[1])))
		active.append(true)
	var taken := _special_cells(level)
	var key_cell := Vector2i(-1, -1)
	var key_owner := -1
	for si in range(specs.size()):
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var target: Vector2i = positions[si] + dir
			if not _test_can_place(board, specs, positions, active, si, target):
				continue
			for off in G.SHAPES[specs[si].shape]:
				var cell: Vector2i = target + off
				if board[cell.y][cell.x] == specs[si].color and not taken.has(cell):
					key_cell = cell
					key_owner = si
					break
			if key_owner >= 0:
				break
		if key_owner >= 0:
			break
	# 인접 흡수가 없으면 실제 경로 탐색으로 도달 가능한 같은 색 젤리를 고른다.
	if key_owner < 0:
		for si in range(specs.size()):
			for y in range(board.size()):
				for x in range(board[y].length()):
					var cell := Vector2i(x, y)
					if board[y][x] != specs[si].color or taken.has(cell):
						continue
					for off in G.SHAPES[specs[si].shape]:
						var target: Vector2i = cell - off
						if _can_reach_origin(board, specs, positions, active, si, target):
							key_cell = cell
							key_owner = si
							break
					if key_owner >= 0:
						break
			if key_owner >= 0:
				break
	if key_owner < 0:
		return
	var lock_index := specs.size() - 1
	if lock_index == key_owner:
		lock_index = 0
	if lock_index == key_owner:
		return
	level["key_locks"] = [{"catcher": lock_index, "key": [key_cell.x, key_cell.y]}]
	level.hint = String(level.get("hint", "")) + "\n🔑 열쇠 젤리를 먼저 구출하면 자물쇠 블록이 움직여요."


static func visible_chapter_count(save) -> int:
	## 1~50은 기본 공개, 이후 챕터는 직전 10단계의 마지막 레벨 클리어 시 공개한다.
	var visible := 5
	for chapter in range(5, CHAPTER_NAMES.size()):
		var previous_final_level := chapter * 10 - 1
		if save.get_stars(previous_final_level) <= 0:
			break
		var segment := chapter * LEVELS_PER_CHAPTER / LEVEL_CHUNK_SIZE
		if not save.is_level_segment_unlocked(segment):
			break
		visible += 1
	return visible


static func _fix_known_mobility_traps(level: Dictionary, number: int) -> void:
	## 자동 풀이는 다른 색을 먼저 치우는 순서를 허용하지만, 시작부터 사방이 막힌 블록은
	## 클릭 고장으로 오해하기 쉽다. 플레이 테스트에서 확인된 배치만 최소 이동으로 보정한다.
	if number == 39:
		var board: Array = level.grid
		# 이전 생성형 배치에서 사용하던 보정.
		if board.size() > 8 and board[6].length() > 6 and board[6][5] == "R" and board[8][0] == ".":
			_put(board, 5, 6, ".")
			_put(board, 0, 8, "R")
		# 현재 L39의 파란 S1(4,6)은 오른쪽만 열려 있어 주변 대형 블록 때문에
		# 터치가 고장 난 것처럼 보인다. 아래 빨간 젤리를 안전한 하단 빈칸으로
		# 옮겨 오른쪽/아래 두 방향의 확실한 탈출구를 보장한다.
		if board.size() > 8 and board[7].length() > 4 and board[7][4] == "R" and board[8][1] == ".":
			_put(board, 4, 7, ".")
			_put(board, 1, 8, "R")


static func _add_rescue_exits(level: Dictionary, number: int) -> void:
	## L6 이후 봉인 레벨과 번갈아 등장하는 색상별 공용 배송 통로.
	## FULL 블록은 같은 색 출구까지 이동해야 보드에서 제거된다.
	if number < 6 or level.has("shape_seals"):
		return
	var board: Array = level.grid
	var h: int = board.size()
	var w: int = board[0].length()
	var colors: Array[String] = []
	for spec in level.catchers:
		var color: String = spec.color
		if not colors.has(color):
			colors.append(color)
	var candidates: Array[Dictionary] = []
	for y in range(h):
		for x in range(w):
			if board[y][x] != ".":
				continue
			var cell := Vector2i(x, y)
			for dir: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				var next_cell: Vector2i = cell + dir
				if next_cell.x < 0 or next_cell.y < 0 or next_cell.x >= w or next_cell.y >= h or board[next_cell.y][next_cell.x] == "_":
					candidates.append({"cell": [x, y], "direction": [dir.x, dir.y]})
					break
	if candidates.size() < colors.size():
		return
	# 여러 결정적 배치를 시도하고 실제 흡수+배송 자동 풀이가 되는 첫 조합만 채택한다.
	for attempt in range(48):
		var exits: Array = []
		var used := {}
		var valid := true
		for ci in range(colors.size()):
			var picked: Dictionary = {}
			for offset in range(candidates.size()):
				var index := (attempt * 3 + ci * 7 + offset) % candidates.size()
				var candidate: Dictionary = candidates[index]
				var key := "%s,%s" % [candidate.cell[0], candidate.cell[1]]
				if not used.has(key):
					picked = candidate
					used[key] = true
					break
			if picked.is_empty():
				valid = false
				break
			exits.append({
				"color": colors[ci],
				"catcher": -1,
				"cell": picked.cell,
				"direction": picked.direction,
			})
		if not valid:
			continue
		level["exits"] = exits
		if _is_greedily_solvable(level):
			level.hint = "젤리를 모두 담아 GO가 된 블록을 같은 색 화살표 출구로 내보내세요!"
			return
	level.erase("exits")


static func _add_shape_seal(level: Dictionary, number: int) -> void:
	## 시그니처 기믹: 같은 색 폴리오미노를 룬 모양에 정확히 포개면 수정 장벽이 열린다.
	## L6부터 4레벨 간격으로 등장하며, 장벽이 닫힌 상태에서도 기본 풀이는 항상 보장한다.
	if number < 6 or (number - 6) % 4 != 0:
		return
	var board: Array = level.grid
	var h: int = board.size()
	var w: int = board[0].length()
	var specs: Array = level.catchers
	var positions: Array[Vector2i] = []
	var active: Array[bool] = []
	var occupied := {}
	for spec in specs:
		var org := Vector2i(spec.cell[0], spec.cell[1])
		positions.append(org)
		active.append(true)
		for off in G.SHAPES[spec.shape]:
			occupied[org + off] = true
	var chosen_index := -1
	var seal_origin := Vector2i(-1, -1)
	for si in range(specs.size()):
		if G.SHAPES[specs[si].shape].size() < 2:
			continue
		var own_start := {}
		for off in G.SHAPES[specs[si].shape]:
			own_start[positions[si] + off] = true
		var targets: Array[Vector2i] = []
		for y in range(h):
			for x in range(w):
				targets.append(Vector2i(x, y))
		targets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.distance_squared_to(positions[si]) > b.distance_squared_to(positions[si])
		)
		for target in targets:
			if target == positions[si]:
				continue
			if not _test_can_place(board, specs, positions, active, si, target):
				continue
			var clean := true
			for off in G.SHAPES[specs[si].shape]:
				var cell: Vector2i = target + off
				# 같은 색 젤리가 놓인 룬은 허용한다. 블록이 포개지는 순간 구조와 봉인 해제가 함께 일어난다.
				if occupied.has(cell) and not own_start.has(cell):
					clean = false
					break
			if clean and _can_reach_origin(board, specs, positions, active, si, target):
				chosen_index = si
				seal_origin = target
				break
		if chosen_index >= 0:
			break
	if chosen_index < 0:
		return
	var seal_cells: Array = []
	var seal_lookup := {}
	for off in G.SHAPES[specs[chosen_index].shape]:
		var cell: Vector2i = seal_origin + off
		seal_cells.append([cell.x, cell.y])
		seal_lookup[cell] = true
	var gate_candidates: Array[Vector2i] = []
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var cell := Vector2i(x, y)
			if board[y][x] != "." or occupied.has(cell) or seal_lookup.has(cell):
				continue
			var open_neighbors := 0
			for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var ch: String = board[y + dir.y][x + dir.x]
				if ch != "_" and ch != "#":
					open_neighbors += 1
			if open_neighbors >= 2:
				gate_candidates.append(cell)
	gate_candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var center := Vector2(w - 1, h - 1) * 0.5
		return Vector2(a).distance_squared_to(center) < Vector2(b).distance_squared_to(center)
	)
	for gate in gate_candidates:
		_put(board, gate.x, gate.y, "#")
		var seal_reachable := _can_reach_origin(board, specs, positions, active, chosen_index, seal_origin)
		if seal_reachable and _is_greedily_solvable(level):
			_put(board, gate.x, gate.y, ".")
			level["shape_seals"] = [{
				"color": specs[chosen_index].color,
				"shape": specs[chosen_index].shape,
				"cells": seal_cells,
				"gates": [[gate.x, gate.y]],
			}]
			level.hint = "빛나는 모양 봉인에 같은 색 블록을 정확히 포개 장벽을 여세요!"
			print("[shape seal] added ", level.name, " ", specs[chosen_index].color, "-", specs[chosen_index].shape)
			return
		_put(board, gate.x, gate.y, ".")


static func _validate_shape_seal(level: Dictionary) -> void:
	if not level.has("shape_seals"):
		return
	if not _shape_seal_is_valid(level):
		print("[shape seal] removed after compaction ", level.name)
		level.erase("shape_seals")


static func _shape_seal_is_valid(level: Dictionary) -> bool:
	var board: Array = level.grid
	var specs: Array = level.catchers
	var positions: Array[Vector2i] = []
	var active: Array[bool] = []
	for spec in specs:
		positions.append(Vector2i(spec.cell[0], spec.cell[1]))
		active.append(true)
	var seal: Dictionary = level.shape_seals[0]
	var chosen_index := -1
	for i in range(specs.size()):
		if specs[i].color == seal.color and specs[i].shape == seal.shape:
			chosen_index = i
			break
	if chosen_index < 0:
		return false
	var first := Vector2i(int(seal.cells[0][0]), int(seal.cells[0][1]))
	var seal_origin: Vector2i = first - G.SHAPES[seal.shape][0]
	for pair in seal.gates:
		_put(board, int(pair[0]), int(pair[1]), "#")
	# 닫힌 상태에서는 봉인 룬까지만 도달하면 된다. 룬을 맞춘 뒤 장벽이
	# 사라진 열린 상태에서 남은 젤리를 전부 구출할 수 있는지 별도로 검사한다.
	var seal_reachable := _can_reach_origin(board, specs, positions, active, chosen_index, seal_origin)
	for pair in seal.gates:
		_put(board, int(pair[0]), int(pair[1]), ".")
	var solvable_after_open := _is_greedily_solvable(level)
	return seal_reachable and solvable_after_open


static func _can_reach_origin(board: Array, specs: Array, positions: Array[Vector2i], active: Array[bool], ci: int, target: Vector2i, ctx: Dictionary = {}) -> bool:
	var queue: Array[Vector2i] = [positions[ci]]
	var seen := {positions[ci]: true}
	var head := 0
	while head < queue.size():
		var origin: Vector2i = queue[head]
		head += 1
		if origin == target:
			return true
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = origin + dir
			if seen.has(next):
				continue
			if not _test_can_place(board, specs, positions, active, ci, next, ctx):
				continue
			if not _one_way_allows(ctx, specs, ci, origin, next):
				continue
			seen[next] = true
			queue.append(next)
	return false


static func _remove_unused_islands(level: Dictionary) -> void:
	## 젤리나 캐처가 하나도 없는 분리된 타일 섬은 장식적 빈 공간이므로 완전히 제거한다.
	var board: Array = level.grid
	var h: int = board.size()
	var w: int = board[0].length()
	var occupied := {}
	for spec in level.catchers:
		var org := Vector2i(spec.cell[0], spec.cell[1])
		for off in G.SHAPES[spec.shape]:
			occupied[org + off] = true
	for seal in level.get("shape_seals", []):
		for pair in seal.cells:
			occupied[Vector2i(int(pair[0]), int(pair[1]))] = true
		for pair in seal.gates:
			occupied[Vector2i(int(pair[0]), int(pair[1]))] = true
	var seen := {}
	for y in range(h):
		for x in range(w):
			var start := Vector2i(x, y)
			if board[y][x] == "_" or seen.has(start):
				continue
			var queue: Array[Vector2i] = [start]
			var component: Array[Vector2i] = []
			var has_content := false
			seen[start] = true
			var head := 0
			while head < queue.size():
				var cell: Vector2i = queue[head]
				head += 1
				component.append(cell)
				if occupied.has(cell) or G.COLORS.has(board[cell.y][cell.x]):
					has_content = true
				for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var next: Vector2i = cell + dir
					if next.x >= 0 and next.y >= 0 and next.x < w and next.y < h and board[next.y][next.x] != "_" and not seen.has(next):
						seen[next] = true
						queue.append(next)
			if not has_content:
				for cell in component:
					_put(board, cell.x, cell.y, "_")


static func _reduce_empty_space(level: Dictionary, number: int) -> void:
	## 캐처가 실제로 이동하는 데 필요하지 않은 외곽 빈 타일부터 깎아 보드를 조밀하게 만든다.
	## 각 칸을 제거할 때마다 런타임과 같은 충돌 규칙으로 풀이 가능성을 다시 확인한다.
	var board: Array = level.grid
	var h: int = board.size()
	var w: int = board[0].length()
	var occupied := {}
	for spec in level.catchers:
		var org := Vector2i(spec.cell[0], spec.cell[1])
		for off in G.SHAPES[spec.shape]:
			occupied[org + off] = true
	for seal in level.get("shape_seals", []):
		for pair in seal.cells:
			occupied[Vector2i(int(pair[0]), int(pair[1]))] = true
		for pair in seal.gates:
			occupied[Vector2i(int(pair[0]), int(pair[1]))] = true
	var free_empty := 0
	for y in range(h):
		for x in range(w):
			if board[y][x] == "." and not occupied.has(Vector2i(x, y)):
				free_empty += 1
	# 초반 이후 바로 빽빽해지고, 챕터가 진행될수록 여유 칸 목표를 조금씩 낮춘다.
	var target := 14
	if number >= 11:
		target = 12
	if number >= 21:
		target = 10
	if number >= 31:
		target = 9
	if number >= 41:
		target = 8
	if number >= 51:
		target = 7
	if number >= 71:
		target = 6
	if number >= 91:
		target = 5
	if number >= 151:
		# 후반에는 신규 기믹 타일이 공간을 대신 잡아먹으므로 과도한 압축을 하지 않는다.
		# 생성 비용도 함께 줄어 500레벨 전체 베이크가 현실적인 시간에 끝난다.
		target = 7
	if _is_challenge_level(number):
		target = maxi(4, target - 2)
	if _is_milestone_challenge(number):
		target = maxi(3, target - 1)
	var safety := w * h
	while free_empty > target and safety > 0:
		safety -= 1
		var candidates: Array[Vector2i] = []
		for y in range(h):
			for x in range(w):
				var cell := Vector2i(x, y)
				if board[y][x] != "." or occupied.has(cell):
					continue
				var touches_edge := false
				for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var neighbor: Vector2i = cell + dir
					if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= w or neighbor.y >= h or board[neighbor.y][neighbor.x] == "_":
						touches_edge = true
						break
				if touches_edge:
					candidates.append(cell)
		if candidates.is_empty():
			break
		# 레벨마다 깎이는 방향을 회전시켜 같은 윤곽이 반복되지 않게 한다.
		candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var sa := (a.x * 7 + a.y * 11 + number * 3) % 23
			var sb := (b.x * 7 + b.y * 11 + number * 3) % 23
			return sa < sb
		)
		var removed := false
		for cell in candidates:
			_put(board, cell.x, cell.y, "_")
			if _is_greedily_solvable(level) and (not level.has("shape_seals") or _shape_seal_is_valid(level)):
				free_empty -= 1
				removed = true
				break
			_put(board, cell.x, cell.y, ".")
		if not removed:
			break


static func _initial_move_options(level: Dictionary) -> int:
	var specs: Array = level.catchers
	var positions: Array[Vector2i] = []
	var active: Array[bool] = []
	for spec in specs:
		positions.append(Vector2i(int(spec.cell[0]), int(spec.cell[1])))
		active.append(true)
	var options := 0
	for ci in range(specs.size()):
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if _test_can_place(level.grid, specs, positions, active, ci, positions[ci] + direction):
				options += 1
	return options


static func _pack_milestone_catchers(level: Dictionary, target_options: int) -> void:
	## 흩어진 시작 블록을 빈 타일 안에서 다시 배치해 서로가 자연스러운 벽이 되게 한다.
	## 단순 통로를 새로 그리지 않고 기존 맵/모양을 유지하며, 매 후보마다 전체 풀이를
	## 통과한 경우에만 확정한다.
	var board: Array = level.grid
	var best_options := _initial_move_options(level)
	if best_options <= target_options:
		return
	# 후반에는 캐처가 10개 이상이므로 앞 블록을 옮긴 뒤 뒤 블록의 더 좋은
	# 위치가 새로 생긴다. 여러 차례 반복해 시작 선택지를 목표까지 압축한다.
	# 100레벨 이후에는 관문 수가 많아 생성 비용을 줄이기 위해 반복을 제한한다.
	var passes := 5 if level.catchers.size() <= 10 else 3
	for _pass in range(passes):
		var improved := false
		for si in range(level.catchers.size()):
			var spec: Dictionary = level.catchers[si]
			var original_cell: Array = spec.cell.duplicate()
			var chosen_cell: Array = original_cell.duplicate()
			var chosen_options := best_options
			for y in range(board.size()):
				for x in range(board[y].length()):
					var origin := Vector2i(x, y)
					if not _shape_fits_level_at(level, si, spec.shape, origin):
						continue
					spec.cell = [x, y]
					var options := _initial_move_options(level)
					if options < chosen_options and _is_greedily_solvable(level):
						chosen_options = options
						chosen_cell = [x, y]
						if chosen_options <= target_options:
							break
				if chosen_options <= target_options:
					break
			spec.cell = chosen_cell
			if chosen_options < best_options:
				best_options = chosen_options
				improved = true
			else:
				spec.cell = original_cell
			if best_options <= target_options:
				return
		if not improved:
			break


static func _tighten_milestone_start(level: Dictionary, number: int) -> void:
	## 대도전 시작부의 자유 이동을 내부 벽으로 줄인다. 매 벽 추가 후 전체 풀이를
	## 다시 검사하므로 유일한 시작 수순에 가까워지되 클리어 불가능해지지는 않는다.
	var board: Array = level.grid
	var occupied := {}
	for spec in level.catchers:
		var origin := Vector2i(int(spec.cell[0]), int(spec.cell[1]))
		for off in G.SHAPES[spec.shape]:
			occupied[origin + off] = true
	var protected := {}
	for seal in level.get("shape_seals", []):
		for pair in seal.get("cells", []):
			protected[Vector2i(int(pair[0]), int(pair[1]))] = true
		for pair in seal.get("gates", []):
			protected[Vector2i(int(pair[0]), int(pair[1]))] = true
	var target_empty := maxi(1, 4 - number / 20)
	var target_moves := maxi(2, 6 - number / 10)
	var safety: int = board.size() * String(board[0]).length()
	while safety > 0:
		safety -= 1
		var free_empty := 0
		var candidates: Array[Vector2i] = []
		for y in range(board.size()):
			for x in range(board[y].length()):
				var cell := Vector2i(x, y)
				if board[y][x] == "." and not occupied.has(cell) and not protected.has(cell):
					free_empty += 1
					candidates.append(cell)
		var move_options := _initial_move_options(level)
		if candidates.is_empty() or (free_empty <= target_empty and move_options <= target_moves):
			break
		# 블록 시작점과 가까운 빈칸부터 막아 초반 자유 이동을 우선 줄인다.
		candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var distance_a := 999
			var distance_b := 999
			for origin in positions_from_specs(level.catchers):
				distance_a = mini(distance_a, int(a.distance_squared_to(origin)))
				distance_b = mini(distance_b, int(b.distance_squared_to(origin)))
			if distance_a == distance_b:
				return (a.x * 17 + a.y * 29 + number) % 97 < (b.x * 17 + b.y * 29 + number) % 97
			return distance_a < distance_b
		)
		var added := false
		for cell in candidates:
			_put(board, cell.x, cell.y, "#")
			if _is_greedily_solvable(level) and (not level.has("shape_seals") or _shape_seal_is_valid(level)):
				added = true
				break
			_put(board, cell.x, cell.y, ".")
		if not added:
			break
	level["constricted_start"] = true
	level["initial_move_options"] = _initial_move_options(level)
	level["initial_empty_spaces"] = _count_free_empty(level)


static func positions_from_specs(specs: Array) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for spec in specs:
		positions.append(Vector2i(int(spec.cell[0]), int(spec.cell[1])))
	return positions


static func _count_free_empty(level: Dictionary) -> int:
	var occupied := {}
	for spec in level.catchers:
		var origin := Vector2i(int(spec.cell[0]), int(spec.cell[1]))
		for off in G.SHAPES[spec.shape]:
			occupied[origin + off] = true
	var count := 0
	for y in range(level.grid.size()):
		for x in range(level.grid[y].length()):
			if level.grid[y][x] == "." and not occupied.has(Vector2i(x, y)):
				count += 1
	return count


static func _promote_tetrominoes(level: Dictionary, pool: Array[String], target_count: int) -> void:
	## 축소된 안전 블록을 다시 테트로미노로 승격하되, 실제 풀이가 유지될 때만 확정한다.
	var tetrominoes := 0
	for spec in level.catchers:
		if G.SHAPES[spec.shape].size() == 4:
			tetrominoes += 1
	if tetrominoes >= target_count:
		return
	for singles_first in [true, false]:
		for si in range(level.catchers.size()):
			if tetrominoes >= target_count:
				return
			var spec: Dictionary = level.catchers[si]
			if G.SHAPES[spec.shape].size() == 4 or (spec.shape == "S1") != singles_first:
				continue
			var original: String = spec.shape
			for candidate in pool:
				if G.SHAPES[candidate].size() != 4 or not _shape_fits_level(level, si, candidate):
					continue
				spec.shape = candidate
				if _is_greedily_solvable(level):
					tetrominoes += 1
					break
				spec.shape = original


static func _ensure_challenge_tetrominoes(level: Dictionary, pool: Array[String], minimum_count: int) -> void:
	## 시작 위치가 좁아 일반 승격에 실패한 도전 맵은 블록의 시작 위치도 함께 탐색한다.
	## 매 시도마다 전체 자동 풀이를 통과시켜 큰 블록 때문에 막히는 맵은 저장하지 않는다.
	var tetrominoes := 0
	for spec in level.catchers:
		if G.SHAPES[spec.shape].size() == 4:
			tetrominoes += 1
	if tetrominoes >= minimum_count:
		return
	var board: Array = level.grid
	for si in range(level.catchers.size()):
		if tetrominoes >= minimum_count:
			return
		var spec: Dictionary = level.catchers[si]
		if G.SHAPES[spec.shape].size() == 4:
			continue
		var original_shape: String = spec.shape
		var original_cell: Array = spec.cell.duplicate()
		var promoted := false
		for candidate in pool:
			if G.SHAPES[candidate].size() != 4:
				continue
			for y in range(board.size()):
				for x in range(board[y].length()):
					var origin := Vector2i(x, y)
					if not _shape_fits_level_at(level, si, candidate, origin):
						continue
					spec.shape = candidate
					spec.cell = [x, y]
					if _is_greedily_solvable(level):
						tetrominoes += 1
						promoted = true
						break
					spec.shape = original_shape
					spec.cell = original_cell.duplicate()
				if promoted:
					break
			if promoted:
				break
		if not promoted:
			spec.shape = original_shape
			spec.cell = original_cell


static func _shape_fits_level(level: Dictionary, spec_index: int, shape: String) -> bool:
	var spec: Dictionary = level.catchers[spec_index]
	var org := Vector2i(spec.cell[0], spec.cell[1])
	return _shape_fits_level_at(level, spec_index, shape, org)


static func _shape_fits_level_at(level: Dictionary, spec_index: int, shape: String, org: Vector2i) -> bool:
	var board: Array = level.grid
	var occupied := {}
	for oi in range(level.catchers.size()):
		if oi == spec_index:
			continue
		var other: Dictionary = level.catchers[oi]
		var other_org := Vector2i(other.cell[0], other.cell[1])
		for off in G.SHAPES[other.shape]:
			occupied[other_org + off] = true
	for off in G.SHAPES[shape]:
		var cell: Vector2i = org + off
		if cell.x < 0 or cell.y < 0 or cell.x >= board[0].length() or cell.y >= board.size():
			return false
		if board[cell.y][cell.x] != "." or occupied.has(cell):
			return false
	return true


static func _intermix_level(level: Dictionary, number: int) -> void:
	## 젤리 일부를 홀 주변으로 옮겨 두 레이어가 보드 전체에서 서로 얽히게 한다.
	## 한 번 이동할 때마다 용량 규칙을 포함한 자동 풀이를 통과하는 경우만 확정한다.
	var board: Array = level.grid
	var h: int = board.size()
	var w: int = board[0].length()
	var occupied := {}
	var near_holes: Array[Vector2i] = []
	for spec in level.catchers:
		var org := Vector2i(spec.cell[0], spec.cell[1])
		for off in G.SHAPES[spec.shape]:
			var cell: Vector2i = org + off
			occupied[cell] = true
			for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var target: Vector2i = cell + dir
				if target.x > 0 and target.y > 0 and target.x < w - 1 and target.y < h - 1 and board[target.y][target.x] == "." and not occupied.has(target) and not near_holes.has(target):
					near_holes.append(target)
	# 홀 인접 칸을 우선하되 나머지 빈칸도 섞어 사용한다.
	for y in range(h - 1, -1, -1):
		for x in range(w):
			var cell := Vector2i(x, y)
			if x > 0 and y > 0 and x < w - 1 and y < h - 1 and board[y][x] == "." and not occupied.has(cell) and not near_holes.has(cell):
				near_holes.append(cell)
	var move_goal := mini(16, 2 + number / 4 + (4 if _is_challenge_level(number) else 0))
	if _is_milestone_challenge(number):
		move_goal = mini(22, move_goal + 2 + number / 25)
	var moved := 0
	for target in near_holes:
		if moved >= move_goal:
			break
		if board[target.y][target.x] != "." or occupied.has(target):
			continue
		var source := Vector2i(-1, -1)
		# 위쪽에 몰린 젤리부터 선택하되 목표와 충분히 떨어진 것을 고른다.
		for y in range(h):
			for x in range(w - 1, -1, -1):
				if G.COLORS.has(board[y][x]) and Vector2i(x, y).distance_to(target) >= 3.0:
					source = Vector2i(x, y)
					break
			if source.x >= 0:
				break
		if source.x < 0:
			break
		var color: String = board[source.y][source.x]
		_put(board, source.x, source.y, ".")
		_put(board, target.x, target.y, color)
		if _is_greedily_solvable(level):
			moved += 1
		else:
			_put(board, target.x, target.y, ".")
			_put(board, source.x, source.y, color)


static func _simpler_shape(shape: String) -> String:
	match shape:
		"H4", "H3", "TU", "ZH", "L4D", "SQ":
			return "H2"
		"V4", "V3", "TR", "SV":
			return "V2"
		"L4A":
			return "V2"
		"L4B":
			return "H2"
		"L4C":
			return "V2"
		"H2", "V2":
			return "S1"
	return shape


static func _fill_bands(board: Array, colors: Array, w: int, h: int) -> void:
	for y in range(h - 3):
		var cid: String = colors[y % colors.size()]
		for x in range(w):
			if (x + y) % 2 == 0 and x != (y * 2 + 1) % w:
				_put(board, x, y, cid)


static func _fill_columns(board: Array, colors: Array, w: int, h: int) -> void:
	for x in range(w):
		var cid: String = colors[x % colors.size()]
		for y in range(h - 3):
			if (x + y) % 2 == 0 and y != (x + 1) % maxi(1, h - 3):
				_put(board, x, y, cid)


static func _fill_rings(board: Array, colors: Array, w: int, h: int) -> void:
	var play_h := h - 3
	for y in range(play_h):
		for x in range(w):
			var ring: int = mini(mini(x, w - 1 - x), mini(y, play_h - 1 - y))
			if (x + y) % 2 == 0 and (x + y) % 7 != 0:
				_put(board, x, y, colors[ring % colors.size()])


static func _fill_checker_lanes(board: Array, colors: Array, w: int, h: int) -> void:
	for y in range(h - 3):
		for x in range(w):
			if (x + y * 2) % 2 == 0:
				var idx: int = (x / 2 + y / 2) % colors.size()
				_put(board, x, y, colors[idx])


static func _capacity_catchers(board: Array, colors: Array, w: int, h: int, number: int) -> Array:
	## 실제 빠지냥처럼 색별 젤리 수를 2~4칸 용량의 여러 홀로 나눈다.
	var counts := {}
	for row in board:
		for ch in row:
			if G.COLORS.has(ch):
				counts[ch] = int(counts.get(ch, 0)) + 1
	var specs: Array = []
	var occupied := {}
	var block_index := 0
	var shape_pool := _level_shape_pool(number)
	for color in colors:
		var left: int = counts.get(color, 0)
		while left > 0:
			# L20/30/40은 같은 색도 서로 다른 모양의 캐처로 더 잘게 나눈다.
			# 어느 캐처로 어느 젤리를 먼저 담는지가 남은 동선을 바꾸게 된다.
			var max_capacity := 4 if number >= 51 or (_is_milestone_challenge(number) and number >= 20) else 5
			var amount := mini(max_capacity, left)
			if left == 6:
				amount = 3
			var wanted: String = shape_pool[(block_index + number) % shape_pool.size()]
			var placement := _find_shape_slot(board, wanted, occupied, w, h, number + block_index * 7)
			if placement.x < 0:
				for alternative in shape_pool:
					placement = _find_shape_slot(board, alternative, occupied, w, h, number + block_index * 7)
					if placement.x >= 0:
						wanted = alternative
						break
			if placement.x < 0:
				wanted = "S1"
				placement = _find_shape_slot(board, wanted, occupied, w, h, number + block_index * 7)
			if placement.x < 0:
				# 보드가 가득 차 캐처를 놓을 자리가 없다. 잘못된 좌표를 남기는 대신
				# 담당할 젤리를 그만큼 덜어내 용량 합과 젤리 수를 항상 일치시킨다.
				var removed := _remove_jellies_of_color(board, color, amount, w, h)
				if removed <= 0:
					break
				left -= removed
				block_index += 1
				continue
			specs.append(_c(color, wanted, placement.x, placement.y, amount))
			for off in G.SHAPES[wanted]:
				occupied[placement + off] = true
			block_index += 1
			left -= amount
	return specs


static func _remove_jellies_of_color(board: Array, color: String, count: int, w: int, h: int) -> int:
	## 캐처를 놓을 공간을 만들기 위해 해당 색 젤리를 아래쪽부터 덜어낸다.
	var removed := 0
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			if removed >= count:
				return removed
			if board[y][x] == color:
				_put(board, x, y, ".")
				removed += 1
	return removed


static func _level_shape_pool(number: int) -> Array[String]:
	if number >= 31:
		return ["H4", "V4", "SQ", "L4A", "L4B", "L4C", "L4D", "TU", "TR", "SV", "ZH"]
	if number >= 21:
		return ["H4", "V4", "SQ", "L4A", "L4B", "L4C", "L4D", "TU", "TR"]
	if number >= 11:
		return ["H4", "V4", "SQ", "L4A", "L4B", "L4C", "L4D"]
	return ["H4", "V4", "SQ"]


static func _find_shape_slot(board: Array, shape: String, occupied: Dictionary, w: int, h: int, salt: int) -> Vector2i:
	## 가능한 모든 위치 중 레벨별 목표 지점에 가까운 곳을 골라 위·중간·아래에 분산한다.
	var candidates: Array[Vector2i] = []
	for y in range(h):
		for x in range(w):
			var org := Vector2i(x, y)
			var valid := true
			for off in G.SHAPES[shape]:
				var cell: Vector2i = org + off
				if cell.x < 0 or cell.y < 0 or cell.x >= w or cell.y >= h or board[cell.y][cell.x] != "." or occupied.has(cell):
					valid = false
					break
			if valid:
				candidates.append(org)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	var target := Vector2i((salt * 3 + 1) % w, (salt * 5 + 2) % h)
	var best: Vector2i = candidates[0]
	var best_score := 999999
	for candidate in candidates:
		var score := absi(candidate.x - target.x) + absi(candidate.y - target.y) * 2
		if score < best_score:
			best_score = score
			best = candidate
	return best


static func _add_walls(board: Array, chapter: int, local: int, w: int, h: int) -> void:
	# 갈림길/최종 관문 패턴은 자체 색 장벽이 충분해 외곽을 열어 둔다.
	if chapter == 0 or local == 5 or local == 9:
		return
	# 젤리 영역의 일부 빈칸만 벽으로 바꾼다. 마지막 두 행은 시작/회차 공간으로 보존.
	var count := mini(2 + chapter + local / 3, 7)
	for i in range(count):
		var x := (i * 3 + local + chapter) % w
		var y := (i * 2 + chapter) % (h - 2)
		if board[y][x] == "." and (x == 0 or x == w - 1):
			_put(board, x, y, "#")


static func _carve_irregular_board(board: Array, number: int, chapter: int, w: int, h: int) -> void:
	if number < 5:
		return
	var variant := (number - 5) % 10
	# 레벨마다 다른 외곽 윤곽: 계단, 한쪽 홈, 양쪽 홈, 중심 홈을 순환한다.
	match variant:
		0:
			_void_cell(board, 0, 0, w, h)
			_void_cell(board, w - 1, 0, w, h)
		1:
			_void_cell(board, 0, 0, w, h)
			_void_cell(board, 0, 1, w, h)
			_void_cell(board, 1, 0, w, h)
		2:
			_void_cell(board, w - 1, 0, w, h)
			_void_cell(board, w - 1, 1, w, h)
			_void_cell(board, w - 2, 0, w, h)
		3:
			for x in range(2):
				_void_cell(board, x, 0, w, h)
				_void_cell(board, w - 1 - x, 0, w, h)
			_void_cell(board, 0, 1, w, h)
			_void_cell(board, w - 1, 1, w, h)
		4:
			_void_cell(board, 0, h / 2, w, h)
			_void_cell(board, 0, h / 2 + 1, w, h)
		5:
			_void_cell(board, w - 1, h / 2 - 1, w, h)
			_void_cell(board, w - 1, h / 2, w, h)
		6:
			_void_cell(board, 0, 0, w, h)
			_void_cell(board, w - 1, h - 2, w, h)
		7:
			_void_cell(board, w - 1, 0, w, h)
			_void_cell(board, 0, h - 2, w, h)
		8:
			_void_cell(board, w / 2 - 1, 0, w, h)
			_void_cell(board, w / 2, 0, w, h)
		9:
			_void_cell(board, 0, h / 3, w, h)
			_void_cell(board, w - 1, h * 2 / 3, w, h)
	# 후반에는 두 번째 작은 홈을 더해 윤곽과 이동 통로를 복잡하게 한다.
	if chapter >= 3:
		_void_cell(board, 0 if variant % 2 == 0 else w - 1, maxi(1, h - 3), w, h)


static func _void_cell(board: Array, x: int, y: int, w: int, h: int) -> void:
	if x >= 0 and y >= 0 and x < w and y < h:
		_put(board, x, y, "_")


static func _put(board: Array, x: int, y: int, value: String) -> void:
	var row: String = board[y]
	board[y] = row.substr(0, x) + value + row.substr(x + 1)


static func _c(color: String, shape: String, x: int, y: int, capacity: int = 0) -> Dictionary:
	var spec := {"color": color, "shape": shape, "cell": [x, y]}
	if capacity > 0:
		spec["capacity"] = capacity
	return spec


static func _level(name: String, grid: Array, catchers: Array, time: float, hint: String, stars: Array = [0.5, 0.25]) -> Dictionary:
	return {"name": name, "grid": grid, "catchers": catchers, "time": time, "stars": stars, "hint": hint}


static func validate_all() -> PackedStringArray:
	var errors := PackedStringArray()
	var levels := all_levels()
	if levels.size() != generated_level_count():
		errors.append("레벨 수가 %d이 아닙니다: %d" % [generated_level_count(), levels.size()])
	var boss_counts := {}
	var gimmick_usage := {}
	var win_condition_usage := {}
	for idx in range(levels.size()):
		var level: Dictionary = levels[idx]
		var grid: Array = level.get("grid", [])
		if grid.is_empty():
			errors.append("L%d: 빈 그리드" % (idx + 1))
			continue
		var width: int = grid[0].length()
		var jelly_colors := {}
		var total_jellies := 0
		for y in range(grid.size()):
			if grid[y].length() != width:
				errors.append("L%d: 행 길이 불일치" % (idx + 1))
			for x in range(grid[y].length()):
				var ch: String = grid[y][x]
				if G.COLORS.has(ch):
					jelly_colors[ch] = true
					total_jellies += 1
		var occupied := {}
		var catcher_colors := {}
		var capacity_by_color := {}
		var large_catchers := 0
		for spec in level.get("catchers", []):
			if not G.SHAPES.has(spec.shape):
				errors.append("L%d: 알 수 없는 캐처 모양 %s" % [idx + 1, spec.shape])
				continue
			catcher_colors[spec.color] = true
			if G.SHAPES[spec.shape].size() >= 4:
				large_catchers += 1
			capacity_by_color[spec.color] = int(capacity_by_color.get(spec.color, 0)) + int(spec.get("capacity", 0))
			var org := Vector2i(spec.cell[0], spec.cell[1])
			for off in G.SHAPES[spec.shape]:
				var cell: Vector2i = org + off
				if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= grid.size():
					errors.append("L%d: 캐처가 보드 밖" % (idx + 1))
				elif grid[cell.y][cell.x] != ".":
					errors.append("L%d: 캐처 시작점이 비어 있지 않음" % (idx + 1))
				elif occupied.has(cell):
					errors.append("L%d: 캐처 시작점 겹침" % (idx + 1))
				occupied[cell] = true
		for color in jelly_colors:
			if not catcher_colors.has(color):
				errors.append("L%d: %s 젤리용 캐처 없음" % [idx + 1, color])
			elif int(capacity_by_color.get(color, 0)) > 0:
				var jelly_count := 0
				for row in grid:
					for ch in row:
						if ch == color:
							jelly_count += 1
				# 분열 보스는 구조 순간 같은 색 미니 젤리를 더 만들므로 그만큼의
				# 여유 수용량이 미리 배정되어 있어야 한다.
				var boss_extra := 0
				var boss_data: Dictionary = level.get("boss", {})
				if not boss_data.is_empty() and String(boss_data.get("type", "")) == "splitter" and String(boss_data.get("color", "")) == color:
					boss_extra = int(boss_data.get("splits", 0))
				if int(capacity_by_color[color]) != jelly_count + boss_extra:
					errors.append("L%d: %s 홀 용량 합(%d)과 젤리 수(%d+%d) 불일치" % [idx + 1, color, capacity_by_color[color], jelly_count, boss_extra])
		for seal in level.get("shape_seals", []):
			for pair in seal.cells + seal.gates:
				var cell := Vector2i(int(pair[0]), int(pair[1]))
				if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= grid.size():
					errors.append("L%d: 모양 봉인/장벽이 보드 밖" % (idx + 1))
		var exit_colors := {}
		for exit in level.get("exits", []):
			var exit_cell := Vector2i(int(exit.cell[0]), int(exit.cell[1]))
			var direction := Vector2i(int(exit.direction[0]), int(exit.direction[1]))
			var color := String(exit.color)
			if not G.COLORS.has(color):
				errors.append("L%d: 알 수 없는 배출구 색상 %s" % [idx + 1, color])
			if exit_cell.x < 0 or exit_cell.y < 0 or exit_cell.x >= width or exit_cell.y >= grid.size():
				errors.append("L%d: 젤리 배출구가 보드 밖" % (idx + 1))
			elif grid[exit_cell.y][exit_cell.x] != ".":
				errors.append("L%d: 젤리 배출구 칸이 이동 가능 타일이 아님" % (idx + 1))
			else:
				var outside := exit_cell + direction
				if abs(direction.x) + abs(direction.y) != 1:
					errors.append("L%d: 젤리 배출구 방향이 상하좌우가 아님" % (idx + 1))
				elif outside.x >= 0 and outside.y >= 0 and outside.x < width and outside.y < grid.size() and grid[outside.y][outside.x] != "_":
					errors.append("L%d: 젤리 배출구가 외벽과 맞닿지 않음" % (idx + 1))
			exit_colors[color] = true
		if level.has("exits"):
			for color in catcher_colors:
				if not exit_colors.has(color):
					errors.append("L%d: %s 블록용 젤리 배출구 없음" % [idx + 1, color])
		var frozen_cells := {}
		for frozen in level.get("frozen", []):
			if not (frozen is Array) or frozen.size() < 3:
				errors.append("L%d: 얼음 젤리 데이터 형식 오류" % (idx + 1))
				continue
			var frozen_cell := Vector2i(int(frozen[0]), int(frozen[1]))
			var layers := int(frozen[2])
			if frozen_cell.x < 0 or frozen_cell.y < 0 or frozen_cell.x >= width or frozen_cell.y >= grid.size():
				errors.append("L%d: 얼음 젤리가 보드 밖" % (idx + 1))
			elif not G.COLORS.has(grid[frozen_cell.y][frozen_cell.x]):
				errors.append("L%d: 얼음이 젤리가 아닌 칸에 배치됨" % (idx + 1))
			if layers < 1 or layers > 2:
				errors.append("L%d: 얼음 겹 수 오류 %d" % [idx + 1, layers])
			if frozen_cells.has(frozen_cell):
				errors.append("L%d: 얼음 젤리 칸 중복" % (idx + 1))
			frozen_cells[frozen_cell] = true
		if idx < 50 and level.has("frozen"):
			errors.append("L%d: 신규 얼음 기믹이 50레벨 이전에 등장함" % (idx + 1))
		var number := idx + 1
		var expected_challenge := _is_challenge_level(number)
		var expected_milestone := _is_milestone_challenge(number)
		if bool(level.get("challenge", false)) != expected_challenge:
			errors.append("L%d: 5단위 도전 스테이지 표시 오류" % number)
		if bool(level.get("milestone_challenge", false)) != expected_milestone:
			errors.append("L%d: 10단위 대도전 스테이지 표시 오류" % number)
		if expected_challenge:
			if total_jellies < 13:
				errors.append("L%d: 도전 스테이지 젤리 밀도 부족(%d)" % [number, total_jellies])
			# 100레벨 이후 보드는 기믹 타일이 자리를 차지해 큰 블록을 두 개까지
			# 강제하면 이동 공간이 사라진다. 최소치를 한 개로 완화한다.
			# 또한 풀이 보정으로 젤리가 덜어진 소형 보드는 4칸 블록을 채울 물량이
			# 없으므로 요구하지 않는다.
			var required_large := 2 if number <= 100 else 1
			if total_jellies < 16:
				required_large = 0
			if not expected_milestone and large_catchers < required_large:
				errors.append("L%d: 도전 스테이지 대형 블록 부족(%d/%d)" % [number, large_catchers, required_large])
		if expected_milestone:
			# 최종 관문은 12개 분할 캐처와 네 기믹을 배치하므로 대형 블록은
			# 두 개를 유지하고 대신 최고 젤리 밀도와 최소 공간을 사용한다.
			# 100레벨 이후에는 보드 면적이 상한이라 요구치를 고정하고,
			# 난도 상승은 보스 규칙과 대체 승리 조건이 담당한다.
			var expected_large := 2 if number == 100 else mini(1 + number / 50, 3)
			var expected_jellies := 13 + mini(number, 100) / 25
			if large_catchers < expected_large:
				errors.append("L%d: 대도전 대형 블록 단계 부족(%d/%d)" % [number, large_catchers, expected_large])
			if total_jellies < expected_jellies:
				errors.append("L%d: 대도전 젤리 밀도 단계 부족(%d/%d)" % [number, total_jellies, expected_jellies])
			# 110레벨부터는 보스 규칙을 읽을 시간을 돌려주므로 시간 축 비교 대신
			# 보스 배치 자체로 난도 상승을 보장한다.
			if number > 1 and number < 110:
				var previous_level: Dictionary = levels[number - 2]
				var time_not_harder := float(level.time) >= float(previous_level.time)
				if number == 60:
					time_not_harder = float(level.time) > float(previous_level.time)
				if total_jellies <= _level_jelly_count(previous_level) or time_not_harder:
					errors.append("L%d: 직전 일반 레벨보다 대도전 난도 상승이 부족함" % number)
			if number > 10 and number < 110:
				var previous_milestone: Dictionary = levels[number - 11]
				# 밀도 또는 제한 시간 중 적어도 한 축이 강화되면 다음 티어로 인정한다.
				# 신규 기믹이 더해지는 후반부까지 두 수치를 동시에 강제하면 맵이 과밀해진다.
				if total_jellies <= _level_jelly_count(previous_milestone) and float(level.time) >= float(previous_milestone.time):
					errors.append("L%d: 이전 대도전보다 난도 단계가 상승하지 않음" % number)
			if int(level.get("difficulty_tier", 0)) != number / 10:
				errors.append("L%d: 대도전 난도 티어 오류" % number)
			if number >= 110 and not level.has("boss"):
				errors.append("L%d: 보스 관문에 보스 규칙이 배치되지 않음" % number)
		if expected_milestone and number >= 20:
			var target_moves := _milestone_target_moves(number)
			# 후반 관문은 기믹 타일이 시작 칸을 차지해 압축 여지가 줄어들므로
			# 초기 선택지 상한을 조금 넓게 인정한다.
			var move_allowance := target_moves + (2 if number > 100 else 0)
			if not bool(level.get("constricted_start", false)):
				errors.append("L%d: 대도전 시작 공간 압축 누락" % number)
			if int(level.get("initial_move_options", 999)) > move_allowance:
				errors.append("L%d: 대도전 초기 이동 선택지가 너무 많음(%d/%d)" % [number, int(level.get("initial_move_options", 999)), move_allowance])
		if number >= 51:
			if int(level.get("late_difficulty_tier", 0)) != 1 + (number - 51) / 10:
				errors.append("L%d: 후반 난도 티어 오류" % number)
			if total_jellies < int(level.get("density_target", 999)):
				errors.append("L%d: 후반 젤리 밀도 부족(%d/%d)" % [number, total_jellies, int(level.get("density_target", 999))])
			# 5단위 도전과 그 직후 레벨은 별도 시간 보너스/회복 곡선을 쓰므로 제외한다.
			if number > 51 and (number - 51) % 10 != 0 and not expected_challenge and not _is_challenge_level(number - 1):
				var previous_late: Dictionary = levels[number - 2]
				if float(level.time) >= float(previous_late.time):
					errors.append("L%d: 같은 후반 구간에서 제한 시간이 증가함" % number)
		var expected := _gimmick_flags(number)
		if number <= 100:
			# 1~100레벨의 학습 순서는 기존과 완전히 동일해야 한다.
			if bool(expected.frost) != level.has("frozen"):
				errors.append("L%d: 얼음 기믹 구간 구성 오류" % number)
			if bool(expected.chain) != level.has("chains"):
				errors.append("L%d: 순서 체인 기믹 구간 구성 오류" % number)
			if bool(expected.switch) != (level.has("switches") and level.has("sealed_jellies")):
				errors.append("L%d: 구조 스위치 기믹 구간 구성 오류" % number)
			if bool(expected.key) != level.has("key_locks"):
				errors.append("L%d: 열쇠 잠금 기믹 구간 구성 오류" % number)
		# 기록된 기믹 목록과 실제 데이터가 일치해야 하고, 해금 전에 등장하면 안 된다.
		var recorded: Array = level.get("gimmicks", [])
		for name in GIMMICK_ORDER:
			var present := _level_has_gimmick(level, name)
			if present and number < gimmick_unlock_level(name):
				errors.append("L%d: %s 기믹이 해금 레벨(%d) 이전에 등장함" % [number, name, gimmick_unlock_level(name)])
			if number >= 51 and present != recorded.has(name):
				errors.append("L%d: 기믹 기록 불일치(%s)" % [number, name])
			if present:
				gimmick_usage[name] = int(gimmick_usage.get(name, 0)) + 1
		# ── 신규 기믹 데이터 무결성
		for pair in level.get("ghosts", []):
			var ghost_cell := Vector2i(int(pair[0]), int(pair[1]))
			if ghost_cell.x < 0 or ghost_cell.y < 0 or ghost_cell.y >= grid.size() or ghost_cell.x >= width or not G.COLORS.has(grid[ghost_cell.y][ghost_cell.x]):
				errors.append("L%d: 유령 표식이 젤리 위에 있지 않음" % number)
		for pair in level.get("bombs", []):
			var bomb_cell := Vector2i(int(pair[0]), int(pair[1]))
			if bomb_cell.x < 0 or bomb_cell.y < 0 or bomb_cell.y >= grid.size() or bomb_cell.x >= width or not G.COLORS.has(grid[bomb_cell.y][bomb_cell.x]):
				errors.append("L%d: 폭탄 표식이 젤리 위에 있지 않음" % number)
		for pair in level.get("sticky", []):
			var sticky_cell := Vector2i(int(pair[0]), int(pair[1]))
			if sticky_cell.x < 0 or sticky_cell.y < 0 or sticky_cell.y >= grid.size() or sticky_cell.x >= width or grid[sticky_cell.y][sticky_cell.x] != ".":
				errors.append("L%d: 끈끈이 타일이 빈 타일 위에 있지 않음" % number)
		for raw in level.get("one_ways", []):
			var ow_cell := Vector2i(int(raw.cell[0]), int(raw.cell[1]))
			var ow_dir := Vector2i(int(raw.dir[0]), int(raw.dir[1]))
			if ow_cell.x < 0 or ow_cell.y < 0 or ow_cell.y >= grid.size() or ow_cell.x >= width or grid[ow_cell.y][ow_cell.x] != ".":
				errors.append("L%d: 일방통행 타일이 빈 타일 위에 있지 않음" % number)
			if absi(ow_dir.x) + absi(ow_dir.y) != 1:
				errors.append("L%d: 일방통행 방향 오류" % number)
		for raw in level.get("portals", []):
			for key in ["a", "b"]:
				var portal_pair: Array = raw.get(key, [])
				if portal_pair.size() < 2:
					errors.append("L%d: 포털 쌍 데이터 누락" % number)
					continue
				var portal_cell := Vector2i(int(portal_pair[0]), int(portal_pair[1]))
				if portal_cell.x < 0 or portal_cell.y < 0 or portal_cell.y >= grid.size() or portal_cell.x >= width or grid[portal_cell.y][portal_cell.x] != ".":
					errors.append("L%d: 포털이 빈 타일 위에 있지 않음" % number)
		for raw in level.get("fragile_walls", []):
			if not (raw is Array) or raw.size() < 3:
				errors.append("L%d: 균열벽 데이터 오류" % number)
				continue
			var fragile_cell := Vector2i(int(raw[0]), int(raw[1]))
			if fragile_cell.x < 0 or fragile_cell.y < 0 or fragile_cell.y >= grid.size() or fragile_cell.x >= width or grid[fragile_cell.y][fragile_cell.x] != "#" or int(raw[2]) <= 0:
				errors.append("L%d: 균열벽 데이터 오류" % number)
		for pair in level.get("fog", []):
			var fog_cell := Vector2i(int(pair[0]), int(pair[1]))
			if fog_cell.x < 0 or fog_cell.y < 0 or fog_cell.y >= grid.size() or fog_cell.x >= width or not G.COLORS.has(grid[fog_cell.y][fog_cell.x]):
				errors.append("L%d: 안개 표식이 젤리 위에 있지 않음" % number)
		for raw in level.get("currents", []):
			var current_cell := Vector2i(int(raw.cell[0]), int(raw.cell[1]))
			var current_dir := Vector2i(int(raw.dir[0]), int(raw.dir[1]))
			if current_cell.x < 0 or current_cell.y < 0 or current_cell.y >= grid.size() or current_cell.x >= width or grid[current_cell.y][current_cell.x] != ".":
				errors.append("L%d: 바람길이 빈 타일 위에 있지 않음" % number)
			if absi(current_dir.x) + absi(current_dir.y) != 1:
				errors.append("L%d: 바람길 방향 오류" % number)
		for raw in level.get("time_rifts", []):
			if not (raw is Array) or raw.size() < 3:
				errors.append("L%d: 시간균열 데이터 오류" % number)
				continue
			var rift_cell := Vector2i(int(raw[0]), int(raw[1]))
			if rift_cell.x < 0 or rift_cell.y < 0 or rift_cell.y >= grid.size() or rift_cell.x >= width or grid[rift_cell.y][rift_cell.x] != "." or float(raw[2]) <= 0.0:
				errors.append("L%d: 시간균열 데이터 오류" % number)
		# ── 보스 규칙
		if level.has("boss"):
			var boss: Dictionary = level.boss
			var boss_type := String(boss.get("type", ""))
			if not BOSS_TYPES.has(boss_type):
				errors.append("L%d: 알 수 없는 보스 종류 %s" % [number, boss_type])
			if not expected_milestone:
				errors.append("L%d: 보스가 10단위 관문이 아닌 레벨에 배치됨" % number)
			if boss_type != boss_type_for(number):
				errors.append("L%d: 보스 종류 순환 규칙 불일치" % number)
			var boss_cell := Vector2i(int(boss.cell[0]), int(boss.cell[1]))
			if boss_cell.x < 0 or boss_cell.y < 0 or boss_cell.y >= grid.size() or boss_cell.x >= width or not G.COLORS.has(grid[boss_cell.y][boss_cell.x]):
				errors.append("L%d: 보스가 젤리 위에 있지 않음" % number)
			elif String(boss.get("color", "")) != grid[boss_cell.y][boss_cell.x]:
				errors.append("L%d: 보스 색상이 보드와 불일치" % number)
			if boss_type == "king" and int(boss.get("hp", 0)) < 2:
				errors.append("L%d: 왕젤리 HP 오류" % number)
			if boss_type == "splitter" and int(boss.get("splits", 0)) < 1:
				errors.append("L%d: 분열 보스 분열 수 오류" % number)
			if boss_type == "thief" and float(boss.get("steal_amount", 0.0)) <= 0.0:
				errors.append("L%d: 시간 도둑 수치 오류" % number)
			boss_counts[boss_type] = int(boss_counts.get(boss_type, 0)) + 1
		# ── 대체 승리 조건
		if level.has("move_limit"):
			win_condition_usage["move_limit"] = int(win_condition_usage.get("move_limit", 0)) + 1
			var cost := _solve_move_cost(level)
			if int(level.move_limit) <= 0:
				errors.append("L%d: 이동 제한 값 오류" % number)
			elif cost > 0 and int(level.move_limit) < cost:
				errors.append("L%d: 이동 제한(%d)이 최소 해답 이동 수(%d)보다 작음" % [number, int(level.move_limit), cost])
		if level.has("color_order"):
			win_condition_usage["color_order"] = int(win_condition_usage.get("color_order", 0)) + 1
			var seen_colors := {}
			for color in level.color_order:
				if not G.COLORS.has(String(color)):
					errors.append("L%d: 색 순서 규칙에 알 수 없는 색" % number)
				if seen_colors.has(String(color)):
					errors.append("L%d: 색 순서 규칙에 중복 색" % number)
				seen_colors[String(color)] = true
				if not jelly_colors.has(String(color)):
					errors.append("L%d: 색 순서 규칙에 보드에 없는 색(%s)" % [number, color])
			if level.color_order.size() < 2:
				errors.append("L%d: 색 순서 규칙은 두 색 이상이어야 함" % number)
		if level.has("escort"):
			win_condition_usage["escort"] = int(win_condition_usage.get("escort", 0)) + 1
			var escort_cell := Vector2i(int(level.escort.cell[0]), int(level.escort.cell[1]))
			var escort_catcher := int(level.escort.catcher)
			if escort_catcher < 0 or escort_catcher >= level.catchers.size():
				errors.append("L%d: 호위 전담 블록 인덱스 오류" % number)
			elif escort_cell.x < 0 or escort_cell.y < 0 or escort_cell.y >= grid.size() or escort_cell.x >= width:
				errors.append("L%d: 호위 대상이 보드 밖" % number)
			elif grid[escort_cell.y][escort_cell.x] != String(level.catchers[escort_catcher].color):
				errors.append("L%d: 호위 대상 색과 전담 블록 색이 다름" % number)
		for chain in level.get("chains", []):
			if not G.COLORS.has(String(chain.get("color", ""))) or chain.get("cells", []).size() < 2:
				errors.append("L%d: 순서 체인 데이터 오류" % number)
			for pair in chain.get("cells", []):
				var cell := Vector2i(int(pair[0]), int(pair[1]))
				if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= grid.size() or grid[cell.y][cell.x] != chain.color:
					errors.append("L%d: 순서 체인이 같은 색 젤리 위에 있지 않음" % number)
		for pair in level.get("switches", []):
			var cell := Vector2i(int(pair[0]), int(pair[1]))
			if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= grid.size() or grid[cell.y][cell.x] != ".":
				errors.append("L%d: 구조 스위치가 빈 타일 위에 있지 않음" % number)
		for pair in level.get("sealed_jellies", []):
			var cell := Vector2i(int(pair[0]), int(pair[1]))
			if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= grid.size() or not G.COLORS.has(grid[cell.y][cell.x]):
				errors.append("L%d: 봉인 대상이 젤리가 아님" % number)
		for lock in level.get("key_locks", []):
			var catcher_index := int(lock.get("catcher", -1))
			var pair: Array = lock.get("key", [])
			if catcher_index < 0 or catcher_index >= level.catchers.size() or pair.size() < 2:
				errors.append("L%d: 열쇠 잠금 데이터 오류" % number)
			elif int(pair[0]) < 0 or int(pair[1]) < 0 or int(pair[0]) >= width or int(pair[1]) >= grid.size():
				errors.append("L%d: 열쇠가 보드 밖" % number)
			elif not G.COLORS.has(grid[int(pair[1])][int(pair[0])]):
				errors.append("L%d: 열쇠가 젤리 위에 있지 않음" % number)
		if level.has("shape_seals") and not _shape_seal_is_valid(level):
			errors.append("L%d: 닫힌 수정 장벽 상태에서 봉인 또는 기본 풀이 도달 불가" % (idx + 1))
		if idx == 38:
			var specs: Array = level.catchers
			var positions: Array[Vector2i] = []
			var active: Array[bool] = []
			var blue_index := -1
			for ci in range(specs.size()):
				positions.append(Vector2i(specs[ci].cell[0], specs[ci].cell[1]))
				active.append(true)
				if specs[ci].color == "B" and specs[ci].shape == "S1":
					blue_index = ci
			var blue_move_count := 0
			var blue_can_move_down := false
			if blue_index >= 0:
				for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if _test_can_place(grid, specs, positions, active, blue_index, positions[blue_index] + direction):
						blue_move_count += 1
						if direction == Vector2i.DOWN:
							blue_can_move_down = true
			if blue_move_count < 2 or not blue_can_move_down:
				errors.append("L39: 파란 S1 블록의 시작 탈출 경로가 2방향 미만이거나 아래 통로가 막힘")
		if not _is_greedily_solvable(level):
			errors.append("L%d: 충돌 규칙 기준 도달 불가능한 젤리 존재" % (idx + 1))
	# ── 캠페인 전체 구성 검사: 후반 단조로움을 막는 콘텐츠가 충분히 깔렸는지 본다.
	if levels.size() == TOTAL_LEVELS:
		if CHAPTER_NAMES.size() != TOTAL_LEVELS / LEVELS_PER_CHAPTER or CHAPTER_COLORS.size() != TOTAL_LEVELS / LEVELS_PER_CHAPTER:
			errors.append("1000레벨 챕터 이름/색상 수가 100개와 일치하지 않음")
		var expansion_intros := {
			501: "portal",
			601: "fragile",
			701: "fog",
			801: "current",
			901: "time_rift",
		}
		for intro_number in expansion_intros:
			if not _level_has_gimmick(levels[int(intro_number) - 1], expansion_intros[intro_number]):
				errors.append("L%d: 100레벨 구간 신규 기믹(%s) 소개 누락" % [intro_number, expansion_intros[intro_number]])
		var expected_bosses := TOTAL_LEVELS / LEVELS_PER_CHAPTER - 1
		var total_bosses := 0
		for key in boss_counts:
			total_bosses += int(boss_counts[key])
		if total_bosses < expected_bosses:
			errors.append("보스 관문 수 부족(%d/%d)" % [total_bosses, expected_bosses])
		for boss_type in BOSS_TYPES:
			if int(boss_counts.get(boss_type, 0)) < 10:
				errors.append("보스 종류 %s 등장 횟수 부족(%d)" % [boss_type, int(boss_counts.get(boss_type, 0))])
		for name in GIMMICK_ORDER:
			var minimum := 12 if gimmick_unlock_level(name) >= 101 else 20
			if int(gimmick_usage.get(name, 0)) < minimum:
				errors.append("기믹 %s 등장 레벨 수 부족(%d/%d)" % [name, int(gimmick_usage.get(name, 0)), minimum])
		for condition in ["move_limit", "color_order", "escort"]:
			if int(win_condition_usage.get(condition, 0)) < 10:
				errors.append("대체 승리 조건 %s 등장 수 부족(%d)" % [condition, int(win_condition_usage.get(condition, 0))])
	return errors


static func _rule_context(level: Dictionary) -> Dictionary:
	## 신규 기믹/대체 승리 조건을 솔버가 런타임과 같은 규칙으로 해석하도록 모은다.
	var ctx := {
		"ghosts": {},              # 다른 색 캐처가 통과할 수 있는 젤리
		"one_ways": {},            # 셀 -> 진입 허용 방향
		"escort_cell": Vector2i(-1, -1),
		"escort_catcher": -1,
		"blocked_colors": {},      # 색 순서 규칙으로 아직 흡수할 수 없는 색
		"boss_cell": Vector2i(-1, -1),
		"boss_splits": 0,
		"boss_color": "",
	}
	for pair in level.get("ghosts", []):
		ctx.ghosts[Vector2i(int(pair[0]), int(pair[1]))] = true
	for raw in level.get("one_ways", []):
		ctx.one_ways[Vector2i(int(raw.cell[0]), int(raw.cell[1]))] = Vector2i(int(raw.dir[0]), int(raw.dir[1]))
	if level.has("escort"):
		ctx.escort_cell = Vector2i(int(level.escort.cell[0]), int(level.escort.cell[1]))
		ctx.escort_catcher = int(level.escort.catcher)
	var boss: Dictionary = level.get("boss", {})
	if not boss.is_empty() and String(boss.get("type", "")) == "splitter":
		ctx.boss_cell = Vector2i(int(boss.cell[0]), int(boss.cell[1]))
		ctx.boss_splits = int(boss.get("splits", 0))
		ctx.boss_color = String(boss.get("color", ""))
	return ctx


static func _one_way_allows(ctx: Dictionary, specs: Array, ci: int, from_org: Vector2i, to_org: Vector2i) -> bool:
	## 새로 밟게 되는 일방통행 타일은 이동 방향이 화살표와 같아야 한다.
	var one_ways: Dictionary = ctx.get("one_ways", {})
	if one_ways.is_empty():
		return true
	var direction: Vector2i = to_org - from_org
	if absi(direction.x) + absi(direction.y) != 1:
		return true
	var previous := {}
	for off in G.SHAPES[specs[ci].shape]:
		previous[from_org + off] = true
	for off in G.SHAPES[specs[ci].shape]:
		var cell: Vector2i = to_org + off
		if previous.has(cell):
			continue
		if one_ways.has(cell) and one_ways[cell] != direction:
			return false
	return true


static func _is_greedily_solvable(level: Dictionary) -> bool:
	return _greedy_solve(level).ok


static func _solve_move_cost(level: Dictionary) -> int:
	var result := _greedy_solve(level)
	return int(result.moves) if bool(result.ok) else 0


static func _natural_clear_order(level: Dictionary) -> Array:
	var result := _greedy_solve(level)
	return result.order if bool(result.ok) else []


static func _greedy_solve(level: Dictionary) -> Dictionary:
	## 캐처 우선순위를 바꿔 가며 시도하고, 성공한 첫 순서의 이동 비용과
	## 색 완료 순서를 함께 돌려준다.
	var catcher_count: int = level.catchers.size()
	var best := {"ok": false, "moves": 0, "order": []}
	for shift in range(maxi(1, catcher_count)):
		var attempt := _solve_with_shift(level, shift)
		if bool(attempt.ok):
			return attempt
	return best


static func _is_solvable_with_shift(level: Dictionary, shift: int) -> bool:
	return bool(_solve_with_shift(level, shift).ok)


static func _solve_with_shift(level: Dictionary, shift: int) -> Dictionary:
	## 각 캐처의 현재 도달 영역에서 같은 색을 하나씩 제거하는 보수적 검사.
	## 보너스 모드 없이도 완주 가능한 레벨만 통과시킨다.
	## 유령/일방통행/호위/색 순서/분열 보스 규칙을 런타임과 동일하게 반영한다.
	var failure := {"ok": false, "moves": 0, "order": []}
	var board: Array = level.grid.duplicate()
	var specs: Array = level.catchers
	var catcher_count: int = specs.size()
	var ctx := _rule_context(level)
	var positions: Array[Vector2i] = []
	var capacities: Array[int] = []
	var active: Array[bool] = []
	var remaining := 0
	var total_moves := 0
	var cleared_order: Array = []
	for spec in specs:
		positions.append(Vector2i(spec.cell[0], spec.cell[1]))
		capacities.append(int(spec.get("capacity", 9999)))
		active.append(true)
	var color_counts := {}
	for row in board:
		for ch in row:
			if G.COLORS.has(ch):
				remaining += 1
				color_counts[ch] = int(color_counts.get(ch, 0)) + 1
	# 분열 보스가 나중에 뿌릴 미니 젤리도 남은 수에 미리 반영한다.
	if ctx.boss_splits > 0:
		color_counts[ctx.boss_color] = int(color_counts.get(ctx.boss_color, 0)) + int(ctx.boss_splits)
		remaining += int(ctx.boss_splits)
	var order_rule: Array = level.get("color_order", [])
	var order_index := 0
	_refresh_blocked_colors(ctx, order_rule, order_index, color_counts)
	var safety := remaining + catcher_count * 6 + 24
	while (remaining > 0 or _has_pending_exit(level, active, capacities)) and safety > 0:
		safety -= 1
		var progressed := false
		for order in range(specs.size()):
			var ci: int = (order + shift) % specs.size()
			if not active[ci]:
				continue
			if capacities[ci] <= 0:
				if _catcher_has_exit(level, specs, ci):
					var exit_hit := _find_reachable_exit(board, specs, positions, active, ci, level.exits, ctx)
					if exit_hit.origin.x >= 0:
						positions[ci] = exit_hit.origin
						total_moves += int(exit_hit.dist)
						active[ci] = false
						progressed = true
						break
				else:
					active[ci] = false
					progressed = true
					break
				continue
			if ctx.blocked_colors.has(specs[ci].color):
				continue
			var hit := _find_reachable_jelly(board, specs, positions, active, ci, ctx)
			if hit.origin.x < 0:
				continue
			positions[ci] = hit.origin
			total_moves += int(hit.dist)
			for off in G.SHAPES[specs[ci].shape]:
				var cell: Vector2i = hit.origin + off
				if board[cell.y][cell.x] != specs[ci].color:
					continue
				if cell == ctx.escort_cell and ci != int(ctx.escort_catcher):
					continue
				_put(board, cell.x, cell.y, ".")
				remaining -= 1
				capacities[ci] -= 1
				var color_key: String = specs[ci].color
				color_counts[color_key] = maxi(0, int(color_counts.get(color_key, 0)) - 1)
				# 실제로 어떤 색이 먼저 비워지는지 기록해 두면 색 순서 규칙을
				# 자연스러운 풀이 흐름에 맞춰 만들 수 있다.
				if int(color_counts[color_key]) == 0 and not cleared_order.has(color_key):
					cleared_order.append(color_key)
				# 분열 보스를 구조하면 인접 빈칸에 같은 색 미니 젤리가 흩어진다.
				if ctx.boss_splits > 0 and cell == ctx.boss_cell:
					_scatter_boss_minions(board, cell, String(ctx.boss_color), int(ctx.boss_splits))
					ctx.boss_splits = 0
				if capacities[ci] <= 0:
					if not _catcher_has_exit(level, specs, ci):
						active[ci] = false
					break
			if not order_rule.is_empty():
				var previous_index := order_index
				order_index = _advance_color_order(order_rule, order_index, color_counts, cleared_order)
				if order_index != previous_index:
					_refresh_blocked_colors(ctx, order_rule, order_index, color_counts)
			progressed = true
			break
		if not progressed:
			failure["leftover"] = _remaining_jelly_cells(board)
			return failure
	if remaining != 0 or _has_pending_exit(level, active, capacities):
		failure["leftover"] = _remaining_jelly_cells(board)
		return failure
	if cleared_order.is_empty():
		cleared_order = _fallback_clear_order(level)
	return {"ok": true, "moves": total_moves, "order": cleared_order}


static func _remaining_jelly_cells(board: Array) -> Array:
	var cells: Array = []
	for y in range(board.size()):
		for x in range(board[y].length()):
			if G.COLORS.has(board[y][x]):
				cells.append(Vector2i(x, y))
	return cells


static func _scatter_boss_minions(board: Array, cell: Vector2i, color: String, count: int) -> void:
	var placed := 0
	for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if placed >= count:
			return
		var near: Vector2i = cell + dir
		if near.x < 0 or near.y < 0 or near.y >= board.size() or near.x >= board[near.y].length():
			continue
		if board[near.y][near.x] == ".":
			_put(board, near.x, near.y, color)
			placed += 1


static func _advance_color_order(order_rule: Array, index: int, color_counts: Dictionary, cleared_order: Array) -> int:
	var next_index := index
	while next_index < order_rule.size():
		var color := String(order_rule[next_index])
		if int(color_counts.get(color, 0)) > 0:
			break
		if not cleared_order.has(color):
			cleared_order.append(color)
		next_index += 1
	return next_index


static func _refresh_blocked_colors(ctx: Dictionary, order_rule: Array, index: int, color_counts: Dictionary) -> void:
	ctx.blocked_colors = {}
	if order_rule.is_empty():
		return
	for i in range(index + 1, order_rule.size()):
		var color := String(order_rule[i])
		if int(color_counts.get(color, 0)) > 0:
			ctx.blocked_colors[color] = true


static func _fallback_clear_order(level: Dictionary) -> Array:
	var colors: Array = []
	for spec in level.catchers:
		var color := String(spec.color)
		if not colors.has(color):
			colors.append(color)
	return colors


static func _catcher_has_exit(level: Dictionary, specs: Array, ci: int) -> bool:
	for exit in level.get("exits", []):
		if exit.color == specs[ci].color and (int(exit.get("catcher", -1)) < 0 or int(exit.catcher) == ci):
			return true
	return false


static func _has_pending_exit(level: Dictionary, active: Array[bool], capacities: Array[int]) -> bool:
	if not level.has("exits"):
		return false
	for i in range(active.size()):
		if active[i] and capacities[i] <= 0:
			return true
	return false


static func _find_reachable_exit(board: Array, specs: Array, positions: Array[Vector2i], active: Array[bool], ci: int, exits: Array, ctx: Dictionary = {}) -> Dictionary:
	var start: Vector2i = positions[ci]
	var queue: Array[Vector2i] = [start]
	var seen := {start: 0}
	var head := 0
	while head < queue.size():
		var origin: Vector2i = queue[head]
		head += 1
		for exit in exits:
			if exit.color != specs[ci].color or (int(exit.get("catcher", -1)) >= 0 and int(exit.catcher) != ci):
				continue
			var exit_cell := Vector2i(int(exit.cell[0]), int(exit.cell[1]))
			for off in G.SHAPES[specs[ci].shape]:
				if origin + off == exit_cell:
					return {"origin": origin, "dist": int(seen[origin])}
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = origin + dir
			if seen.has(next):
				continue
			if not _test_can_place_full(board, specs, positions, active, ci, next, ctx):
				continue
			if not _one_way_allows(ctx, specs, ci, origin, next):
				continue
			seen[next] = int(seen[origin]) + 1
			queue.append(next)
	return {"origin": Vector2i(-1, -1), "dist": 0}


static func _test_can_place_full(board: Array, specs: Array, positions: Array[Vector2i], active: Array[bool], ci: int, org: Vector2i, ctx: Dictionary = {}) -> bool:
	## 가득 찬 블록은 어떤 젤리도 통과할 수 없다(유령 젤리 제외).
	var width: int = board[0].length()
	var ghosts: Dictionary = ctx.get("ghosts", {})
	for off in G.SHAPES[specs[ci].shape]:
		var cell: Vector2i = org + off
		if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= board.size():
			return false
		var ch: String = board[cell.y][cell.x]
		if ch == "#" or ch == "_":
			return false
		if G.COLORS.has(ch) and not ghosts.has(cell):
			return false
		for oi in range(specs.size()):
			if oi == ci or not active[oi]:
				continue
			for other_off in G.SHAPES[specs[oi].shape]:
				if positions[oi] + other_off == cell:
					return false
	return true


static func _find_reachable_jelly(board: Array, specs: Array, positions: Array[Vector2i], active: Array[bool], ci: int, ctx: Dictionary = {}) -> Dictionary:
	var start: Vector2i = positions[ci]
	var queue: Array[Vector2i] = [start]
	var seen := {start: 0}
	var head := 0
	var escort_cell: Vector2i = ctx.get("escort_cell", Vector2i(-1, -1))
	var escort_catcher: int = int(ctx.get("escort_catcher", -1))
	while head < queue.size():
		var org: Vector2i = queue[head]
		head += 1
		for off in G.SHAPES[specs[ci].shape]:
			var cell: Vector2i = org + off
			if board[cell.y][cell.x] != specs[ci].color:
				continue
			# 호위 대상은 전담 블록만 구조할 수 있다.
			if cell == escort_cell and ci != escort_catcher:
				continue
			return {"origin": org, "dist": int(seen[org])}
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = org + dir
			if seen.has(next):
				continue
			if not _test_can_place(board, specs, positions, active, ci, next, ctx):
				continue
			if not _one_way_allows(ctx, specs, ci, org, next):
				continue
			seen[next] = int(seen[org]) + 1
			queue.append(next)
	return {"origin": Vector2i(-1, -1), "dist": 0}


static func _test_can_place(board: Array, specs: Array, positions: Array[Vector2i], active: Array[bool], ci: int, org: Vector2i, ctx: Dictionary = {}) -> bool:
	var width: int = board[0].length()
	var ghosts: Dictionary = ctx.get("ghosts", {})
	var blocked_colors: Dictionary = ctx.get("blocked_colors", {})
	var escort_cell: Vector2i = ctx.get("escort_cell", Vector2i(-1, -1))
	var escort_catcher: int = int(ctx.get("escort_catcher", -1))
	for off in G.SHAPES[specs[ci].shape]:
		var cell: Vector2i = org + off
		if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= board.size():
			return false
		var ch: String = board[cell.y][cell.x]
		if ch == "#" or ch == "_":
			return false
		if G.COLORS.has(ch) and not ghosts.has(cell):
			# 다른 색 젤리는 장애물, 같은 색이라도 아직 순서가 아니거나
			# 전담 호위 대상이 아니면 통과할 수 없다.
			if ch != specs[ci].color:
				return false
			if blocked_colors.has(ch):
				return false
			if cell == escort_cell and ci != escort_catcher:
				return false
		for oi in range(specs.size()):
			if oi == ci or not active[oi]:
				continue
			for other_off in G.SHAPES[specs[oi].shape]:
				if positions[oi] + other_off == cell:
					return false
	return true
