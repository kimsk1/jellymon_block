extends Node
signal restored
signal conflict_found(local_data: Dictionary, remote_data: Dictionary)
var platform: Node
var save: SaveGame
var _request_id := 0
var _busy := false
var _verifying := false
var _account := ""
var _sent: Dictionary = {}
var _conflict: Dictionary = {}
var _retry: Timer
var _retry_seconds := 30.0
var _muted := false
var _watchdog: Timer

func configure(service: Node, storage: SaveGame) -> void:
	platform = service
	_retry = Timer.new()
	_retry.one_shot = true
	add_child(_retry)
	_retry.timeout.connect(sync)
	_watchdog = Timer.new()
	_watchdog.one_shot = true
	_watchdog.wait_time = 25
	add_child(_watchdog)
	_watchdog.timeout.connect(func():
		_request_id += 1
		_fail("응답 시간 초과")
	)
	platform.login_changed.connect(_on_login)
	platform.game_snapshot_loaded.connect(_on_loaded)
	platform.game_snapshot_saved.connect(_on_saved)
	bind_save(storage)
	if platform.logged_in: sync()

func bind_save(storage: SaveGame) -> void:
	if save and save.data_saved.is_connected(_on_local_saved):
		save.data_saved.disconnect(_on_local_saved)
	save = storage
	save.data_saved.connect(_on_local_saved)
	_conflict = {}

func _on_login(_ok: bool, _id: String) -> void:
	platform.cloud_restore_pending = _ok and not platform.account_disconnect_pending
	_request_id += 1
	_busy = false
	_verifying = false
	_conflict = {}
	_retry.stop()
	_watchdog.stop()
	sync()

func _on_local_saved() -> void:
	if not _muted and (_retry.is_stopped() or _retry.time_left > 3.0): _retry.start(3.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and is_instance_valid(_retry): sync()

func sync() -> void:
	if _busy or not _conflict.is_empty() or platform.account_disconnect_pending or not platform.logged_in or not platform.native_available or not save.persistence_enabled: return
	if not save.hive_record_owner.is_empty() and save.hive_record_owner != platform.player_id:
		platform.set_cloud_message("클라우드 · 다른 계정의 기기 데이터 (저장 보류)")
		return
	_account = platform.player_id
	_request_id += 1
	_busy = true
	_verifying = false
	_retry.stop()
	platform.cloud_restore_pending = true
	platform.set_cloud_message("클라우드 데이터 확인 중")
	_watchdog.start()
	platform.load_game_snapshot(_request_id)

func _accept(id: int) -> bool:
	return _busy and id == _request_id and platform.logged_in and not platform.account_disconnect_pending and platform.player_id == _account

static func fingerprint(data: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(data)), "", true).sha256_text()

static func valid_snapshot(value: Variant, account: String) -> bool:
	if not value is Dictionary or value.get("schema_version") != 1 or value.get("player_id") != account or not value.get("data") is Dictionary: return false
	var defaults := SaveGame.new().cloud_data()
	var data: Dictionary = value.data
	if data.size() != defaults.size(): return false
	for key in defaults:
		if not data.has(key): return false
		var expected = defaults[key]
		var actual = data[key]
		if expected is int or expected is float:
			if not (actual is int or actual is float) or not is_finite(float(actual)) or float(actual) < 0: return false
			if expected is int and float(actual) != floor(float(actual)): return false
		elif typeof(expected) != typeof(actual): return false
		if expected is Array and expected.is_typed():
			for item in actual:
				if expected.get_typed_builtin() == TYPE_INT:
					if not (item is int or item is float) or float(item) != floor(float(item)): return false
				elif typeof(item) != expected.get_typed_builtin(): return false
	for key in ["stars", "best_clear_times", "best_clear_at", "three_star_first_at_ms", "jelly_capture_counts", "town_levels", "weekly_progress", "daily_mission_progress", "booster_inventory"]:
		for number in data[key].values():
			if not (number is int or number is float) or not is_finite(float(number)) or float(number) < 0: return false
	for stars in data.stars.values():
		if stars > 3 or stars != floor(stars): return false
	for key in ["room_placements", "resident_records", "album_memories", "resident_requests"]:
		for item in data[key]:
			if not item is Dictionary: return false
	return true

func _on_loaded(id: int, success: bool, json: String, message: String) -> void:
	if not _accept(id): return
	if not success:
		_fail(message)
		return
	if json.to_utf8_buffer().size() > 524288:
		_fail("저장 데이터 크기 확인 필요")
		return
	var remote: Dictionary = {}
	if not json.is_empty():
		var parsed = JSON.parse_string(json)
		if not valid_snapshot(parsed, _account):
			_fail("저장 데이터 형식 또는 계정 확인 필요")
			return
		remote = parsed
	if _verifying:
		if remote.is_empty() or fingerprint(remote.data) != fingerprint(_sent.data):
			_fail("저장 결과가 달라 재확인합니다")
			return
		_ack(_sent.data)
		return
	var local := save.cloud_data()
	if remote.is_empty():
		_upload(local)
	elif fingerprint(remote.data) == fingerprint(local):
		_ack(local)
	elif not save.cloud_baseline.is_empty() and fingerprint(remote.data) == save.cloud_baseline:
		_upload(local)
	else:
		_busy = false
		_watchdog.stop()
		_conflict = remote
		platform.set_cloud_message("클라우드 · 사용할 저장 데이터 선택 필요")
		conflict_found.emit(local, remote.data)

func resolve_conflict(use_cloud: bool) -> void:
	if _conflict.is_empty() or not platform.logged_in or platform.account_disconnect_pending or platform.player_id != _account: return
	var data: Dictionary = _conflict.data
	_conflict = {}
	if use_cloud:
		_restore(data)
	else:
		# Re-read before writing; a concurrently changed cloud save prompts again.
		save.cloud_baseline = fingerprint(data)
		_muted = true
		save.save_data()
		_muted = false
		sync()

func _restore(data: Dictionary) -> void:
	_muted = true
	save.apply_cloud_data(data)
	_muted = false
	_ack(data)
	restored.emit()

func _upload(data: Dictionary) -> void:
	_sent = {"schema_version": 1, "player_id": _account, "data": data.duplicate(true)}
	if JSON.stringify(_sent).to_utf8_buffer().size() > 524288:
		_fail("저장 데이터가 너무 큽니다")
		return
	platform.set_cloud_message("전체 게임 데이터 · Hive 저장 중")
	platform.save_game_snapshot(_request_id, _sent)

func _on_saved(id: int, success: bool, message: String) -> void:
	if not _accept(id): return
	if not success:
		_fail(message)
		return
	_verifying = true
	_watchdog.start()
	platform.load_game_snapshot(_request_id)

func _ack(data: Dictionary) -> void:
	_watchdog.stop()
	_busy = false
	_verifying = false
	_retry_seconds = 30.0
	_muted = true
	save.hive_record_owner = _account
	save.cloud_baseline = fingerprint(data)
	save.save_data()
	_muted = false
	platform.cloud_restore_pending = false
	platform.set_cloud_message("전체 게임 데이터 · Hive 저장 확인")
	_retry.start(3.0 if fingerprint(save.cloud_data()) != save.cloud_baseline else 60.0)

func _fail(message: String) -> void:
	_watchdog.stop()
	platform.cloud_restore_pending = false
	_busy = false
	_verifying = false
	platform.set_cloud_message("클라우드 · DataStore 활성화 필요" if message == "DataStoreDisabled" else "클라우드 · 재시도 대기 (%s)" % message)
	_retry.start(_retry_seconds)
	_retry_seconds = minf(_retry_seconds * 2.0, 300.0)

func request_sync() -> void:
	if not _conflict.is_empty():
		conflict_found.emit(save.cloud_data(), _conflict.data)
	else:
		sync()
