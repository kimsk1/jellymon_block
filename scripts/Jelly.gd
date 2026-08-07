extends Node2D
class_name Jelly
## 보드 위의 고정 젤리몬 (1×1). 같은 색 캐처가 지나가면 흡수된다.
## 다른 색 캐처에게는 장애물(통과 불가)이 된다 — 코어 룰.

var color_id := "R"
var cell := Vector2i.ZERO
var shiny := false
var absorbing := false
var base_scale := 1.0
var phase := 0.0
var sprite: Sprite2D
var shadow_sprite: Sprite2D
var shadow_base_scale := Vector2.ONE
var art_offset := Vector2.ZERO
var fx = null


func setup(cid: String, p_shiny: bool) -> void:
	color_id = cid
	shiny = p_shiny
	phase = randf() * TAU
	sprite = Sprite2D.new()
	sprite.texture = G.jelly_tex(cid)
	base_scale = (G.CELL * 0.94) / float(sprite.texture.get_width())
	# PNG의 투명 여백이 비대칭이어도 실제 그림의 중심이 타일 정중앙에 오도록 보정한다.
	var image := sprite.texture.get_image()
	if image:
		var used := image.get_used_rect()
		var image_center := Vector2(image.get_width(), image.get_height()) * 0.5
		var art_center := Vector2(used.position) + Vector2(used.size) * 0.5
		art_offset = (image_center - art_center) * base_scale
	shadow_sprite = Sprite2D.new()
	shadow_sprite.texture = load("res://assets/fx/soft.png")
	shadow_sprite.modulate = Color(0.11, 0.12, 0.25, 0.24)
	shadow_sprite.position = Vector2(0, G.CELL * 0.31)
	shadow_base_scale = Vector2(
		(G.CELL * 0.58) / float(shadow_sprite.texture.get_width()),
		(G.CELL * 0.18) / float(shadow_sprite.texture.get_height())
	)
	shadow_sprite.scale = shadow_base_scale
	shadow_sprite.z_index = -1
	add_child(shadow_sprite)
	sprite.position = art_offset
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


func _process(_delta: float) -> void:
	if absorbing:
		return
	var s := sin(Time.get_ticks_msec() / 1000.0 * 2.2 + phase)
	sprite.scale = Vector2(base_scale * (1.0 + 0.035 * s), base_scale * (1.0 - 0.035 * s))
	sprite.position = art_offset + Vector2(0, s * 1.2)
	shadow_sprite.scale = Vector2(shadow_base_scale.x * (1.0 + s * 0.08), shadow_base_scale.y)
	shadow_sprite.modulate.a = 0.22 - s * 0.025


func absorb_anim(to: Vector2) -> void:
	## 캐처 구멍 속으로 빨려 들어가는 연출
	absorbing = true
	z_index = 20
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(base_scale * 1.28, base_scale * 0.66), 0.05)
	tw.set_parallel(true)
	tw.tween_property(self, "global_position", to, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(sprite, "scale", Vector2.ONE * base_scale * 0.04, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(sprite, "rotation", randf_range(-2.2, 2.2), 0.16)
	tw.chain().tween_callback(queue_free)


func sad() -> void:
	set_process(false)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "modulate", Color(0.62, 0.6, 0.68), 0.45)
	tw.tween_property(sprite, "scale:y", base_scale * 0.85, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func revive() -> void:
	set_process(true)
	sprite.modulate = Color(1.35, 1.32, 1.05) if shiny else Color.WHITE
	sprite.scale = Vector2.ONE * base_scale
