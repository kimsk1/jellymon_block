extends ColorRect
## Confirmation only. The owner performs the selected reset after confirmed.
signal confirmed
const CONFIRMATION := "DELETE ACCOUNT"
var input: LineEdit
var confirm_button: Button
var status: Label
var scope_text := ""
var heading_text := "계정 초기화"
var action_text := "초기화"
var busy := false

static func accepts_confirmation(value: String) -> bool:
	return value == CONFIRMATION

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = ArtDirection.dim_color()
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 400
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	panel.add_theme_stylebox_override("panel", ArtDirection.panel(ArtDirection.panel_color(), ArtDirection.border_color(), 28))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var heading := Label.new()
	heading.text = heading_text
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	box.add_child(heading)
	var explanation := Label.new()
	explanation.custom_minimum_size.x = 560
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.text = scope_text + "\n\n초기화하려면 아래 문구를 대문자와 공백까지 정확히 입력해 주세요."
	explanation.add_theme_font_size_override("font_size", 21)
	box.add_child(explanation)
	var phrase := Label.new()
	phrase.text = CONFIRMATION
	phrase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phrase.add_theme_font_size_override("font_size", 27)
	box.add_child(phrase)
	input = LineEdit.new()
	input.name = "ResetConfirmationInput"
	input.placeholder_text = CONFIRMATION
	input.custom_minimum_size.y = 64
	input.add_theme_font_size_override("font_size", 25)
	input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	box.add_child(input)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 18)
	box.add_child(status)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	box.add_child(actions)
	var cancel := Button.new()
	cancel.text = "취소"
	cancel.custom_minimum_size = Vector2(260, 66)
	ArtDirection.apply_button(cancel, ArtDirection.panel_color())
	cancel.pressed.connect(func():
		if not busy: queue_free()
	)
	actions.add_child(cancel)
	confirm_button = Button.new()
	confirm_button.name = "ResetConfirmButton"
	confirm_button.text = action_text
	confirm_button.custom_minimum_size = Vector2(260, 66)
	ArtDirection.apply_button(confirm_button, ArtDirection.danger_color())
	confirm_button.disabled = true
	actions.add_child(confirm_button)
	input.text_changed.connect(func(value: String):
		confirm_button.disabled = busy or not accepts_confirmation(value)
	)
	confirm_button.pressed.connect(_confirm)

func _confirm() -> void:
	# Check again at the action boundary; disabling the button alone is insufficient.
	if busy or not accepts_confirmation(input.text):
		return
	busy = true
	input.editable = false
	confirm_button.disabled = true
	status.text = "초기화 중..."
	confirmed.emit()

func show_error(message: String) -> void:
	busy = false
	input.editable = true
	confirm_button.disabled = not accepts_confirmation(input.text)
	status.text = message
