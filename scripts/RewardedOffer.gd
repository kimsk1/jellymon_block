extends CanvasLayer
const L10n = preload("res://scripts/LocalizedText.gd")
## Explicit opt-in only. Quotas are committed after the SDK reward callback.
var host: Node
var placement := ""
var granted_callback: Callable
var closed_callback: Callable
var status: Label
var watch: Button
var cancel: Button
var busy := false
var settled := false
var completed := false

func open(main: Node, key: String, description: String, on_reward: Callable, on_close: Callable) -> void:
	host = main
	placement = key
	granted_callback = on_reward
	closed_callback = on_close
	layer = 120
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ArtDirection.panel(ArtDirection.panel_color(), ArtDirection.border_color(), 24, 0.2, 1))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 25)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 510
	box.add_theme_constant_override("separation", 20)
	margin.add_child(box)
	status = Label.new()
	status.text = description
	status.custom_minimum_size = Vector2(510, 130)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 25)
	status.add_theme_color_override("font_color", ArtDirection.ink())
	box.add_child(status)
	watch = Button.new()
	watch.text = L10n.text("광고 보고 받기")
	watch.custom_minimum_size.y = 72
	watch.add_theme_font_size_override("font_size", 26)
	ArtDirection.apply_button(watch, Color("#8e64c8"), 18)
	watch.pressed.connect(_watch)
	box.add_child(watch)
	cancel = Button.new()
	cancel.text = L10n.text("나중에")
	cancel.custom_minimum_size.y = 65
	cancel.add_theme_font_size_override("font_size", 25)
	ArtDirection.apply_button(cancel, ArtDirection.CORAL, 18)
	cancel.pressed.connect(_close)
	box.add_child(cancel)

func _watch() -> void:
	if busy or completed:
		return
	if placement != "fail_continue" and host.save.rewarded_remaining(placement) <= 0:
		status.text = L10n.text("오늘 받을 수 있는 보상을 모두 받았어요.")
		watch.disabled = true
		return
	busy = true
	settled = false
	watch.disabled = true
	cancel.disabled = true
	status.text = L10n.text("광고를 준비하고 있어요. 끝까지 시청하면 보상을 받아요.")
	host.request_rewarded_ad(_reward, _unavailable, placement)

func _reward() -> void:
	if settled or completed:
		return
	settled = true
	busy = false
	if placement != "fail_continue" and not host.save.claim_rewarded_placement(placement):
		status.text = L10n.text("오늘 받을 수 있는 보상을 모두 받았어요.")
		cancel.disabled = false
		return
	completed = true
	if granted_callback.is_valid(): granted_callback.call()
	_close()

func _unavailable() -> void:
	if settled or completed:
		return
	settled = true
	busy = false
	status.text = L10n.text("광고가 완료되지 않았어요. 보상 횟수는 그대로예요.\n잠시 후 다시 시도하거나 나중에 받을 수 있어요.")
	watch.text = L10n.text("다시 시도")
	watch.disabled = false
	cancel.disabled = false

func _close() -> void:
	if busy:
		return
	if closed_callback.is_valid(): closed_callback.call()
	closed_callback = Callable()
	queue_free()
