extends Control
class_name RoomBackdrop
## 세 가지 빈 방 배경. 가구, 주민, 편집 격자는 별도 레이어다.

var edit_mode := false
var photo_mode := false
var restoration_level := 0
var room_theme_id := RoomData.DEFAULT_ROOM_THEME
var room_texture: Texture2D

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(queue_redraw)
	set_room_theme(room_theme_id)

func set_room_theme(id: String) -> void:
	var theme := RoomData.room_theme(id)
	room_theme_id = String(theme.id)
	room_texture = load(String(theme.asset)) as Texture2D
	queue_redraw()

func set_edit_mode(value: bool) -> void:
	edit_mode = value
	queue_redraw()

func set_photo_mode(value: bool) -> void:
	photo_mode = value
	queue_redraw()

func set_restoration_level(value: int) -> void:
	restoration_level = maxi(0, value)
	queue_redraw()

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	var extra_offset := G.safe_offset(viewport_size)
	var theme := RoomData.room_theme(room_theme_id)
	draw_rect(Rect2(-extra_offset, viewport_size), Color(String(theme.canvas)))
	draw_set_transform(Vector2(0, 142 if photo_mode else RoomData.SCREEN_Y_OFFSET))
	if room_texture:
		# Generated rooms have different wall proportions. Map both source regions to
		# one fixed seam above ORIGIN so existing furniture never lands on a wall.
		var texture_size := room_texture.get_size()
		var seam := texture_size.y * float(theme.wall_ratio)
		draw_texture_rect_region(room_texture, Rect2(0, 138, G.W, 252), Rect2(0, 0, texture_size.x, seam))
		draw_texture_rect_region(room_texture, Rect2(0, 390, G.W, 468), Rect2(0, seam, texture_size.x, texture_size.y - seam))
	if edit_mode:
		for y in range(RoomData.GRID_H):
			for x in range(RoomData.GRID_W):
				var rect := Rect2(RoomData.ORIGIN + Vector2(x, y) * RoomData.CELL, Vector2.ONE * RoomData.CELL)
				draw_rect(rect.grow(-3), Color(1, 1, 1, 0.16), true)
				draw_rect(rect.grow(-4), ArtDirection.muted_color(), false, 1.5)
	draw_set_transform(Vector2.ZERO)
