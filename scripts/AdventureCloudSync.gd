extends Node
## 최고 모험 기록만 동기화한다. 재화/별/맵 진행도를 원격 값으로 덮어쓰지 않는다.
var platform: Node
var save: SaveGame
var _request_id := 0
var _busy := false
var _verifying := false
var _account := ""
var _sent: Dictionary = {}
var _retry: Timer
var _retry_seconds := 30.0


func configure(service: Node, storage: SaveGame) -> void:
	platform = service
	save = storage
	_retry = Timer.new()
	_retry.one_shot = true
	add_child(_retry)
	_retry.timeout.connect(sync)
	platform.login_changed.connect(_on_login)
	platform.adventure_record_loaded.connect(_on_loaded)
	platform.adventure_record_saved.connect(_on_saved)
	if platform.logged_in:
		sync()


func _on_login(_logged_in: bool, _id: String) -> void:
	_request_id += 1 # 이전 계정/요청의 콜백은 무시한다.
	_busy = false
	_retry.stop()
	sync()


func sync() -> void:
	if platform.account_disconnect_pending or _busy or not platform.logged_in or not platform.native_available or not save.persistence_enabled:
		return
	if not save.hive_record_owner.is_empty() and save.hive_record_owner != platform.player_id:
		platform.set_cloud_message("모험 기록 · 다른 계정의 기기 기록 (저장 보류)")
		return
	if save.hive_record_owner.is_empty():
		save.hive_record_owner = platform.player_id
		save.save_data()
	_account = platform.player_id
	_request_id += 1
	_busy = true
	_verifying = false
	_retry.stop()
	platform.set_cloud_message("모험 기록 · Hive 확인 중")
	platform.load_adventure_record(_request_id)


func _accept(id: int) -> bool:
	return not platform.account_disconnect_pending and _busy and id == _request_id and platform.logged_in and platform.player_id == _account


func _on_loaded(id: int, success: bool, json: String, message: String) -> void:
	if not _accept(id):
		return
	if not success:
		_fail(message)
		return
	var remote: Dictionary = {}
	if not json.is_empty():
		var parsed = JSON.parse_string(json)
		if not valid_record(parsed):
			_fail("저장된 기록 형식 확인 필요")
			return
		remote = parsed
	if _verifying:
		_verifying = false
		if remote.is_empty() or preferred_record(_sent, remote) != remote:
			_fail("서버 저장 결과 확인 필요")
			return
	var local := save.adventure_record()
	_sent = preferred_record(local, remote)
	if _sent == remote or int(_sent.get("highest_cleared_level", 0)) == 0:
		_finish()
		return
	platform.set_cloud_message("모험 기록 · Hive 저장 중")
	platform.save_adventure_record(_request_id, _sent)


func _on_saved(id: int, success: bool, message: String) -> void:
	if not _accept(id):
		return
	if not success:
		_fail(message)
		return
	_verifying = true
	# 실제 서버 재조회로 저장 내용 확인. 서버가 반환한 기록을 다시 비교한다.
	platform.load_adventure_record(_request_id)


func _finish() -> void:
	_busy = false
	_retry_seconds = 30.0
	var level := int(_sent.get("highest_cleared_level", 0))
	platform.set_cloud_message("모험 기록 · Hive 저장 확인 (LEVEL %d)" % level if level > 0 else "모험 기록 · 클리어 후 저장")


func _fail(message: String) -> void:
	_busy = false
	platform.set_cloud_message("모험 기록 · 저장 재시도 대기 (%s)" % message)
	push_warning("[HiveCloud] " + message)
	_retry.start(_retry_seconds)
	_retry_seconds = minf(_retry_seconds * 2.0, 300.0)


static func valid_record(value: Variant) -> bool:
	if not value is Dictionary or int(value.get("schema_version", 0)) != 1:
		return false
	for key in ["highest_cleared_level", "best_clear_ms", "best_cleared_at_unix"]:
		if not value.has(key) or not (value[key] is int or value[key] is float):
			return false
		if not is_finite(float(value[key])) or float(value[key]) < 0 or float(value[key]) != floor(float(value[key])):
			return false
	return true


static func preferred_record(local: Dictionary, remote: Dictionary) -> Dictionary:
	if remote.is_empty():
		return local.duplicate(true)
	var local_level := int(local.highest_cleared_level)
	var remote_level := int(remote.highest_cleared_level)
	if local_level != remote_level:
		return (local if local_level > remote_level else remote).duplicate(true)
	var local_ms := int(local.best_clear_ms)
	var remote_ms := int(remote.best_clear_ms)
	if local_ms > 0 and (remote_ms == 0 or local_ms < remote_ms):
		return local.duplicate(true)
	# 같은 소요 시간에서는 알려진 달성 시각 중 먼저 달성한 것을 유지한다.
	if local_ms == remote_ms:
		var local_at := int(local.best_cleared_at_unix)
		var remote_at := int(remote.best_cleared_at_unix)
		if local_at > 0 and (remote_at == 0 or local_at < remote_at):
			return local.duplicate(true)
	return remote.duplicate(true)
