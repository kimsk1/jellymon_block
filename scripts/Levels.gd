class_name Levels
## 100개 레벨 캠페인 데이터.
## 빠지냥식 규칙: 폴리오미노 캐처를 움직여 같은 색 젤리를 흡수하고,
## 다른 색 젤리/벽/캐처는 길을 막는다.

const CHAPTER_NAMES := [
	"젤리 마을", "캔디 숲", "소다 해변", "아이스 설산", "초코 화산",
	"서리 정원", "오로라 동굴", "빙하 연구소", "별빛 극지", "영원의 빙궁",
]
const CHAPTER_COLORS := [
	Color("#ff8fa3"), Color("#77c66e"), Color("#63b9e8"),
	Color("#9caee8"), Color("#d88767"), Color("#55bfc2"),
	Color("#598bd8"), Color("#776bc7"), Color("#ca6ead"), Color("#5279ad"),
]

const BAKED_LEVELS_PATH := "res://assets/data/levels.json"

static var LEVELS: Array = _load_levels()


static func _load_levels() -> Array:
	if FileAccess.file_exists(BAKED_LEVELS_PATH):
		var file := FileAccess.open(BAKED_LEVELS_PATH, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Array and parsed.size() == 100:
			return parsed
	return _build_levels()


static func bake_current_levels() -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/data"))
	var file := FileAccess.open(BAKED_LEVELS_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(LEVELS, "\t"))
	return OK


static func rebuild_and_bake_levels() -> Error:
	LEVELS = _build_levels()
	return bake_current_levels()


static func _build_levels() -> Array:
	var out: Array = []
	# 첫 4레벨만 작은 블록으로 조작과 색 장벽을 학습한다.
	out.append(_level("첫 만남", [".....", ".RR..", "..R..", ".R.R.", "..R..", "....."], [_c("R", "S1", 2, 5)], 60, "끌어서 같은 색 젤리를 모두 구출하세요!"))
	out.append(_level("두 가지 색", ["BBBBB", ".....", "RRRRR", ".....", ".....", "....."], [_c("B", "S1", 1, 5), _c("R", "S1", 3, 5)], 70, "다른 색은 길을 막아요. 알맞은 캐처를 골라 주세요."))
	out.append(_level("넓게 쓸기", ["RRRRRR", "RRRRRR", "......", "Y.Y...", "...Y.Y", "......", "......"], [_c("R", "H2", 3, 6), _c("Y", "V2", 0, 5)], 80, "넓은 캐처는 한 번에 여러 칸을 쓸어요!"))
	out.append(_level("순서가 중요해", ["......", ".BBBB.", ".BBBB.", "RRRRRR", "......", "......", "......"], [_c("R", "S1", 0, 5), _c("B", "S1", 5, 5)], 90, "앞을 막은 색부터 치우면 길이 열려요."))
	for number in range(5, 101):
		out.append(_generated_level(number))
	return out


static func _generated_level(number: int) -> Dictionary:
	var chapter := (number - 1) / 10
	var local := (number - 1) % 10
	var w := mini(8, 6 + (chapter + 1) / 2)
	var h := mini(9, 7 + (chapter + 1) / 2)
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
	var colors: Array = palette.slice(0, color_count)
	# 각 챕터 후반은 새 색을 중심에 배치해 읽기 부담을 점진적으로 높인다.
	if chapter >= 1:
		colors[color_count - 1] = palette[mini(chapter + 2, 5)]
	var board: Array = []
	for y in range(h):
		board.append(".".repeat(w))

	var pattern := local % 4
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

	var specs := _capacity_catchers(board, colors, w, h, number)

	# L1~4 이후는 색/밀도가 늘어나며, 얼음 구간에서는 63초에서 52초까지 다시 압축한다.
	var time_limit := maxf(63.0, 83.0 - float(number - 9) * 0.5)
	if number >= 51:
		time_limit = maxf(52.0, 63.0 - float(number - 50) * 0.22)
	var chapter_name: String = CHAPTER_NAMES[chapter]
	var titles := ["길 열기", "엇갈린 줄", "색의 성", "굽은 통로", "한붓 쓸기", "갈림길", "큰 몸 작은 문", "색깔 미로", "연쇄 구출", "최종 관문"]
	var hint := "색의 층과 캐처 모양을 보고 구출 순서를 정하세요."
	if local == 9:
		hint = "%s의 모든 규칙이 섞인 하이라이트 레벨!" % chapter_name
	var result := _level("%s · %s" % [chapter_name, titles[local]], board, specs, time_limit, hint, [0.45, 0.2] if local == 9 else [0.5, 0.25])
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
	_promote_tetrominoes(result, _level_shape_pool(number), 2 + number / 12)
	if _is_greedily_solvable(result):
		_intermix_level(result, number)
		_add_shape_seal(result, number)
		_reduce_empty_space(result, number)
		_remove_unused_islands(result)
		_fix_known_mobility_traps(result, number)
		_validate_shape_seal(result)
		_add_rescue_exits(result, number)
		_add_late_gimmicks(result, number)
	return result


static func _add_late_gimmicks(level: Dictionary, number: int) -> void:
	if number < 51:
		return
	var flags := _gimmick_flags(number)
	if flags.frost:
		_add_frozen_jellies(level, number)
	if flags.chain:
		_add_rescue_chain(level, number)
	if flags.switch:
		_add_rescue_switch(level, number)
	if flags.key:
		_add_key_lock(level, number)
	if number >= 91:
		var names: Array[String] = []
		if flags.frost: names.append("❄얼음")
		if flags.chain: names.append("⛓순서")
		if flags.switch: names.append("◆스위치")
		if flags.key: names.append("🔑열쇠")
		level.hint = "종합 관문 · %s의 우선순위를 읽고 구출하세요." % " / ".join(names)


static func _gimmick_flags(number: int) -> Dictionary:
	var flags := {
		"frost": number >= 51 and number <= 60,
		"chain": number >= 61 and number <= 70,
		"switch": number >= 71 and number <= 80,
		"key": number >= 81 and number <= 90,
	}
	if number >= 91 and number <= 100:
		var mixes := [
			[true, true, false, false], [false, false, true, true],
			[true, false, true, false], [false, true, false, true],
			[true, false, false, true], [false, true, true, false],
			[true, true, true, false], [true, false, true, true],
			[false, true, true, true], [true, true, true, true],
		]
		var mix: Array = mixes[number - 91]
		flags = {"frost": mix[0], "chain": mix[1], "switch": mix[2], "key": mix[3]}
	return flags


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
	var count := mini(candidates.size(), 2 + (number % 3))
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
		visible += 1
	return visible


static func _fix_known_mobility_traps(level: Dictionary, number: int) -> void:
	## 자동 풀이는 다른 색을 먼저 치우는 순서를 허용하지만, 시작부터 사방이 막힌 블록은
	## 클릭 고장으로 오해하기 쉽다. 플레이 테스트에서 확인된 배치만 최소 이동으로 보정한다.
	if number == 39:
		var board: Array = level.grid
		# L39 파란 S1의 오른쪽 빨간 젤리를 하단 빈칸으로 옮겨 즉시 한 칸 이동 가능하게 한다.
		if board.size() > 8 and board[6].length() > 6 and board[6][5] == "R" and board[8][0] == ".":
			_put(board, 5, 6, ".")
			_put(board, 0, 8, "R")


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
	var valid := _can_reach_origin(board, specs, positions, active, chosen_index, seal_origin) and _is_greedily_solvable(level)
	for pair in seal.gates:
		_put(board, int(pair[0]), int(pair[1]), ".")
	return valid


static func _can_reach_origin(board: Array, specs: Array, positions: Array[Vector2i], active: Array[bool], ci: int, target: Vector2i) -> bool:
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
			if not seen.has(next) and _test_can_place(board, specs, positions, active, ci, next):
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


static func _shape_fits_level(level: Dictionary, spec_index: int, shape: String) -> bool:
	var board: Array = level.grid
	var spec: Dictionary = level.catchers[spec_index]
	var org := Vector2i(spec.cell[0], spec.cell[1])
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
	var move_goal := mini(12, 2 + number / 4)
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
			var amount := mini(5, left)
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
				# 데이터 검증에서 즉시 잡히도록 보드 밖 값을 둔다.
				specs.append(_c(color, wanted, -1, -1, amount))
			else:
				specs.append(_c(color, wanted, placement.x, placement.y, amount))
				for off in G.SHAPES[wanted]:
					occupied[placement + off] = true
			block_index += 1
			left -= amount
	return specs


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
	if LEVELS.size() != 100:
		errors.append("레벨 수가 100이 아닙니다: %d" % LEVELS.size())
	for idx in range(LEVELS.size()):
		var level: Dictionary = LEVELS[idx]
		var grid: Array = level.get("grid", [])
		if grid.is_empty():
			errors.append("L%d: 빈 그리드" % (idx + 1))
			continue
		var width: int = grid[0].length()
		var jelly_colors := {}
		for y in range(grid.size()):
			if grid[y].length() != width:
				errors.append("L%d: 행 길이 불일치" % (idx + 1))
			for x in range(grid[y].length()):
				var ch: String = grid[y][x]
				if G.COLORS.has(ch):
					jelly_colors[ch] = true
		var occupied := {}
		var catcher_colors := {}
		var capacity_by_color := {}
		for spec in level.get("catchers", []):
			if not G.SHAPES.has(spec.shape):
				errors.append("L%d: 알 수 없는 캐처 모양 %s" % [idx + 1, spec.shape])
				continue
			catcher_colors[spec.color] = true
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
				if int(capacity_by_color[color]) != jelly_count:
					errors.append("L%d: %s 홀 용량 합(%d)과 젤리 수(%d) 불일치" % [idx + 1, color, capacity_by_color[color], jelly_count])
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
		var expected := _gimmick_flags(number)
		if bool(expected.frost) != level.has("frozen"):
			errors.append("L%d: 얼음 기믹 구간 구성 오류" % number)
		if bool(expected.chain) != level.has("chains"):
			errors.append("L%d: 순서 체인 기믹 구간 구성 오류" % number)
		if bool(expected.switch) != (level.has("switches") and level.has("sealed_jellies")):
			errors.append("L%d: 구조 스위치 기믹 구간 구성 오류" % number)
		if bool(expected.key) != level.has("key_locks"):
			errors.append("L%d: 열쇠 잠금 기믹 구간 구성 오류" % number)
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
			var blue_can_move := false
			if blue_index >= 0:
				for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if _test_can_place(grid, specs, positions, active, blue_index, positions[blue_index] + direction):
						blue_can_move = true
						break
			if not blue_can_move:
				errors.append("L39: 파란 S1 블록이 시작 위치에서 이동 불가")
		if not _is_greedily_solvable(level):
			errors.append("L%d: 충돌 규칙 기준 도달 불가능한 젤리 존재" % (idx + 1))
	return errors


static func _is_greedily_solvable(level: Dictionary) -> bool:
	var catcher_count: int = level.catchers.size()
	for shift in range(maxi(1, catcher_count)):
		if _is_solvable_with_shift(level, shift):
			return true
	return false


static func _is_solvable_with_shift(level: Dictionary, shift: int) -> bool:
	## 각 캐처의 현재 도달 영역에서 같은 색을 하나씩 제거하는 보수적 검사.
	## 보너스 모드 없이도 완주 가능한 레벨만 통과시킨다.
	var board: Array = level.grid.duplicate()
	var specs: Array = level.catchers
	var catcher_count: int = specs.size()
	var positions: Array[Vector2i] = []
	var capacities: Array[int] = []
	var active: Array[bool] = []
	var remaining := 0
	for spec in specs:
		positions.append(Vector2i(spec.cell[0], spec.cell[1]))
		capacities.append(int(spec.get("capacity", 9999)))
		active.append(true)
	for row in board:
		for ch in row:
			if G.COLORS.has(ch):
				remaining += 1
	var safety := remaining + catcher_count * 4 + 12
	while (remaining > 0 or _has_pending_exit(level, active, capacities)) and safety > 0:
		safety -= 1
		var progressed := false
		for order in range(specs.size()):
			var ci: int = (order + shift) % specs.size()
			if not active[ci]:
				continue
			if capacities[ci] <= 0:
				if _catcher_has_exit(level, specs, ci):
					var exit_origin := _find_reachable_exit(board, specs, positions, active, ci, level.exits)
					if exit_origin.x >= 0:
						positions[ci] = exit_origin
						active[ci] = false
						progressed = true
						break
				else:
					active[ci] = false
					progressed = true
					break
				continue
			var target := _find_reachable_jelly(board, specs, positions, active, ci)
			if target.x < 0:
				continue
			positions[ci] = target
			for off in G.SHAPES[specs[ci].shape]:
				var cell: Vector2i = target + off
				if board[cell.y][cell.x] == specs[ci].color:
					_put(board, cell.x, cell.y, ".")
					remaining -= 1
					capacities[ci] -= 1
					if capacities[ci] <= 0:
						if not _catcher_has_exit(level, specs, ci):
							active[ci] = false
						break
			progressed = true
			break
		if not progressed:
			return false
	return remaining == 0 and not _has_pending_exit(level, active, capacities)


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


static func _find_reachable_exit(board: Array, specs: Array, positions: Array[Vector2i], active: Array[bool], ci: int, exits: Array) -> Vector2i:
	var start: Vector2i = positions[ci]
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
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
					return origin
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = origin + dir
			if not seen.has(next) and _test_can_place_full(board, specs, positions, active, ci, next):
				seen[next] = true
				queue.append(next)
	return Vector2i(-1, -1)


static func _test_can_place_full(board: Array, specs: Array, positions: Array[Vector2i], active: Array[bool], ci: int, org: Vector2i) -> bool:
	var width: int = board[0].length()
	for off in G.SHAPES[specs[ci].shape]:
		var cell: Vector2i = org + off
		if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= board.size():
			return false
		var ch: String = board[cell.y][cell.x]
		if ch == "#" or ch == "_" or G.COLORS.has(ch):
			return false
		for oi in range(specs.size()):
			if oi == ci or not active[oi]:
				continue
			for other_off in G.SHAPES[specs[oi].shape]:
				if positions[oi] + other_off == cell:
					return false
	return true


static func _find_reachable_jelly(board: Array, specs: Array, positions: Array[Vector2i], active: Array[bool], ci: int) -> Vector2i:
	var start: Vector2i = positions[ci]
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var head := 0
	while head < queue.size():
		var org: Vector2i = queue[head]
		head += 1
		for off in G.SHAPES[specs[ci].shape]:
			var cell: Vector2i = org + off
			if board[cell.y][cell.x] == specs[ci].color:
				return org
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = org + dir
			if not seen.has(next) and _test_can_place(board, specs, positions, active, ci, next):
				seen[next] = true
				queue.append(next)
	return Vector2i(-1, -1)


static func _test_can_place(board: Array, specs: Array, positions: Array[Vector2i], active: Array[bool], ci: int, org: Vector2i) -> bool:
	var width: int = board[0].length()
	for off in G.SHAPES[specs[ci].shape]:
		var cell: Vector2i = org + off
		if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= board.size():
			return false
		var ch: String = board[cell.y][cell.x]
		if ch == "#" or ch == "_" or (G.COLORS.has(ch) and ch != specs[ci].color):
			return false
		for oi in range(specs.size()):
			if oi == ci or not active[oi]:
				continue
			for other_off in G.SHAPES[specs[oi].shape]:
				if positions[oi] + other_off == cell:
					return false
	return true
