class_name ArtDirection
## 젤리몬 전 화면이 공유하는 프리미엄 2.5D 디자인 토큰과 스타일 팩토리.

const INK := Color("#25183f")
const CREAM := Color("#fff8e9")
const CORAL := Color("#ff526d")
const CYAN := Color("#31bfe8")
const GOLD := Color("#ffc83d")
const VIOLET := Color("#7b55c7")
const MINT := Color("#4fd18b")
const NAVY := Color("#16213f")

const CHAPTER_TINTS := [
	Color("#fff0ec"), Color("#eaffdd"), Color("#e1f6ff"), Color("#eff0ff"),
	Color("#fff0d7"), Color("#e7faff"), Color("#fff0dc"), Color("#f0e6ff"),
	Color("#e3fff2"), Color("#fff0f4"),
]


static func background_texture() -> Texture2D:
	return load("res://assets/backgrounds/jelly_village_premium_v1.png")


static func chapter_tint(level_index: int) -> Color:
	return CHAPTER_TINTS[clampi(level_index / 10, 0, CHAPTER_TINTS.size() - 1)]


static func panel(fill: Color, border: Color, radius: int = 26, shadow_strength: float = 0.34, border_width: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.corner_detail = 14
	style.border_blend = true
	style.shadow_color = Color(0.055, 0.025, 0.12, shadow_strength)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 7)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 11
	style.content_margin_bottom = 13
	return style


static func glass_panel(tint := Color("#fffaf3"), alpha := 0.94, radius: int = 28) -> StyleBoxFlat:
	var fill := Color(tint.r, tint.g, tint.b, alpha)
	var style := panel(fill, Color(1, 1, 1, 0.82), radius, 0.3, 3)
	style.border_color = Color("#7353a5")
	return style


static func apply_button(button: Button, color: Color, radius: int = 22) -> void:
	var normal := panel(color, color.darkened(0.3), radius, 0.38, 4)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = color.lightened(0.1)
	hover.border_color = Color(1, 1, 1, 0.78)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = color.darkened(0.12)
	pressed.shadow_size = 3
	pressed.shadow_offset = Vector2(0, 2)
	pressed.content_margin_top += 4
	pressed.content_margin_bottom -= 2
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = color.lerp(Color("#8f8997"), 0.56)
	disabled.border_color = Color("#787080")
	disabled.shadow_size = 2
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color", color.darkened(0.42))
	button.add_theme_constant_override("outline_size", 4)
