extends Node2D
class_name FX
## 흡수/합체 이펙트 총괄

var soft_tex: Texture2D
var ring_tex: Texture2D
var star_tex: Texture2D
var lock_tex: Texture2D


func _ready() -> void:
	soft_tex = load("res://assets/fx/soft.png")
	ring_tex = load("res://assets/fx/ring.png")
	star_tex = load("res://assets/fx/star.png")
	lock_tex = load("res://assets/fx/lock.png")


func _auto_free(node: Node, sec: float) -> void:
	# 노드 자신에게 타이머를 붙여 함께 소멸시킴 (화면 전환 시 댕글링 콜백 방지)
	var t := Timer.new()
	t.wait_time = sec
	t.one_shot = true
	t.autostart = true
	t.timeout.connect(node.queue_free)
	node.add_child(t)


func burst(pos: Vector2, col: Color, big: bool = false) -> void:
	## 젤리 자리에서 터지는 방울 파티클
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.amount = 22 if big else 13
	p.lifetime = 0.55
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 950)
	p.initial_velocity_min = 170.0
	p.initial_velocity_max = 430.0 if big else 330.0
	p.scale_amount_min = 0.32
	p.scale_amount_max = 0.85 if big else 0.65
	p.texture = soft_tex
	p.color = col
	p.hue_variation_min = -0.03
	p.hue_variation_max = 0.03
	add_child(p)
	p.emitting = true
	_auto_free(p, 1.3)


func swirl(pos: Vector2, col: Color) -> void:
	## 구멍으로 소용돌이치며 빨려드는 입자
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.amount = 10
	p.lifetime = 0.34
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 48.0
	p.gravity = Vector2.ZERO
	p.radial_accel_min = -1000.0
	p.radial_accel_max = -760.0
	p.tangential_accel_min = 300.0
	p.tangential_accel_max = 440.0
	p.scale_amount_min = 0.2
	p.scale_amount_max = 0.5
	p.texture = soft_tex
	p.color = Color(col.r, col.g, col.b, 0.85)
	add_child(p)
	p.emitting = true
	_auto_free(p, 0.9)


func sparkle(pos: Vector2, amount: int = 6) -> void:
	## 샤이니 반짝임
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, -60)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 90.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.6
	p.texture = star_tex
	p.color = Color(1.0, 0.95, 0.55)
	add_child(p)
	p.emitting = true
	_auto_free(p, 1.0)


func ring(pos: Vector2, col: Color, size: float = 1.0) -> void:
	## 충격파 링
	var s := Sprite2D.new()
	s.texture = ring_tex
	s.position = pos
	s.modulate = Color(col.r, col.g, col.b, 0.9)
	s.scale = Vector2.ONE * 0.22 * size
	add_child(s)
	var tw := s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE * 1.4 * size, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, 0.32)
	tw.chain().tween_callback(s.queue_free)


func impact(pos: Vector2, col: Color, big: bool = false) -> void:
	## 흡수 순간 플래시 + 별 파편 + 이중 충격파. 큰 홀 제거는 한 단계 더 강하게 연출한다.
	var flash := Sprite2D.new()
	flash.texture = soft_tex
	flash.position = pos
	flash.modulate = Color(1, 1, 1, 0.92)
	flash.scale = Vector2.ONE * (1.15 if big else 0.72)
	flash.z_index = 70
	add_child(flash)
	var ft := flash.create_tween().set_parallel(true)
	ft.tween_property(flash, "scale", Vector2.ONE * (2.6 if big else 1.65), 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	ft.tween_property(flash, "modulate:a", 0.0, 0.18)
	ft.chain().tween_callback(flash.queue_free)

	for delay in [0.0, 0.07]:
		var s := Sprite2D.new()
		s.texture = ring_tex
		s.position = pos
		s.modulate = Color(col.r, col.g, col.b, 0.95)
		s.scale = Vector2.ONE * 0.16
		s.z_index = 68
		add_child(s)
		var tw := s.create_tween()
		tw.tween_interval(delay)
		tw.set_parallel(true)
		tw.tween_property(s, "scale", Vector2.ONE * (2.3 if big else 1.35), 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(s.queue_free)

	var stars := CPUParticles2D.new()
	stars.position = pos
	stars.one_shot = true
	stars.amount = 34 if big else 16
	stars.lifetime = 0.7
	stars.explosiveness = 1.0
	stars.direction = Vector2(0, -1)
	stars.spread = 180.0
	stars.gravity = Vector2(0, 620)
	stars.initial_velocity_min = 210.0
	stars.initial_velocity_max = 560.0 if big else 390.0
	stars.scale_amount_min = 0.35
	stars.scale_amount_max = 0.85 if big else 0.58
	stars.texture = star_tex
	stars.color = col.lightened(0.25)
	stars.z_index = 69
	add_child(stars)
	stars.emitting = true
	_auto_free(stars, 1.5)


func float_text(pos: Vector2, text: String, col: Color, fsize: int = 32) -> void:
	## 플로팅 점수 텍스트
	var l := Label.new()
	l.text = text
	l.z_index = 60
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.16, 0.08, 0.2, 0.92))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(240, 48)
	l.position = pos + Vector2(-120, -46)
	add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 50.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func show_lock(pos: Vector2) -> void:
	## 크기 부족 자물쇠 (0.5s)
	var s := Sprite2D.new()
	s.texture = lock_tex
	s.position = pos + Vector2(0, -34)
	s.z_index = 55
	add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "position:y", s.position.y - 12.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.28)
	tw.tween_property(s, "modulate:a", 0.0, 0.15)
	tw.tween_callback(s.queue_free)


func confetti() -> void:
	## 클리어 컨페티 (화면 상단에서 낙하)
	for i in range(3):
		var p := CPUParticles2D.new()
		p.position = Vector2(G.W * (0.2 + 0.3 * i), 40)
		p.one_shot = true
		p.amount = 26
		p.lifetime = 1.6
		p.explosiveness = 0.9
		p.direction = Vector2(0, 1)
		p.spread = 70.0
		p.gravity = Vector2(0, 420)
		p.initial_velocity_min = 120.0
		p.initial_velocity_max = 380.0
		p.scale_amount_min = 0.3
		p.scale_amount_max = 0.7
		p.texture = soft_tex
		p.color_ramp = _confetti_ramp()
		p.hue_variation_min = -0.5
		p.hue_variation_max = 0.5
		p.color = Color(1.0, 0.5, 0.6)
		add_child(p)
		p.emitting = true
		_auto_free(p, 2.2)


func _confetti_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	return g
