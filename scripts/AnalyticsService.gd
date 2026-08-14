extends Node
class_name AnalyticsService
## 개인 식별 정보 없이 플레이 퍼널을 로컬에 버퍼링하는 분석 경계.
## HIVE/Firebase 연결 시 flush 이벤트를 네이티브 전송기로 교체할 수 있다.

const SCHEMA_PATH := "res://assets/data/analytics_schema.json"
const BUFFER_PATH := "user://analytics_events.jsonl"
const GameBalanceCatalogLib = preload("res://scripts/GameBalanceCatalog.gd")

var persistence_enabled := true
var session_id := ""
var _schema: Dictionary = {}
var _pending: Array[Dictionary] = []


func initialize(enabled: bool = true) -> void:
	persistence_enabled = enabled
	_schema = _read_json(SCHEMA_PATH).get("events", {})
	session_id = "%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 1000000]


func track(event_name: String, properties: Dictionary = {}) -> bool:
	if not _schema.has(event_name):
		push_warning("[analytics] unknown event: %s" % event_name)
		return false
	var required: Array = _schema.get(event_name, [])
	for key in required:
		if not properties.has(String(key)):
			push_warning("[analytics] %s missing property: %s" % [event_name, key])
			return false
	var event := {
		"name": event_name,
		"timestamp": int(Time.get_unix_time_from_system()),
		"session_id": session_id,
		"properties": _sanitize(properties),
	}
	_pending.append(event)
	if _pending.size() >= GameBalanceCatalogLib.analytics("flush_batch_size", 10):
		flush()
	return true


func flush() -> void:
	if _pending.is_empty():
		return
	if not persistence_enabled:
		_pending.clear()
		return
	var file := FileAccess.open(BUFFER_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(BUFFER_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	for event in _pending:
		file.store_line(JSON.stringify(event))
	_pending.clear()
	var estimated_limit := GameBalanceCatalogLib.analytics("local_buffer_limit", 500) * 600
	var should_trim := file.get_length() > estimated_limit
	file = null
	if should_trim:
		_trim_buffer()


func _exit_tree() -> void:
	flush()


func _trim_buffer() -> void:
	var file := FileAccess.open(BUFFER_PATH, FileAccess.READ)
	if file == null:
		return
	var lines: Array[String] = []
	while not file.eof_reached():
		var line := file.get_line()
		if not line.is_empty():
			lines.append(line)
	file = null
	var limit := GameBalanceCatalogLib.analytics("local_buffer_limit", 500)
	if lines.size() <= limit:
		return
	var output := FileAccess.open(BUFFER_PATH, FileAccess.WRITE)
	if output == null:
		return
	for index in range(lines.size() - limit, lines.size()):
		output.store_line(lines[index])


func _sanitize(value):
	if value is Dictionary:
		var result := {}
		for key in value:
			result[String(key)] = _sanitize(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_sanitize(item))
		return result
	if value is String or value is bool or value is int or value is float or value == null:
		return value
	return str(value)


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


static func validate_schema() -> PackedStringArray:
	var errors := PackedStringArray()
	var file := FileAccess.open(SCHEMA_PATH, FileAccess.READ)
	if file == null:
		errors.append("분석 이벤트 스키마 파일을 열 수 없습니다")
		return errors
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("events"):
		errors.append("분석 이벤트 스키마 형식이 올바르지 않습니다")
	return errors
