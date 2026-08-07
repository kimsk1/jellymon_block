extends Node2D
class_name Game
## 코어 플레이 v0.3 — 빠지냥 방식 (사용자 확정 룰):
##   · 다양한 모양·색의 구멍 블록(캐처)을 드래그로 움직인다
##   · 같은 색 젤리는 지나가며 흡수(가두기)
##   · 다른 색 젤리는 통과 불가(장애물), 캐처끼리도 통과 불가, 벽 통과 불가
##   · 모든 젤리를 흡수하면 클리어

var main = null
var audio: AudioMgr
var level_idx := 0
var energy_reserved := false
var L: Dictionary
var cols := 0
var rows := 0
var origin := Vector2.ZERO
var walls := {}
var voids := {}
var jellies: Array = []
var jelly_at := {}          # Vector2i -> Jelly
var catchers: Array = []
var catcher_at := {}        # Vector2i -> Catcher
var shape_seals: Array = []
var seal_at := {}           # Vector2i -> 봉인 데이터
var seal_gates := {}        # 닫힌 수정 장벽 셀
var rescue_exits: Array = []
var exit_at := {}            # Vector2i -> 출구 데이터 목록

var grabbed: Catcher = null
var grab_offset := Vector2.ZERO
var drag_px := Vector2.ZERO

var time_left := 0.0
var total_time := 1.0
var goals := {}             # color -> 남은 젤리 수
var score := 0
var state := "play"
var shake_amt := 0.0
var active_absorptions := 0

var jellies_node: Node2D
var catchers_node: Node2D
var fx: FX
var hud: HUD


func _ready() -> void:
	L = Levels.LEVELS[level_idx]
	audio = main.audio
	_add_premium_background()
	cols = L.grid[0].length()
	rows = L.grid.size()
	total_time = L.time
	time_left = total_time
	var top_h := 170.0
	var bottom_h := 240.0
	origin = Vector2((G.W - cols * G.CELL) / 2.0, 0.0)
	origin.y = top_h + max(0.0, (G.H - top_h - bottom_h - rows * G.CELL) / 2.0)
	_setup_shape_seals()
	_setup_rescue_exits()

	jellies_node = Node2D.new()
	add_child(jellies_node)
	catchers_node = Node2D.new()
	add_child(catchers_node)
	fx = FX.new()
	fx.z_index = 30
	add_child(fx)

	for r in range(rows):
		var row: String = L.grid[r]
		for c in range(cols):
			var ch := row[c]
			if ch == "_":
				voids[Vector2i(c, r)] = true
			elif ch == "#":
				walls[Vector2i(c, r)] = true
			elif G.COLORS.has(ch):
				_spawn_jelly(ch, Vector2i(c, r))
	for si in range(L.catchers.size()):
		var cspec: Dictionary = L.catchers[si]
		_spawn_catcher(cspec.color, cspec.shape, Vector2i(cspec.cell[0], cspec.cell[1]), int(cspec.get("capacity", _count_color(cspec.color))), si)

	hud = HUD.new()
	hud.game = self
	add_child(hud)
	hud.setup(goals, L, level_idx)
	hud.set_time(time_left, total_time)
	hud.show_hint(L.get("hint", ""))


func _add_premium_background() -> void:
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/backgrounds/jelly_sky_v2.png")
	bg.centered = true
	bg.position = Vector2(G.W, G.H) * 0.5
	var scale_needed := maxf(G.W / float(bg.texture.get_width()), G.H / float(bg.texture.get_height()))
	bg.scale = Vector2.ONE * scale_needed
	bg.modulate = Color(1, 1, 1, 0.88)
	bg.z_index = -100
	add_child(bg)


func cell_pos(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * G.CELL


func _spawn_jelly(cid: String, cell: Vector2i) -> void:
	var j := Jelly.new()
	j.fx = fx
	j.setup(cid, randf() < 0.02)
	j.cell = cell
	j.position = cell_pos(cell)
	jellies_node.add_child(j)
	jellies.append(j)
	jelly_at[cell] = j
	goals[cid] = int(goals.get(cid, 0)) + 1


func _count_color(cid: String) -> int:
	return int(goals.get(cid, 0))


func _spawn_catcher(cid: String, shape: String, org: Vector2i, capacity: int, spec_index: int) -> void:
	var c := Catcher.new()
	c.setup(cid, shape, capacity)
	c.spec_index = spec_index
	c.origin_cell = org
	c.position = origin + Vector2(org) * G.CELL
	c.slide_target = c.position
	catchers_node.add_child(c)
	catchers.append(c)
	for off in c.cells:
		catcher_at[org + off] = c


func _setup_shape_seals() -> void:
	for raw in L.get("shape_seals", []):
		var seal := {
			"color": String(raw.color),
			"shape": String(raw.shape),
			"cells": [],
			"gates": [],
			"active": false,
		}
		for pair in raw.cells:
			var cell := Vector2i(int(pair[0]), int(pair[1]))
			seal.cells.append(cell)
			seal_at[cell] = seal
		for pair in raw.gates:
			var cell := Vector2i(int(pair[0]), int(pair[1]))
			seal.gates.append(cell)
			seal_gates[cell] = seal
		shape_seals.append(seal)


func _setup_rescue_exits() -> void:
	for raw in L.get("exits", []):
		var exit := {
			"color": String(raw.color),
			"catcher": int(raw.catcher),
			"cell": Vector2i(int(raw.cell[0]), int(raw.cell[1])),
			"direction": Vector2i(int(raw.direction[0]), int(raw.direction[1])),
		}
		rescue_exits.append(exit)
		var list: Array = exit_at.get(exit.cell, [])
		list.append(exit)
		exit_at[exit.cell] = list


# ────────────────────────── 입력 ──────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if state != "play":
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var c = _pick_catcher(event.position)
			if c != null:
				grabbed = c
				c.set_grabbed(true)
				drag_px = event.position
				grab_offset = (origin + Vector2(c.origin_cell) * G.CELL) - event.position
				audio.play("grab", 1.0, -8.0)
				G.haptic(10)
		else:
			_release()
	elif event is InputEventScreenDrag:
		if grabbed:
			drag_px = event.position


func _pick_catcher(p: Vector2):
	# 숫자 배지는 모양의 빈 모서리에 걸칠 수 있으므로 격자 판정보다 먼저 소유 블록을 선택한다.
	for c in catchers:
		if is_instance_valid(c) and c.badge_contains(p):
			return c
	var cell := Vector2i(int(floor((p.x - origin.x) / G.CELL)), int(floor((p.y - origin.y) / G.CELL)))
	if catcher_at.has(cell):
		return catcher_at[cell]
	var best = null
	var best_d := G.CELL * 0.85
	for c in catchers:
		for off in c.cells:
			var d: float = cell_pos(c.origin_cell + off).distance_to(p)
			if d < best_d:
				best_d = d
				best = c
	return best


func _release() -> void:
	if grabbed:
		grabbed.set_grabbed(false)
		grabbed = null


# ────────────────────────── 이동 (격자 슬라이드) ──────────────────────────

func _process_drag() -> void:
	if grabbed == null or grabbed.movement_locked:
		return
	# 시각 블록이 현재 목표 칸에 도착하기 전에는 다음 격자 이동을 예약하지 않는다.
	if grabbed.position.distance_to(grabbed.slide_target) > 1.0:
		return
	var desired_px := drag_px + grab_offset
	var desired := Vector2i(roundi((desired_px.x - origin.x) / G.CELL), roundi((desired_px.y - origin.y) / G.CELL))
	if grabbed.origin_cell != desired:
		var d := desired - grabbed.origin_cell
		var dirs: Array = []
		if absi(d.x) >= absi(d.y):
			if d.x != 0:
				dirs.append(Vector2i(signi(d.x), 0))
			if d.y != 0:
				dirs.append(Vector2i(0, signi(d.y)))
		else:
			if d.y != 0:
				dirs.append(Vector2i(0, signi(d.y)))
			if d.x != 0:
				dirs.append(Vector2i(signi(d.x), 0))
		for dir in dirs:
			if _try_step(grabbed, dir):
				break


func _can_place(c: Catcher, org: Vector2i) -> bool:
	for off in c.cells:
		var cl: Vector2i = org + off
		if cl.x < 0 or cl.y < 0 or cl.x >= cols or cl.y >= rows:
			return false
		if walls.has(cl):
			return false
		if voids.has(cl):
			return false
		if seal_gates.has(cl):
			return false
		var oc = catcher_at.get(cl)
		if oc != null and oc != c:
			return false            # 캐처끼리 통과 불가
		var j = jelly_at.get(cl)
		if j != null:
			if c.completed or j.color_id != c.color_id:
				return false            # FULL 블록과 다른 색 블록은 젤리를 통과할 수 없다.
	return true


func _try_step(c: Catcher, dir: Vector2i) -> bool:
	var org: Vector2i = c.origin_cell + dir
	if not _can_place(c, org):
		return false
	for off in c.cells:
		catcher_at.erase(c.origin_cell + off)
	c.origin_cell = org
	for off in c.cells:
		catcher_at[org + off] = c
	c.slide_target = origin + Vector2(org) * G.CELL
	c.arrival_pending = true
	return true


# ────────────────────────── 메인 루프 ──────────────────────────

func _physics_process(delta: float) -> void:
	if state != "play":
		return
	time_left -= delta
	hud.set_time(time_left, total_time)
	if time_left <= 0.0:
		time_left = 0.0
		_fail()
		return
	_resolve_catcher_arrivals()
	_process_drag()
	if shake_amt > 0.0:
		shake_amt = max(0.0, shake_amt - delta * 24.0)
		position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt
		if shake_amt <= 0.0:
			position = Vector2.ZERO
	queue_redraw()


func _resolve_catcher_arrivals() -> void:
	for c in catchers:
		if is_instance_valid(c) and c.arrival_pending and c.position.distance_to(c.slide_target) <= 1.0:
			c.position = c.slide_target
			c.arrival_pending = false
			if _try_rescue_exit(c):
				continue
			_check_shape_seals(c)
			_absorb_footprint(c)


func _has_rescue_exit(c: Catcher) -> bool:
	for exit in rescue_exits:
		if (exit.catcher < 0 or exit.catcher == c.spec_index) and exit.color == c.color_id:
			return true
	return false


func _try_rescue_exit(c: Catcher) -> bool:
	if not c.completed:
		return false
	var footprint := {}
	for off in c.cells:
		footprint[c.origin_cell + off] = true
	for exit in rescue_exits:
		if (exit.catcher < 0 or exit.catcher == c.spec_index) and exit.color == c.color_id and footprint.has(exit.cell):
			_evacuate_catcher(c, exit)
			return true
	return false


func _evacuate_catcher(c: Catcher, exit: Dictionary) -> void:
	if grabbed == c:
		_release()
	for off in c.cells:
		catcher_at.erase(c.origin_cell + off)
	catchers.erase(c)
	var pos := cell_pos(exit.cell)
	fx.ring(pos, G.COLORS[c.color_id], 1.35)
	fx.impact(pos, G.COLORS[c.color_id], true)
	fx.float_text(pos, "구출 완료!", Color("#eaffbe"), 30)
	audio.play("pop_big", 1.3)
	G.haptic(40)
	shake_amt = maxf(shake_amt, 8.0)
	c.evacuate(exit.direction)
	_maybe_clear_level()


func _check_shape_seals(c: Catcher) -> void:
	var footprint := {}
	for off in c.cells:
		footprint[c.origin_cell + off] = true
	for seal in shape_seals:
		if seal.active or seal.color != c.color_id or seal.shape != c.shape_id:
			continue
		var matched := true
		for cell in seal.cells:
			if not footprint.has(cell):
				matched = false
				break
		if not matched:
			continue
		seal.active = true
		for gate in seal.gates:
			seal_gates.erase(gate)
		var center := Vector2.ZERO
		for cell in seal.cells:
			center += cell_pos(cell)
		center /= float(seal.cells.size())
		fx.impact(center, G.COLORS[c.color_id], true)
		fx.float_text(center, "봉인 해제!", Color("#fff2a6"), 31)
		audio.play("pop_big", 1.25)
		G.haptic(35)
		shake_amt = maxf(shake_amt, 6.0)
		queue_redraw()


# ────────────────────────── 흡수 (가두기) ──────────────────────────

func _absorb_footprint(c: Catcher) -> void:
	## 캐처가 밟은 셀의 같은 색 젤리를 전부 흡수
	var eaten := 0
	for off in c.cells:
		if c.completed or eaten >= c.remaining_capacity:
			break
		var cl: Vector2i = c.origin_cell + off
		var j = jelly_at.get(cl)
		if j != null and not j.absorbing and j.color_id == c.color_id:
			_absorb(j, c, cl)
			eaten += 1
	if eaten >= 3:
		shake_amt = 5.0
	if eaten > 0:
		c.movement_locked = true
		c.gulp()
		_unlock_catcher_after_absorb(c)


func _unlock_catcher_after_absorb(c: Catcher) -> void:
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(c):
		c.movement_locked = false


func _absorb(j: Jelly, c: Catcher, cl: Vector2i) -> void:
	var pts := 100
	if j.shiny:
		pts += 500
	score += pts
	# 목표
	goals[j.color_id] = max(0, int(goals[j.color_id]) - 1)
	hud.set_goals(goals)
	var col: Color = G.COLORS[j.color_id]
	var jp := cell_pos(cl)
	# 블록이 도착한 뒤 젤리가 구멍 위로 떠올라 안쪽으로 빨려 들어간 다음 폭발한다.
	active_absorptions += 1
	jellies.erase(j)
	jelly_at.erase(cl)
	j.absorb_anim(jp + Vector2(0, 5))
	await get_tree().create_timer(0.12).timeout
	# ── 가두기 이펙트 패키지 ──
	fx.burst(jp, col, false)
	fx.swirl(jp, col)
	fx.ring(jp, col, 0.9)
	fx.impact(jp, col, false)
	shake_amt = maxf(shake_amt, 2.8)
	var txt_col := Color(1.0, 0.95, 0.5) if j.shiny else Color.WHITE
	fx.float_text(jp, "+%d" % pts, txt_col, 28)
	if j.shiny:
		fx.sparkle(jp, 10)
		audio.play("shiny")
	audio.play("pop")
	G.haptic(10)
	if c.consume():
		if _has_rescue_exit(c):
			c.set_full()
			fx.float_text(c.center_px(), "출구로!", Color("#dcffb4"), 29)
			call_deferred("_try_rescue_exit", c)
		else:
			call_deferred("_finish_catcher", c)
	active_absorptions = maxi(0, active_absorptions - 1)
	_maybe_clear_level()


func _finish_catcher(c: Catcher) -> void:
	if not is_instance_valid(c) or not catchers.has(c):
		return
	if grabbed == c:
		_release()
	for off in c.cells:
		catcher_at.erase(c.origin_cell + off)
	catchers.erase(c)
	audio.play("pop_big", 1.15)
	G.haptic(25)
	fx.ring(c.center_px(), G.COLORS[c.color_id], 1.5)
	fx.impact(c.center_px(), G.COLORS[c.color_id], true)
	shake_amt = 11.0
	c.vanish()
	_maybe_clear_level()


func _maybe_clear_level() -> void:
	if state == "play" and jellies.is_empty() and active_absorptions == 0 and catchers.is_empty():
		_clear_level()


# ────────────────────────── 종료 ──────────────────────────

func _clear_level() -> void:
	if state != "play":
		return
	state = "clear"
	_release()
	var pct := time_left / total_time
	var stars_n := 1
	if pct >= float(L.stars[0]):
		stars_n = 3
	elif pct >= float(L.stars[1]):
		stars_n = 2
	audio.play("clear")
	G.haptic(60)
	var i := 0
	for c in catchers:
		if is_instance_valid(c):
			c.cheer(0.08 * i)
			i += 1
	fx.confetti()
	var stardust_reward: int = main.on_level_finished(level_idx, stars_n, true, energy_reserved)
	energy_reserved = false
	await get_tree().create_timer(1.3).timeout
	var has_next := level_idx + 1 < Levels.LEVELS.size()
	hud.show_result(stars_n, score, stardust_reward, main.save.get_stardust(), has_next,
		func(): main.start_level(level_idx + 1),
		func(): main.show_map(),
		func(): main.start_level(level_idx))


func _fail() -> void:
	state = "fail"
	_release()
	audio.play("fail")
	G.haptic(25)
	for j in jellies:
		if is_instance_valid(j) and not j.absorbing:
			j.sad()
	for c in catchers:
		if is_instance_valid(c):
			c.sad()
	await get_tree().create_timer(0.9).timeout
	hud.show_fail("시간이 다 됐어요!", main.save.get_stardust(),
		_continue_with_stardust,
		func(): main.start_level(level_idx),
		func(): main.show_map())


func _continue_with_stardust() -> bool:
	const CONTINUE_COST := 20
	if state != "fail" or not main.save.spend_stardust(CONTINUE_COST):
		return false
	for j in jellies:
		if is_instance_valid(j) and not j.absorbing:
			j.revive()
	for c in catchers:
		if is_instance_valid(c):
			c.revive()
	time_left = total_time
	hud.set_time(time_left, total_time)
	state = "play"
	audio.play("grab", 1.18)
	G.haptic(18)
	return true


# ────────────────────────── 보드 렌더 ──────────────────────────

func _draw() -> void:
	# 보드 전체 그림자와 셀별 입체 베벨을 코드로 직접 렌더링한다.
	for r in range(rows):
		for c in range(cols):
			var cell := Vector2i(c, r)
			var p := origin + Vector2(c, r) * G.CELL
			if voids.has(cell):
				continue
			var shadow_style := StyleBoxFlat.new()
			shadow_style.bg_color = Color(0.14, 0.24, 0.42, 0.32)
			shadow_style.set_corner_radius_all(12)
			draw_style_box(shadow_style, Rect2(p + Vector2(2, 8), Vector2(G.CELL - 1, G.CELL - 1)))
			var rim := StyleBoxFlat.new()
			rim.bg_color = Color("#5d91b8")
			rim.set_corner_radius_all(11)
			draw_style_box(rim, Rect2(p, Vector2(G.CELL - 2, G.CELL - 2)))
			if walls.has(cell):
				var wall := StyleBoxFlat.new()
				wall.bg_color = Color("#68558f")
				wall.border_color = Color("#8d78ba")
				wall.set_border_width_all(4)
				wall.set_corner_radius_all(8)
				draw_style_box(wall, Rect2(p + Vector2(5, 5), Vector2(G.CELL - 12, G.CELL - 12)))
				draw_rect(Rect2(p + Vector2(11, 10), Vector2(G.CELL - 24, 8)), Color(1, 1, 1, 0.2))
			else:
				var even := (c + r) % 2 == 0
				var tile := StyleBoxFlat.new()
				tile.bg_color = Color("#fff8e8") if even else Color("#f8ecd2")
				tile.border_color = Color(1, 1, 1, 0.72)
				tile.set_border_width_all(2)
				tile.set_corner_radius_all(8)
				draw_style_box(tile, Rect2(p + Vector2(5, 5), Vector2(G.CELL - 12, G.CELL - 12)))
				draw_rect(Rect2(p + Vector2(12, 11), Vector2(G.CELL - 26, 5)), Color(1, 1, 1, 0.46))
				# 아래쪽의 은은한 음영과 모서리 광점으로 장난감 타일 같은 재질감을 더한다.
				draw_line(p + Vector2(13, G.CELL - 11), p + Vector2(G.CELL - 15, G.CELL - 11), Color(0.61, 0.48, 0.3, 0.12), 3.0, true)
				draw_circle(p + Vector2(G.CELL - 17, 16), 2.5, Color(1, 1, 1, 0.62))
			# FULL 블록을 보드 밖으로 보내는 색상별 구조 통로.
			if exit_at.has(cell):
				var exit: Dictionary = exit_at[cell][0]
				var exit_col: Color = G.COLORS[exit.color]
				var center := p + Vector2.ONE * G.CELL * 0.5
				draw_circle(center, G.CELL * 0.31, Color(exit_col.r, exit_col.g, exit_col.b, 0.2))
				draw_arc(center, G.CELL * 0.3, 0, TAU, 28, exit_col.darkened(0.2), 6.0, true)
				var dir := Vector2(exit.direction).normalized()
				var side := dir.rotated(PI * 0.5)
				var tip := center + dir * 22.0
				var tail := center - dir * 19.0
				draw_line(tail, tip, Color.WHITE, 8.0, true)
				draw_line(tip, tip - dir * 15.0 + side * 13.0, Color.WHITE, 7.0, true)
				draw_line(tip, tip - dir * 15.0 - side * 13.0, Color.WHITE, 7.0, true)
			# 같은 색·모양의 블록을 포개면 장벽을 여는 폴리오미노 룬.
			if seal_at.has(cell):
				var seal: Dictionary = seal_at[cell]
				var rune_col: Color = G.COLORS[seal.color]
				var alpha := 0.22 if seal.active else 0.72
				draw_circle(p + Vector2(G.CELL * 0.5, G.CELL * 0.5), G.CELL * 0.25, Color(rune_col.r, rune_col.g, rune_col.b, alpha * 0.22))
				draw_arc(p + Vector2(G.CELL * 0.5, G.CELL * 0.5), G.CELL * 0.22, 0, TAU, 24, Color(rune_col.r, rune_col.g, rune_col.b, alpha), 4.0, true)
				for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
					var a := p + Vector2(G.CELL * 0.5, G.CELL * 0.5) + Vector2.RIGHT.rotated(angle) * G.CELL * 0.29
					draw_circle(a, 4.0, Color(rune_col.r, rune_col.g, rune_col.b, alpha))
			# 닫힌 장벽은 반투명 수정 기둥으로 표시한다.
			if seal_gates.has(cell):
				var seal: Dictionary = seal_gates[cell]
				var gate_col: Color = G.COLORS[seal.color].lightened(0.2)
				var crystal := PackedVector2Array([
					p + Vector2(G.CELL * 0.5, 7),
					p + Vector2(G.CELL - 9, G.CELL * 0.36),
					p + Vector2(G.CELL - 14, G.CELL - 9),
					p + Vector2(14, G.CELL - 9),
					p + Vector2(9, G.CELL * 0.36),
				])
				draw_colored_polygon(crystal, Color(gate_col.r, gate_col.g, gate_col.b, 0.9))
				draw_polyline(PackedVector2Array(crystal + PackedVector2Array([crystal[0]])), gate_col.darkened(0.32), 5.0, true)
				draw_line(p + Vector2(G.CELL * 0.48, 15), p + Vector2(G.CELL * 0.3, G.CELL - 18), Color(1, 1, 1, 0.62), 5.0, true)


# ────────────────────────── 헤드리스/QA 유틸 ──────────────────────────

func _find_catcher_for(cid: String) -> Catcher:
	for c in catchers:
		if c.color_id == cid and not c.completed and c.remaining_capacity > 0:
			return c
	return null


func debug_capture_one() -> void:
	## 젤리 하나 위로 같은 색 캐처를 순간이동시켜 흡수 파이프라인 실행
	if jellies.is_empty():
		return
	var j = jellies[0]
	var c := _find_catcher_for(j.color_id)
	if c == null:
		return
	for off in c.cells:
		catcher_at.erase(c.origin_cell + off)
	c.origin_cell = j.cell - c.cells[0]
	for off in c.cells:
		catcher_at[c.origin_cell + off] = c
	c.position = origin + Vector2(c.origin_cell) * G.CELL
	c.slide_target = c.position
	_absorb_footprint(c)


func debug_drive() -> void:
	var elapsed := 0.0
	while state == "play" and jellies.size() > 0 and elapsed < 30.0:
		debug_capture_one()
		await get_tree().create_timer(0.2).timeout
		elapsed += 0.2
	# 배출구 레벨은 모든 FULL 블록이 실제 출구 판정을 거쳐 나가야 클리어된다.
	while state == "play" and not catchers.is_empty() and elapsed < 36.0:
		var full: Catcher = null
		for candidate in catchers:
			if candidate.completed and _has_rescue_exit(candidate):
				full = candidate
				break
		if full == null:
			break
		var matching_exit: Dictionary = {}
		for exit in rescue_exits:
			if exit.color == full.color_id and (exit.catcher < 0 or exit.catcher == full.spec_index):
				matching_exit = exit
				break
		if matching_exit.is_empty():
			break
		for off in full.cells:
			catcher_at.erase(full.origin_cell + off)
		full.origin_cell = matching_exit.cell - full.cells[0]
		for off in full.cells:
			catcher_at[full.origin_cell + off] = full
		full.position = origin + Vector2(full.origin_cell) * G.CELL
		full.slide_target = full.position
		_try_rescue_exit(full)
		await get_tree().create_timer(0.2).timeout
		elapsed += 0.2
	print("[smoke] level=", level_idx, " state=", state, " score=", score, " left=", jellies.size(), " catchers=", catchers.size())
