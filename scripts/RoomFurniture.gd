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


func _draw() -> void:
	var source := Color(String(item.color))
	# 기존 파스텔 팔레트의 색상 정체성은 유지하면서 채도와 대비를 높인다.
	var color := Color.from_hsv(source.h, minf(1.0, source.s * 1.38 + 0.06), maxf(0.72, source.v * 0.91), 1.0)
	var dark := color.darkened(0.36)
	var light := color.lightened(0.3)
	var joined := _joined_polygon()
	var outer := _rounded_inset(joined, 17.0, 3.0)
	var body := _rounded_inset(joined, 19.0, 9.0)
	var inner := _rounded_inset(joined, 21.0, 14.0)
	if outer.is_empty() or body.is_empty() or inner.is_empty():
		return
	# 셀별 도형이 아니라 합쳐진 단일 윤곽에 그림자·테두리·몸체를 한 번씩만 그린다.
	draw_colored_polygon(_shifted(outer, Vector2(5, 8)), Color(0.1, 0.05, 0.18, 0.32))
	draw_colored_polygon(outer, Color.WHITE if selected else dark)
	draw_colored_polygon(body, color)
	# 안쪽 면을 한 겹 더 깔아 단색 판처럼 보이지 않는 캔디 베벨을 만든다.
	draw_colored_polygon(inner, color.lightened(0.055))
	draw_polyline(PackedVector2Array(outer + PackedVector2Array([outer[0]])), Color.WHITE if selected else dark, 3.0 if selected else 2.0, true)
	draw_polyline(PackedVector2Array(inner + PackedVector2Array([inner[0]])), Color(1, 1, 1, 0.18), 2.0, true)
	# 연속된 윗면은 셀마다 끊지 않고 하나의 광택선으로 연결한다.
	# 시작·끝에만 1칸 가구와 동일한 16px 여백을 적용한다.
	var exposed_rows := {}
	for cell in cells:
		if not cells.has(cell + Vector2i.UP):
			var xs: Array = exposed_rows.get(cell.y, [])
			xs.append(cell.x)
			exposed_rows[cell.y] = xs
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
			var line_y := float(int(y_key)) * RoomData.CELL + 10.0
			var line_start := Vector2(float(run_start) * RoomData.CELL + 16.0, line_y)
			var line_end := Vector2(float(run_end + 1) * RoomData.CELL - 16.0, line_y)
			draw_line(line_start, line_end, light, 5, true)
			draw_line(line_start + Vector2(4, 4), line_end - Vector2(4, -4), Color(1, 1, 1, 0.28), 2, true)
			if i < xs.size():
				run_start = int(xs[i])
				run_end = run_start
	var first := Vector2(cells[0]) * RoomData.CELL + Vector2.ONE * RoomData.CELL * 0.5
	var font := ThemeDB.fallback_font
	var mark := String(item.get("mark", "✦"))
	draw_string(font, first + Vector2(-18, 13), mark, HORIZONTAL_ALIGNMENT_CENTER, 36, 30, Color.WHITE)
