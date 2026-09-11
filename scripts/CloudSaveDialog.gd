extends ColorRect
const L10n = preload("res://scripts/LocalizedText.gd")
signal selected(use_cloud: bool)
var local_data: Dictionary
var remote_data: Dictionary
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = ArtDirection.dim_color()
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 450
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 620
	panel.add_theme_stylebox_override("panel", ArtDirection.panel(ArtDirection.panel_color(), ArtDirection.border_color(), 28))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var title := Label.new()
	title.text = L10n.text("저장 데이터 선택")
	title.add_theme_color_override("font_color", ArtDirection.ink())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	var copy := Label.new()
	copy.custom_minimum_size.x = 560
	copy.add_theme_color_override("font_color", ArtDirection.ink())
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_theme_font_size_override("font_size", 21)
	copy.text = L10n.text("기기와 클라우드의 데이터가 다릅니다. 사용할 데이터를 선택해 주세요. 선택하지 않은 쪽의 진행도와 재화는 덮어쓰게 됩니다.\n\n기기: %s\n클리어 %d개 · 별가루 %d\n\n클라우드: %s\n클리어 %d개 · 별가루 %d") % [local_data.nickname, local_data.stars.size(), local_data.stardust, remote_data.nickname, remote_data.stars.size(), remote_data.stardust]
	box.add_child(copy)
	for option in [{"label": "클라우드 사용", "action": "cloud"}, {"label": "기기 데이터 사용", "action": "device"}, {"label": "나중에", "action": "cancel"}]:
		var button := Button.new()
		button.text = L10n.text(option.label)
		button.custom_minimum_size.y = 60
		button.add_theme_font_size_override("font_size", 22)
		ArtDirection.apply_button(button, ArtDirection.panel_color())
		box.add_child(button)
		button.pressed.connect(func():
			if option.action != "cancel": selected.emit(option.action == "cloud")
			queue_free()
		)
