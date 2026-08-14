extends Node2D
class_name JellyExpression
## 원본 캐릭터 아트를 훼손하지 않고 퍼즐 상태를 전달하는 표정 레이어.

var mood := "wild"
var accent := Color.WHITE


func setup(color: Color) -> void:
	accent = color
	z_index = 8
	queue_redraw()


func set_mood(value: String) -> void:
	mood = value
	queue_redraw()


func _draw() -> void:
	match mood:
		"wild":
			draw_line(Vector2(-18, -13), Vector2(-6, -9), Color("#45233f"), 3.2, true)
			draw_line(Vector2(18, -13), Vector2(6, -9), Color("#45233f"), 3.2, true)
		"panic":
			draw_arc(Vector2.ZERO, 32, -PI * 0.85, -PI * 0.15, 16, Color(1, 1, 1, 0.82), 3, true)
			draw_string(ThemeDB.fallback_font, Vector2(21, -20), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#fff1a6"))
		"purified":
			var heart := PackedVector2Array([Vector2(0, 9), Vector2(-13, -4), Vector2(-10, -13), Vector2(0, -8), Vector2(10, -13), Vector2(13, -4)])
			draw_colored_polygon(heart, Color("#fff4f7"))
			draw_arc(Vector2.ZERO, 34, 0, TAU, 24, Color(accent, 0.55), 3, true)
