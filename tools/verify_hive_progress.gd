extends Node
const Sync = preload("res://scripts/AdventureCloudSync.gd")
class FakePlatform extends Node:
	signal login_changed(logged_in: bool, player_id: String)
	signal adventure_record_loaded(id: int, success: bool, json: String, message: String)
	signal adventure_record_saved(id: int, success: bool, message: String)
	var logged_in := true
	var native_available := true
	var player_id := "test_player"
	var message := ""
	var reads: Array[int] = []
	var writes: Array = []
	func load_adventure_record(id: int) -> void: reads.append(id)
	func save_adventure_record(id: int, data: Dictionary) -> void: writes.append([id, data.duplicate(true)])
	func set_cloud_message(value: String) -> void: message = value

var errors: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var save := SaveGame.new()
	save.storage_path = "res://output/hive-progress/test-save.json"
	save.stars = {"2": 3, "8": 1}
	save.best_clear_times = {"8": 42.37}
	var legacy := save.adventure_record()
	check(legacy.highest_cleared_level == 9 and legacy.best_clear_ms == 42370 and legacy.best_cleared_at_unix == 0, "Legacy record must not invent a timestamp")
	check(not save.record_clear_time(8, NAN) and not save.record_clear_time(8, INF) and not save.record_clear_time(8, -1), "Invalid times rejected")
	check(not save.record_clear_time(8, 48), "Slower run must preserve best")
	check(save.record_clear_time(8, 39.21), "Faster run accepted")
	var best := save.adventure_record()
	check(best.best_clear_ms == 39210 and best.best_cleared_at_unix > 0, "Best duration and timestamp paired")
	save.record_clear_time(2, 1)
	check(save.adventure_record() == best, "Lower level must not replace highest record")
	var restored := SaveGame.new()
	restored.storage_path = save.storage_path
	restored.load_data()
	check(restored.adventure_record() == best, "Record persists through restart")
	var higher := best.duplicate()
	higher.highest_cleared_level = 10
	higher.best_clear_ms = 99999
	check(Sync.preferred_record(best, higher) == higher, "Higher cloud level wins even when slower")
	check(Sync.preferred_record(legacy, best) == best, "Faster cloud time wins")
	check(not Sync.valid_record({}) and not Sync.valid_record({"schema_version":1,"highest_cleared_level":-1}), "Malformed remote rejected")
	var platform := FakePlatform.new()
	get_tree().root.add_child(platform)
	var sync := Sync.new()
	get_tree().root.add_child(sync)
	sync.configure(platform, restored)
	check(platform.reads.size() == 1 and restored.hive_record_owner == platform.player_id, "Login sync and owner binding")
	var id: int = platform.reads.back()
	platform.adventure_record_loaded.emit(id, false, "", "network")
	check(platform.writes.is_empty() and not sync._retry.is_stopped(), "Failed read never overwrites cloud, retries")
	sync.sync()
	id = platform.reads.back()
	platform.adventure_record_loaded.emit(id, true, "", "")
	check(platform.writes.size() == 1 and platform.writes.back()[1] == best, "Absent key uploads existing best")
	platform.adventure_record_saved.emit(id, true, "")
	check(sync._busy and sync._verifying, "Write success requires readback")
	platform.adventure_record_loaded.emit(id, true, JSON.stringify(best), "")
	check(not sync._busy and platform.message.contains("저장 확인"), "Readback verifies stored record")
	sync.sync()
	id = platform.reads.back()
	platform.adventure_record_loaded.emit(id, true, JSON.stringify(higher), "")
	check(platform.writes.size() == 1 and platform.message.contains("10"), "Never downgrades higher cloud record")
	sync.sync()
	id = platform.reads.back()
	platform.adventure_record_loaded.emit(id, true, "broken", "")
	check(platform.writes.size() == 1, "Malformed cloud never overwritten")
	# 저장 중 새 최고 기록이 생겨도 응답 대기 때문에 누락되면 안 된다.
	sync.sync()
	id = platform.reads.back()
	platform.adventure_record_loaded.emit(id, true, "", "")
	restored.stars["9"] = 1
	restored.record_clear_time(9, 55)
	var latest := restored.adventure_record()
	sync.sync()
	platform.adventure_record_saved.emit(id, true, "")
	platform.adventure_record_loaded.emit(id, true, JSON.stringify(best), "")
	check(platform.writes.back()[1] == latest, "Clear during in-flight upload is not lost")
	platform.adventure_record_saved.emit(id, false, "write_failed")
	check(not sync._busy and not sync._retry.is_stopped(), "Failed write remains retryable")
	sync.sync()
	id = platform.reads.back()
	platform.adventure_record_loaded.emit(id, true, "", "")
	var writes_before_verify := platform.writes.size()
	platform.adventure_record_saved.emit(id, true, "")
	platform.adventure_record_loaded.emit(id, true, "", "")
	check(platform.writes.size() == writes_before_verify and not sync._busy, "Unconfirmed write must back off, not loop forever")
	var writes_before_switch := platform.writes.size()
	platform.player_id = "other_account"
	platform.login_changed.emit(true, platform.player_id)
	platform.adventure_record_loaded.emit(id, true, "", "")
	check(platform.writes.size() == writes_before_switch and platform.message.contains("다른 계정"), "Account isolation and stale callback ignored")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.storage_path))
	if errors.is_empty(): print("[Hive progress] record migration, best time, persistence, read/write verification, retry and account isolation PASSED")
	for error in errors: push_error(error)
	get_tree().quit(0 if errors.is_empty() else 1)
