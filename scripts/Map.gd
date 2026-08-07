extends Control
class_name MapScreen
## 레벨 선택 화면 (04 문서 3장 간소판)

var main = null
var star_tex: Texture2D

const BTN_COLORS := [
	Color(1.0, 0.45, 0.55), Color(1.0, 0.65, 0.3), Color(0.35, 0.7, 0.95),
	Color(0.4, 0.78, 0.45), Color(0.7, 0.5, 0.9), Color(0.95, 0.55, 0.75),
]


func _ready() -> void:
	star_tex = load("res://assets/fx/ui_star.png")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/jelly_sky_v2.png")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(1, 1, 1, 0.88)
	add_child(bg)

	var title := Label.new()
	title.text = "레벨 선택"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.42, 0.32, 0.56))
	title.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.92))
	title.add_theme_constant_override("outline_size", 10)
	title.position = Vector2(0, 90)
	title.size = Vector2(G.W, 80)
	add_child(title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28, 190)
	scroll.size = Vector2(G.W - 56, G.H - 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var chapters := VBoxContainer.new()
	chapters.custom_minimum_size = Vector2(G.W - 76, 0)
	chapters.add_theme_constant_override("separation", 34)
	scroll.add_child(chapters)
	for chapter in range(5):
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 14)
		chapters.add_child(section)
		var chapter_title := Label.new()
		chapter_title.text = "CHAPTER %d  %s" % [chapter + 1, Levels.CHAPTER_NAMES[chapter]]
		chapter_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chapter_title.add_theme_font_size_override("font_size", 34)
		chapter_title.add_theme_color_override("font_color", Levels.CHAPTER_COLORS[chapter].darkened(0.28))
		section.add_child(chapter_title)
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		section.add_child(grid)
		for local in range(10):
			grid.add_child(_level_button(chapter * 10 + local))

	var back := Button.new()
	back.text = "처음으로"
	back.custom_minimum_size = Vector2(220, 76)
	back.add_theme_font_size_override("font_size", 30)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.62, 0.56, 0.72)
	sb.border_color = Color(0.42, 0.34, 0.58)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(20)
	sb.shadow_color = Color(0.1, 0.06, 0.18, 0.3)
	sb.shadow_size = 7
	sb.shadow_offset = Vector2(0, 5)
	back.add_theme_stylebox_override("normal", sb)
	var sb2: StyleBoxFlat = sb.duplicate()
	sb2.bg_color = sb.bg_color.darkened(0.15)
	back.add_theme_stylebox_override("hover", sb2)
	back.add_theme_stylebox_override("pressed", sb2)
	back.add_theme_color_override("font_color", Color.WHITE)
	back.position = Vector2(G.W / 2 - 110, G.H - 150)
	back.pressed.connect(_on_back)
	add_child(back)


func _on_back() -> void:
	if main:
		main.show_title()


func _level_button(i: int) -> Button:
	var unlocked: bool = main.save.is_unlocked(i)
	var earned: int = main.save.get_stars(i)
	var b := Button.new()
	b.custom_minimum_size = Vector2(116, 118)
	var col: Color = BTN_COLORS[i % BTN_COLORS.size()] if unlocked else Color(0.72, 0.7, 0.78)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = col.darkened(0.3)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(22)
	sb.shadow_color = Color(0.1, 0.06, 0.2, 0.3)
	sb.shadow_size = 7
	sb.shadow_offset = Vector2(0, 5)
	b.add_theme_stylebox_override("normal", sb)
	var sb2: StyleBoxFlat = sb.duplicate()
	sb2.bg_color = col.darkened(0.15)
	b.add_theme_stylebox_override("hover", sb2)
	b.add_theme_stylebox_override("pressed", sb2)
	b.add_theme_stylebox_override("disabled", sb)
	b.disabled = not unlocked

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)

	var num := Label.new()
	num.text = str(i + 1) if unlocked else "잠김"
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", 40 if unlocked else 23)
	num.add_theme_color_override("font_color", Color.WHITE)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(num)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	for s in range(3):
		var tr := TextureRect.new()
		tr.texture = star_tex
		tr.custom_minimum_size = Vector2(23, 23)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.modulate = Color(1.0, 0.85, 0.2) if s < earned else Color(1, 1, 1, 0.35)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tr)

	var idx := i
	b.pressed.connect(func(): main.start_level(idx))
	return b
