extends Node2D
class_name Game
## 코어 플레이 v0.3 — 빠지냥 방식 (사용자 확정 룰):
##   · 다양한 모양·색의 구멍 블록(캐처)을 드래그로 움직인다
##   · 같은 색 젤리는 지나가며 흡수(가두기)
##   · 다른 색 젤리는 통과 불가(장애물), 캐처끼리도 통과 불가, 벽 통과 불가
##   · 모든 젤리를 흡수하면 클리어

const L10n = preload("res://scripts/LocalizedText.gd")
const LevelSolverLib = preload("res://scripts/levels/LevelSolver.gd")
const GameBalanceCatalogLib = preload("res://scripts/GameBalanceCatalog.gd")

var main = null
var audio: AudioMgr
var level_idx := 0
var debug_catcher_shift := 0
var _debug_reservation_cache := {}
var _debug_terrain_cache := {}
var _debug_continuation_cache := {}
var _debug_relaxed_continuation := false
var energy_reserved := false
var continued_after_fail := false
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
var frozen_at := {}          # Vector2i -> 남은 얼음 겹 수
var chain_at := {}           # Vector2i -> {chain, index}
var chain_progress: Array[int] = []
var sealed_at := {}          # 스위치 전까지 흡수할 수 없는 젤리
var switch_at := {}          # 구조 스위치 타일
var rescue_switch_active := false
var key_unlock_at := {}      # 열쇠 젤리 셀 -> 잠금 캐처 인덱스 배열
var locked_catcher_indices := {}
var personality_spawn_count := 0
# ── 101레벨 이후 신규 기믹
var ghost_at := {}           # 다른 색 블록이 통과할 수 있는 유령 젤리
var bomb_at := {}            # 구조 시 인접 장벽을 부수는 폭탄 젤리
var sticky_at := {}          # 통과 시 블록이 잠시 느려지는 끈끈이 바닥
var one_way_at := {}         # 셀 -> 진입 허용 방향
# ── 501레벨 이후 확장 기믹
var portal_at := {}          # 셀 -> 짝 포털 셀
var fragile_at := {}         # 벽 셀 -> 무너지기까지 남은 이동
var fog_at := {}             # 가까이 가기 전까지 색이 감춰진 젤리
var current_at := {}         # 셀 -> 바람 방향
var time_rift_at := {}       # 셀 -> 최초 진입 시간 페널티
# ── 보스 관문
var boss_data := {}
var boss_cell := Vector2i(-1, -1)
var boss_steal_timer := 0.0
var boss_defeated := false
# ── 대체 승리 조건
var move_limit := 0
var moves_used := 0
var total_moves := 0
var color_order: Array = []
var color_order_index := 0
var escort_cell := Vector2i(-1, -1)
var escort_catcher := -1

var grabbed: Catcher = null
var grab_offset := Vector2.ZERO
var drag_px := Vector2.ZERO
var active_touch_index := -1
var last_blocked_feedback_msec := 0

var time_left := 0.0
var total_time := 1.0
var elapsed_play_time := 0.0
var goals := {}             # color -> 남은 젤리 수
var score := 0
var state := "play"
var state_before_pause := "play"
var shake_amt := 0.0
var active_absorptions := 0
var tutorial_id := ""
var tutorial_active := false
var tutorial_timer_paused := false
var tutorial_wrong_color_shown := false
var tutorial_replay := false
var adventure_support: Dictionary = {}
var shiny_chance := 0.02
var screen_offset := Vector2.ZERO
var premium_bg: Sprite2D
var board_outer_style: StyleBoxFlat
var board_plate_style: StyleBoxFlat
var tile_shadow_style: StyleBoxFlat
var tile_rim_style: StyleBoxFlat
var wall_tile_style: StyleBoxFlat
var floor_tile_styles: Array[StyleBoxFlat] = []

var jellies_node: Node2D
var catchers_node: Node2D
var fx: FX
var hud: HUD


func _ready() -> void:
	_apply_responsive_layout()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	L = Levels.get_level(level_idx)
	if main.active_activity.is_empty():
		adventure_support = main.save.adventure_support()
		L = L.duplicate(true)
		var support_time := float(adventure_support.get("time_bonus", 0.0))
		if support_time > 0.0:
			L["time"] = float(L.get("time", 60.0)) + support_time
		shiny_chance += float(adventure_support.get("shiny_bonus", 0.0))
	if not main.active_activity.is_empty():
		L = L.duplicate(true)
		var modifier_id := String(main.active_activity.get("modifier", {}).get("id", ""))
		if modifier_id == "fast_timer":
			L["time"] = maxf(20.0, float(L.get("time", 60.0)) * 0.85)
		elif modifier_id == "limited_moves" and not L.has("move_limit"):
			var jelly_count := 0
			for grid_row in L.get("grid", []):
				for color_id in G.COLORS: jelly_count += String(grid_row).count(String(color_id))
			L["move_limit"] = maxi(12, int(jelly_count * 2.6))
	audio = main.audio
	_build_board_styles()
	_add_premium_background()
	cols = L.grid[0].length()
	rows = L.grid.size()
	total_time = L.time
	time_left = total_time
	# 보스/대체 승리 조건이 있으면 목표 요약 줄이 뜨므로 보드를 그만큼 내린다.
	var top_h := 214.0 if _has_objective_bar() else 170.0
	var bottom_h := 240.0
	origin = Vector2((G.W - cols * G.CELL) / 2.0, 0.0)
	origin.y = top_h + max(0.0, (G.H - top_h - bottom_h - rows * G.CELL) / 2.0)
	_setup_shape_seals()
	_setup_rescue_exits()
	_setup_frozen_jellies()
	_setup_rescue_chains()
	_setup_rescue_switches()
	_setup_key_locks()
	_setup_new_gimmicks()
	_setup_objectives()

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
	_reveal_nearby_fog()

	hud = HUD.new()
	hud.game = self
	add_child(hud)
	hud.setup(goals, L, level_idx)
	hud.set_time(time_left, total_time)
	hud.refresh_objectives()
	if not adventure_support.is_empty() and main.analytics:
		main.analytics.track("adventure_support", {"time_bonus":float(adventure_support.get("time_bonus", 0.0)),"shiny_bonus":float(adventure_support.get("shiny_bonus", 0.0)),"stardust_bonus":int(adventure_support.get("stardust_bonus", 0))})
	tutorial_id = String(L.get("tutorial", ""))
	hud.set_tutorial_help_visible(not tutorial_id.is_empty())
	if _tutorial_ui_enabled() and not tutorial_id.is_empty() and not main.save.has_completed_tutorial(tutorial_id):
		call_deferred("_begin_tutorial", false)
	else:
		var support_line := _adventure_support_line()
		hud.show_hint(L10n.text(String(L.get("hint", ""))) + ("\n" + support_line if not support_line.is_empty() else ""))
		if not L.get("signature", {}).is_empty() and main.save.get_stars(level_idx) <= 0:
			tutorial_timer_paused = true
			call_deferred("_show_signature_intro")
		if _tutorial_ui_enabled():
			call_deferred("_start_late_tutorial_if_needed")
		if bool(adventure_support.get("free_hint", false)) and L.get("signature", {}).is_empty():
			call_deferred("_show_bond_hint")


func _show_signature_intro() -> void:
	if not is_instance_valid(hud) or L.get("signature", {}).is_empty():
		tutorial_timer_paused = false
		return
	if main.analytics:
		main.analytics.track("signature_moment", {"level":level_idx + 1,"phase":"start"})
	hud.show_signature_intro(L.signature, func():
		tutorial_timer_paused = false
		if bool(adventure_support.get("free_hint", false)):
			_show_bond_hint()
	)


func _adventure_support_line() -> String:
	if adventure_support.is_empty():
		return ""
	var parts: Array[String] = []
	if float(adventure_support.get("time_bonus", 0.0)) > 0.0:
		parts.append(L10n.text("주민 응원 +%d초") % int(adventure_support.time_bonus))
	if int(adventure_support.get("stardust_bonus", 0)) > 0:
		parts.append(L10n.text("복구 마을 첫 클리어 +%d 별가루") % int(adventure_support.stardust_bonus))
	return "✦ " + " · ".join(parts) if not parts.is_empty() else ""


func _show_bond_hint() -> void:
	await _delay(1.0)
	if state == "play" and is_instance_valid(hud) and _show_movement_hint():
		fx.float_text(Vector2(G.W * 0.5, 190), L10n.text("단짝 주민이 첫 움직임을 알려줬어요!"), Color("#fff2a0"), 22)


func _add_premium_background() -> void:
	premium_bg = Sprite2D.new()
	premium_bg.texture = ArtDirection.background_texture()
	premium_bg.centered = true
	premium_bg.modulate = ArtDirection.chapter_tint(level_idx).lerp(Color.WHITE, 0.7)
	premium_bg.z_index = -100
	add_child(premium_bg)
	# 배경 원화와 게임 오브젝트 사이에 따뜻한 중앙광과 차가운 상단 림을 둔다.
	# 정적인 일러스트 위에서도 보드가 같은 공간 안의 무대처럼 느껴진다.
	var soft: Texture2D = load("res://assets/fx/soft.png")
	for spec in [
		[Vector2(G.W * 0.5, G.H * 0.53), Vector2(22, 28), Color(1.0, 0.72, 0.34, 0.11)],
		[Vector2(G.W * 0.5, 95), Vector2(18, 8), Color(0.32, 0.83, 1.0, 0.1)],
	]:
		var glow := Sprite2D.new()
		glow.texture = soft
		glow.position = spec[0]
		glow.scale = spec[1]
		glow.modulate = spec[2]
		glow.z_index = -90
		add_child(glow)
	_layout_premium_background()


func _apply_responsive_layout() -> void:
	screen_offset = G.safe_offset(get_viewport_rect().size)
	position = screen_offset
	_layout_premium_background()


func _layout_premium_background() -> void:
	if not premium_bg or not premium_bg.texture:
		return
	var viewport_size := get_viewport_rect().size
	# Game 노드가 안전 영역 중앙으로 이동했으므로 배경은 그만큼 반대로 보정한다.
	premium_bg.position = viewport_size * 0.5 - screen_offset
	var scale_needed := maxf(viewport_size.x / float(premium_bg.texture.get_width()), viewport_size.y / float(premium_bg.texture.get_height()))
	premium_bg.scale = Vector2.ONE * scale_needed


func _build_board_styles() -> void:
	## 매 프레임/매 타일마다 Resource를 만들지 않고 레벨 생명주기 동안 공유한다.
	board_outer_style = ArtDirection.panel(Color(0.055, 0.075, 0.17, 0.88), Color("#89e4ff"), 40, 0.52, 5)
	board_outer_style.shadow_size = 24
	board_outer_style.shadow_offset = Vector2(0, 13)
	board_plate_style = StyleBoxFlat.new()
	board_plate_style.bg_color = Color(0.73, 0.9, 0.97, 0.36)
	board_plate_style.border_color = Color(1, 1, 1, 0.58)
	board_plate_style.set_border_width_all(3)
	board_plate_style.set_corner_radius_all(31)
	board_plate_style.corner_detail = 20
	board_plate_style.anti_aliasing = true
	tile_shadow_style = StyleBoxFlat.new()
	tile_shadow_style.bg_color = Color(0.025, 0.06, 0.15, 0.62)
	tile_shadow_style.set_corner_radius_all(15)
	tile_shadow_style.shadow_color = Color(0.02, 0.03, 0.1, 0.38)
	tile_shadow_style.shadow_size = 7
	tile_shadow_style.shadow_offset = Vector2(0, 5)
	tile_rim_style = StyleBoxFlat.new()
	tile_rim_style.bg_color = Color("#397aa7")
	tile_rim_style.border_color = Color("#b9efff")
	tile_rim_style.set_border_width_all(3)
	tile_rim_style.set_corner_radius_all(14)
	wall_tile_style = StyleBoxFlat.new()
	wall_tile_style.bg_color = Color("#5a477f")
	wall_tile_style.border_color = Color("#aa91d5")
	wall_tile_style.set_border_width_all(4)
	wall_tile_style.set_corner_radius_all(8)
	floor_tile_styles.clear()
	var chapter_surface := ArtDirection.chapter_tint(level_idx)
	for blend in [0.78, 0.64]:
		var tile := StyleBoxFlat.new()
		tile.bg_color = chapter_surface.lerp(Color("#fffdf5"), blend)
		tile.border_color = Color(1, 1, 1, 0.9)
		tile.set_border_width_all(3)
		tile.set_corner_radius_all(10)
		tile.corner_detail = 12
		tile.anti_aliasing = true
		floor_tile_styles.append(tile)


func cell_pos(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * G.CELL


func _spawn_jelly(cid: String, cell: Vector2i) -> void:
	var j := Jelly.new()
	j.fx = fx
	j.setup(cid, randf() < shiny_chance, int(frozen_at.get(cell, 0)))
	# 51레벨부터 성격 기믹을 점진적으로 섞는다. 레벨당 수를 제한해
	# 기존 색/경로 퍼즐의 해답을 망가뜨리지 않고 읽을 수 있는 밀도로 유지한다.
	var personality_limit := clampi(1 + (level_idx - 50) / 18, 1, 3) if level_idx >= 50 else 0
	if personality_spawn_count < personality_limit and posmod(cell.x * 3 + cell.y * 5 + level_idx, 7) == 0:
		var traits := ["shy", "sleepy", "playful", "lonely"]
		j.set_personality(traits[posmod(level_idx / 10 + personality_spawn_count, traits.size())])
		personality_spawn_count += 1
	if chain_at.has(cell):
		j.set_chain_badge(int(chain_at[cell].index) + 1)
	if sealed_at.has(cell):
		j.set_rescue_sealed(true)
	if key_unlock_at.has(cell):
		j.set_key_marker(true)
	if ghost_at.has(cell):
		j.set_ghost(true)
	if bomb_at.has(cell):
		j.set_bomb(true)
	if fog_at.has(cell):
		j.modulate = Color(0.58, 0.61, 0.68, 0.82)
	if cell == escort_cell:
		j.set_escort(true)
	if cell == boss_cell and not boss_data.is_empty():
		j.set_boss(String(boss_data.type), int(boss_data.get("hp", 1)))
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
	c.set_key_locked(locked_catcher_indices.has(spec_index))
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


func _setup_frozen_jellies() -> void:
	for raw in L.get("frozen", []):
		if raw is Array and raw.size() >= 3:
			frozen_at[Vector2i(int(raw[0]), int(raw[1]))] = int(raw[2])


func _setup_rescue_chains() -> void:
	for raw in L.get("chains", []):
		var chain_index := chain_progress.size()
		chain_progress.append(0)
		for order in range(raw.cells.size()):
			var pair: Array = raw.cells[order]
			chain_at[Vector2i(int(pair[0]), int(pair[1]))] = {"chain": chain_index, "index": order}


func _setup_rescue_switches() -> void:
	for pair in L.get("switches", []):
		switch_at[Vector2i(int(pair[0]), int(pair[1]))] = true
	for pair in L.get("sealed_jellies", []):
		sealed_at[Vector2i(int(pair[0]), int(pair[1]))] = true


func _has_objective_bar() -> bool:
	return L.has("boss") or L.has("move_limit") or L.has("color_order") or L.has("escort")


func _setup_new_gimmicks() -> void:
	for pair in L.get("ghosts", []):
		ghost_at[Vector2i(int(pair[0]), int(pair[1]))] = true
	for pair in L.get("bombs", []):
		bomb_at[Vector2i(int(pair[0]), int(pair[1]))] = true
	for pair in L.get("sticky", []):
		sticky_at[Vector2i(int(pair[0]), int(pair[1]))] = true
	for raw in L.get("one_ways", []):
		one_way_at[Vector2i(int(raw.cell[0]), int(raw.cell[1]))] = Vector2i(int(raw.dir[0]), int(raw.dir[1]))
	for raw in L.get("portals", []):
		var a := Vector2i(int(raw.a[0]), int(raw.a[1]))
		var b := Vector2i(int(raw.b[0]), int(raw.b[1]))
		portal_at[a] = b
		portal_at[b] = a
	for raw in L.get("fragile_walls", []):
		fragile_at[Vector2i(int(raw[0]), int(raw[1]))] = int(raw[2])
	for pair in L.get("fog", []):
		fog_at[Vector2i(int(pair[0]), int(pair[1]))] = true
	for raw in L.get("currents", []):
		current_at[Vector2i(int(raw.cell[0]), int(raw.cell[1]))] = Vector2i(int(raw.dir[0]), int(raw.dir[1]))
	for raw in L.get("time_rifts", []):
		time_rift_at[Vector2i(int(raw[0]), int(raw[1]))] = float(raw[2])


func _setup_objectives() -> void:
	boss_data = L.get("boss", {})
	if not boss_data.is_empty():
		boss_cell = Vector2i(int(boss_data.cell[0]), int(boss_data.cell[1]))
		boss_steal_timer = float(boss_data.get("steal_interval", 6.0))
	move_limit = int(L.get("move_limit", 0))
	color_order = L.get("color_order", [])
	if L.has("escort"):
		escort_cell = Vector2i(int(L.escort.cell[0]), int(L.escort.cell[1]))
		escort_catcher = int(L.escort.catcher)


func _order_blocks_color(cid: String) -> bool:
	## 색 순서 규칙에서 아직 차례가 오지 않은 색은 흡수도 통과도 할 수 없다.
	if color_order.is_empty():
		return false
	_advance_color_order()
	for i in range(color_order_index + 1, color_order.size()):
		if String(color_order[i]) == cid and int(goals.get(cid, 0)) > 0:
			return true
	return false


func _advance_color_order() -> void:
	while color_order_index < color_order.size() and int(goals.get(String(color_order[color_order_index]), 0)) <= 0:
		color_order_index += 1


func _setup_key_locks() -> void:
	for raw in L.get("key_locks", []):
		var catcher_index := int(raw.catcher)
		var pair: Array = raw.key
		var cell := Vector2i(int(pair[0]), int(pair[1]))
		locked_catcher_indices[catcher_index] = true
		var indices: Array = key_unlock_at.get(cell, [])
		indices.append(catcher_index)
		key_unlock_at[cell] = indices


# ────────────────────────── 상황형 튜토리얼 ──────────────────────────

func _tutorial_ui_enabled() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--shot") or String(arg).begins_with("--validate"):
			return false
	return true


func _begin_tutorial(replay: bool = false) -> void:
	if tutorial_id.is_empty() or not is_instance_valid(hud) or catchers.is_empty():
		return
	tutorial_replay = replay
	tutorial_active = true
	tutorial_timer_paused = true
	tutorial_wrong_color_shown = false
	var catcher: Catcher = catchers[0]
	var target := catcher.center_px()
	var message := L10n.text("블록을 끌어 젤리몬을 안에 담아 주세요!")
	match tutorial_id:
		"shape_seal":
			if not shape_seals.is_empty():
				target = _cells_center(shape_seals[0].cells)
			message = L10n.text("빛나는 모양과 같은 블록을 정확히 포개 보세요!")
		"rescue_exit":
			target = _first_matching_jelly_position(catcher)
			message = L10n.text("먼저 같은 색 젤리몬을 블록 안에 모두 담아 주세요!")
		"color_match":
			target = _first_matching_jelly_position(catcher)
			message = L10n.text("블록과 같은 색·같은 문양의 젤리몬만 담을 수 있어요!")
		_:
			target = _first_matching_jelly_position(catcher)
	var focus := _guide_focus(catcher.center_px(), target)
	hud.show_tutorial_step(message, catcher.center_px(), target, focus)
	_track_tutorial("tutorial_step_start", "first_drag")


func replay_tutorial() -> void:
	if tutorial_id in ["square_capture", "shape_seal", "rescue_exit", "color_match"]:
		_begin_tutorial(true)


func _tutorial_first_grab() -> void:
	if not tutorial_active or not tutorial_timer_paused:
		return
	tutorial_timer_paused = false
	hud.clear_tutorial_step()
	_track_tutorial("tutorial_step_complete", "first_drag")


func _complete_tutorial(step: String) -> void:
	if not tutorial_active:
		return
	tutorial_active = false
	tutorial_timer_paused = false
	hud.clear_tutorial_step()
	if not main.save.has_completed_tutorial(tutorial_id):
		main.save.mark_tutorial_completed(tutorial_id)
	_track_tutorial("tutorial_step_complete", step)


func _show_exit_tutorial(c: Catcher) -> void:
	if not tutorial_active or rescue_exits.is_empty():
		return
	var target := cell_pos(rescue_exits[0].cell)
	hud.show_tutorial_step(L10n.text("GO가 됐어요! 같은 색 화살표 출구로 내보내세요."), c.center_px(), target, _guide_focus(c.center_px(), target))
	_track_tutorial("tutorial_step_start", "move_to_exit")


func _show_tutorial_wrong_color(c: Catcher, directions: Array) -> void:
	if tutorial_id != "color_match" or not tutorial_active or tutorial_wrong_color_shown:
		return
	for direction in directions:
		var wrong = _wrong_color_jelly(c, c.origin_cell + direction)
		if wrong == null:
			continue
		tutorial_wrong_color_shown = true
		var target: Vector2 = wrong.position
		fx.float_text(target, L10n.text("색이 달라요!"), Color("#ffe7a6"), 25)
		hud.show_tutorial_step(L10n.text("이 젤리몬은 색이 달라요. 같은 문양의 블록을 사용하세요!"), c.center_px(), target, _guide_focus(c.center_px(), target))
		_track_tutorial_error("wrong_color")
		_delay(2.0).connect(func():
			if tutorial_active and is_instance_valid(hud):
				hud.clear_tutorial_step()
		)
		return


func _wrong_color_jelly(c: Catcher, candidate_origin: Vector2i):
	for off in c.cells:
		var jelly = jelly_at.get(candidate_origin + off)
		if jelly != null and jelly.color_id != c.color_id:
			return jelly
	return null


func _first_matching_jelly_position(c: Catcher) -> Vector2:
	for jelly in jellies:
		if is_instance_valid(jelly) and jelly.color_id == c.color_id:
			return jelly.position
	return c.center_px()


func _cells_center(cells: Array) -> Vector2:
	if cells.is_empty():
		return Vector2(G.W * 0.5, G.H * 0.5)
	var center := Vector2.ZERO
	for cell in cells:
		center += cell_pos(cell)
	return center / float(cells.size())


func _guide_focus(from: Vector2, to: Vector2) -> Rect2:
	var left := minf(from.x, to.x) - 72.0
	var top := minf(from.y, to.y) - 72.0
	var right := maxf(from.x, to.x) + 72.0
	var bottom := maxf(from.y, to.y) + 72.0
	return Rect2(left, top, right - left, bottom - top)


func _track_tutorial(event_name: String, step: String) -> void:
	if main.analytics:
		main.analytics.track(event_name, {"tutorial_id": tutorial_id, "level": level_idx + 1, "step": step})


func _track_tutorial_error(reason: String) -> void:
	if main.analytics:
		main.analytics.track("tutorial_error", {"tutorial_id": tutorial_id, "level": level_idx + 1, "reason": reason})


func _start_late_tutorial_if_needed() -> void:
	var late_id := ""
	var text := ""
	var target := Vector2.ZERO
	match level_idx:
		50:
			late_id = "frozen_jelly"
			text = L10n.text("얼음 젤리는 같은 색 블록으로 한 번 깨고, 다시 지나가면 구조돼요!")
			if not frozen_at.is_empty():
				target = cell_pos(frozen_at.keys()[0])
		60:
			late_id = "rescue_chain"
			text = L10n.text("번호가 붙은 젤리몬은 1번부터 차례대로 구조하세요!")
			if not chain_at.is_empty():
				target = cell_pos(chain_at.keys()[0])
		70:
			late_id = "rescue_switch"
			text = L10n.text("바닥 스위치를 먼저 밟으면 봉인된 젤리몬이 깨어나요!")
			if not switch_at.is_empty():
				target = cell_pos(switch_at.keys()[0])
		80:
			late_id = "key_lock"
			text = L10n.text("열쇠 젤리몬을 먼저 구조하면 잠긴 블록을 움직일 수 있어요!")
			if not key_unlock_at.is_empty():
				target = cell_pos(key_unlock_at.keys()[0])
	if late_id.is_empty() or target == Vector2.ZERO or main.save.has_completed_tutorial(late_id):
		return
	tutorial_id = late_id
	tutorial_active = true
	hud.show_tutorial_step(text, target + Vector2(-95, 70), target, Rect2(target - Vector2(54, 54), Vector2(108, 108)))
	_track_tutorial("tutorial_step_start", "first_sighting")
	await _delay(4.2)
	if not is_instance_valid(hud) or tutorial_id != late_id:
		return
	main.save.mark_tutorial_completed(late_id)
	_track_tutorial("tutorial_step_complete", "first_sighting")
	tutorial_active = false
	hud.clear_tutorial_step()


# ────────────────────────── 입력 ──────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		set_paused(state != "paused")
		get_viewport().set_input_as_handled()
		return
	# PC 디버그 빌드 전용: C를 누르면 1성 클리어로 저장하고 즉시 다음 레벨을 연다.
	if event is InputEventKey and event.pressed and not event.echo and OS.is_debug_build() and not OS.has_feature("mobile"):
		if event.keycode == KEY_C or event.physical_keycode == KEY_C:
			_debug_clear_one_star_and_next()
			get_viewport().set_input_as_handled()
			return
	if state != "play":
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			# Android에서 앱 전환·시스템 제스처 등으로 release가 누락되면 이전
			# touch index가 영구히 남을 수 있다. 같은 index의 새 press는 새 접촉이므로
			# 오래된 드래그를 정리하고 다시 선택한다. 다른 손가락은 계속 무시한다.
			if active_touch_index >= 0:
				if event.index != active_touch_index:
					return
				_release()
			var c = _pick_catcher(event.position)
			if c != null:
				_tutorial_first_grab()
				var local_position := to_local(event.position)
				grabbed = c
				active_touch_index = event.index
				c.set_grabbed(true)
				_set_color_focus(c.color_id)
				fx.grab_pulse(c.center_px(), G.COLORS[c.color_id])
				drag_px = local_position
				grab_offset = (origin + Vector2(c.origin_cell) * G.CELL) - local_position
				audio.play("grab", 1.0, -8.0)
				G.haptic(10)
				queue_redraw()
		elif event.index == active_touch_index:
			_release()
	elif event is InputEventScreenDrag:
		if grabbed and event.index == active_touch_index:
			drag_px = to_local(event.position)


func _pick_catcher(viewport_position: Vector2):
	# 터치 좌표는 Viewport 기준이고 보드는 긴 화면에서 screen_offset만큼 이동하므로,
	# 셀/거리 판정 전에 Game 노드의 로컬 좌표로 변환한다. 실제 점유 셀을 가장
	# 먼저 선택해야 오목한 T/L 블록의 숫자 배지가 이웃 블록을 가로채지 않는다.
	var p := to_local(viewport_position)
	var cell := Vector2i(int(floor((p.x - origin.x) / G.CELL)), int(floor((p.y - origin.y) / G.CELL)))
	if catcher_at.has(cell):
		var direct: Catcher = catcher_at[cell]
		if direct.key_locked:
			_show_key_locked_feedback(direct)
			return null
		return direct
	# 숫자 배지가 블록의 빈 모서리에 놓인 경우에는 점유 셀이 없으므로 그때만
	# 별도 배지 히트 영역을 사용한다. 숫자 위 드래그 기능은 그대로 유지된다.
	for c in catchers:
		if is_instance_valid(c) and c.badge_contains(viewport_position):
			if c.key_locked:
				_show_key_locked_feedback(c)
				return null
			return c
	var best = null
	var best_d := G.CELL * 0.85
	for c in catchers:
		if c.key_locked:
			continue
		for off in c.cells:
			var d: float = cell_pos(c.origin_cell + off).distance_to(p)
			if d < best_d:
				best_d = d
				best = c
	return best


func _show_key_locked_feedback(c: Catcher) -> void:
	fx.float_text(c.center_px(), L10n.text("열쇠가 필요해요!"), Color("#f1d7ff"), 24)
	audio.play("grab", 0.75, -9.0)


func _release() -> void:
	if grabbed:
		grabbed.set_grabbed(false)
		grabbed = null
	_set_color_focus("")
	active_touch_index = -1
	queue_redraw()


func _set_color_focus(color_id: String) -> void:
	# 오브젝트가 많은 후반에는 잡은 블록과 같은 색 목표를 선명하게 남기고,
	# 다른 색 장애물은 실루엣만 보이도록 낮춰 경로를 빠르게 읽게 한다.
	if level_idx < 100:
		return
	for jelly in jellies:
		if not is_instance_valid(jelly):
			continue
		jelly.self_modulate = Color.WHITE if color_id.is_empty() else (Color(1.08, 1.08, 1.08, 1.0) if jelly.color_id == color_id else Color(0.68, 0.72, 0.82, 0.42))
	for catcher in catchers:
		if not is_instance_valid(catcher):
			continue
		catcher.self_modulate = Color.WHITE if color_id.is_empty() else (Color.WHITE if catcher == grabbed else Color(0.74, 0.78, 0.88, 0.58))


# ────────────────────────── 이동 (격자 슬라이드) ──────────────────────────

func _process_drag() -> void:
	if grabbed == null or grabbed.movement_locked:
		return
	var desired_px := drag_px + grab_offset
	var grid_anchor := origin + Vector2(grabbed.origin_cell) * G.CELL
	var pull := desired_px - grid_anchor
	# 막힌 방향은 짧은 고무 저항만 허용해 벽을 관통해 보이지 않게 한다.
	if pull.x < 0.0 and not _can_place(grabbed, grabbed.origin_cell + Vector2i.LEFT, Vector2i.LEFT):
		pull.x = maxf(pull.x, -9.0)
	elif pull.x > 0.0 and not _can_place(grabbed, grabbed.origin_cell + Vector2i.RIGHT, Vector2i.RIGHT):
		pull.x = minf(pull.x, 9.0)
	if pull.y < 0.0 and not _can_place(grabbed, grabbed.origin_cell + Vector2i.UP, Vector2i.UP):
		pull.y = maxf(pull.y, -9.0)
	elif pull.y > 0.0 and not _can_place(grabbed, grabbed.origin_cell + Vector2i.DOWN, Vector2i.DOWN):
		pull.y = minf(pull.y, 9.0)
	grabbed.set_drag_pull(pull)
	# 시각 블록이 현재 목표 칸에 도착하기 전에는 다음 격자 이동을 예약하지 않는다.
	if grabbed.arrival_pending and grabbed.position.distance_to(grabbed.slide_target) > 3.5:
		return
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
		var moved := false
		for dir in dirs:
			if _try_step(grabbed, dir):
				moved = true
				break
		if not moved and Time.get_ticks_msec() - last_blocked_feedback_msec > 180:
			last_blocked_feedback_msec = Time.get_ticks_msec()
			fx.blocked_bump(grabbed.center_px(), G.COLORS[grabbed.color_id])
			G.haptic(5)
			_show_tutorial_wrong_color(grabbed, dirs)


func _can_place(c: Catcher, org: Vector2i, direction: Vector2i = Vector2i.ZERO, occupancy: Dictionary = {}) -> bool:
	if occupancy.is_empty():
		occupancy = catcher_at
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
		var oc = occupancy.get(cl)
		if oc != null and oc != c:
			return false            # 캐처끼리 통과 불가
		var j = jelly_at.get(cl)
		if j != null and not j.is_ghost:
			# FULL 블록과 다른 색 블록은 젤리를 통과할 수 없다.
			# 유령 젤리만 예외적으로 모두 통과할 수 있다.
			if c.completed or j.color_id != c.color_id:
				return false
			# 아직 순서가 오지 않은 색과 전담 호위 대상도 길을 막는다.
			if _order_blocks_color(j.color_id):
				return false
			if cl == escort_cell and c.spec_index != escort_catcher:
				return false
	if direction != Vector2i.ZERO and not _one_way_allows(c, org, direction):
		return false
	return true


func _one_way_allows(c: Catcher, org: Vector2i, direction: Vector2i) -> bool:
	## 새로 밟는 일방통행 타일은 화살표와 같은 방향으로만 진입할 수 있다.
	if one_way_at.is_empty():
		return true
	var previous := {}
	for off in c.cells:
		previous[org - direction + off] = true
	for off in c.cells:
		var cl: Vector2i = org + off
		if previous.has(cl):
			continue
		if one_way_at.has(cl) and one_way_at[cl] != direction:
			return false
	return true


func _try_step(c: Catcher, dir: Vector2i) -> bool:
	if c.key_locked:
		return false
	var org: Vector2i = c.origin_cell + dir
	if not _can_place(c, org, dir):
		return false
	if _trigger_moving_personality(c, org):
		return false
	var from_center := c.center_px()
	var entered_sticky := false
	var previous := {}
	for off in c.cells:
		previous[c.origin_cell + off] = true
	for off in c.cells:
		var cl: Vector2i = org + off
		if sticky_at.has(cl) and not previous.has(cl):
			entered_sticky = true
	for off in c.cells:
		catcher_at.erase(c.origin_cell + off)
	c.origin_cell = org
	for off in c.cells:
		catcher_at[org + off] = c
	_apply_advanced_floor(c, previous, dir)
	org = c.origin_cell
	c.slide_target = origin + Vector2(org) * G.CELL
	c.arrival_pending = true
	fx.move_streak(from_center, from_center + Vector2(dir) * G.CELL, G.COLORS[c.color_id])
	if entered_sticky:
		# 끈끈이 바닥은 통과를 막지 않고 이동 비용만 올린다.
		c.slow_until_msec = Time.get_ticks_msec() + 420
		fx.float_text(c.center_px(), L10n.text("끈적…"), Color("#ffe6a8"), 21)
		G.haptic(8)
	_register_move(1 + (1 if entered_sticky else 0))
	queue_redraw()
	return true


func _register_move(cost: int) -> void:
	if state != "play":
		return
	total_moves += cost
	_advance_fragile_walls(cost)
	_reveal_nearby_fog()
	## 제한 이동 규칙이 있는 레벨에서만 HUD 이동 수를 센다.
	if move_limit <= 0:
		return
	moves_used += cost
	hud.set_move_counter(moves_used, move_limit)
	if moves_used >= move_limit:
		call_deferred("_check_move_limit_failure")


func _apply_advanced_floor(c: Catcher, previous: Dictionary, direction: Vector2i) -> void:
	## 한 번의 이동에서 포털·바람·시간균열을 각각 한 번만 처리한다.
	var entered: Array[Vector2i] = []
	for off in c.cells:
		var cell: Vector2i = c.origin_cell + off
		if not previous.has(cell):
			entered.append(cell)
	var portal_source := Vector2i(-1, -1)
	var portal_offset := Vector2i.ZERO
	for cell in entered:
		if portal_at.has(cell):
			portal_source = cell
			portal_offset = cell - c.origin_cell
			break
	if portal_source.x >= 0:
		var destination: Vector2i = portal_at[portal_source]
		var target_origin := destination - portal_offset
		if _can_place(c, target_origin):
			for off in c.cells:
				catcher_at.erase(c.origin_cell + off)
			c.origin_cell = target_origin
			for off in c.cells:
				catcher_at[c.origin_cell + off] = c
			fx.ring(cell_pos(portal_source), Color("#a989ff"), 1.2)
			fx.ring(cell_pos(destination), Color("#6ee5ff"), 1.2)
			fx.float_text(cell_pos(destination), L10n.text("워프!"), Color("#e9ddff"), 24)
			audio.play("shiny", 1.18, -7.0)
			G.haptic(18)
	for cell in entered:
		if current_at.has(cell):
			var wind: Vector2i = current_at[cell]
			var delta_time := 1.5 if wind == direction else (-2.0 if wind == -direction else -0.5)
			time_left = clampf(time_left + delta_time, 0.1, total_time)
			fx.float_text(cell_pos(cell), L10n.text("+1.5초") if delta_time > 0.0 else L10n.text("%0.1f초") % delta_time, Color("#bcecff") if delta_time > 0.0 else Color("#ffc1cf"), 21)
			break
	for cell in entered:
		if time_rift_at.has(cell):
			var penalty := float(time_rift_at[cell])
			time_rift_at.erase(cell)
			time_left = maxf(0.1, time_left - penalty)
			fx.ring(cell_pos(cell), Color("#8555c7"), 1.5)
			fx.float_text(cell_pos(cell), L10n.text("-%0.0f초") % penalty, Color("#efc5ff"), 25)
			G.haptic(24)
			queue_redraw()
			break


func _advance_fragile_walls(cost: int) -> void:
	if fragile_at.is_empty():
		return
	var broken: Array[Vector2i] = []
	for cell in fragile_at.keys():
		fragile_at[cell] = int(fragile_at[cell]) - cost
		if int(fragile_at[cell]) <= 0:
			broken.append(cell)
	for cell in broken:
		fragile_at.erase(cell)
		walls.erase(cell)
		fx.impact(cell_pos(cell), Color("#d9c5ff"), true)
		fx.float_text(cell_pos(cell), L10n.text("균열 붕괴!"), Color("#f2eaff"), 22)
	if not broken.is_empty():
		audio.play("pop_big", 0.9)
		G.haptic(28)
		queue_redraw()


func _reveal_nearby_fog() -> void:
	if fog_at.is_empty():
		return
	var revealed: Array[Vector2i] = []
	for fog_cell in fog_at.keys():
		for c in catchers:
			if not is_instance_valid(c):
				continue
			for off in c.cells:
				var distance: Vector2i = (c.origin_cell + off - Vector2i(fog_cell)).abs()
				if distance.x + distance.y <= 2:
					revealed.append(fog_cell)
					break
			if revealed.has(fog_cell):
				break
	for cell in revealed:
		fog_at.erase(cell)
		var jelly = jelly_at.get(cell)
		if jelly != null:
			jelly.create_tween().tween_property(jelly, "modulate", Color.WHITE, 0.22)
			jelly.show_personality_feedback(L10n.text("안개 해제!"))


func _check_move_limit_failure() -> void:
	if state != "play" or move_limit <= 0 or moves_used < move_limit:
		return
	# 마지막 이동의 도착/흡수 판정까지 기다린다. 이동 등록은 슬라이드보다 먼저다.
	while state == "play" and catchers.any(func(c): return c.arrival_pending):
		await get_tree().process_frame
	if state != "play":
		return
	# 마지막 이동으로 클리어됐다면 실패시키지 않는다.
	if jellies.is_empty() and catchers.is_empty():
		return
	# 마지막 포획 연출이 끝나는 중이면 결과가 확정될 때까지 기다린다.
	if active_absorptions > 0:
		await _delay(0.65)
		if state != "play":
			return
		if jellies.is_empty() and catchers.is_empty():
			return
	_fail(L10n.text("이동 횟수를 모두 썼어요!"))


func _target_footprint(c: Catcher, org: Vector2i) -> Dictionary:
	var footprint := {}
	for off in c.cells:
		footprint[org + off] = true
	return footprint


func _personality_destination(cell: Vector2i, forbidden: Dictionary) -> Vector2i:
	for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var target: Vector2i = cell + dir
		if target.x < 0 or target.y < 0 or target.x >= cols or target.y >= rows:
			continue
		if forbidden.has(target) or walls.has(target) or voids.has(target) or seal_gates.has(target) or jelly_at.has(target) or catcher_at.has(target):
			continue
		return target
	return cell


func _move_personality_jelly(j: Jelly, from: Vector2i, to: Vector2i, text: String) -> void:
	_move_jelly_rules(from, to)
	jelly_at.erase(from)
	jelly_at[to] = j
	j.cell = to
	j.personality_state = 1
	j.show_personality_feedback(text)
	j.create_tween().tween_property(j, "position", cell_pos(to), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _move_jelly_rules(from: Vector2i, to: Vector2i) -> void:
	# 성격으로 자리를 바꿔도 번호/열쇠/호위 등은 바닥이 아닌 젤리를 따라간다.
	for rules in [frozen_at, chain_at, sealed_at, key_unlock_at, ghost_at, bomb_at]:
		var had_from: bool = rules.has(from)
		var had_to: bool = rules.has(to)
		var from_value = rules.get(from)
		var to_value = rules.get(to)
		rules.erase(from)
		rules.erase(to)
		if had_from:
			rules[to] = from_value
		if had_to:
			rules[from] = to_value
	if escort_cell == from:
		escort_cell = to
	elif escort_cell == to:
		escort_cell = from
	if boss_cell == from:
		boss_cell = to
	elif boss_cell == to:
		boss_cell = from


func _trigger_moving_personality(c: Catcher, org: Vector2i) -> bool:
	var footprint := _target_footprint(c, org)
	for cell in footprint:
		var j = jelly_at.get(cell)
		if j == null or j.color_id != c.color_id or j.personality_state > 0:
			continue
		if j.personality_id == "shy":
			var target := _personality_destination(cell, footprint)
			if target != cell:
				_move_personality_jelly(j, cell, target, L10n.text("앗, 부끄러워!"))
				return true
		elif j.personality_id == "playful":
			for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var other_cell: Vector2i = cell + dir
				var other = jelly_at.get(other_cell)
				if other != null and not footprint.has(other_cell) and not other.absorbing:
					_move_jelly_rules(cell, other_cell)
					jelly_at[cell] = other
					jelly_at[other_cell] = j
					j.cell = other_cell
					other.cell = cell
					j.personality_state = 1
					j.show_personality_feedback(L10n.text("자리 바꾸기!"))
					j.create_tween().tween_property(j, "position", cell_pos(other_cell), 0.22).set_trans(Tween.TRANS_BACK)
					other.create_tween().tween_property(other, "position", cell_pos(cell), 0.22).set_trans(Tween.TRANS_BACK)
					return true
	return false


# ────────────────────────── 메인 루프 ──────────────────────────

func _physics_process(delta: float) -> void:
	if state != "play":
		return
	# 첫 격자 이동 전에는 탐색 시간을 주고, 이동 후에는 손을 떼도 계속 센다.
	if total_moves > 0 and not tutorial_timer_paused:
		elapsed_play_time += delta
		time_left -= delta
		hud.set_time(time_left, total_time)
		_process_boss_timer(delta)
		if time_left <= 0.0:
			time_left = 0.0
			_fail()
			return
	_resolve_catcher_arrivals()
	_process_drag()
	if shake_amt > 0.0:
		shake_amt = max(0.0, shake_amt - delta * 24.0)
		position = screen_offset + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt
		if shake_amt <= 0.0:
			position = screen_offset


func set_paused(value: bool) -> void:
	if value:
		if state != "play":
			return
		state_before_pause = state
		state = "paused"
		_release()
		if is_instance_valid(hud):
			hud.show_pause()
		if main and main.music:
			main.music.set_game_paused(true)
	else:
		if state != "paused":
			return
		state = state_before_pause
		if is_instance_valid(hud):
			hud.hide_pause()
		if main and main.music:
			main.music.set_game_paused(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if state == "play":
			set_paused(true)


func _resolve_catcher_arrivals() -> void:
	for c in catchers:
		if is_instance_valid(c) and c.arrival_pending and c.position.distance_to(c.slide_target) <= 3.5:
			c.position = c.slide_target
			c.arrival_pending = false
			_check_rescue_switch(c)
			if _try_rescue_exit(c):
				continue
			_check_shape_seals(c)
			_absorb_footprint(c)


func _check_rescue_switch(c: Catcher) -> void:
	if rescue_switch_active or switch_at.is_empty():
		return
	for off in c.cells:
		var cell: Vector2i = c.origin_cell + off
		if not switch_at.has(cell):
			continue
		rescue_switch_active = true
		for sealed_cell in sealed_at:
			var jelly = jelly_at.get(sealed_cell)
			if jelly != null:
				jelly.set_rescue_sealed(false)
		fx.impact(cell_pos(cell), Color("#bd8cf4"), true)
		fx.float_text(cell_pos(cell), L10n.text("봉인 해제!"), Color("#f5e4ff"), 29)
		audio.play("pop_big", 1.2)
		G.haptic(32)
		queue_redraw()
		return


func _has_rescue_exit(c: Catcher) -> bool:
	for exit in rescue_exits:
		if (exit.catcher < 0 or exit.catcher == c.spec_index) and exit.color == c.color_id:
			return true
	return false


func _try_rescue_exit(c: Catcher) -> bool:
	# 내부 포획 연출이 끝나기 전에 블록이 배출되면 자식 젤리도 함께 사라진다.
	if not c.completed or c.trapped_jellies > 0:
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
	fx.float_text(pos, L10n.text("구출 완료!"), Color("#eaffbe"), 30)
	audio.play("pop_big", 1.3)
	G.haptic(40)
	shake_amt = maxf(shake_amt, 8.0)
	c.evacuate(exit.direction)
	if tutorial_id == "rescue_exit":
		_complete_tutorial("exit_reached")
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
		fx.float_text(center, L10n.text("봉인 해제!"), Color("#fff2a6"), 31)
		audio.play("pop_big", 1.25)
		G.haptic(35)
		shake_amt = maxf(shake_amt, 6.0)
		if tutorial_id == "shape_seal":
			_complete_tutorial("seal_opened")
		queue_redraw()


# ────────────────────────── 흡수 (가두기) ──────────────────────────

func _absorb_footprint(c: Catcher) -> void:
	## 캐처가 밟은 셀의 같은 색 젤리를 전부 흡수
	var eaten := 0
	var cracked := 0
	for off in c.cells:
		# _absorb()가 호출 즉시 수용량을 예약하므로 eaten과 감소한 remaining_capacity를
		# 다시 비교하면 여러 마리를 동시에 잡을 때 마지막 젤리를 건너뛰게 된다.
		if c.completed:
			break
		var cl: Vector2i = c.origin_cell + off
		var j = jelly_at.get(cl)
		if j != null and not j.absorbing and j.color_id == c.color_id:
			if not _special_jelly_ready(cl, c):
				continue
			if not _personality_jelly_ready(j, cl):
				continue
			if j.hit_frost():
				cracked += 1
				frozen_at[cl] = j.frost_layers
				fx.impact(cell_pos(cl), Color("#bff7ff"), false)
				fx.float_text(cell_pos(cl), L10n.text("얼음 파괴!"), Color("#e8fdff"), 25)
			elif j.hit_boss():
				# 왕젤리는 남은 체력만큼 같은 색 블록으로 더 두드려야 구조된다.
				cracked += 1
				shake_amt = maxf(shake_amt, 6.0)
				audio.play("pop_big", 0.86)
				G.haptic(26)
			else:
				_absorb(j, c, cl)
				eaten += 1
	if eaten >= 3:
		shake_amt = 5.0
	if cracked > 0:
		shake_amt = maxf(shake_amt, 3.5)
		audio.play("shiny", 1.25, -6.0)
		G.haptic(18)
	if eaten + cracked > 0:
		if eaten > 0:
			c.gulp()


func _personality_jelly_ready(j: Jelly, cell: Vector2i) -> bool:
	if j.personality_id == "sleepy" and j.personality_state == 0:
		j.personality_state = 1
		j.show_personality_feedback(L10n.text("Zzz… 한 번 더!"))
		return false
	if j.personality_id == "lonely" and j.personality_state == 0:
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var friend = jelly_at.get(cell + dir)
			if friend != null and friend != j and not friend.absorbing:
				j.personality_state = 1
				return true
		# 막다른 해답이 생기지 않게 첫 접촉 뒤에는 혼자서도 용기를 내게 한다.
		j.personality_state = 1
		j.show_personality_feedback(L10n.text("친구가 필요해…"))
		return false
	return true


func _special_jelly_ready(cell: Vector2i, catcher: Catcher = null) -> bool:
	if sealed_at.has(cell) and not rescue_switch_active:
		fx.float_text(cell_pos(cell), L10n.text("스위치 먼저!"), Color("#e8ceff"), 23)
		return false
	# 호위 대상은 전담 블록만 구조할 수 있다.
	if cell == escort_cell and catcher != null and catcher.spec_index != escort_catcher:
		fx.float_text(cell_pos(cell), L10n.text("전담 블록만!"), Color("#c9f7de"), 23)
		return false
	# 색 순서 규칙에서 아직 차례가 아닌 색은 구조할 수 없다.
	var ordered = jelly_at.get(cell)
	if ordered != null and _order_blocks_color(ordered.color_id):
		_advance_color_order()
		var current := String(color_order[mini(color_order_index, color_order.size() - 1)])
		fx.float_text(cell_pos(cell), L10n.text("%s 먼저!") % L10n.text(String(G.COLOR_NAMES.get(current, current))), Color("#ffe5a6"), 23)
		return false
	if chain_at.has(cell):
		var link: Dictionary = chain_at[cell]
		if chain_progress[int(link.chain)] != int(link.index):
			fx.float_text(cell_pos(cell), L10n.text("%d번부터!") % (chain_progress[int(link.chain)] + 1), Color("#ffe5a6"), 23)
			return false
	return true


func _absorb(j: Jelly, c: Catcher, cl: Vector2i) -> void:
	var pts := 100
	if j.shiny:
		pts += 500
	var was_shiny := j.shiny
	score += pts
	# 목표
	goals[j.color_id] = max(0, int(goals[j.color_id]) - 1)
	hud.set_goals(goals)
	hud.refresh_objectives()
	main.save.record_daily_action("capture")
	main.save.record_weekly_action("capture")
	main.save.record_jelly_capture(j.color_id, j.shiny)
	if tutorial_id == "square_capture":
		_complete_tutorial("first_capture")
	elif tutorial_id == "color_match":
		_complete_tutorial("correct_color")
	var col: Color = G.COLORS[j.color_id]
	var jp := cell_pos(cl)
	# 포획 즉시 수용량을 예약해 중복 포획은 막되, 블록 드래그는 잠그지 않는다.
	active_absorptions += 1
	jellies.erase(j)
	jelly_at.erase(cl)
	if bomb_at.has(cl):
		_detonate_bomb(cl)
	if cl == boss_cell and not boss_data.is_empty():
		_on_boss_defeated(cl)
	c.begin_trap()
	if chain_at.has(cl):
		var link: Dictionary = chain_at[cl]
		chain_progress[int(link.chain)] += 1
		chain_at.erase(cl)
	if key_unlock_at.has(cl):
		for catcher_index in key_unlock_at[cl]:
			locked_catcher_indices.erase(int(catcher_index))
			for locked in catchers:
				if locked.spec_index == int(catcher_index):
					locked.set_key_locked(false)
					fx.float_text(locked.center_px(), L10n.text("잠금 해제!"), Color("#f4e2ff"), 27)
					break
		audio.play("pop_big", 1.32)
		G.haptic(30)
	for rules in [frozen_at, sealed_at, key_unlock_at, ghost_at]:
		rules.erase(cl)
	var local_trap_pos := (Vector2(cl - c.origin_cell) + Vector2(0.5, 0.5)) * G.CELL
	j.trap_in(c, local_trap_pos)
	fx.swirl(jp, col)
	fx.ring(jp, col, 0.48)
	audio.play("pop", 1.18, -7.0)
	# 블록과 함께 이동하며 0.5초간 갇혀 있다가 현재 블록 안의 위치에서 터진다.
	await _delay(0.5)
	var burst_pos := jp
	if is_instance_valid(j):
		burst_pos = to_local(j.global_position)
		j.pop_trapped()
	fx.burst(burst_pos, col, false)
	fx.ring(burst_pos, col, 0.9)
	fx.impact(burst_pos, col, false)
	shake_amt = maxf(shake_amt, 2.8)
	var txt_col := Color(1.0, 0.95, 0.5) if was_shiny else Color.WHITE
	fx.float_text(burst_pos, "+%d" % pts, txt_col, 28)
	if was_shiny:
		fx.sparkle(burst_pos, 10)
		audio.play("shiny")
	audio.play("pop")
	G.haptic(10)
	var traps_left := c.finish_trap() if is_instance_valid(c) else 0
	if is_instance_valid(c) and c.completed and traps_left == 0:
		if _has_rescue_exit(c):
			c.set_full()
			fx.float_text(c.center_px(), L10n.text("출구로!"), Color("#dcffb4"), 29)
			if tutorial_id == "rescue_exit":
				_show_exit_tutorial(c)
			call_deferred("_try_rescue_exit", c)
		else:
			call_deferred("_finish_catcher", c)
	active_absorptions = maxi(0, active_absorptions - 1)
	_maybe_clear_level()


func _detonate_bomb(cell: Vector2i) -> void:
	## 폭탄 젤리를 구조하면 인접한 장벽이 부서져 새 길이 열린다.
	bomb_at.erase(cell)
	var broken := 0
	for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var near: Vector2i = cell + dir
		if walls.has(near):
			walls.erase(near)
			broken += 1
			fx.impact(cell_pos(near), Color("#ffb066"), true)
	fx.ring(cell_pos(cell), Color("#ff9a3c"), 1.6)
	fx.float_text(cell_pos(cell), L10n.text("장벽 파괴!") if broken > 0 else L10n.text("펑!"), Color("#ffd9a8"), 27)
	audio.play("pop_big", 0.92)
	G.haptic(34)
	shake_amt = maxf(shake_amt, 9.0)
	queue_redraw()


func _on_boss_defeated(cell: Vector2i) -> void:
	## 보스 종류별 마무리 처리. 분열 보스만 보드 상태를 바꾼다.
	if boss_defeated:
		return
	boss_defeated = true
	var boss_type := String(boss_data.get("type", ""))
	var pos := cell_pos(cell)
	fx.ring(pos, Color("#ffd978"), 2.1)
	fx.impact(pos, Color("#ffd978"), true)
	fx.sparkle(pos, 18)
	shake_amt = maxf(shake_amt, 12.0)
	audio.play("clear", 1.25)
	G.haptic(60)
	match boss_type:
		"splitter":
			var splits := int(boss_data.get("splits", 0))
			var color := String(boss_data.get("color", ""))
			var placed := 0
			for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if placed >= splits:
					break
				var near: Vector2i = cell + dir
				if near.x < 0 or near.y < 0 or near.x >= cols or near.y >= rows:
					continue
				if walls.has(near) or voids.has(near) or jelly_at.has(near) or catcher_at.has(near) or seal_gates.has(near):
					continue
				_spawn_jelly(color, near)
				var spawned = jelly_at.get(near)
				if spawned != null:
					spawned.scale = Vector2.ZERO
					spawned.create_tween().tween_property(spawned, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				fx.sparkle(cell_pos(near), 6)
				placed += 1
			hud.set_goals(goals)
			fx.float_text(pos, L10n.text("%d마리로 분열!") % placed, Color("#e2d0ff"), 29)
			# 놓을 자리가 모자라 덜 분열했다면, 미리 잡아 둔 여유 수용량을 정리해
			# 블록이 영원히 GO가 되지 못하는 상태를 막는다.
			if placed < splits:
				_absorb_unused_capacity(color, splits - placed)
		"thief":
			var bounty := float(boss_data.get("bounty", 12.0))
			time_left += bounty
			total_time = maxf(total_time, time_left)
			hud.set_time(time_left, total_time)
			fx.float_text(pos, L10n.text("시간 되찾기 +%d초") % int(bounty), Color("#c9f0ff"), 30)
		_:
			fx.float_text(pos, L10n.text("왕젤리 구조 완료!"), Color("#ffe9a8"), 30)
	hud.refresh_objectives()


func _absorb_unused_capacity(color: String, amount: int) -> void:
	## 분열 보스가 예상보다 적게 갈라졌을 때 남는 여유 수용량을 회수한다.
	var left := amount
	for c in catchers.duplicate():
		if left <= 0:
			break
		if not is_instance_valid(c) or c.color_id != color:
			continue
		while left > 0 and not c.completed:
			left -= 1
			if c.consume():
				if _has_rescue_exit(c):
					c.set_full()
				else:
					call_deferred("_finish_catcher", c)
				break
	call_deferred("_maybe_clear_level")


func _process_boss_timer(delta: float) -> void:
	## 시간 도둑은 살아 있는 동안 주기적으로 남은 시간을 훔친다.
	if boss_defeated or boss_data.is_empty() or String(boss_data.get("type", "")) != "thief":
		return
	boss_steal_timer -= delta
	if boss_steal_timer > 0.0:
		return
	boss_steal_timer = float(boss_data.get("steal_interval", 6.0))
	var amount := float(boss_data.get("steal_amount", 2.0))
	time_left = maxf(0.0, time_left - amount)
	hud.set_time(time_left, total_time)
	if boss_cell.x >= 0:
		fx.float_text(cell_pos(boss_cell), L10n.text("-%0.1f초") % amount, Color("#ffb3c1"), 25)
		fx.ring(cell_pos(boss_cell), Color("#7fb4e0"), 1.1)
	audio.play("lock", 1.05, -6.0)
	G.haptic(14)


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
	# 이어하기는 제한시간을 한 번 더 제공하므로, 남은 시간과 관계없이 1성으로 완료한다.
	if continued_after_fail:
		stars_n = 1
	if not main.active_activity.is_empty() and String(main.active_activity.get("modifier", {}).get("id", "")) == "perfect_rescue" and stars_n < 2:
		state = "play"
		_fail(L10n.text("완벽 구조는 2성 이상으로 완료해야 해요!"))
		return
	audio.play("clear")
	G.haptic(60)
	var i := 0
	for c in catchers:
		if is_instance_valid(c):
			c.cheer(0.08 * i)
			i += 1
	fx.confetti()
	# 이어하기 완료는 1성만 기록하며 신규 별가루도 최대 1개로 제한한다.
	# 이미 1성 이상을 받은 레벨은 기존처럼 중복 지급하지 않는다.
	var reward_cap := 1 if continued_after_fail else -1
	var stardust_reward: int = main.on_level_finished(level_idx, stars_n, true, energy_reserved, reward_cap, elapsed_play_time)
	if main.analytics:
		main.analytics.track("level_clear", {"level": level_idx + 1, "stars": stars_n, "elapsed_seconds": snappedf(elapsed_play_time, 0.01), "stardust_reward": stardust_reward, "continued": continued_after_fail})
		if not L.get("signature", {}).is_empty():
			main.analytics.track("signature_moment", {"level":level_idx + 1,"phase":"clear"})
	energy_reserved = false
	await _delay(1.3)
	var has_next := level_idx + 1 < Levels.level_count()
	if not main.active_activity.is_empty():
		has_next = String(main.active_activity.get("kind", "")) == "weekly_expedition" and main.save.get_weekly_expedition_step() < 5
	var show_clear_result := func():
		if not is_instance_valid(hud):
			return
		hud.show_result(stars_n, score, stardust_reward, main.save.get_stardust(), elapsed_play_time, main.save.get_best_clear_time(level_idx), has_next,
			func():
				if main.active_activity.is_empty(): main.start_level(level_idx + 1)
				else: main.advance_active_activity(),
			func():
				if main.active_activity.is_empty(): main.show_map()
				else: main.show_title(),
			func():
				if main.active_activity.is_empty(): main.start_level(level_idx)
				else: main.retry_active_activity())
	if main.play_chapter_end_if_needed(level_idx, show_clear_result):
		return
	show_clear_result.call()


func _debug_clear_one_star_and_next() -> void:
	if state != "play":
		return
	state = "debug_clear"
	_release()
	main.on_level_finished(level_idx, 1, true, energy_reserved)
	energy_reserved = false
	audio.play("clear", 1.15)
	G.haptic(25)
	var next_level := level_idx + 1
	await _delay(0.12)
	if next_level < Levels.level_count():
		main.start_level(next_level, true, true)
	else:
		main.show_map()


func _fail(reason: String = "시간이 다 됐어요!") -> void:
	state = "fail"
	_release()
	audio.play("fail")
	G.haptic(25)
	main.save.record_level_failure()
	if main.analytics:
		var reason_id := "move_limit" if reason.begins_with(L10n.text("이동")) else "time_out"
		main.analytics.track("level_fail", {"level": level_idx + 1, "reason": reason_id, "elapsed_seconds": snappedf(elapsed_play_time, 0.01), "continued": continued_after_fail})
	for j in jellies:
		if is_instance_valid(j) and not j.absorbing:
			j.sad()
	for c in catchers:
		if is_instance_valid(c):
			c.sad()
	await _delay(0.9)
	hud.show_fail(reason, main.save.get_stardust(), not continued_after_fail,
		_continue_with_stardust,
		func():
			if main.active_activity.is_empty(): main.start_level(level_idx)
			else: main.retry_active_activity(),
		func():
			if main.active_activity.is_empty(): main.show_map()
			else: main.show_title())


func _continue_with_stardust() -> bool:
	var continue_cost: int = GameBalanceCatalogLib.economy("continue_stardust_cost", 20)
	# 한 번 이어서 플레이한 판에서는 다시 시간이 끝나도 두 번째 재시도를 허용하지 않는다.
	# 비용 결제보다 먼저 검사해 중복 입력이나 두 번째 실패에서 별가루가 빠지지 않게 한다.
	if state != "fail" or continued_after_fail:
		return false
	if not main.save.spend_stardust(continue_cost):
		return false
	if main.analytics:
		main.analytics.track("level_continue", {"level": level_idx + 1, "cost": continue_cost})
		main.analytics.track("currency_sink", {"currency": "stardust", "amount": continue_cost, "sink": "level_continue"})
	for j in jellies:
		if is_instance_valid(j) and not j.absorbing:
			j.revive()
	for c in catchers:
		if is_instance_valid(c):
			c.revive()
	time_left = total_time
	hud.set_time(time_left, total_time)
	continued_after_fail = true
	state = "play"
	audio.play("grab", 1.18)
	G.haptic(18)
	# 실패 팝업이 열린 동안 마지막 가두기 타이머가 끝난 경우도 즉시 클리어 판정한다.
	call_deferred("_maybe_clear_level")
	return true


# ────────────────────────── 구조 보조 아이템 ──────────────────────────

func use_booster(booster_id: String) -> void:
	if state != "play" or main.save.get_booster_count(booster_id) <= 0:
		return
	if not main.active_activity.is_empty() and String(main.active_activity.get("modifier", {}).get("id", "")) == "no_boosters":
		fx.float_text(Vector2(G.W * 0.5, G.H - 150), L10n.text("맨손 구조에서는 부스터를 사용할 수 없어요"), Color("#fff0dc"), 22)
		return
	var applied := false
	match booster_id:
		"time":
			time_left += 15.0
			total_time = maxf(total_time, time_left)
			hud.set_time(time_left, total_time)
			fx.float_text(Vector2(G.W * 0.5, 165), L10n.text("+15초"), Color("#fff39b"), 31)
			applied = true
		"compass":
			applied = _show_movement_hint()
		"ice":
			applied = _weaken_frost()
		"space":
			applied = _open_bonus_space()
		"rescue":
			applied = _release_one_gimmick()
	if not applied:
		fx.float_text(Vector2(G.W * 0.5, G.H - 150), L10n.text("지금은 사용할 곳이 없어요"), Color("#fff0dc"), 22)
		return
	main.save.consume_booster(booster_id)
	hud.refresh_boosters()
	audio.play("shiny", 1.1, -5.0)
	G.haptic(18)


func _show_movement_hint() -> bool:
	for c in catchers:
		if not is_instance_valid(c) or c.key_locked:
			continue
		for dir in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			if _can_place(c, c.origin_cell + dir, dir):
				var arrow: String = String({Vector2i.UP: "↑", Vector2i.RIGHT: "→", Vector2i.DOWN: "↓", Vector2i.LEFT: "←"}[dir])
				fx.ring(c.center_px(), G.COLORS[c.color_id], 1.25)
				fx.float_text(c.center_px(), L10n.text("%s 이쪽!") % arrow, Color("#e9fbff"), 30)
				return true
	return false


func _weaken_frost() -> bool:
	var changed := false
	for cell in frozen_at.keys():
		var jelly = jelly_at.get(cell)
		if jelly != null and jelly.frost_layers > 0:
			jelly.frost_layers = maxi(0, jelly.frost_layers - 1)
			frozen_at[cell] = jelly.frost_layers
			jelly.queue_redraw()
			fx.sparkle(cell_pos(cell), 6)
			changed = true
	return changed


func _open_bonus_space() -> bool:
	for cell in walls.keys():
		var adjacent_playable := false
		for dir in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var near: Vector2i = cell + dir
			if near.x >= 0 and near.y >= 0 and near.x < cols and near.y < rows and not walls.has(near) and not voids.has(near):
				adjacent_playable = true
				break
		if adjacent_playable:
			walls.erase(cell)
			fx.impact(cell_pos(cell), Color("#ffd978"), true)
			fx.float_text(cell_pos(cell), L10n.text("길 열림!"), Color("#fff0a8"), 27)
			queue_redraw()
			return true
	return false


func _release_one_gimmick() -> bool:
	for c in catchers:
		if is_instance_valid(c) and c.key_locked:
			locked_catcher_indices.erase(c.spec_index)
			c.set_key_locked(false)
			fx.float_text(c.center_px(), L10n.text("잠금 해제!"), Color("#f4e2ff"), 27)
			return true
	if not rescue_switch_active and not sealed_at.is_empty():
		rescue_switch_active = true
		for cell in sealed_at:
			var jelly = jelly_at.get(cell)
			if jelly != null:
				jelly.set_rescue_sealed(false)
		fx.float_text(Vector2(G.W * 0.5, G.H * 0.5), L10n.text("구조 봉인 해제!"), Color("#f4e2ff"), 29)
		return true
	if not seal_gates.is_empty():
		var seal = seal_gates.values()[0]
		for gate in seal.gates:
			seal_gates.erase(gate)
		seal.active = true
		queue_redraw()
		return true
	return false


# ────────────────────────── 보드 렌더 ──────────────────────────

func _draw() -> void:
	# 보드 전체 그림자와 셀별 입체 베벨을 코드로 직접 렌더링한다.
	# 화려한 챕터 배경 위에서도 퍼즐 실루엣이 즉시 읽히는 서리 낀 젤리 유리판.
	# 배경의 채도를 유지하되 플레이 영역과 경쟁하는 미세 디테일은 한 톤 눌러 준다.
	draw_rect(Rect2(Vector2.ZERO, Vector2(G.W, G.H)), Color(0.025, 0.045, 0.13, 0.13))
	var board_rect := Rect2(origin - Vector2(17, 17), Vector2(cols, rows) * G.CELL + Vector2(32, 32))
	draw_style_box(board_outer_style, board_rect.grow(7.0))
	draw_style_box(board_plate_style, board_rect)
	# 위쪽 림의 길고 부드러운 반사광이 보드 전체를 하나의 입체 오브젝트로 묶는다.
	draw_line(board_rect.position + Vector2(31, 10), board_rect.position + Vector2(board_rect.size.x - 31, 10), Color(1, 1, 1, 0.55), 4.0, true)
	for r in range(rows):
		for c in range(cols):
			var cell := Vector2i(c, r)
			var p := origin + Vector2(c, r) * G.CELL
			if voids.has(cell):
				continue
			draw_style_box(tile_shadow_style, Rect2(p + Vector2(2, 7), Vector2(G.CELL - 1, G.CELL - 1)))
			draw_style_box(tile_rim_style, Rect2(p, Vector2(G.CELL - 2, G.CELL - 2)))
			if walls.has(cell):
				draw_style_box(wall_tile_style, Rect2(p + Vector2(5, 5), Vector2(G.CELL - 12, G.CELL - 12)))
				draw_rect(Rect2(p + Vector2(11, 10), Vector2(G.CELL - 24, 8)), Color(1, 1, 1, 0.2))
			else:
				var even := (c + r) % 2 == 0
				draw_style_box(floor_tile_styles[0 if even else 1], Rect2(p + Vector2(5, 5), Vector2(G.CELL - 12, G.CELL - 12)))
				draw_rect(Rect2(p + Vector2(12, 11), Vector2(G.CELL - 26, 5)), Color(1, 1, 1, 0.46))
				# 아래쪽의 은은한 음영과 모서리 광점으로 장난감 타일 같은 재질감을 더한다.
				draw_line(p + Vector2(14, G.CELL - 12), p + Vector2(G.CELL - 16, G.CELL - 12), Color(0.32, 0.29, 0.48, 0.18), 4.0, true)
				draw_line(p + Vector2(12, 18), p + Vector2(12, G.CELL - 23), Color(1, 1, 1, 0.25), 2.0, true)
				draw_circle(p + Vector2(G.CELL - 17, 16), 2.5, Color(1, 1, 1, 0.62))
			# 끈끈이 바닥: 지나가면 블록이 잠시 느려진다.
			if sticky_at.has(cell):
				var sticky_center := p + Vector2.ONE * G.CELL * 0.5
				draw_circle(sticky_center, G.CELL * 0.33, Color(0.86, 0.63, 0.22, 0.34))
				draw_arc(sticky_center, G.CELL * 0.33, 0, TAU, 26, Color("#e0a63c"), 4.0, true)
				for blob in [Vector2(-13, -8), Vector2(11, -3), Vector2(-4, 12)]:
					draw_circle(sticky_center + blob, 6.0, Color(0.99, 0.82, 0.45, 0.72))
			# 일방통행 타일: 화살표 방향으로만 진입할 수 있다.
			if one_way_at.has(cell):
				var ow_center := p + Vector2.ONE * G.CELL * 0.5
				var ow_dir := Vector2(one_way_at[cell]).normalized()
				var ow_side := ow_dir.rotated(PI * 0.5)
				draw_circle(ow_center, G.CELL * 0.32, Color(0.35, 0.72, 0.55, 0.26))
				draw_arc(ow_center, G.CELL * 0.32, 0, TAU, 26, Color("#4fbf8b"), 4.0, true)
				for step_index in range(3):
					var arrow_tip: Vector2 = ow_center + ow_dir * (float(step_index) * 11.0)
					draw_line(arrow_tip - ow_dir * 6.0 + ow_side * 8.0, arrow_tip, Color(1, 1, 1, 0.92), 4.5, true)
					draw_line(arrow_tip - ow_dir * 6.0 - ow_side * 8.0, arrow_tip, Color(1, 1, 1, 0.92), 4.5, true)
			# 501+: 짝 포털.
			if portal_at.has(cell):
				var portal_center := p + Vector2.ONE * G.CELL * 0.5
				draw_circle(portal_center, G.CELL * 0.31, Color(0.42, 0.24, 0.78, 0.3))
				for ring_index in range(3):
					draw_arc(portal_center, G.CELL * (0.12 + ring_index * 0.07), float(ring_index) * 0.8, TAU - float(ring_index) * 0.4, 24, Color("#cdb8ff").lerp(Color("#65e2ff"), float(ring_index) / 2.0), 4.0, true)
			# 601+: 이동 횟수에 따라 무너지는 균열벽.
			if fragile_at.has(cell):
				var crack_center := p + Vector2.ONE * G.CELL * 0.5
				draw_line(crack_center + Vector2(-18, -22), crack_center + Vector2(-4, -5), Color("#f1ddff"), 4.0, true)
				draw_line(crack_center + Vector2(-4, -5), crack_center + Vector2(13, 3), Color("#f1ddff"), 4.0, true)
				draw_line(crack_center + Vector2(-4, -5), crack_center + Vector2(-12, 18), Color("#f1ddff"), 4.0, true)
				draw_string(ThemeDB.fallback_font, crack_center + Vector2(-7, 25), str(int(fragile_at[cell])), HORIZONTAL_ALIGNMENT_CENTER, 16, 19, Color.WHITE)
			# 801+: 방향에 따라 시간을 더하거나 빼는 바람길.
			if current_at.has(cell):
				var current_center := p + Vector2.ONE * G.CELL * 0.5
				var current_dir := Vector2(current_at[cell]).normalized()
				var current_side := current_dir.rotated(PI * 0.5)
				for lane in [-1.0, 0.0, 1.0]:
					var base: Vector2 = current_center + current_side * lane * 10.0
					draw_line(base - current_dir * 18.0, base + current_dir * 17.0, Color("#8de5f2"), 4.0, true)
					draw_line(base + current_dir * 17.0, base + current_dir * 7.0 + current_side * 7.0, Color("#d9fbff"), 3.0, true)
			# 901+: 한 번 밟으면 사라지는 시간균열.
			if time_rift_at.has(cell):
				var rift_center := p + Vector2.ONE * G.CELL * 0.5
				draw_circle(rift_center, G.CELL * 0.29, Color(0.28, 0.12, 0.48, 0.35))
				draw_arc(rift_center, G.CELL * 0.24, -PI * 0.4, PI * 1.35, 24, Color("#e4b9ff"), 5.0, true)
				draw_line(rift_center + Vector2(0, -13), rift_center + Vector2(0, 2), Color.WHITE, 4.0, true)
				draw_line(rift_center, rift_center + Vector2(10, 8), Color.WHITE, 4.0, true)
			# 봉인 젤리를 깨우는 구조 스위치. 활성화 후에는 밝은 체크 링으로 남는다.
			if switch_at.has(cell):
				var center := p + Vector2.ONE * G.CELL * 0.5
				var switch_color := Color("#79d58c") if rescue_switch_active else Color("#a66de0")
				draw_circle(center + Vector2(0, 4), G.CELL * 0.29, Color(0.1, 0.05, 0.18, 0.25))
				draw_circle(center, G.CELL * 0.28, switch_color.darkened(0.28))
				draw_circle(center, G.CELL * 0.21, switch_color)
				draw_arc(center, G.CELL * 0.18, PI * 1.1, PI * 1.9, 18, Color(1, 1, 1, 0.62), 4, true)
				if rescue_switch_active:
					draw_line(center + Vector2(-12, 0), center + Vector2(-3, 10), Color.WHITE, 6, true)
					draw_line(center + Vector2(-3, 10), center + Vector2(15, -12), Color.WHITE, 6, true)
				else:
					var diamond := PackedVector2Array([center + Vector2(0, -14), center + Vector2(14, 0), center + Vector2(0, 14), center + Vector2(-14, 0)])
					draw_colored_polygon(diamond, Color.WHITE)
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
	# 잡은 블록이 이동 가능한 방향만 밝게 보여 주어 시행착오와 오입력을 줄인다.
	if grabbed and is_instance_valid(grabbed) and not grabbed.movement_locked:
		var base := grabbed.center_px()
		var hint_col: Color = G.COLORS[grabbed.color_id].lightened(0.28)
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not _can_place(grabbed, grabbed.origin_cell + dir, dir):
				continue
			var center := base + Vector2(dir) * G.CELL
			draw_circle(center, 18, Color(hint_col.r, hint_col.g, hint_col.b, 0.28))
			draw_arc(center, 18, 0, TAU, 24, Color(1, 1, 1, 0.82), 3.0, true)
			var dv := Vector2(dir)
			var side := dv.rotated(PI * 0.5)
			draw_line(center - dv * 7, center + dv * 8, Color.WHITE, 4, true)
			draw_line(center + dv * 8, center + dv * 2 + side * 6, Color.WHITE, 4, true)
			draw_line(center + dv * 8, center + dv * 2 - side * 6, Color.WHITE, 4, true)


# ────────────────────────── 헤드리스/QA 유틸 ──────────────────────────

func debug_validate_tutorial_flow() -> bool:
	if catchers.is_empty() or tutorial_id.is_empty():
		return false
	main.save.completed_tutorials.erase(tutorial_id)
	_begin_tutorial(false)
	var valid := tutorial_active and tutorial_timer_paused and hud.tutorial_guide != null
	_tutorial_first_grab()
	valid = valid and tutorial_active and not tutorial_timer_paused and hud.tutorial_guide == null
	_complete_tutorial("qa_complete")
	valid = valid and not tutorial_active and not tutorial_timer_paused and main.save.has_completed_tutorial(tutorial_id)
	valid = valid and hud.booster_tray != null and not hud.booster_tray.visible
	return valid

func debug_validate_touch_mapping(test_offset := Vector2(0, 160)) -> bool:
	## 세로로 긴 Android 화면처럼 보드가 이동한 상태에서 선택 좌표와 멀티터치를 검증한다.
	if catchers.is_empty() or state != "play":
		return false
	var original_position := position
	position = test_offset
	var target: Catcher = catchers[0]
	var target_local := cell_pos(target.origin_cell + target.cells[0])
	var target_viewport := to_global(target_local)
	var press := InputEventScreenTouch.new()
	press.index = 3
	press.pressed = true
	press.position = target_viewport
	_unhandled_input(press)
	var valid := grabbed == target and active_touch_index == 3
	# Android에서 이전 release가 유실된 뒤 같은 index가 재사용되는 상황에서도
	# 입력 잠금이 풀리고 새 press가 정상적으로 대상을 다시 잡아야 한다.
	var recovered_press := InputEventScreenTouch.new()
	recovered_press.index = 3
	recovered_press.pressed = true
	recovered_press.position = target_viewport
	_unhandled_input(recovered_press)
	valid = valid and grabbed == target and active_touch_index == 3
	# 다른 손가락이 떨어져도 첫 손가락의 드래그가 유지되어야 한다.
	var unrelated_release := InputEventScreenTouch.new()
	unrelated_release.index = 4
	unrelated_release.pressed = false
	unrelated_release.position = target_viewport
	_unhandled_input(unrelated_release)
	valid = valid and grabbed == target and active_touch_index == 3
	var release := InputEventScreenTouch.new()
	release.index = 3
	release.pressed = false
	release.position = target_viewport
	_unhandled_input(release)
	valid = valid and grabbed == null and active_touch_index == -1
	position = original_position
	return valid


func debug_validate_smooth_drag() -> bool:
	## 반 칸 이전에는 탄성 미리보기, 이후에는 실제 격자 이동이 시작되는지 검증한다.
	if catchers.is_empty() or state != "play":
		return false
	var target: Catcher = null
	var direction := Vector2i.ZERO
	for candidate in catchers:
		for test_dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if _can_place(candidate, candidate.origin_cell + test_dir):
				target = candidate
				direction = test_dir
				break
		if target:
			break
	if not target:
		return false
	var start_cell := target.origin_cell
	var center := to_global(cell_pos(start_cell + target.cells[0]))
	var press := InputEventScreenTouch.new()
	press.index = 7
	press.pressed = true
	press.position = center
	_unhandled_input(press)
	var small_drag := InputEventScreenDrag.new()
	small_drag.index = 7
	small_drag.position = center + Vector2(direction) * 20.0
	_unhandled_input(small_drag)
	_process_drag()
	var preview_valid := target.origin_cell == start_cell and target.drag_pull_target.length() > 8.0
	target._process(1.0 / 60.0)
	preview_valid = preview_valid and target.position.distance_to(target.slide_target) > 1.0
	var step_drag := InputEventScreenDrag.new()
	step_drag.index = 7
	step_drag.position = center + Vector2(direction) * (G.CELL * 0.62)
	_unhandled_input(step_drag)
	_process_drag()
	var step_valid := target.origin_cell == start_cell + direction and target.arrival_pending
	var release := InputEventScreenTouch.new()
	release.index = 7
	release.pressed = false
	release.position = step_drag.position
	_unhandled_input(release)
	return preview_valid and step_valid and grabbed == null

func _debug_terrain_reach(c: Catcher) -> Dictionary:
	if _debug_terrain_cache.has(c.spec_index):
		return _debug_terrain_cache[c.spec_index]
	var queue: Array[Vector2i] = [c.origin_cell]
	var seen := {c.origin_cell: true}
	var cells := {}
	var head := 0
	while head < queue.size():
		var from := queue[head]
		head += 1
		for off in c.cells:
			cells[from + off] = true
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var target := from + direction
			if seen.has(target) or not _one_way_allows(c, target, direction):
				continue
			var fits := true
			for off in c.cells:
				var cell: Vector2i = target + off
				if cell.x < 0 or cell.y < 0 or cell.x >= cols or cell.y >= rows or walls.has(cell) or voids.has(cell):
					fits = false
					break
			if fits:
				seen[target] = true
				queue.append(target)
	_debug_terrain_cache[c.spec_index] = cells
	return cells


func _debug_reserved_cells(c: Catcher) -> Dictionary:
	# 좁은 모서리처럼 특정 블록만 담을 수 있는 젤리에 마지막 수용량을 남긴다.
	if _debug_reservation_cache.has(c.spec_index):
		return _debug_reservation_cache[c.spec_index]
	var reserved := {}
	for j in jellies:
		if j.color_id != c.color_id:
			continue
		var capable: Array = []
		for candidate in catchers:
			if candidate.completed or candidate.color_id != j.color_id:
				continue
			if j.cell == escort_cell and candidate.spec_index != escort_catcher:
				continue
			if _debug_terrain_reach(candidate).has(j.cell):
				capable.append(candidate)
		if capable.size() == 1 and capable[0] == c:
			reserved[j.cell] = true
	_debug_reservation_cache[c.spec_index] = reserved
	return reserved


func _debug_preserves_capacity(c: Catcher, target: Vector2i, positions: Array = []) -> bool:
	if c.completed:
		return true
	var reserved := _debug_reserved_cells(c)
	var unreserved := 0
	for off in c.cells:
		var j = jelly_at.get(target + off)
		if j != null and not j.absorbing and j.color_id == c.color_id and not reserved.has(j.cell):
			unreserved += 1
	if unreserved > c.remaining_capacity - reserved.size():
		return false
	return _debug_can_finish_catcher(c, target, positions)


func _debug_can_finish_catcher(c: Catcher, target: Vector2i, positions: Array) -> bool:
	if _debug_relaxed_continuation:
		return true
	# 마지막 수용량을 쓰기 전, 남은 블록으로 후속 구조가 가능한지 확인한다.
	# 복합 규칙의 실제 판정은 여전히 _try_step/도착 처리에서 수행한다.
	if not rescue_exits.is_empty() or not portal_at.is_empty() or not color_order.is_empty() or escort_catcher >= 0 or String(boss_data.get("type", "")) == "splitter":
		return true
	var captured := {}
	for off in c.cells:
		var cell: Vector2i = target + off
		var j = jelly_at.get(cell)
		if j == null or j.absorbing or j.color_id != c.color_id:
			continue
		if j.frost_layers > 0 or j.boss_hp > 1 or (not j.personality_id.is_empty() and j.personality_state == 0):
			return true
		if sealed_at.has(cell) and not rescue_switch_active:
			continue
		if chain_at.has(cell):
			var link: Dictionary = chain_at[cell]
			if chain_progress[int(link.chain)] != int(link.index):
				continue
		captured[cell] = true
	if captured.size() < c.remaining_capacity:
		return true
	var cache_key := "%d:%s:%s" % [c.spec_index, target, positions]
	if _debug_continuation_cache.has(cache_key):
		return _debug_continuation_cache[cache_key]
	# 다중 블록 탐색의 모든 후보마다 전체 풀이를 반복하면 화면이 멎는다.
	# 보조 휴리스틱에만 예산을 두며 실제 충돌/수용량 검사는 계속 적용한다.
	if _debug_continuation_cache.size() >= 64:
		return true
	var board: Array = []
	for y in range(rows):
		var row := ""
		for x in range(cols):
			var cell := Vector2i(x, y)
			var j = jelly_at.get(cell)
			row += "_" if voids.has(cell) else "#" if walls.has(cell) else String(j.color_id) if j != null and not captured.has(cell) else "."
		board.append(row)
	var specs: Array = []
	for i in range(catchers.size()):
		var candidate: Catcher = catchers[i]
		var capacity: int = candidate.remaining_capacity - (mini(captured.size(), c.remaining_capacity) if candidate == c else 0)
		if capacity <= 0 or candidate.completed:
			continue
		var cell: Vector2i = target if candidate == c else positions[i] if not positions.is_empty() else candidate.origin_cell
		specs.append({"cell": [cell.x, cell.y], "color": candidate.color_id, "shape": candidate.shape_id, "capacity": capacity})
	var snapshot := {"grid": board, "catchers": specs, "one_ways": L.get("one_ways", []), "ghosts": []}
	for cell in ghost_at:
		if not captured.has(cell): snapshot.ghosts.append([cell.x, cell.y])
	var possible := bool(LevelSolverLib._greedy_solve(snapshot).ok)
	_debug_continuation_cache[cache_key] = possible
	return possible


func _debug_goal(c: Catcher, org: Vector2i, priority_only: bool) -> bool:
	var reserved := _debug_reserved_cells(c)
	for off in c.cells:
		var cell: Vector2i = org + off
		if not rescue_switch_active and switch_at.has(cell):
			return true
		if c.completed:
			for gate in rescue_exits:
				if gate.cell == cell and gate.color == c.color_id and (gate.catcher < 0 or gate.catcher == c.spec_index):
					return true
			continue
		var j = jelly_at.get(cell)
		if j == null or j.absorbing or j.color_id != c.color_id or _order_blocks_color(j.color_id):
			continue
		if c.remaining_capacity <= reserved.size() and not reserved.has(cell):
			continue
		if sealed_at.has(cell) and not rescue_switch_active:
			continue
		if cell == escort_cell and c.spec_index != escort_catcher:
			continue
		if chain_at.has(cell):
			var link: Dictionary = chain_at[cell]
			if chain_progress[int(link.chain)] != int(link.index):
				continue
		if not priority_only or key_unlock_at.has(cell) or chain_at.has(cell):
			return true
	return false


func _debug_path(c: Catcher, priority_only: bool) -> Array[Vector2i]:
	# 현재 보드를 읽기만 한다. 탐색 중에도 캐처 위치/점유표를 변경하지 않는다.
	var queue: Array[Vector2i] = [c.origin_cell]
	var paths := {c.origin_cell: []}
	var head := 0
	while head < queue.size():
		var from := queue[head]
		head += 1
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var target := from + direction
			if not _can_place(c, target, direction) or not _debug_preserves_capacity(c, target):
				continue
			var route: Array[Vector2i] = []
			route.assign(paths[from])
			route.append(direction)
			# 얼음/왕젤리는 한 칸 나갔다 돌아와 다시 접촉할 수 있어야 한다.
			if _debug_goal(c, target, priority_only):
				return route
			if not paths.has(target):
				paths[target] = route
				queue.append(target)
	return []


func _debug_unblocking_route() -> Array:
	# 구조할 수 있는 목표가 없으면 다른 블록을 비켜 주는 합법적인 이동도 탐색한다.
	var initial: Array[Vector2i] = []
	for c in catchers:
		initial.append(c.origin_cell)
	var queue: Array = [{"positions": initial, "route": []}]
	var seen := {str(initial): true}
	var head := 0
	while head < queue.size() and head < 10000:
		var entry: Dictionary = queue[head]
		head += 1
		var occupancy := {}
		for i in range(catchers.size()):
			for off in catchers[i].cells:
				occupancy[entry.positions[i] + off] = catchers[i]
		for i in range(catchers.size()):
			var c: Catcher = catchers[i]
			if c.key_locked or c.movement_locked:
				continue
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var target: Vector2i = entry.positions[i] + direction
				if not _can_place(c, target, direction, occupancy) or not _debug_preserves_capacity(c, target, entry.positions):
					continue
				var route: Array = entry.route.duplicate()
				route.append({"catcher": c, "direction": direction})
				if _debug_goal(c, target, false):
					return route
				var positions: Array = entry.positions.duplicate()
				positions[i] = target
				var key := str(positions)
				if not seen.has(key):
					seen[key] = true
					queue.append({"positions": positions, "route": route})
	return []


func debug_capture_one(relaxed_continuation: bool = false) -> bool:
	# 실제 입력과 동일한 이동, 슬라이드, 도착, 흡수 파이프라인을 사용한다.
	_debug_relaxed_continuation = relaxed_continuation
	_debug_reservation_cache.clear()
	_debug_terrain_cache.clear()
	_debug_continuation_cache.clear()
	var candidates := catchers.duplicate()
	var count: int = L.catchers.size()
	candidates.sort_custom(func(a, b): return posmod(a.spec_index - debug_catcher_shift, count) < posmod(b.spec_index - debug_catcher_shift, count))
	for priority_only in [true, false]:
		for c: Catcher in candidates:
			if not is_instance_valid(c) or c.key_locked or c.movement_locked or c.arrival_pending:
				continue
			var route := _debug_path(c, priority_only)
			if route.is_empty():
				continue
			for direction in route:
				if state != "play" or not is_instance_valid(c) or not catchers.has(c):
					return true
				var before := c.origin_cell
				if not _try_step(c, direction):
					# 성격 젤리가 회피했다면 갱신된 보드에서 다음 경로를 찾는다.
					return true
				while is_instance_valid(c) and c.arrival_pending and state == "play":
					await get_tree().process_frame
				if not is_instance_valid(c) or not catchers.has(c) or c.origin_cell != before + direction or active_absorptions > 0:
					return true
			return true
	var unblocking := _debug_unblocking_route()
	for step in unblocking:
		var c: Catcher = step.catcher
		if not is_instance_valid(c) or state != "play" or not _try_step(c, step.direction):
			return true
		while is_instance_valid(c) and c.arrival_pending and state == "play":
			await get_tree().process_frame
		if active_absorptions > 0 or state != "play":
			return true
	if unblocking.is_empty() and not relaxed_continuation:
		# 탐욕적 후속 탐색 실패는 불가능의 증명이 아니다. 실제 이동 규칙과
		# 수용량 예약은 유지하고, 후속 탐색 휴리스틱만 완화해 다시 찾는다.
		return await debug_capture_one(true)
	return not unblocking.is_empty()


func debug_drive() -> bool:
	debug_catcher_shift = int(LevelSolverLib._greedy_solve(L).get("shift", 0))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autoplay-shift="):
			debug_catcher_shift = int(arg.get_slice("=", 1))
	var attempts := 0
	while state == "play" and attempts < 2000:
		if active_absorptions > 0:
			await get_tree().process_frame
			continue
		attempts += 1
		if OS.get_cmdline_user_args().has("--trace-autoplay"):
			print("[autoplay trace] level=", level_idx + 1, " attempt=", attempts, " moves=", total_moves, " left=", jellies.size())
		if not await debug_capture_one():
			for c in catchers:
				print("[autoplay] catcher=", c.spec_index, " cell=", c.origin_cell, " color=", c.color_id, " capacity=", c.remaining_capacity, " locked=", c.key_locked)
			for j in jellies:
				print("[autoplay] jelly=", j.cell, " color=", j.color_id, " personality=", j.personality_id)
			push_error("[autoplay] route search exhausted: level=%d moves=%d left=%d (not proof of an unsolvable level)" % [level_idx + 1, total_moves, jellies.size()])
			break
		await get_tree().process_frame
	print("[smoke] level=", level_idx, " state=", state, " moves=", total_moves, " limit=", move_limit, " left=", jellies.size(), " catchers=", catchers.size())
	return state == "clear"


func _delay(seconds: float) -> Signal:
	# 화면이 사라지면 대기 중인 코루틴/콜백도 함께 해제된다.
	var timer := Timer.new()
	timer.one_shot = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timer.timeout.connect(timer.queue_free)
	add_child(timer)
	timer.start(seconds)
	return timer.timeout
