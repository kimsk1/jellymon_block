extends Node
signal changed
var entries: Array = []
var status := "랭킹을 불러오는 중입니다."
var loading := false
var submit_status := ""
var platform: Node
var save: SaveGame
var _base := ""
var _read: HTTPRequest
var _write: HTTPRequest
var _retry: Timer
var _auth_id := 0
var _account := ""
var _busy := false
var _sent: Dictionary = {}
var _acked: Dictionary = {}

func configure(service: Node, storage: SaveGame) -> void:
	platform = service
	save = storage
	_base = String(platform.config.get("ranking", {}).get("api_base_url", "")).trim_suffix("/")
	_read = HTTPRequest.new()
	_write = HTTPRequest.new()
	for request in [_read, _write]:
		request.timeout = 20
		request.body_size_limit = 262144
		request.max_redirects = 0 # Never forward account tokens to redirects.
		add_child(request)
	_read.request_completed.connect(_on_read)
	_write.request_completed.connect(_on_write)
	_retry = Timer.new()
	_retry.one_shot = true
	_retry.wait_time = 60
	add_child(_retry)
	_retry.timeout.connect(sync_record)
	platform.ranking_auth_ready.connect(_on_auth)
	platform.login_changed.connect(_on_login)
	if platform.logged_in:
		sync_record()

func available() -> bool:
	return _base.begins_with("https://")

func refresh() -> void:
	if loading: return
	if not available():
		status = "랭킹 서비스 준비 중입니다.\n별 3개 달성 기록은 기기에 보관됩니다."
		changed.emit()
		return
	loading = true
	status = "랭킹을 불러오는 중입니다."
	changed.emit()
	var error := _read.request(_base + "/v1/ranking/top", _transport_headers())
	if error != OK:
		_on_read(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
	sync_record()

func _transport_headers() -> PackedStringArray:
	var headers := PackedStringArray(["Accept: application/json"])
	if _base.get_slice("/", 2).ends_with(".ngrok-free.dev"):
		headers.append("ngrok-skip-browser-warning: true")
	return headers

func _on_read(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	loading = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		status = "랭킹을 불러오지 못했습니다. 다시 시도해 주세요."
		if not entries.is_empty(): status += "\n이전에 불러온 기록을 표시합니다."
	else:
		var parser := JSON.new()
		if parser.parse(body.get_string_from_utf8()) != OK or not parser.data is Dictionary or not parser.data.get("entries") is Array:
			status = "랭킹 응답을 확인할 수 없습니다."
		else:
			var rows: Array = parser.data.entries
			var valid := rows.size() <= 100
			var ids := {}
			for row in rows:
				if not row is Dictionary or int(row.get("stars", 0)) != 3 or int(row.get("level", 0)) < 1 or int(row.get("achieved_at_ms", 0)) <= 0 or String(row.get("player_id", "")).is_empty():
					valid = false
					break
				if ids.has(String(row.player_id)): valid = false
				ids[String(row.player_id)] = true
			if valid:
				entries = rows.duplicate(true)
				entries.sort_custom(func(a, b):
					if int(a.level) != int(b.level): return int(a.level) > int(b.level)
					if int(a.achieved_at_ms) != int(b.achieved_at_ms): return int(a.achieved_at_ms) < int(b.achieved_at_ms)
					return String(a.player_id) < String(b.player_id)
				)
				status = "아직 등록된 기록이 없습니다. 첫 별 3개 기록에 도전해 보세요!" if entries.is_empty() else "상위 %d명 · 달성 시각은 기기 시간대 기준" % entries.size()
			else:
				status = "랭킹 데이터 형식을 확인할 수 없습니다."
	changed.emit()

func _on_login(_ok: bool, _id: String) -> void:
	_auth_id += 1
	_busy = false
	_write.cancel_request()
	_acked = {}
	_retry.stop()
	sync_record()

func sync_record() -> void:
	if platform.cloud_restore_pending or platform.account_disconnect_pending or _busy or not available() or not platform.logged_in or not platform.native_available or not save.persistence_enabled:
		return
	if not save.hive_record_owner.is_empty() and save.hive_record_owner != platform.player_id:
		submit_status = "다른 계정의 기기 기록은 등록하지 않습니다."
		changed.emit()
		return
	var record := save.three_star_ranking_record()
	if record.is_empty() or record == _acked: return
	if save.hive_record_owner.is_empty():
		save.hive_record_owner = platform.player_id
		save.save_data()
	_account = platform.player_id
	_sent = record
	_busy = true
	_auth_id += 1
	_retry.stop()
	submit_status = "내 별 3개 기록을 등록하는 중입니다."
	changed.emit()
	platform.prepare_ranking_auth(_auth_id)

func _on_auth(id: int, success: bool, json: String) -> void:
	if not _busy or id != _auth_id or platform.player_id != _account: return
	var auth = JSON.parse_string(json) if success else null
	if not auth is Dictionary or String(auth.get("player_id", "")) != _account:
		_submit_failed("기록 등록을 위해 Hive 로그인을 확인해 주세요.")
		return
	var data := _sent.duplicate(true)
	data["player_id"] = _account
	data["did"] = String(auth.get("did", ""))
	var headers := PackedStringArray(["Content-Type: application/json", "X-Hive-Player-Token: " + String(auth.get("player_token", "")), "X-Hive-Access-Token: " + String(auth.get("access_token", ""))])
	headers.append_array(_transport_headers())
	var error := _write.request(_base + "/v1/ranking/record", headers, HTTPClient.METHOD_POST, JSON.stringify(data))
	if error != OK: _submit_failed("기록을 기기에 보관했습니다. 연결 후 다시 등록합니다.")

func _on_write(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if not _busy or platform.player_id != _account: return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_submit_failed("기록을 보관했습니다. Hive 반영을 다시 확인합니다.")
		return
	_busy = false
	_acked = _sent.duplicate(true)
	submit_status = "내 별 3개 기록을 Hive에 등록했습니다."
	changed.emit()
	refresh()

func _submit_failed(message: String) -> void:
	_busy = false
	submit_status = message
	_retry.start()
	changed.emit()
