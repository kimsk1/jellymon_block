extends Node2D
class_name Jelly
## 젤리몬. 로직은 격자 기반, 시각은 스쿼시&스트레치 (02 문서 8.2)

var color_id := "R"
var cells: Array = []          # Vector2i 배열 (1x1=1칸, 2x1=2칸)
var big := false
var shiny := false
var absorbing := false
var base_scale := 1.0
var phase := 0.0
var refuse_cd := 0.0
var sprite: Sprite2D
var fx = null                  # FX 노드 (Game이 주입)


func setup(cid: String, p_cells: Array, p_big: bool, p_shiny: bool) -> void:
	color_id = cid
	cells = p_cells
	big = p_big
	shiny = p_shiny
	phase = randf() * TAU
	sprite = Sprite2D.new()
	sprite.texture = G.big_tex(cid) if big else G.jelly_tex(cid)
	var target_w := G.CELL * (1.9 if big else 0.94)
	base_scale = target_w / float(sprite.texture.get_width())
	sprite.scale = Vector2.ONE * base_scale
	add_child(sprite)
	if shiny:
		sprite.modulate = Color(1.35, 1.32, 1.05)
		var t := Timer.new()
		t.wait_time = 0.6
		t.autostart = true
		t.timeout.connect(_shiny_sparkle)
		add_child(t)


func _shiny_sparkle() -> void:
	if absorbing or fx == null:
		return
	fx.sparkle(global_position + Vector2(randf_range(-24, 24), randf_range(-30, 10)), 1)


func _process(delta: float) -> void:
	refuse_cd = max(0.0, refuse_cd - delta)
	if absorbing:
		return
	# 말랑 호흡 (idle squish)
	var s := sin(Time.get_ticks_msec() / 1000.0 * 2.2 + phase)
	sprite.scale = Vector2(base_scale * (1.0 + 0.035 * s), base_scale * (1.0 - 0.035 * s))


func absorb_to(target: Vector2) -> void:
	## 흡수 연출: 스쿼시 → 빨려 들어가며 회전+축소 (0.18s, 02 문서 5.1)
	absorbing = true
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(base_scale * 1.28, base_scale * 0.66), 0.06)
	tw.set_parallel(true)
	tw.tween_property(self, "global_position", target, 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(sprite, "scale", Vector2.ONE * base_scale * 0.04, 0.17).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(sprite, "rotation", randf_range(-2.2, 2.2), 0.17)
	tw.chain().tween_callback(queue_free)


func refuse() -> bool:
	## 크기 부족: 부르르 떨림 (02 문서 5.1, 페널티 없음)
	if refuse_cd > 0.0 or absorbing:
		return false
	refuse_cd = 0.9
	var tw := create_tween()
	tw.tween_property(sprite, "rotation", 0.16, 0.05)
	tw.tween_property(sprite, "rotation", -0.16, 0.09)
	tw.tween_property(sprite, "rotation", 0.1, 0.07)
	tw.tween_property(sprite, "rotation", 0.0, 0.05)
	return true


func cheer(delay_s: float) -> void:
	## 클리어: 만세 점프 (04 문서)
	var y0 := position.y
	var tw := create_tween()
	tw.tween_interval(delay_s)
	tw.tween_property(self, "position:y", y0 - 28.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", y0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.set_loops(3)


func sad() -> void:
	## 실패: 시무룩 (채도 다운 + 처짐)
	set_process(false)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "modulate", Color(0.62, 0.6, 0.68), 0.45)
	tw.tween_property(sprite, "scale:y", base_scale * 0.85, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
