extends Node
class_name AnalyticsService
## 개인 식별 정보 없이 플레이 퍼널을 로컬에 버퍼링하는 분석 경계.
## HIVE/Firebase 연결 시 flush 이벤트를 네이티브 전송기로 교체할 수 있다.

const SCHEMA_PATH := "res://assets/data/analytics_schema.json"
const BUFFER_PATH := "user://analytics_events.jsonl"
const REMOTE_CONFIG_PATH := "res://assets/data/analytics_remote.json"
const UPLOAD_QUEUE_PATH := "user://analytics_upload_queue.json"
const GameBalanceCatalogLib = preload("res://scripts/GameBalanceCatalog.gd")

var persistence_enabled := true
var session_id := ""
var player_key := ""
var _schema: Dictionary = {}
var _pending: Array[Dictionary] = []
var _remote_config: Dictionary = {}
var _upload_queue: Array = []
var _request: HTTPRequest
var _uploading := false
var _upload_batch_count := 0
var _retry_seconds := 5.0


func initialize(enabled: bool = true) -> void:
	persistence_enabled = enabled
	_schema = _read_json(SCHEMA_PATH).get("events", {})
	_remote_config = _read_json(REMOTE_CONFIG_PATH)
	session_id = "%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 1000000]
	# 원본 기기 식별자는 저장·전송하지 않고 게임 전용 단방향 키만 사용한다.
	player_key = ("jellymon_analytics_v1:" + OS.get_unique_id()).sha256_text().substr(0, 20)
	_load_upload_queue()
	if persistence_enabled and _remote_enabled():
		_request = HTTPRequest.new()
		_request.timeout = float(_remote_config.get("request_timeout_seconds", 12))
		_request.request_completed.connect(_on_upload_completed)
		add_child(_request)
		call_deferred("_try_remote_upload")


func reset_local_data() -> void:
	if is_instance_valid(_request):
		_request.cancel_request()
	_pending.clear()
	_upload_queue.clear()
	_uploading = false
	_upload_batch_count = 0
	_retry_seconds = 5.0
	if persistence_enabled:
		for path in [BUFFER_PATH, UPLOAD_QUEUE_PATH]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
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
		"player_key": player_key,
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
	var batch := _pending.duplicate(true)
	var file := FileAccess.open(BUFFER_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(BUFFER_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	for event in _pending:
		file.store_line(JSON.stringify(event))
	_pending.clear()
	if _remote_enabled():
		_upload_queue.append_array(batch)
		_trim_upload_queue()
		_save_upload_queue()
		call_deferred("_try_remote_upload")
	var estimated_limit := GameBalanceCatalogLib.analytics("local_buffer_limit", 500) * 600
	var should_trim := file.get_length() > estimated_limit
	file = null
	if should_trim:
		_trim_buffer()


func _remote_enabled() -> bool:
	return bool(_remote_config.get("enabled", false)) and not String(_remote_config.get("endpoint", "")).is_empty()


func feedback_prompt_enabled() -> bool:
	return bool(_remote_config.get("feedback_prompt", false))


func _load_upload_queue() -> void:
	var file := FileAccess.open(UPLOAD_QUEUE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		_upload_queue = parsed


func _save_upload_queue() -> void:
	if not persistence_enabled:
		return
	var file := FileAccess.open(UPLOAD_QUEUE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_upload_queue))


func _trim_upload_queue() -> void:
	var limit := GameBalanceCatalogLib.analytics("local_buffer_limit", 500)
	if _upload_queue.size() > limit:
		_upload_queue = _upload_queue.slice(_upload_queue.size() - limit)


func _try_remote_upload() -> void:
	if not _remote_enabled() or _uploading or _upload_queue.is_empty() or not is_instance_valid(_request):
		return
	var batch_size := clampi(int(_remote_config.get("batch_size", 30)), 1, 100)
	_upload_batch_count = mini(batch_size, _upload_queue.size())
	var payload := {
		"schema_version": 1,
		"game": "jellymon",
		"environment": String(_remote_config.get("environment", "closed_beta")),
		"events": _upload_queue.slice(0, _upload_batch_count),
	}
	var headers := PackedStringArray(["Content-Type: application/json", "X-JellyMon-Schema: 1"])
	var api_key := String(_remote_config.get("api_key", ""))
	if not api_key.is_empty():
		headers.append("Authorization: Bearer " + api_key)
	_uploading = true
	var error := _request.request(String(_remote_config.endpoint), headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		_uploading = false
		_schedule_retry()


func _on_upload_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_uploading = false
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		_upload_queue = _upload_queue.slice(_upload_batch_count)
		_save_upload_queue()
		_retry_seconds = 5.0
		call_deferred("_try_remote_upload")
		return
	_schedule_retry()


func _schedule_retry() -> void:
	if not is_inside_tree() or not _remote_enabled():
		return
	var delay := _retry_seconds
	_retry_seconds = minf(300.0, _retry_seconds * 2.0)
	get_tree().create_timer(delay).timeout.connect(_try_remote_upload)


func local_quality_report() -> Dictionary:
	## 클로즈드 베타에서 수집된 로컬 이벤트만으로 퍼널 품질을 빠르게 점검한다.
	var counts := {}
	var level_starts := {}
	var level_clears := {}
	var level_fails := {}
	var sessions := {}
	var players := {}
	var file := FileAccess.open(BUFFER_PATH, FileAccess.READ)
	if file != null:
		while not file.eof_reached():
			var line := file.get_line().strip_edges()
			if line.is_empty():
				continue
			var parsed = JSON.parse_string(line)
			if not parsed is Dictionary:
				continue
			var event_name := String(parsed.get("name", ""))
			var properties: Dictionary = parsed.get("properties", {})
			counts[event_name] = int(counts.get(event_name, 0)) + 1
			var report_session := String(parsed.get("session_id", ""))
			var report_player := String(parsed.get("player_key", ""))
			if not report_session.is_empty(): sessions[report_session] = true
			if not report_player.is_empty(): players[report_player] = true
			var level := str(int(properties.get("level", 0)))
			if event_name == "level_start": level_starts[level] = int(level_starts.get(level, 0)) + 1
			elif event_name == "level_clear": level_clears[level] = int(level_clears.get(level, 0)) + 1
			elif event_name == "level_fail": level_fails[level] = int(level_fails.get(level, 0)) + 1
	return {"anonymous_players":players.size(),"sessions":sessions.size(),"events":counts,"level_starts":level_starts,"level_clears":level_clears,"level_fails":level_fails,"queued_for_upload":_upload_queue.size()}


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
	var remote_file := FileAccess.open(REMOTE_CONFIG_PATH, FileAccess.READ)
	var remote = JSON.parse_string(remote_file.get_as_text()) if remote_file != null else null
	if not remote is Dictionary:
		errors.append("원격 분석 설정 형식이 올바르지 않습니다")
	elif bool(remote.get("enabled", false)) and String(remote.get("endpoint", "")).is_empty():
		errors.append("원격 분석이 활성화됐지만 endpoint가 없습니다")
	return errors
