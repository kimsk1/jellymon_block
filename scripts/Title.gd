extends Control
class_name Title
## 타이틀 화면 (04 문서 2장)

var main = null
var _jellies: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/jelly_sky_v2.png")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var wash := ColorRect.new()
	wash.color = Color(0.95, 0.9, 1.0, 0.14)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)

	var logo := Label.new()
	logo.text = "젤리몬!"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", 128)
	logo.add_theme_color_override("font_color", Color(1.0, 0.42, 0.5))
	logo.add_theme_color_override("font_outline_color", Color("#fff7e8"))
	logo.add_theme_constant_override("outline_size", 20)
	logo.add_theme_color_override("font_shadow_color", Color(0.32, 0.18, 0.5, 0.28))
	logo.add_theme_constant_override("shadow_offset_x", 0)
	logo.add_theme_constant_override("shadow_offset_y", 12)
	logo.position = Vector2(0, 240)
	logo.size = Vector2(G.W, 160)
	logo.pivot_offset = Vector2(G.W / 2, 80)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	var tw := logo.create_tween().set_loops()
	tw.tween_property(logo, "scale", Vector2(1.05, 0.95), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(logo, "scale", Vector2(0.97, 1.03), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var sub := Label.new()
	sub.text = "구멍을 슬라이드해서 젤리를 구출하세요!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 30)
	sub.add_theme_color_override("font_color", Color(0.55, 0.46, 0.66))
	sub.position = Vector2(0, 420)
	sub.size = Vector2(G.W, 50)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sub)

	# 데코 젤리들
	var keys := ["R", "Y", "B", "G", "P", "O"]
	for i in range(6):
		var tr := TextureRect.new()
		tr.texture = G.jelly_tex(keys[i])
		tr.custom_minimum_size = Vector2(96, 96)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(48 + i * 106, 620 + (34 if i % 2 == 1 else 0))
		tr.size = Vector2(96, 96)
		tr.pivot_offset = Vector2(48, 88)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)
		var jt := tr.create_tween().set_loops()
		jt.tween_interval(i * 0.17)
		jt.tween_property(tr, "scale", Vector2(1.12, 0.88), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		jt.tween_property(tr, "scale", Vector2(0.94, 1.08), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		jt.tween_property(tr, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var tap_panel := PanelContainer.new()
	tap_panel.position = Vector2(G.W / 2 - 250, 910)
	tap_panel.size = Vector2(500, 100)
	tap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tap_style := StyleBoxFlat.new()
	tap_style.bg_color = Color("#ff9c59")
	tap_style.border_color = Color("#c96348")
	tap_style.set_border_width_all(5)
	tap_style.set_corner_radius_all(32)
	tap_style.shadow_color = Color(0.18, 0.1, 0.28, 0.28)
	tap_style.shadow_size = 9
	tap_style.shadow_offset = Vector2(0, 7)
	tap_panel.add_theme_stylebox_override("panel", tap_style)
	add_child(tap_panel)
	var tap := Label.new()
	tap.text = "화면을 탭해서 시작!"
	tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tap.add_theme_font_size_override("font_size", 40)
	tap.add_theme_color_override("font_color", Color.WHITE)
	tap.add_theme_color_override("font_outline_color", Color("#9a493c"))
	tap.add_theme_constant_override("outline_size", 6)
	tap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tap_panel.add_child(tap)
	var bt := tap.create_tween().set_loops()
	bt.tween_property(tap, "modulate", Color(1.15, 1.15, 1.15, 1), 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bt.tween_property(tap, "modulate", Color.WHITE, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var ver := Label.new()
	ver.text = "v1.0 · 50 LEVELS"
	ver.add_theme_font_size_override("font_size", 22)
	ver.add_theme_color_override("font_color", Color(0.6, 0.55, 0.7))
	ver.position = Vector2(24, G.H - 54)
	ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ver)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if main:
			main.audio.play("pop", 1.2)
			main.show_map()
