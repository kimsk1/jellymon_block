extends CanvasLayer
class_name HUD
## 인게임 HUD + 팝업 (04 문서 5/6/7장)

var game = null
var root: Control
var time_label: Label
var name_label: Label
var timer_caption: Label
var timer_bar: ProgressBar
var goal_items := {}
var star_tex: Texture2D
var clear_base_reward := 0
var clear_bonus_claimed := false
var clear_reward_label: Label
var clear_double_button: Button


func _ready() -> void:
	star_tex = load("res://assets/fx/ui_star.png")
	root = Control.new()
	_apply_responsive_layout()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ── 상단 바: 실제 모바일 게임처럼 화면에서 살짝 띄운 카드형 HUD
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_top = 12
	top.offset_right = -16
	top.offset_bottom = 142
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#45b7ef")
	sb.border_color = Color("#176a9f")
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(28)
	sb.corner_detail = 12
	sb.border_blend = true
	sb.shadow_color = Color(0.05, 0.13, 0.28, 0.38)
	sb.shadow_size = 13
	sb.shadow_offset = Vector2(0, 8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	top.add_theme_stylebox_override("panel", sb)
	root.add_child(top)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	top.add_child(hb)
	var mascot := TextureRect.new()
	mascot.texture = G.hero_tex()
	mascot.custom_minimum_size = Vector2(76, 76)
	mascot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mascot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mascot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(mascot)

	var quit_btn := _small_button("⌂", Color("#9c8bc4"))
	quit_btn.tooltip_text = "레벨 선택"
	quit_btn.pressed.connect(_on_quit_pressed)
	hb.add_child(quit_btn)

	var retry_btn := _small_button("↻", Color("#f5a255"))
	retry_btn.tooltip_text = "다시 시작"
	retry_btn.pressed.connect(_on_retry_pressed)
	hb.add_child(retry_btn)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(mid)
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color("#e9f8ff"))
	name_label.add_theme_color_override("font_outline_color", Color("#29698f"))
	name_label.add_theme_constant_override("outline_size", 5)
	mid.add_child(name_label)
	timer_caption = Label.new()
	timer_caption.text = "TIME"
	timer_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_caption.add_theme_font_size_override("font_size", 15)
	timer_caption.add_theme_color_override("font_color", Color("#dff6ff"))
	mid.add_child(timer_caption)
	time_label = Label.new()
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 48)
	time_label.add_theme_color_override("font_color", Color.WHITE)
	time_label.add_theme_color_override("font_outline_color", Color("#214e74"))
	time_label.add_theme_constant_override("outline_size", 8)
	mid.add_child(time_label)
	timer_bar = ProgressBar.new()
	timer_bar.custom_minimum_size = Vector2(250, 12)
	timer_bar.show_percentage = false
	timer_bar.max_value = 100.0
	var timer_bg := StyleBoxFlat.new()
	timer_bg.bg_color = Color(0.06, 0.25, 0.43, 0.48)
	timer_bg.set_corner_radius_all(6)
	timer_bg.content_margin_top = 2
	timer_bg.content_margin_bottom = 2
	timer_bar.add_theme_stylebox_override("background", timer_bg)
	var timer_fill := StyleBoxFlat.new()
	timer_fill.bg_color = Color("#fff18a")
	timer_fill.border_color = Color(1, 1, 1, 0.72)
	timer_fill.set_border_width_all(2)
	timer_fill.set_corner_radius_all(6)
	timer_bar.add_theme_stylebox_override("fill", timer_fill)
	mid.add_child(timer_bar)


func _apply_responsive_layout() -> void:
	if not root:
		return
	root.position = G.safe_offset(get_viewport().get_visible_rect().size)
	root.size = Vector2(G.W, G.H)


func _fit_overlay_to_viewport(control: Control) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = -G.safe_offset(viewport_size)
	control.size = viewport_size

func _on_quit_pressed() -> void:
	if game:
		game.main.show_map()


func _on_retry_pressed() -> void:
	if game:
		game.main.start_level(game.level_idx)


func setup(goals: Dictionary, level: Dictionary, level_idx: int) -> void:
	name_label.text = "LEVEL %d  %s" % [level_idx + 1, level.name]
	# 실제 빠지냥처럼 목표 카운터 대신 각 홀의 용량 숫자 자체가 목표를 표시한다.
	if not goal_items.has("_box"):
		return
	var box: HBoxContainer = goal_items["_box"]
	for k in goals:
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		var tr := TextureRect.new()
		tr.texture = G.jelly_tex(k)
		tr.custom_minimum_size = Vector2(52, 52)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		v.add_child(tr)
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 26)
		l.add_theme_color_override("font_color", G.INK)
		l.text = str(goals[k])
		v.add_child(l)
		box.add_child(v)
		goal_items[k] = l


func set_goals(goals: Dictionary) -> void:
	for k in goals:
		if goal_items.has(k):
			var l: Label = goal_items[k]
			var n: int = goals[k]
			l.text = str(n)
			if n <= 0:
				l.text = "OK!"
				l.add_theme_color_override("font_color", Color(0.2, 0.7, 0.3))


func set_time(t: float, total: float) -> void:
	var m := int(t) / 60
	var s := int(t) % 60
	time_label.text = "%d:%02d" % [m, s]
	if timer_bar:
		timer_bar.value = clampf(t / maxf(total, 0.01) * 100.0, 0.0, 100.0)
	if t <= 10.0:
		time_label.add_theme_color_override("font_color", Color(0.95, 0.25, 0.3))
		if timer_bar:
			var danger: StyleBoxFlat = timer_bar.get_theme_stylebox("fill").duplicate()
			danger.bg_color = Color("#ff667e")
			timer_bar.add_theme_stylebox_override("fill", danger)
	elif t <= total * 0.2:
		time_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.15))
	else:
		time_label.add_theme_color_override("font_color", Color.WHITE)


func show_hint(text: String) -> void:
	if text.is_empty():
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0.45, 0.95))
	l.add_theme_constant_override("outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	l.offset_left = 40
	l.offset_top = 155
	l.offset_right = -40
	l.offset_bottom = 255
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


# ────────────────────────── 팝업 ──────────────────────────

func _small_button(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(78, 78)
	b.add_theme_font_size_override("font_size", 40)
	_style_button(b, col)
	return b


func _big_button(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(210, 80)
	b.add_theme_font_size_override("font_size", 32)
	_style_button(b, col)
	return b


func _result_button(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(142, 76)
	b.add_theme_font_size_override("font_size", 27)
	_style_button(b, col)
	return b


func _style_button(b: Button, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(18)
	sb.corner_detail = 10
	sb.border_blend = true
	sb.border_color = col.darkened(0.28)
	sb.set_border_width_all(4)
	sb.shadow_color = Color(0.1, 0.08, 0.2, 0.3)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_top = 8
	sb.content_margin_bottom = 12
	b.add_theme_stylebox_override("normal", sb)
	var sb2: StyleBoxFlat = sb.duplicate()
	sb2.bg_color = col.lightened(0.08)
	b.add_theme_stylebox_override("hover", sb2)
	var pressed: StyleBoxFlat = sb.duplicate()
	pressed.bg_color = col.darkened(0.12)
	pressed.shadow_size = 1
	pressed.shadow_offset = Vector2(0, 1)
	b.add_theme_stylebox_override("pressed", pressed)
	# Godot 기본 disabled 스타일(각진 회색 패널) 대신 밝고 둥근 게임 공통 스타일을 사용한다.
	var disabled: StyleBoxFlat = sb.duplicate()
	disabled.bg_color = col.lightened(0.48)
	disabled.border_color = col.lightened(0.12)
	disabled.shadow_color = Color(0.1, 0.08, 0.2, 0.18)
	disabled.shadow_size = 4
	disabled.shadow_offset = Vector2(0, 3)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", col.darkened(0.34))
	b.add_theme_color_override("font_outline_color", col.darkened(0.42))
	b.add_theme_constant_override("outline_size", 3)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _set_reward_complete_style(button: Button) -> void:
	var completed := StyleBoxFlat.new()
	completed.bg_color = Color("#dff7e7")
	completed.border_color = Color("#69bd7d")
	completed.set_border_width_all(4)
	completed.set_corner_radius_all(20)
	completed.corner_detail = 12
	completed.shadow_color = Color(0.08, 0.2, 0.12, 0.22)
	completed.shadow_size = 5
	completed.shadow_offset = Vector2(0, 4)
	completed.content_margin_top = 8
	completed.content_margin_bottom = 12
	button.add_theme_stylebox_override("disabled", completed)
	button.add_theme_color_override("font_disabled_color", Color("#31704a"))
	button.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))


func _popup_frame() -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.06, 0.18, 0.55)
	_fit_overlay_to_viewport(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#fff7fc")
	sb.border_color = Color("#674493")
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(32)
	sb.shadow_color = Color(0.08, 0.03, 0.18, 0.5)
	sb.shadow_size = 20
	sb.shadow_offset = Vector2(0, 12)
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 36
	sb.content_margin_bottom = 36
	panel.add_theme_stylebox_override("panel", sb)
	cc.add_child(panel)
	panel.scale = Vector2(0.7, 0.7)
	panel.pivot_offset = Vector2(260, 200)
	var tw := panel.create_tween()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 22)
	v.custom_minimum_size = Vector2(430, 0)
	panel.add_child(v)
	return v


func _title_label(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 56)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 6)
	return l


func show_result(stars_n: int, score: int, stardust_reward: int, stardust_total: int, has_next: bool, on_next: Callable, on_map: Callable, on_retry: Callable) -> void:
	clear_base_reward = stardust_reward
	clear_bonus_claimed = false
	var v := _popup_frame()
	var mascot := TextureRect.new()
	mascot.texture = G.hero_tex()
	mascot.custom_minimum_size = Vector2(112, 92)
	mascot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mascot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mascot.pivot_offset = Vector2(56, 46)
	v.add_child(mascot)
	var mascot_tween := mascot.create_tween().set_loops()
	mascot_tween.tween_property(mascot, "rotation", -0.08, 0.22).set_trans(Tween.TRANS_SINE)
	mascot_tween.tween_property(mascot, "rotation", 0.08, 0.22).set_trans(Tween.TRANS_SINE)
	v.add_child(_title_label("클리어!", Color(1.0, 0.5, 0.35)))
	# 별 3개 (순차 팝)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	for i in range(3):
		var tr := TextureRect.new()
		tr.texture = star_tex
		tr.custom_minimum_size = Vector2(92, 92)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.pivot_offset = Vector2(46, 46)
		if i < stars_n:
			tr.modulate = Color(1.0, 0.8, 0.15)
			tr.scale = Vector2.ZERO
			var tw := tr.create_tween()
			tw.tween_interval(0.25 + 0.22 * i)
			tw.tween_callback(func():
				if game:
					game.audio.play("pop", 1.0 + 0.15 * i))
			tw.tween_property(tr, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			tr.modulate = Color(0.45, 0.42, 0.5, 0.55)
		row.add_child(tr)
	var sc := Label.new()
	sc.text = "점수  %d" % score
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sc.add_theme_font_size_override("font_size", 34)
	sc.add_theme_color_override("font_color", G.INK)
	v.add_child(sc)
	var dust := Label.new()
	clear_reward_label = dust
	dust.text = "★ 별가루 +%d   보유 %d" % [stardust_reward, stardust_total] if stardust_reward > 0 else "★ 이미 받은 별 보상이에요   보유 %d" % stardust_total
	dust.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dust.add_theme_font_size_override("font_size", 25)
	dust.add_theme_color_override("font_color", Color("#8057b2"))
	v.add_child(dust)
	if stardust_reward > 0:
		clear_double_button = _big_button("보상 2배 받기" if game.main.save.has_removed_ads() else "광고 보고 보상 2배", Color("#8e64c8"))
		clear_double_button.custom_minimum_size = Vector2(430, 72)
		clear_double_button.pressed.connect(_request_clear_double_reward)
		v.add_child(clear_double_button)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 12)
	v.add_child(btns)
	var b_home := _result_button("모험", Color("#55a9d8"))
	b_home.tooltip_text = "모험 레벨 선택으로"
	b_home.pressed.connect(on_map)
	btns.add_child(b_home)
	var b_retry := _result_button("다시", Color(0.62, 0.56, 0.72))
	b_retry.pressed.connect(on_retry)
	btns.add_child(b_retry)
	if has_next:
		var b_next := _result_button("다음 레벨", Color(0.28, 0.75, 0.42))
		b_next.pressed.connect(on_next)
		btns.add_child(b_next)


func _request_clear_double_reward() -> void:
	if clear_bonus_claimed or clear_base_reward <= 0 or not clear_double_button:
		return
	clear_double_button.disabled = true
	if game.main.save.has_removed_ads():
		clear_double_button.text = "2배 보상 지급 중..."
	else:
		clear_double_button.text = "광고 재생 중..."
	game.main.request_rewarded_ad(_finish_clear_double_reward, _restore_clear_double_button)


func _finish_clear_double_reward() -> void:
	if clear_bonus_claimed or clear_base_reward <= 0 or not is_instance_valid(clear_double_button):
		return
	if not game.main.save.grant_stardust(clear_base_reward):
		_restore_clear_double_button()
		return
	clear_bonus_claimed = true
	clear_double_button.text = "✓ 2배 보상 받음"
	_set_reward_complete_style(clear_double_button)
	clear_double_button.disabled = true
	clear_reward_label.text = "★ 별가루 +%d  · 2배 완료!   보유 %d" % [clear_base_reward * 2, game.main.save.get_stardust()]
	clear_reward_label.add_theme_color_override("font_color", Color("#d7792e"))
	game.audio.play("shiny", 1.12)
	game.fx.sparkle(Vector2(G.W * 0.5, 470), 22)
	G.haptic(24)


func _restore_clear_double_button() -> void:
	if not is_instance_valid(clear_double_button) or clear_bonus_claimed:
		return
	clear_double_button.disabled = false
	clear_double_button.text = "보상 2배 받기" if game.main.save.has_removed_ads() else "광고 보고 보상 2배"
	if clear_reward_label:
		clear_reward_label.text = "광고를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."


func show_fail(reason: String, stardust_total: int, on_continue: Callable, on_retry: Callable, on_map: Callable) -> void:
	var v := _popup_frame()
	var dim: Control = v.get_parent().get_parent().get_parent()
	v.add_child(_title_label("아쉬워요!", Color(0.55, 0.48, 0.68)))
	var l := Label.new()
	l.text = reason
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", G.INK)
	v.add_child(l)
	var tip := Label.new()
	tip.text = "현재 보드 그대로, 시간만 처음부터 다시 시작해요.\n보유 별가루  ★ %d" % stardust_total
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 24)
	tip.add_theme_color_override("font_color", Color(0.6, 0.55, 0.7))
	v.add_child(tip)
	var b_continue := _big_button("★ 20  이어하기", Color("#9165c7"))
	b_continue.custom_minimum_size = Vector2(430, 78)
	b_continue.disabled = stardust_total < 20
	if b_continue.disabled:
		b_continue.text = "별가루가 부족해요  (%d/20)" % stardust_total
	b_continue.pressed.connect(func():
		if bool(on_continue.call()):
			dim.queue_free()
	)
	v.add_child(b_continue)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 18)
	v.add_child(btns)
	var b_map := _result_button("그만", Color(0.62, 0.56, 0.72))
	b_map.pressed.connect(on_map)
	btns.add_child(b_map)
	var b_retry := _result_button("처음부터", Color(1.0, 0.55, 0.25))
	b_retry.pressed.connect(on_retry)
	btns.add_child(b_retry)
