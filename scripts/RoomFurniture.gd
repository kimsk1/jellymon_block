extends Node2D
class_name RoomFurniture
## 실제 가구 형태의 2D 그림. 배치·충돌은 기존 폴리오미노 좌표를 유지한다.

const FurnitureArtLib = preload("res://scripts/FurnitureArt.gd")
var item: Dictionary
var cells: Array[Vector2i] = []
var selected := false
var animation_time := 0.0
var art: Texture2D
var rotation_turns := 0

func setup(p_item: Dictionary, placement: Dictionary, p_selected: bool) -> void:
	item = p_item
	selected = p_selected
	rotation_turns = posmod(int(placement.get("rotation", 0)), 4)
	cells = RoomData.rotated_cells(String(item.shape), rotation_turns)
	position = RoomData.ORIGIN + Vector2(int(placement.x), int(placement.y)) * RoomData.CELL
	art = FurnitureArtLib.texture(String(item.id))
	set_process(bool(item.get("animated", false)))
	queue_redraw()

func _process(delta: float) -> void:
	animation_time += delta
	queue_redraw()

func play_reaction() -> void:
	if not bool(item.get("animated", false)):
		return
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.04, 0.98), 0.16).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BOUNCE)

func _bounds() -> Rect2:
	var max_cell := Vector2i.ZERO
	for cell in cells:
		max_cell.x = maxi(max_cell.x, cell.x + 1)
		max_cell.y = maxi(max_cell.y, cell.y + 1)
	return Rect2(Vector2.ZERO, Vector2(max_cell) * RoomData.CELL)

func interaction_point() -> Vector2:
	return position + _bounds().get_center()

func art_bounds() -> Rect2:
	var bounds := _bounds().grow(-4)
	if art == null:
		return bounds
	# 회전은 점유 칸을 바꾼다. 정면 가구 그림을 눕히거나 늘이지 않는다.
	var factor := minf(bounds.size.x / art.get_width(), bounds.size.y / art.get_height())
	var dimensions := art.get_size() * factor
	return Rect2(Vector2(bounds.get_center().x - dimensions.x * 0.5, bounds.end.y - dimensions.y), dimensions)

func _draw() -> void:
	if art:
		var rect := art_bounds()
		# 180도 방향은 좌우 반전으로 표현하며 높이·종횡비를 보존한다.
		if rotation_turns >= 2:
			rect.position.x += rect.size.x
			rect.size.x = -rect.size.x
		draw_texture_rect(art, rect, false)
		if bool(item.get("animated", false)):
			var center := art_bounds().get_center()
			for i in range(3):
				var angle := animation_time * 0.6 + TAU * float(i) / 3.0
				var point := center + Vector2(cos(angle), sin(angle)) * minf(_bounds().size.x, _bounds().size.y) * 0.33
				draw_circle(point, 1.6, Color(1.0, 0.9, 0.65, 0.35 + sin(animation_time * 2.0) * 0.15))
	if selected:
		# 선택 시 실제 점유 셀만 표시해 L/T형 가구의 빈 칸도 구분할 수 있다.
		for cell in cells:
			var rect := Rect2(Vector2(cell) * RoomData.CELL, Vector2.ONE * RoomData.CELL).grow(-2)
			draw_rect(rect, Color(0.49, 0.82, 0.76, 0.12), true)
			draw_rect(rect, Color("#fff0b0"), false, 2.0)
