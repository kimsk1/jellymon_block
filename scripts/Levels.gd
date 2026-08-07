class_name Levels
## 50개 레벨 캠페인 데이터.
## 빠지냥식 규칙: 폴리오미노 캐처를 움직여 같은 색 젤리를 흡수하고,
## 다른 색 젤리/벽/캐처는 길을 막는다.

const CHAPTER_NAMES := ["젤리 마을", "캔디 숲", "소다 해변", "아이스 설산", "초코 화산"]
const CHAPTER_COLORS := [
	Color("#ff8fa3"), Color("#77c66e"), Color("#63b9e8"),
	Color("#9caee8"), Color("#d88767"),
]

const BAKED_LEVELS_PATH := "res://assets/data/levels.json"

static var LEVELS: Array = _load_levels()


static func _load_levels() -> Array:
	if FileAccess.file_exists(BAKED_LEVELS_PATH):
		var file := FileAccess.open(BAKED_LEVELS_PATH, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Array and parsed.size() == 50:
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
	for number in range(5, 51):
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

	# L1~4 이후는 색/밀도가 늘어나는 동시에 L9 83초 → L50 63초로 압축한다.
	var time_limit := maxf(63.0, 83.0 - float(number - 9) * 0.5)
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
		_reduce_empty_space(result, number)
		_remove_unused_islands(result)
	return result


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
			if _is_greedily_solvable(level):
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
	if LEVELS.size() != 50:
		errors.append("레벨 수가 50이 아닙니다: %d" % LEVELS.size())
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
	var safety := remaining + 1
	while remaining > 0 and safety > 0:
		safety -= 1
		var progressed := false
		for order in range(specs.size()):
			var ci: int = (order + shift) % specs.size()
			if not active[ci]:
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
						active[ci] = false
						break
			progressed = true
			break
		if not progressed:
			return false
	return remaining == 0


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
