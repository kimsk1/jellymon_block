extends Node
## Google Play → Hive 검증 서버 → 기기 원자 저장 → 서버 ACK → SDK 거래 완료.
signal changed
var platform: Node
var save: SaveGame
var prices: Dictionary = {}
var busy := false
var status := "계정 연결 후 상점을 이용할 수 있어요."
var _base := ""
var _account := ""
var _install := ""
var _auth_id := -100000
var _action := ""
var _data: Dictionary = {}
var _queue: Array = []
var _grant: Dictionary = {}
var _request: HTTPRequest
var _timeout: Timer

func configure(service: Node, storage: SaveGame) -> void:
	platform = service
	save = storage
	_base = String(platform.config.get("ranking", {}).get("api_base_url", "")).trim_suffix("/")
	_request = HTTPRequest.new()
	_request.timeout = 20
	_request.max_redirects = 0
	_request.body_size_limit = 262144
	add_child(_request)
	_request.request_completed.connect(_on_response)
	_timeout = Timer.new()
	_timeout.one_shot = true
	_timeout.wait_time = 180
	add_child(_timeout)
	_timeout.timeout.connect(func(): _fail("상점 응답을 기다리고 있습니다. 잠시 후 구매 복원을 눌러 주세요."))
	platform.ranking_auth_ready.connect(_on_auth)
	platform.billing_event.connect(_on_native)
	platform.login_changed.connect(_on_login)
	if save.persistence_enabled:
		var path := "user://billing_install_id"
		if FileAccess.file_exists(path): _install = FileAccess.get_file_as_string(path).strip_edges()
		if _install.length() != 32:
			_install = Crypto.new().generate_random_bytes(16).hex_encode()
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file:
				file.store_string(_install)
				file.flush()
				if file.get_error() != OK: _install = ""
			else: _install = ""
	if platform.logged_in and available(): refresh.call_deferred()

func _on_login(_ok: bool, _pid: String) -> void:
	_auth_id -= 1
	_request.cancel_request()
	_timeout.stop()
	prices.clear()
	_queue.clear()
	_grant.clear()
	busy = false
	_action = ""
	_data.clear()
	status = "상점에서 구매 내역을 확인할 수 있어요." if platform.logged_in else "계정 연결 후 상점을 이용할 수 있어요."
	changed.emit()
	if _ok and available(): refresh.call_deferred()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and is_instance_valid(platform) and is_instance_valid(_request) and available() and not busy:
		refresh.call_deferred()

func available() -> bool:
	return platform.billing_available() and _base.begins_with("https://") and _install.length() == 32 and save.persistence_enabled

func price(item: Dictionary) -> String:
	return String(prices.get(String(item.get("android_product_id", "")), "상품 확인 중" if busy else "판매 준비 중"))

func can_buy(item: Dictionary) -> bool:
	return available() and not busy and prices.has(String(item.get("android_product_id", "")))

func refresh() -> void:
	if busy: return
	if not available():
		_fail("Google Play 결제를 사용할 수 없습니다. Android 앱의 계정 연결을 확인해 주세요.")
		return
	_account = platform.player_id
	busy = true
	status = "상점과 구매 내역을 확인하고 있어요."
	_timeout.start()
	changed.emit()
	platform.billing_call("billingInitialize")

func purchase(item: Dictionary) -> void:
	if not can_buy(item): return
	_account = platform.player_id
	status = "구매를 준비하고 있어요."
	_post("order", {"sku": String(item.get("android_product_id", ""))})

func _post(action: String, data: Dictionary) -> void:
	busy = true
	_action = action
	_data = data.duplicate(true)
	_auth_id -= 1
	_timeout.start()
	changed.emit()
	platform.prepare_ranking_auth(_auth_id)

func _on_auth(id: int, success: bool, raw: String) -> void:
	if id != _auth_id or not busy or platform.player_id != _account: return
	var auth = JSON.parse_string(raw) if success else null
	if not auth is Dictionary or String(auth.get("player_id", "")) != _account:
		_fail("구매 확인을 위해 계정을 다시 연결해 주세요.")
		return
	var body := _data.duplicate(true)
	body.merge({"app_id": String(platform.config.get("app_id", "")), "player_id": _account, "did": String(auth.get("did", "")), "install_id": _install}, true)
	var headers := PackedStringArray(["Content-Type: application/json", "X-Hive-Player-Token: " + String(auth.get("player_token", "")), "X-Hive-Access-Token: " + String(auth.get("access_token", "")), "ngrok-skip-browser-warning: true"])
	var error := _request.request(_base + "/v1/billing/" + _action, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	_data.clear()
	if error != OK: _fail("결제 확인에 연결하지 못했습니다. 구매 복원을 다시 눌러 주세요.")

func _on_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not busy or platform.player_id != _account: return
	var response = JSON.parse_string(body.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not response is Dictionary:
		var message := "구매 확인에 실패했습니다. 구매 복원을 다시 눌러 주세요."
		if response is Dictionary: message = String(response.get("message", message)).left(180)
		_fail(message)
		return
	match _action:
		"order":
			status = "Google Play에서 구매를 완료해 주세요."
			platform.billing_call("billingPurchase", [String(response.sku), String(response.payload)])
		"entitlements":
			for entry in response.get("entitlements", []):
				if not save.apply_iap_delivery("entitlement", entry.item, String(entry.season), true):
					_fail("구매 내역을 기기에 저장하지 못했습니다. 저장 공간을 확인해 주세요.")
					return
			platform.billing_call("billingRestore")
		"verify":
			_grant = response
			if String(response.get("sku", "")) != String(_queue[0].get("sku", "")):
				_fail("구매 상품 확인에 실패했습니다.")
				return
			if bool(response.get("delivered", false)):
				# Already granted: consumable currency is restored only through cloud saves.
				platform.billing_call("billingFinish", [String(response.sku)])
			elif save.apply_iap_delivery(String(response.transaction_id), response.item, String(response.season)):
				_post("ack", {"transaction_id": String(response.transaction_id)})
			else:
				_fail("지급을 저장하지 못했습니다. 저장 공간 또는 시즌 기간을 확인하고 구매 복원을 눌러 주세요.")
		"ack":
			platform.billing_call("billingFinish", [String(response.sku)])
	changed.emit()

func _on_native(kind: String, raw: String) -> void:
	var data = JSON.parse_string(raw)
	if not data is Dictionary or String(data.get("player_id", "")) != _account or platform.player_id != _account: return
	match kind:
		"products":
			prices.clear()
			for item in data.get("products", []):
				if not String(item.get("price", "")).is_empty(): prices[String(item.sku)] = String(item.price)
			_post("entitlements", {})
		"receipts":
			_queue = data.get("receipts", [])
			_next_receipt()
		"finished":
			if not _queue.is_empty(): _queue.pop_front()
			_next_receipt()
		"error":
			_fail(String(data.get("message", "구매를 완료하지 못했습니다.")) + " (" + String(data.get("code", "")) + ")")
	changed.emit()

func _next_receipt() -> void:
	if _queue.is_empty():
		busy = false
		_timeout.stop()
		status = "구매 내역 확인 완료. 최종 가격은 Google Play 결제창에서 확인해 주세요."
		if prices.is_empty(): status = "판매 중인 상품이 없습니다. 잠시 후 다시 확인해 주세요."
		_grant.clear()
		changed.emit()
	else:
		status = "구매 상품을 확인하고 있어요."
		_post("verify", {"receipt": String(_queue[0].receipt)})

func _fail(message: String) -> void:
	busy = false
	_action = ""
	_data.clear()
	_queue.clear()
	_grant.clear()
	_timeout.stop()
	status = message
	changed.emit()
