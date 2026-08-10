extends Control
class_name Title
## 메인 화면 = 플레이 기록이 살아 움직이는 '젤리 아지트'.

const FurnitureRewards = preload("res://scripts/FurnitureRewardCatalog.gd")

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


func _nav_button(icon_text: String, title_text: String, color: Color, width: float = 150.0) -> Button:
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
	var icon := Label.new()
	icon.text = icon_text
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.add_theme_font_size_override("font_size", 27)
	icon.add_theme_color_override("font_color", Color.WHITE)
	icon.add_theme_color_override("font_outline_color", color.darkened(0.42))
	icon.add_theme_constant_override("outline_size", 4)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	progress.text = "%s · 성장 별 %d / %d" % [RoomData.growth_name(stage), stars, RoomData.next_growth_stars(stage)] if stage < 3 else "%s · 별 %d" % [RoomData.growth_name(stage), stars]
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
	attendance_button = _button("🎁 출석", Color("#8c63c7"), Vector2(195, 43), 17)
	attendance_button.position = Vector2(505, 132)
	attendance_button.size = Vector2(195, 43)
	attendance_button.pressed.connect(_show_attendance_popup)
	ui_layer.add_child(attendance_button)
	_refresh_home_energy()
	_refresh_attendance_button()


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
		attendance_button.text = "🎁 %d주차 · %d일차" % [week, claimed + 1]
	else:
		attendance_button.text = "✓ %d주차 %d/7 · 내일" % [week, claimed]


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
			return
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
		return
	if not main.save.apply_verified_shop_item(item):
		shop_status_label.text = "이미 구매했거나 지급할 수 없는 상품이에요."
		return
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


func _build_navigation() -> void:
	var resident_info := Label.new()
	resident_info.name = "ResidentInfo"
	resident_info.position = Vector2(30, 925)
	resident_info.size = Vector2(G.W - 60, 55)
	resident_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resident_info.add_theme_font_size_override("font_size", 25)
	resident_info.add_theme_color_override("font_color", Color("#684f78"))
	resident_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(resident_info)
	nav_bar = PanelContainer.new()
	nav_bar.position = Vector2(20, 1080)
	nav_bar.size = Vector2(G.W - 40, 172)
	nav_bar.add_theme_stylebox_override("panel", _panel_style(Color("#fff9f4"), Color("#8b70a8"), 30))
	ui_layer.add_child(nav_bar)
	var buttons := GridContainer.new()
	buttons.columns = 3
	buttons.add_theme_constant_override("h_separation", 10)
	buttons.add_theme_constant_override("v_separation", 8)
	var button_center := CenterContainer.new()
	button_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nav_bar.add_child(button_center)
	button_center.add_child(buttons)
	var adventure := _nav_button("▶", "모험", Color("#ed6c43"), 190)
	adventure.pressed.connect(func(): main.show_map())
	buttons.add_child(adventure)
	var decorate := _nav_button("▦", "꾸미기", Color("#3f9dcc"), 190)
	decorate.pressed.connect(_enter_edit_mode)
	buttons.add_child(decorate)
	var shop := _nav_button("★", "상점", Color("#8a5bc0"), 190)
	shop.pressed.connect(_show_shop_popup)
	buttons.add_child(shop)


func _clear_layer(layer: Node) -> void:
	for child in layer.get_children():
		child.free()


func _refresh_room() -> void:
	_refresh_furniture()
	_refresh_characters()
	var info := ui_layer.get_node_or_null("ResidentInfo") as Label
	if info:
		var residents: Array[String] = main.save.get_rescued_jellies()
		info.text = "구출 주민 %d/5 · 스테이지를 처음 클리어하면 새 친구가 찾아와요" % residents.size()


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
	var stage := RoomData.growth_stage(main.save)
	var aura := Sprite2D.new()
	aura.texture = load("res://assets/fx/soft.png")
	aura.position = Vector2(360, 610)
	var aura_size := 210.0 + stage * 42.0
	aura.scale = Vector2.ONE * aura_size / float(aura.texture.get_width())
	aura.modulate = Color(1.0, 0.72, 0.88, 0.24 + stage * 0.08)
	character_layer.add_child(aura)
	var hero := Sprite2D.new()
	hero.name = "Hero"
	hero.texture = G.hero_tex()
	hero.position = Vector2(360, 615)
	var hero_size: float = [0.0, 148.0, 182.0, 220.0][stage]
	hero.scale = Vector2.ONE * hero_size / float(hero.texture.get_width())
	character_layer.add_child(hero)
	var bounce := hero.create_tween().set_loops()
	bounce.tween_property(hero, "scale", hero.scale * Vector2(1.04, 0.96), 0.8).set_trans(Tween.TRANS_SINE)
	bounce.tween_property(hero, "scale", hero.scale * Vector2(0.97, 1.04), 0.8).set_trans(Tween.TRANS_SINE)
	if stage >= 2:
		var badge := Label.new()
		badge.text = "✦" if stage == 2 else "♛"
		badge.position = Vector2(329, 475 if stage == 3 else 500)
		badge.size = Vector2(64, 64)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 48)
		badge.add_theme_color_override("font_color", Color("#ffd75e"))
		badge.add_theme_color_override("font_outline_color", Color("#8a547f"))
		badge.add_theme_constant_override("outline_size", 6)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		character_layer.add_child(badge)
	var spots := [Vector2(222, 565), Vector2(500, 545), Vector2(190, 742), Vector2(530, 728), Vector2(360, 785)]
	var residents: Array[String] = main.save.get_rescued_jellies()
	for i in range(mini(5, residents.size())):
		var resident := Sprite2D.new()
		resident.texture = G.hero_tex() if residents[i] == "R" else G.jelly_tex(residents[i])
		resident.position = spots[i]
		resident.scale = Vector2.ONE * 82.0 / float(resident.texture.get_width())
		resident.z_index = 2 + i
		character_layer.add_child(resident)
		var home := resident.position
		var move := resident.create_tween().set_loops()
		move.tween_interval(i * 0.15)
		move.tween_property(resident, "position", home + Vector2(13 if i % 2 else -13, -12), 0.65).set_trans(Tween.TRANS_SINE)
		move.tween_property(resident, "position", home + Vector2(-10 if i % 2 else 10, 2), 0.75).set_trans(Tween.TRANS_SINE)


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
	main.save.set_room_placements(placements)
	_refresh_furniture()


func _build_palette() -> void:
	if palette:
		palette.free()
	palette = PanelContainer.new()
	# 메인 내비게이션과 동일하게 좌우 20px, 아래 28px의 하단 고정 영역을 사용한다.
	var palette_height := 205.0
	palette.position = Vector2(20, G.H - 28.0 - palette_height)
	palette.size = Vector2(G.W - 40, palette_height)
	palette.add_theme_stylebox_override("panel", _panel_style(Color("#fffaf5"), Color("#81659f"), 26))
	ui_layer.add_child(palette)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
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
	scroll.custom_minimum_size = Vector2(0, 116)
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
		if event.position.distance_to(Vector2(360, 615 + RoomData.SCREEN_Y_OFFSET)) < 125:
			_hero_react()


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
	_show_toast(["말랑!", "오늘도 같이 모험해요!", "방이 정말 포근해요!"][randi() % 3])


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
	var residents: Array[String] = main.save.get_rescued_jellies()
	var resident_text := " · ".join(residents.map(func(c): return G.COLOR_NAMES[c])) if not residents.is_empty() else "아직 초대한 주민이 없어요"
	var resident_label := Label.new()
	resident_label.text = "구출 주민 %d/5\n%s" % [residents.size(), resident_text]
	resident_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resident_label.add_theme_font_size_override("font_size", 24)
	resident_label.add_theme_color_override("font_color", Color("#7c657f"))
	box.add_child(resident_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(540, 0)
	list.add_theme_constant_override("separation", 7)
	scroll.add_child(list)
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
	controls.position = Vector2(170, 1150)
	controls.add_theme_constant_override("separation", 16)
	photo_layer.add_child(controls)
	var save_button := _button("사진 저장", Color("#e580a7"), Vector2(190, 78), 27)
	save_button.pressed.connect(_save_photo)
	controls.add_child(save_button)
	var close := _button("닫기", Color("#7d6a9e"), Vector2(190, 78), 27)
	close.pressed.connect(_leave_photo_mode)
	controls.add_child(close)


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
