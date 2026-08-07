extends Control
class_name RoomBackdrop
## 아지트의 벽·바닥·편집 격자를 직접 그리는 배경.

var edit_mode := false
var photo_mode := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(queue_redraw)


func set_edit_mode(value: bool) -> void:
	edit_mode = value
	queue_redraw()


func set_photo_mode(value: bool) -> void:
	photo_mode = value
	queue_redraw()


func _draw() -> void:
	# 바깥 하늘과 방 카드
	var viewport_size := get_viewport_rect().size
	var extra_offset := G.safe_offset(viewport_size)
	# 부모 Title이 안전 영역만큼 이동하므로 음수 방향부터 실제 뷰포트 끝까지 칠한다.
	draw_rect(Rect2(-extra_offset, viewport_size), Color("#d2c0f0"))
	# 단색 캔버스가 아니라 중앙이 환해지는 층을 겹쳐 아지트에 깊이를 준다.
	draw_circle(Vector2(360, 560), 430, Color(0.93, 0.86, 1.0, 0.24))
	draw_circle(Vector2(105, 1080), 230, Color(0.58, 0.39, 0.82, 0.09))
	draw_circle(Vector2(660, 1020), 260, Color(1.0, 0.45, 0.68, 0.08))
	for i in range(10):
		var p := Vector2(42 + (i * 83) % 660, 145 + (i % 3) * 54)
		draw_circle(p, 22 + (i % 4) * 7, Color(1, 1, 1, 0.2))
	for p in [Vector2(54, 306), Vector2(686, 335), Vector2(70, 930), Vector2(650, 962)]:
		draw_line(p - Vector2(8, 0), p + Vector2(8, 0), Color(1, 1, 1, 0.48), 3, true)
		draw_line(p - Vector2(0, 8), p + Vector2(0, 8), Color(1, 1, 1, 0.48), 3, true)
	# 촬영 모드에서는 상·하단 여백이 균형을 이루도록 방 전체를 세로 중앙에 배치한다.
	draw_set_transform(Vector2(0, 142 if photo_mode else RoomData.SCREEN_Y_OFFSET))
	var room := Rect2(28, 138, G.W - 56, 720)
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0.18, 0.12, 0.31, 0.2)
	shadow.set_corner_radius_all(38)
	draw_style_box(shadow, Rect2(room.position + Vector2(0, 12), room.size))
	var wall := StyleBoxFlat.new()
	wall.bg_color = Color("#fff0f7")
	wall.border_color = Color("#8061aa")
	wall.set_border_width_all(5)
	wall.set_corner_radius_all(38)
	draw_style_box(wall, room)
	# 패널 안쪽의 얇은 광택선으로 플라스틱 장난감 같은 마감을 만든다.
	draw_arc(Vector2(66, 176), 20, PI, PI * 1.5, 10, Color(1, 1, 1, 0.72), 3, true)
	draw_line(Vector2(88, 151), Vector2(628, 151), Color(1, 1, 1, 0.55), 3, true)
	# 벽지 무늬
	for y in range(190, 410, 60):
		for x in range(75, 650, 74):
			var stagger := 22 if int(y / 60) % 2 else 0
			var large_dot := Vector2(x + stagger, y)
			var small_dot := Vector2(x + 9 + stagger, y - 6)
			# 둥근 패널의 안쪽 안전 영역을 벗어나는 마지막 무늬 열은 그리지 않는다.
			if large_dot.x <= 656:
				draw_circle(large_dot, 5, Color("#d9b5e3"))
			if small_dot.x <= 662:
				draw_circle(small_dot, 3, Color("#ed9fbd"))
	# 둥근 창문
	var window_rect := Rect2(260, 175, 200, 128)
	var window_style := StyleBoxFlat.new()
	window_style.bg_color = Color("#9edbfa")
	window_style.border_color = Color("#6c91bf")
	window_style.set_border_width_all(8)
	window_style.set_corner_radius_all(42)
	draw_style_box(window_style, window_rect)
	var window_inner := StyleBoxFlat.new()
	window_inner.bg_color = Color(0.45, 0.72, 0.95, 0.18)
	window_inner.border_color = Color(1, 1, 1, 0.5)
	window_inner.set_border_width_all(3)
	window_inner.set_corner_radius_all(34)
	draw_style_box(window_inner, window_rect.grow(-11))
	draw_circle(Vector2(310, 218), 22, Color(1, 1, 1, 0.75))
	draw_circle(Vector2(345, 218), 29, Color(1, 1, 1, 0.75))
	draw_circle(Vector2(380, 220), 20, Color(1, 1, 1, 0.75))
	draw_line(Vector2(360, 180), Vector2(360, 298), Color("#6c91bf"), 7)
	# 창틀 받침과 작은 반사광
	draw_line(Vector2(278, 306), Vector2(442, 306), Color("#5679aa"), 9, true)
	draw_line(Vector2(289, 302), Vector2(431, 302), Color("#d8f3ff"), 3, true)
	# 바닥과 러그 영역
	var floor_style := StyleBoxFlat.new()
	floor_style.bg_color = Color("#e9c39d")
	floor_style.corner_radius_bottom_left = 34
	floor_style.corner_radius_bottom_right = 34
	draw_style_box(floor_style, Rect2(33, 365, 654, 488))
	draw_line(Vector2(34, 365), Vector2(686, 365), Color("#b88472"), 4.0, true)
	for y in range(405, 850, 52):
		draw_line(Vector2(38, y), Vector2(682, y), Color(0.65, 0.45, 0.38, 0.13), 2)
	for x in range(62, 680, 92):
		draw_line(Vector2(x, 367), Vector2(x - 45, 850), Color(0.65, 0.45, 0.38, 0.1), 2)
	# 주인공을 받쳐주는 젤리 모양 러그. 가구보다 뒤에 있어 화면 중심을 자연스럽게 묶는다.
	draw_circle(Vector2(360, 676), 132, Color(0.5, 0.28, 0.7, 0.09))
	draw_circle(Vector2(360, 668), 118, Color(1.0, 0.72, 0.84, 0.2))
	draw_arc(Vector2(360, 668), 118, PI * 0.1, PI * 0.9, 32, Color(1, 1, 1, 0.34), 4, true)
	# 편집 모드에서만 실제 배치 셀을 표시한다.
	if edit_mode:
		for y in range(RoomData.GRID_H):
			for x in range(RoomData.GRID_W):
				var rect := Rect2(RoomData.ORIGIN + Vector2(x, y) * RoomData.CELL, Vector2.ONE * RoomData.CELL)
				draw_rect(rect.grow(-3), Color(1, 1, 1, 0.16), true)
				draw_rect(rect.grow(-4), Color("#a884bb"), false, 2.0)
	draw_set_transform(Vector2.ZERO)
