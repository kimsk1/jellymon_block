extends CanvasLayer
class_name HUD
## 인게임 HUD + 팝업 (04 문서 5/6/7장)

const L10n = preload("res://scripts/LocalizedText.gd")
const TutorialGuideScene = preload("res://scripts/TutorialGuide.gd")
const BattleHUDIconScene = preload("res://scripts/BattleHUDIcon.gd")

var game = null
var root: Control
var time_label: Label
var name_label: Label
var timer_caption: Label
var timer_bar: ProgressBar
var _timer_fill: StyleBoxFlat
var _timer_normal_color: Color
var _timer_second := -1
var _timer_state := -1
var goal_items := {}
var star_tex: Texture2D
var clear_base_reward := 0
var clear_bonus_claimed := false
var clear_reward_label: Label
var clear_double_button: Button
var booster_buttons := {}
var booster_tray: Control
var tutorial_guide: Control
var tutorial_help_button: Button
var objective_card: PanelContainer
var objective_label: Label
var pause_overlay: Control
var retry_overlay: Control
var retry_cancel: Callable


func _ready() -> void:
	star_tex = load("res://assets/fx/ui_star.png")
	root = Control.new()
	root.theme = ArtDirection.ui_theme()
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
	# 메인 화면과 같은 크림 패널과 갈색 본문을 사용한다.
	var sb := ArtDirection.panel(Color("#263968"), Color("#68d8f4"), 30, 0.52, 5)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	top.add_theme_stylebox_override("panel", sb)
	ArtDirection.decorate_surface(top, 30, Color("#a9efff"), 0.92)
	root.add_child(top)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 9)
	top.add_child(hb)
	var mascot := TextureRect.new()
	mascot.texture = G.hero_tex()
	mascot.custom_minimum_size = Vector2(58, 68)
	mascot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mascot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mascot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(mascot)

	var quit_btn := _small_button("home", Color("#9c8bc4"))
	quit_btn.tooltip_text = L10n.text(tr("레벨 선택"))
	quit_btn.pressed.connect(_on_quit_pressed)
	hb.add_child(quit_btn)

	var retry_btn := _small_button("retry", Color("#f5a255"))
	retry_btn.tooltip_text = L10n.text(tr("다시 시작"))
	retry_btn.pressed.connect(_on_retry_pressed)
	hb.add_child(retry_btn)

	var pause_btn := _small_button("pause", Color("#6c91c8"))
	pause_btn.tooltip_text = L10n.text(tr("일시정지"))
	pause_btn.pressed.connect(func(): game.set_paused(true))
	hb.add_child(pause_btn)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(mid)
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", ArtDirection.ink())
	name_label.add_theme_color_override("font_outline_color", Color("#12234e"))
	name_label.add_theme_constant_override("outline_size", 0)
	mid.add_child(name_label)
	timer_caption = Label.new()
	timer_caption.text = L10n.text("TIME")
	timer_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_caption.add_theme_font_size_override("font_size", 15)
	timer_caption.add_theme_color_override("font_color", ArtDirection.ink())
	mid.add_child(timer_caption)
	time_label = Label.new()
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 44)
	time_label.add_theme_color_override("font_color", ArtDirection.ink())
	time_label.add_theme_color_override("font_outline_color", Color("#111d46"))
	time_label.add_theme_constant_override("outline_size", 0)
	mid.add_child(time_label)
	timer_bar = ProgressBar.new()
	timer_bar.custom_minimum_size = Vector2(215, 12)
	timer_bar.show_percentage = false
	timer_bar.max_value = 100.0
	var timer_bg := StyleBoxFlat.new()
	timer_bg.bg_color = ArtDirection.disabled_color()
	timer_bg.set_corner_radius_all(6)
	timer_bg.content_margin_top = 2
	timer_bg.content_margin_bottom = 2
	timer_bar.add_theme_stylebox_override("background", timer_bg)
	var timer_fill := StyleBoxFlat.new()
	timer_fill.bg_color = ArtDirection.primary_color()
	timer_fill.border_color = ArtDirection.border_color()
	timer_fill.set_border_width_all(1)
	timer_fill.set_corner_radius_all(6)
	_timer_fill = timer_fill
	_timer_normal_color = timer_fill.bg_color
	timer_bar.add_theme_stylebox_override("fill", timer_fill)
	mid.add_child(timer_bar)
	_build_objective_bar()
	_build_booster_tray()
	_build_tutorial_help()


func _build_objective_bar() -> void:
	## 보스/대체 승리 조건이 있는 레벨에서만 보이는 목표 요약 줄.
	objective_card = PanelContainer.new()
	objective_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	objective_card.offset_left = 48
	objective_card.offset_top = 148
	objective_card.offset_right = -48
	objective_card.offset_bottom = 196
	objective_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := ArtDirection.panel(Color(0.16, 0.1, 0.3, 0.86), Color("#ffd978"), 20, 0.24, 3)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 5
	style.content_margin_bottom = 6
	objective_card.add_theme_stylebox_override("panel", style)
	objective_card.visible = false
	root.add_child(objective_card)
	objective_label = Label.new()
	objective_label.add_theme_font_size_override("font_size", 21)
	objective_label.add_theme_color_override("font_color", ArtDirection.ink())
	objective_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.2, 0.9))
	objective_label.add_theme_constant_override("outline_size", 0)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_card.add_child(objective_label)


func refresh_objectives() -> void:
	## 보스 종류, 남은 이동 수, 현재 구조 순서를 한 줄로 요약한다.
	if not objective_card or not game:
		return
	var parts: Array[String] = []
	if not game.boss_data.is_empty() and not game.boss_defeated:
		var marks := {"king": L10n.text("👑 왕젤리"), "splitter": L10n.text("🌀 분열 젤리"), "thief": L10n.text("⏳ 시간 도둑")}
		parts.append(L10n.text(String(marks.get(L10n.text(String(game.boss_data.get("type", ""))), L10n.text("보스")))))
	if game.move_limit > 0:
		parts.append(L10n.text("이동 %d/%d") % [game.moves_used, game.move_limit])
	if not game.color_order.is_empty():
		game._advance_color_order()
		if game.color_order_index < game.color_order.size():
			var current := L10n.text(String(game.color_order[game.color_order_index]))
			parts.append(L10n.text("순서 ▶ %s") % L10n.text(String(G.COLOR_NAMES.get(current, current))))
	if game.escort_catcher >= 0:
		parts.append(L10n.text("🛡 호위"))
	if parts.is_empty():
		objective_card.visible = false
		return
	objective_card.visible = true
	objective_label.text = L10n.text("   ·   ".join(parts))
	if game.move_limit > 0 and game.moves_used >= int(float(game.move_limit) * 0.8):
		objective_label.add_theme_color_override("font_color", ArtDirection.ink())
	else:
		objective_label.add_theme_color_override("font_color", ArtDirection.ink())


func set_move_counter(_used: int, _limit: int) -> void:
	refresh_objectives()


func _build_booster_tray() -> void:
	var tray := PanelContainer.new()
	booster_tray = tray
	tray.position = Vector2(28, 1155)
	tray.size = Vector2(G.W - 56, 92)
	tray.add_theme_stylebox_override("panel", ArtDirection.panel(Color(0.12, 0.08, 0.22, 0.82), Color(1, 1, 1, 0.48), 25, 0.32, 3))
	ArtDirection.decorate_surface(tray, 25, Color("#c7edff"), 0.7)
	root.add_child(tray)
	tray.visible = game.level_idx >= 3
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 7)
	tray.add_child(row)
	var specs := [
		["time", L10n.text("시간 젤리")],
		["compass", L10n.text("구조 나침반")],
		["ice", L10n.text("햇살 스푼")],
		["space", L10n.text("공간 캔디")],
		["rescue", L10n.text("구조 호루라기")],
	]
	for spec in specs:
		var id := L10n.text(String(spec[0]))
		var count: int = game.main.save.get_booster_count(id)
		var button := Button.new()
		button.text = L10n.text("×%d" % count)
		button.tooltip_text = L10n.text(String(spec[1]))
		button.custom_minimum_size = Vector2(119, 62)
		button.add_theme_font_size_override("font_size", 19)
		button.icon = load("res://assets/ui/boosters/%s_v1.png" % id)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_constant_override("icon_max_width", 43)
		button.add_theme_constant_override("h_separation", 2)
		ArtDirection.apply_button(button, Color("#e48658") if id == "time" else Color("#6d8fd1"), 17)
		button.disabled = count <= 0
		button.pressed.connect(func(): game.use_booster(id))
		row.add_child(button)
		booster_buttons[id] = button


func _build_tutorial_help() -> void:
	tutorial_help_button = Button.new()
	tutorial_help_button.text = L10n.text("?")
	tutorial_help_button.position = Vector2(648, 154)
	tutorial_help_button.size = Vector2(52, 52)
	tutorial_help_button.add_theme_font_size_override("font_size", 27)
	ArtDirection.apply_button(tutorial_help_button, Color("#8d70bc"), 18)
	tutorial_help_button.tooltip_text = L10n.text("조작 안내 다시 보기")
	tutorial_help_button.visible = false
	tutorial_help_button.pressed.connect(func(): game.replay_tutorial())
	root.add_child(tutorial_help_button)


func set_tutorial_help_visible(value: bool) -> void:
	if tutorial_help_button:
		tutorial_help_button.visible = value


func show_tutorial_step(text: String, from: Vector2, to: Vector2, focus: Rect2 = Rect2()) -> void:
	clear_tutorial_step()
	tutorial_guide = TutorialGuideScene.new()
	root.add_child(tutorial_guide)
	tutorial_guide.setup(text, from, to, focus)


func clear_tutorial_step() -> void:
	if tutorial_guide and is_instance_valid(tutorial_guide):
		tutorial_guide.dismiss()
	tutorial_guide = null


func show_signature_intro(signature: Dictionary, on_start: Callable) -> void:
	## 5레벨마다 목표를 감정적인 사건으로 바꿔 기억에 남는 진입 장면을 만든다.
	var dim := ColorRect.new()
	dim.color = ArtDirection.dim_color()
	_fit_overlay_to_viewport(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(570, 0)
	var accent := Color(L10n.text(String(signature.get("accent", "#ff7f94"))))
	var style := ArtDirection.glass_panel(accent.lightened(0.42), 0.99, 36)
	style.border_color = ArtDirection.border_color()
	style.set_border_width_all(1)
	style.content_margin_left = 42
	style.content_margin_right = 42
	style.content_margin_top = 34
	style.content_margin_bottom = 34
	panel.add_theme_stylebox_override("panel", style)
	ArtDirection.decorate_surface(panel, 36, Color.WHITE, 0.82)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)
	var eyebrow := Label.new()
	eyebrow.text = L10n.text(String(signature.get("eyebrow", L10n.text("특별 구조 작전"))))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 19)
	eyebrow.add_theme_color_override("font_color", ArtDirection.text_color(accent.darkened(0.28)))
	content.add_child(eyebrow)
	var title := Label.new()
	title.text = L10n.text(String(signature.get("title", L10n.text("특별 구조"))))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(title)
	var mascot := TextureRect.new()
	mascot.texture = G.hero_tex()
	mascot.custom_minimum_size = Vector2(150, 130)
	mascot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mascot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(mascot)
	var objective := Label.new()
	objective.text = L10n.text(String(signature.get("objective", L10n.text("모든 젤리몬을 구조해요"))))
	objective.custom_minimum_size = Vector2(480, 0)
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.add_theme_font_size_override("font_size", 23)
	objective.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(objective)
	var start := Button.new()
	start.text = L10n.text(tr("구조 작전 시작"))
	start.custom_minimum_size = Vector2(390, 76)
	start.add_theme_font_size_override("font_size", 28)
	ArtDirection.apply_button(start, accent, 23)
	start.pressed.connect(func():
		dim.queue_free()
		if on_start.is_valid(): on_start.call()
	)
	content.add_child(start)


func refresh_boosters() -> void:
	var activity_blocks_boosters: bool = not game.main.active_activity.is_empty() and String(game.main.active_activity.get("modifier", {}).get("id", "")) == "no_boosters"
	for id in booster_buttons:
		var button: Button = booster_buttons[id]
		var count: int = game.main.save.get_booster_count(L10n.text(String(id)))
		button.text = L10n.text("×%d" % count)
		button.disabled = count <= 0 or game.state != "play" or activity_blocks_boosters
		button.tooltip_text = L10n.text("맨손 구조 규칙에서는 사용할 수 없어요") if activity_blocks_boosters else ""


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
		if game.main.active_activity.is_empty():
			game.main.show_map()
		else:
			game.main.show_title()


func _on_retry_pressed() -> void:
	if game:
		confirm_retry(func():
			if game.main.active_activity.is_empty():
				game.main.start_level(game.level_idx)
			else:
				game.main.retry_active_activity()
		)


func confirm_retry(on_confirm: Callable) -> void:
	if is_instance_valid(retry_overlay):
		return
	var resume_play: bool = game.state == "play"
	if resume_play:
		game.set_paused(true)
		hide_pause()
	var dim := ColorRect.new()
	dim.name = "RetryConfirmation"
	dim.color = ArtDirection.dim_color()
	_fit_overlay_to_viewport(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 600
	root.add_child(dim)
	retry_overlay = dim
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 320)
	panel.add_theme_stylebox_override("panel", ArtDirection.panel(Color("#fff9f1"), Color("#76539a"), 34, 0.38, 5))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	panel.add_child(box)
	var title := Label.new()
	title.text = L10n.text(tr("모험을 다시 시작할까요?"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", ArtDirection.ink())
	box.add_child(title)
	var message := Label.new()
	message.text = L10n.text(tr("현재 모험을 처음부터 다시 시작합니다."))
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 22)
	message.add_theme_color_override("font_color", ArtDirection.ink())
	box.add_child(message)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 20)
	box.add_child(actions)
	retry_cancel = func():
		if not is_instance_valid(retry_overlay) or retry_overlay.is_queued_for_deletion():
			return
		retry_overlay.queue_free()
		retry_cancel = Callable()
		if resume_play:
			game.set_paused(false)
	var cancel := _big_button(tr("취소"), Color("#7888b5"))
	cancel.name = "CancelRetry"
	cancel.pressed.connect(retry_cancel)
	actions.add_child(cancel)
	var confirm := _big_button(tr("확인"), ArtDirection.CORAL)
	confirm.name = "ConfirmRetry"
	confirm.pressed.connect(func():
		if dim.is_queued_for_deletion():
			return
		confirm.disabled = true
		dim.queue_free()
		retry_cancel = Callable()
		if resume_play:
			game.set_paused(false)
		on_confirm.call()
	)
	actions.add_child(confirm)
	cancel.grab_focus()


func _input(event: InputEvent) -> void:
	if is_instance_valid(retry_overlay) and event.is_action_pressed("ui_cancel"):
		if retry_cancel.is_valid():
			retry_cancel.call()
		get_viewport().set_input_as_handled()


func setup(goals: Dictionary, level: Dictionary, level_idx: int) -> void:
	var activity_title: String = L10n.text(String(game.main.active_activity_title()))
	name_label.text = L10n.text("%s  ·  %s" % [activity_title, L10n.text(String(level.name))] if not activity_title.is_empty() else "LEVEL %d  %s" % [level_idx + 1, L10n.text(level.name)])
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
		l.add_theme_color_override("font_color", ArtDirection.ink())
		l.text = L10n.text(str(goals[k]))
		v.add_child(l)
		box.add_child(v)
		goal_items[k] = l


func set_goals(goals: Dictionary) -> void:
	for k in goals:
		if goal_items.has(k):
			var l: Label = goal_items[k]
			var n: int = goals[k]
			l.text = L10n.text(str(n))
			if n <= 0:
				l.text = L10n.text("OK!")
				l.add_theme_color_override("font_color", ArtDirection.text_color(Color(0.2, 0.7, 0.3)))


func set_time(t: float, total: float) -> void:
	var seconds := maxi(0, int(t))
	if seconds != _timer_second:
		_timer_second = seconds
		time_label.text = L10n.text("%d:%02d" % [seconds / 60, seconds % 60])
	if timer_bar:
		timer_bar.value = clampf(t / maxf(total, 0.01) * 100.0, 0.0, 100.0)
	var next_state := 2 if t <= 10.0 else (1 if t <= total * 0.2 else 0)
	if next_state == _timer_state:
		return
	_timer_state = next_state
	var text_color := ArtDirection.ink()
	if next_state == 2:
		text_color = ArtDirection.text_color(Color(0.95, 0.25, 0.3))
	elif next_state == 1:
		text_color = ArtDirection.text_color(Color(1.0, 0.55, 0.15))
	time_label.add_theme_color_override("font_color", text_color)
	if _timer_fill:
		# 시간 추가/이어하기로 위험 구간을 벗어나면 원래 색도 복원한다.
		_timer_fill.bg_color = ArtDirection.danger_color() if next_state == 2 else _timer_normal_color


func show_hint(text: String) -> void:
	if text.is_empty():
		return
	var hint_card := PanelContainer.new()
	hint_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint_card.offset_left = 54
	# 목표 요약 줄이 떠 있으면 그 아래로 밀어 겹치지 않게 한다.
	var hint_top := 206.0 if (objective_card and objective_card.visible) else 150.0
	hint_card.offset_top = hint_top
	hint_card.offset_right = -54
	# 복합 관문 안내는 세 줄까지 늘어나므로 줄 수에 맞춰 카드 높이를 잡는다.
	var lines := text.split("\n", false)
	# 후반 복합 레벨은 규칙을 전부 다시 읽히지 않고 지금 필요한 핵심 두 줄만
	# 보여 준다. 전체 규칙은 일시정지의 '규칙 다시 보기'에서 확인한다.
	if lines.size() > 2:
		lines = lines.slice(0, 2)
		text = "\n".join(lines)
	var line_count: int = maxi(1, lines.size())
	hint_card.offset_bottom = hint_top + 40.0 + 28.0 * float(line_count)
	hint_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint_style := ArtDirection.panel(Color(0.09, 0.13, 0.27, 0.84), Color(1, 1, 1, 0.48), 22, 0.26, 2)
	hint_style.content_margin_left = 20
	hint_style.content_margin_right = 20
	hint_style.content_margin_top = 9
	hint_style.content_margin_bottom = 10
	hint_card.add_theme_stylebox_override("panel", hint_style)
	root.add_child(hint_card)
	var l := Label.new()
	l.text = L10n.text(text)
	l.add_theme_font_size_override("font_size", 19 if game.level_idx >= 100 else 20)
	l.add_theme_color_override("font_color", ArtDirection.ink())
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.18, 0.92))
	l.add_theme_constant_override("outline_size", 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_card.add_child(l)
	var tw := hint_card.create_tween()
	tw.tween_interval(4.4 if game.level_idx <= 20 else 3.2)
	tw.tween_property(hint_card, "modulate:a", 0.0, 0.5)
	tw.tween_callback(hint_card.queue_free)


func show_pause() -> void:
	if pause_overlay and is_instance_valid(pause_overlay):
		return
	var dim := ColorRect.new()
	dim.color = ArtDirection.dim_color()
	_fit_overlay_to_viewport(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 500
	root.add_child(dim)
	pause_overlay = dim
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 520)
	panel.add_theme_stylebox_override("panel", ArtDirection.panel(Color("#fff9f1"), Color("#76539a"), 34, 0.38, 5))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var title := Label.new()
	title.text = L10n.text(tr("잠깐 쉬어갈까요?"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", ArtDirection.ink())
	box.add_child(title)
	var rule := Label.new()
	rule.text = L10n.text(tr(L10n.text(String(game.L.get("hint", L10n.text("같은 색 젤리몬부터 차례로 구조해요."))))))
	rule.custom_minimum_size = Vector2(470, 100)
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.add_theme_font_size_override("font_size", 19)
	rule.add_theme_color_override("font_color", ArtDirection.ink())
	box.add_child(rule)
	var resume := _big_button(tr("계속하기"), ArtDirection.CORAL)
	resume.pressed.connect(func(): game.set_paused(false))
	box.add_child(resume)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	var retry := _result_button(tr("처음부터"), Color("#e79852"))
	retry.pressed.connect(_on_retry_pressed)
	actions.add_child(retry)
	var leave := _result_button(tr("레벨 선택"), Color("#7888b5"))
	leave.pressed.connect(func():
		game.set_paused(false)
		_on_quit_pressed()
	)
	actions.add_child(leave)


func hide_pause() -> void:
	if pause_overlay and is_instance_valid(pause_overlay):
		pause_overlay.queue_free()
	pause_overlay = null


# ────────────────────────── 팝업 ──────────────────────────

func _small_button(icon_kind: String, col: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(66, 72)
	_style_button(b, col)
	var icon := BattleHUDIconScene.new()
	icon.setup(icon_kind)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(icon)
	return b


func _big_button(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = L10n.text(tr(text))
	b.custom_minimum_size = Vector2(210, 80)
	b.add_theme_font_size_override("font_size", 32)
	_style_button(b, col)
	return b


func _result_button(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = L10n.text(tr(text))
	b.custom_minimum_size = Vector2(142, 76)
	b.add_theme_font_size_override("font_size", 27)
	_style_button(b, col)
	return b


func _style_button(b: Button, col: Color) -> void:
	ArtDirection.apply_button(b, col, 20)
	b.add_theme_color_override("font_disabled_color", ArtDirection.text_color(col.darkened(0.34)))


func _set_reward_complete_style(button: Button) -> void:
	var completed := StyleBoxFlat.new()
	completed.bg_color = ArtDirection.selected_color()
	completed.border_color = ArtDirection.border_color()
	completed.set_border_width_all(1)
	completed.set_corner_radius_all(20)
	completed.corner_detail = 12
	completed.shadow_color = Color(0.35, 0.22, 0.12, 0.10)
	completed.shadow_size = 3
	completed.shadow_offset = Vector2(0, 2)
	completed.content_margin_top = 8
	completed.content_margin_bottom = 12
	button.add_theme_stylebox_override("disabled", completed)
	button.add_theme_color_override("font_disabled_color", ArtDirection.success_color())
	button.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))


func _popup_frame() -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = ArtDirection.dim_color()
	_fit_overlay_to_viewport(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var panel := PanelContainer.new()
	var sb := ArtDirection.glass_panel(Color("#fff8ed"), 0.98, 34)
	sb.set_border_width_all(1)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 36
	sb.content_margin_bottom = 36
	panel.add_theme_stylebox_override("panel", sb)
	ArtDirection.decorate_surface(panel, 34, Color("#ffffff"), 0.7)
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
	l.text = L10n.text(tr(text))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 56)
	l.add_theme_color_override("font_color", ArtDirection.text_color(col))
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 0)
	return l


func show_result(stars_n: int, score: int, stardust_reward: int, stardust_total: int, clear_time: float, best_time: float, has_next: bool, on_next: Callable, on_map: Callable, on_retry: Callable) -> void:
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
	v.add_child(_title_label(tr("클리어!"), Color(1.0, 0.5, 0.35)))
	var new_resident: Dictionary = game.main.last_new_resident
	if not new_resident.is_empty():
		var resident_card := PanelContainer.new()
		resident_card.custom_minimum_size = Vector2(430, 118)
		resident_card.add_theme_stylebox_override("panel", ArtDirection.panel(Color("#fff0f7"), G.COLORS[String(new_resident.get("color", "R"))].darkened(0.2), 24, 0.3, 4))
		var resident_row := HBoxContainer.new()
		resident_card.add_child(resident_row)
		var portrait := TextureRect.new()
		portrait.texture = CharacterCatalog.character_texture(String(new_resident.get("color", "R")))
		portrait.custom_minimum_size = Vector2(105, 100)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		resident_row.add_child(portrait)
		var reveal := VBoxContainer.new()
		reveal.alignment = BoxContainer.ALIGNMENT_CENTER
		resident_row.add_child(reveal)
		var joined := Label.new()
		joined.text = L10n.text("새 주민이 찾아왔어요!")
		joined.add_theme_font_size_override("font_size", 18)
		joined.add_theme_color_override("font_color", ArtDirection.danger_color())
		reveal.add_child(joined)
		var resident_name := Label.new()
		resident_name.text = L10n.text("%s · %s" % [L10n.text(String(new_resident.get("name", L10n.text("젤리몬")))), L10n.text(String(new_resident.get("personality", L10n.text("다정한 친구"))))])
		resident_name.add_theme_font_size_override("font_size", 23)
		resident_name.add_theme_color_override("font_color", ArtDirection.ink())
		reveal.add_child(resident_name)
		var origin := Label.new()
		origin.text = L10n.text("LEVEL %d에서 구조 · 아지트 입주 완료") % int(new_resident.get("rescued_level", game.level_idx + 1))
		origin.add_theme_font_size_override("font_size", 15)
		origin.add_theme_color_override("font_color", ArtDirection.ink())
		reveal.add_child(origin)
		v.add_child(resident_card)
	var signature: Dictionary = game.L.get("signature", {})
	if not signature.is_empty():
		var finale := Label.new()
		finale.text = L10n.text("✦  %s" % L10n.text(String(signature.get("reward_line", L10n.text("특별 구조를 완수했어요!")))))
		finale.custom_minimum_size = Vector2(470, 0)
		finale.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		finale.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		finale.add_theme_font_size_override("font_size", 21)
		finale.add_theme_color_override("font_color", ArtDirection.text_color(Color(L10n.text(String(signature.get("accent", "#db6f88")))).darkened(0.2)))
		v.add_child(finale)
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
	sc.text = L10n.text(tr("점수  %d") % score)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sc.add_theme_font_size_override("font_size", 34)
	sc.add_theme_color_override("font_color", ArtDirection.ink())
	v.add_child(sc)
	var record := Label.new()
	record.text = L10n.text(tr("클리어  %s   ·   최고 기록  %s") % [_format_clear_time(clear_time), _format_clear_time(best_time)])
	record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	record.add_theme_font_size_override("font_size", 23)
	record.add_theme_color_override("font_color", ArtDirection.ink())
	v.add_child(record)
	var dust := Label.new()
	clear_reward_label = dust
	dust.text = L10n.text("★ 별가루 +%d   보유 %d") % [stardust_reward, stardust_total] if stardust_reward > 0 else L10n.text("★ 이미 받은 별 보상이에요   보유 %d") % stardust_total
	dust.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dust.add_theme_font_size_override("font_size", 25)
	dust.add_theme_color_override("font_color", ArtDirection.ink())
	v.add_child(dust)
	var furniture_reward: Dictionary = game.main.last_furniture_reward
	if not furniture_reward.is_empty():
		var furniture := RoomData.item_by_id(L10n.text(String(furniture_reward.get("furniture_id", ""))))
		var reward_label := Label.new()
		reward_label.text = L10n.text("🎁 %d레벨 기념 가구 · %s 획득!") % [int(furniture_reward.get("level", game.level_idx + 1)), L10n.text(String(furniture.get("name", furniture_reward.get("title", L10n.text("기념 가구")))))]
		reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_label.add_theme_font_size_override("font_size", 23)
		reward_label.add_theme_color_override("font_color", ArtDirection.ink())
		reward_label.add_theme_color_override("font_outline_color", Color.WHITE)
		reward_label.add_theme_constant_override("outline_size", 0)
		v.add_child(reward_label)
	if stardust_reward > 0:
		clear_double_button = _big_button(tr("VIP 오늘의 무료 2배") if game.main.save.can_skip_rewarded_ad("clear_reward_double") else L10n.text("광고 보고 보상 2배"), Color("#8e64c8"))
		clear_double_button.custom_minimum_size = Vector2(430, 72)
		clear_double_button.pressed.connect(_request_clear_double_reward)
		v.add_child(clear_double_button)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 12)
	v.add_child(btns)
	var b_home := _result_button(L10n.text("모험"), Color("#55a9d8"))
	b_home.tooltip_text = L10n.text("모험 레벨 선택으로")
	b_home.pressed.connect(on_map)
	btns.add_child(b_home)
	var b_retry := _result_button(tr("다시"), Color(0.62, 0.56, 0.72))
	b_retry.pressed.connect(func(): confirm_retry(on_retry))
	btns.add_child(b_retry)
	if has_next:
		var b_next := _result_button(tr("다음 레벨"), ArtDirection.CORAL)
		b_next.pressed.connect(on_next)
		btns.add_child(b_next)


static func _format_clear_time(seconds: float) -> String:
	var centiseconds := maxi(0, int(round(seconds * 100.0)))
	return "%d:%02d.%02d" % [centiseconds / 6000, (centiseconds / 100) % 60, centiseconds % 100]


func _request_clear_double_reward() -> void:
	if clear_bonus_claimed or clear_base_reward <= 0 or not clear_double_button:
		return
	clear_double_button.disabled = true
	clear_double_button.text = L10n.text(tr("2배 보상 지급 중...") if game.main.save.can_skip_rewarded_ad("clear_reward_double") else L10n.text("광고 재생 중..."))
	game.main.request_rewarded_ad(_finish_clear_double_reward, _restore_clear_double_button, "clear_reward_double")


func _finish_clear_double_reward() -> void:
	if clear_bonus_claimed or clear_base_reward <= 0 or not is_instance_valid(clear_double_button):
		return
	if not game.main.save.grant_stardust(clear_base_reward):
		_restore_clear_double_button()
		return
	if game.main.analytics:
		game.main.analytics.track("currency_source", {"currency": "stardust", "amount": clear_base_reward, "source": "clear_reward_double"})
	clear_bonus_claimed = true
	clear_double_button.text = L10n.text(tr("✓ 2배 보상 받음"))
	_set_reward_complete_style(clear_double_button)
	clear_double_button.disabled = true
	clear_reward_label.text = L10n.text("★ 별가루 +%d  · 2배 완료!   보유 %d") % [clear_base_reward * 2, game.main.save.get_stardust()]
	clear_reward_label.add_theme_color_override("font_color", ArtDirection.danger_color())
	game.audio.play("shiny", 1.12)
	game.fx.sparkle(Vector2(G.W * 0.5, 470), 22)
	G.haptic(24)


func _restore_clear_double_button() -> void:
	if not is_instance_valid(clear_double_button) or clear_bonus_claimed:
		return
	clear_double_button.disabled = false
	clear_double_button.text = L10n.text(tr("VIP 오늘의 무료 2배") if game.main.save.can_skip_rewarded_ad("clear_reward_double") else L10n.text("광고 보고 보상 2배"))
	if clear_reward_label:
		var reason := L10n.text(String(game.main.platform.rewarded_ad_message)) if game.main.platform else ""
		clear_reward_label.text = L10n.text("광고를 끝까지 시청해야 2배 보상을 받을 수 있어요.") if reason.contains("완료되지") else L10n.text("광고를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")


func show_fail(reason: String, stardust_total: int, continue_available: bool, on_continue: Callable, on_retry: Callable, on_map: Callable) -> void:
	var v := _popup_frame()
	var dim: Control = v.get_parent().get_parent().get_parent()
	v.add_child(_title_label(L10n.text("아쉬워요!"), Color(0.55, 0.48, 0.68)))
	var l := Label.new()
	l.text = L10n.text(reason)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", ArtDirection.ink())
	v.add_child(l)
	var tip := Label.new()
	tip.text = (L10n.text("현재 보드 그대로, 시간만 처음부터 다시 시작해요.\n보유 별가루  ★ %d") % stardust_total
		if continue_available else L10n.text("이번 도전의 재시도 기회를 이미 사용했어요.\n처음부터 다시 도전하거나 모험으로 돌아가 주세요."))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 24)
	tip.add_theme_color_override("font_color", ArtDirection.text_color(Color(0.6, 0.55, 0.7)))
	v.add_child(tip)
	var b_continue := _big_button(tr("★ 20  이어하기"), ArtDirection.CORAL)
	b_continue.custom_minimum_size = Vector2(430, 78)
	b_continue.disabled = not continue_available or stardust_total < 20
	if not continue_available:
		b_continue.text = L10n.text("✓ 재시도 사용 완료")
	elif b_continue.disabled:
		b_continue.text = L10n.text("별가루가 부족해요  (%d/20)") % stardust_total
	b_continue.pressed.connect(func():
		if bool(on_continue.call()):
			dim.queue_free()
	)
	v.add_child(b_continue)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 18)
	v.add_child(btns)
	var b_map := _result_button(tr("그만"), Color(0.62, 0.56, 0.72))
	b_map.pressed.connect(on_map)
	btns.add_child(b_map)
	var b_retry := _result_button(tr("처음부터"), Color(1.0, 0.55, 0.25))
	b_retry.pressed.connect(func(): confirm_retry(on_retry))
	btns.add_child(b_retry)
