extends Node2D
class_name Block
## 다양한 모양의 젤리 블록 (빠지냥식 코어). 로직은 격자, 시각은 부드러운 슬라이드+스쿼시.

var color_id := "R"
var shape_id := "S1"
var cells: Array = []          # Vector2i 오프셋 목록
var origin_cell := Vector2i.ZERO
var shiny := false
var absorbing := false
var grabbed := false
var slide_target := Vector2.ZERO
var base_scale := 1.0
var phase := 0.0
var sprite: Sprite2D
var fx = null


func setup(cid: String, shape: String, p_shiny: bool) -> void:
	color_id = cid
	shape_id = shape
	cells = G.SHAPES[shape]
	shiny = p_shiny
	phase = randf() * TAU
	sprite = Sprite2D.new()
	sprite.texture = G.block_tex(shape, cid)
	var bbox := Vector2.ZERO
	for off in cells:
		bbox.x = maxf(bbox.x, float(off.x + 1))
		bbox.y = maxf(bbox.y, float(off.y + 1))
	base_scale = (G.CELL * bbox.x) / float(sprite.texture.get_width())
	sprite.scale = Vector2.ONE * base_scale
	sprite.position = bbox * G.CELL * 0.5
	add_child(sprite)
	if shiny:
		sprite.modulate = Color(1.35, 1.32, 1.05)
		var t := Timer.new()
		t.wait_time = 0.6
		t.autostart = true
		t.timeout.connect(_shiny_sparkle)
		add_child(t)


func center_px() -> Vector2:
	return global_position + sprite.position


func _shiny_sparkle() -> void:
	if absorbing or fx == null:
		return
	fx.sparkle(center_px() + Vector2(randf_range(-24, 24), randf_range(-30, 10)), 1)


func _process(delta: float) -> void:
	if absorbing:
		return
	# 격자 논리 위치로 부드럽게 슬라이드
	position = position.move_toward(slide_target, 2400.0 * delta)
	# 말랑 호흡 (잡고 있으면 더 크게 출렁)
	var k := 0.05 if grabbed else 0.03
	var s := sin(Time.get_ticks_msec() / 1000.0 * 2.2 + phase)
	sprite.scale = Vector2(base_scale * (1.0 + k * s), base_scale * (1.0 - k * s))


func absorb_to(target: Vector2) -> void:
	## 가두기 연출: 스쿼시 → 구멍으로 회전하며 통째로 빨려 들어감
	absorbing = true
	grabbed = false
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(base_scale * 1.25, base_scale * 0.68), 0.06)
	tw.set_parallel(true)
	tw.tween_property(self, "position", target - sprite.position, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(sprite, "scale", Vector2.ONE * base_scale * 0.04, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(sprite, "rotation", randf_range(-2.2, 2.2), 0.2)
	tw.chain().tween_callback(queue_free)


func cheer(delay_s: float) -> void:
	set_process(false)
	var y0 := position.y
	var tw := create_tween()
	tw.tween_interval(delay_s)
	tw.tween_property(self, "position:y", y0 - 26.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", y0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.set_loops(3)


func sad() -> void:
	set_process(false)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "modulate", Color(0.62, 0.6, 0.68), 0.45)
	tw.tween_property(sprite, "scale:y", base_scale * 0.85, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
