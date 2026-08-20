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


static func panel(fill: Color, border: Color, radius: int = 26, shadow_strength: float = 0.34, border_width: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	# 큰 모바일 패널의 곡선에서 각이 보이지 않도록 충분한 세그먼트를 쓰고,
	# 밝은 외곽선과 깊은 드롭 섀도를 한 리소스에서 일관되게 유지한다.
	style.corner_detail = 20
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.35
	style.border_blend = true
	style.shadow_color = Color(0.035, 0.018, 0.095, shadow_strength)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 11
	style.content_margin_bottom = 13
	return style


static func glass_panel(tint := Color("#fffaf3"), alpha := 0.94, radius: int = 28) -> StyleBoxFlat:
	var fill := Color(tint.r, tint.g, tint.b, alpha)
	var style := panel(fill, Color("#7353a5"), radius, 0.34, 4)
	# 반투명 카드도 가장자리에서 흰 산란광이 느껴지도록 테두리를 살짝 밝힌다.
	style.border_color = Color("#8d70bc").lerp(Color.WHITE, 0.14)
	return style


static func apply_button(button: Button, color: Color, radius: int = 22) -> void:
	var normal := panel(color.lightened(0.035), color.darkened(0.34), radius, 0.44, 5)
	normal.content_margin_top += 1
	normal.content_margin_bottom += 2
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = color.lightened(0.13)
	hover.border_color = Color(1, 1, 1, 0.88)
	hover.shadow_size = 17
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = color.darkened(0.14)
	pressed.border_color = color.darkened(0.42)
	pressed.shadow_size = 4
	pressed.shadow_offset = Vector2(0, 3)
	pressed.content_margin_top += 5
	pressed.content_margin_bottom -= 3
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
	button.add_theme_color_override("font_outline_color", color.darkened(0.5))
	button.add_theme_color_override("font_shadow_color", Color(0.06, 0.025, 0.13, 0.38))
	button.add_theme_constant_override("outline_size", 5)
	button.add_theme_constant_override("shadow_offset_x", 0)
	button.add_theme_constant_override("shadow_offset_y", 3)
