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
	# v6 원화의 얼굴을 다시 그리지 않고, 퍼즐 상태만 바깥 오라로 전달한다.
	# 덕분에 표정이 이중으로 겹치지 않고 고해상도 캐릭터 원화가 그대로 보인다.
	match mood:
		"wild":
			for angle in [-2.45, -0.7]:
				draw_arc(Vector2.ZERO, 38, angle, angle + 0.42, 9, Color(accent, 0.62), 2.6, true)
		"panic":
			draw_arc(Vector2.ZERO, 39, -PI * 0.88, -PI * 0.12, 18, Color(1, 1, 1, 0.86), 3, true)
			draw_string(ThemeDB.fallback_font, Vector2(21, -20), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#fff1a6"))
		"purified":
			draw_arc(Vector2.ZERO, 38, 0, TAU, 32, Color(accent, 0.7), 3.5, true)
			for angle in [-PI * 0.5, 0.15, PI * 0.8]:
				var p := Vector2.RIGHT.rotated(angle) * 42.0
				draw_circle(p, 3.2, Color("#fff8cf"))
