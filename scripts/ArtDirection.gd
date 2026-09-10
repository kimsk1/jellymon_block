class_name ArtDirection
## 젤리몬 전 화면이 공유하는 A/B/D 테마 디자인 토큰과 스타일 팩토리.

const INK := Color("#765338")
const CREAM := Color("#fff7e9")
const CORAL := Color("#f58f7d")
const CYAN := Color("#31bfe8")
const GOLD := Color("#ffc83d")
const VIOLET := Color("#7b55c7")
const MINT := Color("#4fd18b")
const NAVY := Color("#16213f")

const CHAPTER_TINTS := [
	Color("#fff0ec"), Color("#eaffdd"), Color("#e1f6ff"), Color("#eff0ff"),
	Color("#fff0d7"), Color("#e7faff"), Color("#fff0dc"), Color("#f0e6ff"),
	Color("#e3fff2"), Color("#fff0f4"),
	Color("#fdeef6"), Color("#f1f9e4"), Color("#fdf3e0"), Color("#e6f8f1"), Color("#eef3fd"),
	Color("#e6f4fd"), Color("#fbf0e2"), Color("#e8fbf2"), Color("#ffeef0"), Color("#f4edfd"),
	Color("#fdeff5"), Color("#fbf4e1"), Color("#faf1e6"), Color("#e9f6fc"), Color("#fdf1ea"),
	Color("#fdf8e2"), Color("#f2ecfd"), Color("#fdf0e8"), Color("#e9f1fc"), Color("#fdf6e0"),
	Color("#eef1fd"), Color("#eeecfb"), Color("#f8eefc"), Color("#e8f5fb"), Color("#eaf8f3"),
	Color("#ebf2fd"), Color("#e9f8fc"), Color("#f1ecfc"), Color("#eaf8f0"), Color("#e9f2fc"),
	Color("#faf2e3"), Color("#f1f8e6"), Color("#e8f2fb"), Color("#efecf7"), Color("#eff5f9"),
	Color("#fdeee9"), Color("#f0ecfa"), Color("#fdf7e3"), Color("#f6ecfb"), Color("#fbf3e0"),
]


static func background_texture() -> Texture2D:
	return load("res://assets/backgrounds/jelly_village_premium_v1.png")


static func chapter_tint(level_index: int) -> Color:
	return CHAPTER_TINTS[clampi(level_index / 10, 0, CHAPTER_TINTS.size() - 1)]


const BORDER := Color("#dfc7a9")
const CANVAS := Color("#f5ecd9")
const MUTED := Color("#8b705a")
const SELECTED := Color("#d4eee2")
const SUCCESS_INK := Color("#285d4a")
const DISABLED := Color("#e9e0d4")
const DANGER := Color("#ad453d")
const DIM := Color(0.24, 0.17, 0.12, 0.48)


static var active_room_theme := "b"

static func set_room_theme(id: String) -> void:
	var valid := id if id in ["a", "b", "d"] else "b"
	if active_room_theme != valid:
		active_room_theme = valid
		_shared_theme = null

static func is_botanical() -> bool:
	return active_room_theme == "b"

static func is_night() -> bool:
	return active_room_theme == "d"

static func ink() -> Color:
	return Color("#f6e3bd") if is_night() else INK

static func panel_color() -> Color:
	return Color("#463044") if is_night() else CREAM

static func border_color() -> Color:
	return Color("#75566d") if is_night() else BORDER

static func muted_color() -> Color:
	return Color("#c4acc0") if is_night() else MUTED

static func selected_color() -> Color:
	return Color("#72516d") if is_night() else SELECTED

static func disabled_color() -> Color:
	return Color("#352736") if is_night() else DISABLED

static func success_color() -> Color:
	return Color("#cbe5bf") if is_night() else SUCCESS_INK

static func danger_color() -> Color:
	return Color("#ffaf9c") if is_night() else DANGER

static func dim_color() -> Color:
	return Color(0.07,0.04,0.10,0.65) if is_night() else DIM

static func growth_color() -> Color:
	return Color("#c1779c") if is_night() else primary_color()

static func primary_ink() -> Color:
	return Color("#59351e") if is_night() else Color.WHITE


static func primary_color() -> Color:
	return Color("#efb24f") if is_night() else (Color("#43bfb0") if is_botanical() else CORAL)

static func primary_pressed() -> Color:
	return Color("#d99a3f") if is_night() else (Color("#329e91") if is_botanical() else Color("#e97b69"))

static func primary_hover() -> Color:
	return Color("#f7c36a") if is_night() else (Color("#5acbbb") if is_botanical() else Color("#f8a08f"))

static func navigation_ink() -> Color:
	return Color("#557b68") if is_botanical() else ink()


static func surface(fill: Color = CREAM, radius: int = 22) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	if is_night() and fill.a > 0.8 and fill.v > 0.8 and fill not in [primary_color(), primary_hover(), primary_pressed(), growth_color()]:
		style.bg_color = panel_color()
	style.border_color = border_color()
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.corner_detail = 20
	style.shadow_color = Color(0.35, 0.22, 0.12, 0.10)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	return style


static func panel(_fill: Color, _border: Color, radius: int = 26, _shadow_strength: float = 0.34, _border_width: int = 4) -> StyleBoxFlat:
	# 기존 호출의 레이아웃은 유지하고 UI 재질은 공통 토큰에서 결정한다.
	var style := surface(CREAM, radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 11
	style.content_margin_bottom = 13
	return style


static func glass_panel(_tint := CREAM, _alpha := 0.94, radius: int = 28) -> StyleBoxFlat:
	return panel(CREAM, BORDER, radius)


static func text_color(source: Color) -> Color:
	# 상태 색상은 유지하고 일반 본문은 현재 테마의 패널 대비색을 사용한다.
	if source.s > 0.35 and source.r > source.g * 1.45 and source.r > source.b * 1.3:
		return danger_color()
	if source.s > 0.3 and source.g > source.r * 1.35 and source.g > source.b * 1.15:
		return success_color()
	return ink()


static func apply_button(button: Button, color: Color, radius: int = 22) -> void:
	var primary := color.s > 0.3 and color.r > color.b * 1.25 and color.r > color.g * 1.15
	var normal := panel(CREAM, BORDER, radius)
	normal.bg_color = primary_color() if primary else panel_color()
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = primary_hover() if primary else (Color("#563c52") if is_night() else Color("#f9efdf"))
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = primary_pressed() if primary else (Color("#362538") if is_night() else Color("#f5e4cd"))
	pressed.shadow_size = 1
	var focus := surface(Color(0, 0, 0, 0), radius)
	focus.border_color = ink()
	focus.set_border_width_all(2)
	focus.shadow_size = 0
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = disabled_color()
	disabled.shadow_size = 0
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, {"normal":normal,"hover":hover,"pressed":pressed,"focus":focus,"disabled":disabled}[state])
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, primary_ink() if primary else ink())
	button.add_theme_color_override("font_disabled_color", muted_color())
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_constant_override("shadow_offset_x", 0)
	button.add_theme_constant_override("shadow_offset_y", 0)


static func decorate_surface(_control: Control, _radius: int, _accent: Color = Color.WHITE, _intensity: float = 0.78) -> void:
	# 예전 호출과 호환된다. 크림 UI에는 유광 베벨을 추가하지 않는다.
	pass


static var _shared_theme: Theme

static func ui_theme() -> Theme:
	if _shared_theme != null:
		return _shared_theme
	var result := Theme.new()
	result.default_font = load("res://assets/fonts/Jua-Regular.ttf")
	for type in ["Label", "Button", "OptionButton", "CheckButton", "LineEdit", "TextEdit", "PopupMenu"]:
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_selected_color"]:
			result.set_color(key, type, ink())
		result.set_color("font_disabled_color", type, muted_color())
		result.set_constant("outline_size", type, 0)
	result.set_color("default_color", "RichTextLabel", ink())
	for type in ["Panel", "PanelContainer", "PopupPanel", "PopupMenu", "AcceptDialog"]:
		result.set_stylebox("panel", type, panel(CREAM, border_color()))
	for type in ["Button", "OptionButton", "LineEdit", "TextEdit"]:
		for state in ["normal", "hover", "pressed", "focus", "read_only"]:
			result.set_stylebox(state, type, panel(Color.WHITE, border_color(), 16))
		result.set_stylebox("disabled", type, surface(disabled_color(), 16))
	result.set_stylebox("hover", "PopupMenu", surface(selected_color(), 10))
	result.set_stylebox("selected", "LineEdit", surface(selected_color(), 8))
	result.set_color("caret_color", "LineEdit", ink())
	result.set_color("font_placeholder_color", "LineEdit", muted_color())
	result.set_color("selection_color", "LineEdit", selected_color())
	for type in ["HScrollBar", "VScrollBar"]:
		result.set_stylebox("scroll", type, surface(disabled_color(), 6))
		for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
			result.set_stylebox(state, type, surface(border_color(), 6))
	_shared_theme = result
	return result
