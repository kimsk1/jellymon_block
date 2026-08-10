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
var frost_layers := 0
var frost_panel: PanelContainer
var frost_label: Label
var seal_panel: PanelContainer


func setup(cid: String, p_shiny: bool, p_frost_layers: int = 0) -> void:
	color_id = cid
	shiny = p_shiny
	frost_layers = maxi(0, p_frost_layers)
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
	if frost_layers > 0:
		_build_frost_shell()
	if shiny:
		# 반짝이 개체도 같은 색 ID라면 원본 색을 유지한다.
		# 기존의 비균일 RGB 증폭은 파란 젤리를 청록색처럼 보이게 했다.
		sprite.modulate = Color.WHITE
		var t := Timer.new()
		t.wait_time = 0.6
		t.autostart = true
		t.timeout.connect(_shiny_sparkle)
		add_child(t)


func _build_frost_shell() -> void:
	frost_panel = PanelContainer.new()
	frost_panel.position = Vector2(-38, -39)
	frost_panel.size = Vector2(76, 76)
	frost_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frost_panel.z_index = 3
	var ice := StyleBoxFlat.new()
	ice.bg_color = Color(0.55, 0.91, 1.0, 0.2)
	ice.border_color = Color("#bff7ff")
	ice.set_border_width_all(5 if frost_layers == 1 else 7)
	ice.set_corner_radius_all(21)
	ice.corner_detail = 10
	ice.shadow_color = Color(0.17, 0.48, 0.72, 0.3)
	ice.shadow_size = 5
	ice.shadow_offset = Vector2(0, 3)
	frost_panel.add_theme_stylebox_override("panel", ice)
	add_child(frost_panel)
	frost_label = Label.new()
	frost_label.position = Vector2(43, -8)
	frost_label.size = Vector2(38, 34)
	frost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frost_label.add_theme_font_size_override("font_size", 21)
	frost_label.add_theme_color_override("font_color", Color.WHITE)
	frost_label.add_theme_color_override("font_outline_color", Color("#4388b6"))
	frost_label.add_theme_constant_override("outline_size", 5)
	frost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frost_label.text = "❄" if frost_layers == 1 else "❄%d" % frost_layers
	frost_panel.add_child(frost_label)


func hit_frost() -> bool:
	## true면 이번 접촉은 얼음만 깨고 젤리는 아직 흡수하지 않는다.
	if frost_layers <= 0:
		return false
	frost_layers -= 1
	if frost_panel and is_instance_valid(frost_panel):
		var pulse := frost_panel.create_tween()
		pulse.tween_property(frost_panel, "scale", Vector2(1.13, 0.88), 0.08).set_trans(Tween.TRANS_BACK)
		pulse.tween_property(frost_panel, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_BOUNCE)
		if frost_layers > 0:
			frost_label.text = "❄%d" % frost_layers
		else:
			pulse.parallel().tween_property(frost_panel, "modulate:a", 0.0, 0.18)
			pulse.tween_callback(frost_panel.queue_free)
	return true


func _status_badge(text: String, color: Color, position_offset: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = position_offset
	panel.size = Vector2(34, 34)
	panel.z_index = 6
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color.WHITE
	style.set_border_width_all(3)
	style.set_corner_radius_all(17)
	style.shadow_color = Color(0.08, 0.04, 0.18, 0.35)
	style.shadow_size = 3
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", color.darkened(0.4))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return panel


func set_chain_badge(order: int) -> void:
	_status_badge(str(order), Color("#ee9d38"), Vector2(-42, -43))


func set_key_marker(value: bool) -> void:
	if value:
		_status_badge("◆", Color("#e0aa35"), Vector2(9, 10))


func set_rescue_sealed(value: bool) -> void:
	if not value:
		if seal_panel and is_instance_valid(seal_panel):
			var tw := seal_panel.create_tween()
			tw.tween_property(seal_panel, "modulate:a", 0.0, 0.2)
			tw.tween_callback(seal_panel.queue_free)
		return
	seal_panel = PanelContainer.new()
	seal_panel.position = Vector2(-38, -39)
	seal_panel.size = Vector2(76, 76)
	seal_panel.z_index = 4
	seal_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.55, 0.28, 0.8, 0.13)
	style.border_color = Color("#b987ef")
	style.set_border_width_all(5)
	style.set_corner_radius_all(22)
	style.shadow_color = Color(0.25, 0.08, 0.42, 0.32)
	style.shadow_size = 5
	seal_panel.add_theme_stylebox_override("panel", style)
	add_child(seal_panel)
	var lock := Label.new()
	lock.text = "◆"
	lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock.add_theme_font_size_override("font_size", 22)
	lock.add_theme_color_override("font_color", Color("#f4dcff"))
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal_panel.add_child(lock)


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
	# 실패 연출에서 복귀할 때도 반짝이 여부와 관계없이 원본 색상으로 돌아온다.
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE * base_scale
