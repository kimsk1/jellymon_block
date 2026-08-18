extends Control
class_name TutorialGuide
## 입력을 가로채지 않는 상황형 튜토리얼 오버레이.

var from_point := Vector2.ZERO
var to_point := Vector2.ZERO
var focus_rect := Rect2()
var phase := 0.0
var message_label: Label
var focus_style: StyleBoxFlat


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 180
	focus_style = StyleBoxFlat.new()
	focus_style.bg_color = Color(0, 0, 0, 0)
	focus_style.border_color = Color(1, 0.91, 0.42, 0.9)
	focus_style.set_border_width_all(4)
	focus_style.set_corner_radius_all(26)
	message_label = Label.new()
	message_label.position = Vector2(55, 1010)
	message_label.size = Vector2(610, 92)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 24)
	message_label.add_theme_color_override("font_color", Color("#523866"))
	message_label.add_theme_color_override("font_outline_color", Color.WHITE)
	message_label.add_theme_constant_override("outline_size", 3)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fff8e9")
	style.border_color = Color("#8b67b3")
	style.set_border_width_all(4)
	style.set_corner_radius_all(24)
	style.shadow_color = Color(0.1, 0.05, 0.18, 0.3)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 5)
	style.content_margin_left = 18
	style.content_margin_right = 18
	message_label.add_theme_stylebox_override("normal", style)
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(message_label)


func setup(text: String, from: Vector2, to: Vector2, focus: Rect2 = Rect2()) -> void:
	from_point = from
	to_point = to
	focus_rect = focus
	if focus_rect.size == Vector2.ZERO:
		var left := minf(from.x, to.x) - 70.0
		var top := minf(from.y, to.y) - 70.0
		var right := maxf(from.x, to.x) + 70.0
		var bottom := maxf(from.y, to.y) + 70.0
		focus_rect = Rect2(left, top, right - left, bottom - top)
	if message_label:
		message_label.text = text
	queue_redraw()


func _process(delta: float) -> void:
	phase = fmod(phase + delta * 0.62, 1.0)
	queue_redraw()


func _draw() -> void:
	var safe := focus_rect.grow(18.0)
	var dim := Color(0.08, 0.04, 0.16, 0.46)
	draw_rect(Rect2(0, 0, size.x, maxf(0, safe.position.y)), dim)
	draw_rect(Rect2(0, safe.end.y, size.x, maxf(0, size.y - safe.end.y)), dim)
	draw_rect(Rect2(0, safe.position.y, maxf(0, safe.position.x), safe.size.y), dim)
	draw_rect(Rect2(safe.end.x, safe.position.y, maxf(0, size.x - safe.end.x), safe.size.y), dim)
	var pulse := 7.0 + sin(phase * TAU) * 3.0
	draw_style_box(focus_style, safe.grow(pulse))
	var distance := from_point.distance_to(to_point)
	var segments := maxi(1, int(distance / 24.0))
	for index in range(segments):
		if index % 2 == 0:
			var a := from_point.lerp(to_point, float(index) / segments)
			var b := from_point.lerp(to_point, float(index + 1) / segments)
			draw_line(a, b, Color(1, 1, 1, 0.9), 7.0, true)
	var hand := from_point.lerp(to_point, 0.08 + 0.84 * phase)
	draw_circle(hand + Vector2(3, 6), 21, Color(0.15, 0.08, 0.23, 0.28))
	draw_circle(hand, 19, Color("#fff4c9"))
	draw_arc(hand, 19, 0, TAU, 28, Color("#8b67b3"), 4.0, true)
	var direction := (to_point - from_point).normalized()
	draw_line(hand, hand + direction * 30.0, Color("#fff4c9"), 13.0, true)
	draw_circle(to_point, 25 + sin(phase * TAU) * 5, Color(1, 0.9, 0.35, 0.16))
	draw_arc(to_point, 28 + sin(phase * TAU) * 5, 0, TAU, 32, Color("#ffe36d"), 5.0, true)


func dismiss() -> void:
	set_process(false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)
