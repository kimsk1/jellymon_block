extends Node
const Save = preload("res://scripts/SaveGame.gd")
const Catalog = preload("res://scripts/ShopCatalog.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		push_error(label)
		failures += 1
func _ready() -> void:
	var save = Save.new()
	save.storage_path = "/private/tmp/jellymon-iap-save-test.json"
	save.stardust = 0
	var dust := Catalog.item_by_id("stardust_50")
	check(save.apply_iap_delivery("tx1", dust, ""), "first purchase")
	check(save.stardust == 50, "reward amount")
	check(save.apply_iap_delivery("tx1", dust, "") and save.stardust == 50, "duplicate purchase")
	var reloaded = Save.new()
	reloaded.storage_path = save.storage_path
	reloaded.load_data()
	check(reloaded.apply_iap_delivery("tx1", dust, "") and reloaded.stardust == 50, "durable duplicate protection")
	var before := reloaded.to_dictionary().duplicate(true)
	reloaded.storage_path = "/does-not-exist/jellymon-iap.json"
	check(not reloaded.apply_iap_delivery("tx2", dust, ""), "failed disk write")
	check(before == reloaded.to_dictionary(), "failed write rolls back reward and marker")
	save.stardust = 0
	var pack := Catalog.item_by_id("starter_rescue_pack")
	check(save.apply_iap_delivery("entitlement", pack, "", true), "restore entitlement")
	check(save.stardust == 0 and save.has_furniture("sofa_p") and save.has_purchased_shop_item("starter_rescue_pack"), "restore excludes pack currency")
	var cloud := save.cloud_data()
	check(not cloud.has("iap_transactions"), "cloud excludes device transaction journal")
	var season := str(int(Time.get_unix_time_from_system()) / (28 * 86400))
	check(not save.apply_iap_delivery("old_season", Catalog.item_by_id("season_heart_star_pass"), "0"), "expired season cannot grant current premium")
	check(save.apply_iap_delivery("season", Catalog.item_by_id("season_heart_star_pass"), season), "current season grant")
	DirAccess.remove_absolute(save.storage_path)
	print("Billing save checks: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
