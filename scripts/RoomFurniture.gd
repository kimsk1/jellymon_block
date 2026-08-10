extends Node2D
class_name RoomFurniture
## 폴리오미노 가구 하나. 선택·회전 상태까지 포함해 코드로 렌더링한다.

var item: Dictionary
var cells: Array[Vector2i] = []
var selected := false


func setup(p_item: Dictionary, placement: Dictionary, p_selected: bool) -> void:
	item = p_item
	selected = p_selected
	cells = RoomData.rotated_cells(String(item.shape), int(placement.get("rotation", 0)))
	position = RoomData.ORIGIN + Vector2(int(placement.x), int(placement.y)) * RoomData.CELL
	queue_redraw()


func _cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var p := Vector2(cell) * RoomData.CELL
	return PackedVector2Array([
		p,
		p + Vector2(RoomData.CELL, 0),
		p + Vector2(RoomData.CELL, RoomData.CELL),
		p + Vector2(0, RoomData.CELL),
	])


func _largest_polygon(polygons: Array[PackedVector2Array]) -> PackedVector2Array:
	if polygons.is_empty():
		return PackedVector2Array()
	var best: PackedVector2Array = polygons[0]
	var best_area := 0.0
	for polygon in polygons:
		var rect := Rect2(polygon[0], Vector2.ZERO)
		for point in polygon:
			rect = rect.expand(point)
		var area := rect.size.x * rect.size.y
		if area > best_area:
			best = polygon
			best_area = area
	return best


func _joined_polygon() -> PackedVector2Array:
	if cells.is_empty():
		return PackedVector2Array()
	var joined := _cell_polygon(cells[0])
	for i in range(1, cells.size()):
		var merged: Array[PackedVector2Array] = Geometry2D.merge_polygons(joined, _cell_polygon(cells[i]))
		joined = _largest_polygon(merged)
	return joined


func _inset(polygon: PackedVector2Array, amount: float) -> PackedVector2Array:
	return _largest_polygon(Geometry2D.offset_polygon(polygon, -amount, Geometry2D.JOIN_ROUND))


func _rounded_inset(polygon: PackedVector2Array, radius: float, final_inset: float) -> PackedVector2Array:
	## 한 번 안으로 줄인 뒤 둥근 조인으로 다시 넓혀 실제 곡률이 있는 외곽 모서리를 만든다.
	var core := _largest_polygon(Geometry2D.offset_polygon(polygon, -radius, Geometry2D.JOIN_ROUND))
	if core.is_empty():
		return _inset(polygon, final_inset)
	return _largest_polygon(Geometry2D.offset_polygon(core, radius - final_inset, Geometry2D.JOIN_ROUND))


func _shifted(polygon: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in polygon:
		result.append(point + offset)
	return result


func _bounds() -> Rect2:
	var max_cell := Vector2i.ZERO
	for cell in cells:
		max_cell.x = maxi(max_cell.x, cell.x + 1)
		max_cell.y = maxi(max_cell.y, cell.y + 1)
	return Rect2(Vector2.ZERO, Vector2(max_cell) * RoomData.CELL)


func _round_box(rect: Rect2, fill: Color, border: Color, radius: float = 16.0, width: int = 3, shadow := true) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(int(radius))
	style.corner_detail = 10
	if shadow:
		style.shadow_color = Color(0.12, 0.07, 0.18, 0.28)
		style.shadow_size = 5
		style.shadow_offset = Vector2(0, 5)
	draw_style_box(style, rect)


func _draw_selection(bounds: Rect2) -> void:
	if not selected:
		return
	_round_box(bounds.grow(-2), Color(0.55, 0.85, 1.0, 0.2), Color.WHITE, 20, 4, false)


func _draw_cushion(bounds: Rect2, color: Color) -> void:
	var body := Rect2(bounds.position + Vector2(7, 10), bounds.size - Vector2(14, 18))
	draw_circle(body.get_center() + Vector2(2, 6), body.size.x * 0.42, Color(0.15, 0.07, 0.18, 0.2))
	_round_box(body, color.lightened(0.07), color.darkened(0.3), 24, 4)
	draw_arc(body.get_center(), body.size.x * 0.31, 0.2, PI - 0.2, 22, Color(1, 1, 1, 0.45), 3, true)
	var font := ThemeDB.fallback_font
	draw_string(font, body.get_center() + Vector2(-13, 12), "♥", HORIZONTAL_ALIGNMENT_CENTER, 28, 25, Color("#fff8f0"))
	for corner in [body.position + Vector2(9, 9), Vector2(body.end.x - 9, body.position.y + 9), Vector2(body.position.x + 9, body.end.y - 9), body.end - Vector2(9, 9)]:
		draw_circle(corner, 2.2, color.darkened(0.18))


func _draw_lamp(bounds: Rect2, color: Color) -> void:
	var center_x := bounds.get_center().x
	var glow_center := Vector2(center_x, bounds.position.y + minf(42.0, bounds.size.y * 0.3))
	draw_circle(glow_center, 34, Color(1.0, 0.83, 0.26, 0.13))
	draw_line(Vector2(center_x, bounds.position.y + 43), Vector2(center_x, bounds.end.y - 24), color.darkened(0.36), 8, true)
	draw_line(Vector2(center_x - 3, bounds.position.y + 45), Vector2(center_x - 3, bounds.end.y - 27), Color(1, 1, 1, 0.32), 2, true)
	var shade := PackedVector2Array([
		Vector2(center_x - 27, bounds.position.y + 40), Vector2(center_x - 18, bounds.position.y + 10),
		Vector2(center_x + 18, bounds.position.y + 10), Vector2(center_x + 27, bounds.position.y + 40),
	])
	draw_colored_polygon(shade, color.lightened(0.08))
	draw_polyline(PackedVector2Array(shade + PackedVector2Array([shade[0]])), color.darkened(0.28), 4, true)
	_round_box(Rect2(center_x - 27, bounds.end.y - 28, 54, 21), color, color.darkened(0.32), 11, 4)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(center_x - 12, bounds.position.y + 36), "★", HORIZONTAL_ALIGNMENT_CENTER, 25, 22, Color.WHITE)


func _draw_table(bounds: Rect2, color: Color) -> void:
	var top := Rect2(bounds.position + Vector2(5, 12), Vector2(bounds.size.x - 10, minf(45, bounds.size.y * 0.62)))
	draw_line(Vector2(top.position.x + 24, top.end.y - 2), Vector2(top.position.x + 19, bounds.end.y - 5), color.darkened(0.36), 10, true)
	draw_line(Vector2(top.end.x - 24, top.end.y - 2), Vector2(top.end.x - 19, bounds.end.y - 5), color.darkened(0.36), 10, true)
	_round_box(top, color.lightened(0.08), color.darkened(0.31), 22, 4)
	draw_line(top.position + Vector2(18, 10), Vector2(top.end.x - 18, top.position.y + 10), Color(1, 1, 1, 0.42), 4, true)
	draw_circle(top.get_center() + Vector2(-18, 4), 8, Color("#e7f8ff"))
	draw_circle(top.get_center() + Vector2(7, -2), 5, Color(1, 1, 1, 0.62))
	draw_circle(top.get_center() + Vector2(25, 7), 3, Color(1, 1, 1, 0.48))


func _draw_shelf(bounds: Rect2, color: Color) -> void:
	var frame := Rect2(bounds.position + Vector2(4, 8), bounds.size - Vector2(8, 14))
	_round_box(frame, color.darkened(0.18), color.darkened(0.38), 15, 4)
	var inner := frame.grow(-8)
	_round_box(inner, Color("#fff2cf"), color.darkened(0.25), 9, 3, false)
	var sections := maxi(1, cells.size())
	var section_w := inner.size.x / float(sections)
	for i in range(1, sections):
		draw_line(Vector2(inner.position.x + section_w * i, inner.position.y + 3), Vector2(inner.position.x + section_w * i, inner.end.y - 3), color.darkened(0.22), 4, true)
	for i in range(sections):
		var base_x := inner.position.x + section_w * i
		if i % 3 == 0:
			draw_rect(Rect2(base_x + 11, inner.end.y - 24, 8, 19), Color("#ff8a75"), true)
			draw_rect(Rect2(base_x + 21, inner.end.y - 29, 7, 24), Color("#6e9ee8"), true)
		else:
			draw_circle(Vector2(base_x + section_w * 0.5, inner.position.y + 21), 10, Color("#69c977"))
			draw_rect(Rect2(base_x + section_w * 0.5 - 8, inner.position.y + 29, 16, 11), Color("#e59856"), true)


func _draw_rug(bounds: Rect2, color: Color) -> void:
	var rug := bounds.grow(-7)
	_round_box(rug, Color(color.r, color.g, color.b, 0.78), color.darkened(0.24), 28, 3)
	draw_arc(rug.get_center(), minf(rug.size.x, rug.size.y) * 0.3, 0, TAU, 30, Color(1, 1, 1, 0.4), 3, true)


func _draw_plant(bounds: Rect2, color: Color) -> void:
	var c := bounds.get_center()
	draw_circle(c + Vector2(-11, -11), 15, color.lightened(0.1))
	draw_circle(c + Vector2(10, -15), 17, color)
	draw_circle(c + Vector2(1, -27), 14, color.lightened(0.2))
	var pot := PackedVector2Array([c + Vector2(-20, 2), c + Vector2(20, 2), c + Vector2(14, 30), c + Vector2(-14, 30)])
	draw_colored_polygon(pot, Color("#f39b64"))
	draw_polyline(PackedVector2Array(pot + PackedVector2Array([pot[0]])), Color("#a65e42"), 4, true)


func _draw_soft_furniture(bounds: Rect2, color: Color) -> void:
	var seat := Rect2(bounds.position + Vector2(7, bounds.size.y * 0.34), Vector2(bounds.size.x - 14, bounds.size.y * 0.52))
	_round_box(seat, color, color.darkened(0.34), 23, 4)
	var back := Rect2(bounds.position + Vector2(12, 8), Vector2(bounds.size.x - 24, bounds.size.y * 0.48))
	_round_box(back, color.lightened(0.08), color.darkened(0.3), 22, 4)
	draw_line(Vector2(bounds.get_center().x, back.position.y + 8), Vector2(bounds.get_center().x, back.end.y - 7), Color(1, 1, 1, 0.24), 3, true)


func _draw_candy_furniture(_bounds_rect: Rect2, color: Color) -> void:
	var joined := _joined_polygon()
	var outer := _rounded_inset(joined, 17.0, 3.0)
	var body := _rounded_inset(joined, 19.0, 9.0)
	if outer.is_empty() or body.is_empty():
		return
	draw_colored_polygon(_shifted(outer, Vector2(5, 8)), Color(0.1, 0.05, 0.18, 0.28))
	draw_colored_polygon(outer, color.darkened(0.34))
	draw_colored_polygon(body, color.lightened(0.04))
	# 손잡이·쿠션 단추를 추가해 단순 퍼즐 블록보다 실제 수납 가구처럼 보이게 한다.
	for cell in cells:
		var center := Vector2(cell) * RoomData.CELL + Vector2.ONE * RoomData.CELL * 0.5
		draw_circle(center, 5, Color(1, 1, 1, 0.78))
		draw_arc(center, 13, PI * 0.12, PI * 0.88, 12, Color(1, 1, 1, 0.22), 2, true)


func _draw() -> void:
	var source := Color(String(item.color))
	var color := Color.from_hsv(source.h, minf(1.0, source.s * 1.38 + 0.06), maxf(0.72, source.v * 0.91), 1.0)
	var bounds := _bounds()
	var id := String(item.id)
	match id:
		"cushion_r", "ach_first", "ach_3x10": _draw_cushion(bounds, color)
		"lamp_y": _draw_lamp(bounds, color)
		"table_b": _draw_table(bounds, color)
		"shelf_g", "ach_15": _draw_shelf(bounds, color)
		"rug_r": _draw_rug(bounds, color)
		"plant_g": _draw_plant(bounds, color)
		"bench_o", "bed_r": _draw_soft_furniture(bounds, color)
		_: _draw_candy_furniture(bounds, color)
	_draw_selection(bounds)
