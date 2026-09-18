extends Node
const Ranking = preload("res://scripts/RankingService.gd")
const Billing = preload("res://scripts/BillingService.gd")
class Storage extends SaveGame:
	var record := {"level": 3, "stars": 3, "achieved_at_ms": 123456789, "nickname": "Test"}
	func three_star_ranking_record() -> Dictionary: return record.duplicate()
class Platform extends Node:
	signal ranking_auth_ready(id: int, success: bool, data: String)
	signal login_changed(ok: bool, id: String)
	signal billing_event(kind: String, data: String)
	var config := {"app_id": "test", "ranking": {"api_base_url": "https://example.invalid"}}
	var logged_in := false
	var native_available := true
	var cloud_restore_pending := false
	var account_disconnect_pending := false
	var player_id := "123"
	var auth_calls := 0
	var native_calls: Array = []
	func prepare_ranking_auth(_id: int) -> void: auth_calls += 1
	func billing_available() -> bool: return logged_in
	func billing_platform() -> String: return "android"
	func billing_store_name() -> String: return "Google Play"
	func billing_call(method: String, _args: Array) -> void: native_calls.append(method)
func _ready() -> void: call_deferred("run")
func run() -> void:
	var p := Platform.new()
	add_child(p)
	var s := Storage.new()
	s.storage_path = "/tmp/jellymon-auth-call-test.json"
	s.hive_record_owner = "123"
	s.persistence_enabled = true
	DirAccess.remove_absolute(s.storage_path + ".ranking-ack")
	var r := Ranking.new()
	add_child(r)
	r.configure(p, s)
	p.logged_in = true
	r.sync_record()
	r.sync_record()
	assert(p.auth_calls == 0 and not r._batch.is_stopped(), "Batch rapid updates")
	r.sync_record(true)
	assert(p.auth_calls == 1)
	r._on_write(HTTPRequest.RESULT_SUCCESS, 202, PackedStringArray(), PackedByteArray())
	r.sync_record(true)
	assert(p.auth_calls == 1, "202 accepted must not reauthenticate")
	r.free()
	r = Ranking.new()
	add_child(r)
	r.configure(p, s)
	r.sync_record(true)
	assert(p.auth_calls == 1, "Accepted record survives restart")
	s.record.level = 4
	r.sync_record(true)
	assert(p.auth_calls == 2)
	r._on_write(HTTPRequest.RESULT_SUCCESS, 401, PackedStringArray(), PackedByteArray())
	r.sync_record(true)
	assert(p.auth_calls == 2 and r._retry.is_stopped(), "401 waits for login")
	r._on_login(true, p.player_id)
	r.sync_record(true)
	assert(p.auth_calls == 3)
	r._on_write(HTTPRequest.RESULT_SUCCESS, 503, PackedStringArray(), PackedByteArray())
	assert(r._retry.time_left >= 59 and r._retry_seconds == 120)
	r.sync_record(true)
	assert(p.auth_calls == 3, "Failure backoff prevents rapid retries")
	r.free()
	DirAccess.remove_absolute(s.storage_path + ".ranking-ack")
	var b := Billing.new()
	add_child(b)
	s.persistence_enabled = false
	b.configure(p, s)
	s.persistence_enabled = true
	b._install = "01234567890123456789012345678901"
	b.refresh(true)
	var products := JSON.stringify({"player_id": "123", "products": [{"sku": "dust", "price": "1000"}]})
	b._on_native("products", products)
	assert(b._action == "entitlements" and p.auth_calls == 4)
	b._on_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), '{"entitlements":[]}'.to_utf8_buffer())
	b._on_native("receipts", '{"player_id":"123","receipts":[]}')
	assert(not b.busy and not b._recovery_needed)
	var native_count: int = p.native_calls.size()
	b.refresh()
	assert(p.native_calls.size() == native_count and p.auth_calls == 4, "Repeated shop open uses price cache")
	b._last_refresh_ms = Time.get_ticks_msec() - b.REFRESH_CACHE_MS
	b.refresh()
	b._on_native("products", products)
	assert(not b.busy and p.auth_calls == 4, "Expired prices refresh without entitlements auth")
	b.refresh(true)
	b._on_native("products", products)
	assert(p.auth_calls == 5 and b._action == "entitlements", "Explicit restore bypasses cache")
	b._fail("test")
	b.purchase({"android_product_id": "dust"})
	assert(b._recovery_needed and b._action == "order")
	b._fail("test purchase interruption")
	b.refresh()
	b._on_native("products", products)
	assert(b._action == "entitlements", "Interrupted purchase must recover")
	b.free()
	p.free()
	print("PASS: ranking batch, durable 202, 401 pause, backoff, price cache, explicit restore, purchase recovery")
	get_tree().quit()
