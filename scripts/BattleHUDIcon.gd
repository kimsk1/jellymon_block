extends Control
class_name BattleHUDIcon
## 전투 HUD용 해상도 독립 아이콘. 폰트/이모지 렌더러 차이를 제거한다.

var kind := "home"


func setup(value: String) -> void:
	kind = value
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var ink := ArtDirection.ink()
	var shade := Color(0.35, 0.22, 0.12, 0.08)
	if kind == "pause":
		draw_style_box(_box(shade, 4), Rect2(center + Vector2(-16, -20), Vector2(11, 43)))
		draw_style_box(_box(shade, 4), Rect2(center + Vector2(7, -20), Vector2(11, 43)))
		draw_style_box(_box(ink, 4), Rect2(center + Vector2(-18, -22), Vector2(11, 43)))
		draw_style_box(_box(ink, 4), Rect2(center + Vector2(5, -22), Vector2(11, 43)))
	elif kind == "home":
		var roof := PackedVector2Array([
			center + Vector2(-22, -3), center + Vector2(0, -22), center + Vector2(22, -3),
			center + Vector2(17, 2), center, center + Vector2(-17, 2),
		])
		var roof_shadow := PackedVector2Array()
		for point in roof:
			roof_shadow.append(point + Vector2(0, 3))
		draw_colored_polygon(roof_shadow, shade)
		draw_colored_polygon(roof, ink)
		draw_style_box(_box(ink, 6), Rect2(center + Vector2(-16, -1), Vector2(32, 25)))
		draw_rect(Rect2(center + Vector2(-5, 11), Vector2(10, 13)), ArtDirection.panel_color())
	else:
		draw_arc(center + Vector2(0, 2), 20, -PI * 0.15, PI * 1.48, 28, shade, 8, true)
		draw_arc(center, 20, -PI * 0.15, PI * 1.48, 28, ink, 6, true)
		var tip := center + Vector2(19, -8)
		var arrow := PackedVector2Array([tip + Vector2(-1, -10), tip + Vector2(10, 1), tip + Vector2(-5, 5)])
		draw_colored_polygon(arrow, ink)


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style
