extends Node2D
class_name Hole
## 색깔 구멍 — 같은 색 젤리 블록만 빠짐. 피버 중엔 무지개(모든 색 허용).

var color_id := "R"
var cell := Vector2i.ZERO
var game = null
var pit: Sprite2D
var rim: Sprite2D
var pat: Sprite2D
var _hue := 0.0
var _fever_vis := false

const TEX_SIZE := 128.0


func _ready() -> void:
	var sc := G.CELL / 114.0  # 림 외경(114px)이 셀 크기에 맞도록
	pit = Sprite2D.new()
	pit.texture = load("res://assets/holes/hole_pit.png")
	pit.scale = Vector2.ONE * sc
	add_child(pit)
	rim = Sprite2D.new()
	rim.texture = load("res://assets/holes/hole_rim.png")
	rim.scale = Vector2.ONE * sc
	rim.modulate = G.COLORS[color_id]
	add_child(rim)
	pat = Sprite2D.new()
	pat.texture = load("res://assets/holes/pat_%s.png" % color_id)
	pat.scale = Vector2.ONE * sc * 0.9
	pat.modulate = Color(1, 1, 1, 0.45)
	add_child(pat)


func _process(delta: float) -> void:
	if game and game.fever_time > 0.0:
		_fever_vis = true
		_hue = fmod(_hue + delta * 1.2, 1.0)
		rim.modulate = Color.from_hsv(_hue, 0.7, 1.0)
	elif _fever_vis:
		_fever_vis = false
		rim.modulate = G.COLORS[color_id]


func gulp() -> void:
	## 꿀꺽 연출
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.24, 1.24), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
