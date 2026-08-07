class_name G
## 전역 상수/유틸

const CELL := 84.0
const W := 720.0
const H := 1280.0

const COLORS := {
	"R": Color(1.0, 0.353, 0.431),
	"Y": Color(1.0, 0.788, 0.235),
	"B": Color(0.31, 0.659, 1.0),
	"G": Color(0.341, 0.839, 0.42),
	"P": Color(0.69, 0.424, 0.941),
	"O": Color(1.0, 0.604, 0.235),
}

const COLOR_NAMES := {"R": "빨강", "Y": "노랑", "B": "파랑", "G": "초록", "P": "보라", "O": "주황"}

const INK := Color(0.24, 0.14, 0.28)

## 폴리오미노 블록 모양 (빠지냥식 다양한 모양의 젤리 블록)
const SHAPES := {
	"S1": [Vector2i(0, 0)],
	"H2": [Vector2i(0, 0), Vector2i(1, 0)],
	"V2": [Vector2i(0, 0), Vector2i(0, 1)],
	"H3": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	"V3": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],
	"H4": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
	"V4": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)],
	"SQ": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	"LA": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
	"LB": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
	"L4A": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)],
	"L4B": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 2)],
	"L4C": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	"L4D": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)],
	"TU": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
	"TD": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	"TL": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
	"TR": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)],
	"SH": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
	"ZH": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
	"SV": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
	"ZV": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)],
}


static func jelly_tex(c: String) -> Texture2D:
	return load("res://assets/jelly_%s.png" % c)


static func catcher_tex(shape: String, c: String) -> Texture2D:
	return load("res://assets/catchers/%s_%s.png" % [shape, c])


static func haptic(ms: int) -> void:
	Input.vibrate_handheld(ms)
