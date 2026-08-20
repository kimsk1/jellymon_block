extends Node
class_name PlatformService
## HIVE SDK를 게임 코드와 분리하는 단일 경계.
## Android/iOS 네이티브 완료 콜백은 반드시 이 서비스의 signal을 거쳐 UI에 전달한다.

signal setup_changed(ready: bool, message: String)
signal login_changed(logged_in: bool, player_id: String)
signal login_failed(message: String)
signal rewarded_ad_state_changed(state: String, message: String)

const CONFIG_PATH := "res://assets/data/platform_services.json"
const LOCAL_CLOUD_PATH := "user://jellymon_cloud_fallback.json"
const LOCAL_RANK_PATH := "user://jellymon_rank_fallback.json"
const ANDROID_SINGLETON := "HiveBridge"

var native_available := false
var native_ready := false
var logged_in := false
var player_id := ""
var player_name := ""
var setup_message := ""
var rewarded_ad_state := "unavailable"
var rewarded_ad_message := ""
var config: Dictionary = {}

var _native_bridge = null
var _setup_finished := false
var _login_requested := false
var _pending_reward := Callable()
var _pending_unavailable := Callable()


func initialize() -> void:
	config = _read_json(CONFIG_PATH)
	var singleton_name := String(config.get("android", {}).get("singleton", ANDROID_SINGLETON))
	native_available = Engine.has_singleton(singleton_name)
	if native_available:
		_native_bridge = Engine.get_singleton(singleton_name)
		_connect_native_signals()
		var test_ads := bool(config.get("android", {}).get("test_ads", OS.is_debug_build()))
		var sandbox := String(config.get("android", {}).get("zone", "sandbox")) == "sandbox"
		_native_bridge.call("initialize", test_ads, sandbox)
		return
	player_id = "guest_%s" % OS.get_unique_id().substr(0, 10)
	# 데스크톱 개발 환경은 기존 로컬 폴백을 유지한다. Android 출시 빌드는
	# 네이티브 플러그인이 없으면 보상/로그인을 성공 처리하지 않는다.
	native_ready = OS.get_name() != "Android"
	setup_message = "로컬 개발 모드" if native_ready else "HIVE Android 플러그인을 찾을 수 없습니다."
	setup_changed.emit(native_ready, setup_message)


func _connect_native_signals() -> void:
	_native_bridge.connect("hive_setup_completed", Callable(self, "_on_hive_setup_completed"))
	_native_bridge.connect("hive_login_completed", Callable(self, "_on_hive_login_completed"))
	_native_bridge.connect("rewarded_ad_state", Callable(self, "_on_rewarded_ad_state"))
	_native_bridge.connect("rewarded_ad_completed", Callable(self, "_on_rewarded_ad_completed"))


func login() -> bool:
	if native_available:
		if not native_ready:
			if _setup_finished:
				login_failed.emit.call_deferred("HIVE 초기화 실패: %s" % setup_message)
				return false
			_login_requested = true
			return true
		return bool(_native_bridge.call("login"))
	logged_in = true
	login_changed.emit(true, player_id)
	return true


func complete_native_login(id: String) -> void:
	## iOS 브리지도 동일 진입점을 사용할 수 있도록 유지한다.
	player_id = id
	logged_in = not id.is_empty()
	login_changed.emit(logged_in, player_id)


func show_rewarded_ad(on_reward: Callable, on_unavailable: Callable = Callable()) -> void:
	if native_available:
		if _pending_reward.is_valid() or _pending_unavailable.is_valid():
			if on_unavailable.is_valid():
				on_unavailable.call_deferred()
			return
		_pending_reward = on_reward
		_pending_unavailable = on_unavailable
		_native_bridge.call("showRewardedAd")
		return
	if OS.is_debug_build() and OS.get_name() != "Android":
		await get_tree().create_timer(0.65).timeout
		if on_reward.is_valid():
			on_reward.call()
		return
	if on_unavailable.is_valid():
		on_unavailable.call_deferred()


func _on_hive_setup_completed(success: bool, message: String, auto_sign_in: bool) -> void:
	_setup_finished = true
	native_ready = success
	setup_message = message
	print("[HiveBridge] setup success=%s auto_sign_in=%s message=%s" % [success, auto_sign_in, message])
	setup_changed.emit(success, message)
	if not success:
		if _login_requested:
			_login_requested = false
			login_failed.emit("HIVE 초기화 실패: %s" % message)
		return
	if auto_sign_in or _login_requested:
		_login_requested = false
		_native_bridge.call("login")


func _on_hive_login_completed(success: bool, id: String, name: String, error: String) -> void:
	print("[HiveBridge] login success=%s player_id=%s error=%s" % [success, id, error])
	if success:
		player_id = id
		player_name = name
		logged_in = true
		login_changed.emit(true, player_id)
	else:
		logged_in = false
		login_failed.emit("로그인 실패: %s" % error)


func _on_rewarded_ad_state(state: String, message: String) -> void:
	rewarded_ad_state = state
	rewarded_ad_message = message
	print("[HiveBridge] rewarded state=%s message=%s" % [state, message])
	rewarded_ad_state_changed.emit(state, message)


func _on_rewarded_ad_completed(rewarded: bool, message: String) -> void:
	rewarded_ad_message = message
	print("[HiveBridge] rewarded completed=%s message=%s" % [rewarded, message])
	var reward_callback := _pending_reward
	var unavailable_callback := _pending_unavailable
	_pending_reward = Callable()
	_pending_unavailable = Callable()
	if rewarded:
		if reward_callback.is_valid():
			reward_callback.call()
	elif unavailable_callback.is_valid():
		unavailable_callback.call()
	if not message.is_empty():
		rewarded_ad_state_changed.emit("failed", message)


func submit_score(score: int) -> bool:
	if score < 0:
		return false
	if native_available:
		return false
	var rank := _read_json(LOCAL_RANK_PATH)
	rank["player_id"] = player_id
	rank["best_score"] = maxi(score, int(rank.get("best_score", 0)))
	rank["updated_at"] = int(Time.get_unix_time_from_system())
	return _write_json(LOCAL_RANK_PATH, rank)


func save_cloud_snapshot(snapshot: Dictionary) -> bool:
	if native_available:
		return false
	var envelope := {"player_id": player_id, "updated_at": int(Time.get_unix_time_from_system()), "data": snapshot}
	return _write_json(LOCAL_CLOUD_PATH, envelope)


func load_cloud_snapshot() -> Dictionary:
	if native_available:
		return {}
	var envelope := _read_json(LOCAL_CLOUD_PATH)
	var value = envelope.get("data", {})
	return value if value is Dictionary else {}


func status_text() -> String:
	if logged_in:
		if native_available:
			var suffix := "" if player_name.is_empty() else " · " + player_name
			return "HIVE 연결됨%s" % suffix
		return "게스트 저장 연결됨"
	if native_available:
		if native_ready:
			return "HIVE 계정 연결 대기"
		return "HIVE 초기화 실패" if _setup_finished else "HIVE 준비 중"
	return "게스트 모드"


func service_detail_text() -> String:
	if not native_available:
		return "로컬 개발 모드"
	var login_text := "로그인 연결됨" if logged_in else ("로그인 선택 가능" if native_ready else ("로그인 설정 확인 필요" if _setup_finished else "로그인 준비 중"))
	var ad_labels := {
		"ready": "보상 광고 준비됨",
		"loading": "보상 광고 준비 중",
		"showing": "보상 광고 재생 중",
		"failed": "보상 광고 확인 필요",
		"unavailable": "보상 광고 준비 전",
	}
	return "%s  ·  %s" % [login_text, String(ad_labels.get(rewarded_ad_state, "보상 광고 준비 전"))]


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value))
	return true
