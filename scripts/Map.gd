extends Control
class_name MapScreen
## 레벨 선택 화면 (04 문서 3장 간소판)

var main = null
var star_tex: Texture2D
var stardust_label: Label
var energy_label: Label
var energy_timer_label: Label
var empty_energy_timer_label: Label
var _last_energy_second := -1
var background: TextureRect

const BTN_COLORS := [
	Color(1.0, 0.45, 0.55), Color(1.0, 0.65, 0.3), Color(0.35, 0.7, 0.95),
	Color(0.4, 0.78, 0.45), Color(0.7, 0.5, 0.9), Color(0.95, 0.55, 0.75),
]


func _ready() -> void:
	star_tex = load("res://assets/fx/ui_star.png")
	_apply_responsive_layout()
	get_viewport().size_changed.connect(_apply_responsive_layout)

	background = TextureRect.new()
	background.texture = ArtDirection.background_texture()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(1, 1, 1, 0.9)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_layout_background()
	_add_stardust_panel()
	_add_energy_panel()

	var title := Label.new()
	title.text = "레벨 선택"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.42, 0.32, 0.56))
	title.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.92))
	title.add_theme_constant_override("outline_size", 10)
	title.position = Vector2(0, 90)
	title.size = Vector2(G.W, 80)
	add_child(title)

	# 레벨 목록과 배경을 명확하게 구분하는 라운드 스크롤 패널.
	var scroll_frame := PanelContainer.new()
	scroll_frame.position = Vector2(20, 178)
	scroll_frame.size = Vector2(G.W - 40, G.H - 382)
	scroll_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := ArtDirection.glass_panel(Color("#fff8ef"), 0.76, 32)
	frame_style.set_border_width_all(5)
	scroll_frame.add_theme_stylebox_override("panel", frame_style)
	add_child(scroll_frame)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28, 190)
	# 하단 홈 버튼의 전용 공간을 확보해 마지막 레벨 카드와 겹치지 않게 한다.
	scroll.size = Vector2(G.W - 56, G.H - 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.scroll_deadzone = 8
	scroll.follow_focus = false
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scroll)

	var chapters := VBoxContainer.new()
	# 스크롤 패널의 전체 안쪽 폭을 사용해 5열 카드의 좌우 여백을 동일하게 맞춘다.
	chapters.custom_minimum_size = Vector2(G.W - 56, 0)
	chapters.add_theme_constant_override("separation", 34)
	chapters.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(chapters)
	for chapter in range(Levels.visible_chapter_count(main.save)):
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 14)
		section.mouse_filter = Control.MOUSE_FILTER_PASS
		chapters.add_child(section)
		var chapter_title := Label.new()
		chapter_title.text = "CHAPTER %d  %s" % [chapter + 1, Levels.CHAPTER_NAMES[chapter]]
		chapter_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chapter_title.add_theme_font_size_override("font_size", 34)
		chapter_title.add_theme_color_override("font_color", Levels.CHAPTER_COLORS[chapter].darkened(0.28))
		section.add_child(chapter_title)
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		grid.mouse_filter = Control.MOUSE_FILTER_PASS
		var grid_center := CenterContainer.new()
		grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid_center.mouse_filter = Control.MOUSE_FILTER_PASS
		section.add_child(grid_center)
		grid_center.add_child(grid)
		for local in range(10):
			grid.add_child(_level_button(chapter * 10 + local))

	var back := Button.new()
	back.text = "홈으로"
	back.custom_minimum_size = Vector2(220, 76)
	back.add_theme_font_size_override("font_size", 30)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.62, 0.56, 0.72)
	sb.border_color = Color(0.42, 0.34, 0.58)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(20)
	sb.shadow_color = Color(0.1, 0.06, 0.18, 0.3)
	sb.shadow_size = 7
	sb.shadow_offset = Vector2(0, 5)
	back.add_theme_stylebox_override("normal", sb)
	var sb2: StyleBoxFlat = sb.duplicate()
	sb2.bg_color = sb.bg_color.darkened(0.15)
	back.add_theme_stylebox_override("hover", sb2)
	back.add_theme_stylebox_override("pressed", sb2)
	back.add_theme_color_override("font_color", Color.WHITE)
	# 스크롤 패널 아래와 화면 바닥 사이의 여백 중앙에 배치한다.
	back.position = Vector2(G.W / 2 - 110, G.H - 142)
	back.pressed.connect(_on_back)
	add_child(back)
	_update_energy_display()


func _apply_responsive_layout() -> void:
	position = G.safe_offset(get_viewport_rect().size)
	size = Vector2(G.W, G.H)
	_layout_background()


func _layout_background() -> void:
	if not background:
		return
	var viewport_size := get_viewport_rect().size
	background.position = -G.safe_offset(viewport_size)
	background.size = viewport_size


func _fit_overlay_to_viewport(control: Control) -> void:
	var viewport_size := get_viewport_rect().size
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = -G.safe_offset(viewport_size)
	control.size = viewport_size


func _process(_delta: float) -> void:
	var now := int(Time.get_unix_time_from_system())
	if now != _last_energy_second:
		_last_energy_second = now
		_update_energy_display()


func _add_energy_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(G.W - 224, 24)
	panel.size = Vector2(196, 64)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.96, 0.98, 0.94)
	style.border_color = Color("#dc6685")
	style.set_border_width_all(4)
	style.set_corner_radius_all(22)
	style.shadow_color = Color(0.18, 0.08, 0.2, 0.24)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 13
	style.content_margin_right = 13
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	energy_label = Label.new()
	energy_label.add_theme_font_size_override("font_size", 28)
	energy_label.add_theme_color_override("font_color", Color("#e84f73"))
	row.add_child(energy_label)
	energy_timer_label = Label.new()
	energy_timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	energy_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	energy_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	energy_timer_label.add_theme_font_size_override("font_size", 17)
	energy_timer_label.add_theme_color_override("font_color", Color("#685575"))
	row.add_child(energy_timer_label)


func _add_stardust_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(28, 24)
	panel.size = Vector2(205, 64)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.95, 1.0, 0.96)
	style.border_color = Color("#9b78d0")
	style.set_border_width_all(4)
	style.set_corner_radius_all(22)
	style.shadow_color = Color(0.18, 0.08, 0.2, 0.24)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	stardust_label = Label.new()
	stardust_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stardust_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stardust_label.add_theme_font_size_override("font_size", 24)
	stardust_label.add_theme_color_override("font_color", Color("#7150a3"))
	panel.add_child(stardust_label)


func _energy_time_text() -> String:
	var seconds: int = main.save.seconds_until_next_energy()
	return "%02d:%02d" % [seconds / 60, seconds % 60]


func _update_energy_display() -> void:
	if main == null or energy_label == null:
		return
	var current: int = main.save.get_energy()
	stardust_label.text = "★ 별가루 %d" % main.save.get_stardust()
	energy_label.text = "♥ %d/%d" % [current, SaveGame.MAX_ENERGY]
	energy_timer_label.text = "가득 참" if current >= SaveGame.MAX_ENERGY else "다음 " + _energy_time_text()
	if empty_energy_timer_label:
		empty_energy_timer_label.text = "지금 도전할 수 있어요!" if current > 0 else "다음 행동력  " + _energy_time_text()


func show_energy_empty() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.16, 0.58)
	_fit_overlay_to_viewport(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fffaf0")
	style.border_color = Color("#da6687")
	style.set_border_width_all(5)
	style.set_corner_radius_all(30)
	style.shadow_color = Color(0.1, 0.04, 0.18, 0.38)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 9)
	style.content_margin_left = 42
	style.content_margin_right = 42
	style.content_margin_top = 34
	style.content_margin_bottom = 34
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(400, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var heart := Label.new()
	heart.text = "♥"
	heart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heart.add_theme_font_size_override("font_size", 74)
	heart.add_theme_color_override("font_color", Color("#ef5d7d"))
	box.add_child(heart)
	var title := Label.new()
	title.text = "행동력이 부족해요"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", G.INK)
	box.add_child(title)
	var guide := Label.new()
	guide.text = "10분마다 행동력이 1개씩 회복돼요.\n1개가 생기면 바로 다시 도전할 수 있어요!"
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide.add_theme_font_size_override("font_size", 23)
	guide.add_theme_color_override("font_color", Color("#75647f"))
	box.add_child(guide)
	empty_energy_timer_label = Label.new()
	empty_energy_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_energy_timer_label.add_theme_font_size_override("font_size", 30)
	empty_energy_timer_label.add_theme_color_override("font_color", Color("#df5575"))
	box.add_child(empty_energy_timer_label)
	var ok := Button.new()
	ok.text = "확인"
	ok.custom_minimum_size = Vector2(250, 72)
	ok.add_theme_font_size_override("font_size", 29)
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color("#f28661")
	button_style.border_color = Color("#b9574d")
	button_style.set_border_width_all(4)
	button_style.set_corner_radius_all(20)
	ok.add_theme_stylebox_override("normal", button_style)
	ok.add_theme_color_override("font_color", Color.WHITE)
	ok.pressed.connect(func():
		empty_energy_timer_label = null
		dim.queue_free()
	)
	box.add_child(ok)
	_update_energy_display()


func _on_back() -> void:
	if main:
		main.show_title()


func _level_button(i: int) -> Button:
	var unlocked: bool = main.save.is_unlocked(i)
	var earned: int = main.save.get_stars(i)
	var b := Button.new()
	b.custom_minimum_size = Vector2(116, 118)
	# 레벨 카드 위에서 시작한 모바일 드래그도 부모 ScrollContainer로 전달한다.
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.mouse_force_pass_scroll_events = true
	var col: Color = BTN_COLORS[i % BTN_COLORS.size()] if unlocked else Color(0.72, 0.7, 0.78)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = col.darkened(0.36)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(22)
	sb.corner_detail = 10
	sb.border_blend = true
	sb.shadow_color = Color(0.08, 0.04, 0.18, 0.4)
	sb.shadow_size = 9
	sb.shadow_offset = Vector2(0, 6)
	b.add_theme_stylebox_override("normal", sb)
	var sb2: StyleBoxFlat = sb.duplicate()
	sb2.bg_color = col.darkened(0.15)
	b.add_theme_stylebox_override("hover", sb2)
	b.add_theme_stylebox_override("pressed", sb2)
	b.add_theme_stylebox_override("disabled", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.disabled = not unlocked

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)

	var num := Label.new()
	num.text = str(i + 1) if unlocked else "잠김"
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", 40 if unlocked else 23)
	num.add_theme_color_override("font_color", Color.WHITE)
	num.add_theme_color_override("font_outline_color", col.darkened(0.38))
	num.add_theme_constant_override("outline_size", 4)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(num)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	for s in range(3):
		var tr := TextureRect.new()
		tr.texture = star_tex
		tr.custom_minimum_size = Vector2(23, 23)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.modulate = Color(1.0, 0.85, 0.2) if s < earned else Color(1, 1, 1, 0.35)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tr)
	var best_time: float = main.save.get_best_clear_time(i)
	if earned > 0 and best_time > 0.0:
		var record := Label.new()
		record.text = "⏱ %s" % _format_clear_time(best_time)
		record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		record.add_theme_font_size_override("font_size", 14)
		record.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
		record.add_theme_color_override("font_outline_color", col.darkened(0.38))
		record.add_theme_constant_override("outline_size", 2)
		record.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(record)

	var idx := i
	b.pressed.connect(func(): main.start_level(idx))
	return b


static func _format_clear_time(seconds: float) -> String:
	var centiseconds := maxi(0, int(round(seconds * 100.0)))
	return "%d:%02d.%02d" % [centiseconds / 6000, (centiseconds / 100) % 60, centiseconds % 100]
