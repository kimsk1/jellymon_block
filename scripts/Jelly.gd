extends Node2D
class_name Jelly
## 보드 위의 고정 젤리몬 (1×1). 같은 색 캐처가 지나가면 흡수된다.
## 다른 색 캐처에게는 장애물(통과 불가)이 된다 — 코어 룰.

var color_id := "R"
var cell := Vector2i.ZERO
var shiny := false
var absorbing := false
var trapped := false
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
var expression: JellyExpression
var personality_id := ""
var personality_state := 0
# ── 101레벨 이후 신규 기믹 / 보스 상태
var is_ghost := false            # 다른 색 블록이 통과할 수 있는 유령 젤리
var is_bomb := false             # 구조 시 인접 장벽을 부수는 폭탄 젤리
var is_escort := false           # 전담 블록만 구조할 수 있는 호위 대상
var boss_type := ""              # "king" / "splitter" / "thief"
var boss_hp := 0
var boss_panel: PanelContainer
var boss_label: Label


func setup(cid: String, p_shiny: bool, p_frost_layers: int = 0) -> void:
	color_id = cid
	shiny = p_shiny
	frost_layers = maxi(0, p_frost_layers)
	phase = randf() * TAU
	sprite = Sprite2D.new()
	sprite.texture = CharacterCatalog.character_texture(cid)
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
	expression = JellyExpression.new()
	expression.setup(G.COLORS[cid])
	add_child(expression)
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


func set_ghost(value: bool) -> void:
	## 유령 젤리는 반투명하게 보여 다른 색 블록이 지나갈 수 있음을 알린다.
	is_ghost = value
	if not value:
		return
	sprite.modulate = Color(1, 1, 1, 0.6)
	if shadow_sprite:
		shadow_sprite.modulate.a = 0.08
	_status_badge("👻", Color("#7fa8d8"), Vector2(-42, 10))


func set_bomb(value: bool) -> void:
	is_bomb = value
	if value:
		_status_badge("💣", Color("#c05c4e"), Vector2(9, 10))


func set_escort(value: bool) -> void:
	is_escort = value
	if not value:
		return
	_status_badge("🛡", Color("#3f9f78"), Vector2(-42, 10))
	var halo := create_tween().set_loops()
	halo.tween_property(sprite, "modulate", Color(1.16, 1.16, 1.04), 0.6).set_trans(Tween.TRANS_SINE)
	halo.tween_property(sprite, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)


func set_boss(type_id: String, hp: int) -> void:
	## 보스는 왕관 배지와 남은 타격 수를 항상 보여 준다.
	boss_type = type_id
	boss_hp = hp
	var marks := {"king": "👑", "splitter": "🌀", "thief": "⏳"}
	var tints := {"king": Color("#d8a12f"), "splitter": Color("#7b5fd0"), "thief": Color("#3f8fbf")}
	_status_badge(String(marks.get(type_id, "★")), Color(tints.get(type_id, Color("#d8a12f"))), Vector2(-42, -43))
	sprite.scale = Vector2.ONE * base_scale * 1.06
	if type_id == "king":
		boss_panel = PanelContainer.new()
		boss_panel.position = Vector2(-26, 26)
		boss_panel.size = Vector2(52, 28)
		boss_panel.z_index = 7
		boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#3a2340")
		style.border_color = Color("#f0c65c")
		style.set_border_width_all(3)
		style.set_corner_radius_all(13)
		boss_panel.add_theme_stylebox_override("panel", style)
		add_child(boss_panel)
		boss_label = Label.new()
		boss_label.text = "♥%d" % boss_hp
		boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boss_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		boss_label.add_theme_font_size_override("font_size", 17)
		boss_label.add_theme_color_override("font_color", Color("#ffe9a8"))
		boss_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boss_panel.add_child(boss_label)
	var pulse := create_tween().set_loops()
	pulse.tween_property(self, "scale", Vector2(1.05, 0.96), 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(self, "scale", Vector2(0.97, 1.04), 0.5).set_trans(Tween.TRANS_SINE)


func hit_boss() -> bool:
	## true면 이번 접촉은 체력만 깎고 아직 구조되지 않는다.
	if boss_type != "king" or boss_hp <= 1:
		return false
	boss_hp -= 1
	if boss_label:
		boss_label.text = "♥%d" % boss_hp
	# _process가 매 프레임 sprite.scale을 갱신하므로 흔들림은 회전으로 표현한다.
	var tw := create_tween()
	tw.tween_property(sprite, "rotation", 0.18, 0.06)
	tw.tween_property(sprite, "rotation", -0.18, 0.09)
	tw.tween_property(sprite, "rotation", 0.0, 0.08)
	if fx:
		fx.impact(global_position, Color("#ffd978"), true)
		fx.float_text(global_position, "왕젤리 ♥%d" % boss_hp, Color("#ffe9a8"), 24)
	return true


func _shiny_sparkle() -> void:
	if absorbing or fx == null:
		return
	fx.sparkle(global_position + Vector2(randf_range(-24, 24), randf_range(-30, 10)), 1)


func set_personality(value: String) -> void:
	personality_id = value
	if value.is_empty():
		return
	var symbols := {"shy":"↝", "sleepy":"Z", "playful":"↔", "lonely":"♡"}
	_status_badge(String(symbols.get(value, "•")), G.COLORS[color_id].darkened(0.18), Vector2(9, -43))


func show_personality_feedback(text: String) -> void:
	if fx:
		fx.float_text(global_position, text, Color("#fff2c7"), 22)
	var tw := create_tween()
	tw.tween_property(sprite, "rotation", -0.12, 0.08)
	tw.tween_property(sprite, "rotation", 0.12, 0.08)
	tw.tween_property(sprite, "rotation", 0.0, 0.1)


func _process(_delta: float) -> void:
	if absorbing:
		if trapped:
			var trapped_wave := sin(Time.get_ticks_msec() / 1000.0 * 5.4 + phase)
			sprite.scale = Vector2(
				base_scale * (0.61 + trapped_wave * 0.025),
				base_scale * (0.58 - trapped_wave * 0.018)
			)
			sprite.rotation = trapped_wave * 0.035
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


func trap_in(catcher: Catcher, local_target: Vector2) -> void:
	## 젤리를 캐처의 자식으로 옮겨 블록이 계속 움직여도 내부에서 함께 따라가게 한다.
	absorbing = true
	expression.set_mood("panic")
	trapped = false
	# 블록 표면보다 위, 숫자 배지보다 아래에 보여 실제로 안에 갇힌 것처럼 보인다.
	z_index = 3
	var before := global_position
	reparent(catcher, true)
	global_position = before
	for child in get_children():
		if child is Control:
			child.visible = false
	if shadow_sprite:
		shadow_sprite.modulate.a = 0.08
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", local_target, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "scale", Vector2(base_scale * 0.61, base_scale * 0.58), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "rotation", 0.0, 0.16)
	tw.tween_property(sprite, "modulate", Color(1.08, 1.08, 1.08, 0.88), 0.16)
	tw.chain().tween_callback(func(): trapped = true)


func pop_trapped() -> void:
	## 블록 내부에서 잠깐 눌렸다가 터지는 마무리 모션.
	trapped = false
	expression.set_mood("purified")
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "scale", Vector2(base_scale * 0.82, base_scale * 0.18), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.1)
	tw.tween_property(sprite, "rotation", sprite.rotation + randf_range(-0.22, 0.22), 0.1)
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
