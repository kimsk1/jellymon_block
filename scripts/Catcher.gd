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
var base_scale := 1.0
var phase := 0.0
var sprite: Sprite2D
var visual_root: Node2D
var bbox_size := Vector2.ONE
var capacity := 1
var remaining_capacity := 1
var completed := false
var arrival_pending := false
var movement_locked := false
var count_badge: Label
var badge_panel: PanelContainer
var badge_style: StyleBoxFlat


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
	badge_panel.position = bbox * G.CELL - Vector2(49, 50)
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
	## 오목한 L/T 블록에서는 배지가 실제 점유 셀 밖에 걸칠 수 있으므로 별도 히트 영역으로 처리한다.
	return badge_panel != null and badge_panel.get_global_rect().grow(8.0).has_point(screen_point)


func center_px() -> Vector2:
	return global_position + bbox_size * G.CELL * 0.5


func mouth_px(cell_world: Vector2) -> Vector2:
	## 흡수 연출 목적지: 해당 셀 위 캐처 구멍 중심
	return cell_world


func set_grabbed(g: bool) -> void:
	grabbed = g
	visual_root.modulate = Color(1.18, 1.18, 1.18) if g else Color.WHITE


func _process(delta: float) -> void:
	position = position.move_toward(slide_target, 2400.0 * delta)
	var k := 0.04 if grabbed else 0.02
	var s := sin(Time.get_ticks_msec() / 1000.0 * 2.2 + phase)
	if sprite:
		sprite.scale = Vector2(base_scale * (1.0 + k * s), base_scale * (1.0 - k * s))
	else:
		visual_root.scale = Vector2(1.0 + k * s, 1.0 - k * s)


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
	visual_root.modulate = Color(1.14, 1.14, 1.2) if completed else Color.WHITE
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
		var inner := Color("#11162e")
		var inner_light := Color("#252752")
		var rim_dark := edge_color.darkened(0.35)
		var shine := edge_color.lightened(0.42)
		var shadow_col := Color(0.04, 0.05, 0.14, 0.38)
		var joined := _joined_polygon()
		var outer := _inset(joined, 2.0)
		var body := _inset(joined, 6.0)
		var pit_border := _inset(joined, 11.0)
		var pit := _inset(joined, 16.0)
		if outer.is_empty() or body.is_empty() or pit_border.is_empty() or pit.is_empty():
			return

		# 통합된 폴리곤을 겹쳐 그려 셀 경계가 전혀 없는 단일 블록을 만든다.
		# 두 겹의 부드러운 그림자로 보드 위에서 살짝 떠 있는 깊이를 준다.
		draw_colored_polygon(_shifted(outer, Vector2(5, 10)), Color(0.04, 0.05, 0.14, 0.18))
		draw_polyline(PackedVector2Array(_shifted(outer, Vector2(5, 10)) + PackedVector2Array([outer[0] + Vector2(5, 10)])), shadow_col, 7.0, true)
		draw_colored_polygon(outer, rim_dark)
		draw_colored_polygon(body, edge_color)
		draw_colored_polygon(pit_border, inner_light)
		draw_colored_polygon(pit, inner)
		draw_polyline(PackedVector2Array(outer + PackedVector2Array([outer[0]])), rim_dark, 3.0, true)
		draw_polyline(PackedVector2Array(pit + PackedVector2Array([pit[0]])), Color(0.42, 0.48, 0.75, 0.24), 2.0, true)

		# 외곽에 노출된 윗면에만 광택을 넣는다.
		for off in shape_cells:
			if not shape_cells.has(off + Vector2i.UP):
				var p := Vector2(off) * cell_size
				draw_line(p + Vector2(14, 7), p + Vector2(cell_size - 14, 7), shine, 4.0, true)
		# 첫 칸에 작은 표정을 넣어 단순 도형이 아니라 살아 있는 몬스터 홀로 보이게 한다.
		if not shape_cells.is_empty():
			var face := Vector2(shape_cells[0]) * cell_size + Vector2(cell_size * 0.5, cell_size * 0.52)
			draw_circle(face + Vector2(-13, -4), 8.5, Color("#f8fbff"))
			draw_circle(face + Vector2(13, -4), 8.5, Color("#f8fbff"))
			draw_circle(face + Vector2(-11, -3), 3.8, Color("#25304b"))
			draw_circle(face + Vector2(11, -3), 3.8, Color("#25304b"))
			draw_arc(face + Vector2(0, 8), 8.0, 0.15, PI - 0.15, 14, Color("#ff8fa3"), 4.0, true)
