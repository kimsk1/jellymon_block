extends Control
class_name Title
## 메인 화면 = 플레이 기록이 살아 움직이는 '젤리 아지트'.

const L10n = preload("res://scripts/LocalizedText.gd")
const AttendanceRewardPopupLib = preload("res://scripts/ui/AttendanceRewardPopup.gd")
const FurnitureArtLib = preload("res://scripts/FurnitureArt.gd")
const FurnitureRewards = preload("res://scripts/FurnitureRewardCatalog.gd")
const HomeNavIconScene = preload("res://scripts/HomeNavIcon.gd")
const DailyMissionCatalogLib = preload("res://scripts/DailyMissionCatalog.gd")
const JellyDexCatalogLib = preload("res://scripts/JellyDexCatalog.gd")
const LiveMessageCatalogLib = preload("res://scripts/LiveMessageCatalog.gd")
const LiveProgressionCatalogLib = preload("res://scripts/LiveProgressionCatalog.gd")
const RetentionCatalogLib = preload("res://scripts/RetentionCatalog.gd")

var main = null
var room_theme_popup: Control
var room_theme_button: Button
var backdrop: RoomBackdrop
var furniture_layer: Node2D
var character_layer: Node2D
var ui_layer: Control
var nav_bar: Control
var palette: Control
var photo_layer: Control
var attendance_button: Button
var attendance_popup: Control
var mission_button: Button
var mission_popup: Control
var dex_popup: Control
var menu_popup: Control
var lifestyle_popup: Control
var stardust_label: Label
var shop_popup: Control
var purchase_confirm_popup: Control
var shop_balance_label: Label
var shop_status_label: Label
var _billing_buttons: Array = []
var home_energy_label: Label
var header_name_label: Label
var nickname_popup: Control
var nickname_input: LineEdit
var nickname_error: Label
var nickname_confirm_button: Button
var _last_home_energy_second := -1
var adventure_button: Button
var home_interaction_hint: Control
var _hero_reaction_tween: Tween
var _resident_touch_tweens := {}
var resident_nodes: Array[Sprite2D] = []
var resident_home_positions := {}
var resident_action_timer: Timer
var placements: Array = []
var furniture_nodes: Array[RoomFurniture] = []
var edit_mode := false
var selected_index := -1
var drag_index := -1
var drag_offset := Vector2i.ZERO


func _ready() -> void:
	main.billing.changed.connect(_refresh_billing_ui)
	ArtDirection.set_room_theme(main.save.get_room_theme())
	theme = ArtDirection.ui_theme()
	get_tree().root.theme = theme
	_apply_responsive_layout()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	mouse_filter = Control.MOUSE_FILTER_STOP
	placements = main.save.get_room_placements()
	backdrop = RoomBackdrop.new()
	add_child(backdrop)
	backdrop.set_restoration_level(main.save.town_total_level())
	backdrop.set_room_theme(main.save.get_room_theme())
	furniture_layer = Node2D.new()
	furniture_layer.z_index = 2
	furniture_layer.position.y = RoomData.SCREEN_Y_OFFSET
	add_child(furniture_layer)
	character_layer = Node2D.new()
	character_layer.z_index = 4
	character_layer.position.y = RoomData.SCREEN_Y_OFFSET
	add_child(character_layer)
	ui_layer = Control.new()
	ui_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.z_index = 10
	add_child(ui_layer)
	_build_header()
	_build_navigation()
	_refresh_room()
	_start_resident_life()
	# 최초 닉네임 설정을 출석 안내보다 먼저 처리한다. 자동 QA에서는 기존 화면 캡처를 가리지 않는다.
	var interactive := not OS.get_cmdline_user_args().has("--shots") and not OS.get_cmdline_user_args().has("--shot-room-refresh") and not OS.get_cmdline_user_args().has("--shot-lifestyle") and not OS.get_cmdline_user_args().has("--shot-room-edit") and not OS.get_cmdline_user_args().has("--shot-level-51") and DisplayServer.get_name() != "headless"
	if interactive and not main.save.has_nickname():
		call_deferred("_show_nickname_popup")
	elif interactive:
		call_deferred("_continue_first_time_flow")


func _process(_delta: float) -> void:
	var now := int(Time.get_unix_time_from_system())
	if now != _last_home_energy_second:
		_last_home_energy_second = now
		_refresh_home_energy()


func _apply_responsive_layout() -> void:
	position = G.safe_offset(get_viewport_rect().size)
	size = Vector2(G.W, G.H)


func _fit_overlay_to_viewport(control: Control) -> void:
	var viewport_size := get_viewport_rect().size
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = -G.safe_offset(viewport_size)
	control.size = viewport_size


func _center_popup_horizontally(card: Control) -> void:
	# Anchor to the overlay center, including when content changes its minimum width.
	var card_width := card.size.x
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.offset_left = -card_width * 0.5
	card.offset_right = card_width * 0.5
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _panel_style(color: Color, border: Color, radius: int = 24) -> StyleBoxFlat:
	return ArtDirection.panel(color, border, radius)


func _button(text: String, color: Color, size := Vector2(150, 74), font_size := 27) -> Button:
	var button := Button.new()
	button.text = L10n.text(tr(text))
	button.custom_minimum_size = size
	button.add_theme_font_size_override("font_size", font_size)
	ArtDirection.apply_button(button, color, 20)
	button.add_theme_color_override("font_disabled_color", ArtDirection.muted_color())
	button.add_theme_color_override("font_disabled_outline_color", color.darkened(0.38))
	return button


func _style_lifestyle_button(button: Button, disabled_fill: Color, disabled_border: Color, disabled_text: Color, completed: bool = false) -> void:
	## 밝은 팝업에서는 비활성 버튼도 상태를 읽을 수 있도록 중명도 배경과 짙은 글자를 쓴다.
	var disabled := _panel_style(disabled_fill, disabled_border, 18)
	disabled.bg_color = ArtDirection.selected_color() if completed else ArtDirection.disabled_color()
	disabled.set_border_width_all(1)
	disabled.shadow_color = Color(0.35, 0.22, 0.12, 0.10)
	disabled.shadow_size = 3
	disabled.shadow_offset = Vector2(0, 2)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_disabled_color", ArtDirection.success_color() if completed else ArtDirection.muted_color())
	button.add_theme_color_override("font_disabled_outline_color", Color(1, 1, 1, 0.42))
	button.add_theme_constant_override("outline_size", 0)


func _format_number(value: int) -> String:
	var digits := str(maxi(0, value))
	var formatted := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			formatted += ","
		formatted += digits[i]
	return formatted


func _nav_button(icon_kind: String, title_text: String, color: Color, width: float = 150.0) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(width, 104)
	var normal := _home_surface(color, 18)
	normal.set_border_width_all(0 if (ArtDirection.is_botanical() or ArtDirection.is_night()) else 2)
	normal.shadow_size = 0 if (ArtDirection.is_botanical() or ArtDirection.is_night()) else 1
	normal.shadow_offset = Vector2(0, 3)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = color.lightened(0.08)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = color.darkened(0.1)
	pressed.shadow_size = 2
	pressed.shadow_offset = Vector2(0, 2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 5)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)
	var icon_badge := PanelContainer.new()
	icon_badge.custom_minimum_size = Vector2(46, 46)
	icon_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = ArtDirection.panel_color()
	badge_style.border_color = ArtDirection.border_color()
	badge_style.set_border_width_all(2)
	badge_style.set_corner_radius_all(13)
	if ArtDirection.is_botanical() or ArtDirection.is_night():
		icon_badge.custom_minimum_size = Vector2(62, 62)
		icon_badge.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		icon_badge.add_theme_stylebox_override("panel", badge_style)
	content.add_child(icon_badge)
	var icon: Control = HomeNavIconScene.new()
	icon.setup(icon_kind, ArtDirection.navigation_ink())
	if ArtDirection.is_botanical() or ArtDirection.is_night():
		icon.custom_minimum_size = Vector2(62, 62)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_badge.add_child(icon)
	var title := Label.new()
	title.text = L10n.text(tr(title_text))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", ArtDirection.navigation_ink())
	title.add_theme_color_override("font_outline_color", color.darkened(0.42))
	title.add_theme_constant_override("outline_size", 0)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)
	return button


func _mark_furniture_placed(button: Button, item_color: Color) -> void:
	## 잠긴 가구와 혼동되지 않도록 배치 완료 상태는 색과 배지를 동시에 사용한다.
	var placed_style: StyleBoxFlat = button.get_theme_stylebox("disabled").duplicate()
	placed_style.bg_color = ArtDirection.selected_color()
	placed_style.border_color = ArtDirection.border_color()
	placed_style.shadow_color = Color(0.08, 0.04, 0.14, 0.28)
	button.add_theme_stylebox_override("disabled", placed_style)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.72))
	button.add_theme_color_override("font_disabled_outline_color", Color("#4b3d57"))

	var badge := PanelContainer.new()
	badge.position = Vector2(55, 4)
	badge.size = Vector2(66, 30)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color("#35a56d")
	badge_style.border_color = Color("#fff5d8")
	badge_style.set_border_width_all(2)
	badge_style.set_corner_radius_all(12)
	badge_style.shadow_color = Color(0.08, 0.04, 0.14, 0.28)
	badge_style.shadow_size = 3
	badge_style.shadow_offset = Vector2(0, 2)
	badge.add_theme_stylebox_override("panel", badge_style)
	button.add_child(badge)
	var badge_label := Label.new()
	badge_label.text = L10n.text("✓ 배치됨")
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size", 14)
	badge_label.add_theme_color_override("font_color", Color.WHITE)
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(badge_label)


func _home_surface(color: Color = Color("#fff7e9"), radius: int = 22) -> StyleBoxFlat:
	return ArtDirection.surface(color, radius)


func _home_label(value: String, point: Vector2, bounds: Vector2, font_size: int = 22) -> Label:
	var label := Label.new()
	label.text = L10n.text(value)
	label.position = point
	label.size = bounds
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ArtDirection.ink())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _home_button(value: String, bounds: Vector2, font_size: int = 22) -> Button:
	var button := Button.new()
	button.text = L10n.text(tr(value))
	button.custom_minimum_size = bounds
	button.size = bounds
	button.clip_text = true
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, _home_surface(Color("#f5e4cd") if state == "pressed" else Color("#fff8eb")))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, ArtDirection.navigation_ink())
	button.add_theme_stylebox_override("disabled", _home_surface(ArtDirection.selected_color()))
	button.add_theme_color_override("font_disabled_color", ArtDirection.success_color())
	return button


func _build_header() -> void:
	var shell := Panel.new()
	shell.name = "HomeHUDShell"
	shell.position = Vector2(14, 12)
	shell.size = Vector2(692, 116)
	shell.add_theme_stylebox_override("panel", _home_surface())
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(shell)
	var avatar := TextureButton.new()
	avatar.position = Vector2(28, 26)
	avatar.size = Vector2(78, 78)
	avatar.texture_normal = G.hero_tex()
	avatar.ignore_texture_size = true
	avatar.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	avatar.pressed.connect(_show_jelly_dex)
	ui_layer.add_child(avatar)
	var display_name: String = String(main.save.get_nickname()) if main.save.has_nickname() else tr("내 젤리몬")
	header_name_label = _home_label(display_name, Vector2(122, 25), Vector2(258, 35), 27)
	ui_layer.add_child(header_name_label)
	_refresh_vip_identity()
	var stars := RoomData.total_stars(main.save)
	var stage := RoomData.growth_stage(main.save)
	var target := RoomData.next_growth_stars(stage) if stage < RoomData.max_growth_stage() else maxi(1, stars)
	ui_layer.add_child(_home_label(tr("성장 %d / %d") % [stars, target], Vector2(122, 65), Vector2(264, 25), 19))
	var track := ProgressBar.new()
	track.position = Vector2(122, 99)
	track.size = Vector2(264, 9)
	track.max_value = target
	track.value = stars
	track.show_percentage = false
	var bg := _home_surface(ArtDirection.disabled_color() if ArtDirection.is_night() else Color("#eddfc9"), 5)
	bg.shadow_size = 0
	bg.set_border_width_all(0)
	var fill: StyleBoxFlat = bg.duplicate()
	fill.bg_color = ArtDirection.growth_color()
	track.name = "GrowthBar"
	track.add_theme_stylebox_override("background", bg)
	track.add_theme_stylebox_override("fill", fill)
	ui_layer.add_child(track)
	for spec in [[Vector2(410, 33), Vector2(132, 60), false], [Vector2(550, 33), Vector2(144, 60), true]]:
		var panel := Panel.new()
		panel.position = spec[0]
		panel.size = spec[1]
		panel.add_theme_stylebox_override("panel", _home_surface(Color("#fffaf2"), 24))
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_layer.add_child(panel)
		var label := _home_label("", Vector2(8, 8), Vector2(panel.size.x - 40, 44), 21)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(label)
		if ArtDirection.is_botanical() or ArtDirection.is_night():
			var resource_icon := HomeNavIconScene.new()
			resource_icon.setup("heart" if spec[2] else "star", ArtDirection.navigation_ink())
			resource_icon.custom_minimum_size = Vector2.ZERO
			resource_icon.position = Vector2(5, 14)
			resource_icon.size = Vector2(30, 30)
			panel.add_child(resource_icon)
			label.position.x = 34
			label.size.x = panel.size.x - 68
		if spec[2]:
			home_energy_label = label
		else:
			stardust_label = label
			label.text = L10n.text(("%s" if (ArtDirection.is_botanical() or ArtDirection.is_night()) else "★ %s") % _format_number(main.save.get_stardust()))
		var plus := _home_button("+", Vector2(30, 44), 23)
		plus.position = panel.position + Vector2(panel.size.x - 33, 8)
		plus.pressed.connect(_show_shop_popup)
		ui_layer.add_child(plus)
	room_theme_button = _home_button(L10n.text("방 테마"), Vector2(280, 46), 20)
	room_theme_button.position = Vector2(24, 138)
	room_theme_button.pressed.connect(_show_room_themes)
	ui_layer.add_child(room_theme_button)
	mission_button = _home_button(L10n.text("구조 0/3"), Vector2(132, 46), 19)
	mission_button.position = Vector2(414, 138)
	mission_button.pressed.connect(_show_daily_mission_popup)
	mission_button.visible = main.save.home_feature_unlocked("missions")
	ui_layer.add_child(mission_button)
	attendance_button = _home_button(L10n.text("선물 받기"), Vector2(144, 46), 19)
	attendance_button.position = Vector2(554, 138)
	attendance_button.pressed.connect(_show_attendance_popup)
	attendance_button.visible = main.save.home_feature_unlocked("attendance")
	ui_layer.add_child(attendance_button)
	if ArtDirection.is_botanical() or ArtDirection.is_night():
		_add_botanical_action_icon(mission_button, "rescue")
		_add_botanical_action_icon(attendance_button, "gift")
	_refresh_home_energy()
	_refresh_attendance_button()
	_refresh_mission_button()
	_add_header_badges()
	_refresh_room_theme_label()


func _add_botanical_action_icon(button: Button, kind: String) -> void:
	var icon := HomeNavIconScene.new()
	icon.setup(kind, ArtDirection.navigation_ink())
	icon.custom_minimum_size = Vector2.ZERO
	icon.position = Vector2(7, 9)
	icon.size = Vector2(28, 28)
	button.add_child(icon)
	button.add_theme_font_size_override("font_size", 17)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
		style.content_margin_left = 35
		style.content_margin_right = 5
		button.add_theme_stylebox_override(state, style)


func _refresh_room_theme_label() -> void:
	if is_instance_valid(room_theme_button):
		room_theme_button.text = L10n.text(tr("방 테마") + " · " + tr(L10n.text(String(RoomData.room_theme(main.save.get_room_theme()).name))))


func _select_room_theme(id: String) -> void:
	if not main.save.set_room_theme(id):
		return
	ArtDirection.set_room_theme(id)
	theme = ArtDirection.ui_theme()
	get_tree().root.theme = theme
	backdrop.set_room_theme(id)
	if is_instance_valid(room_theme_popup) and room_theme_popup.get_parent() != ui_layer:
		room_theme_popup.queue_free()
	room_theme_popup = null
	# Defer freeing the button currently emitting its pressed signal.
	for child in ui_layer.get_children():
		ui_layer.remove_child(child)
		child.queue_free()
	palette = null
	_build_header()
	_build_navigation()
	if edit_mode:
		nav_bar.hide()
		ui_layer.get_node("NextAdventureCard").hide()
		_build_palette()



func _show_room_themes() -> void:
	if is_instance_valid(room_theme_popup):
		return
	var dim := ColorRect.new()
	dim.color = ArtDirection.dim_color()
	_fit_overlay_to_viewport(dim)
	dim.z_index = 300
	ui_layer.add_child(dim)
	room_theme_popup = dim
	var card := Panel.new()
	card.position = (dim.size - Vector2(652, 540)) * 0.5
	card.size = Vector2(652, 540)
	card.add_theme_stylebox_override("panel", _home_surface())
	dim.add_child(card)
	_center_popup_horizontally(card)
	card.add_child(_home_label(tr("방 테마"), Vector2(24, 20), Vector2(604, 44), 30))
	card.add_child(_home_label(tr("테마를 바꿔도 가구 배치는 유지돼요"), Vector2(24, 70), Vector2(604, 40), 19))
	for i in range(RoomData.ROOM_THEMES.size()):
		var theme: Dictionary = RoomData.ROOM_THEMES[i]
		var preview := TextureRect.new()
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.texture = load(L10n.text(String(theme.asset)))
		preview.position = Vector2(24 + i * 204, 128)
		preview.size = Vector2(196, 218)
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(preview)
		var text := tr(L10n.text(String(theme.name)))
		var choose := _home_button(text, Vector2(196, 68), 19)
		choose.position = Vector2(24 + i * 204, 358)
		choose.name = "Theme_" + String(theme.id)
		var unlocked: bool = main.save.is_room_theme_unlocked(String(theme.id))
		choose.disabled = not unlocked or main.save.get_room_theme() == theme.id
		if not unlocked:
			choose.text = L10n.text(text + L10n.text("\n%d레벨 클리어 후 해금") % int(theme.unlock_level))
			choose.add_theme_font_size_override("font_size", 16)
			preview.modulate = Color(0.65, 0.65, 0.65, 0.8)
		elif choose.disabled:
			choose.text = L10n.text("✓ " + text)
			choose.add_theme_stylebox_override("disabled", _home_surface(ArtDirection.selected_color()))
			choose.add_theme_color_override("font_disabled_color", ArtDirection.success_color())
		choose.pressed.connect(_select_room_theme.bind(String(theme.id)))
		card.add_child(choose)
	var close := _home_button(L10n.text("닫기"), Vector2(240, 60), 23)
	close.position = Vector2(206, 454)
	close.pressed.connect(func(): dim.queue_free(); room_theme_popup = null)
	card.add_child(close)


func _refresh_vip_identity() -> void:
	if not header_name_label:
		return
	var display_name: String = String(main.save.get_nickname()) if main.save.has_nickname() else L10n.text("내 젤리몬")
	header_name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	header_name_label.text = "VIP ✦  %s" % display_name if main.save.has_removed_ads() else display_name
	header_name_label.add_theme_color_override("font_color", ArtDirection.text_color(Color("#a36822") if main.save.has_removed_ads() else ArtDirection.ink()))
	header_name_label.tooltip_text = L10n.text("VIP 광고 스킵 패스 보유 · 전용 명패 지급 완료") if main.save.has_removed_ads() else ""


func _add_notification_dot(target: Control, visible_now: bool) -> void:
	if not visible_now:
		return
	var dot := PanelContainer.new()
	dot.position = Vector2(target.size.x - 20, -7)
	dot.size = Vector2(27, 27)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _panel_style(Color("#ffcb3d"), Color("#9f5327"), 14)
	style.set_border_width_all(1)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	dot.add_theme_stylebox_override("panel", style)
	target.add_child(dot)
	dot.pivot_offset = Vector2(13.5, 13.5)
	var mark := Label.new()
	mark.text = L10n.text("!")
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", 17)
	mark.add_theme_color_override("font_color", ArtDirection.danger_color())
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.add_child(mark)
	var tween := dot.create_tween().set_loops()
	tween.tween_property(dot, "scale", Vector2(1.12, 1.12), 0.55).set_trans(Tween.TRANS_SINE)
	tween.tween_property(dot, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE)


func _add_header_badges() -> void:
	_add_notification_dot(attendance_button, main.save.can_claim_attendance())
	_add_notification_dot(mission_button, main.save.can_claim_daily_mission_chest())


func _show_nickname_popup() -> void:
	if nickname_popup and is_instance_valid(nickname_popup):
		return
	var dim := ColorRect.new()
	dim.color = ArtDirection.dim_color()
	_fit_overlay_to_viewport(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 110
	add_child(dim)
	nickname_popup = dim
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 510)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#f8eaff"), Color("#815ba9"), 36))
	center.add_child(panel)
	panel.scale = Vector2(0.72, 0.72)
	panel.pivot_offset = Vector2(310, 255)
	panel.create_tween().tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)
	var avatar := TextureRect.new()
	avatar.texture = G.hero_tex()
	avatar.custom_minimum_size = Vector2(105, 105)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(avatar)
	var title := Label.new()
	title.text = L10n.text(tr("반가워요! 이름을 알려주세요"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(title)
	var guide := Label.new()
	guide.text = L10n.text("공백 없이 1~12글자로 입력해 주세요.")
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide.add_theme_font_size_override("font_size", 20)
	guide.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(guide)
	nickname_input = LineEdit.new()
	nickname_input.custom_minimum_size = Vector2(510, 72)
	nickname_input.max_length = SaveGame.MAX_NICKNAME_LENGTH
	nickname_input.placeholder_text = L10n.text(tr("닉네임 입력"))
	nickname_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	nickname_input.add_theme_font_size_override("font_size", 28)
	nickname_input.add_theme_color_override("font_color", ArtDirection.ink())
	nickname_input.add_theme_color_override("font_placeholder_color", ArtDirection.muted_color())
	nickname_input.add_theme_stylebox_override("normal", _panel_style(Color("#fffafd"), Color("#b38acb"), 20))
	nickname_input.add_theme_stylebox_override("focus", _panel_style(Color.WHITE, Color("#e06e91"), 20))
	nickname_input.text_changed.connect(_on_nickname_text_changed)
	nickname_input.text_submitted.connect(func(_value: String): _confirm_nickname())
	content.add_child(nickname_input)
	nickname_error = Label.new()
	nickname_error.text = L10n.text("공백은 사용할 수 없어요.")
	nickname_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nickname_error.add_theme_font_size_override("font_size", 18)
	nickname_error.add_theme_color_override("font_color", ArtDirection.danger_color())
	nickname_error.modulate.a = 0.0
	content.add_child(nickname_error)
	var notice := Label.new()
	notice.text = L10n.text("※ 불법·음란·위험한 단어는 외부 노출 시 *로 표시될 수 있어요.")
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.custom_minimum_size.x = 540
	notice.add_theme_font_size_override("font_size", 17)
	notice.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(notice)
	nickname_confirm_button = _button(tr("이 이름으로 시작하기"), Color("#eb7b95"), Vector2(330, 70), 25)
	nickname_confirm_button.disabled = true
	nickname_confirm_button.pressed.connect(_confirm_nickname)
	content.add_child(nickname_confirm_button)
	nickname_input.call_deferred("grab_focus")


func _on_nickname_text_changed(value: String) -> void:
	var valid := SaveGame.is_valid_nickname(value)
	if nickname_confirm_button:
		nickname_confirm_button.disabled = not valid
	if nickname_error:
		nickname_error.modulate.a = 0.0 if value.is_empty() or valid else 1.0
		nickname_error.text = L10n.text("공백은 사용할 수 없어요.") if value.length() <= SaveGame.MAX_NICKNAME_LENGTH else L10n.text("닉네임은 12글자까지 사용할 수 있어요.")


func _confirm_nickname() -> void:
	if not nickname_input or not main.save.set_nickname(nickname_input.text):
		if nickname_error:
			nickname_error.text = L10n.text("공백 없이 1~12글자로 입력해 주세요.")
			nickname_error.modulate.a = 1.0
		return
	main.audio.play("shiny", 1.04)
	G.haptic(15)
	if header_name_label:
		header_name_label.text = main.save.get_nickname()
	if nickname_popup and is_instance_valid(nickname_popup):
		nickname_popup.queue_free()
	nickname_popup = null
	nickname_input = null
	nickname_error = null
	nickname_confirm_button = null
	_show_toast(L10n.text("%s님, 환영해요!") % main.save.get_nickname())
	call_deferred("_continue_first_time_flow")


func _continue_first_time_flow() -> void:
	if main.play_intro_if_needed():
		return
	# 첫 방문에는 닉네임과 이야기까지만 보여주고, 출석은 헤더의 알림 배지로 안내한다.
	# 캐릭터 상호작용까지 연달아 팝업으로 막지 않아 바로 방을 둘러볼 수 있게 한다.
	if not main.save.has_completed_tutorial("home_character_touch"):
		_show_home_interaction_hint()
		return
	_maybe_show_beta_feedback()


func _show_home_interaction_hint() -> void:
	if home_interaction_hint and is_instance_valid(home_interaction_hint):
		return
	var hint := Label.new()
	hint.name = "HomeInteractionHint"
	hint.text = L10n.text(tr("젤리몬과 친구들을 톡 눌러 보세요!"))
	hint.position = Vector2(145, 176)
	hint.size = Vector2(430, 66)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", ArtDirection.ink())
	hint.add_theme_color_override("font_outline_color", Color.WHITE)
	hint.add_theme_constant_override("outline_size", 0)
	var hint_style := _panel_style(Color("#fff8e8"), Color("#b47fc5"), 22)
	hint_style.set_border_width_all(1)
	hint_style.shadow_size = 3
	hint_style.shadow_offset = Vector2(0, 2)
	hint.add_theme_stylebox_override("normal", hint_style)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.z_index = 70
	ui_layer.add_child(hint)
	home_interaction_hint = hint
	hint.pivot_offset = hint.size * 0.5
	var pulse := hint.create_tween().set_loops(3)
	pulse.tween_property(hint, "scale", Vector2(1.03, 1.03), 0.42).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(hint, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_SINE)
	pulse.finished.connect(func():
		if is_instance_valid(hint):
			var fade := hint.create_tween()
			fade.tween_property(hint, "modulate:a", 0.0, 0.35)
			fade.finished.connect(hint.queue_free)
		if home_interaction_hint == hint:
			home_interaction_hint = null
	)


func _complete_home_interaction_hint() -> void:
	main.save.mark_tutorial_completed("home_character_touch")
	if home_interaction_hint and is_instance_valid(home_interaction_hint):
		home_interaction_hint.queue_free()
	home_interaction_hint = null


func _refresh_home_energy() -> void:
	if not home_energy_label or main == null:
		return
	var current: int = main.save.get_energy()
	var status := L10n.text("가득 참")
	if current < SaveGame.MAX_ENERGY:
		var seconds: int = main.save.seconds_until_next_energy()
		status = "%02d:%02d" % [seconds / 60, seconds % 60]
	home_energy_label.text = L10n.text((tr("%d/%d") if (ArtDirection.is_botanical() or ArtDirection.is_night()) else tr("♥ %d/%d")) % [current, SaveGame.MAX_ENERGY])
	home_energy_label.tooltip_text = L10n.text(tr("하트 가득 참") if current >= SaveGame.MAX_ENERGY else tr("다음 하트까지 %s") % status)


func _refresh_attendance_button() -> void:
	if not attendance_button:
		return
	var week: int = main.save.get_attendance_week()
	var claimed: int = main.save.get_attendance_day_in_week()
	if main.save.can_claim_attendance():
		attendance_button.text = L10n.text("선물 받기")
		attendance_button.tooltip_text = L10n.text("%d주차 %d일차 출석 선물을 받을 수 있어요") % [week, claimed + 1]
	else:
		attendance_button.text = L10n.text(tr("출석 %d/7") % claimed)
		attendance_button.tooltip_text = L10n.text("%d주차 출석 완료 · 다음 선물은 내일 받을 수 있어요") % week


func _shop_item_card(item: Dictionary) -> PanelContainer:
	var is_ads := L10n.text(String(item.get("type", ""))) == "remove_ads"
	var is_energy := L10n.text(String(item.get("type", ""))) == "energy"
	var is_furniture := L10n.text(String(item.get("type", ""))) == "furniture"
	var is_bundle := L10n.text(String(item.get("type", ""))) == "bundle"
	var is_season := L10n.text(String(item.get("type", ""))) == "season_pass"
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(570, 128)
	var style := StyleBoxFlat.new()
	style.bg_color = ArtDirection.panel_color()
	style.border_color = ArtDirection.border_color()
	style.set_border_width_all(1)
	style.set_corner_radius_all(24)
	style.corner_detail = 12
	style.shadow_color = Color(0.35, 0.22, 0.12, 0.10)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(92, 92)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = ArtDirection.panel_color()
	icon_style.set_corner_radius_all(25)
	icon_style.border_color = ArtDirection.border_color()
	icon_style.set_border_width_all(1)
	icon_frame.add_theme_stylebox_override("panel", icon_style)
	row.add_child(icon_frame)
	if is_furniture:
		var furniture_icon := Label.new()
		furniture_icon.text = L10n.text(String(item.get("mark", "◆")))
		furniture_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		furniture_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		furniture_icon.add_theme_font_size_override("font_size", 45)
		furniture_icon.add_theme_color_override("font_color", ArtDirection.ink())
		icon_frame.add_child(furniture_icon)
	elif is_ads:
		var ad_icon := Label.new()
		ad_icon.text = L10n.text("VIP\nPASS")
		ad_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ad_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ad_icon.add_theme_font_size_override("font_size", 23)
		ad_icon.add_theme_color_override("font_color", ArtDirection.ink())
		icon_frame.add_child(ad_icon)
	elif is_bundle:
		var pack_icon := Label.new()
		pack_icon.text = L10n.text("PACK")
		pack_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pack_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pack_icon.add_theme_font_size_override("font_size", 20)
		pack_icon.add_theme_color_override("font_color", ArtDirection.ink())
		icon_frame.add_child(pack_icon)
	elif is_energy:
		var heart_icon := Label.new()
		heart_icon.text = L10n.text("♥")
		heart_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heart_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		heart_icon.add_theme_font_size_override("font_size", 52)
		heart_icon.add_theme_color_override("font_color", ArtDirection.ink())
		icon_frame.add_child(heart_icon)
	else:
		var star := TextureRect.new()
		star.texture = load("res://assets/fx/ui_star.png")
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.custom_minimum_size = Vector2(76, 76)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_frame.add_child(star)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = L10n.text(String(item.get("name", "")))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", ArtDirection.ink())
	info.add_child(name_label)
	if String(item.get("id", "")) == main.save.recommended_shop_item_id():
		var recommended := Label.new()
		recommended.text = L10n.text("지금 추천 · 현재 진행에 가장 잘 맞아요")
		recommended.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		recommended.add_theme_font_size_override("font_size", 16)
		recommended.add_theme_color_override("font_color", ArtDirection.danger_color())
		info.add_child(recommended)
	if bool(item.get("exclusive", false)):
		var exclusive := Label.new()
		exclusive.text = L10n.text("EXCLUSIVE · 이 상품에서만 획득")
		exclusive.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		exclusive.add_theme_font_size_override("font_size", 16)
		exclusive.add_theme_color_override("font_color", ArtDirection.danger_color())
		info.add_child(exclusive)
	if String(item.get("id", "")) == "stardust_110":
		var best := Label.new()
		best.text = L10n.text("BEST · 10개 보너스")
		best.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		best.add_theme_font_size_override("font_size", 17)
		best.add_theme_color_override("font_color", ArtDirection.danger_color())
		info.add_child(best)
	var description := Label.new()
	description.text = L10n.text(String(item.get("description", "")))
	description.add_theme_font_size_override("font_size", 16)
	description.add_theme_color_override("font_color", ArtDirection.ink())
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(description)
	var purchased: bool = (is_season and main.save.season_premium) or (not bool(item.get("consumable", true)) and main.save.has_purchased_shop_item(String(item.get("id", "")))) or (is_furniture and main.save.has_furniture(L10n.text(String(item.get("furniture_id", "")))))
	var buy := _button(tr("보유 중") if purchased and is_furniture else (L10n.text("구매 완료") if purchased else L10n.text(String(item.get("display_price", "")))), Color("#77b984") if purchased else Color("#eb8650"), Vector2(135, 68), 23)
	buy.clip_text = true
	buy.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	buy.disabled = purchased
	buy.pressed.connect(func(): _show_purchase_confirmation(item, buy))
	if not is_furniture:
		_billing_buttons.append({"button": buy, "item": item})
		buy.text = L10n.text("구매 완료") if purchased else main.billing.price(item)
		buy.disabled = purchased or not main.billing.can_buy(item)
	row.add_child(buy)
	return card


func _furniture_shop_product(item: Dictionary) -> Dictionary:
	var id := String(item.id)
	return {
		"id": "furniture_" + id,
		"type": "furniture",
		"furniture_id": id,
		"name": L10n.text(String(item.name)),
		"display_price": "★ %s" % _format_number(RoomData.furniture_price(id)),
		"description": L10n.text("한 번 구매하면 젤리 아지트에서 영구적으로 배치할 수 있어요."),
		"color": String(item.color),
		"mark": L10n.text(String(item.mark)),
	}


func _show_shop_popup() -> void:
	if not main.save.home_feature_unlocked("shop"):
		_show_toast(L10n.text("LEVEL %d 클리어 후 상점이 열려요") % main.save.home_feature_unlock_level("shop"))
		return
	if shop_popup and is_instance_valid(shop_popup):
		return
	var dim := ColorRect.new()
	dim.color = ArtDirection.dim_color()
	_fit_overlay_to_viewport(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 92
	add_child(dim)
	shop_popup = dim
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(650, 1020)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#f5e9ff"), Color("#70499e"), 34))
	center.add_child(panel)
	panel.scale = Vector2(0.72, 0.72)
	panel.pivot_offset = Vector2(325, 510)
	panel.create_tween().tween_property(panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var title := Label.new()
	title.text = L10n.text(tr("★ 젤리몬 상점"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 43)
	title.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(title)
	shop_balance_label = Label.new()
	shop_balance_label.text = L10n.text("보유 별가루  ★ %d") % main.save.get_stardust()
	shop_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_balance_label.add_theme_font_size_override("font_size", 22)
	shop_balance_label.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(shop_balance_label)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 12)
	content.add_child(tabs)
	var tab_group := ButtonGroup.new()
	tab_group.allow_unpress = false
	var currency_tab := _button(tr("★ 별가루·하트"), Color("#e48a48"), Vector2(275, 64), 23)
	currency_tab.toggle_mode = true
	currency_tab.button_group = tab_group
	currency_tab.button_pressed = true
	tabs.add_child(currency_tab)
	var furniture_tab := _button(tr("▦ 가구"), Color("#4c9dcc"), Vector2(275, 64), 23)
	furniture_tab.toggle_mode = true
	furniture_tab.button_group = tab_group
	tabs.add_child(furniture_tab)

	# 두 상품군은 같은 영역을 공유하고 선택한 탭의 목록만 표시한다.
	var tab_content := Control.new()
	tab_content.custom_minimum_size = Vector2(600, 620)
	tab_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(tab_content)
	var currency_scroll := ScrollContainer.new()
	currency_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	currency_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	currency_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	currency_scroll.scroll_deadzone = 8
	tab_content.add_child(currency_scroll)
	var currency_products := VBoxContainer.new()
	currency_products.custom_minimum_size = Vector2(570, 0)
	currency_products.add_theme_constant_override("separation", 10)
	currency_scroll.add_child(currency_products)
	var currency_guide := Label.new()
	currency_guide.text = L10n.text("모험에 필요한 별가루와 하트를 충전하세요.")
	currency_guide.add_theme_font_size_override("font_size", 20)
	currency_guide.add_theme_color_override("font_color", ArtDirection.ink())
	currency_products.add_child(currency_guide)
	if main.save.has_removed_ads():
		currency_products.add_child(_vip_support_button())
	var shop_items := ShopCatalog.load_items()
	var recommended_id: String = L10n.text(String(main.save.recommended_shop_item_id()))
	if main.analytics and not recommended_id.is_empty():
		main.analytics.track("shop_offer_view", {"item_id":recommended_id,"reason":"progress_recommendation"})
	shop_items.sort_custom(func(a: Dictionary, b: Dictionary): return String(a.get("id", "")) == recommended_id and String(b.get("id", "")) != recommended_id)
	for item in shop_items:
		currency_products.add_child(_shop_item_card(item))

	var furniture_scroll := ScrollContainer.new()
	furniture_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	furniture_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	furniture_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	furniture_scroll.scroll_deadzone = 8
	furniture_scroll.visible = false
	tab_content.add_child(furniture_scroll)
	var furniture_products := VBoxContainer.new()
	furniture_products.custom_minimum_size = Vector2(570, 0)
	furniture_products.add_theme_constant_override("separation", 10)
	furniture_scroll.add_child(furniture_products)
	var furniture_guide := Label.new()
	furniture_guide.text = L10n.text("별가루로 구매한 가구는 영구적으로 보유해요.")
	furniture_guide.add_theme_font_size_override("font_size", 20)
	furniture_guide.add_theme_color_override("font_color", ArtDirection.ink())
	furniture_products.add_child(furniture_guide)
	var milestone_reward_ids := FurnitureRewards.reward_item_ids()
	for furniture in RoomData.purchasable_items():
		if milestone_reward_ids.has(String(furniture.id)):
			continue
		furniture_products.add_child(_shop_item_card(_furniture_shop_product(furniture)))
	currency_tab.pressed.connect(func():
		currency_scroll.visible = true
		furniture_scroll.visible = false
	)
	furniture_tab.pressed.connect(func():
		currency_scroll.visible = false
		furniture_scroll.visible = true
	)
	shop_status_label = Label.new()
	shop_status_label.text = L10n.text(main.billing.status)
	shop_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_status_label.add_theme_font_size_override("font_size", 16)
	shop_status_label.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(shop_status_label)
	var restore := _button(L10n.text("구매 복원 / 상품 새로고침"), ArtDirection.panel_color(), Vector2(390, 58), 21)
	restore.pressed.connect(func(): main.billing.refresh())
	content.add_child(restore)
	var close := _button(tr("닫기"), Color("#806aa7"), Vector2(190, 64), 24)
	close.pressed.connect(_close_shop_popup)
	content.add_child(close)
	main.billing.refresh()

func _refresh_billing_ui() -> void:
	if not is_instance_valid(shop_status_label): return
	shop_status_label.text = L10n.text(main.billing.status)
	for entry in _billing_buttons:
		if not is_instance_valid(entry.button): continue
		var item: Dictionary = entry.item
		var owned: bool = main.save.has_purchased_shop_item(String(item.id)) or (L10n.text(String(item.type)) == "season_pass" and main.save.season_premium)
		entry.button.text = L10n.text("구매 완료") if owned else main.billing.price(item)
		entry.button.disabled = owned or not main.billing.can_buy(item)
	shop_balance_label.text = L10n.text("보유 별가루  ★ %d") % main.save.get_stardust()
	stardust_label.text = L10n.text(("%s" if (ArtDirection.is_botanical() or ArtDirection.is_night()) else "★ %s") % _format_number(main.save.get_stardust()))
	_refresh_home_energy()
	_refresh_vip_identity()


func _show_purchase_confirmation(item: Dictionary, buy_button: Button) -> void:
	if purchase_confirm_popup and is_instance_valid(purchase_confirm_popup):
		return
	var dim := ColorRect.new()
	dim.color = ArtDirection.dim_color()
	_fit_overlay_to_viewport(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 125
	add_child(dim)
	purchase_confirm_popup = dim
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(570, 470)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#fff5fb"), Color("#8d64b4"), 34))
	center.add_child(panel)
	panel.scale = Vector2(0.76, 0.76)
	panel.pivot_offset = Vector2(285, 235)
	panel.create_tween().tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 15)
	panel.add_child(content)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(96, 96)
	var badge_style := StyleBoxFlat.new()
	var item_type := L10n.text(String(item.get("type", "")))
	badge_style.bg_color = ArtDirection.panel_color()
	badge_style.border_color = ArtDirection.border_color()
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(30)
	badge.add_theme_stylebox_override("panel", badge_style)
	content.add_child(badge)
	var badge_icon := Label.new()
	badge_icon.text = L10n.text(String(item.get("mark", "◆"))) if item_type == "furniture" else ("★" if item_type == "stardust" else ("♥" if item_type == "energy" else ("PACK" if item_type == "bundle" else "VIP\nPASS")))
	badge_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_icon.add_theme_font_size_override("font_size", 20 if ["remove_ads", "bundle"].has(L10n.text(String(item.get("type", "")))) else 48)
	badge_icon.add_theme_color_override("font_color", ArtDirection.ink())
	badge.add_child(badge_icon)
	var title := Label.new()
	title.text = L10n.text(tr("구매할까요?"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 37)
	title.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(title)
	var product := Label.new()
	product.text = L10n.text("%s\n%s" % [L10n.text(String(item.get("name", ""))), L10n.text(String(item.get("display_price", ""))) if item_type == "furniture" else main.billing.price(item)])
	product.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	product.add_theme_font_size_override("font_size", 25)
	product.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(product)
	var notice := Label.new()
	notice.text = L10n.text("보유 별가루에서 즉시 차감됩니다.") if item_type == "furniture" else L10n.text("%s 결제창에서 최종 확인 후 구매합니다.") % main.platform.billing_store_name()
	if item_type == "season_pass": notice.text += L10n.text("\n현재 시즌 종료까지 이용 · 자동 갱신 없음")
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_font_size_override("font_size", 17)
	notice.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(notice)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	content.add_child(actions)
	var cancel := _button(tr("취소"), Color("#8b78a9"), Vector2(190, 70), 25)
	cancel.pressed.connect(_close_purchase_confirmation)
	actions.add_child(cancel)
	var confirm := _button(tr("구매"), Color("#eb7b55"), Vector2(230, 70), 26)
	confirm.pressed.connect(func():
		_close_purchase_confirmation()
		_purchase_shop_item(item, buy_button)
	)
	actions.add_child(confirm)


func _close_purchase_confirmation() -> void:
	if purchase_confirm_popup and is_instance_valid(purchase_confirm_popup):
		purchase_confirm_popup.queue_free()
	purchase_confirm_popup = null


func _purchase_shop_item(item: Dictionary, buy_button: Button) -> void:
	var analytics_item_id := String(item.get("id", item.get("furniture_id", "unknown")))
	var analytics_item_kind := L10n.text(String(item.get("type", "unknown")))
	if L10n.text(String(item.get("type", ""))) == "furniture":
		var furniture_id := L10n.text(String(item.get("furniture_id", "")))
		var price := RoomData.furniture_price(furniture_id)
		if main.save.has_furniture(furniture_id):
			shop_status_label.text = L10n.text("이미 보유한 가구예요.")
			return
		if main.save.get_stardust() < price:
			shop_status_label.text = L10n.text("별가루가 부족해요.  ★ %s 필요") % _format_number(price)
			return
		if not main.save.purchase_furniture(furniture_id, price):
			shop_status_label.text = L10n.text("가구를 구매하지 못했어요.")
			if main.analytics:
				main.analytics.track("shop_purchase", {"item_id": analytics_item_id, "kind": analytics_item_kind, "result": "failed"})
			return
		if main.analytics:
			main.analytics.track("shop_purchase", {"item_id": analytics_item_id, "kind": analytics_item_kind, "result": "success"})
			main.analytics.track("currency_sink", {"currency": "stardust", "amount": price, "sink": "furniture"})
		main.audio.play("shiny", 1.05)
		G.haptic(18)
		stardust_label.text = L10n.text(("%s" if (ArtDirection.is_botanical() or ArtDirection.is_night()) else "★ %s") % _format_number(main.save.get_stardust()))
		shop_balance_label.text = L10n.text("보유 별가루  ★ %d") % main.save.get_stardust()
		buy_button.text = L10n.text(tr("보유 중"))
		buy_button.disabled = true
		shop_status_label.text = L10n.text("%s 구매 완료! 꾸미기에서 배치할 수 있어요.") % L10n.text(String(item.get("name", "")))
		return
	main.billing.purchase(item)


func _close_shop_popup() -> void:
	_billing_buttons.clear()
	_close_purchase_confirmation()
	if shop_popup and is_instance_valid(shop_popup):
		shop_popup.queue_free()
	shop_popup = null
	shop_balance_label = null
	shop_status_label = null


func _attendance_tile(day: int, reward: Dictionary, claimed_days: int, claimable: bool) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(76, 118)
	var style := StyleBoxFlat.new()
	var already_claimed := day <= claimed_days
	var is_today := day == claimed_days + 1 and claimable
	var day_colors := [Color("#ffd9df"), Color("#ffe4bf"), Color("#d8ecff"), Color("#dff2d8"), Color("#e8dcfa"), Color("#d7f0f1"), Color("#ffd4e8")]
	var day_color: Color = day_colors[day - 1]
	style.bg_color = ArtDirection.selected_color() if already_claimed else ((ArtDirection.selected_color() if ArtDirection.is_night() else Color("#ffe5d8")) if is_today else ArtDirection.panel_color())
	style.border_color = ArtDirection.border_color()
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.corner_detail = 10
	style.shadow_color = Color(0.35, 0.22, 0.12, 0.10)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	tile.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	tile.add_child(box)
	var day_label := Label.new()
	day_label.text = L10n.text("%d일%s") % [day, " ✓" if already_claimed else ""]
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_label.add_theme_font_size_override("font_size", 18)
	day_label.add_theme_color_override("font_color", ArtDirection.ink())
	box.add_child(day_label)
	var reward_label := Label.new()
	reward_label.text = L10n.text(_attendance_reward_compact(reward))
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward_label.custom_minimum_size = Vector2(68, 57)
	reward_label.add_theme_font_size_override("font_size", 16)
	reward_label.add_theme_color_override("font_color", ArtDirection.ink())
	box.add_child(reward_label)
	return tile


func _attendance_reward_compact(reward: Dictionary) -> String:
	var lines: Array[String] = []
	var stardust := int(reward.get("stardust", 0))
	var energy := int(reward.get("energy", 0))
	if stardust > 0:
		lines.append(L10n.text("★ 별 %d") % stardust)
	if energy > 0:
		lines.append(L10n.text("♥ 하트 %d") % energy)
	return "\n".join(lines)


func _attendance_reward_sentence(reward: Dictionary) -> String:
	var parts: Array[String] = []
	var stardust := int(reward.get("stardust", 0))
	var energy := int(reward.get("energy", 0))
	if stardust > 0:
		parts.append(L10n.text("별가루 %d개") % stardust)
	if energy > 0:
		parts.append(L10n.text("하트 %d개") % energy)
	return " + ".join(parts)


func _show_attendance_popup() -> void:
	if attendance_popup and is_instance_valid(attendance_popup):
		return
	var dim := ColorRect.new()
	dim.color = ArtDirection.dim_color()
	_fit_overlay_to_viewport(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 90
	add_child(dim)
	attendance_popup = dim
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(650, 600)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#f1e3fa"), Color("#70499e"), 34))
	center.add_child(panel)
	panel.scale = Vector2(0.72, 0.72)
	panel.pivot_offset = Vector2(325, 300)
	panel.create_tween().tween_property(panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var week: int = main.save.get_attendance_week()
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 15)
	panel.add_child(content)
	# 제목을 별도 글래스 배너로 묶어 단순한 흰 팝업 대신 이벤트 카드처럼 보이게 한다.
	var banner := PanelContainer.new()
	banner.custom_minimum_size = Vector2(590, 126)
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = ArtDirection.panel_color()
	banner_style.border_color = ArtDirection.border_color()
	banner_style.set_border_width_all(1)
	banner_style.set_corner_radius_all(25)
	banner_style.corner_detail = 12
	banner_style.shadow_color = Color(0.35, 0.22, 0.12, 0.10)
	banner_style.shadow_size = 3
	banner_style.shadow_offset = Vector2(0, 2)
	banner.add_theme_stylebox_override("panel", banner_style)
	content.add_child(banner)
	var banner_row := HBoxContainer.new()
	banner_row.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_row.add_theme_constant_override("separation", 12)
	banner.add_child(banner_row)
	for side in range(2):
		if side == 1:
			var copy := TextureRect.new()
			copy.texture = load("res://assets/fx/ui_star.png")
			copy.custom_minimum_size = Vector2(58, 58)
			copy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			copy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			copy.modulate = Color("#ffd66b")
			copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
			banner_row.add_child(copy)
			continue
		var left_star := TextureRect.new()
		left_star.texture = load("res://assets/fx/ui_star.png")
		left_star.custom_minimum_size = Vector2(58, 58)
		left_star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		left_star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		left_star.modulate = Color("#ffd66b")
		left_star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner_row.add_child(left_star)
		var heading := VBoxContainer.new()
		heading.alignment = BoxContainer.ALIGNMENT_CENTER
		heading.add_theme_constant_override("separation", 2)
		banner_row.add_child(heading)
		var title := Label.new()
		title.text = L10n.text("첫 주 출석 선물") if week == 1 else L10n.text("%d주차 출석 선물") % week
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 40)
		title.add_theme_color_override("font_color", ArtDirection.ink())
		heading.add_child(title)
		var subtitle := Label.new()
		subtitle.text = L10n.text("별가루와 하트를 매일 함께 받아요!") if week == 1 else L10n.text("매주 새로운 선물이 기다리고 있어요!")
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_font_size_override("font_size", 20)
		subtitle.add_theme_color_override("font_color", ArtDirection.ink())
		heading.add_child(subtitle)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 7)
	content.add_child(row)
	var claimed_days: int = main.save.get_attendance_day_in_week()
	var claimable: bool = main.save.can_claim_attendance()
	var week_rewards: Array[Dictionary] = main.save.get_attendance_week_rewards()
	for i in range(week_rewards.size()):
		row.add_child(_attendance_tile(i + 1, week_rewards[i], claimed_days, claimable))
	var status_panel := PanelContainer.new()
	var status_style := StyleBoxFlat.new()
	status_style.bg_color = ArtDirection.panel_color()
	status_style.border_color = ArtDirection.border_color()
	status_style.set_border_width_all(1)
	status_style.set_corner_radius_all(18)
	status_panel.add_theme_stylebox_override("panel", status_style)
	content.add_child(status_panel)
	var status := Label.new()
	status.custom_minimum_size = Vector2(540, 48)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 23)
	status.add_theme_color_override("font_color", ArtDirection.ink())
	if claimable:
		status.text = L10n.text("오늘은 %s를 받을 수 있어요.") % _attendance_reward_sentence(main.save.get_attendance_next_reward())
	else:
		status.text = L10n.text("오늘 선물을 받았어요. 내일 다시 만나요!")
	status_panel.add_child(status)
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 12)
	content.add_child(action_row)
	if claimable:
		var claim := _button(L10n.text("선물 받기  ") + _attendance_reward_compact(main.save.get_attendance_next_reward()).replace("\n", "  "), Color("#f29b45"), Vector2(330, 70), 23)
		claim.pressed.connect(_claim_attendance)
		action_row.add_child(claim)
	var close := _button(tr("닫기"), Color("#806aa7"), Vector2(150, 70), 25)
	close.pressed.connect(_close_attendance_popup)
	action_row.add_child(close)


func _claim_attendance() -> void:
	var reward: Dictionary = main.save.claim_attendance()
	if reward.is_empty():
		return
	main.audio.play("reward")
	G.haptic(18)
	if stardust_label:
		stardust_label.text = L10n.text(("%s" if (ArtDirection.is_botanical() or ArtDirection.is_night()) else "★ %s") % _format_number(main.save.get_stardust()))
	_refresh_home_energy()
	_close_attendance_popup(false)
	_refresh_attendance_button()
	var popup := AttendanceRewardPopupLib.new()
	popup.reward = reward.duplicate(true)
	_fit_overlay_to_viewport(popup)
	popup.confirmed.connect(_close_attendance_popup)
	attendance_popup = popup
	add_child(popup)


func _close_attendance_popup(show_feedback: bool = true) -> void:
	if attendance_popup and is_instance_valid(attendance_popup):
		attendance_popup.queue_free()
	attendance_popup = null
	if show_feedback:
		call_deferred("_maybe_show_beta_feedback")


func _maybe_show_beta_feedback() -> void:
	if main.save.beta_feedback_submitted or main.save.get_stars(9) <= 0 or main.analytics == null or not main.analytics.feedback_prompt_enabled():
		return
	_show_beta_feedback_popup()


func _show_beta_feedback_popup() -> void:
	var dim := ColorRect.new()
	dim.color = ArtDirection.dim_color()
	_fit_overlay_to_viewport(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 410
	ui_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(610, 0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#fff8f1"), Color("#8c65b5"), 34))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)
	var title := Label.new()
	title.text = L10n.text("구조대 경험을 알려주세요")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(title)
	var guide := Label.new()
	guide.text = L10n.text("LEVEL 10까지 함께해 주셔서 고마워요.\n세 문항은 게임 개선에만 사용돼요.")
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide.add_theme_font_size_override("font_size", 19)
	guide.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(guide)
	var answers := {"fun":0,"attachment":0,"purchase_intent":0}
	for spec in [["fun",L10n.text("퍼즐이 계속하고 싶을 만큼 재미있나요?")],["attachment",L10n.text("젤리몬과 주민에게 애착이 생겼나요?")],["purchase_intent",L10n.text("시즌·꾸미기 상품이 갖고 싶나요?")]]:
		var question_id := L10n.text(String(spec[0]))
		var question := Label.new()
		question.text = L10n.text(String(spec[1]))
		question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		question.add_theme_font_size_override("font_size", 20)
		question.add_theme_color_override("font_color", ArtDirection.ink())
		content.add_child(question)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		content.add_child(row)
		for score in range(1, 6):
			var score_value := score
			var rating := _button(str(score), Color("#9b7ac4"), Vector2(74, 58), 21)
			rating.pressed.connect(func():
				answers[question_id] = score_value
				for child in row.get_children(): child.modulate = Color.WHITE
				rating.modulate = Color("#fff0a0")
			)
			row.add_child(rating)
	var submit := _button(L10n.text("의견 보내기"), Color("#ef7c57"), Vector2(320, 72), 25)
	submit.pressed.connect(func():
		if int(answers.fun) <= 0 or int(answers.attachment) <= 0 or int(answers.purchase_intent) <= 0:
			_show_toast(L10n.text("세 문항에 모두 답해 주세요"))
			return
		main.analytics.track("beta_feedback", {"fun":int(answers.fun),"attachment":int(answers.attachment),"purchase_intent":int(answers.purchase_intent),"level":10})
		main.analytics.flush()
		main.save.mark_beta_feedback_submitted()
		dim.queue_free()
		_show_toast(L10n.text("고마워요! 더 재미있는 구조 작전을 만들게요"))
	)
	content.add_child(submit)
	var later := _button(L10n.text("다음에 답하기"), Color("#8d8398"), Vector2(230, 58), 19)
	later.pressed.connect(dim.queue_free)
	content.add_child(later)


func _refresh_mission_button() -> void:
	if not mission_button:
		return
	var completed: int = main.save.get_daily_completed_count()
	if main.save.has_claimed_daily_mission_chest():
		mission_button.text = L10n.text("✓ 완료")
	elif main.save.can_claim_daily_mission_chest():
		mission_button.text = L10n.text(tr("상자 받기!"))
	else:
		mission_button.text = L10n.text(tr("구조 %d/3") % completed)


func _mission_row(mission: Dictionary) -> PanelContainer:
	var id := String(mission.get("id", ""))
	var target := int(mission.get("target", 1))
	var progress: int = main.save.get_daily_mission_progress(id)
	var complete: bool = progress >= target
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(570, 72)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#effbf4") if complete else Color("#fff8ef"), Color("#53b77a") if complete else Color("#d4a878"), 18))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var badge := Label.new()
	badge.text = L10n.text("✓" if complete else str(progress))
	badge.custom_minimum_size = Vector2(50, 0)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 27)
	badge.add_theme_color_override("font_color", ArtDirection.text_color(Color("#3a9c67") if complete else Color("#df7652")))
	row.add_child(badge)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	var title := Label.new()
	title.text = L10n.text(String(mission.get("title", L10n.text("오늘의 구조"))))
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", ArtDirection.ink())
	copy.add_child(title)
	var desc := Label.new()
	desc.text = L10n.text(String(mission.get("description", "")))
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", ArtDirection.ink())
	copy.add_child(desc)
	var count := Label.new()
	count.text = L10n.text("%d / %d" % [progress, target])
	count.custom_minimum_size = Vector2(82, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", 20)
	count.add_theme_color_override("font_color", ArtDirection.text_color(Color("#3a9c67") if complete else Color("#7d6489")))
	row.add_child(count)
	return panel


func _current_chapter_progress() -> Dictionary:
	var idx := _next_level_index()
	var chapter := clampi(idx / 10, 0, Levels.CHAPTER_NAMES.size() - 1)
	var start := chapter * 10
	var cleared := 0
	for level_idx in range(start, mini(start + 10, Levels.level_count())):
		if main.save.get_stars(level_idx) > 0:
			cleared += 1
	var reward := FurnitureRewardCatalog.reward_for_level((chapter + 1) * 10)
	return {"chapter": chapter, "cleared": cleared, "reward": reward}


func _show_daily_mission_popup() -> void:
	if not main.save.home_feature_unlocked("missions"):
		return
	if mission_popup and is_instance_valid(mission_popup):
		return
	var dim := ColorRect.new()
	dim.color = ArtDirection.dim_color()
	_fit_overlay_to_viewport(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 250
	ui_layer.add_child(dim)
	mission_popup = dim
	var card := PanelContainer.new()
	card.position = Vector2(55, 100)
	card.size = Vector2(610, 1060)
	card.add_theme_stylebox_override("panel", _panel_style(Color("#fffaf3"), Color("#8b62bd"), 34))
	dim.add_child(card)
	_center_popup_horizontally(card)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	card.add_child(content)
	var heading := Label.new()
	heading.text = L10n.text(tr("오늘의 구조"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 35)
	heading.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(heading)
	var sub := Label.new()
	sub.text = L10n.text("매일 세 가지 부탁을 완료하고 구조 상자를 받아요!")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(sub)
	var lifestyle := _button(L10n.text("주민 부탁 · 시즌 · 마을  ▶"), Color("#d06f91"), Vector2(520, 55), 19)
	main.save.refresh_season()
	lifestyle.disabled = not main.save.home_feature_unlocked("lifestyle") and not main.save.season_premium
	if lifestyle.disabled:
		lifestyle.text = L10n.text("🔒 LEVEL %d · 시즌 생활") % main.save.home_feature_unlock_level("lifestyle")
	lifestyle.pressed.connect(func():
		_close_daily_mission_popup()
		_show_lifestyle_popup()
	)
	content.add_child(lifestyle)
	var daily_done: bool = bool(main.save.has_completed_daily_challenge())
	var daily_level: int = int(LiveProgressionCatalogLib.daily_challenge_level())
	var daily_button := _button(L10n.text("✓ 오늘의 특별 구조 완료") if daily_done else L10n.text("오늘의 특별 구조  ·  LEVEL %d  ▶") % daily_level, Color("#6e5fc4") if not daily_done else Color("#70aa82"), Vector2(520, 58), 19)
	daily_button.disabled = daily_done
	daily_button.tooltip_text = L10n.text("하루 한 번, 하트 소모 없이 도전하고 별가루와 시간 부스터를 받아요.")
	daily_button.pressed.connect(func():
		_close_daily_mission_popup()
		main.start_daily_challenge()
	)
	content.add_child(daily_button)
	var expedition_step: int = int(main.save.get_weekly_expedition_step())
	var expedition_button := _button(L10n.text("✓ 이번 주 5단계 원정 완료") if expedition_step >= 5 else L10n.text("주간 원정  %d/5  ·  다음 작전 ▶") % expedition_step, Color("#3d9daa") if expedition_step < 5 else Color("#70aa82"), Vector2(520, 58), 19)
	expedition_button.disabled = expedition_step >= 5
	expedition_button.tooltip_text = L10n.text("매주 바뀌는 5개 퍼즐을 연속 구조하고 부스터 묶음을 받아요.")
	expedition_button.pressed.connect(func():
		_close_daily_mission_popup()
		main.start_weekly_expedition()
	)
	content.add_child(expedition_button)
	for mission in DailyMissionCatalogLib.missions():
		content.add_child(_mission_row(mission))
	var reward := DailyMissionCatalogLib.reward()
	var chest := _button(L10n.text("구조 상자  ★ %d  ♥ %d") % [int(reward.get("stardust", 0)), int(reward.get("energy", 0))], Color("#f09a42"), Vector2(420, 72), 22)
	chest.disabled = not main.save.can_claim_daily_mission_chest()
	chest.pressed.connect(_claim_daily_mission_chest)
	content.add_child(chest)
	var divider := HSeparator.new()
	divider.custom_minimum_size.y = 8
	content.add_child(divider)
	var chapter_data := _current_chapter_progress()
	var chapter := int(chapter_data.chapter)
	var reward_data: Dictionary = chapter_data.reward
	var chapter_title := Label.new()
	chapter_title.text = L10n.text("CHAPTER %d · %s" % [chapter + 1, L10n.text(Levels.CHAPTER_NAMES[chapter])])
	chapter_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter_title.add_theme_font_size_override("font_size", 24)
	chapter_title.add_theme_color_override("font_color", ArtDirection.text_color(Levels.CHAPTER_COLORS[chapter].darkened(0.28)))
	content.add_child(chapter_title)
	var track := ProgressBar.new()
	track.custom_minimum_size = Vector2(540, 34)
	track.max_value = 10
	track.value = int(chapter_data.cleared)
	track.show_percentage = false
	track.add_theme_stylebox_override("background", ArtDirection.surface(ArtDirection.disabled_color(), 15))
	track.add_theme_stylebox_override("fill", ArtDirection.surface(ArtDirection.primary_color(), 15))
	content.add_child(track)
	var track_copy := Label.new()
	track_copy.text = L10n.text("%d / 10 구조 · 완주 보상: %s") % [int(chapter_data.cleared), L10n.text(String(reward_data.get("title", L10n.text("기념 가구"))))]
	track_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	track_copy.add_theme_font_size_override("font_size", 18)
	track_copy.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(track_copy)
	var weekly: Dictionary = LiveProgressionCatalogLib.weekly()
	var weekly_parts: Array[String] = []
	for mission in weekly.get("missions", []):
		weekly_parts.append("%d/%d" % [main.save.get_weekly_progress(String(mission.get("id", ""))), int(mission.get("target", 0))])
	var weekly_button := _button(L10n.text("주간 작전  %s") % " · ".join(weekly_parts), Color("#4fa7b4"), Vector2(500, 57), 18)
	weekly_button.disabled = not main.save.can_claim_weekly_reward()
	weekly_button.pressed.connect(_claim_weekly_reward)
	content.add_child(weekly_button)
	var season: Dictionary = LiveProgressionCatalogLib.season()
	var season_stars: int = RoomData.total_stars(main.save)
	var next_milestone := 0
	for milestone in season.get("milestones", []):
		var target := int(milestone.get("stars", 0))
		if not main.save.claimed_season_milestones.has(target):
			next_milestone = target
			break
	if next_milestone > 0:
		var season_button := _button(L10n.text("시즌 패스  ★ %d/%d") % [season_stars, next_milestone], Color("#8b64c4"), Vector2(500, 57), 18)
		season_button.disabled = season_stars < next_milestone
		season_button.pressed.connect(func(): _claim_season_reward(next_milestone))
		content.add_child(season_button)
	var close := _button(tr("닫기"), Color("#8065aa"), Vector2(210, 62), 22)
	close.pressed.connect(_close_daily_mission_popup)
	content.add_child(close)


func _vip_support_button() -> Button:
	var button := _button(L10n.text("VIP 오늘의 구조 지원 · 별가루 8 + 시간 젤리 1"), Color("#d7aa39"), Vector2(530, 58), 17)
	button.set_meta("vip_daily_support", true)
	button.disabled = not main.save.can_claim_vip_daily_support()
	if button.disabled:
		button.text = L10n.text("VIP 오늘의 구조 지원 · 수령 완료")
	button.pressed.connect(func():
		var reward: Dictionary = main.save.claim_vip_daily_support()
		if reward.is_empty(): return
		button.disabled = true
		button.text = L10n.text("VIP 오늘의 구조 지원 · 수령 완료")
		if main.analytics: main.analytics.track("vip_daily_support", {"result":"claimed"})
		_refresh_billing_ui()
		_show_toast(L10n.text("VIP 지원 도착! 별가루 8 · 시간 젤리 1"))
	)
	return button


func _show_lifestyle_popup() -> void:
	main.save.refresh_season()
	if not main.save.home_feature_unlocked("lifestyle") and not main.save.season_premium:
		return
	if lifestyle_popup and is_instance_valid(lifestyle_popup):
		return
	main.save.refresh_resident_requests()
	main.save.refresh_season()
	var dim := ColorRect.new()
	dim.color = ArtDirection.dim_color()
	_fit_overlay_to_viewport(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 290
	ui_layer.add_child(dim)
	lifestyle_popup = dim
	var card := PanelContainer.new()
	card.position = Vector2(45, 70)
	card.size = Vector2(630, 1120)
	card.add_theme_stylebox_override("panel", _panel_style(Color("#fff7f2"), Color("#8a58ae"), 34))
	dim.add_child(card)
	_center_popup_horizontally(card)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	card.add_child(outer)
	var heading := Label.new()
	heading.text = L10n.text(tr("마음별 시즌 생활"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	heading.add_theme_color_override("font_color", ArtDirection.ink())
	outer.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(590, 950)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 570
	content.add_theme_constant_override("separation", 13)
	scroll.add_child(content)
	if main.save.has_removed_ads():
		content.add_child(_vip_support_button())
	var request_title := Label.new()
	request_title.text = L10n.text(tr("오늘의 주민 부탁"))
	request_title.add_theme_font_size_override("font_size", 27)
	request_title.add_theme_color_override("font_color", ArtDirection.danger_color())
	content.add_child(request_title)
	for request in main.save.resident_requests:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(560, 108)
		var request_style := _panel_style(Color("#fff8fb"), G.COLORS.get(String(request.get("color", "R")), Color("#d16e8c")).darkened(0.08), 20)
		request_style.set_border_width_all(1)
		request_style.shadow_size = 3
		request_style.shadow_offset = Vector2(0, 2)
		request_style.content_margin_left = 16
		request_style.content_margin_right = 12
		panel.add_theme_stylebox_override("panel", request_style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		panel.add_child(row)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.alignment = BoxContainer.ALIGNMENT_CENTER
		copy.add_theme_constant_override("separation", 5)
		row.add_child(copy)
		var title := Label.new()
		title.text = L10n.text("%s · %s" % [L10n.text(String(request.get("resident_name", L10n.text("주민")))), L10n.text(String(request.get("title", L10n.text("부탁"))))])
		title.add_theme_font_size_override("font_size", 22)
		title.add_theme_color_override("font_color", ArtDirection.ink())
		copy.add_child(title)
		var progress := Label.new()
		progress.text = L10n.text("%s  %d/%d" % [L10n.text(String(request.get("description", ""))), int(request.get("progress", 0)), int(request.get("target", 1))])
		progress.add_theme_font_size_override("font_size", 18)
		progress.add_theme_color_override("font_color", ArtDirection.ink())
		copy.add_child(progress)
		var claimed := bool(request.get("claimed", false))
		var claim := _button(tr("완료") if claimed else L10n.text("받기"), Color("#70ae7f") if claimed else Color("#e98558"), Vector2(112, 64), 20)
		_style_lifestyle_button(claim, Color("#e7ddd8") if not claimed else Color("#dceade"), Color("#a17b6c") if not claimed else Color("#6a9874"), Color("#68483e") if not claimed else Color("#31563b"), claimed)
		claim.disabled = claimed or int(request.get("progress", 0)) < int(request.get("target", 1))
		var request_id := String(request.get("id", ""))
		claim.pressed.connect(func(): _claim_resident_request(request_id))
		row.add_child(claim)
		content.add_child(panel)
	var season := RetentionCatalogLib.season()
	var season_title := Label.new()
	season_title.text = L10n.text("%s · %d일 남음\nLV.%d/20 · XP %d") % [L10n.text(String(season.get("title", L10n.text("시즌")))), RetentionCatalogLib.season_days_remaining(), main.save.season_level(), main.save.season_xp]
	season_title.add_theme_font_size_override("font_size", 26)
	season_title.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(season_title)
	if not main.save.season_premium:
		var premium := _button(tr("프리미엄 보상 열기 · 상점으로"), Color("#8052b4"), Vector2(520, 64), 21)
		premium.add_theme_constant_override("outline_size", 0)
		premium.pressed.connect(func():
			_close_lifestyle_popup()
			_show_shop_popup()
		)
		content.add_child(premium)
	for level in RetentionCatalogLib.season_reward_levels():
		var reward_row := HBoxContainer.new()
		reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
		reward_row.add_theme_constant_override("separation", 8)
		var free_reward: Dictionary = season.get("free_rewards", {}).get(str(level), {})
		var premium_reward: Dictionary = season.get("premium_rewards", {}).get(str(level), {})
		var free_button := _button(tr("무료 %d · %s%s") % [level, _compact_reward(free_reward), " ✓" if main.save.claimed_season_free.has(level) else ""], Color("#438f8d"), Vector2(250, 58), 16)
		_style_lifestyle_button(free_button, Color("#dcebea"), Color("#659492"), Color("#315d5b"), main.save.claimed_season_free.has(level))
		free_button.visible = not free_reward.is_empty()
		free_button.disabled = free_reward.is_empty() or main.save.claimed_season_free.has(level) or level > main.save.season_level()
		free_button.pressed.connect(func(): _claim_retention_season(level, false))
		free_button.set_meta("season_reward_level", level)
		free_button.set_meta("premium", false)
		reward_row.add_child(free_button)
		var premium_button := _button(tr("프리미엄 %d · %s%s") % [level, _compact_reward(premium_reward), " ✓" if main.save.claimed_season_premium.has(level) else ""], Color("#8055ab"), Vector2(280, 58), 16)
		_style_lifestyle_button(premium_button, Color("#e5deec"), Color("#8c75a3"), Color("#554268"), main.save.claimed_season_premium.has(level))
		premium_button.visible = not premium_reward.is_empty()
		premium_button.disabled = premium_reward.is_empty() or not main.save.season_premium or main.save.claimed_season_premium.has(level) or level > main.save.season_level()
		premium_button.pressed.connect(func(): _claim_retention_season(level, true))
		premium_button.set_meta("season_reward_level", level)
		premium_button.set_meta("premium", true)
		reward_row.add_child(premium_button)
		content.add_child(reward_row)
	var town_title := Label.new()
	town_title.text = L10n.text(tr("마을 복구 · 재료 %d") % main.save.restoration_points)
	town_title.add_theme_font_size_override("font_size", 26)
	town_title.add_theme_color_override("font_color", ArtDirection.success_color())
	content.add_child(town_title)
	for district in RetentionCatalogLib.towns():
		var district_level := int(main.save.town_levels.get(String(district.id), 0))
		var costs: Array = district.costs
		var unlocked: bool = bool(main.save.get_stars(int(district.unlock_level) - 2) > 0)
		var town_button := _button("%s · %s\n%s" % [L10n.text(String(district.name)), (L10n.text("복구 %d/3 · 재료 %d") % [district_level, int(costs[district_level])]) if district_level < 3 else L10n.text("복구 완료"), L10n.text(String(district.get("perk", L10n.text("마을 지원 강화"))))], Color("#4d946c") if unlocked else Color("#93899b"), Vector2(530, 80), 17)
		_style_lifestyle_button(town_button, Color("#e4e1e8"), Color("#8b8293"), Color("#4e4856"))
		town_button.disabled = not unlocked or district_level >= 3 or main.save.restoration_points < int(costs[district_level])
		var district_id := String(district.id)
		town_button.pressed.connect(func(): _upgrade_town(district_id))
		content.add_child(town_button)
	var share := _button(tr("내 아지트 방문 코드 복사"), Color("#4e8fbd"), Vector2(350, 56), 18)
	share.pressed.connect(func():
		DisplayServer.clipboard_set(main.save.room_share_code())
		if main.analytics: main.analytics.track("room_share", {"furniture_count":main.save.room_placements.size(),"town_level":main.save.town_total_level()})
		_show_toast(L10n.text("친구에게 보낼 방문 코드를 복사했어요!"))
	)
	content.add_child(share)
	var visit_row := HBoxContainer.new()
	visit_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var visit_code := LineEdit.new()
	visit_code.placeholder_text = L10n.text("친구의 JELLY1 방문 코드 붙여넣기")
	visit_code.custom_minimum_size = Vector2(390, 50)
	visit_code.add_theme_font_size_override("font_size", 15)
	visit_row.add_child(visit_code)
	var visit := _button(tr("방문"), Color("#6976b8"), Vector2(120, 50), 17)
	visit.pressed.connect(func():
		var preview: Dictionary = main.save.parse_room_share_code(visit_code.text)
		if preview.is_empty():
			_show_toast(L10n.text("방문 코드를 확인해 주세요."))
		else:
			_show_toast(L10n.text("%s의 아지트 · 별 %d · 가구 %d개 · 복구 %d단계") % [L10n.text(String(preview.get("name", L10n.text("친구")))), int(preview.get("stars", 0)), preview.get("furniture", []).size(), int(preview.get("town", 0))])
	)
	visit_row.add_child(visit)
	content.add_child(visit_row)
	var close := _button(tr("닫기"), Color("#715692"), Vector2(520, 64), 24)
	close.add_theme_constant_override("outline_size", 0)
	close.pressed.connect(_close_lifestyle_popup)
	outer.add_child(close)


func _close_lifestyle_popup() -> void:
	if lifestyle_popup and is_instance_valid(lifestyle_popup): lifestyle_popup.queue_free()
	lifestyle_popup = null


func _compact_reward(reward: Dictionary) -> String:
	if int(reward.get("stardust", 0)) > 0: return "★%d" % int(reward.stardust)
	if not String(reward.get("furniture", "")).is_empty(): return L10n.text(String(RoomData.item_by_id(L10n.text(String(reward.furniture))).get("name", L10n.text("한정 가구"))))
	if not String(reward.get("booster", "")).is_empty(): return "%s×%d" % [L10n.text(String(reward.booster)), int(reward.get("amount", 1))]
	return L10n.text("선물")


func _claim_resident_request(request_id: String) -> void:
	var result: Dictionary = main.save.claim_resident_request(request_id)
	if result.is_empty(): return
	if main.analytics: main.analytics.track("resident_request", {"request_id":request_id,"resident_id":L10n.text(String(result.get("resident_id", ""))),"result":"claimed"})
	_close_lifestyle_popup()
	_show_toast("%s: %s" % [L10n.text(String(result.get("resident_name", L10n.text("주민")))), L10n.text(String(result.get("line", L10n.text("고마워!"))))])
	_show_lifestyle_popup()


func _claim_retention_season(level: int, premium: bool) -> void:
	var reward: Dictionary = main.save.claim_retention_season_reward(level, premium)
	if reward.is_empty(): return
	if main.analytics: main.analytics.track("season_reward", {"level":level,"track":"premium" if premium else "free"})
	_close_lifestyle_popup()
	_show_toast(L10n.text("시즌 %d단계 보상을 받았어요!") % level)
	_show_lifestyle_popup()


func _upgrade_town(district_id: String) -> void:
	var result: Dictionary = main.save.upgrade_town(district_id)
	if result.is_empty(): return
	if main.analytics: main.analytics.track("town_upgrade", {"district_id":district_id,"level":int(result.level)})
	_close_lifestyle_popup()
	_show_toast(L10n.text("%s 복구 %d단계!  ★ %d") % [L10n.text(String(result.name)), int(result.level), int(result.reward)])
	_show_lifestyle_popup()


func _claim_daily_mission_chest() -> void:
	var reward: Dictionary = main.save.claim_daily_mission_chest()
	if reward.is_empty():
		return
	G.haptic(24)
	_close_daily_mission_popup()
	if stardust_label:
		stardust_label.text = L10n.text(("%s" if (ArtDirection.is_botanical() or ArtDirection.is_night()) else "★ %s") % _format_number(main.save.get_stardust()))
	_refresh_home_energy()
	_refresh_mission_button()
	_show_toast(L10n.text("구조 상자 획득!  ★ %d  ♥ %d") % [int(reward.get("stardust", 0)), int(reward.get("energy", 0))])


func _close_daily_mission_popup() -> void:
	if mission_popup and is_instance_valid(mission_popup):
		mission_popup.queue_free()
	mission_popup = null


func _claim_weekly_reward() -> void:
	var reward: Dictionary = main.save.claim_weekly_reward()
	if reward.is_empty():
		return
	_close_daily_mission_popup()
	stardust_label.text = L10n.text(("%s" if (ArtDirection.is_botanical() or ArtDirection.is_night()) else "★ %s") % _format_number(main.save.get_stardust()))
	_show_toast(L10n.text("주간 구조 작전 완료!  ★ %d") % int(reward.get("stardust", 0)))
	_show_daily_mission_popup()


func _claim_season_reward(target: int) -> void:
	var reward: Dictionary = main.save.claim_season_milestone(target)
	if reward.is_empty():
		return
	_close_daily_mission_popup()
	stardust_label.text = L10n.text(("%s" if (ArtDirection.is_botanical() or ArtDirection.is_night()) else "★ %s") % _format_number(main.save.get_stardust()))
	_show_toast(L10n.text("시즌 ★ %d 보상 획득!") % target)
	_show_daily_mission_popup()


func _dex_entry_card(entry: Dictionary) -> PanelContainer:
	var color_id := String(entry.get("color", ""))
	var discovered: bool = main.save.has_discovered_jelly(color_id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(270, 142)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#fff9f2") if discovered else Color("#e5e0e8"), G.COLORS[color_id].darkened(0.24) if discovered else Color("#90899b"), 20))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var portrait := TextureRect.new()
	portrait.texture = G.hero_tex() if color_id == "R" else G.jelly_tex(color_id)
	portrait.custom_minimum_size = Vector2(82, 82)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.modulate = Color.WHITE if discovered else Color(0.25, 0.22, 0.32, 0.35)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(copy)
	var name_label := Label.new()
	name_label.text = L10n.text(String(entry.get("name", "???"))) if discovered else L10n.text("아직 만나지 못했어요")
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", ArtDirection.text_color(Color("#523764") if discovered else Color("#837b89")))
	copy.add_child(name_label)
	var habitat := Label.new()
	habitat.text = L10n.text(String(entry.get("habitat", ""))) if discovered else L10n.text("모험에서 구조해 주세요")
	habitat.add_theme_font_size_override("font_size", 14)
	habitat.add_theme_color_override("font_color", ArtDirection.ink())
	copy.add_child(habitat)
	var count := Label.new()
	count.text = L10n.text("구조 %d · %s") % [main.save.get_jelly_capture_count(color_id), L10n.text("샤이니 발견") if main.save.has_discovered_shiny(color_id) else L10n.text("샤이니 미발견")] if discovered else "???"
	count.add_theme_font_size_override("font_size", 14)
	count.add_theme_color_override("font_color", ArtDirection.text_color(Color("#b35f75") if discovered else Color("#99929f")))
	copy.add_child(count)
	var personality := Label.new()
	personality.text = L10n.text(String(entry.get("personality", ""))) if discovered else ""
	personality.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	personality.add_theme_font_size_override("font_size", 13)
	personality.add_theme_color_override("font_color", ArtDirection.ink())
	copy.add_child(personality)
	return panel


func _show_jelly_dex() -> void:
	if dex_popup and is_instance_valid(dex_popup):
		return
	var dim := ColorRect.new()
	dim.color = ArtDirection.dim_color()
	_fit_overlay_to_viewport(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 260
	ui_layer.add_child(dim)
	dex_popup = dim
	var card := PanelContainer.new()
	card.position = Vector2(50, 145)
	card.size = Vector2(620, 970)
	card.add_theme_stylebox_override("panel", _panel_style(Color("#fff8f3"), Color("#7350a1"), 34))
	dim.add_child(card)
	_center_popup_horizontally(card)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	card.add_child(content)
	var title := Label.new()
	title.text = L10n.text("젤리몬 구조 도감")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(title)
	var status := Label.new()
	status.text = L10n.text("발견 %d / %d · 초상화를 누르면 언제든 다시 볼 수 있어요") % [main.save.get_discovered_jelly_count(), JellyDexCatalogLib.entries().size()]
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 17)
	status.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(status)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	for entry in JellyDexCatalogLib.entries():
		grid.add_child(_dex_entry_card(entry))
	var rewards := HBoxContainer.new()
	rewards.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards.add_theme_constant_override("separation", 8)
	content.add_child(rewards)
	for milestone in JellyDexCatalogLib.milestones():
		var needed := int(milestone.get("count", 0))
		var reward := int(milestone.get("stardust", 0))
		var button := _button(L10n.text("%d종\n★ %d") % [needed, reward], Color("#5dbb82") if main.save.has_claimed_dex_milestone(needed) else Color("#e49a43"), Vector2(120, 70), 17)
		button.disabled = main.save.has_claimed_dex_milestone(needed) or main.save.get_discovered_jelly_count() < needed
		button.pressed.connect(func(): _claim_dex_reward(needed, reward))
		rewards.add_child(button)
	var close := _button(tr("닫기"), Color("#8065aa"), Vector2(220, 64), 23)
	close.pressed.connect(_close_jelly_dex)
	content.add_child(close)


func _claim_dex_reward(count: int, reward: int) -> void:
	if not main.save.claim_dex_milestone(count, reward):
		return
	_close_jelly_dex()
	if stardust_label:
		stardust_label.text = L10n.text(("%s" if (ArtDirection.is_botanical() or ArtDirection.is_night()) else "★ %s") % _format_number(main.save.get_stardust()))
	_show_toast(L10n.text("도감 %d종 보상!  ★ %d") % [count, reward])
	_show_jelly_dex()


func _close_jelly_dex() -> void:
	if dex_popup and is_instance_valid(dex_popup):
		dex_popup.queue_free()
	dex_popup = null


func _build_navigation() -> void:
	_build_next_adventure_card()
	nav_bar = PanelContainer.new()
	nav_bar.position = Vector2(20, 1104)
	nav_bar.size = Vector2(G.W - 40, 156)
	var nav_style := _home_surface(Color("#fff6e7"), 22)
	nav_style.set_border_width_all(1)
	nav_style.shadow_color = Color(0.35, 0.22, 0.12, 0.10)
	nav_style.shadow_size = 3
	nav_style.shadow_offset = Vector2(0, 2)
	nav_bar.add_theme_stylebox_override("panel", nav_style)
	ui_layer.add_child(nav_bar)
	var buttons := GridContainer.new()
	buttons.columns = 4
	buttons.add_theme_constant_override("h_separation", 7)
	buttons.add_theme_constant_override("v_separation", 8)
	var button_center := CenterContainer.new()
	button_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nav_bar.add_child(button_center)
	button_center.add_child(buttons)
	var nav_color := ArtDirection.panel_color() if ArtDirection.is_night() else Color("#fff9ee")
	var adventure := _nav_button("adventure", L10n.text("지도"), nav_color, 146)
	adventure.pressed.connect(func(): main.show_map())
	buttons.add_child(adventure)
	var decorate := _nav_button("decorate", L10n.text("꾸미기"), nav_color, 146)
	decorate.pressed.connect(_enter_edit_mode)
	_apply_feature_lock(decorate, "decorate", L10n.text("꾸미기"))
	buttons.add_child(decorate)
	var shop := _nav_button("shop", L10n.text("상점"), nav_color, 146)
	shop.pressed.connect(_show_shop_popup)
	_apply_feature_lock(shop, "shop", L10n.text("상점"))
	buttons.add_child(shop)
	var menu := _nav_button("menu", L10n.text("메뉴"), nav_color, 146)
	menu.pressed.connect(_show_home_menu)
	buttons.add_child(menu)


func _apply_feature_lock(button: Button, feature_id: String, label_text: String) -> void:
	if main.save.home_feature_unlocked(feature_id):
		return
	var unlock_level: int = main.save.home_feature_unlock_level(feature_id)
	button.disabled = true
	button.tooltip_text = L10n.text("LEVEL %d 클리어 후 %s 기능이 열려요") % [unlock_level, label_text]
	button.modulate = Color(0.68, 0.72, 0.82, 0.92)
	var badge := Label.new()
	badge.text = L10n.text("🔒 LEVEL %d" % unlock_level)
	badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	badge.offset_bottom = -6
	badge.add_theme_font_size_override("font_size", 14)
	badge.add_theme_color_override("font_color", Color("#fff2ac"))
	badge.add_theme_color_override("font_outline_color", Color("#26304f"))
	badge.add_theme_constant_override("outline_size", 3)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(badge)


func _set_preference_switch_style(toggle: Button, enabled: bool, accent: Color) -> void:
	toggle.text = L10n.text("ON   ●" if enabled else "●   OFF")
	var fill := ArtDirection.selected_color() if enabled else ArtDirection.disabled_color()
	var border := accent.darkened(0.28) if enabled else Color("#756b80")
	var normal := _panel_style(fill, border, 24)
	normal.bg_color = fill
	normal.shadow_size = 3
	normal.shadow_offset = Vector2(0, 2)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = fill.lightened(0.035)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = fill.darkened(0.035)
	pressed.shadow_size = 3
	toggle.add_theme_stylebox_override("normal", normal)
	toggle.add_theme_stylebox_override("hover", hover)
	toggle.add_theme_stylebox_override("focus", hover)
	toggle.add_theme_stylebox_override("pressed", pressed)
	toggle.add_theme_color_override("font_color", ArtDirection.ink())
	toggle.add_theme_color_override("font_hover_color", ArtDirection.ink())
	toggle.add_theme_color_override("font_pressed_color", ArtDirection.ink())
	toggle.add_theme_color_override("font_outline_color", border.darkened(0.15))
	toggle.add_theme_constant_override("outline_size", 0)


func _preference_row(label_text: String, enabled: bool, accent: Color) -> Dictionary:
	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(520, 62)
	var row_style := _panel_style(Color("#fff7fd"), Color("#c2a8d5"), 20)
	row_style.shadow_size = 3
	row_style.shadow_offset = Vector2(0, 2)
	row_panel.add_theme_stylebox_override("panel", row_style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row_panel.add_child(row)
	var label := Label.new()
	label.text = L10n.text(tr(label_text))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", ArtDirection.ink())
	row.add_child(label)
	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = enabled
	toggle.custom_minimum_size = Vector2(112, 44)
	toggle.add_theme_font_size_override("font_size", 17)
	_set_preference_switch_style(toggle, enabled, accent)
	toggle.toggled.connect(func(value: bool): _set_preference_switch_style(toggle, value, accent))
	row.add_child(toggle)
	return {"row": row_panel, "toggle": toggle}


func _language_preference_row() -> Dictionary:
	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(520, 62)
	var row_style := _panel_style(Color("#fff7fd"), Color("#c2a8d5"), 20)
	row_style.shadow_size = 3
	row_style.shadow_offset = Vector2(0, 2)
	row_panel.add_theme_stylebox_override("panel", row_style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row_panel.add_child(row)
	var label := Label.new()
	label.text = L10n.text(tr("언어"))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", ArtDirection.ink())
	row.add_child(label)
	var selector := OptionButton.new()
	selector.get_popup().theme = ArtDirection.ui_theme()
	selector.custom_minimum_size = Vector2(250, 46)
	selector.add_theme_font_size_override("font_size", 17)
	selector.add_theme_color_override("font_color", ArtDirection.ink())
	selector.add_theme_color_override("font_hover_color", ArtDirection.ink())
	var selector_style := _panel_style(Color("#8065aa"), Color("#5d467f"), 18)
	selector_style.shadow_size = 3
	selector_style.shadow_offset = Vector2(0, 2)
	selector.add_theme_stylebox_override("normal", selector_style)
	selector.add_theme_stylebox_override("hover", selector_style)
	selector.add_theme_stylebox_override("pressed", selector_style)
	for option_label in Localization.option_labels():
		selector.add_item(option_label)
	selector.select(Localization.option_index(main.save.language))
	row.add_child(selector)
	return {"row": row_panel, "selector": selector}


func _show_home_menu() -> void:
	if menu_popup and is_instance_valid(menu_popup):
		return
	var dim := ColorRect.new()
	dim.color = ArtDirection.dim_color()
	_fit_overlay_to_viewport(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 280
	ui_layer.add_child(dim)
	menu_popup = dim
	var card := PanelContainer.new()
	card.position = Vector2(48, 120)
	card.size = Vector2(624, 1085)
	var menu_style := _panel_style(Color("#eee2f6"), Color("#7954a3"), 34)
	menu_style.border_width_left = 1
	menu_style.border_width_top = 1
	menu_style.border_width_right = 1
	menu_style.border_width_bottom = 1
	menu_style.shadow_size = 3
	card.add_theme_stylebox_override("panel", menu_style)
	dim.add_child(card)
	_center_popup_horizontally(card)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	card.add_child(content)
	var heading := Label.new()
	heading.text = L10n.text(tr("젤리 메뉴"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 35)
	heading.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(heading)
	var settings_title := Label.new()
	settings_title.text = L10n.text(tr("환경 설정"))
	settings_title.add_theme_font_size_override("font_size", 23)
	settings_title.add_theme_color_override("font_color", ArtDirection.danger_color())
	content.add_child(settings_title)
	var settings_panel := PanelContainer.new()
	settings_panel.custom_minimum_size = Vector2(558, 301)
	settings_panel.add_theme_stylebox_override("panel", _panel_style(Color("#dfccef"), Color("#aa82c8"), 25))
	content.add_child(settings_panel)
	var settings_rows := VBoxContainer.new()
	settings_rows.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_rows.add_theme_constant_override("separation", 7)
	settings_panel.add_child(settings_rows)
	var sound_data := _preference_row(L10n.text("효과음"), main.save.sound_enabled, Color("#e16388"))
	var haptics_data := _preference_row(L10n.text("진동"), main.save.haptics_enabled, Color("#6f9ed7"))
	var notifications_data := _preference_row(L10n.text("알림"), main.save.notifications_enabled, Color("#8c68c7"))
	var language_data := _language_preference_row()
	var sound: Button = sound_data.toggle
	var haptics: Button = haptics_data.toggle
	var notifications: Button = notifications_data.toggle
	for data in [sound_data, haptics_data, notifications_data]:
		settings_rows.add_child(data.row)
		var toggle: Button = data.toggle
		toggle.toggled.connect(func(_enabled: bool):
			main.save.set_preferences(sound.button_pressed, haptics.button_pressed, notifications.button_pressed)
			main.audio.enabled = sound.button_pressed
			main.music.set_enabled(sound.button_pressed)
			G.haptics_enabled = haptics.button_pressed
		)
	settings_rows.add_child(language_data.row)
	var language_selector: OptionButton = language_data.selector
	language_selector.item_selected.connect(func(index: int):
		var codes := Localization.option_codes()
		if index < 0 or index >= codes.size():
			return
		var locale_code: String = codes[index]
		main.save.set_language(locale_code)
		Localization.apply_language(locale_code)
		_close_home_menu()
		main.call_deferred("show_title")
	)
	var account_panel := PanelContainer.new()
	account_panel.custom_minimum_size = Vector2(558, 104)
	account_panel.add_theme_stylebox_override("panel", _panel_style(Color("#f7efff"), Color("#8b68b8"), 23))
	content.add_child(account_panel)
	var account_box := VBoxContainer.new()
	account_box.alignment = BoxContainer.ALIGNMENT_CENTER
	account_box.add_theme_constant_override("separation", 2)
	account_panel.add_child(account_box)
	var account_row := HBoxContainer.new()
	account_row.alignment = BoxContainer.ALIGNMENT_CENTER
	account_row.add_theme_constant_override("separation", 10)
	account_box.add_child(account_row)
	var account_status := Label.new()
	account_status.text = L10n.text(main.platform.status_text() if main.platform else L10n.text("플랫폼 연결 대기"))
	account_status.custom_minimum_size = Vector2(320, 48)
	account_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	account_status.add_theme_font_size_override("font_size", 17)
	account_status.add_theme_color_override("font_color", ArtDirection.ink())
	account_row.add_child(account_status)
	var service_detail := Label.new()
	service_detail.text = L10n.text(main.platform.service_detail_text() if main.platform else L10n.text("플랫폼 서비스 준비 중"))
	service_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	service_detail.add_theme_font_size_override("font_size", 14)
	service_detail.add_theme_color_override("font_color", ArtDirection.ink())
	var login := _button(tr("연결 해제") if main.platform and main.platform.logged_in else tr("계정 연결"), Color("#5a9bc0"), Vector2(160, 52), 18)
	login.name = "AccountConnectionButton"
	login.disabled = not main.platform.native_available if main.platform else true
	if main.platform and not main.platform.native_available:
		login.text = L10n.text("Hive 미포함")
	var refresh_account := func(_connected: bool, _id: String):
		if not is_instance_valid(login): return
		login.text = L10n.text(tr("연결 해제") if main.platform.logged_in else tr("계정 연결"))
		login.disabled = main.platform.account_disconnect_pending
		account_status.text = L10n.text(main.platform.status_text())
		service_detail.text = L10n.text(main.platform.service_detail_text())
	var login_error := func(message: String):
		if not is_instance_valid(login): return
		account_status.text = L10n.text(message)
		login.text = L10n.text(tr("계정 연결"))
		login.disabled = false
	if main.platform:
		main.platform.login_changed.connect(refresh_account)
		main.platform.login_failed.connect(login_error)
		login.tree_exiting.connect(func():
			if not is_instance_valid(main) or not is_instance_valid(main.platform): return
			if main.platform.login_changed.is_connected(refresh_account): main.platform.login_changed.disconnect(refresh_account)
			if main.platform.login_failed.is_connected(login_error): main.platform.login_failed.disconnect(login_error)
		)
	login.pressed.connect(func():
		if not main.platform: return
		if main.platform.logged_in:
			_show_account_disconnect()
			return
		login.disabled = true
		login.text = L10n.text(tr("연결 중..."))
		account_status.text = L10n.text("HIVE 로그인 화면을 준비하고 있어요")
		if not main.platform.login(): login_error.call(L10n.text("로그인을 시작하지 못했습니다."))
	)
	account_row.add_child(login)
	if main.platform:
		var refresh_cloud := func(_message: String):
			if is_instance_valid(service_detail): service_detail.text = main.platform.service_detail_text()
		main.platform.cloud_state_changed.connect(refresh_cloud)
		service_detail.tree_exiting.connect(func():
			if is_instance_valid(main) and is_instance_valid(main.platform) and main.platform.cloud_state_changed.is_connected(refresh_cloud):
				main.platform.cloud_state_changed.disconnect(refresh_cloud)
		)
	account_box.add_child(service_detail)
	var cloud_button := _button(L10n.text("클라우드 저장 / 복원"), ArtDirection.panel_color(), Vector2(300, 44), 17)
	cloud_button.pressed.connect(func(): main.adventure_cloud.request_sync())
	account_box.add_child(cloud_button)
	var divider := HSeparator.new()
	divider.custom_minimum_size.y = 5
	content.add_child(divider)
	var mail_title := Label.new()
	mail_title.text = L10n.text(tr("우편함"))
	mail_title.add_theme_font_size_override("font_size", 23)
	mail_title.add_theme_color_override("font_color", ArtDirection.danger_color())
	content.add_child(mail_title)
	for mail in LiveMessageCatalogLib.mail():
		var mail_row := PanelContainer.new()
		mail_row.custom_minimum_size = Vector2(540, 105)
		mail_row.add_theme_stylebox_override("panel", _panel_style(Color("#fff0cf"), Color("#dc9b3d"), 19))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		mail_row.add_child(row)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(copy)
		var mail_name := Label.new()
		mail_name.text = L10n.text(String(mail.get("title", L10n.text("선물 우편"))))
		mail_name.add_theme_font_size_override("font_size", 19)
		mail_name.add_theme_color_override("font_color", ArtDirection.ink())
		copy.add_child(mail_name)
		var mail_body := Label.new()
		mail_body.text = L10n.text("%s  ·  ★ %d  ♥ %d" % [L10n.text(String(mail.get("body", ""))), int(mail.get("stardust", 0)), int(mail.get("energy", 0))])
		mail_body.add_theme_font_size_override("font_size", 14)
		mail_body.add_theme_color_override("font_color", ArtDirection.ink())
		mail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy.add_child(mail_body)
		var mail_id := String(mail.get("id", ""))
		var claimed: bool = main.save.has_claimed_mail(mail_id)
		var receive := _button(tr("수령 완료") if claimed else L10n.text("받기"), Color("#76ae7d") if claimed else Color("#e98948"), Vector2(118, 58), 19)
		receive.disabled = claimed
		receive.pressed.connect(func(): _claim_home_mail(mail))
		row.add_child(receive)
		content.add_child(mail_row)
	var notice_title := Label.new()
	notice_title.text = L10n.text("공지")
	notice_title.add_theme_font_size_override("font_size", 23)
	notice_title.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(notice_title)
	for notice in LiveMessageCatalogLib.notices():
		var notice_card := PanelContainer.new()
		notice_card.custom_minimum_size = Vector2(540, 94)
		notice_card.add_theme_stylebox_override("panel", _panel_style(Color("#edf5ff"), Color("#73a2c7"), 18))
		var notice_copy := VBoxContainer.new()
		notice_card.add_child(notice_copy)
		var notice_name := Label.new()
		notice_name.text = L10n.text("%s  ·  %s" % [L10n.text(String(notice.get("title", L10n.text("공지")))), L10n.text(String(notice.get("date", "")))])
		notice_name.add_theme_font_size_override("font_size", 17)
		notice_name.add_theme_color_override("font_color", ArtDirection.ink())
		notice_copy.add_child(notice_name)
		var notice_body := Label.new()
		notice_body.text = L10n.text(String(notice.get("body", "")))
		notice_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		notice_body.add_theme_font_size_override("font_size", 14)
		notice_body.add_theme_color_override("font_color", ArtDirection.ink())
		notice_copy.add_child(notice_body)
		content.add_child(notice_card)
	var close := _button(tr("닫기"), Color("#8065aa"), Vector2(210, 60), 22)
	close.pressed.connect(_close_home_menu)
	content.add_child(close)


func _claim_home_mail(mail: Dictionary) -> void:
	if not main.save.claim_mail(mail):
		return
	G.haptic(20)
	_close_home_menu()
	if stardust_label:
		stardust_label.text = L10n.text(("%s" if (ArtDirection.is_botanical() or ArtDirection.is_night()) else "★ %s") % _format_number(main.save.get_stardust()))
	_refresh_home_energy()
	_show_toast(L10n.text("우편 선물 수령!  ★ %d  ♥ %d") % [int(mail.get("stardust", 0)), int(mail.get("energy", 0))])
	_show_home_menu()


func _show_account_disconnect() -> void:
	if ui_layer.has_node("AccountDisconnectDialog"): return
	var dialog := preload("res://scripts/AccountResetDialog.gd").new()
	dialog.name = "AccountDisconnectDialog"
	dialog.heading_text = L10n.text("계정 연결 해제")
	dialog.action_text = L10n.text("연결 해제")
	var is_guest: bool = main.platform.is_guest_account()
	dialog.scope_text = (L10n.text("게스트 Hive 계정을 삭제하고 연결을 해제합니다. 기존 게스트 계정으로 다시 로그인할 수 없습니다.") if is_guest else L10n.text("현재 Hive 계정에서 로그아웃합니다. 연결된 Google 등의 계정은 삭제되지 않습니다."))
	dialog.scope_text += L10n.text("\n연결 해제가 완료되면 이 기기의 진행도, 재화, 가구, 닉네임과 설정이 모두 초기화됩니다. 이 작업은 되돌릴 수 없습니다. Hive 클라우드와 랭킹 서버에 저장된 기록은 삭제하지 않습니다.")
	ui_layer.add_child(dialog)
	var completed := func(success: bool, message: String):
		if not is_instance_valid(dialog): return
		if not success:
			dialog.show_error(message)
			return
		dialog.queue_free()
		_close_home_menu()
	main.platform.account_disconnect_completed.connect(completed)
	dialog.tree_exiting.connect(func():
		if not is_instance_valid(main) or not is_instance_valid(main.platform): return
		if main.platform.account_disconnect_completed.is_connected(completed): main.platform.account_disconnect_completed.disconnect(completed)
	)
	dialog.confirmed.connect(func():
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			DisplayServer.virtual_keyboard_hide()
		if not main.platform.disconnect_account(dialog.input.text, is_guest):
			dialog.show_error(L10n.text("연결 해제를 시작하지 못했습니다. 로그인 상태와 앱 버전을 확인해 주세요."))
	)


func _close_home_menu() -> void:
	if menu_popup and is_instance_valid(menu_popup):
		menu_popup.queue_free()
	menu_popup = null


func _next_level_index() -> int:
	for idx in range(Levels.level_count()):
		if main.save.get_stars(idx) <= 0:
			return idx
	return Levels.level_count() - 1


func _next_resident_text() -> String:
	var count: int = main.save.get_rescued_jellies().size()
	if count >= 6:
		return L10n.text("주민 6/6 · 모두 구조했어요")
	var target_level := count * 10 + 1
	return L10n.text("다음 친구 · LEVEL %d에서 만나요") % target_level


func _build_next_adventure_card() -> void:
	var idx := _next_level_index()
	var level: Dictionary = Levels.get_level(idx)
	var chapter := clampi(idx / 10, 0, Levels.CHAPTER_NAMES.size() - 1)
	var chapter_name := L10n.text(String(L10n.text(Levels.CHAPTER_NAMES[chapter])))
	var card := Control.new()
	card.name = "NextAdventureCard"
	card.position = Vector2(24, 920)
	card.size = Vector2(672, 170)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(card)
	var strip := Panel.new()
	strip.size = Vector2(672, 54)
	strip.add_theme_stylebox_override("panel", _home_surface())
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(strip)
	var level_name := L10n.text(String(level.get("name", L10n.text("다음 구조")))).trim_prefix(chapter_name + " · ")
	strip.add_child(_home_label(tr("LEVEL %d  ·  %s") % [idx + 1, tr(level_name)], Vector2(18, 6), Vector2(470, 42), 24))
	var stars := 0
	for level_index in range(chapter * 10, mini(chapter * 10 + 10, Levels.level_count())):
		stars += main.save.get_stars(level_index)
	strip.add_child(_home_label("★ %d/30" % stars, Vector2(526, 6), Vector2(128, 42), 23))
	adventure_button = _home_button(tr("모험 시작  ▶"), Vector2(672, 100), 36)
	adventure_button.position = Vector2(0, 66)
	adventure_button.tooltip_text = L10n.text("LEVEL %d 바로 시작") % (idx + 1)
	for state in ["normal", "hover", "pressed", "focus"]:
		adventure_button.add_theme_stylebox_override(state, _home_surface(ArtDirection.primary_pressed() if state == "pressed" else ArtDirection.primary_color(), 36))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		adventure_button.add_theme_color_override(state, ArtDirection.primary_ink())
	if ArtDirection.is_botanical() or ArtDirection.is_night():
		for state in ["normal", "hover", "pressed", "focus"]:
			var button_style: StyleBoxFlat = adventure_button.get_theme_stylebox(state).duplicate()
			button_style.border_color = Color("#b7803d") if ArtDirection.is_night() else Color("#2da797")
			button_style.set_border_width_all(2)
			adventure_button.add_theme_stylebox_override(state, button_style)
		for x in ([] if ArtDirection.is_night() else [28, 592]):
			var sprig := HomeNavIconScene.new()
			sprig.setup("leaf", Color("#b0e4cc"))
			sprig.position = Vector2(x, 24)
			sprig.size = Vector2(50, 50)
			adventure_button.add_child(sprig)
	adventure_button.pressed.connect(func(): main.start_level(idx))
	card.add_child(adventure_button)


func _clear_layer(layer: Node) -> void:
	for child in layer.get_children():
		child.free()


func _refresh_room() -> void:
	_refresh_furniture()
	_refresh_characters()
	var info := ui_layer.find_child("ResidentInfo", true, false) as Label
	if info:
		info.text = L10n.text(_next_resident_text())


func _refresh_furniture() -> void:
	_clear_layer(furniture_layer)
	furniture_nodes.clear()
	for i in range(placements.size()):
		var placement: Dictionary = placements[i]
		var item := RoomData.item_by_id(String(placement.get("id", "")))
		if item.is_empty() or not RoomData.item_unlocked(item, main.save):
			continue
		var visual := RoomFurniture.new()
		visual.setup(item, placement, edit_mode and i == selected_index)
		visual.z_index = int(placement.get("y", 0))
		furniture_layer.add_child(visual)
		furniture_nodes.append(visual)


func _refresh_characters() -> void:
	_clear_layer(character_layer)
	resident_nodes.clear()
	resident_home_positions.clear()
	_resident_touch_tweens.clear()
	var stage := RoomData.growth_stage(main.save)
	var aura := Sprite2D.new()
	aura.texture = load("res://assets/fx/soft.png")
	aura.position = Vector2(360, 610)
	var aura_size := 210.0 + minf(stage, 7) * 20.0
	aura.scale = Vector2.ONE * aura_size / float(aura.texture.get_width())
	aura.modulate = Color(1.0, 0.72, 0.88, minf(0.66, 0.24 + stage * 0.055))
	character_layer.add_child(aura)
	var hero := Sprite2D.new()
	hero.name = "Hero"
	hero.texture = G.hero_tex()
	hero.position = Vector2(360, 615)
	hero.set_meta("home_position", hero.position)
	var hero_size: float = minf(220.0, 146.0 + float(stage - 1) * 13.0)
	hero.scale = Vector2.ONE * hero_size / float(hero.texture.get_width())
	character_layer.add_child(hero)
	var bounce := hero.create_tween().set_loops()
	bounce.tween_property(hero, "scale", hero.scale * Vector2(1.04, 0.96), 0.8).set_trans(Tween.TRANS_SINE)
	bounce.tween_property(hero, "scale", hero.scale * Vector2(0.97, 1.04), 0.8).set_trans(Tween.TRANS_SINE)
	var growth_badge := RoomData.growth_badge(stage)
	if not growth_badge.is_empty():
		var badge := Label.new()
		badge.text = L10n.text(growth_badge)
		badge.position = Vector2(329, 492 - mini(stage, 7) * 4)
		badge.size = Vector2(64, 64)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 48)
		badge.add_theme_color_override("font_color", Color("#ffd75e"))
		badge.add_theme_color_override("font_outline_color", Color("#8a547f"))
		badge.add_theme_constant_override("outline_size", 6)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		character_layer.add_child(badge)
	var spots := [Vector2(222, 565), Vector2(500, 545), Vector2(170, 725), Vector2(550, 710), Vector2(295, 790), Vector2(440, 790)]
	var residents: Array = main.save.get_resident_records()
	for i in range(mini(6, residents.size())):
		var record: Dictionary = residents[i]
		var color_id := String(record.get("color", "R"))
		var resident := Sprite2D.new()
		resident.name = "Resident_%s" % String(record.get("id", i))
		resident.texture = CharacterCatalog.character_texture(color_id)
		resident.position = spots[i]
		resident.scale = Vector2.ONE * 82.0 / float(resident.texture.get_width())
		resident.z_index = 2 + i
		resident.set_meta("record", record)
		var bond_level: int = main.save.get_resident_bond_level(record)
		resident.set_meta("bond_level", bond_level)
		character_layer.add_child(resident)
		resident_nodes.append(resident)
		resident_home_positions[resident.get_instance_id()] = resident.position
		if bond_level >= 3:
			var bond_badge := Label.new()
			bond_badge.text = L10n.text("♥%d" % bond_level)
			bond_badge.position = resident.position + Vector2(-34, -64)
			bond_badge.size = Vector2(68, 28)
			bond_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			bond_badge.add_theme_font_size_override("font_size", 15)
			bond_badge.add_theme_color_override("font_color", Color("#fff7b5") if bond_level >= 7 else Color.WHITE)
			bond_badge.add_theme_color_override("font_outline_color", G.COLORS[color_id].darkened(0.38))
			bond_badge.add_theme_constant_override("outline_size", 4)
			bond_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bond_badge.z_index = resident.z_index + 1
			character_layer.add_child(bond_badge)
		_play_resident_idle(resident, L10n.text(String(record.get("trait", "kind"))), i % 3)


func _start_resident_life() -> void:
	resident_action_timer = Timer.new()
	resident_action_timer.wait_time = 5.4
	resident_action_timer.autostart = true
	resident_action_timer.timeout.connect(_play_random_resident_interaction)
	add_child(resident_action_timer)


func _play_resident_idle(resident: Sprite2D, trait_id: String, variant_index: int) -> void:
	if not is_instance_valid(resident):
		return
	var home: Vector2 = resident_home_positions.get(resident.get_instance_id(), resident.position)
	resident.position = home
	resident.rotation = 0.0
	resident.modulate.a = 1.0
	var base_scale := Vector2.ONE * 82.0 / float(resident.texture.get_width())
	resident.scale = base_scale
	var tw := resident.create_tween()
	var bond_level := int(resident.get_meta("bond_level", 1))
	match variant_index % 3:
		0: # 인사 점프
			tw.tween_property(resident, "position", home + Vector2(0, -16 if trait_id == "energetic" else -10), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(resident, "position", home, 0.34).set_trans(Tween.TRANS_BOUNCE)
			if bond_level >= 7:
				tw.tween_property(resident, "position", home + Vector2(0, -8), 0.15).set_trans(Tween.TRANS_QUAD)
				tw.tween_property(resident, "position", home, 0.2).set_trans(Tween.TRANS_BOUNCE)
		1: # 말랑 호흡
			tw.tween_property(resident, "scale", base_scale * Vector2(1.08, 0.92), 0.32).set_trans(Tween.TRANS_SINE)
			tw.tween_property(resident, "scale", base_scale * Vector2(0.95, 1.06), 0.32).set_trans(Tween.TRANS_SINE)
			tw.tween_property(resident, "scale", base_scale, 0.24)
		_: # 좌우 호기심
			var angle := 0.14 if trait_id == "playful" else 0.09
			tw.tween_property(resident, "rotation", -angle, 0.22).set_trans(Tween.TRANS_BACK)
			tw.tween_property(resident, "rotation", angle, 0.28).set_trans(Tween.TRANS_BACK)
			tw.tween_property(resident, "rotation", 0.0, 0.2)


func _speech_bubble(text: String, position_at: Vector2) -> void:
	var bubble := Label.new()
	bubble.text = L10n.text(text)
	bubble.position = position_at - Vector2(105, 78)
	bubble.size = Vector2(210, 58)
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.add_theme_font_size_override("font_size", 15)
	bubble.add_theme_color_override("font_color", ArtDirection.ink())
	bubble.add_theme_stylebox_override("normal", _panel_style(Color("#fff9f2"), Color("#bc91ca"), 18))
	bubble.z_index = 20
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character_layer.add_child(bubble)
	var tw := bubble.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.3)
	tw.tween_callback(bubble.queue_free)


func _play_random_resident_interaction() -> void:
	if edit_mode or photo_layer or resident_nodes.is_empty():
		return
	if not furniture_nodes.is_empty() and randf() < 0.38:
		_play_furniture_behavior()
		return
	if randf() < 0.34:
		var solo: Sprite2D = resident_nodes.pick_random()
		_play_resident_idle(solo, L10n.text(String((solo.get_meta("record") as Dictionary).get("trait", "kind"))), randi_range(0, 2))
		return
	if resident_nodes.size() == 1:
		var only: Sprite2D = resident_nodes[0]
		var record: Dictionary = only.get_meta("record")
		_speech_bubble(String(CharacterCatalog.profile(String(record.color)).get("greeting", L10n.text("말랑!"))), only.position)
		return
	var first: Sprite2D = resident_nodes.pick_random()
	var second: Sprite2D = resident_nodes.pick_random()
	if first == second:
		second = resident_nodes[(resident_nodes.find(first) + 1) % resident_nodes.size()]
	var a: Dictionary = first.get_meta("record")
	var b: Dictionary = second.get_meta("record")
	var chosen: Dictionary = CharacterCatalog.interactions()[0]
	for interaction in CharacterCatalog.interactions():
		var traits: Array = interaction.get("traits", [])
		if traits.is_empty() or (traits.has(L10n.text(String(a.trait))) and traits.has(L10n.text(String(b.trait)))):
			chosen = interaction
			if not traits.is_empty():
				break
	var midpoint := (first.position + second.position) * 0.5
	var first_home: Vector2 = resident_home_positions.get(first.get_instance_id(), first.position)
	var second_home: Vector2 = resident_home_positions.get(second.get_instance_id(), second.position)
	var tw := first.create_tween()
	tw.tween_property(first, "position", midpoint + Vector2(-28, 0), 0.45).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(1.7)
	tw.tween_property(first, "position", first_home, 0.42).set_trans(Tween.TRANS_SINE)
	var tw2 := second.create_tween()
	tw2.tween_property(second, "position", midpoint + Vector2(28, 0), 0.45).set_trans(Tween.TRANS_BACK)
	tw2.tween_interval(1.7)
	tw2.tween_property(second, "position", second_home, 0.42).set_trans(Tween.TRANS_SINE)
	_speech_bubble(L10n.text(String(chosen.get("text", L10n.text("친구와 함께 놀아요!")))), midpoint)
	main.save.record_resident_interaction(String(a.id), String(b.id), String(chosen.get("id", "greeting")))
	main.save.add_album_memory("interaction", L10n.text(String(chosen.get("text", "친구와 함께 놀아요!"))), [String(a.id), String(b.id)])


func _play_furniture_behavior() -> void:
	var resident: Sprite2D = resident_nodes.pick_random()
	var record: Dictionary = resident.get_meta("record")
	var favorite := L10n.text(String(record.get("favorite_furniture", "")))
	var furniture: RoomFurniture = null
	for candidate in furniture_nodes:
		if favorite != "" and String(candidate.item.get("id", "")) == favorite:
			furniture = candidate
			break
	if furniture == null:
		var exclusive_furniture: Array[RoomFurniture] = []
		for candidate in furniture_nodes:
			if bool(candidate.item.get("package_exclusive", false)):
				exclusive_furniture.append(candidate)
		furniture = exclusive_furniture.pick_random() if not exclusive_furniture.is_empty() and randf() < 0.68 else furniture_nodes.pick_random()
	var item_id := String(furniture.item.get("id", "furniture"))
	var item_name := L10n.text(String(furniture.item.get("name", L10n.text("가구"))))
	var lines := {
		"cushion_r": L10n.text("폭신폭신, 구름 같아!"),
		"lamp_y": L10n.text("별빛을 세어 볼까?"),
		"table_b": L10n.text("소다 한 모금, 톡톡!"),
		"shelf_g": L10n.text("새싹에게 인사했어!"),
		"sofa_p": L10n.text("소파에서 말랑 휴식!"),
		"bench_o": L10n.text("귤 향기가 솔솔 나!"),
		"ach_first": L10n.text("우리의 첫 만남이야!"),
	}
	var line := L10n.text(String(furniture.item.get("reaction", lines.get(item_id, L10n.text("%s이(가) 마음에 들어!") % item_name))))
	var bond_level: int = main.save.get_resident_bond_level(record)
	if bond_level >= 5 and bool(furniture.item.get("package_exclusive", false)):
		line = L10n.text("우리만의 추억이 또 생겼어! ") + line
	var home: Vector2 = resident_home_positions.get(resident.get_instance_id(), resident.position)
	var destination := furniture.interaction_point() + Vector2(0, 42)
	var tw := resident.create_tween()
	tw.tween_property(resident, "position", destination, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(furniture.play_reaction)
	tw.tween_property(resident, "rotation", 0.12, 0.16)
	tw.tween_property(resident, "rotation", -0.12, 0.16)
	tw.tween_property(resident, "rotation", 0.0, 0.14)
	tw.tween_interval(1.25)
	tw.tween_property(resident, "position", home, 0.48).set_trans(Tween.TRANS_SINE)
	_speech_bubble(line, destination)
	var bond_gain: Dictionary = main.save.add_resident_affection(String(record.get("id", "")), 1)
	_record_bond_analytics(record, bond_gain)
	main.save.add_album_memory("exclusive_furniture" if bool(furniture.item.get("package_exclusive", false)) else "furniture", line, [String(record.get("id", "")), item_id])


func _placement_cells(placement: Dictionary) -> Array[Vector2i]:
	var item := RoomData.item_by_id(String(placement.id))
	if item.is_empty():
		return []
	var cells: Array[Vector2i] = []
	var origin := Vector2i(int(placement.x), int(placement.y))
	for off in RoomData.rotated_cells(String(item.shape), int(placement.get("rotation", 0))):
		cells.append(origin + off)
	return cells


func _placement_valid(candidate: Dictionary, ignored_index: int) -> bool:
	var cells := _placement_cells(candidate)
	if cells.is_empty():
		return false
	var occupied := {}
	for i in range(placements.size()):
		if i == ignored_index:
			continue
		for cell in _placement_cells(placements[i]):
			occupied[cell] = true
	for cell in cells:
		if cell.x < 0 or cell.y < 0 or cell.x >= RoomData.GRID_W or cell.y >= RoomData.GRID_H or occupied.has(cell):
			return false
	return true


func _enter_edit_mode() -> void:
	if not main.save.home_feature_unlocked("decorate"):
		_show_toast(L10n.text("LEVEL %d 클리어 후 꾸미기가 열려요") % main.save.home_feature_unlock_level("decorate"))
		return
	if edit_mode:
		return
	edit_mode = true
	selected_index = -1
	backdrop.set_edit_mode(true)
	nav_bar.visible = false
	var adventure_card := ui_layer.get_node_or_null("NextAdventureCard") as Control
	if adventure_card:
		adventure_card.visible = false
	_build_palette()
	_refresh_furniture()


func _leave_edit_mode() -> void:
	edit_mode = false
	selected_index = -1
	drag_index = -1
	backdrop.set_edit_mode(false)
	if palette:
		palette.queue_free()
		palette = null
	nav_bar.visible = true
	var adventure_card := ui_layer.get_node_or_null("NextAdventureCard") as Control
	if adventure_card:
		adventure_card.visible = true
	main.save.set_room_placements(placements)
	_refresh_furniture()


func _build_palette() -> void:
	if is_instance_valid(palette):
		palette.get_parent().remove_child(palette)
		palette.queue_free()
	palette = PanelContainer.new()
	# 꾸미기 중에는 모험 카드를 숨겨 편집 공간과 도구 패널의 시각적 간격을 확보한다.
	# 도구 행과 가구 목록 사이에도 충분한 내부 여백을 둔다.
	var palette_height := 282.0
	palette.position = Vector2(20, G.H - 28.0 - palette_height)
	palette.size = Vector2(G.W - 40, palette_height)
	var palette_style := _panel_style(Color("#fffaf5"), Color("#81659f"), 26)
	palette_style.content_margin_left = 12
	palette_style.content_margin_right = 12
	palette_style.content_margin_top = 14
	palette_style.content_margin_bottom = 14
	palette.add_theme_stylebox_override("panel", palette_style)
	ui_layer.add_child(palette)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	palette.add_child(box)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	box.add_child(tools)
	var guide := Label.new()
	guide.text = L10n.text("가구 배치")
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	guide.add_theme_font_size_override("font_size", 21)
	guide.add_theme_color_override("font_color", ArtDirection.ink())
	tools.add_child(guide)
	var rotate := _button(L10n.text("회전"), Color("#6daed5"), Vector2(70, 54), 18)
	rotate.disabled = selected_index < 0
	rotate.pressed.connect(_rotate_selected)
	tools.add_child(rotate)
	var remove := _button(L10n.text("치우기"), Color("#b883a5"), Vector2(78, 54), 17)
	remove.disabled = selected_index < 0
	remove.pressed.connect(_remove_selected)
	tools.add_child(remove)
	var album := _button(L10n.text("앨범"), Color("#7454aa"), Vector2(78, 54), 18)
	album.pressed.connect(_show_album)
	if not main.save.home_feature_unlocked("album"):
		album.disabled = true
		album.text = L10n.text("🔒L%d" % main.save.home_feature_unlock_level("album"))
		album.tooltip_text = L10n.text("LEVEL %d 클리어 후 첫 추억 앨범이 열려요") % main.save.home_feature_unlock_level("album")
	tools.add_child(album)
	var photo := _button(L10n.text("촬영"), Color("#d65e91"), Vector2(78, 54), 18)
	photo.pressed.connect(_enter_photo_mode)
	tools.add_child(photo)
	var done := _button(tr("완료"), Color("#65bd77"), Vector2(70, 54), 19)
	done.pressed.connect(_leave_edit_mode)
	tools.add_child(done)
	var themes := HBoxContainer.new()
	themes.add_theme_constant_override("separation", 8)
	box.add_child(themes)
	for theme in RoomData.ROOM_THEMES:
		var theme_button := _home_button(tr(L10n.text(String(theme.name))), Vector2(208, 44), 18)
		theme_button.name = "EditorTheme_" + String(theme.id)
		var unlocked: bool = main.save.is_room_theme_unlocked(String(theme.id))
		theme_button.disabled = not unlocked or main.save.get_room_theme() == theme.id
		if not unlocked:
			theme_button.text = L10n.text(tr(L10n.text(String(theme.name))) + L10n.text("\n%d레벨 클리어 후 해금") % int(theme.unlock_level))
			theme_button.add_theme_font_size_override("font_size", 15)
		theme_button.pressed.connect(_select_room_theme.bind(String(theme.id)))
		themes.add_child(theme_button)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 120)
	# 모바일에서도 가구 버튼 위를 손가락으로 끌어 좌우 목록을 탐색할 수 있다.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 8
	scroll.follow_focus = false
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(scroll)
	var list := HBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(list)
	# 배치 팔레트는 실제 지급된 시작 가구만 보여준다. 별/업적 보상은
	# 별도의 획득·보유 처리가 구현되기 전까지 잠금 슬롯으로도 노출하지 않는다.
	for item in RoomData.owned_items(main.save):
		var unlocked := RoomData.item_unlocked(item, main.save)
		var already_placed := false
		for placement in placements:
			if placement.id == item.id:
				already_placed = true
				break
		var label := L10n.text(String(item.name))
		var button := _home_button("", Vector2(126, 100), 16)
		button.tooltip_text = L10n.text(tr(label))
		var preview := TextureRect.new()
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.texture = FurnitureArtLib.texture(String(item.id))
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.position = Vector2(8, 5)
		preview.size = Vector2(110, 64)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(preview)
		var caption := _home_label(tr(label), Vector2(5, 72), Vector2(116, 24), 16)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_child(caption)
		# 아이템 위에서 시작한 터치도 부모 ScrollContainer로 전달한다.
		# ScrollContainer가 deadzone을 넘으면 버튼 클릭을 취소하고 좌우 드래그로 전환한다.
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.mouse_force_pass_scroll_events = true
		button.disabled = not unlocked or already_placed
		if already_placed:
			_mark_furniture_placed(button, Color(String(item.color)))
			caption.add_theme_color_override("font_color", ArtDirection.success_color())
		var item_id := String(item.id)
		button.pressed.connect(func(): _add_furniture(item_id))
		list.add_child(button)


func _add_furniture(id: String) -> void:
	for y in range(RoomData.GRID_H):
		for x in range(RoomData.GRID_W):
			var candidate := {"id":id, "x":x, "y":y, "rotation":0}
			if _placement_valid(candidate, -1):
				placements.append(candidate)
				selected_index = placements.size() - 1
				main.audio.play("pop", 1.12)
				main.save.set_room_placements(placements)
				main.save.record_retention_action("decorate")
				_refresh_furniture()
				_build_palette()
				return
	_show_toast(L10n.text("놓을 공간이 부족해요"))


func _rotate_selected() -> void:
	if selected_index < 0 or selected_index >= placements.size():
		return
	var candidate: Dictionary = placements[selected_index].duplicate(true)
	candidate.rotation = posmod(int(candidate.get("rotation", 0)) + 1, 4)
	if _placement_valid(candidate, selected_index):
		placements[selected_index] = candidate
		main.audio.play("grab", 1.15)
		main.save.set_room_placements(placements)
		_refresh_furniture()
	else:
		_show_toast(L10n.text("회전할 공간이 없어요"))


func _remove_selected() -> void:
	if selected_index < 0 or selected_index >= placements.size():
		return
	placements.remove_at(selected_index)
	selected_index = -1
	main.save.set_room_placements(placements)
	_refresh_furniture()
	_build_palette()


func _gui_input(event: InputEvent) -> void:
	if edit_mode:
		_handle_edit_input(event)
	elif event is InputEventScreenTouch and event.pressed:
		var touched_resident := false
		for resident in resident_nodes:
			if is_instance_valid(resident) and event.position.distance_to(resident.global_position) < 58:
				_complete_home_interaction_hint()
				_resident_touch_react(resident)
				touched_resident = true
				break
		if not touched_resident and event.position.distance_to(Vector2(360, 615 + RoomData.SCREEN_Y_OFFSET)) < 125:
			_complete_home_interaction_hint()
			_hero_react()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for resident in resident_nodes:
			if is_instance_valid(resident) and event.position.distance_to(resident.global_position) < 58:
				_complete_home_interaction_hint()
				_resident_touch_react(resident)
				return
		if event.position.distance_to(Vector2(360, 615 + RoomData.SCREEN_Y_OFFSET)) < 125:
			_complete_home_interaction_hint()
			_hero_react()


func _resident_touch_react(resident: Sprite2D) -> void:
	var record: Dictionary = resident.get_meta("record")
	var profile := CharacterCatalog.profile(String(record.get("color", "R")))
	var reactions: Array = profile.get("touch", ["smile"])
	var reaction := L10n.text(String(reactions[randi() % reactions.size()]))
	var resident_id := resident.get_instance_id()
	var previous = _resident_touch_tweens.get(resident_id)
	if previous is Tween and previous.is_valid():
		previous.kill()
	var home: Vector2 = resident_home_positions.get(resident_id, resident.position)
	var base_scale := Vector2.ONE * 82.0 / float(resident.texture.get_width())
	resident.position = home
	resident.rotation = 0.0
	resident.scale = base_scale
	var tw := resident.create_tween()
	_resident_touch_tweens[resident_id] = tw
	if reaction in ["startle", "surprise", "peek"]:
		tw.tween_property(resident, "scale", base_scale * 1.22, 0.12).set_trans(Tween.TRANS_BACK)
		tw.tween_property(resident, "scale", base_scale, 0.25).set_trans(Tween.TRANS_BOUNCE)
	else:
		tw.tween_property(resident, "position", home + Vector2(0, -25), 0.16).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(resident, "position", home, 0.28).set_trans(Tween.TRANS_BOUNCE)
	_speech_bubble(L10n.text(String(profile.get("greeting", L10n.text("반가워요!")))), home)
	var bond_gain: Dictionary = main.save.add_resident_affection(String(record.get("id", "")), 1)
	_record_bond_analytics(record, bond_gain)
	main.audio.play("pop", 1.12)
	G.haptic(7)


func _record_bond_analytics(record: Dictionary, result: Dictionary) -> void:
	if not main.analytics or int(result.get("granted", 0)) <= 0:
		return
	main.analytics.track("resident_bond", {
		"resident_id": String(record.get("id", "")),
		"level": int(result.get("level", 1)),
		"affection": int(result.get("affection", 0)),
	})


func _grid_cell(point: Vector2) -> Vector2i:
	return Vector2i(
		floori((point.x - RoomData.ORIGIN.x) / RoomData.CELL),
		floori((point.y - furniture_layer.position.y - RoomData.ORIGIN.y) / RoomData.CELL)
	)


func _pick_placement(cell: Vector2i) -> int:
	for i in range(placements.size() - 1, -1, -1):
		if _placement_cells(placements[i]).has(cell):
			return i
	return -1


func _handle_edit_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var cell := _grid_cell(event.position)
			drag_index = _pick_placement(cell)
			selected_index = drag_index
			if drag_index >= 0:
				drag_offset = cell - Vector2i(int(placements[drag_index].x), int(placements[drag_index].y))
				main.audio.play("grab")
			_refresh_furniture()
			_build_palette()
		else:
			if drag_index >= 0:
				main.save.set_room_placements(placements)
			drag_index = -1
	elif event is InputEventScreenDrag and drag_index >= 0:
		var desired := _grid_cell(event.position) - drag_offset
		var candidate: Dictionary = placements[drag_index].duplicate(true)
		candidate.x = desired.x
		candidate.y = desired.y
		if _placement_valid(candidate, drag_index):
			placements[drag_index] = candidate
			_refresh_furniture()


func _hero_react() -> void:
	var hero := character_layer.get_node_or_null("Hero") as Sprite2D
	if not hero:
		return
	main.audio.play("pop", randf_range(0.92, 1.25))
	G.haptic(8)
	# 연타 중 현재(공중) 좌표를 새 기준점으로 삼으면 클릭할 때마다 위로 떠오른다.
	# 진행 중인 반응을 취소하고 생성 시 저장한 홈 좌표에서 항상 다시 시작한다.
	if _hero_reaction_tween and _hero_reaction_tween.is_valid():
		_hero_reaction_tween.kill()
	var home: Vector2 = hero.get_meta("home_position", Vector2(360, 615))
	hero.position = home
	_hero_reaction_tween = hero.create_tween()
	_hero_reaction_tween.tween_property(hero, "position", home + Vector2(0, -34), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hero_reaction_tween.tween_property(hero, "position", home, 0.28).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var hero_half_height := 80.0
	if hero.texture:
		hero_half_height = float(hero.texture.get_height()) * absf(hero.scale.y) * 0.5
	var speech_anchor := home - Vector2(0, hero_half_height + 14.0)
	_speech_bubble([L10n.text("말랑!"), L10n.text("오늘도 같이 모험해요!"), L10n.text("방이 정말 포근해요!")][randi() % 3], speech_anchor)


func _show_album() -> void:
	if not main.save.home_feature_unlocked("album"):
		return
	var dim := ColorRect.new()
	dim.color = ArtDirection.dim_color()
	_fit_overlay_to_viewport(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 330
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(650, 1060)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#fff9f3"), Color("#73509a"), 34))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = L10n.text(tr("젤리 아지트 앨범"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", ArtDirection.ink())
	box.add_child(title)
	var residents: Array = main.save.get_resident_records()
	var summary := Label.new()
	summary.text = L10n.text(tr("구출 주민 %d/6 · 추억 %d개") % [residents.size(), main.save.album_memories.size()])
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 20)
	summary.add_theme_color_override("font_color", ArtDirection.ink())
	box.add_child(summary)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(590, 0)
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	var resident_heading := Label.new()
	resident_heading.text = L10n.text(tr("함께 사는 친구들"))
	resident_heading.add_theme_font_size_override("font_size", 23)
	resident_heading.add_theme_color_override("font_color", ArtDirection.ink())
	list.add_child(resident_heading)
	var resident_grid := GridContainer.new()
	resident_grid.columns = 3
	resident_grid.add_theme_constant_override("h_separation", 8)
	resident_grid.add_theme_constant_override("v_separation", 8)
	list.add_child(resident_grid)
	if residents.is_empty():
		var empty := Label.new()
		empty.text = L10n.text(tr("모험에서 첫 주민을 구조하면 사진 카드가 열려요."))
		empty.custom_minimum_size = Vector2(570, 110)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 19)
		empty.add_theme_color_override("font_color", ArtDirection.ink())
		resident_grid.add_child(empty)
	else:
		for resident in residents:
			resident_grid.add_child(_album_resident_card(resident))
	var memory_heading := Label.new()
	memory_heading.text = L10n.text(tr("최근 말랑 추억"))
	memory_heading.add_theme_font_size_override("font_size", 23)
	memory_heading.add_theme_color_override("font_color", ArtDirection.danger_color())
	list.add_child(memory_heading)
	var memory_grid := GridContainer.new()
	memory_grid.columns = 2
	memory_grid.add_theme_constant_override("h_separation", 8)
	memory_grid.add_theme_constant_override("v_separation", 8)
	list.add_child(memory_grid)
	var memories: Array = main.save.album_memories.slice(0, 6)
	if memories.is_empty():
		memories = [{"kind":"welcome", "caption":tr("첫 모험을 시작한 날") }]
	for memory in memories:
		memory_grid.add_child(_album_memory_card(memory))
	var achievement_heading := Label.new()
	achievement_heading.text = L10n.text(tr("구조대 배지"))
	achievement_heading.add_theme_font_size_override("font_size", 23)
	achievement_heading.add_theme_color_override("font_color", ArtDirection.success_color())
	list.add_child(achievement_heading)
	for i in range(RoomData.ACHIEVEMENT_NAMES.size()):
		var unlocked := RoomData.achievement_unlocked(i, main.save)
		var badge := PanelContainer.new()
		badge.custom_minimum_size = Vector2(570, 52)
		badge.add_theme_stylebox_override("panel", _panel_style(Color("#eaf8ed") if unlocked else Color("#eeeaf0"), Color("#65a878") if unlocked else Color("#a29aa6"), 17))
		var row := Label.new()
		row.text = L10n.text(("★  " if unlocked else "◇  ") + tr(RoomData.ACHIEVEMENT_NAMES[i]) + ("  · " + tr("달성") if unlocked else ""))
		row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override("font_size", 19)
		row.add_theme_color_override("font_color", ArtDirection.text_color(Color("#4f805e") if unlocked else Color("#8c838f")))
		badge.add_child(row)
		list.add_child(badge)
	var close := _button(tr("닫기"), Color("#8d72bd"), Vector2(260, 64), 24)
	close.pressed.connect(dim.queue_free)
	box.add_child(close)


func _album_resident_card(resident: Dictionary) -> PanelContainer:
	var bond: Dictionary = main.save.get_resident_bond_progress(resident)
	var color_id := String(resident.get("color", "R"))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(187, 184)
	var tint: Color = G.COLORS.get(color_id, Color("#e98aa5"))
	card.add_theme_stylebox_override("panel", _panel_style(tint.lightened(0.35), tint.darkened(0.24), 22))
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 2)
	card.add_child(content)
	var portrait := TextureRect.new()
	portrait.texture = G.jelly_tex(color_id)
	portrait.custom_minimum_size = Vector2(96, 96)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(portrait)
	var name := Label.new()
	name.text = L10n.text("%s · Lv.%d" % [L10n.text(String(resident.get("name", tr("젤리몬")))), int(bond.level)])
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 18)
	name.add_theme_color_override("font_color", ArtDirection.text_color(tint.darkened(0.42)))
	content.add_child(name)
	var relation := Label.new()
	relation.text = L10n.text(tr(L10n.text(String(bond.title))))
	relation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	relation.add_theme_font_size_override("font_size", 15)
	relation.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(relation)
	return card


func _album_memory_card(memory: Dictionary) -> PanelContainer:
	var kinds := {"photo":"📷", "pose":"✦", "interaction":"♥", "furniture":"⌂", "exclusive_furniture":"♛", "welcome":"★"}
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(286, 112)
	card.add_theme_stylebox_override("panel", _panel_style(Color("#fff0f5"), Color("#d88ba7"), 20))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var icon := Label.new()
	icon.text = String(kinds.get(String(memory.get("kind", "interaction")), "♥"))
	icon.custom_minimum_size = Vector2(54, 0)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 33)
	icon.add_theme_color_override("font_color", ArtDirection.danger_color())
	row.add_child(icon)
	var caption := Label.new()
	caption.text = L10n.text(tr(L10n.text(String(memory.get("caption", L10n.text("함께 보낸 포근한 순간"))))))
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 16)
	caption.add_theme_color_override("font_color", ArtDirection.ink())
	row.add_child(caption)
	return card


func _enter_photo_mode() -> void:
	if edit_mode:
		_leave_edit_mode()
	ui_layer.visible = false
	backdrop.set_photo_mode(true)
	furniture_layer.position.y = 142
	character_layer.position.y = 142
	photo_layer = Control.new()
	photo_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	photo_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo_layer.z_index = 40
	add_child(photo_layer)
	for rect in [Rect2(18, 18, G.W - 36, 8), Rect2(18, G.H - 26, G.W - 36, 8), Rect2(18, 18, 8, G.H - 36), Rect2(G.W - 26, 18, 8, G.H - 36)]:
		var line := ColorRect.new()
		line.position = rect.position
		line.size = rect.size
		line.color = Color(1, 1, 1, 0.78)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		photo_layer.add_child(line)
	var title := Label.new()
	title.text = L10n.text("PHOTO  ·  MY JELLY HIDEOUT")
	title.position = Vector2(60, 45)
	title.size = Vector2(600, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", ArtDirection.ink())
	title.add_theme_color_override("font_outline_color", Color("#684c7c"))
	title.add_theme_constant_override("outline_size", 0)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_stylebox_override("normal", ArtDirection.surface())
	photo_layer.add_child(title)
	var controls := HBoxContainer.new()
	controls.position = Vector2(65, 1150)
	controls.add_theme_constant_override("separation", 16)
	photo_layer.add_child(controls)
	var pose := _button(L10n.text("포즈"), Color("#66a9d8"), Vector2(160, 78), 24)
	pose.pressed.connect(_photo_pose)
	controls.add_child(pose)
	var save_button := _button(L10n.text("사진 저장"), Color("#e580a7"), Vector2(190, 78), 27)
	save_button.pressed.connect(_save_photo)
	controls.add_child(save_button)
	var close := _button(tr("닫기"), Color("#7d6a9e"), Vector2(190, 78), 27)
	close.pressed.connect(_leave_photo_mode)
	controls.add_child(close)
	_play_random_resident_interaction()


func _photo_pose() -> void:
	if resident_nodes.is_empty():
		return
	var center := Vector2(360, 720)
	for i in range(resident_nodes.size()):
		var resident: Sprite2D = resident_nodes[i]
		var angle := -PI * 0.85 + PI * 0.7 * float(i) / maxf(1.0, resident_nodes.size() - 1.0)
		var target := center + Vector2(cos(angle) * 155, sin(angle) * 78)
		resident.create_tween().tween_property(resident, "position", target, 0.42).set_trans(Tween.TRANS_BACK)
	_speech_bubble(L10n.text("다 같이 말랑~!"), center - Vector2(0, 95))
	main.save.add_album_memory("pose", "모두 함께 기념사진 포즈!", main.save.get_resident_records().map(func(r): return String(r.id)))


func _leave_photo_mode() -> void:
	if photo_layer:
		photo_layer.queue_free()
		photo_layer = null
	backdrop.set_photo_mode(false)
	furniture_layer.position.y = RoomData.SCREEN_Y_OFFSET
	character_layer.position.y = RoomData.SCREEN_Y_OFFSET
	ui_layer.visible = true


func _save_photo() -> void:
	if not photo_layer:
		return
	photo_layer.visible = false
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var pictures := "/tmp" if OS.get_cmdline_user_args().has("--shots") else OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pictures.is_empty():
		pictures = ProjectSettings.globalize_path("user://photos")
	var folder := pictures.path_join("JellyMon")
	DirAccess.make_dir_recursive_absolute(folder)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := folder.path_join("jellymon_room_%s.png" % stamp)
	var error := image.save_png(path)
	if error == OK:
		main.save.add_album_memory("photo", "아지트 사진을 남겼어요", main.save.get_resident_records().map(func(r): return String(r.id)))
	photo_layer.visible = true
	_show_toast(L10n.text("사진을 저장했어요!\n%s") % folder if error == OK else L10n.text("사진 저장에 실패했어요"))


func _show_toast(text: String) -> void:
	var label := Label.new()
	label.text = L10n.text(text)
	label.position = Vector2(110, 960)
	label.size = Vector2(500, 80)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", ArtDirection.ink())
	label.add_theme_color_override("font_outline_color", Color("#5f456e"))
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_stylebox_override("normal", ArtDirection.surface())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 80
	add_child(label)
	var tw := label.create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(label, "modulate:a", 0.0, 0.35)
	tw.tween_callback(label.queue_free)
