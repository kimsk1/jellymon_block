extends Node2D
class_name Catcher
## 플레이어가 움직이는 색상 구멍 블록 (다양한 폴리오미노 모양).
## 같은 색 젤리는 흡수하며 지나가고, 다른 색 젤리·다른 캐처·벽에는 막힌다.

var color_id := "R"
var shape_id := "S1"
var spec_index := -1
var cells: Array = []          # Vector2i 오프셋 목록
var origin_cell := Vector2i.ZERO
var grabbed := false
var slide_target := Vector2.ZERO
var drag_pull_target := Vector2.ZERO
var base_scale := 1.0
var phase := 0.0
var sprite: Sprite2D
var visual_root: Node2D
var glow_sprite: Sprite2D
var bbox_size := Vector2.ONE
var capacity := 1
var remaining_capacity := 1
var completed := false
var arrival_pending := false
var movement_locked := false
var count_badge: Label
var badge_panel: PanelContainer
var badge_style: StyleBoxFlat
var key_locked := false
var key_lock_panel: PanelContainer

const SLIDE_SPEED := 1450.0
const DRAG_PULL_MAX := 20.0


func setup(cid: String, shape: String, amount: int = 1) -> void:
	color_id = cid
	shape_id = shape
	capacity = maxi(1, amount)
	remaining_capacity = capacity
	cells = G.SHAPES[shape]
	phase = randf() * TAU
	var bbox := Vector2.ZERO
	for off in cells:
		bbox.x = maxf(bbox.x, float(off.x + 1))
		bbox.y = maxf(bbox.y, float(off.y + 1))
	bbox_size = bbox
	visual_root = Node2D.new()
	add_child(visual_root)
	glow_sprite = Sprite2D.new()
	glow_sprite.texture = load("res://assets/fx/soft.png")
	glow_sprite.position = bbox * G.CELL * 0.5
	glow_sprite.scale = Vector2(maxf(2.8, bbox.x * 2.55), maxf(2.8, bbox.y * 2.55))
	glow_sprite.modulate = Color(G.COLORS[cid].r, G.COLORS[cid].g, G.COLORS[cid].b, 0.2)
	glow_sprite.z_index = -2
	visual_root.add_child(glow_sprite)
	# 모든 모양을 동일한 프리미엄 재질로 직접 그려 기존 에셋/생성 모양 간 품질 차이를 없앤다.
	var generated := ShapeVisual.new()
	generated.setup(cells, G.COLORS[cid])
	visual_root.add_child(generated)
	badge_panel = PanelContainer.new()
	badge_style = StyleBoxFlat.new()
	badge_style.bg_color = Color("#fff7d6")
	badge_style.border_color = G.COLORS[cid].darkened(0.28)
	badge_style.set_border_width_all(4)
	badge_style.set_corner_radius_all(20)
	badge_style.shadow_color = Color(0.04, 0.05, 0.14, 0.42)
	badge_style.shadow_size = 4
	badge_style.shadow_offset = Vector2(0, 3)
	badge_panel.add_theme_stylebox_override("panel", badge_style)
	# 모양의 bounding box 우하단은 T/L/S/Z 블록에서 실제로 비어 있을 수 있다.
	# 실제 점유 칸 중 가장 아래·오른쪽 칸 안에 배지를 넣어 숫자/GO가 블록을
	# 벗어나거나 이웃 타일을 덮지 않도록 한다.
	var badge_cell: Vector2i = cells[0]
	for off: Vector2i in cells:
		if off.y > badge_cell.y or (off.y == badge_cell.y and off.x > badge_cell.x):
			badge_cell = off
	# 48px 배지와 최대 7px 그림자까지 84px 점유 칸 안에 들어오는 위치다.
	badge_panel.position = Vector2(badge_cell) * G.CELL + Vector2(G.CELL - 56, G.CELL - 57)
	badge_panel.size = Vector2(48, 48)
	badge_panel.z_index = 5
	# 숫자 위에서 시작한 드래그도 블록으로 전달되도록 UI 입력을 가로채지 않는다.
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge_panel)
	count_badge = Label.new()
	count_badge.text = str(remaining_capacity)
	count_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_badge.add_theme_font_size_override("font_size", 28)
	count_badge.add_theme_color_override("font_color", Color("#27304d"))
	count_badge.add_theme_color_override("font_outline_color", Color.WHITE)
	count_badge.add_theme_constant_override("outline_size", 4)
	count_badge.custom_minimum_size = Vector2(40, 40)
	count_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_panel.add_child(count_badge)


func badge_contains(screen_point: Vector2) -> bool:
	## 숫자 위에서 시작한 드래그가 작은 배지 가장자리에서도 안정적으로 잡히게 한다.
	return badge_panel != null and badge_panel.get_global_rect().grow(8.0).has_point(screen_point)


func set_key_locked(value: bool) -> void:
	key_locked = value
	if not value:
		if key_lock_panel and is_instance_valid(key_lock_panel):
			var unlock_tween := key_lock_panel.create_tween()
			unlock_tween.tween_property(key_lock_panel, "scale", Vector2(1.35, 0.2), 0.16).set_trans(Tween.TRANS_BACK)
			unlock_tween.parallel().tween_property(key_lock_panel, "modulate:a", 0.0, 0.16)
			unlock_tween.tween_callback(key_lock_panel.queue_free)
		visual_root.modulate = Color.WHITE
		return
	visual_root.modulate = Color(0.72, 0.74, 0.86)
	key_lock_panel = PanelContainer.new()
	key_lock_panel.position = bbox_size * G.CELL * 0.5 - Vector2(28, 28)
	key_lock_panel.size = Vector2(56, 56)
	key_lock_panel.pivot_offset = Vector2(28, 28)
	key_lock_panel.z_index = 8
	key_lock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#62498d")
	style.border_color = Color("#e9d7ff")
	style.set_border_width_all(4)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(0.08, 0.03, 0.16, 0.42)
	style.shadow_size = 5
	key_lock_panel.add_theme_stylebox_override("panel", style)
	add_child(key_lock_panel)
	var icon := Label.new()
	icon.text = "🔒"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 27)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_lock_panel.add_child(icon)


func center_px() -> Vector2:
	# Game 자식인 FX와 같은 로컬 좌표계를 사용한다. global_position을 쓰면
	# 폴드/태블릿 안전 영역 오프셋이 효과에 두 번 적용된다.
	return position + bbox_size * G.CELL * 0.5


func mouth_px(cell_world: Vector2) -> Vector2:
	## 흡수 연출 목적지: 해당 셀 위 캐처 구멍 중심
	return cell_world


func set_grabbed(g: bool) -> void:
	grabbed = g
	if not g:
		drag_pull_target = Vector2.ZERO
	visual_root.modulate = Color(1.18, 1.18, 1.18) if g else Color.WHITE
	if glow_sprite:
		glow_sprite.modulate.a = 0.4 if g else (0.3 if completed else 0.2)


func set_drag_pull(offset: Vector2) -> void:
	## 격자 판정 전에도 블록이 손가락을 살짝 따라와 입력 지연감을 없앤다.
	drag_pull_target = offset.limit_length(DRAG_PULL_MAX)


func _process(delta: float) -> void:
	var visual_target := slide_target
	if grabbed and not arrival_pending:
		visual_target += drag_pull_target
	var before := position
	position = position.move_toward(visual_target, SLIDE_SPEED * delta)
	var motion := position - before
	var moving_ratio := clampf(motion.length() / maxf(1.0, SLIDE_SPEED * delta), 0.0, 1.0)
	var k := 0.04 if grabbed else 0.02
	var s := sin(Time.get_ticks_msec() / 1000.0 * 2.2 + phase)
	var motion_scale := Vector2.ONE
	if motion.length_squared() > 0.01:
		if absf(motion.x) >= absf(motion.y):
			motion_scale = Vector2(1.0 + 0.028 * moving_ratio, 1.0 - 0.018 * moving_ratio)
		else:
			motion_scale = Vector2(1.0 - 0.018 * moving_ratio, 1.0 + 0.028 * moving_ratio)
	if sprite:
		sprite.scale = Vector2(base_scale * (1.0 + k * s), base_scale * (1.0 - k * s)) * motion_scale
	else:
		visual_root.scale = Vector2(1.0 + k * s, 1.0 - k * s) * motion_scale
	if glow_sprite:
		glow_sprite.modulate.a = (0.32 if completed else 0.18) + s * (0.06 if completed else 0.025)


func gulp() -> void:
	## 꿀꺽 연출 (흡수 순간)
	var tw := create_tween()
	if sprite:
		tw.tween_property(sprite, "scale", Vector2(base_scale * 1.1, base_scale * 0.92), 0.07)
		tw.tween_property(sprite, "scale", Vector2.ONE * base_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(visual_root, "scale", Vector2(1.1, 0.92), 0.07)
		tw.tween_property(visual_root, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func consume() -> bool:
	if completed:
		return true
	remaining_capacity = maxi(0, remaining_capacity - 1)
	count_badge.text = str(remaining_capacity)
	var tw := count_badge.create_tween()
	tw.tween_property(count_badge, "scale", Vector2(1.35, 1.35), 0.08)
	tw.tween_property(count_badge, "scale", Vector2.ONE, 0.12)
	if remaining_capacity == 0:
		completed = true
		return true
	return false


func set_full() -> void:
	completed = true
	movement_locked = true
	count_badge.text = "GO"
	count_badge.add_theme_font_size_override("font_size", 20)
	badge_style.bg_color = Color("#dfffe6")
	badge_style.border_color = Color("#43b66a")
	visual_root.modulate = Color(1.14, 1.14, 1.2)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.08, 0.94), 0.1)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func evacuate(direction: Vector2i) -> void:
	## FULL 블록이 벽 통로를 통해 보드 밖으로 배송되는 연출.
	set_process(false)
	movement_locked = true
	count_badge.visible = false
	badge_panel.visible = false
	var target := position + Vector2(direction) * G.CELL * 2.4
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position", target, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector2(0.24, 0.7) if direction.x != 0 else Vector2(0.7, 0.24), 0.34)
	tw.tween_property(self, "modulate:a", 0.0, 0.22).set_delay(0.12)
	tw.chain().tween_callback(queue_free)


func vanish() -> void:
	set_process(false)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.18, 0.1), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(queue_free)


func cheer(delay_s: float) -> void:
	set_process(false)
	var y0 := position.y
	var tw := create_tween()
	tw.tween_interval(delay_s)
	tw.tween_property(self, "position:y", y0 - 26.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", y0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.set_loops(3)


func sad() -> void:
	set_process(false)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(visual_root, "modulate", Color(0.62, 0.6, 0.68), 0.45)
	tw.tween_property(visual_root, "scale:y", 0.9, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func revive() -> void:
	set_process(true)
	visual_root.modulate = Color(0.72, 0.74, 0.86) if key_locked else (Color(1.14, 1.14, 1.2) if completed else Color.WHITE)
	visual_root.scale = Vector2.ONE


class ShapeVisual extends Node2D:
	var shape_cells: Array = []
	var edge_color := Color.WHITE

	func setup(p_cells: Array, p_color: Color) -> void:
		shape_cells = p_cells
		edge_color = p_color
		queue_redraw()

	func _cell_polygon(off: Vector2i) -> PackedVector2Array:
		var p := Vector2(off) * G.CELL
		return PackedVector2Array([
			p,
			p + Vector2(G.CELL, 0),
			p + Vector2(G.CELL, G.CELL),
			p + Vector2(0, G.CELL),
		])

	func _largest_polygon(polygons: Array[PackedVector2Array]) -> PackedVector2Array:
		if polygons.is_empty():
			return PackedVector2Array()
		var best: PackedVector2Array = polygons[0]
		var best_size := 0.0
		for polygon in polygons:
			var rect := Rect2(polygon[0], Vector2.ZERO)
			for point in polygon:
				rect = rect.expand(point)
			var area := rect.size.x * rect.size.y
			if area > best_size:
				best = polygon
				best_size = area
		return best

	func _joined_polygon() -> PackedVector2Array:
		if shape_cells.is_empty():
			return PackedVector2Array()
		var joined := _cell_polygon(shape_cells[0])
		for i in range(1, shape_cells.size()):
			var merged: Array[PackedVector2Array] = Geometry2D.merge_polygons(joined, _cell_polygon(shape_cells[i]))
			joined = _largest_polygon(merged)
		return joined

	func _inset(polygon: PackedVector2Array, amount: float) -> PackedVector2Array:
		var result: Array[PackedVector2Array] = Geometry2D.offset_polygon(polygon, -amount, Geometry2D.JOIN_ROUND)
		return _largest_polygon(result)

	func _shifted(polygon: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
		var result := PackedVector2Array()
		for point in polygon:
			result.append(point + offset)
		return result

	func _draw() -> void:
		var cell_size := G.CELL
		var inner := Color("#172246")
		var inner_light := edge_color.darkened(0.48).lerp(Color("#34477b"), 0.55)
		var rim_dark := edge_color.darkened(0.4)
		var shine := edge_color.lightened(0.42)
		var shadow_col := Color(0.04, 0.05, 0.14, 0.38)
		var joined := _joined_polygon()
		var outer := _inset(joined, 2.0)
		var body := _inset(joined, 6.0)
		var body_glass := _inset(joined, 8.5)
		var pit_border := _inset(joined, 11.0)
		var pit := _inset(joined, 16.0)
		if outer.is_empty() or body.is_empty() or body_glass.is_empty() or pit_border.is_empty() or pit.is_empty():
			return

		# 통합된 폴리곤을 겹쳐 그려 셀 경계가 전혀 없는 단일 블록을 만든다.
		# 두 겹의 부드러운 그림자로 보드 위에서 살짝 떠 있는 깊이를 준다.
		var glow := Color(edge_color.r, edge_color.g, edge_color.b, 0.18)
		draw_colored_polygon(_shifted(outer, Vector2(0, 3)), glow)
		draw_colored_polygon(_shifted(outer, Vector2(5, 10)), Color(0.04, 0.05, 0.14, 0.22))
		draw_polyline(PackedVector2Array(_shifted(outer, Vector2(5, 10)) + PackedVector2Array([outer[0] + Vector2(5, 10)])), shadow_col, 7.0, true)
		draw_colored_polygon(outer, rim_dark)
		draw_colored_polygon(body, edge_color)
		# 반투명 젤리 프레임의 안쪽 산란광. 외곽색과 흰빛을 섞어 단색 띠를 피한다.
		draw_colored_polygon(body_glass, edge_color.lightened(0.16))
		draw_colored_polygon(pit_border, inner_light)
		draw_colored_polygon(pit, inner)
		draw_polyline(PackedVector2Array(outer + PackedVector2Array([outer[0]])), rim_dark, 3.0, true)
		draw_polyline(PackedVector2Array(body_glass + PackedVector2Array([body_glass[0]])), Color(1, 1, 1, 0.38), 2.0, true)
		draw_polyline(PackedVector2Array(pit + PackedVector2Array([pit[0]])), Color(0.64, 0.72, 1.0, 0.32), 3.0, true)

		# 외곽에 노출된 윗면 광택은 연속 구간마다 한 줄로 그려 다칸 블록도 하나처럼 보이게 한다.
		var exposed_rows := {}
		for off in shape_cells:
			if not shape_cells.has(off + Vector2i.UP):
				var xs: Array = exposed_rows.get(off.y, [])
				xs.append(off.x)
				exposed_rows[off.y] = xs
		for y_key in exposed_rows:
			var xs: Array = exposed_rows[y_key]
			xs.sort()
			var run_start: int = int(xs[0])
			var run_end: int = run_start
			for i in range(1, xs.size() + 1):
				var continues := i < xs.size() and int(xs[i]) == run_end + 1
				if continues:
					run_end = int(xs[i])
					continue
				var y := float(int(y_key)) * cell_size + 7.0
				var start := Vector2(float(run_start) * cell_size + 14.0, y)
				var finish := Vector2(float(run_end + 1) * cell_size - 14.0, y)
				draw_line(start, finish, shine, 5.0, true)
				draw_line(start + Vector2(5, 4), finish - Vector2(5, -4), Color(1, 1, 1, 0.24), 2.0, true)
				if i < xs.size():
					run_start = int(xs[i])
					run_end = run_start
		# 첫 칸에 작은 표정을 넣어 단순 도형이 아니라 살아 있는 몬스터 홀로 보이게 한다.
		if not shape_cells.is_empty():
			var face := Vector2(shape_cells[0]) * cell_size + Vector2(cell_size * 0.5, cell_size * 0.52)
			draw_circle(face + Vector2(-22, 9), 7.0, Color(1.0, 0.42, 0.58, 0.42))
			draw_circle(face + Vector2(22, 9), 7.0, Color(1.0, 0.42, 0.58, 0.42))
			draw_circle(face + Vector2(-13, -4), 9.5, Color("#f8fbff"))
			draw_circle(face + Vector2(13, -4), 9.5, Color("#f8fbff"))
			draw_circle(face + Vector2(-11, -3), 3.8, Color("#25304b"))
			draw_circle(face + Vector2(11, -3), 3.8, Color("#25304b"))
			draw_circle(face + Vector2(-15, -7), 2.1, Color.WHITE)
			draw_circle(face + Vector2(9, -7), 2.1, Color.WHITE)
			draw_arc(face + Vector2(0, 8), 8.0, 0.15, PI - 0.15, 14, Color("#ff8fa3"), 4.0, true)
			# 젤리 표면의 작은 스펙큘러가 얼굴과 재질을 한 층 더 분리한다.
			draw_circle(face + Vector2(-27, -25), 4.0, Color(1, 1, 1, 0.7))
