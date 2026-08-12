extends Node
class_name PlatformService
## HIVE SDK를 게임 코드와 분리하는 단일 경계.
## 플러그인이 없는 개발 환경에서는 동일 API의 로컬 폴백으로 안전하게 동작한다.

signal login_changed(logged_in: bool, player_id: String)

const CONFIG_PATH := "res://assets/data/platform_services.json"
const LOCAL_CLOUD_PATH := "user://jellymon_cloud_fallback.json"
const LOCAL_RANK_PATH := "user://jellymon_rank_fallback.json"

var native_available := false
var logged_in := false
var player_id := ""
var config: Dictionary = {}


func initialize() -> void:
	config = _read_json(CONFIG_PATH)
	# HIVE Godot 플러그인 등록 여부만 확인한다. SDK 버전별 메서드는 네이티브
	# 브리지 구현에서 호출하여 게임 코드가 SDK 업데이트에 영향받지 않게 한다.
	native_available = Engine.has_singleton("Hive") or Engine.has_singleton("HIVE")
	if not native_available:
		player_id = "guest_%s" % OS.get_unique_id().substr(0, 10)


func login() -> bool:
	if native_available:
		# 실제 SDK 연결 시 네이티브 브리지가 인증 완료 후 complete_native_login()을 호출한다.
		return false
	logged_in = true
	login_changed.emit(true, player_id)
	return true


func complete_native_login(id: String) -> void:
	player_id = id
	logged_in = not id.is_empty()
	login_changed.emit(logged_in, player_id)


func show_rewarded_ad(on_reward: Callable, on_unavailable: Callable = Callable()) -> void:
	if OS.is_debug_build() and not native_available:
		await get_tree().create_timer(0.65).timeout
		if on_reward.is_valid():
			on_reward.call()
		return
	# 출시 빌드에서는 HIVE 광고 브리지가 시청 완료 콜백을 전달해야 한다.
	if on_unavailable.is_valid():
		on_unavailable.call_deferred()


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
		return "HIVE 연결됨" if native_available else "게스트 저장 연결됨"
	return "HIVE SDK 연결 대기" if native_available else "게스트 모드"


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
