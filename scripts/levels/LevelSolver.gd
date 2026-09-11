extends RefCounted
## 정적 레벨 풀이와 도달 가능성 검사. 생성기나 화면 상태에 의존하지 않는다.

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
			attempt["shift"] = shift
			return attempt
	return best


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
	var occupied := _other_catcher_cells(specs, positions, active, ci)
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
			if not _test_can_place_full(board, specs, positions, active, ci, next, ctx, occupied):
				continue
			if not _one_way_allows(ctx, specs, ci, origin, next):
				continue
			seen[next] = int(seen[origin]) + 1
			queue.append(next)
	return {"origin": Vector2i(-1, -1), "dist": 0}


static func _test_can_place_full(board: Array, specs: Array, positions: Array[Vector2i], active: Array[bool], ci: int, org: Vector2i, ctx: Dictionary = {}, occupied: Variant = null) -> bool:
	return _test_can_place(board, specs, positions, active, ci, org, ctx, occupied, true)


static func _find_reachable_jelly(board: Array, specs: Array, positions: Array[Vector2i], active: Array[bool], ci: int, ctx: Dictionary = {}) -> Dictionary:
	var occupied := _other_catcher_cells(specs, positions, active, ci)
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
			if not _test_can_place(board, specs, positions, active, ci, next, ctx, occupied):
				continue
			if not _one_way_allows(ctx, specs, ci, org, next):
				continue
			seen[next] = int(seen[org]) + 1
			queue.append(next)
	return {"origin": Vector2i(-1, -1), "dist": 0}


static func _test_can_place(board: Array, specs: Array, positions: Array[Vector2i], active: Array[bool], ci: int, org: Vector2i, ctx: Dictionary = {}, occupied: Variant = null, full: bool = false) -> bool:
	if occupied == null:
		occupied = _other_catcher_cells(specs, positions, active, ci)
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
			if full or ch != specs[ci].color:
				return false
			if blocked_colors.has(ch):
				return false
			if cell == escort_cell and ci != escort_catcher:
				return false
		if occupied.has(cell):
			return false
	return true


static func _can_reach_origin(board: Array, specs: Array, positions: Array[Vector2i], active: Array[bool], ci: int, target: Vector2i, ctx: Dictionary = {}) -> bool:
	var occupied := _other_catcher_cells(specs, positions, active, ci)
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
			if not _test_can_place(board, specs, positions, active, ci, next, ctx, occupied):
				continue
			if not _one_way_allows(ctx, specs, ci, origin, next):
				continue
			seen[next] = true
			queue.append(next)
	return false


static func _put(board: Array, x: int, y: int, value: String) -> void:
	var row: String = board[y]
	board[y] = row.substr(0, x) + value + row.substr(x + 1)


static func _other_catcher_cells(specs: Array, positions: Array[Vector2i], active: Array[bool], ci: int) -> Dictionary:
	# 각 탐색의 지역 캐시이므로 이동·배출 후 이전 점유 정보가 남지 않는다.
	var occupied := {}
	for oi in range(specs.size()):
		if oi == ci or not active[oi]:
			continue
		for off in G.SHAPES[specs[oi].shape]:
			occupied[positions[oi] + off] = true
	return occupied
