extends Control
var main: Node
var _list: VBoxContainer
var _status: Label
var _mine: Label
var _refresh: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = ArtDirection.panel_color().darkened(0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 28)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	margin.add_child(body)
	var nav := HBoxContainer.new()
	body.add_child(nav)
	var back := _button("‹ 지도", 95)
	back.pressed.connect(func(): main.show_map(true))
	nav.add_child(back)
	var title := _label("모험 랭킹", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav.add_child(title)
	_refresh = _button("새로고침", 115)
	_refresh.pressed.connect(func(): main.ranking.refresh())
	nav.add_child(_refresh)
	var intro := PanelContainer.new()
	intro.add_theme_stylebox_override("panel", ArtDirection.panel(ArtDirection.panel_color(), ArtDirection.border_color(), 24))
	body.add_child(intro)
	var intro_box := VBoxContainer.new()
	intro_box.add_theme_constant_override("separation", 8)
	intro.add_child(intro_box)
	var stars := _label("★★★  TOP 100", 34)
	stars.add_theme_color_override("font_color", ArtDirection.primary_color())
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_box.add_child(stars)
	var rule := _label("별 3개로 깬 최고 레벨 순\n같은 레벨이면 먼저 달성한 유저가 앞서요", 20)
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_box.add_child(rule)
	_mine = _label("", 18)
	_mine.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mine.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_box.add_child(_mine)
	_status = _label("", 18)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_status)
	var header := HBoxContainer.new()
	body.add_child(header)
	for item in [["순위", 56], ["유저", 0], ["레벨", 95], ["최초 달성", 180]]:
		var label := _label(item[0], 18)
		label.custom_minimum_size.x = item[1]
		if item[1] == 0: label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_child(label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	var note := _label("별 1·2개 기록은 제외 · 달성 시각은 한국시간 (UTC+9)\n기존 기록의 달성 시각이 없으면 별 3개로 다시 클리어해 주세요.", 16)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(note)
	main.ranking.changed.connect(_render)
	_render()
	main.ranking.refresh()

func _render() -> void:
	_status.text = main.ranking.status.replace("기기 시간대 기준", "한국시간 기준")
	_refresh.disabled = main.ranking.loading
	var record: Dictionary = main.save.three_star_ranking_record()
	_mine.text = "내 별 3개 기록: LEVEL %d" % int(record.level) if not record.is_empty() else "아직 등록할 별 3개 달성 기록이 없어요"
	if not main.ranking.submit_status.is_empty(): _mine.text += "\n" + main.ranking.submit_status
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var index := 0
	for row in main.ranking.entries:
		index += 1
		var panel := PanelContainer.new()
		var mine: bool = main.platform.logged_in and String(row.player_id) == main.platform.player_id
		panel.custom_minimum_size.y = 82
		panel.add_theme_stylebox_override("panel", ArtDirection.surface(ArtDirection.selected_color() if mine else ArtDirection.panel_color(), 18))
		_list.add_child(panel)
		var columns := HBoxContainer.new()
		columns.add_theme_constant_override("separation", 8)
		panel.add_child(columns)
		var date := Time.get_datetime_string_from_unix_time(int(row.achieved_at_ms) / 1000 + 9 * 3600).replace("T", "\n") + ".%03d" % (int(row.achieved_at_ms) % 1000)
		var items := [[str(index), 56, 26], [String(row.get("nickname", "구조 대원")) + (" · 나" if mine else ""), 0, 22], [str(int(row.level)) + "\n★★★", 83, 21], [date, 166, 17]]
		for item in items:
			var label := _label(item[0], item[2])
			label.custom_minimum_size.x = item[1]
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if item[1] == 0:
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			columns.add_child(label)

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ArtDirection.ink())
	return label

func _button(text: String, width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 52)
	button.add_theme_font_size_override("font_size", 18)
	ArtDirection.apply_button(button, ArtDirection.primary_color(), 18)
	return button
