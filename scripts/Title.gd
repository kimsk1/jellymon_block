extends Control
class_name Title
## 메인 화면 = 플레이 기록이 살아 움직이는 '젤리 아지트'.

const FurnitureRewards = preload("res://scripts/FurnitureRewardCatalog.gd")
const HomeNavIconScene = preload("res://scripts/HomeNavIcon.gd")
const DailyMissionCatalogLib = preload("res://scripts/DailyMissionCatalog.gd")
const JellyDexCatalogLib = preload("res://scripts/JellyDexCatalog.gd")
const LiveMessageCatalogLib = preload("res://scripts/LiveMessageCatalog.gd")
const LiveProgressionCatalogLib = preload("res://scripts/LiveProgressionCatalog.gd")

var main = null
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
var stardust_label: Label
var shop_popup: Control
var purchase_confirm_popup: Control
var shop_balance_label: Label
var shop_status_label: Label
var home_energy_label: Label
var header_name_label: Label
var nickname_popup: Control
var nickname_input: LineEdit
var nickname_error: Label
var nickname_confirm_button: Button
var _last_home_energy_second := -1
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
	_apply_responsive_layout()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	mouse_filter = Control.MOUSE_FILTER_STOP
	placements = main.save.get_room_placements()
	backdrop = RoomBackdrop.new()
	add_child(backdrop)
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
	var interactive := not OS.get_cmdline_user_args().has("--shots") and not OS.get_cmdline_user_args().has("--shot-room-refresh") and not OS.get_cmdline_user_args().has("--shot-room-edit") and not OS.get_cmdline_user_args().has("--shot-level-51") and DisplayServer.get_name() != "headless"
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


func _panel_style(color: Color, border: Color, radius: int = 24) -> StyleBoxFlat:
	return ArtDirection.panel(color, border, radius)


func _button(text: String, color: Color, size := Vector2(150, 74), font_size := 27) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = size
	button.add_theme_font_size_override("font_size", font_size)
	ArtDirection.apply_button(button, color, 20)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.72))
	button.add_theme_color_override("font_disabled_outline_color", color.darkened(0.38))
	return button


func _format_number(value: int) -> String:
	var digits := str(maxi(0, value))
	var formatted := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			formatted += ","
		formatted += digits[i]
	return formatted


func _nav_button(icon_kind: String, title_text: String, color: Color, width: float = 150.0) -> Button:
	var button := _button("", color, Vector2(width, 122), 27)
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 4)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)
	var icon_badge := PanelContainer.new()
	icon_badge.custom_minimum_size = Vector2(50, 50)
	icon_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(1, 1, 1, 0.18)
	badge_style.border_color = Color(1, 1, 1, 0.42)
	badge_style.set_border_width_all(2)
	badge_style.set_corner_radius_all(25)
	badge_style.shadow_color = Color(0.12, 0.05, 0.2, 0.18)
	badge_style.shadow_size = 3
	badge_style.shadow_offset = Vector2(0, 2)
	icon_badge.add_theme_stylebox_override("panel", badge_style)
	content.add_child(icon_badge)
	var icon: Control = HomeNavIconScene.new()
	icon.setup(icon_kind)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_badge.add_child(icon)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", color.darkened(0.42))
	title.add_theme_constant_override("outline_size", 3)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)
	return button


func _mark_furniture_placed(button: Button, item_color: Color) -> void:
	## 잠긴 가구와 혼동되지 않도록 배치 완료 상태는 색과 배지를 동시에 사용한다.
	var placed_style: StyleBoxFlat = button.get_theme_stylebox("disabled").duplicate()
	placed_style.bg_color = Color.from_hsv(item_color.h, item_color.s * 0.38, 0.52, 1.0)
	placed_style.border_color = Color("#51445f")
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
	badge_label.text = "✓ 배치됨"
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size", 14)
	badge_label.add_theme_color_override("font_color", Color.WHITE)
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(badge_label)


func _build_header() -> void:
	var card := PanelContainer.new()
	card.position = Vector2(20, 18)
	card.size = Vector2(470, 105)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _panel_style(Color("#fff8fd"), Color("#8e72ad"), 26))
	ui_layer.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 13)
	card.add_child(row)
	var avatar := TextureRect.new()
	avatar.texture = G.hero_tex()
	avatar.custom_minimum_size = Vector2(76, 76)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.mouse_filter = Control.MOUSE_FILTER_STOP
	avatar.tooltip_text = "젤리몬 도감 열기"
	avatar.gui_input.connect(func(event: InputEvent):
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
			_show_jelly_dex()
	)
	row.add_child(avatar)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	var stage := RoomData.growth_stage(main.save)
	header_name_label = Label.new()
	header_name_label.text = main.save.get_nickname() if main.save.has_nickname() else "내 젤리몬"
	header_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header_name_label.add_theme_font_size_override("font_size", 27)
	header_name_label.add_theme_color_override("font_color", Color("#5b3d73"))
	info.add_child(header_name_label)
	var stars := RoomData.total_stars(main.save)
	var progress := Label.new()
	progress.text = "%s · 성장 별 %d / %d" % [RoomData.growth_name(stage), stars, RoomData.next_growth_stars(stage)] if stage < RoomData.max_growth_stage() else "%s · 별 %d" % [RoomData.growth_name(stage), stars]
	progress.add_theme_font_size_override("font_size", 19)
	progress.add_theme_color_override("font_color", Color("#8d6b98"))
	info.add_child(progress)
	var dust := PanelContainer.new()
	dust.position = Vector2(505, 18)
	dust.size = Vector2(195, 49)
	dust.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dust.add_theme_stylebox_override("panel", _panel_style(Color("#f5efff"), Color("#9872c9"), 22))
	ui_layer.add_child(dust)
	stardust_label = Label.new()
	stardust_label.text = "★ 별가루 %d" % main.save.get_stardust()
	stardust_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stardust_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stardust_label.add_theme_font_size_override("font_size", 23)
	stardust_label.add_theme_color_override("font_color", Color("#70499e"))
	stardust_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dust.add_child(stardust_label)
	var energy_panel := PanelContainer.new()
	energy_panel.position = Vector2(505, 73)
	energy_panel.size = Vector2(195, 52)
	energy_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_panel.add_theme_stylebox_override("panel", _panel_style(Color("#fff3f6"), Color("#d8647e"), 19))
	ui_layer.add_child(energy_panel)
	home_energy_label = Label.new()
	home_energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	home_energy_label.add_theme_font_size_override("font_size", 18)
	home_energy_label.add_theme_color_override("font_color", Color("#ce4e6d"))
	home_energy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_panel.add_child(home_energy_label)
	mission_button = _button("구조 0/3", Color("#e06f7f"), Vector2(94, 43), 15)
	mission_button.position = Vector2(505, 132)
	mission_button.size = Vector2(94, 43)
	mission_button.pressed.connect(_show_daily_mission_popup)
	ui_layer.add_child(mission_button)
	attendance_button = _button("출석", Color("#8c63c7"), Vector2(94, 43), 15)
	attendance_button.position = Vector2(606, 132)
	attendance_button.size = Vector2(94, 43)
	attendance_button.clip_text = true
	attendance_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	attendance_button.pressed.connect(_show_attendance_popup)
	ui_layer.add_child(attendance_button)
	_refresh_home_energy()
	_refresh_attendance_button()
	_refresh_mission_button()


func _show_nickname_popup() -> void:
	if nickname_popup and is_instance_valid(nickname_popup):
		return
	var dim := ColorRect.new()
	dim.color = Color(0.09, 0.04, 0.16, 0.74)
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
	title.text = "반가워요! 이름을 알려주세요"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#5b3675"))
	content.add_child(title)
	var guide := Label.new()
	guide.text = "공백 없이 1~12글자로 입력해 주세요."
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide.add_theme_font_size_override("font_size", 20)
	guide.add_theme_color_override("font_color", Color("#7e628d"))
	content.add_child(guide)
	nickname_input = LineEdit.new()
	nickname_input.custom_minimum_size = Vector2(510, 72)
	nickname_input.max_length = SaveGame.MAX_NICKNAME_LENGTH
	nickname_input.placeholder_text = "닉네임 입력"
	nickname_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	nickname_input.add_theme_font_size_override("font_size", 28)
	nickname_input.add_theme_color_override("font_color", Color("#563a6e"))
	nickname_input.add_theme_color_override("placeholder_color", Color("#a58daf"))
	nickname_input.add_theme_stylebox_override("normal", _panel_style(Color("#fffafd"), Color("#b38acb"), 20))
	nickname_input.add_theme_stylebox_override("focus", _panel_style(Color.WHITE, Color("#e06e91"), 20))
	nickname_input.text_changed.connect(_on_nickname_text_changed)
	nickname_input.text_submitted.connect(func(_value: String): _confirm_nickname())
	content.add_child(nickname_input)
	nickname_error = Label.new()
	nickname_error.text = "공백은 사용할 수 없어요."
	nickname_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nickname_error.add_theme_font_size_override("font_size", 18)
	nickname_error.add_theme_color_override("font_color", Color("#d34f70"))
	nickname_error.modulate.a = 0.0
	content.add_child(nickname_error)
	var notice := Label.new()
	notice.text = "※ 불법·음란·위험한 단어는 외부 노출 시 *로 표시될 수 있어요."
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.custom_minimum_size.x = 540
	notice.add_theme_font_size_override("font_size", 17)
	notice.add_theme_color_override("font_color", Color("#8b718f"))
	content.add_child(notice)
	nickname_confirm_button = _button("이 이름으로 시작하기", Color("#eb7b95"), Vector2(330, 70), 25)
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
		nickname_error.text = "공백은 사용할 수 없어요." if value.length() <= SaveGame.MAX_NICKNAME_LENGTH else "닉네임은 12글자까지 사용할 수 있어요."


func _confirm_nickname() -> void:
	if not nickname_input or not main.save.set_nickname(nickname_input.text):
		if nickname_error:
			nickname_error.text = "공백 없이 1~12글자로 입력해 주세요."
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
	_show_toast("%s님, 환영해요!" % main.save.get_nickname())
	call_deferred("_continue_first_time_flow")


func _continue_first_time_flow() -> void:
	if main.play_intro_if_needed():
		return
	if main.save.can_claim_attendance():
		_show_attendance_popup()


func _refresh_home_energy() -> void:
	if not home_energy_label or main == null:
		return
	var current: int = main.save.get_energy()
	var status := "가득 참"
	if current < SaveGame.MAX_ENERGY:
		var seconds: int = main.save.seconds_until_next_energy()
		status = "다음 %02d:%02d" % [seconds / 60, seconds % 60]
	home_energy_label.text = "♥ %d/%d  ·  %s" % [current, SaveGame.MAX_ENERGY, status]


func _refresh_attendance_button() -> void:
	if not attendance_button:
		return
	var week: int = main.save.get_attendance_week()
	var claimed: int = main.save.get_attendance_day_in_week()
	if main.save.can_claim_attendance():
		attendance_button.text = "선물 받기"
		attendance_button.tooltip_text = "%d주차 %d일차 출석 선물을 받을 수 있어요" % [week, claimed + 1]
	else:
		attendance_button.text = "출석 %d/7" % claimed
		attendance_button.tooltip_text = "%d주차 출석 완료 · 다음 선물은 내일 받을 수 있어요" % week


func _shop_item_card(item: Dictionary) -> PanelContainer:
	var is_ads := String(item.get("type", "")) == "remove_ads"
	var is_energy := String(item.get("type", "")) == "energy"
	var is_furniture := String(item.get("type", "")) == "furniture"
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(570, 128)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#e4f4ff") if is_furniture else (Color("#efe4ff") if is_ads else (Color("#ffe3e9") if is_energy else Color("#fff3ce")))
	style.border_color = Color("#4d91bd") if is_furniture else (Color("#805caf") if is_ads else (Color("#d45f7b") if is_energy else Color("#d69a35")))
	style.set_border_width_all(3)
	style.set_corner_radius_all(24)
	style.corner_detail = 12
	style.shadow_color = Color(0.1, 0.05, 0.18, 0.24)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(92, 92)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(String(item.get("color", "#5fa9d6"))) if is_furniture else (Color("#7c5ab0") if is_ads else (Color("#f06b88") if is_energy else Color("#ffd660")))
	icon_style.set_corner_radius_all(25)
	icon_style.border_color = Color("#5b3f83") if is_ads else (Color("#b74260") if is_energy else Color("#d18c27"))
	icon_style.set_border_width_all(3)
	icon_frame.add_theme_stylebox_override("panel", icon_style)
	row.add_child(icon_frame)
	if is_furniture:
		var furniture_icon := Label.new()
		furniture_icon.text = String(item.get("mark", "◆"))
		furniture_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		furniture_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		furniture_icon.add_theme_font_size_override("font_size", 45)
		furniture_icon.add_theme_color_override("font_color", Color.WHITE)
		icon_frame.add_child(furniture_icon)
	elif is_ads:
		var ad_icon := Label.new()
		ad_icon.text = "AD\nOFF"
		ad_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ad_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ad_icon.add_theme_font_size_override("font_size", 23)
		ad_icon.add_theme_color_override("font_color", Color.WHITE)
		icon_frame.add_child(ad_icon)
	elif is_energy:
		var heart_icon := Label.new()
		heart_icon.text = "♥"
		heart_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heart_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		heart_icon.add_theme_font_size_override("font_size", 52)
		heart_icon.add_theme_color_override("font_color", Color.WHITE)
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
	name_label.text = String(item.get("name", ""))
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", Color("#583b70"))
	info.add_child(name_label)
	if String(item.get("id", "")) == "stardust_110":
		var best := Label.new()
		best.text = "BEST · 10개 보너스"
		best.add_theme_font_size_override("font_size", 17)
		best.add_theme_color_override("font_color", Color("#d07038"))
		info.add_child(best)
	var description := Label.new()
	description.text = String(item.get("description", ""))
	description.add_theme_font_size_override("font_size", 16)
	description.add_theme_color_override("font_color", Color("#816d89"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(description)
	var purchased: bool = (is_ads and bool(main.save.has_removed_ads())) or (is_furniture and main.save.has_furniture(String(item.get("furniture_id", ""))))
	var buy := _button("보유 중" if purchased and is_furniture else ("구매 완료" if purchased else String(item.get("display_price", ""))), Color("#77b984") if purchased else Color("#eb8650"), Vector2(135, 68), 23)
	buy.disabled = purchased
	buy.pressed.connect(func(): _show_purchase_confirmation(item, buy))
	row.add_child(buy)
	return card


func _furniture_shop_product(item: Dictionary) -> Dictionary:
	var id := String(item.id)
	return {
		"id": "furniture_" + id,
		"type": "furniture",
		"furniture_id": id,
		"name": String(item.name),
		"display_price": "★ %s" % _format_number(RoomData.furniture_price(id)),
		"description": "한 번 구매하면 젤리 아지트에서 영구적으로 배치할 수 있어요.",
		"color": String(item.color),
		"mark": String(item.mark),
	}


func _show_shop_popup() -> void:
	if shop_popup and is_instance_valid(shop_popup):
		return
	var dim := ColorRect.new()
	dim.color = Color(0.09, 0.04, 0.16, 0.68)
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
	title.text = "★ 젤리몬 상점"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 43)
	title.add_theme_color_override("font_color", Color("#5f387a"))
	content.add_child(title)
	shop_balance_label = Label.new()
	shop_balance_label.text = "보유 별가루  ★ %d" % main.save.get_stardust()
	shop_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_balance_label.add_theme_font_size_override("font_size", 22)
	shop_balance_label.add_theme_color_override("font_color", Color("#7d5a91"))
	content.add_child(shop_balance_label)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 12)
	content.add_child(tabs)
	var tab_group := ButtonGroup.new()
	tab_group.allow_unpress = false
	var currency_tab := _button("★ 별가루·하트", Color("#e48a48"), Vector2(275, 64), 23)
	currency_tab.toggle_mode = true
	currency_tab.button_group = tab_group
	currency_tab.button_pressed = true
	tabs.add_child(currency_tab)
	var furniture_tab := _button("▦ 가구", Color("#4c9dcc"), Vector2(275, 64), 23)
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
	currency_guide.text = "모험에 필요한 별가루와 하트를 충전하세요."
	currency_guide.add_theme_font_size_override("font_size", 20)
	currency_guide.add_theme_color_override("font_color", Color("#7a5b83"))
	currency_products.add_child(currency_guide)
	for item in ShopCatalog.load_items():
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
	furniture_guide.text = "별가루로 구매한 가구는 영구적으로 보유해요."
	furniture_guide.add_theme_font_size_override("font_size", 20)
	furniture_guide.add_theme_color_override("font_color", Color("#477c9c"))
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
	shop_status_label.text = "개발 빌드에서는 실제 결제 없이 테스트 상품이 지급됩니다." if OS.is_debug_build() else "구매 가격은 스토어 결제창에서 최종 확인할 수 있어요."
	shop_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_status_label.add_theme_font_size_override("font_size", 16)
	shop_status_label.add_theme_color_override("font_color", Color("#8b718f"))
	content.add_child(shop_status_label)
	var close := _button("닫기", Color("#806aa7"), Vector2(190, 64), 24)
	close.pressed.connect(_close_shop_popup)
	content.add_child(close)


func _show_purchase_confirmation(item: Dictionary, buy_button: Button) -> void:
	if purchase_confirm_popup and is_instance_valid(purchase_confirm_popup):
		return
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.03, 0.14, 0.76)
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
	var item_type := String(item.get("type", ""))
	badge_style.bg_color = Color(String(item.get("color", "#56a4d1"))) if item_type == "furniture" else (Color("#f6cc63") if item_type == "stardust" else (Color("#ef718d") if item_type == "energy" else Color("#8062b7")))
	badge_style.border_color = badge_style.bg_color.darkened(0.25)
	badge_style.set_border_width_all(3)
	badge_style.set_corner_radius_all(30)
	badge.add_theme_stylebox_override("panel", badge_style)
	content.add_child(badge)
	var badge_icon := Label.new()
	badge_icon.text = String(item.get("mark", "◆")) if item_type == "furniture" else ("★" if item_type == "stardust" else ("♥" if item_type == "energy" else "AD\nOFF"))
	badge_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_icon.add_theme_font_size_override("font_size", 48 if String(item.get("type", "")) != "remove_ads" else 21)
	badge_icon.add_theme_color_override("font_color", Color.WHITE)
	badge.add_child(badge_icon)
	var title := Label.new()
	title.text = "구매할까요?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 37)
	title.add_theme_color_override("font_color", Color("#5b3973"))
	content.add_child(title)
	var product := Label.new()
	product.text = "%s\n%s" % [String(item.get("name", "")), String(item.get("display_price", ""))]
	product.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	product.add_theme_font_size_override("font_size", 25)
	product.add_theme_color_override("font_color", Color("#6e4d7f"))
	content.add_child(product)
	var notice := Label.new()
	notice.text = "보유 별가루에서 즉시 차감됩니다." if item_type == "furniture" else "구매 버튼을 누르면 결제가 진행됩니다."
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_font_size_override("font_size", 17)
	notice.add_theme_color_override("font_color", Color("#907694"))
	content.add_child(notice)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	content.add_child(actions)
	var cancel := _button("취소", Color("#8b78a9"), Vector2(190, 70), 25)
	cancel.pressed.connect(_close_purchase_confirmation)
	actions.add_child(cancel)
	var confirm := _button("구매", Color("#eb7b55"), Vector2(230, 70), 26)
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
	var analytics_item_kind := String(item.get("type", "unknown"))
	if String(item.get("type", "")) == "furniture":
		var furniture_id := String(item.get("furniture_id", ""))
		var price := RoomData.furniture_price(furniture_id)
		if main.save.has_furniture(furniture_id):
			shop_status_label.text = "이미 보유한 가구예요."
			return
		if main.save.get_stardust() < price:
			shop_status_label.text = "별가루가 부족해요.  ★ %s 필요" % _format_number(price)
			return
		if not main.save.purchase_furniture(furniture_id, price):
			shop_status_label.text = "가구를 구매하지 못했어요."
			if main.analytics:
				main.analytics.track("shop_purchase", {"item_id": analytics_item_id, "kind": analytics_item_kind, "result": "failed"})
			return
		if main.analytics:
			main.analytics.track("shop_purchase", {"item_id": analytics_item_id, "kind": analytics_item_kind, "result": "success"})
			main.analytics.track("currency_sink", {"currency": "stardust", "amount": price, "sink": "furniture"})
		main.audio.play("shiny", 1.05)
		G.haptic(18)
		stardust_label.text = "★ 별가루 %d" % main.save.get_stardust()
		shop_balance_label.text = "보유 별가루  ★ %d" % main.save.get_stardust()
		buy_button.text = "보유 중"
		buy_button.disabled = true
		shop_status_label.text = "%s 구매 완료! 꾸미기에서 배치할 수 있어요." % String(item.get("name", ""))
		return
	if not OS.is_debug_build():
		shop_status_label.text = "플랫폼 결제 공급자를 연결한 뒤 구매할 수 있어요."
		if main.analytics:
			main.analytics.track("shop_purchase", {"item_id": analytics_item_id, "kind": analytics_item_kind, "result": "provider_unavailable"})
		return
	if not main.save.apply_verified_shop_item(item):
		shop_status_label.text = "이미 구매했거나 지급할 수 없는 상품이에요."
		if main.analytics:
			main.analytics.track("shop_purchase", {"item_id": analytics_item_id, "kind": analytics_item_kind, "result": "failed"})
		return
	if main.analytics:
		main.analytics.track("shop_purchase", {"item_id": analytics_item_id, "kind": analytics_item_kind, "result": "debug_success"})
	main.audio.play("shiny", 1.05)
	G.haptic(18)
	stardust_label.text = "★ 별가루 %d" % main.save.get_stardust()
	_refresh_home_energy()
	shop_balance_label.text = "보유 별가루  ★ %d" % main.save.get_stardust()
	if String(item.get("type", "")) == "remove_ads":
		buy_button.text = "구매 완료"
		buy_button.disabled = true
	shop_status_label.text = "%s 지급 완료!" % String(item.get("name", ""))


func _close_shop_popup() -> void:
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
	style.bg_color = Color("#d9f2df") if already_claimed else (Color("#ffe27a") if is_today else day_color)
	style.border_color = Color("#55a96c") if already_claimed else (Color("#d99225") if is_today else day_color.darkened(0.25))
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.corner_detail = 10
	style.shadow_color = Color(0.1, 0.05, 0.18, 0.22)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 3)
	tile.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	tile.add_child(box)
	var day_label := Label.new()
	day_label.text = "%d일%s" % [day, " ✓" if already_claimed else ""]
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_label.add_theme_font_size_override("font_size", 18)
	day_label.add_theme_color_override("font_color", Color("#674779"))
	box.add_child(day_label)
	var reward_label := Label.new()
	reward_label.text = _attendance_reward_compact(reward)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward_label.custom_minimum_size = Vector2(68, 57)
	reward_label.add_theme_font_size_override("font_size", 16)
	reward_label.add_theme_color_override("font_color", Color("#71577c"))
	box.add_child(reward_label)
	return tile


func _attendance_reward_compact(reward: Dictionary) -> String:
	var lines: Array[String] = []
	var stardust := int(reward.get("stardust", 0))
	var energy := int(reward.get("energy", 0))
	if stardust > 0:
		lines.append("★ 별 %d" % stardust)
	if energy > 0:
		lines.append("♥ 하트 %d" % energy)
	return "\n".join(lines)


func _attendance_reward_sentence(reward: Dictionary) -> String:
	var parts: Array[String] = []
	var stardust := int(reward.get("stardust", 0))
	var energy := int(reward.get("energy", 0))
	if stardust > 0:
		parts.append("별가루 %d개" % stardust)
	if energy > 0:
		parts.append("하트 %d개" % energy)
	return " + ".join(parts)


func _show_attendance_popup() -> void:
	if attendance_popup and is_instance_valid(attendance_popup):
		return
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.04, 0.18, 0.66)
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
	banner_style.bg_color = Color("#dec4f2")
	banner_style.border_color = Color("#9a72c4")
	banner_style.set_border_width_all(3)
	banner_style.set_corner_radius_all(25)
	banner_style.corner_detail = 12
	banner_style.shadow_color = Color(0.18, 0.08, 0.28, 0.2)
	banner_style.shadow_size = 6
	banner_style.shadow_offset = Vector2(0, 4)
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
		title.text = "첫 주 출석 선물" if week == 1 else "%d주차 출석 선물" % week
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 40)
		title.add_theme_color_override("font_color", Color("#5f387a"))
		heading.add_child(title)
		var subtitle := Label.new()
		subtitle.text = "별가루와 하트를 매일 함께 받아요!" if week == 1 else "매주 새로운 선물이 기다리고 있어요!"
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_font_size_override("font_size", 20)
		subtitle.add_theme_color_override("font_color", Color("#7f5d91"))
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
	status_style.bg_color = Color(1, 0.97, 0.88, 0.78)
	status_style.border_color = Color("#d5b168")
	status_style.set_border_width_all(2)
	status_style.set_corner_radius_all(18)
	status_panel.add_theme_stylebox_override("panel", status_style)
	content.add_child(status_panel)
	var status := Label.new()
	status.custom_minimum_size = Vector2(540, 48)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 23)
	status.add_theme_color_override("font_color", Color("#6e5878"))
	if claimable:
		status.text = "오늘은 %s를 받을 수 있어요." % _attendance_reward_sentence(main.save.get_attendance_next_reward())
	else:
		status.text = "오늘 선물을 받았어요. 내일 다시 만나요!"
	status_panel.add_child(status)
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 12)
	content.add_child(action_row)
	if claimable:
		var claim := _button("선물 받기  " + _attendance_reward_compact(main.save.get_attendance_next_reward()).replace("\n", "  "), Color("#f29b45"), Vector2(330, 70), 23)
		claim.pressed.connect(_claim_attendance)
		action_row.add_child(claim)
	var close := _button("닫기", Color("#806aa7"), Vector2(150, 70), 25)
	close.pressed.connect(_close_attendance_popup)
	action_row.add_child(close)


func _claim_attendance() -> void:
	var reward: Dictionary = main.save.claim_attendance()
	if reward.is_empty():
		return
	main.audio.play("shiny", 1.05)
	G.haptic(18)
	if stardust_label:
		stardust_label.text = "★ 별가루 %d" % main.save.get_stardust()
	_refresh_home_energy()
	_close_attendance_popup()
	_refresh_attendance_button()
	_show_toast("출석 완료!  " + _attendance_reward_sentence(reward))


func _close_attendance_popup() -> void:
	if attendance_popup and is_instance_valid(attendance_popup):
		attendance_popup.queue_free()
	attendance_popup = null


func _refresh_mission_button() -> void:
	if not mission_button:
		return
	var completed: int = main.save.get_daily_completed_count()
	if main.save.has_claimed_daily_mission_chest():
		mission_button.text = "✓ 완료"
	elif main.save.can_claim_daily_mission_chest():
		mission_button.text = "상자 받기!"
	else:
		mission_button.text = "구조 %d/3" % completed


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
	badge.text = "✓" if complete else str(progress)
	badge.custom_minimum_size = Vector2(50, 0)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 27)
	badge.add_theme_color_override("font_color", Color("#3a9c67") if complete else Color("#df7652"))
	row.add_child(badge)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	var title := Label.new()
	title.text = String(mission.get("title", "오늘의 구조"))
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("#543d65"))
	copy.add_child(title)
	var desc := Label.new()
	desc.text = String(mission.get("description", ""))
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Color("#8a728f"))
	copy.add_child(desc)
	var count := Label.new()
	count.text = "%d / %d" % [progress, target]
	count.custom_minimum_size = Vector2(82, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", 20)
	count.add_theme_color_override("font_color", Color("#3a9c67") if complete else Color("#7d6489"))
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
	if mission_popup and is_instance_valid(mission_popup):
		return
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.04, 0.15, 0.72)
	_fit_overlay_to_viewport(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 250
	ui_layer.add_child(dim)
	mission_popup = dim
	var card := PanelContainer.new()
	card.position = Vector2(55, 180)
	card.size = Vector2(610, 880)
	card.add_theme_stylebox_override("panel", _panel_style(Color("#fffaf3"), Color("#8b62bd"), 34))
	dim.add_child(card)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	card.add_child(content)
	var heading := Label.new()
	heading.text = "오늘의 젤리 구조"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 35)
	heading.add_theme_color_override("font_color", Color("#62407e"))
	content.add_child(heading)
	var sub := Label.new()
	sub.text = "매일 세 가지 부탁을 완료하고 구조 상자를 받아요!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", Color("#967da0"))
	content.add_child(sub)
	for mission in DailyMissionCatalogLib.missions():
		content.add_child(_mission_row(mission))
	var reward := DailyMissionCatalogLib.reward()
	var chest := _button("구조 상자  ★ %d  ♥ %d" % [int(reward.get("stardust", 0)), int(reward.get("energy", 0))], Color("#f09a42"), Vector2(420, 72), 22)
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
	chapter_title.text = "CHAPTER %d · %s" % [chapter + 1, Levels.CHAPTER_NAMES[chapter]]
	chapter_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter_title.add_theme_font_size_override("font_size", 24)
	chapter_title.add_theme_color_override("font_color", Levels.CHAPTER_COLORS[chapter].darkened(0.28))
	content.add_child(chapter_title)
	var track := ProgressBar.new()
	track.custom_minimum_size = Vector2(540, 34)
	track.max_value = 10
	track.value = int(chapter_data.cleared)
	track.show_percentage = false
	track.add_theme_stylebox_override("background", _panel_style(Color("#eadff0"), Color("#b79bc5"), 15))
	track.add_theme_stylebox_override("fill", _panel_style(Levels.CHAPTER_COLORS[chapter], Levels.CHAPTER_COLORS[chapter].darkened(0.25), 15))
	content.add_child(track)
	var track_copy := Label.new()
	track_copy.text = "%d / 10 구조 · 완주 보상: %s" % [int(chapter_data.cleared), String(reward_data.get("title", "기념 가구"))]
	track_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	track_copy.add_theme_font_size_override("font_size", 18)
	track_copy.add_theme_color_override("font_color", Color("#725a7d"))
	content.add_child(track_copy)
	var weekly: Dictionary = LiveProgressionCatalogLib.weekly()
	var weekly_parts: Array[String] = []
	for mission in weekly.get("missions", []):
		weekly_parts.append("%d/%d" % [main.save.get_weekly_progress(String(mission.get("id", ""))), int(mission.get("target", 0))])
	var weekly_button := _button("주간 작전  %s" % " · ".join(weekly_parts), Color("#4fa7b4"), Vector2(500, 57), 18)
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
		var season_button := _button("시즌 패스  ★ %d/%d" % [season_stars, next_milestone], Color("#8b64c4"), Vector2(500, 57), 18)
		season_button.disabled = season_stars < next_milestone
		season_button.pressed.connect(func(): _claim_season_reward(next_milestone))
		content.add_child(season_button)
	var close := _button("닫기", Color("#8065aa"), Vector2(210, 62), 22)
	close.pressed.connect(_close_daily_mission_popup)
	content.add_child(close)


func _claim_daily_mission_chest() -> void:
	var reward: Dictionary = main.save.claim_daily_mission_chest()
	if reward.is_empty():
		return
	G.haptic(24)
	_close_daily_mission_popup()
	if stardust_label:
		stardust_label.text = "★ 별가루 %d" % main.save.get_stardust()
	_refresh_home_energy()
	_refresh_mission_button()
	_show_toast("구조 상자 획득!  ★ %d  ♥ %d" % [int(reward.get("stardust", 0)), int(reward.get("energy", 0))])


func _close_daily_mission_popup() -> void:
	if mission_popup and is_instance_valid(mission_popup):
		mission_popup.queue_free()
	mission_popup = null


func _claim_weekly_reward() -> void:
	var reward: Dictionary = main.save.claim_weekly_reward()
	if reward.is_empty():
		return
	_close_daily_mission_popup()
	stardust_label.text = "★ 별가루 %d" % main.save.get_stardust()
	_show_toast("주간 구조 작전 완료!  ★ %d" % int(reward.get("stardust", 0)))
	_show_daily_mission_popup()


func _claim_season_reward(target: int) -> void:
	var reward: Dictionary = main.save.claim_season_milestone(target)
	if reward.is_empty():
		return
	_close_daily_mission_popup()
	stardust_label.text = "★ 별가루 %d" % main.save.get_stardust()
	_show_toast("시즌 ★ %d 보상 획득!" % target)
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
	name_label.text = String(entry.get("name", "???")) if discovered else "아직 만나지 못했어요"
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", Color("#523764") if discovered else Color("#837b89"))
	copy.add_child(name_label)
	var habitat := Label.new()
	habitat.text = String(entry.get("habitat", "")) if discovered else "모험에서 구조해 주세요"
	habitat.add_theme_font_size_override("font_size", 14)
	habitat.add_theme_color_override("font_color", Color("#8c718f"))
	copy.add_child(habitat)
	var count := Label.new()
	count.text = "구조 %d · %s" % [main.save.get_jelly_capture_count(color_id), "샤이니 발견" if main.save.has_discovered_shiny(color_id) else "샤이니 미발견"] if discovered else "???"
	count.add_theme_font_size_override("font_size", 14)
	count.add_theme_color_override("font_color", Color("#b35f75") if discovered else Color("#99929f"))
	copy.add_child(count)
	var personality := Label.new()
	personality.text = String(entry.get("personality", "")) if discovered else ""
	personality.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	personality.add_theme_font_size_override("font_size", 13)
	personality.add_theme_color_override("font_color", Color("#725c79"))
	copy.add_child(personality)
	return panel


func _show_jelly_dex() -> void:
	if dex_popup and is_instance_valid(dex_popup):
		return
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.04, 0.15, 0.74)
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
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	card.add_child(content)
	var title := Label.new()
	title.text = "젤리몬 구조 도감"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#603d79"))
	content.add_child(title)
	var status := Label.new()
	status.text = "발견 %d / %d · 초상화를 누르면 언제든 다시 볼 수 있어요" % [main.save.get_discovered_jelly_count(), JellyDexCatalogLib.entries().size()]
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 17)
	status.add_theme_color_override("font_color", Color("#907698"))
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
		var button := _button("%d종\n★ %d" % [needed, reward], Color("#5dbb82") if main.save.has_claimed_dex_milestone(needed) else Color("#e49a43"), Vector2(120, 70), 17)
		button.disabled = main.save.has_claimed_dex_milestone(needed) or main.save.get_discovered_jelly_count() < needed
		button.pressed.connect(func(): _claim_dex_reward(needed, reward))
		rewards.add_child(button)
	var close := _button("닫기", Color("#8065aa"), Vector2(220, 64), 23)
	close.pressed.connect(_close_jelly_dex)
	content.add_child(close)


func _claim_dex_reward(count: int, reward: int) -> void:
	if not main.save.claim_dex_milestone(count, reward):
		return
	_close_jelly_dex()
	if stardust_label:
		stardust_label.text = "★ 별가루 %d" % main.save.get_stardust()
	_show_toast("도감 %d종 보상!  ★ %d" % [count, reward])
	_show_jelly_dex()


func _close_jelly_dex() -> void:
	if dex_popup and is_instance_valid(dex_popup):
		dex_popup.queue_free()
	dex_popup = null


func _build_navigation() -> void:
	_build_next_adventure_card()
	nav_bar = PanelContainer.new()
	nav_bar.position = Vector2(20, 1080)
	nav_bar.size = Vector2(G.W - 40, 172)
	nav_bar.add_theme_stylebox_override("panel", _panel_style(Color("#fff9f4"), Color("#8b70a8"), 30))
	ui_layer.add_child(nav_bar)
	var buttons := GridContainer.new()
	buttons.columns = 4
	buttons.add_theme_constant_override("h_separation", 8)
	buttons.add_theme_constant_override("v_separation", 8)
	var button_center := CenterContainer.new()
	button_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nav_bar.add_child(button_center)
	button_center.add_child(buttons)
	var adventure := _nav_button("adventure", "모험", Color("#ed6c43"), 142)
	adventure.pressed.connect(func(): main.show_map())
	buttons.add_child(adventure)
	var decorate := _nav_button("decorate", "꾸미기", Color("#3f9dcc"), 142)
	decorate.pressed.connect(_enter_edit_mode)
	buttons.add_child(decorate)
	var shop := _nav_button("shop", "상점", Color("#8a5bc0"), 142)
	shop.pressed.connect(_show_shop_popup)
	buttons.add_child(shop)
	var menu := _nav_button("menu", "메뉴", Color("#cf668d"), 142)
	menu.pressed.connect(_show_home_menu)
	buttons.add_child(menu)


func _set_preference_switch_style(toggle: Button, enabled: bool, accent: Color) -> void:
	toggle.text = "ON   ●" if enabled else "●   OFF"
	var fill := accent if enabled else Color("#aaa1b6")
	var border := accent.darkened(0.28) if enabled else Color("#756b80")
	var normal := _panel_style(fill, border, 24)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 3)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = fill.lightened(0.08)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = fill.darkened(0.08)
	pressed.shadow_size = 1
	toggle.add_theme_stylebox_override("normal", normal)
	toggle.add_theme_stylebox_override("hover", hover)
	toggle.add_theme_stylebox_override("focus", hover)
	toggle.add_theme_stylebox_override("pressed", pressed)
	toggle.add_theme_color_override("font_color", Color.WHITE)
	toggle.add_theme_color_override("font_hover_color", Color.WHITE)
	toggle.add_theme_color_override("font_pressed_color", Color.WHITE)
	toggle.add_theme_color_override("font_outline_color", border.darkened(0.15))
	toggle.add_theme_constant_override("outline_size", 2)


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
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", Color("#624870"))
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


func _show_home_menu() -> void:
	if menu_popup and is_instance_valid(menu_popup):
		return
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.04, 0.15, 0.74)
	_fit_overlay_to_viewport(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 280
	ui_layer.add_child(dim)
	menu_popup = dim
	var card := PanelContainer.new()
	card.position = Vector2(48, 120)
	card.size = Vector2(624, 1085)
	var menu_style := _panel_style(Color("#eee2f6"), Color("#7954a3"), 34)
	menu_style.border_width_left = 6
	menu_style.border_width_top = 6
	menu_style.border_width_right = 6
	menu_style.border_width_bottom = 6
	menu_style.shadow_size = 22
	card.add_theme_stylebox_override("panel", menu_style)
	dim.add_child(card)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	card.add_child(content)
	var heading := Label.new()
	heading.text = "젤리 메뉴"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 35)
	heading.add_theme_color_override("font_color", Color("#5d3b78"))
	content.add_child(heading)
	var settings_title := Label.new()
	settings_title.text = "환경 설정"
	settings_title.add_theme_font_size_override("font_size", 23)
	settings_title.add_theme_color_override("font_color", Color("#d05f83"))
	content.add_child(settings_title)
	var settings_panel := PanelContainer.new()
	settings_panel.custom_minimum_size = Vector2(558, 232)
	settings_panel.add_theme_stylebox_override("panel", _panel_style(Color("#dfccef"), Color("#aa82c8"), 25))
	content.add_child(settings_panel)
	var settings_rows := VBoxContainer.new()
	settings_rows.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_rows.add_theme_constant_override("separation", 7)
	settings_panel.add_child(settings_rows)
	var sound_data := _preference_row("효과음", main.save.sound_enabled, Color("#e16388"))
	var haptics_data := _preference_row("진동", main.save.haptics_enabled, Color("#6f9ed7"))
	var notifications_data := _preference_row("알림", main.save.notifications_enabled, Color("#8c68c7"))
	var sound: Button = sound_data.toggle
	var haptics: Button = haptics_data.toggle
	var notifications: Button = notifications_data.toggle
	for data in [sound_data, haptics_data, notifications_data]:
		settings_rows.add_child(data.row)
		var toggle: Button = data.toggle
		toggle.toggled.connect(func(_enabled: bool):
			main.save.set_preferences(sound.button_pressed, haptics.button_pressed, notifications.button_pressed)
			main.audio.enabled = sound.button_pressed
			G.haptics_enabled = haptics.button_pressed
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
	account_status.text = main.platform.status_text() if main.platform else "플랫폼 연결 대기"
	account_status.custom_minimum_size = Vector2(320, 48)
	account_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	account_status.add_theme_font_size_override("font_size", 17)
	account_status.add_theme_color_override("font_color", Color("#77647f"))
	account_row.add_child(account_status)
	var service_detail := Label.new()
	service_detail.text = main.platform.service_detail_text() if main.platform else "플랫폼 서비스 준비 중"
	service_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	service_detail.add_theme_font_size_override("font_size", 14)
	service_detail.add_theme_color_override("font_color", Color("#765f86"))
	var login := _button("계정 연결", Color("#5a9bc0"), Vector2(160, 52), 18)
	login.disabled = main.platform.logged_in if main.platform else true
	login.pressed.connect(func():
		if not main.platform:
			return
		login.disabled = true
		login.text = "연결 중..."
		account_status.text = "HIVE 로그인 화면을 준비하고 있어요"
		var on_login_success := func(_logged_in: bool, _player_id: String):
			if is_instance_valid(account_status):
				account_status.text = main.platform.status_text()
			if is_instance_valid(service_detail):
				service_detail.text = main.platform.service_detail_text()
			if is_instance_valid(login):
				login.text = "연결 완료"
				login.disabled = true
		var on_login_failed := func(message: String):
			if is_instance_valid(account_status):
				account_status.text = message
			if is_instance_valid(login):
				login.text = "다시 연결"
				login.disabled = false
			if is_instance_valid(service_detail):
				service_detail.text = main.platform.service_detail_text()
		main.platform.login_changed.connect(on_login_success, CONNECT_ONE_SHOT)
		main.platform.login_failed.connect(on_login_failed, CONNECT_ONE_SHOT)
		if not main.platform.login():
			on_login_failed.call("로그인을 시작하지 못했습니다.")
	)
	account_row.add_child(login)
	account_box.add_child(service_detail)
	var divider := HSeparator.new()
	divider.custom_minimum_size.y = 5
	content.add_child(divider)
	var mail_title := Label.new()
	mail_title.text = "우편함"
	mail_title.add_theme_font_size_override("font_size", 23)
	mail_title.add_theme_color_override("font_color", Color("#d8873f"))
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
		mail_name.text = String(mail.get("title", "선물 우편"))
		mail_name.add_theme_font_size_override("font_size", 19)
		mail_name.add_theme_color_override("font_color", Color("#684653"))
		copy.add_child(mail_name)
		var mail_body := Label.new()
		mail_body.text = "%s  ·  ★ %d  ♥ %d" % [String(mail.get("body", "")), int(mail.get("stardust", 0)), int(mail.get("energy", 0))]
		mail_body.add_theme_font_size_override("font_size", 14)
		mail_body.add_theme_color_override("font_color", Color("#8b6a72"))
		mail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy.add_child(mail_body)
		var mail_id := String(mail.get("id", ""))
		var claimed: bool = main.save.has_claimed_mail(mail_id)
		var receive := _button("수령 완료" if claimed else "받기", Color("#76ae7d") if claimed else Color("#e98948"), Vector2(118, 58), 19)
		receive.disabled = claimed
		receive.pressed.connect(func(): _claim_home_mail(mail))
		row.add_child(receive)
		content.add_child(mail_row)
	var notice_title := Label.new()
	notice_title.text = "공지"
	notice_title.add_theme_font_size_override("font_size", 23)
	notice_title.add_theme_color_override("font_color", Color("#527fac"))
	content.add_child(notice_title)
	for notice in LiveMessageCatalogLib.notices():
		var notice_card := PanelContainer.new()
		notice_card.custom_minimum_size = Vector2(540, 94)
		notice_card.add_theme_stylebox_override("panel", _panel_style(Color("#edf5ff"), Color("#73a2c7"), 18))
		var notice_copy := VBoxContainer.new()
		notice_card.add_child(notice_copy)
		var notice_name := Label.new()
		notice_name.text = "%s  ·  %s" % [String(notice.get("title", "공지")), String(notice.get("date", ""))]
		notice_name.add_theme_font_size_override("font_size", 17)
		notice_name.add_theme_color_override("font_color", Color("#4e6381"))
		notice_copy.add_child(notice_name)
		var notice_body := Label.new()
		notice_body.text = String(notice.get("body", ""))
		notice_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		notice_body.add_theme_font_size_override("font_size", 14)
		notice_body.add_theme_color_override("font_color", Color("#758299"))
		notice_copy.add_child(notice_body)
		content.add_child(notice_card)
	var close := _button("닫기", Color("#8065aa"), Vector2(210, 60), 22)
	close.pressed.connect(_close_home_menu)
	content.add_child(close)


func _claim_home_mail(mail: Dictionary) -> void:
	if not main.save.claim_mail(mail):
		return
	G.haptic(20)
	_close_home_menu()
	if stardust_label:
		stardust_label.text = "★ 별가루 %d" % main.save.get_stardust()
	_refresh_home_energy()
	_show_toast("우편 선물 수령!  ★ %d  ♥ %d" % [int(mail.get("stardust", 0)), int(mail.get("energy", 0))])
	_show_home_menu()


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
		return "주민 6/6 · 모두 구조했어요"
	var target_level := count * 10 + 1
	return "다음 친구 · LEVEL %d에서 만나요" % target_level


func _growth_goal_text() -> String:
	var stage := RoomData.growth_stage(main.save)
	var stars := RoomData.total_stars(main.save)
	if stage >= RoomData.max_growth_stage():
		return "최종 성장 완료 · 별 %d" % stars
	var target := RoomData.next_growth_stars(stage)
	return "다음 성장까지 ★ %d" % maxi(0, target - stars)


func _build_next_adventure_card() -> void:
	var idx := _next_level_index()
	var level: Dictionary = Levels.get_level(idx)
	var chapter := clampi(idx / 10, 0, Levels.CHAPTER_NAMES.size() - 1)
	var card := PanelContainer.new()
	card.name = "NextAdventureCard"
	card.position = Vector2(20, 905)
	card.size = Vector2(G.W - 40, 158)
	card.add_theme_stylebox_override("panel", _panel_style(Color("#fffaf1"), Levels.CHAPTER_COLORS[chapter].darkened(0.2), 28))
	ui_layer.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var goal := VBoxContainer.new()
	goal.custom_minimum_size = Vector2(330, 0)
	goal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal.alignment = BoxContainer.ALIGNMENT_CENTER
	goal.add_theme_constant_override("separation", 1)
	row.add_child(goal)
	var eyebrow := Label.new()
	eyebrow.text = "CHAPTER %d · %s" % [chapter + 1, Levels.CHAPTER_NAMES[chapter]]
	eyebrow.add_theme_font_size_override("font_size", 17)
	eyebrow.add_theme_color_override("font_color", Levels.CHAPTER_COLORS[chapter].darkened(0.32))
	goal.add_child(eyebrow)
	var title := Label.new()
	title.text = "LEVEL %d  %s" % [idx + 1, String(level.get("name", "다음 구조"))]
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#4e345f"))
	goal.add_child(title)
	var growth := Label.new()
	growth.text = _growth_goal_text()
	growth.add_theme_font_size_override("font_size", 17)
	growth.add_theme_color_override("font_color", Color("#b66a35"))
	goal.add_child(growth)
	var resident := Label.new()
	resident.name = "ResidentInfo"
	resident.text = _next_resident_text()
	resident.add_theme_font_size_override("font_size", 16)
	resident.add_theme_color_override("font_color", Color("#735d80"))
	goal.add_child(resident)
	var play := _button("모험 시작", Color("#ed6c43"), Vector2(275, 104), 29)
	play.tooltip_text = "LEVEL %d 바로 시작" % (idx + 1)
	play.pressed.connect(func(): main.start_level(idx))
	row.add_child(play)


func _clear_layer(layer: Node) -> void:
	for child in layer.get_children():
		child.free()


func _refresh_room() -> void:
	_refresh_furniture()
	_refresh_characters()
	var info := ui_layer.get_node_or_null("ResidentInfo") as Label
	if info:
		info.text = _next_resident_text()


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
	var hero_size: float = minf(220.0, 146.0 + float(stage - 1) * 13.0)
	hero.scale = Vector2.ONE * hero_size / float(hero.texture.get_width())
	character_layer.add_child(hero)
	var bounce := hero.create_tween().set_loops()
	bounce.tween_property(hero, "scale", hero.scale * Vector2(1.04, 0.96), 0.8).set_trans(Tween.TRANS_SINE)
	bounce.tween_property(hero, "scale", hero.scale * Vector2(0.97, 1.04), 0.8).set_trans(Tween.TRANS_SINE)
	var growth_badge := RoomData.growth_badge(stage)
	if not growth_badge.is_empty():
		var badge := Label.new()
		badge.text = growth_badge
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
		character_layer.add_child(resident)
		resident_nodes.append(resident)
		resident_home_positions[resident.get_instance_id()] = resident.position
		_play_resident_idle(resident, String(record.get("trait", "kind")), i % 3)


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
	match variant_index % 3:
		0: # 인사 점프
			tw.tween_property(resident, "position", home + Vector2(0, -16 if trait_id == "energetic" else -10), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(resident, "position", home, 0.34).set_trans(Tween.TRANS_BOUNCE)
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
	bubble.text = text
	bubble.position = position_at - Vector2(105, 78)
	bubble.size = Vector2(210, 58)
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.add_theme_font_size_override("font_size", 15)
	bubble.add_theme_color_override("font_color", Color("#563d67"))
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
		_play_resident_idle(solo, String((solo.get_meta("record") as Dictionary).get("trait", "kind")), randi_range(0, 2))
		return
	if resident_nodes.size() == 1:
		var only: Sprite2D = resident_nodes[0]
		var record: Dictionary = only.get_meta("record")
		_speech_bubble(String(CharacterCatalog.profile(String(record.color)).get("greeting", "말랑!")), only.position)
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
		if traits.is_empty() or (traits.has(String(a.trait)) and traits.has(String(b.trait))):
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
	_speech_bubble(String(chosen.get("text", "친구와 함께 놀아요!")), midpoint)
	main.save.record_resident_interaction(String(a.id), String(b.id), String(chosen.get("id", "greeting")))
	main.save.add_album_memory("interaction", String(chosen.get("text", "친구와 함께 놀아요!")), [String(a.id), String(b.id)])


func _play_furniture_behavior() -> void:
	var resident: Sprite2D = resident_nodes.pick_random()
	var record: Dictionary = resident.get_meta("record")
	var favorite := String(record.get("favorite_furniture", ""))
	var furniture: RoomFurniture = null
	for candidate in furniture_nodes:
		if favorite != "" and String(candidate.item.get("id", "")) == favorite:
			furniture = candidate
			break
	if furniture == null:
		furniture = furniture_nodes.pick_random()
	var item_id := String(furniture.item.get("id", "furniture"))
	var item_name := String(furniture.item.get("name", "가구"))
	var lines := {
		"cushion_r": "폭신폭신, 구름 같아!",
		"lamp_y": "별빛을 세어 볼까?",
		"table_b": "소다 한 모금, 톡톡!",
		"shelf_g": "새싹에게 인사했어!",
		"sofa_p": "소파에서 말랑 휴식!",
		"bench_o": "귤 향기가 솔솔 나!",
		"ach_first": "우리의 첫 만남이야!",
	}
	var line := String(lines.get(item_id, "%s이(가) 마음에 들어!" % item_name))
	var home: Vector2 = resident_home_positions.get(resident.get_instance_id(), resident.position)
	var destination := furniture.interaction_point() + Vector2(0, 42)
	var tw := resident.create_tween()
	tw.tween_property(resident, "position", destination, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(resident, "rotation", 0.12, 0.16)
	tw.tween_property(resident, "rotation", -0.12, 0.16)
	tw.tween_property(resident, "rotation", 0.0, 0.14)
	tw.tween_interval(1.25)
	tw.tween_property(resident, "position", home, 0.48).set_trans(Tween.TRANS_SINE)
	_speech_bubble(line, destination)
	var bond_gain: Dictionary = main.save.add_resident_affection(String(record.get("id", "")), 1)
	_record_bond_analytics(record, bond_gain)
	main.save.add_album_memory("furniture", line, [String(record.get("id", "")), item_id])


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
	if palette:
		palette.free()
	palette = PanelContainer.new()
	# 꾸미기 중에는 모험 카드를 숨겨 편집 공간과 도구 패널의 시각적 간격을 확보한다.
	# 도구 행과 가구 목록 사이에도 충분한 내부 여백을 둔다.
	var palette_height := 225.0
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
	guide.text = "가구 배치"
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	guide.add_theme_font_size_override("font_size", 21)
	guide.add_theme_color_override("font_color", Color("#634d72"))
	tools.add_child(guide)
	var rotate := _button("회전", Color("#6daed5"), Vector2(70, 54), 18)
	rotate.disabled = selected_index < 0
	rotate.pressed.connect(_rotate_selected)
	tools.add_child(rotate)
	var remove := _button("치우기", Color("#b883a5"), Vector2(78, 54), 17)
	remove.disabled = selected_index < 0
	remove.pressed.connect(_remove_selected)
	tools.add_child(remove)
	var album := _button("앨범", Color("#7454aa"), Vector2(78, 54), 18)
	album.pressed.connect(_show_album)
	tools.add_child(album)
	var photo := _button("촬영", Color("#d65e91"), Vector2(78, 54), 18)
	photo.pressed.connect(_enter_photo_mode)
	tools.add_child(photo)
	var done := _button("완료", Color("#65bd77"), Vector2(70, 54), 19)
	done.pressed.connect(_leave_edit_mode)
	tools.add_child(done)
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
		var label := String(item.name)
		var button := _button(label, Color(String(item.color)) if unlocked else Color("#aaa1b3"), Vector2(126, 100), 18)
		# 아이템 위에서 시작한 터치도 부모 ScrollContainer로 전달한다.
		# ScrollContainer가 deadzone을 넘으면 버튼 클릭을 취소하고 좌우 드래그로 전환한다.
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.mouse_force_pass_scroll_events = true
		button.disabled = not unlocked or already_placed
		if already_placed:
			_mark_furniture_placed(button, Color(String(item.color)))
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
				_refresh_furniture()
				_build_palette()
				return
	_show_toast("놓을 공간이 부족해요")


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
		_show_toast("회전할 공간이 없어요")


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
				_resident_touch_react(resident)
				touched_resident = true
				break
		if not touched_resident and event.position.distance_to(Vector2(360, 615 + RoomData.SCREEN_Y_OFFSET)) < 125:
			_hero_react()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for resident in resident_nodes:
			if is_instance_valid(resident) and event.position.distance_to(resident.global_position) < 58:
				_resident_touch_react(resident)
				return


func _resident_touch_react(resident: Sprite2D) -> void:
	var record: Dictionary = resident.get_meta("record")
	var profile := CharacterCatalog.profile(String(record.get("color", "R")))
	var reactions: Array = profile.get("touch", ["smile"])
	var reaction := String(reactions[randi() % reactions.size()])
	var home: Vector2 = resident.position
	var tw := resident.create_tween()
	if reaction in ["startle", "surprise", "peek"]:
		tw.tween_property(resident, "scale", resident.scale * 1.22, 0.12).set_trans(Tween.TRANS_BACK)
		tw.tween_property(resident, "scale", resident.scale, 0.25).set_trans(Tween.TRANS_BOUNCE)
	else:
		tw.tween_property(resident, "position", home + Vector2(0, -25), 0.16).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(resident, "position", home, 0.28).set_trans(Tween.TRANS_BOUNCE)
	_speech_bubble(String(profile.get("greeting", "반가워요!")), resident.position)
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
	var start := hero.position
	var tw := hero.create_tween()
	tw.tween_property(hero, "position", start + Vector2(0, -34), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(hero, "position", start, 0.28).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var hero_half_height := 80.0
	if hero.texture:
		hero_half_height = float(hero.texture.get_height()) * absf(hero.scale.y) * 0.5
	var speech_anchor := start - Vector2(0, hero_half_height + 14.0)
	_speech_bubble(["말랑!", "오늘도 같이 모험해요!", "방이 정말 포근해요!"][randi() % 3], speech_anchor)


func _show_album() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.16, 0.62)
	_fit_overlay_to_viewport(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 30
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(610, 930)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#fffaf4"), Color("#80639d"), 32))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "젤리 아지트 앨범"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("#674779"))
	box.add_child(title)
	var residents: Array = main.save.get_resident_records()
	var resident_names: Array[String] = []
	for resident in residents:
		var bond: Dictionary = main.save.get_resident_bond_progress(resident)
		resident_names.append("%s Lv.%d" % [String(resident.get("name", "젤리몬")), int(bond.level)])
	var resident_text := " · ".join(resident_names) if not residents.is_empty() else "아직 초대한 주민이 없어요"
	var resident_label := Label.new()
	resident_label.text = "구출 주민 %d/6\n%s" % [residents.size(), resident_text]
	resident_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resident_label.add_theme_font_size_override("font_size", 24)
	resident_label.add_theme_color_override("font_color", Color("#7c657f"))
	box.add_child(resident_label)
	if not residents.is_empty():
		var bond_summary := Label.new()
		var bond_lines: Array[String] = []
		for resident in residents:
			var bond: Dictionary = main.save.get_resident_bond_progress(resident)
			var progress_text := "MAX" if bool(bond.maxed) else "%d/%d" % [int(bond.affection), int(bond.next_affection)]
			bond_lines.append("%s · %s · %s" % [String(resident.get("name", "젤리몬")), String(bond.title), progress_text])
		bond_summary.text = "친밀도\n" + "\n".join(bond_lines)
		bond_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bond_summary.add_theme_font_size_override("font_size", 18)
		bond_summary.add_theme_color_override("font_color", Color("#8b5d8d"))
		box.add_child(bond_summary)
	var memory_title := Label.new()
	memory_title.text = "최근 말랑 추억"
	memory_title.add_theme_font_size_override("font_size", 22)
	memory_title.add_theme_color_override("font_color", Color("#d06f91"))
	box.add_child(memory_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(540, 0)
	list.add_theme_constant_override("separation", 7)
	scroll.add_child(list)
	for memory in main.save.album_memories.slice(0, 6):
		var memory_row := Label.new()
		memory_row.text = "♥  " + String(memory.get("caption", "함께 보낸 포근한 순간"))
		memory_row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		memory_row.add_theme_font_size_override("font_size", 18)
		memory_row.add_theme_color_override("font_color", Color("#9c5f7a"))
		list.add_child(memory_row)
	for i in range(RoomData.ACHIEVEMENT_NAMES.size()):
		var unlocked := RoomData.achievement_unlocked(i, main.save)
		var row := Label.new()
		row.text = ("✓  " if unlocked else "○  ") + RoomData.ACHIEVEMENT_NAMES[i] + ("  · 달성" if unlocked else "")
		row.add_theme_font_size_override("font_size", 23)
		row.add_theme_color_override("font_color", Color("#6bac79") if unlocked else Color("#9b929f"))
		list.add_child(row)
	var close := _button("닫기", Color("#8d72bd"), Vector2(260, 68), 26)
	close.pressed.connect(dim.queue_free)
	box.add_child(close)


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
	title.text = "PHOTO  ·  MY JELLY HIDEOUT"
	title.position = Vector2(60, 45)
	title.size = Vector2(600, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color("#684c7c"))
	title.add_theme_constant_override("outline_size", 6)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo_layer.add_child(title)
	var controls := HBoxContainer.new()
	controls.position = Vector2(65, 1150)
	controls.add_theme_constant_override("separation", 16)
	photo_layer.add_child(controls)
	var pose := _button("포즈", Color("#66a9d8"), Vector2(160, 78), 24)
	pose.pressed.connect(_photo_pose)
	controls.add_child(pose)
	var save_button := _button("사진 저장", Color("#e580a7"), Vector2(190, 78), 27)
	save_button.pressed.connect(_save_photo)
	controls.add_child(save_button)
	var close := _button("닫기", Color("#7d6a9e"), Vector2(190, 78), 27)
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
	_speech_bubble("다 같이 말랑~!", center - Vector2(0, 95))
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
	_show_toast("사진을 저장했어요!\n%s" % folder if error == OK else "사진 저장에 실패했어요")


func _show_toast(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(110, 960)
	label.size = Vector2(500, 80)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color("#5f456e"))
	label.add_theme_constant_override("outline_size", 9)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 80
	add_child(label)
	var tw := label.create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(label, "modulate:a", 0.0, 0.35)
	tw.tween_callback(label.queue_free)
