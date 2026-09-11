extends Node
## Headless protocol tests. No native store, credentials or network calls.
const Billing = preload("res://scripts/BillingService.gd")
const Platform = preload("res://scripts/PlatformService.gd")

class FakePlatform extends Node:
	signal ranking_auth_ready(id: int, success: bool, json: String)
	signal billing_event(kind: String, json: String)
	signal login_changed(ok: bool, pid: String)
	var config := {"ranking": {"api_base_url": "https://example.invalid"}}
	var logged_in := true
	var player_id := "10"
	var kind := "ios"
	var calls: Array = []
	func billing_platform() -> String: return kind
	func billing_app_id() -> String: return "com.jellymontest.game" if kind == "ios" else "com.jellymon.game"
	func billing_store_name() -> String: return "App Store" if kind == "ios" else "Google Play"
	func billing_available() -> bool: return logged_in
	func billing_call(method: String, args: Array = []) -> void: calls.append([method, args])
	func prepare_ranking_auth(_id: int) -> void: pass

class IOSPlatform extends Platform:
	func billing_platform() -> String: return "ios"

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func response(billing: Node, data: Dictionary, code: int = 200) -> void:
	billing._on_response(HTTPRequest.RESULT_SUCCESS, code, PackedStringArray(), JSON.stringify(data).to_utf8_buffer())
func event(platform: Node, kind: String, data: Dictionary) -> void:
	data["player_id"] = platform.player_id
	platform.billing_event.emit(kind, JSON.stringify(data))
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var ios := IOSPlatform.new()
	ios.config = {"ios": {"bundle_id": "bundle", "hive_app_id": "hive-app"}}
	check(ios.billing_app_id() == "hive-app", "iOS uses configured Hive App ID")
	ios.config.ios.erase("hive_app_id")
	check(ios.billing_app_id() == "bundle", "Existing bundle ID configuration remains compatible")
	ios.free()
	for kind in ["ios", "android"]:
		var platform := FakePlatform.new()
		platform.kind = kind
		add_child(platform)
		var save := SaveGame.new()
		save.persistence_enabled = false
		save.storage_path = "/private/tmp/jellymon-billing-client-%s-%d.json" % [kind, Time.get_ticks_usec()]
		var billing := Billing.new()
		add_child(billing)
		billing.configure(platform, save)
		billing._install = "a".repeat(32)
		save.persistence_enabled = true
		var item := ShopCatalog.item_by_id("stardust_50").duplicate(true)
		item.ios_product_id = "ios.different.sku"
		var sku: String = item.ios_product_id if kind == "ios" else item.android_product_id
		billing.refresh()
		event(platform, "products", {"products": [{"sku": sku, "price": "$0.99"}]})
		check(billing.price(item) == "$0.99", "Use actual localized store price and platform SKU")
		response(billing, {"entitlements": []})
		check(platform.calls.back()[0] == "billingRestore", "Refresh restores pending purchases")
		event(platform, "receipts", {"receipts": []})
		check(not billing.busy, "Empty restore completes")
		billing.purchase(item)
		check(billing._data.sku == sku, "Order uses platform SKU")
		response(billing, {"sku": sku, "payload": "server-order"})
		check(platform.calls.back() == ["billingPurchase", [sku, "server-order"]], "Purchase forwards server payload unchanged")
		event(platform, "receipts", {"receipts": [{"sku": sku, "receipt": "opaque"}]})
		check(save.stardust == 0 and billing._action == "verify", "Native receipt alone never grants currency")
		var grant := {"sku": sku, "transaction_id": "test_" + kind, "item": item, "season": "", "delivered": false}
		response(billing, grant)
		check(save.stardust == 50 and billing._action == "ack", "Persist reward before server ACK")
		check(platform.calls.back()[0] != "billingFinish", "Do not finish before ACK")
		response(billing, {"sku": sku, "transaction_id": grant.transaction_id})
		check(platform.calls.back() == ["billingFinish", [sku]], "ACK permits native finish")
		event(platform, "finished", {"sku": "wrong"})
		check(billing.busy, "Ignore unrelated completion")
		event(platform, "finished", {"sku": sku})
		check(not billing.busy, "Matching completion ends purchase")
		event(platform, "receipts", {"receipts": [{"sku": sku, "receipt": "late"}]})
		check(not billing.busy and save.stardust == 50, "Ignore unsolicited late receipts")
		billing.refresh()
		event(platform, "products", {"products": [{"sku": sku, "price": "$0.99"}]})
		response(billing, {"entitlements": []})
		event(platform, "receipts", {"receipts": [{"sku": sku, "receipt": "retry"}]})
		response(billing, grant) # Same transaction after lost ACK: local journal deduplicates.
		check(save.stardust == 50, "Retry does not duplicate persisted currency")
		response(billing, {"sku": sku, "transaction_id": "wrong"})
		check(not billing.busy and platform.calls.back()[0] != "billingFinish", "Mismatched ACK cannot finish")
		billing.refresh()
		billing._fail("timeout")
		event(platform, "products", {"products": [{"sku": sku, "price": "late"}]})
		check(billing.price(item) == "$0.99", "Ignore late native callback after timeout")
		platform.player_id = "11"
		platform.login_changed.emit(false, "")
		check(billing.prices.is_empty() and not billing.busy, "Account change clears purchase state")
		billing.free()
		platform.free()
		DirAccess.remove_absolute(save.storage_path)
	print("[billing client] failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
