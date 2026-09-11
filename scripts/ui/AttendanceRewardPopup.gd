extends ColorRect
## 지급이 끝난 출석 보상만 표시한다. 보상 지급/저장은 호출자가 담당한다.
signal confirmed

var reward: Dictionary = {}
var _confirmed := false

func _ready() -> void:
	name = "AttendanceRewardPopup"
	color = ArtDirection.dim_color()
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 90
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "RewardCard"
	panel.custom_minimum_size = Vector2(560, 0)
	var style := ArtDirection.panel(ArtDirection.panel_color(), ArtDirection.border_color(), 30)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)
	content.add_child(_label(tr("출석 완료!"), 36))
	content.add_child(_label(tr("오늘의 선물을 받았어요!"), 23))
	for item in ["stardust", "energy"]:
		var amount := int(reward.get(item, 0))
		if amount <= 0:
			continue
		var tile := PanelContainer.new()
		tile.name = "Reward_" + item
		tile.custom_minimum_size.y = 100
		var tile_style := ArtDirection.panel(ArtDirection.selected_color(), ArtDirection.border_color(), 20)
		tile.add_theme_stylebox_override("panel", tile_style)
		content.add_child(tile)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		tile.add_child(row)
		if item == "stardust":
			var icon := TextureRect.new()
			icon.texture = preload("res://assets/fx/ui_star.png")
			icon.custom_minimum_size = Vector2(64, 64)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon)
		else:
			var icon := _label("♥", 48)
			icon.custom_minimum_size.x = 64
			icon.add_theme_color_override("font_color", ArtDirection.danger_color())
			row.add_child(icon)
		var item_label := _label(tr("별가루") if item == "stardust" else tr("하트"), 27)
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(item_label)
		var count := _label("+%d" % amount, 32)
		count.name = "Amount"
		count.custom_minimum_size.x = 86
		row.add_child(count)
	var confirm := Button.new()
	confirm.name = "ConfirmReward"
	confirm.text = tr("확인")
	confirm.custom_minimum_size.y = 70
	confirm.add_theme_font_size_override("font_size", 27)
	ArtDirection.apply_button(confirm, ArtDirection.primary_color(), 20)
	confirm.pressed.connect(_confirm)
	content.add_child(confirm)
	confirm.grab_focus()

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ArtDirection.ink())
	return label

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_confirm()

func _confirm() -> void:
	if _confirmed:
		return
	_confirmed = true
	confirmed.emit()
