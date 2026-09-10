extends Node
const Cloud = preload("res://scripts/CloudSaveService.gd")
class FakePlatform extends PlatformService:
	var remote := ""
	var fail_read := false
	var writes := 0
	func load_game_snapshot(id: int) -> void:
		game_snapshot_loaded.emit.call_deferred(id, not fail_read, remote, "DataStoreDisabled" if fail_read else "")
	func save_game_snapshot(id: int, data: Dictionary) -> void:
		writes += 1
		remote = JSON.stringify(data)
		game_snapshot_saved.emit.call_deferred(id, true, "")

func frames() -> void:
	for i in range(8): await get_tree().process_frame

func _ready() -> void:
	var storage := SaveGame.new()
	storage.storage_path = "/tmp/jellymon-cloud-test.json"
	storage.stars = {"5": 3}
	storage.stardust = 50
	storage.nickname = "CloudTest"
	storage.owned_furniture = ["sofa_p"]
	storage.claimed_mail_ids = ["welcome"]
	var p := FakePlatform.new()
	add_child(p)
	p.logged_in = true
	p.native_available = true
	p.player_id = "123"
	p.fail_read = true
	var c := Cloud.new()
	add_child(c)
	c.configure(p, storage)
	await frames()
	assert(p.writes == 0 and storage.stardust == 50)
	p.fail_read = false
	c.sync()
	await frames()
	assert(p.writes == 1 and not storage.cloud_baseline.is_empty())
	assert(Cloud.valid_snapshot(JSON.parse_string(p.remote), "123"))
	assert(not Cloud.valid_snapshot(JSON.parse_string(p.remote), "other"))
	storage.stardust = 30
	storage.save_data()
	c.sync()
	await frames()
	assert(p.writes == 2 and JSON.parse_string(p.remote).data.stardust == 30)
	var new_save := SaveGame.new()
	new_save.storage_path = storage.storage_path
	c.bind_save(new_save)
	c.sync()
	await frames()
	assert(not c._conflict.is_empty() and new_save.stardust == 0)
	c.resolve_conflict(true)
	assert(new_save.stardust == 30 and new_save.owned_furniture == ["sofa_p"])
	var reloaded := SaveGame.new()
	reloaded.storage_path = new_save.storage_path
	reloaded.load_data()
	assert(reloaded.get_stars(5) == 3 and reloaded.cloud_baseline == new_save.cloud_baseline)
	# Changed data on both sides must never be silently merged or overwritten.
	var r: Dictionary = JSON.parse_string(p.remote)
	r.data.stardust = 100
	p.remote = JSON.stringify(r)
	new_save.stardust = 20
	c.sync()
	await frames()
	assert(not c._conflict.is_empty() and p.writes == 2)
	c.resolve_conflict(false)
	await frames()
	assert(p.writes == 3 and JSON.parse_string(p.remote).data.stardust == 20)
	p.fail_read = true
	c.sync()
	var stale_id: int = c._request_id
	p.logged_in = false
	p.login_changed.emit(false, "")
	c._on_loaded(stale_id, true, p.remote, "")
	assert(p.writes == 3 and new_save.stardust == 20)
	DirAccess.remove_absolute(storage.storage_path)
	print("[cloud save] upload/readback, all-field restore, persistent reload, conflict, offline and stale-account guards PASSED")
	get_tree().quit()
