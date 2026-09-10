extends Control
class_name MapScreen
## 젤리 마을에서 시작해 테마 지역을 이어 여행하는 세로형 구조 원정 지도.

var main = null
var star_tex: Texture2D
var stardust_label: Label
var energy_label: Label
var energy_timer_label: Label
var empty_energy_timer_label: Label
var _last_energy_second := -1
var background: TextureRect
var current_level_idx := 0
var current_scroll_target := 0.0
var scroll_target_stage: Control
var selected_chapter_idx := 0
var visible_chapter_total := 0
var loaded_chapter_start := 0
var map_scroll: ScrollContainer
var chapter_list: VBoxContainer
var chapter_selector_label: Label
var chapter_back_ten: Button
var chapter_previous: Button
var chapter_next: Button
var chapter_forward_ten: Button

const ChapterPathScene = preload("res://scripts/ChapterPath.gd")
const CHAPTER_PATH_HEIGHT := 840.0
const CHAPTER_HEADER_HEIGHT := 140.0
const CHAPTER_STAGE_HEIGHT := CHAPTER_HEADER_HEIGHT + CHAPTER_PATH_HEIGHT
const CHAPTER_WINDOW_SIZE := 5
const PATH_POINTS := [
	Vector2(96, 92), Vector2(224, 156), Vector2(408, 224), Vector2(514, 296),
	Vector2(420, 374), Vector2(242, 448), Vector2(108, 524), Vector2(216, 610),
	Vector2(402, 690), Vector2(516, 772),
]

const WORLD_NAMES := [
	"달콤한 고향", "얼어붙은 별길", "디저트 대륙", "무지개 해안",
	"포근한 간식 왕국", "과일빛 정원", "은하 정거장", "프리즘 도시",
	"시간과 기억의 땅", "태초의 별세계", "차원 여행로", "소용돌이 관문",
	"부서진 디저트 왕국", "대균열 지대", "꿈안개 왕국", "달빛 몽환계",
	"천공의 바람섬", "폭풍의 왕관", "멈춘 시간도시", "천년의 대성전",
]

const BTN_COLORS := [
	Color(1.0, 0.45, 0.55), Color(1.0, 0.65, 0.3), Color(0.35, 0.7, 0.95),
	Color(0.4, 0.78, 0.45), Color(0.7, 0.5, 0.9), Color(0.95, 0.55, 0.75),
]


func _ready() -> void:
	theme = ArtDirection.ui_theme()
	star_tex = load("res://assets/fx/ui_star.png")
	current_level_idx = _find_current_level()
	visible_chapter_total = Levels.visible_chapter_count(main.save)
	selected_chapter_idx = clampi(current_level_idx / Levels.LEVELS_PER_CHAPTER, 0, visible_chapter_total - 1)
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
	title.text = tr("구조 원정")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", ArtDirection.text_color(Color(0.42, 0.32, 0.56)))
	title.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.92))
	title.add_theme_constant_override("outline_size", 0)
	title.position = Vector2(0, 90)
	title.size = Vector2(G.W, 80)
	add_child(title)

	# 경로가 하나의 세계처럼 이어지되, 바깥 배경과는 충분히 분리한다.
	var scroll_frame := PanelContainer.new()
	scroll_frame.position = Vector2(20, 254)
	scroll_frame.size = Vector2(G.W - 40, G.H - 458)
	scroll_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := ArtDirection.glass_panel(Color("#fff8ef"), 0.48, 32)
	frame_style.set_border_width_all(1)
	scroll_frame.add_theme_stylebox_override("panel", frame_style)
	ArtDirection.decorate_surface(scroll_frame, 32, Color("#ffffff"), 0.72)
	add_child(scroll_frame)
	_add_chapter_selector()

	# 한 겹의 알파 마스크로 스크롤 내용과 스크롤바를 함께 둥글게 자른다.
	# 외곽 반경 32 - 동일 여백 8 = 안쪽 반경 24.
	var map_mask := Panel.new()
	map_mask.name = "RoundedMapViewport"
	map_mask.position = scroll_frame.position + Vector2(8, 8)
	map_mask.size = scroll_frame.size - Vector2(16, 16)
	map_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask_style := StyleBoxFlat.new()
	mask_style.bg_color = Color.WHITE
	mask_style.set_corner_radius_all(24)
	mask_style.corner_detail = 12
	map_mask.add_theme_stylebox_override("panel", mask_style)
	map_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	add_child(map_mask)

	map_scroll = ScrollContainer.new()
	map_scroll.size = map_mask.size
	map_scroll.clip_contents = true
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	map_scroll.scroll_deadzone = 8
	map_scroll.follow_focus = false
	map_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	map_mask.add_child(map_scroll)

	chapter_list = VBoxContainer.new()
	# 스크롤 패널의 전체 안쪽 폭을 챕터 디오라마가 사용한다.
	chapter_list.custom_minimum_size = Vector2(G.W - 72, 0)
	chapter_list.add_theme_constant_override("separation", 0)
	chapter_list.mouse_filter = Control.MOUSE_FILTER_PASS
	map_scroll.add_child(chapter_list)
	_rebuild_chapter_window()

	var ranking_button := Button.new()
	ranking_button.name = "AdventureRankingButton"
	ranking_button.text = tr("모험 랭킹")
	ranking_button.custom_minimum_size = Vector2(220, 76)
	ranking_button.add_theme_font_size_override("font_size", 28)
	ArtDirection.apply_button(ranking_button, ArtDirection.primary_color(), 20)
	ranking_button.position = Vector2(G.W / 2 - 230, G.H - 142)
	ranking_button.pressed.connect(func(): main.show_ranking())
	add_child(ranking_button)
	var back := Button.new()
	back.name = "MapHomeButton"
	back.text = tr("홈으로")
	back.custom_minimum_size = Vector2(220, 76)
	back.add_theme_font_size_override("font_size", 30)
	ArtDirection.apply_button(back, Color(0.62, 0.56, 0.72), 20)
	# 스크롤 패널 아래와 화면 바닥 사이의 여백 중앙에 배치한다.
	back.position = Vector2(G.W / 2 + 10, G.H - 142)
	back.pressed.connect(_on_back)
	add_child(back)
	_update_energy_display()


func _find_current_level() -> int:
	var last_unlocked := 0
	for i in range(Levels.level_count()):
		if not main.save.is_unlocked(i):
			break
		last_unlocked = i
		if main.save.get_stars(i) <= 0:
			return i
	return last_unlocked


func _add_chapter_selector() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(54, 168)
	panel.size = Vector2(G.W - 108, 72)
	var accent: Color = Levels.CHAPTER_COLORS[selected_chapter_idx]
	var style := ArtDirection.glass_panel(Color("#fff8ee"), 0.96, 24)
	style.border_color = ArtDirection.border_color()
	style.set_border_width_all(1)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", style)
	ArtDirection.decorate_surface(panel, 24, Color.WHITE, 0.78)
	add_child(panel)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	chapter_back_ten = _chapter_nav_button("-10", -10, 17)
	chapter_previous = _chapter_nav_button("◀", -1, 23)
	row.add_child(chapter_back_ten)
	row.add_child(chapter_previous)
	chapter_selector_label = Label.new()
	chapter_selector_label.custom_minimum_size = Vector2(340, 54)
	chapter_selector_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter_selector_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chapter_selector_label.add_theme_font_size_override("font_size", 16)
	chapter_selector_label.add_theme_color_override("font_color", ArtDirection.ink())
	chapter_selector_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.82))
	chapter_selector_label.add_theme_constant_override("outline_size", 0)
	row.add_child(chapter_selector_label)
	chapter_next = _chapter_nav_button("▶", 1, 23)
	chapter_forward_ten = _chapter_nav_button("+10", 10, 17)
	row.add_child(chapter_next)
	row.add_child(chapter_forward_ten)


func _chapter_nav_button(text: String, delta: int, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(54, 52)
	button.add_theme_font_size_override("font_size", font_size)
	ArtDirection.apply_button(button, Color("#8d6cbd"), 16)
	button.pressed.connect(func(): _shift_chapter(delta))
	return button


func _shift_chapter(delta: int) -> void:
	var next_chapter := clampi(selected_chapter_idx + delta, 0, visible_chapter_total - 1)
	if next_chapter == selected_chapter_idx:
		return
	selected_chapter_idx = next_chapter
	_rebuild_chapter_window()


func _rebuild_chapter_window() -> void:
	visible_chapter_total = Levels.visible_chapter_count(main.save)
	selected_chapter_idx = clampi(selected_chapter_idx, 0, visible_chapter_total - 1)
	for child in chapter_list.get_children():
		chapter_list.remove_child(child)
		child.queue_free()

	var window_count := mini(CHAPTER_WINDOW_SIZE, visible_chapter_total)
	var max_start := maxi(0, visible_chapter_total - window_count)
	loaded_chapter_start = clampi(selected_chapter_idx - CHAPTER_WINDOW_SIZE / 2, 0, max_start)
	var loaded_chapter_end := loaded_chapter_start + window_count
	# Higher chapters come first in the vertical container: progress climbs upward.
	scroll_target_stage = null
	current_scroll_target = CHAPTER_HEADER_HEIGHT + CHAPTER_PATH_HEIGHT * 0.5
	if loaded_chapter_end == visible_chapter_total:
		var unlockable_segment: int = main.save.next_unlockable_level_segment(Levels.level_count())
		if unlockable_segment > 0:
			chapter_list.add_child(_level_segment_gate_card(unlockable_segment))
	for chapter in range(loaded_chapter_end - 1, loaded_chapter_start - 1, -1):
		chapter_list.add_child(_build_chapter_section(chapter))
	_update_chapter_selector()
	map_scroll.scroll_vertical = 0
	call_deferred("_scroll_to_current", map_scroll)


func _update_chapter_selector() -> void:
	var chapter_number := selected_chapter_idx + 1
	var world_index := selected_chapter_idx / 5
	chapter_selector_label.text = "지역 %02d · %s\nCHAPTER %03d / %03d  ·  %s" % [world_index + 1, WORLD_NAMES[clampi(world_index, 0, WORLD_NAMES.size() - 1)], chapter_number, Levels.CHAPTER_NAMES.size(), Levels.CHAPTER_NAMES[selected_chapter_idx]]
	chapter_back_ten.disabled = selected_chapter_idx <= 0
	chapter_previous.disabled = selected_chapter_idx <= 0
	chapter_next.disabled = selected_chapter_idx >= visible_chapter_total - 1
	chapter_forward_ten.disabled = selected_chapter_idx >= visible_chapter_total - 1


func _build_chapter_section(chapter: int) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 0)
	section.mouse_filter = Control.MOUSE_FILTER_PASS
	var sign_color: Color = Levels.CHAPTER_COLORS[chapter]

	var stage := Control.new()
	stage.custom_minimum_size = Vector2(G.W - 72, CHAPTER_STAGE_HEIGHT)
	stage.mouse_filter = Control.MOUSE_FILTER_PASS
	section.add_child(stage)
	if chapter == selected_chapter_idx:
		scroll_target_stage = stage
	var scenery := PanelContainer.new()
	scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scenery_style := ArtDirection.glass_panel(ArtDirection.chapter_tint(chapter * 10), 0.82, 0)
	scenery_style.border_color = ArtDirection.border_color()
	scenery_style.set_border_width_all(0)
	scenery.add_theme_stylebox_override("panel", scenery_style)
	scenery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(scenery)

	var path_points := _chapter_path_points(chapter)
	var world_index := chapter / 5
	var region_tag := Label.new()
	region_tag.text = "지역 %02d · %s" % [world_index + 1, WORLD_NAMES[clampi(world_index, 0, WORLD_NAMES.size() - 1)]]
	region_tag.position = Vector2(26, 20)
	region_tag.size = Vector2(G.W - 124, 30)
	region_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_tag.add_theme_font_size_override("font_size", 17)
	region_tag.add_theme_color_override("font_color", ArtDirection.text_color(sign_color.darkened(0.36)))
	region_tag.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.72))
	region_tag.add_theme_constant_override("outline_size", 0)
	region_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(region_tag)

	var sign := PanelContainer.new()
	sign.position = Vector2((G.W - 72 - 410) * 0.5, 50)
	sign.size = Vector2(410, 58)
	sign.add_theme_stylebox_override("panel", ArtDirection.panel(sign_color.lightened(0.35), sign_color.darkened(0.3), 22, 0.26, 4))
	ArtDirection.decorate_surface(sign, 22, Color.WHITE, 0.82)
	stage.add_child(sign)
	var chapter_title := Label.new()
	chapter_title.text = "CHAPTER %d  ·  %s" % [chapter + 1, Levels.CHAPTER_NAMES[chapter]]
	chapter_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chapter_title.add_theme_font_size_override("font_size", 27)
	chapter_title.add_theme_color_override("font_color", ArtDirection.text_color(sign_color.darkened(0.38)))
	chapter_title.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.7))
	chapter_title.add_theme_constant_override("outline_size", 0)
	sign.add_child(chapter_title)

	var unlocked_count := 0
	var marker_point := Vector2.ZERO
	var has_current_marker := false
	for local in range(10):
		if main.save.is_unlocked(chapter * 10 + local):
			unlocked_count += 1
	var path := ChapterPathScene.new()
	path.position = Vector2(0, CHAPTER_HEADER_HEIGHT)
	path.size = Vector2(G.W - 72, CHAPTER_PATH_HEIGHT)
	path.setup(path_points, sign_color, unlocked_count, chapter)
	stage.add_child(path)

	for local in range(10):
		var idx := chapter * 10 + local
		var button := _level_button(idx, local)
		var button_size: Vector2 = Vector2(116, 108) if local == 9 else (Vector2(102, 98) if local == 4 else Vector2(92, 92))
		button.position = path_points[local] + Vector2(0, CHAPTER_HEADER_HEIGHT) - button_size * 0.5
		button.size = button_size
		stage.add_child(button)
		if idx == current_level_idx:
			marker_point = path_points[local] + Vector2(0, CHAPTER_HEADER_HEIGHT)
			has_current_marker = true
			if chapter == selected_chapter_idx:
				current_scroll_target = CHAPTER_HEADER_HEIGHT + path_points[local].y
	if has_current_marker:
		_add_current_marker(stage, marker_point)
	return section


func _chapter_path_points(chapter: int) -> Array:
	## 인접 챕터의 끝과 시작이 같은 쪽에서 만나 전체 지도가 한 줄로 이어진다.
	var mirrored := chapter % 2 == 1
	var points: Array = []
	for source: Vector2 in PATH_POINTS:
		points.append(Vector2(G.W - 72 - source.x if mirrored else source.x, CHAPTER_PATH_HEIGHT - source.y))
	return points


func _add_current_marker(stage: Control, point: Vector2) -> void:
	var glow := TextureRect.new()
	glow.texture = load("res://assets/fx/soft.png")
	glow.position = point - Vector2(56, 73)
	glow.size = Vector2(112, 112)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.modulate = Color(1.0, 0.82, 0.26, 0.5)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.z_index = 8
	stage.add_child(glow)
	# 고해상도 원화를 Control 최소 크기에 맡기면 원본 크기로 튀는 경우가 있어
	# Sprite2D를 텍스처 실측 크기에 맞춰 직접 축소한다.
	var hero := Sprite2D.new()
	var hero_texture := G.hero_tex()
	hero.texture = hero_texture
	hero.position = point + Vector2(0, -45)
	var hero_scale := 78.0 / maxf(float(hero_texture.get_width()), float(hero_texture.get_height()))
	hero.scale = Vector2.ONE * hero_scale
	hero.z_index = 9
	stage.add_child(hero)
	var bounce := hero.create_tween().set_loops()
	bounce.tween_property(hero, "position:y", hero.position.y - 7.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bounce.tween_property(hero, "position:y", hero.position.y, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _scroll_to_current(scroll: ScrollContainer) -> void:
	await get_tree().process_frame
	if not is_instance_valid(scroll_target_stage):
		return
	var stage_top := scroll_target_stage.global_position.y - chapter_list.global_position.y
	var target := maxi(0, int(stage_top + current_scroll_target - scroll.size.y * 0.6))
	scroll.scroll_vertical = target


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
	style.bg_color = ArtDirection.panel_color()
	style.border_color = ArtDirection.border_color()
	style.set_border_width_all(1)
	style.set_corner_radius_all(22)
	style.shadow_color = Color(0.35, 0.22, 0.12, 0.10)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 13
	style.content_margin_right = 13
	panel.add_theme_stylebox_override("panel", style)
	ArtDirection.decorate_surface(panel, 22, Color("#ffffff"), 0.68)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	energy_label = Label.new()
	energy_label.add_theme_font_size_override("font_size", 28)
	energy_label.add_theme_color_override("font_color", ArtDirection.danger_color())
	row.add_child(energy_label)
	energy_timer_label = Label.new()
	energy_timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	energy_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	energy_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	energy_timer_label.add_theme_font_size_override("font_size", 17)
	energy_timer_label.add_theme_color_override("font_color", ArtDirection.ink())
	row.add_child(energy_timer_label)


func _add_stardust_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(28, 24)
	panel.size = Vector2(205, 64)
	var style := StyleBoxFlat.new()
	style.bg_color = ArtDirection.panel_color()
	style.border_color = ArtDirection.border_color()
	style.set_border_width_all(1)
	style.set_corner_radius_all(22)
	style.shadow_color = Color(0.35, 0.22, 0.12, 0.10)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 14
	style.content_margin_right = 14
	panel.add_theme_stylebox_override("panel", style)
	ArtDirection.decorate_surface(panel, 22, Color("#ffffff"), 0.68)
	add_child(panel)
	stardust_label = Label.new()
	stardust_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stardust_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stardust_label.add_theme_font_size_override("font_size", 24)
	stardust_label.add_theme_color_override("font_color", ArtDirection.ink())
	panel.add_child(stardust_label)


func _energy_time_text() -> String:
	var seconds: int = main.save.seconds_until_next_energy()
	return "%02d:%02d" % [seconds / 60, seconds % 60]


func _update_energy_display() -> void:
	if main == null or energy_label == null:
		return
	var current: int = main.save.get_energy()
	stardust_label.text = tr("★ 별가루 %d") % main.save.get_stardust()
	energy_label.text = tr("♥ %d/%d") % [current, SaveGame.MAX_ENERGY]
	energy_timer_label.text = "가득 참" if current >= SaveGame.MAX_ENERGY else "다음 " + _energy_time_text()
	if empty_energy_timer_label:
		empty_energy_timer_label.text = "지금 도전할 수 있어요!" if current > 0 else "다음 행동력  " + _energy_time_text()


func show_energy_empty() -> void:
	var dim := ColorRect.new()
	dim.color = ArtDirection.dim_color()
	dim.z_index = 100
	_fit_overlay_to_viewport(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = ArtDirection.panel_color()
	style.border_color = ArtDirection.border_color()
	style.set_border_width_all(1)
	style.set_corner_radius_all(30)
	style.shadow_color = Color(0.35, 0.22, 0.12, 0.10)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
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
	heart.add_theme_color_override("font_color", ArtDirection.danger_color())
	box.add_child(heart)
	var title := Label.new()
	title.text = "행동력이 부족해요"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", ArtDirection.ink())
	box.add_child(title)
	var guide := Label.new()
	guide.text = "10분마다 행동력이 1개씩 회복돼요.\n1개가 생기면 바로 다시 도전할 수 있어요!"
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide.add_theme_font_size_override("font_size", 23)
	guide.add_theme_color_override("font_color", ArtDirection.ink())
	box.add_child(guide)
	empty_energy_timer_label = Label.new()
	empty_energy_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_energy_timer_label.add_theme_font_size_override("font_size", 30)
	empty_energy_timer_label.add_theme_color_override("font_color", ArtDirection.danger_color())
	box.add_child(empty_energy_timer_label)
	var ok := Button.new()
	ok.text = tr("확인")
	ok.custom_minimum_size = Vector2(250, 72)
	ok.add_theme_font_size_override("font_size", 29)
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = ArtDirection.panel_color()
	button_style.border_color = ArtDirection.border_color()
	button_style.set_border_width_all(1)
	button_style.set_corner_radius_all(20)
	ok.add_theme_stylebox_override("normal", button_style)
	ArtDirection.apply_button(ok, ArtDirection.CORAL, 20)
	ok.pressed.connect(func():
		empty_energy_timer_label = null
		dim.queue_free()
	)
	box.add_child(ok)
	_update_energy_display()


func _on_back() -> void:
	if main:
		main.show_title()


func _level_segment_gate_card(segment: int) -> PanelContainer:
	var first_level := segment * SaveGame.LEVEL_GATE_SIZE + 1
	var last_level := mini((segment + 1) * SaveGame.LEVEL_GATE_SIZE, Levels.level_count())
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(G.W - 92, 210)
	var style := ArtDirection.glass_panel(Color("#f8efff"), 0.96, 28)
	style.set_border_width_all(1)
	style.border_color = ArtDirection.border_color()
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	card.add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	card.add_child(content)
	var title := Label.new()
	title.text = "🔒 LEVEL %d~%d" % [first_level, last_level]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 31)
	title.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(title)
	var guide := Label.new()
	guide.text = "광고를 보고 다음 100레벨을 영구 해금하세요."
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide.add_theme_font_size_override("font_size", 20)
	guide.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(guide)
	var unlock := Button.new()
	unlock.text = "바로 열기" if main.save.has_removed_ads() else "광고 보고 다음 구간 열기"
	unlock.custom_minimum_size = Vector2(390, 70)
	unlock.add_theme_font_size_override("font_size", 24)
	ArtDirection.apply_button(unlock, Color("#8e64c8"), 20)
	unlock.pressed.connect(func():
		main.request_level_segment_unlock(segment * SaveGame.LEVEL_GATE_SIZE, Callable(main, "show_map"))
	)
	content.add_child(unlock)
	return card


func _level_button(i: int, local_index: int = -1) -> Button:
	var unlocked: bool = main.save.is_unlocked(i)
	var earned: int = main.save.get_stars(i)
	var b := Button.new()
	b.custom_minimum_size = Vector2(92, 92)
	# 레벨 카드 위에서 시작한 모바일 드래그도 부모 ScrollContainer로 전달한다.
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.mouse_force_pass_scroll_events = true
	var is_reward := local_index == 4
	var is_boss := local_index == 9
	var col: Color = (Color("#8c65c6") if is_boss else (Color("#edae3d") if is_reward else BTN_COLORS[i % BTN_COLORS.size()])) if unlocked else Color(0.64, 0.63, 0.7)
	ArtDirection.apply_button(b, ArtDirection.CORAL if i == current_level_idx else ArtDirection.panel_color(), 30 if is_boss else 26)
	if earned > 0 and i != current_level_idx:
		var completed: StyleBoxFlat = b.get_theme_stylebox("normal").duplicate()
		completed.bg_color = ArtDirection.selected_color()
		b.add_theme_stylebox_override("normal", completed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.disabled = not unlocked

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)

	var num := Label.new()
	num.text = ("관문\n%d" % (i + 1) if is_boss else str(i + 1)) if unlocked else "◆"
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", 28 if is_boss else (35 if unlocked else 22))
	num.add_theme_color_override("font_color", Color.WHITE if i == current_level_idx else (ArtDirection.ink() if unlocked else ArtDirection.muted_color()))
	num.add_theme_color_override("font_outline_color", col.darkened(0.38))
	num.add_theme_constant_override("outline_size", 0)
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
		tr.custom_minimum_size = Vector2(18, 18)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.modulate = Color(1.0, 0.85, 0.2) if s < earned else Color(1, 1, 1, 0.35)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tr)
	if is_reward:
		var reward := Label.new()
		reward.text = "보상"
		reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward.add_theme_font_size_override("font_size", 14)
		reward.add_theme_color_override("font_color", ArtDirection.ink())
		reward.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(reward)

	var idx := i
	b.pressed.connect(func(): _show_level_card(idx))
	return b


func _show_level_card(i: int) -> void:
	var level: Dictionary = Levels.get_level(i)
	var dim := ColorRect.new()
	dim.color = ArtDirection.dim_color()
	dim.z_index = 100
	_fit_overlay_to_viewport(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var close := Button.new()
	close.flat = true
	close.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	close.pressed.connect(dim.queue_free)
	dim.add_child(close)
	var card := PanelContainer.new()
	# dim 자체가 뷰포트 원점으로 보정되므로 카드에는 safe offset을 중복 적용하지 않는다.
	card.position = Vector2(28, G.H - 438)
	card.size = Vector2(G.W - 56, 400)
	var chapter := clampi(i / 10, 0, Levels.CHAPTER_COLORS.size() - 1)
	var accent: Color = Levels.CHAPTER_COLORS[chapter]
	var style := ArtDirection.glass_panel(Color("#fffaf1"), 0.99, 34)
	style.border_color = ArtDirection.border_color()
	style.set_border_width_all(1)
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	card.add_theme_stylebox_override("panel", style)
	ArtDirection.decorate_surface(card, 34, Color.WHITE, 0.82)
	dim.add_child(card)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var eyebrow := Label.new()
	eyebrow.text = "CHAPTER %d · %s" % [chapter + 1, Levels.CHAPTER_NAMES[chapter]]
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 18)
	eyebrow.add_theme_color_override("font_color", ArtDirection.text_color(accent.darkened(0.28)))
	box.add_child(eyebrow)
	var heading := Label.new()
	heading.text = "LEVEL %d  %s" % [i + 1, String(level.get("name", "구조 원정"))]
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	heading.add_theme_color_override("font_color", ArtDirection.ink())
	box.add_child(heading)
	var mechanics := Label.new()
	mechanics.text = "  ·  ".join(_level_mechanic_labels(level))
	mechanics.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mechanics.add_theme_font_size_override("font_size", 20)
	mechanics.add_theme_color_override("font_color", ArtDirection.ink())
	box.add_child(mechanics)
	var record := Label.new()
	var best: float = main.save.get_best_clear_time(i)
	var earned: int = main.save.get_stars(i)
	record.text = tr("달성 별  %s    최고 기록  %s") % ["★".repeat(earned) + "☆".repeat(3 - earned), _format_clear_time(best) if best > 0.0 else "--:--"]
	record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	record.add_theme_font_size_override("font_size", 22)
	record.add_theme_color_override("font_color", ArtDirection.ink())
	box.add_child(record)
	var start := Button.new()
	start.text = "구조 원정 시작"
	start.custom_minimum_size = Vector2(430, 78)
	start.add_theme_font_size_override("font_size", 29)
	ArtDirection.apply_button(start, Color("#ef7047"), 23)
	start.pressed.connect(func(): main.start_level(i))
	box.add_child(start)


func _level_mechanic_labels(level: Dictionary) -> Array[String]:
	var labels: Array[String] = []
	if level.has("boss"):
		labels.append("보스 관문")
	if not level.get("exits", []).is_empty():
		labels.append("젤리 배출구")
	if not level.get("frozen", []).is_empty():
		labels.append("얼음 젤리")
	if not level.get("shape_seals", []).is_empty():
		labels.append("모양 봉인")
	if level.has("move_limit"):
		labels.append("제한 이동")
	if labels.is_empty():
		labels.append("색상 구조 퍼즐")
	labels.append("제한시간 %d초" % int(level.get("time", 0)))
	return labels


static func _format_clear_time(seconds: float) -> String:
	var centiseconds := maxi(0, int(round(seconds * 100.0)))
	return "%d:%02d.%02d" % [centiseconds / 6000, (centiseconds / 100) % 60, centiseconds % 100]
