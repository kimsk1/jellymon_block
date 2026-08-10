extends Control
class_name StoryScreen
## 인트로·챕터 시나리오 공용 플레이어. 탭으로 타이핑 완료/다음 대사를 진행한다.

var main = null
var sequence: Dictionary = {}
var on_finished := Callable()

var lines: Array = []
var line_index := 0
var full_text := ""
var revealed := 0.0
var typing := false
var typing_speed := 32.0
var last_advance_msec := -1000
var auto_advance_token := 0
var auto_advance_due_msec := -1

const ADVANCE_DEBOUNCE_MS := 120
const AUTO_ADVANCE_DELAY_SEC := 2.5

var background: TextureRect
var shade: ColorRect
var header_panel: PanelContainer
var skip_button: Button
var dialogue_panel: PanelContainer
var speaker_label: Label
var dialogue_label: RichTextLabel
var progress_label: Label
var portrait: TextureRect
var continue_label: Label


func _ready() -> void:
	position = G.safe_offset(get_viewport_rect().size)
	size = Vector2(G.W, G.H)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	lines = sequence.get("lines", [])
	_build_ui()
	if lines.is_empty():
		_finish()
		return
	_show_line(0)


func _apply_responsive_layout() -> void:
	position = G.safe_offset(get_viewport_rect().size)
	size = Vector2(G.W, G.H)
	if background:
		background.position = -G.safe_offset(get_viewport_rect().size)
		background.size = get_viewport_rect().size
	if shade:
		shade.position = background.position
		shade.size = background.size
	_layout_story_ui()


func _local_safe_insets() -> Vector2:
	## OS 카메라 홀/둥근 모서리 안전 영역을 720×1280 로컬 캔버스 좌표로 환산한다.
	if DisplayServer.get_name() == "headless":
		return Vector2.ZERO
	var screen_index := DisplayServer.window_get_current_screen()
	var screen_size := Vector2(DisplayServer.screen_get_size(screen_index))
	var screen_position := Vector2(DisplayServer.screen_get_position(screen_index))
	var safe_rect := Rect2(DisplayServer.get_display_safe_area())
	if screen_size.x <= 0.0 or screen_size.y <= 0.0 or safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return Vector2.ZERO
	var viewport_size := get_viewport_rect().size
	var canvas_offset := G.safe_offset(viewport_size)
	# macOS 다중 모니터에서는 safe_rect가 전역 화면 좌표이므로 현재 화면 원점을 제거한다.
	var safe_local_position := safe_rect.position - screen_position
	var mapped_top := safe_local_position.y * viewport_size.y / screen_size.y
	var physical_bottom := screen_size.y - (safe_local_position.y + safe_rect.size.y)
	var mapped_bottom := physical_bottom * viewport_size.y / screen_size.y
	# 잘못된 플랫폼 리포트가 전체 UI를 밀지 않도록 일반적인 모바일 컷아웃 범위로 제한한다.
	return Vector2(
		clampf(mapped_top - canvas_offset.y, 0.0, 140.0),
		clampf(mapped_bottom - canvas_offset.y, 0.0, 140.0)
	)


func _layout_story_ui() -> void:
	if not header_panel or not dialogue_panel:
		return
	var insets := _local_safe_insets()
	# 상단 카드는 카메라 홀 아래, 본문 카드는 하단에서 넉넉히 띄워 배경과 균형을 맞춘다.
	var header_y := maxf(22.0, insets.x + 12.0)
	header_panel.position = Vector2(22, header_y)
	skip_button.position = Vector2(548, header_y + 21)
	var panel_height := 360.0
	var bottom_air := maxf(150.0, insets.y + 92.0)
	var panel_min_y := minf(header_y + 390.0, 790.0)
	var panel_y := clampf(G.H - panel_height - bottom_air, panel_min_y, 790.0)
	dialogue_panel.position = Vector2(28, panel_y)
	dialogue_panel.size = Vector2(664, panel_height)
	portrait.position.y = panel_y - 172.0
	speaker_label.position = Vector2(60, panel_y + 24)
	progress_label.position = Vector2(532, panel_y + 34)
	dialogue_label.position = Vector2(60, panel_y + 82)
	dialogue_label.size = Vector2(600, 212)
	continue_label.position = Vector2(380, panel_y + panel_height - 50)


func _panel_style(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(4)
	style.set_corner_radius_all(radius)
	style.corner_detail = 12
	style.shadow_color = Color(0.08, 0.03, 0.15, 0.42)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 8)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


func _build_ui() -> void:
	background = TextureRect.new()
	background.texture = load(String(sequence.get("background_asset", "res://assets/backgrounds/jelly_sky_v2.png")))
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.position = -G.safe_offset(get_viewport_rect().size)
	background.size = get_viewport_rect().size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	shade = ColorRect.new()
	shade.color = Color(0.06, 0.02, 0.12, 0.14)
	shade.position = background.position
	shade.size = background.size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	header_panel = PanelContainer.new()
	header_panel.position = Vector2(22, 22)
	header_panel.size = Vector2(676, 112)
	header_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.18, 0.09, 0.28, 0.86), Color(1, 1, 1, 0.74), 26))
	add_child(header_panel)
	var heading := VBoxContainer.new()
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	header_panel.add_child(heading)
	var title := Label.new()
	title.text = String(sequence.get("title", "젤리몬 이야기"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color("#4d3266"))
	title.add_theme_constant_override("outline_size", 4)
	heading.add_child(title)
	var subtitle := Label.new()
	subtitle.text = String(sequence.get("subtitle", ""))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 19)
	subtitle.add_theme_color_override("font_color", Color("#f5d9ff"))
	subtitle.visible = not subtitle.text.is_empty()
	heading.add_child(subtitle)

	skip_button = Button.new()
	skip_button.text = "건너뛰기  »"
	skip_button.position = Vector2(548, 43)
	skip_button.size = Vector2(130, 64)
	skip_button.add_theme_font_size_override("font_size", 18)
	skip_button.add_theme_color_override("font_color", Color.WHITE)
	skip_button.add_theme_stylebox_override("normal", _panel_style(Color(0.25, 0.14, 0.34, 0.76), Color(1, 1, 1, 0.42), 18))
	skip_button.add_theme_stylebox_override("hover", skip_button.get_theme_stylebox("normal").duplicate())
	skip_button.add_theme_stylebox_override("pressed", skip_button.get_theme_stylebox("normal").duplicate())
	skip_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	skip_button.pressed.connect(_finish)
	add_child(skip_button)

	portrait = TextureRect.new()
	portrait.position = Vector2(42, 674)
	portrait.size = Vector2(190, 190)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.pivot_offset = portrait.size * 0.5
	add_child(portrait)

	dialogue_panel = PanelContainer.new()
	dialogue_panel.position = Vector2(28, 846)
	dialogue_panel.size = Vector2(664, 380)
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_panel.add_theme_stylebox_override("panel", _panel_style(Color(1.0, 0.97, 1.0, 0.95), Color("#765493"), 30))
	add_child(dialogue_panel)

	speaker_label = Label.new()
	speaker_label.position = Vector2(60, 872)
	speaker_label.size = Vector2(420, 48)
	speaker_label.add_theme_font_size_override("font_size", 27)
	speaker_label.add_theme_color_override("font_color", Color("#65417d"))
	speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(speaker_label)

	progress_label = Label.new()
	progress_label.position = Vector2(532, 882)
	progress_label.size = Vector2(110, 36)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.add_theme_font_size_override("font_size", 17)
	progress_label.add_theme_color_override("font_color", Color("#9a83a2"))
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(progress_label)

	dialogue_label = RichTextLabel.new()
	dialogue_label.position = Vector2(60, 930)
	dialogue_label.size = Vector2(600, 215)
	dialogue_label.fit_content = false
	dialogue_label.scroll_active = false
	dialogue_label.add_theme_font_size_override("normal_font_size", 28)
	dialogue_label.add_theme_color_override("default_color", Color("#422c50"))
	dialogue_label.add_theme_constant_override("line_separation", 8)
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dialogue_label)

	continue_label = Label.new()
	continue_label.text = "▼  화면을 탭해 계속"
	continue_label.position = Vector2(400, 1170)
	continue_label.size = Vector2(250, 34)
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	continue_label.add_theme_font_size_override("font_size", 17)
	continue_label.add_theme_color_override("font_color", Color("#8b6f96"))
	continue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(continue_label)
	_layout_story_ui()


func _process(delta: float) -> void:
	if typing:
		revealed += typing_speed * delta
		dialogue_label.visible_characters = mini(full_text.length(), int(revealed))
		if dialogue_label.visible_characters >= full_text.length():
			_complete_current_line()
	if continue_label and continue_label.visible:
		continue_label.modulate.a = 0.7 + sin(Time.get_ticks_msec() * 0.006) * 0.25
		if auto_advance_due_msec > 0:
			var remaining := maxf(0.0, float(auto_advance_due_msec - Time.get_ticks_msec()) / 1000.0)
			continue_label.text = "▼  %.1f초 후 다음 · 탭해서 계속" % remaining


func _on_gui_input(event: InputEvent) -> void:
	var pressed: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	pressed = pressed or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	accept_event()
	_request_advance(Time.get_ticks_msec())


func _request_advance(now_msec: int) -> bool:
	## 모바일/에디터에서 한 번의 탭이 MouseButton+ScreenTouch로 중복 전달되는 것을 막는다.
	if now_msec - last_advance_msec < ADVANCE_DEBOUNCE_MS:
		return false
	last_advance_msec = now_msec
	_advance()
	return true


func _advance() -> void:
	if typing:
		_complete_current_line()
		return
	if line_index + 1 >= lines.size():
		_finish()
		return
	_show_line(line_index + 1)


func _show_line(index: int) -> void:
	# 이전 문장에 예약된 자동 진행 콜백을 무효화한다.
	auto_advance_token += 1
	auto_advance_due_msec = -1
	line_index = index
	var line: Dictionary = lines[line_index]
	var speaker_id := String(line.get("speaker", "narrator"))
	var cast: Dictionary = sequence.get("cast", {})
	var speaker: Dictionary = cast.get(speaker_id, {"name": "이야기"})
	speaker_label.text = _replace_variables(String(speaker.get("name", "이야기")))
	full_text = _replace_variables(String(line.get("text", "")))
	# 이전 문장의 완성 상태(-1 또는 전체 글자 수)를 지운 뒤 새 문장을 0글자부터 시작한다.
	dialogue_label.visible_characters = -1
	dialogue_label.text = full_text
	dialogue_label.visible_characters = 0
	revealed = 0.0
	typing = true
	continue_label.visible = false
	progress_label.text = "%d / %d" % [line_index + 1, lines.size()]
	_update_portrait(speaker_id, String(line.get("portrait_side", "left")))
	main.audio.play("grab", 1.0 + float(line_index % 3) * 0.04, -8.0)


func _complete_current_line() -> void:
	if not typing:
		return
	dialogue_label.visible_characters = full_text.length()
	typing = false
	continue_label.visible = true
	_schedule_auto_advance()


func _schedule_auto_advance() -> void:
	## 타이핑 완료 시점(탭으로 즉시 완성한 경우 포함)부터 정확히 2.5초를 센다.
	var token := auto_advance_token
	auto_advance_due_msec = Time.get_ticks_msec() + int(AUTO_ADVANCE_DELAY_SEC * 1000.0)
	await get_tree().create_timer(AUTO_ADVANCE_DELAY_SEC).timeout
	if token != auto_advance_token or typing or sequence.is_empty():
		return
	auto_advance_due_msec = -1
	_advance()


func debug_validate_typewriter_advance() -> bool:
	## 다음 탭과 함께 들어오는 중복 이벤트가 새 문장을 즉시 완성하지 않는지 검증한다.
	if lines.size() < 2:
		return false
	_show_line(0)
	typing = false
	dialogue_label.visible_characters = full_text.length()
	continue_label.visible = true
	last_advance_msec = -1000
	var first_accepted := _request_advance(1000)
	var duplicate_accepted := _request_advance(1001)
	return first_accepted and not duplicate_accepted and line_index == 1 and typing and revealed == 0.0 and dialogue_label.visible_characters == 0


func debug_start_auto_advance_test() -> void:
	_show_line(0)
	_complete_current_line()


func _replace_variables(value: String) -> String:
	var nickname: String = main.save.get_nickname()
	if nickname.is_empty():
		nickname = "구출 대원"
	return value.replace("{player_name}", nickname)


func _update_portrait(speaker_id: String, side: String) -> void:
	var color_by_speaker := {
		"mallow": "R", "starbean": "Y", "bubble": "B",
		"sprout": "G", "popo": "P", "cacao_king": "P"
	}
	portrait.visible = color_by_speaker.has(speaker_id)
	if not portrait.visible:
		return
	var portrait_color := String(color_by_speaker[speaker_id])
	portrait.texture = G.hero_tex() if portrait_color == "R" else G.jelly_tex(portrait_color)
	portrait.modulate = Color("#60445f") if speaker_id == "cacao_king" else Color.WHITE
	portrait.position.x = 488 if side == "right" else 42
	portrait.scale = Vector2(1.08, 1.08)
	portrait.create_tween().tween_property(portrait, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _finish() -> void:
	if sequence.is_empty():
		return
	auto_advance_token += 1
	auto_advance_due_msec = -1
	var sequence_id := String(sequence.get("sequence_id", ""))
	sequence = {}
	if not sequence_id.is_empty():
		main.save.mark_scenario_seen(sequence_id)
	var callback := on_finished
	queue_free()
	if callback.is_valid():
		callback.call_deferred()
