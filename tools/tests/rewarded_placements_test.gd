extends Node
const Save = preload("res://scripts/SaveGame.gd")
const Offer = preload("res://scripts/RewardedOffer.gd")
class Host extends Node:
	var save = Save.new()
	var reward: Callable
	var unavailable: Callable
	var calls := 0
	func request_rewarded_ad(r: Callable, u: Callable, _p: String) -> void:
		calls += 1
		reward = r
		unavailable = u
var delivered := 0
var closed := 0
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var h := Host.new()
	h.save.persistence_enabled = false
	add_child(h)
	assert(h.save.rewarded_remaining("unknown") == 0)
	var o := Offer.new()
	add_child(o)
	o.open(h, "home_gift", "Test", func(): delivered += 1, func(): closed += 1)
	var before: int = h.save.stardust
	o._watch()
	o._watch()
	assert(h.calls == 1, "Only one outstanding ad")
	h.unavailable.call()
	assert(h.save.stardust == before and h.save.rewarded_remaining("home_gift") == 1)
	o._watch()
	h.reward.call()
	h.reward.call()
	assert(delivered == 1 and closed == 1, "Duplicate reward callback must not duplicate grants")
	assert(h.save.stardust == before + 5 and h.save.rewarded_remaining("home_gift") == 0)
	await get_tree().process_frame
	var energy_before: int = h.save.get_energy()
	for i in range(3): assert(h.save.claim_rewarded_placement("energy_refill"))
	assert(not h.save.claim_rewarded_placement("energy_refill"))
	assert(h.save.get_energy() == energy_before + 3)
	var inventory: Dictionary = h.save.booster_inventory.duplicate()
	assert(h.save.claim_rewarded_placement("booster_time"))
	assert(h.save.claim_rewarded_placement("booster_time"))
	assert(not h.save.claim_rewarded_placement("booster_time"))
	assert(h.save.booster_inventory == inventory, "Temporary effect must not mint inventory")
	h.save.rewarded_daily["home_gift"] = {"date":"2000-01-01", "count":1}
	assert(h.save.rewarded_remaining("home_gift") == 1)
	h.save.rewarded_daily["home_gift"] = {"date":"2099-01-01", "count":1}
	assert(h.save.rewarded_remaining("home_gift") == 0)
	h.save.persistence_enabled = true
	h.save.storage_path = "/tmp/jellymon-rewarded-test-save.json"
	h.save.save_data()
	var restored = Save.new()
	restored.storage_path = h.save.storage_path
	restored.load_data()
	assert(restored.rewarded_remaining("energy_refill") == 0, "Quota persists on restart")
	assert(restored.rewarded_remaining("home_gift") == 0)
	DirAccess.remove_absolute(h.save.storage_path)
	h.free()
	print("PASS: opt-in deduplication, failure retry, daily quotas, date rollover, persistence, temporary booster")
	get_tree().quit()
