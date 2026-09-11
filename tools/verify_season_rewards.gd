extends Node
const Catalog = preload("res://scripts/RetentionCatalog.gd")
const Shop = preload("res://scripts/ShopCatalog.gd")
class Fixture extends "res://scripts/Main.gd":
	func _ready() -> void: pass
var errors: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
func buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node == null: return result
	if node is Button: result.append(node)
	for child in node.get_children(): result.append_array(buttons(child))
	return result
func _ready() -> void: call_deferred("run")
func run() -> void:
	var main := Fixture.new()
	main.save.persistence_enabled = false
	main.save.storage_path = "user://nonexistent-season-regression-save.json"
	add_child(main)
	main._initialize_runtime()
	var save = main.save
	save.refresh_season()
	for i in range(9): save.stars[str(i)] = 3
	save.ads_removed = true
	check(save.home_feature_unlocked("shop") and not save.home_feature_unlocked("lifestyle"), "L10 fixture gates")
	main.show_title()
	await get_tree().process_frame
	main.current_screen._show_shop_popup()
	var vip_count := 0
	for button in buttons(main.current_screen.shop_popup):
		if not button.has_meta("vip_daily_support"): continue
		vip_count += 1
		var before: int = save.stardust
		var boosters: int = save.get_booster_count("time")
		button.pressed.emit()
		check(button.disabled and save.stardust == before + 8 and save.get_booster_count("time") == boosters + 1, "VIP shop claim")
		button.pressed.emit()
		check(save.stardust == before + 8, "VIP duplicate rejected")
	check(vip_count == 1, "VIP visible at L10")
	main.current_screen._close_shop_popup()
	check(save.claim_retention_season_reward(1, true).is_empty(), "premium ownership required")
	check(save.apply_verified_shop_item(Shop.item_by_id("season_heart_star_pass")), "buy premium")
	check(save.claim_retention_season_reward(5, true).is_empty(), "future reward locked")
	check(save.claim_retention_season_reward(1, false).is_empty(), "absent free reward rejected")
	main.current_screen._show_lifestyle_popup()
	var first: Button
	var displayed := 0
	for button in buttons(main.current_screen.lifestyle_popup):
		if not button.has_meta("season_reward_level") or not button.visible: continue
		displayed += 1
		if int(button.get_meta("season_reward_level")) == 1 and bool(button.get_meta("premium")): first = button
	check(displayed == 9, "all 9 configured rewards displayed")
	check(first != null and not first.disabled, "premium Lv1 enabled at zero XP")
	if first:
		var before: int = save.stardust
		first.pressed.emit()
		check(save.stardust == before + 40 and save.claimed_season_premium.has(1), "actual UI delivers Lv1 stardust 40")
		check(save.claim_retention_season_reward(1, true).is_empty() and save.stardust == before + 40, "season duplicate rejected")
		for button in buttons(main.current_screen.lifestyle_popup):
			if button.get_meta("season_reward_level", 0) == 1 and button.get_meta("premium", false): check(button.disabled, "claimed UI disabled")
	save.add_season_xp(380)
	for level in Catalog.season_reward_levels():
		for premium in [false, true]:
			var table: Dictionary = Catalog.season().get("premium_rewards" if premium else "free_rewards", {})
			if not table.has(str(level)) or (premium and level == 1): continue
			check(not save.claim_retention_season_reward(level, premium).is_empty(), "configured reward claim %d/%s" % [level, premium])
			check(save.claim_retention_season_reward(level, premium).is_empty(), "configured reward duplicate %d/%s" % [level, premium])
	# Three residents used to select the same resident for every slot.
	for count in [3, 6]:
		save.resident_records.clear()
		for i in range(count): save.register_rescued_jelly(i * 10)
		save.resident_request_date = ""
		save.season_premium = false
		save.refresh_resident_requests()
		check(save.resident_requests.size() == 2, "free request count")
		save.resident_requests[0].progress = 1
		save.resident_requests[0].claimed = true
		var old_id: String = save.resident_requests[0].id
		save.season_premium = true
		save.refresh_resident_requests()
		var ids := {}
		for request in save.resident_requests: ids[request.id] = true
		check(ids.size() == 3 and save.resident_requests.size() == 3, "unique premium requests / same day upgrade")
		check(save.resident_requests[0].id == old_id and save.resident_requests[0].progress == 1 and save.resident_requests[0].claimed, "upgrade preserves progress and claims")
		save.refresh_resident_requests()
		check(save.resident_requests.size() == 3, "refresh idempotent")
		save.season_key = "expired"
		save.resident_request_date = "yesterday"
		save.refresh_resident_requests()
		check(not save.season_premium and save.resident_requests.size() == 2, "expiry checked before daily slots")
	for error in errors: print("FAIL ", error)
	print("[season rewards] failures=", errors.size())
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	main._request_shutdown(0 if errors.is_empty() else 1)
