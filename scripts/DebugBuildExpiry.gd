extends Node
## Export-time metadata is embedded in the APK, never in the player's save.
const METADATA_PATH := "res://debug_build_expiry.json"
var expires_at := 0
var blocked := false
var _elapsed := 0.0

static func build_metadata(now: int) -> Dictionary:
	var date := Time.get_datetime_dict_from_unix_time(now)
	date.month += 1
	if date.month > 12:
		date.month = 1
		date.year += 1
	var year := int(date.year)
	var leap := year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)
	var days := [31, 29 if leap else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	date.day = mini(int(date.day), days[int(date.month) - 1])
	return {"built_at": now, "expires_at": Time.get_unix_time_from_datetime_dict(date)}

func start() -> bool:
	if not OS.has_feature("android") or not OS.has_feature("debug") or OS.has_feature("editor"):
		return true
	process_mode = Node.PROCESS_MODE_ALWAYS
	var metadata = JSON.parse_string(FileAccess.get_file_as_string(METADATA_PATH)) if FileAccess.file_exists(METADATA_PATH) else null
	if metadata is Dictionary:
		if metadata.get("enabled", true) == false: return true
		expires_at = int(metadata.get("expires_at", 0))
	_check_expiry()
	return not blocked

func _process(delta: float) -> void:
	if expires_at <= 0 or blocked: return
	_elapsed += delta
	if _elapsed >= 1.0:
		_elapsed = 0.0
		_check_expiry()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and expires_at > 0 and not blocked:
		_check_expiry()

func _check_expiry() -> void:
	if blocked: return
	if expires_at > 0 and int(Time.get_unix_time_from_system()) < expires_at: return
	blocked = true
	get_tree().paused = true
	var layer := CanvasLayer.new()
	layer.layer = 1000
	add_child(layer)
	var background := ColorRect.new()
	background.color = Color("#251e35")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	background.add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 28)
	margin.add_child(column)
	var label := Label.new()
	label.text = "테스트 기간이 종료되었습니다\n\n이 테스트 버전은 빌드 후 한 달 동안 이용할 수 있어요.\n새 테스트 APK를 설치해 주세요." if expires_at > 0 else "테스트 버전 정보를 확인할 수 없습니다.\n새 테스트 APK를 설치해 주세요."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	column.add_child(label)
	var close := Button.new()
	close.text = "종료"
	close.custom_minimum_size.y = 64
	close.pressed.connect(func(): get_tree().quit())
	column.add_child(close)
