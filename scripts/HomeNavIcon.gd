extends Control
class_name HomeNavIcon
## 홈 하단 메뉴에서 사용하는 코드 기반 전용 아이콘.
## 폰트 기호에 의존하지 않아 Android/iOS에서도 같은 모양으로 보인다.

var kind := "adventure"
var ink := Color.WHITE


func setup(icon_kind: String, color: Color = Color.WHITE) -> void:
	kind = icon_kind
	ink = color
	custom_minimum_size = Vector2(46, 46)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var c := Vector2(23, 23)
	match kind:
		"adventure":
			# 둥근 지도 핀과 그 안의 발바닥으로 '구조 모험'을 표현한다.
			draw_circle(c, 16, Color(1, 1, 1, 0.14))
			draw_arc(c, 15, 0, TAU, 28, ink, 3.2, true)
			draw_circle(c + Vector2(0, 5), 6, ink)
			for p in [Vector2(-8, -4), Vector2(-3, -9), Vector2(3, -9), Vector2(8, -4)]:
				draw_circle(c + p, 3.2, ink)
		"decorate":
			# 소파 실루엣.
			draw_style_box(_round_box(Color(1, 1, 1, 0.14), ink, 7, 3), Rect2(7, 17, 32, 19))
			draw_line(Vector2(12, 17), Vector2(12, 10), ink, 4, true)
			draw_line(Vector2(34, 17), Vector2(34, 10), ink, 4, true)
			draw_arc(Vector2(23, 14), 11, PI, TAU, 16, ink, 3, true)
			draw_line(Vector2(12, 36), Vector2(10, 41), ink, 3, true)
			draw_line(Vector2(34, 36), Vector2(36, 41), ink, 3, true)
		"shop":
			# 젤리 별이 담긴 쇼핑백.
			draw_style_box(_round_box(Color(1, 1, 1, 0.14), ink, 7, 3), Rect2(8, 16, 30, 25))
			draw_arc(Vector2(23, 17), 9, PI, TAU, 16, ink, 3, true)
			var star := PackedVector2Array()
			for i in range(10):
				var radius := 7.0 if i % 2 == 0 else 3.2
				var angle := -PI / 2.0 + i * PI / 5.0
				star.append(Vector2(23, 29) + Vector2(cos(angle), sin(angle)) * radius)
			draw_colored_polygon(star, ink)
		"menu":
			for y in [13.0, 23.0, 33.0]:
				draw_circle(Vector2(11, y), 3, ink)
				draw_line(Vector2(18, y), Vector2(37, y), ink, 4, true)


func _round_box(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style
