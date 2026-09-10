extends RefCounted
class_name SaveGame
## 진행도 저장 (user://jellymon_save.json)

const RoomDataLib = preload("res://scripts/RoomData.gd")
const FurnitureRewardCatalogLib = preload("res://scripts/FurnitureRewardCatalog.gd")
const DailyMissionCatalogLib = preload("res://scripts/DailyMissionCatalog.gd")
const LiveProgressionCatalogLib = preload("res://scripts/LiveProgressionCatalog.gd")
const CharacterCatalogLib = preload("res://scripts/CharacterCatalog.gd")
const GameBalanceCatalogLib = preload("res://scripts/GameBalanceCatalog.gd")
const MetaProgressionCatalogLib = preload("res://scripts/MetaProgressionCatalog.gd")
const ShopCatalogLib = preload("res://scripts/ShopCatalog.gd")
const RetentionCatalogLib = preload("res://scripts/RetentionCatalog.gd")

signal data_saved
var cloud_baseline := ""

const PATH := "user://jellymon_save.json"
const MAX_ENERGY := 5
const ENERGY_REGEN_SECONDS := 10 * 60
const ROOM_GRID_VERSION := 2
const ATTENDANCE_DAYS_PER_WEEK := 7
const ATTENDANCE_WEEK1_STARDUST := [10, 20, 30, 40, 50, 60, 100]
const ATTENDANCE_WEEK1_ENERGY := [5, 5, 5, 5, 5, 5, 5]
const ATTENDANCE_REPEAT_STARDUST := [10, 0, 15, 0, 20, 0, 20]
const ATTENDANCE_REPEAT_ENERGY := [0, 5, 0, 7, 0, 10, 10]
const MAX_NICKNAME_LENGTH := 12
const LEVEL_GATE_SIZE := 100
const HOME_FEATURE_LEVELS := {
	"attendance": 3,
	"decorate": 4,
	"album": 5,
	"missions": 6,
	"shop": 10,
	"lifestyle": 15,
}

var stars := {}
var best_clear_times := {}
var best_clear_at := {}
var three_star_first_at_ms := {}
var hive_record_owner := ""
var stardust := 0
var room_placements: Array = []
var room_theme_id := RoomDataLib.DEFAULT_ROOM_THEME
# Tests can isolate persistence without touching the player save.
var storage_path := PATH
var owned_furniture: Array[String] = []
var claimed_furniture_reward_levels: Array[int] = []
var room_grid_version := ROOM_GRID_VERSION
var rescued_jellies: Array[String] = []
var resident_records: Array = []
var resident_relationships := {}
var album_memories: Array = []
var attendance_claimed_days := 0
var attendance_last_claim_date := ""
var ads_removed := false
var claimed_shop_items: Array[String] = []
var iap_transactions: Dictionary = {}
var vip_reward_skip_date := ""
var vip_daily_support_date := ""
var nickname := ""
var seen_scenarios: Array[String] = []
var completed_tutorials: Array[String] = []
var energy := MAX_ENERGY
var energy_updated_at := 0
var daily_mission_date := ""
var daily_mission_progress := {}
var daily_mission_claimed := false
var daily_challenge_date := ""
var jelly_capture_counts := {}
var shiny_discoveries: Array[String] = []
var claimed_dex_milestones: Array[int] = []
var sound_enabled := true
var haptics_enabled := true
var notifications_enabled := true
var language := "system"
var claimed_mail_ids: Array[String] = []
var booster_inventory := {"time": 2, "compass": 2, "ice": 1, "space": 1, "rescue": 1}
var weekly_key := ""
var weekly_progress := {}
var weekly_claimed := false
var weekly_expedition_step := 0
var weekly_expedition_claimed := false
var claimed_season_milestones: Array[int] = []
var unlocked_level_segments: Array[int] = [0]
var persistence_enabled := true
var resident_request_date := ""
var resident_requests: Array = []
var season_key := ""
var season_xp := 0
var season_premium := false
var claimed_season_free: Array[int] = []
var claimed_season_premium: Array[int] = []
var restoration_points := 0
var town_levels := {}
var weekly_activity_best := 0.0
var consecutive_failures := 0
var beta_feedback_submitted := false


func cleared_level_count() -> int:
	var count := 0
	for value in stars.values():
		if int(value) > 0:
			count += 1
	return count


func home_feature_unlocked(feature_id: String) -> bool:
	var required_level := int(HOME_FEATURE_LEVELS.get(feature_id, 1))
	if required_level <= 1:
		return true
	return get_stars(required_level - 2) > 0


func home_feature_unlock_level(feature_id: String) -> int:
	return int(HOME_FEATURE_LEVELS.get(feature_id, 1))


func load_data() -> void:
	if FileAccess.file_exists(storage_path):
		var f := FileAccess.open(storage_path, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if typeof(d) == TYPE_DICTIONARY:
				iap_transactions = d.get("iap_transactions", {})
				stars = d.get("stars", {})
				best_clear_times = d.get("best_clear_times", {})
				best_clear_at = d.get("best_clear_at", {})
				three_star_first_at_ms = d.get("three_star_first_at_ms", {})
				hive_record_owner = String(d.get("hive_record_owner", ""))
				cloud_baseline = String(d.get("cloud_baseline", ""))
				stardust = maxi(0, int(d.get("stardust", 0)))
				room_placements = d.get("room_placements", [])
				room_theme_id = String(RoomDataLib.room_theme(String(d.get("room_theme_id", RoomDataLib.DEFAULT_ROOM_THEME))).id)
				for raw_id in d.get("owned_furniture", []):
					var furniture_id := String(raw_id)
					if not furniture_id.is_empty() and not owned_furniture.has(furniture_id):
						owned_furniture.append(furniture_id)
				for raw_level in d.get("claimed_furniture_reward_levels", []):
					var reward_level := int(raw_level)
					if reward_level > 0 and not claimed_furniture_reward_levels.has(reward_level):
						claimed_furniture_reward_levels.append(reward_level)
				room_grid_version = int(d.get("room_grid_version", 1))
				# 구버전의 0~7일 기록을 그대로 이어받고, 이후에는 주차 제한 없이 누적한다.
				attendance_claimed_days = maxi(0, int(d.get("attendance_claimed_days", 0)))
				attendance_last_claim_date = String(d.get("attendance_last_claim_date", ""))
				ads_removed = bool(d.get("ads_removed", false))
				for raw_shop_id in d.get("claimed_shop_items", []):
					var shop_id := String(raw_shop_id)
					if not shop_id.is_empty() and not claimed_shop_items.has(shop_id):
						claimed_shop_items.append(shop_id)
				vip_reward_skip_date = String(d.get("vip_reward_skip_date", ""))
				vip_daily_support_date = String(d.get("vip_daily_support_date", ""))
				nickname = String(d.get("nickname", ""))
				for scenario_id in d.get("seen_scenarios", []):
					var value := String(scenario_id)
					if not value.is_empty() and not seen_scenarios.has(value):
						seen_scenarios.append(value)
				for tutorial_id in d.get("completed_tutorials", []):
					var completed_id := String(tutorial_id)
					if not completed_id.is_empty() and not completed_tutorials.has(completed_id):
						completed_tutorials.append(completed_id)
				for color in d.get("rescued_jellies", []):
					if G.COLORS.has(String(color)) and not rescued_jellies.has(String(color)) and rescued_jellies.size() < 6:
						rescued_jellies.append(String(color))
				var loaded_residents = d.get("resident_records", [])
				if loaded_residents is Array:
					resident_records = loaded_residents.duplicate(true)
				resident_relationships = d.get("resident_relationships", {})
				var loaded_memories = d.get("album_memories", [])
				if loaded_memories is Array:
					album_memories = loaded_memories.duplicate(true)
				# 구매한 보너스 하트는 최대치 5를 넘어 보유할 수 있다.
				energy = maxi(0, int(d.get("energy", MAX_ENERGY)))
				energy_updated_at = int(d.get("energy_updated_at", _now()))
				daily_mission_date = String(d.get("daily_mission_date", ""))
				daily_mission_progress = d.get("daily_mission_progress", {})
				daily_mission_claimed = bool(d.get("daily_mission_claimed", false))
				daily_challenge_date = String(d.get("daily_challenge_date", ""))
				jelly_capture_counts = d.get("jelly_capture_counts", {})
				for raw_color in d.get("shiny_discoveries", []):
					var shiny_color := String(raw_color)
					if G.COLORS.has(shiny_color) and not shiny_discoveries.has(shiny_color):
						shiny_discoveries.append(shiny_color)
				for raw_count in d.get("claimed_dex_milestones", []):
					var milestone_count := int(raw_count)
					if milestone_count > 0 and not claimed_dex_milestones.has(milestone_count):
						claimed_dex_milestones.append(milestone_count)
				sound_enabled = bool(d.get("sound_enabled", true))
				haptics_enabled = bool(d.get("haptics_enabled", true))
				notifications_enabled = bool(d.get("notifications_enabled", true))
				language = String(d.get("language", "system"))
				for raw_mail_id in d.get("claimed_mail_ids", []):
					var mail_id := String(raw_mail_id)
					if not mail_id.is_empty() and not claimed_mail_ids.has(mail_id):
						claimed_mail_ids.append(mail_id)
				var loaded_boosters = d.get("booster_inventory", {})
				if loaded_boosters is Dictionary:
					for booster_id in booster_inventory:
						booster_inventory[booster_id] = maxi(0, int(loaded_boosters.get(booster_id, booster_inventory[booster_id])))
				weekly_key = String(d.get("weekly_key", ""))
				weekly_progress = d.get("weekly_progress", {})
				weekly_claimed = bool(d.get("weekly_claimed", false))
				weekly_expedition_step = clampi(int(d.get("weekly_expedition_step", 0)), 0, 5)
				weekly_expedition_claimed = bool(d.get("weekly_expedition_claimed", false))
				for raw_milestone in d.get("claimed_season_milestones", []):
					var season_star := int(raw_milestone)
					if season_star > 0 and not claimed_season_milestones.has(season_star):
						claimed_season_milestones.append(season_star)
				for raw_segment in d.get("unlocked_level_segments", [0]):
					var segment := int(raw_segment)
					if segment >= 0 and not unlocked_level_segments.has(segment):
						unlocked_level_segments.append(segment)
				resident_request_date = String(d.get("resident_request_date", ""))
				resident_requests = d.get("resident_requests", []).duplicate(true)
				season_key = String(d.get("season_key", ""))
				season_xp = maxi(0, int(d.get("season_xp", 0)))
				season_premium = bool(d.get("season_premium", false))
				for value in d.get("claimed_season_free", []): claimed_season_free.append(int(value))
				for value in d.get("claimed_season_premium", []): claimed_season_premium.append(int(value))
				restoration_points = maxi(0, int(d.get("restoration_points", 0)))
				town_levels = d.get("town_levels", {}).duplicate(true)
				weekly_activity_best = maxf(0.0, float(d.get("weekly_activity_best", 0.0)))
				consecutive_failures = maxi(0, int(d.get("consecutive_failures", 0)))
				beta_feedback_submitted = bool(d.get("beta_feedback_submitted", false))
	if energy_updated_at <= 0:
		energy_updated_at = _now()
	# 구버전 저장 데이터도 기본 지급 4종만 소유한 상태에서 시작한다.
	for starter_id in RoomDataLib.STARTER_ITEM_IDS:
		if not owned_furniture.has(starter_id):
			owned_furniture.append(starter_id)
	_sync_shop_entitlement_rewards()
	_sync_furniture_milestone_rewards()
	# 빈 배열도 유효한 사용자 배치다. 신규 방은 비워 두고 시작 가구는 보관함에 지급한다.
	if room_grid_version < ROOM_GRID_VERSION:
		# 6×5 구형 방의 화면상 위치를 유지한 채 새 왼쪽 열만 추가한다.
		for placement in room_placements:
			placement["x"] = int(placement.get("x", 0)) + 1
		room_grid_version = ROOM_GRID_VERSION
		save_data()
	# 구버전 저장 파일은 주민 목록이 없으므로 완료한 챕터 기록에서 최대 6마리를 복원한다.
	if rescued_jellies.is_empty() and not stars.is_empty():
		var chapter_colors := ["R", "Y", "B", "G", "P", "O"]
		for chapter in range(6):
			for idx in range(chapter * 10, chapter * 10 + 10):
				if get_stars(idx) > 0:
					rescued_jellies.append(chapter_colors[chapter])
					break
	_migrate_resident_records()
	_migrate_level_segments()
	refresh_energy()
	refresh_daily_missions()
	refresh_weekly_progress()
	refresh_resident_requests()
	refresh_season()


func to_dictionary() -> Dictionary:
	return {
		"stars": stars,
		"best_clear_times": best_clear_times,
		"best_clear_at": best_clear_at,
		"three_star_first_at_ms": three_star_first_at_ms,
		"hive_record_owner": hive_record_owner,
		"stardust": stardust,
		"room_placements": room_placements,
		"room_theme_id": room_theme_id,
		"owned_furniture": owned_furniture,
		"claimed_furniture_reward_levels": claimed_furniture_reward_levels,
		"room_grid_version": room_grid_version,
		"rescued_jellies": rescued_jellies,
		"resident_records": resident_records,
		"resident_relationships": resident_relationships,
		"album_memories": album_memories,
		"attendance_claimed_days": attendance_claimed_days,
		"attendance_last_claim_date": attendance_last_claim_date,
		"ads_removed": ads_removed,
		"claimed_shop_items": claimed_shop_items,
		"iap_transactions": iap_transactions,
		"vip_reward_skip_date": vip_reward_skip_date,
		"vip_daily_support_date": vip_daily_support_date,
		"nickname": nickname,
		"seen_scenarios": seen_scenarios,
		"completed_tutorials": completed_tutorials,
		"energy": energy,
		"energy_updated_at": energy_updated_at,
		"daily_mission_date": daily_mission_date,
		"daily_mission_progress": daily_mission_progress,
		"daily_mission_claimed": daily_mission_claimed,
		"daily_challenge_date": daily_challenge_date,
		"jelly_capture_counts": jelly_capture_counts,
		"shiny_discoveries": shiny_discoveries,
		"claimed_dex_milestones": claimed_dex_milestones,
		"sound_enabled": sound_enabled,
		"haptics_enabled": haptics_enabled,
		"notifications_enabled": notifications_enabled,
		"language": language,
		"claimed_mail_ids": claimed_mail_ids,
		"booster_inventory": booster_inventory,
		"weekly_key": weekly_key,
		"weekly_progress": weekly_progress,
		"weekly_claimed": weekly_claimed,
		"weekly_expedition_step": weekly_expedition_step,
		"weekly_expedition_claimed": weekly_expedition_claimed,
		"claimed_season_milestones": claimed_season_milestones,
		"unlocked_level_segments": unlocked_level_segments,
		"resident_request_date": resident_request_date,
		"resident_requests": resident_requests,
		"season_key": season_key,
		"season_xp": season_xp,
		"season_premium": season_premium,
		"claimed_season_free": claimed_season_free,
		"claimed_season_premium": claimed_season_premium,
		"restoration_points": restoration_points,
		"town_levels": town_levels,
		"weekly_activity_best": weekly_activity_best,
		"consecutive_failures": consecutive_failures,
		"beta_feedback_submitted": beta_feedback_submitted,
		}

func cloud_data() -> Dictionary:
	var data := to_dictionary()
	data.erase("hive_record_owner")
	data.erase("iap_transactions") # Device delivery journal must not roll back with a cloud snapshot.
	return data

func apply_cloud_data(data: Dictionary) -> void:
	for key in cloud_data():
		var current = get(key)
		if current is Array:
			current.assign(data[key])
		else:
			set(key, data[key].duplicate(true) if data[key] is Dictionary else data[key])

func save_data() -> bool:
	if not persistence_enabled: return false
	var data := to_dictionary()
	data["cloud_baseline"] = cloud_baseline
	var f := FileAccess.open(storage_path + ".tmp", FileAccess.WRITE)
	if not f: return false
	f.store_string(JSON.stringify(data))
	f.flush()
	var error := f.get_error()
	f.close()
	if error != OK: return false
	if DirAccess.rename_absolute(storage_path + ".tmp", storage_path) == OK:
		data_saved.emit()
		return true
	return false


func _now() -> int:
	return int(Time.get_unix_time_from_system())


func refresh_energy() -> bool:
	## 앱이 꺼져 있던 시간까지 포함해 10분마다 한 칸씩 회복한다.
	var now := _now()
	if energy_updated_at > now:
		energy_updated_at = now
	if energy >= MAX_ENERGY:
		energy_updated_at = now
		return false
	var elapsed := now - energy_updated_at
	var gained: int = elapsed / ENERGY_REGEN_SECONDS
	if gained <= 0:
		return false
	energy = mini(MAX_ENERGY, energy + gained)
	if energy >= MAX_ENERGY:
		energy_updated_at = now
	else:
		energy_updated_at += gained * ENERGY_REGEN_SECONDS
	save_data()
	return true


func get_energy() -> int:
	refresh_energy()
	return energy


func seconds_until_next_energy() -> int:
	refresh_energy()
	if energy >= MAX_ENERGY:
		return 0
	return maxi(1, ENERGY_REGEN_SECONDS - (_now() - energy_updated_at))


func reserve_energy() -> bool:
	## 입장 시 예약 차감하고, 클리어하면 refund_energy()로 반환한다.
	refresh_energy()
	if energy <= 0:
		return false
	if energy >= MAX_ENERGY:
		energy_updated_at = _now()
	energy -= 1
	save_data()
	return true


func refund_energy() -> void:
	refresh_energy()
	# 예약 전에 보너스 하트를 보유했다면 클리어 환급 후에도 같은 수량을 복원한다.
	energy += 1
	if energy >= MAX_ENERGY:
		energy_updated_at = _now()
	save_data()


func get_stars(idx: int) -> int:
	return int(stars.get(str(idx), 0))


func set_stars(idx: int, n: int) -> void:
	award_stars(idx, n)


func get_best_clear_time(idx: int) -> float:
	return maxf(0.0, float(best_clear_times.get(str(idx), 0.0)))


func record_clear_time(idx: int, elapsed_seconds: float) -> bool:
	## 비정상 값은 버리고, 레벨별 가장 빠른 실제 플레이 시간만 영구 저장한다.
	if idx < 0 or not is_finite(elapsed_seconds) or elapsed_seconds <= 0.0:
		return false
	var elapsed := snappedf(maxf(0.01, elapsed_seconds), 0.01)
	var previous := get_best_clear_time(idx)
	if previous > 0.0 and elapsed >= previous:
		return false
	best_clear_times[str(idx)] = elapsed
	best_clear_at[str(idx)] = int(Time.get_unix_time_from_system())
	save_data()
	return true


func adventure_record() -> Dictionary:
	var highest := -1
	for key in stars:
		if int(stars[key]) > 0:
			highest = maxi(highest, int(String(key)))
	return {
		"schema_version": 1,
		"highest_cleared_level": highest + 1,
		"best_clear_ms": roundi(get_best_clear_time(highest) * 1000.0) if highest >= 0 else 0,
		"best_cleared_at_unix": int(best_clear_at.get(str(highest), 0)) if highest >= 0 else 0,
	}


func record_three_star_clear(idx: int, achieved_stars: int) -> bool:
	# 이미 3성인 구버전 기록도 실제 재클리어 때만 달성 시각을 새로 확보한다.
	if idx < 0 or achieved_stars != 3 or three_star_first_at_ms.has(str(idx)):
		return false
	three_star_first_at_ms[str(idx)] = int(Time.get_unix_time_from_system() * 1000.0)
	save_data()
	return true


func three_star_ranking_record() -> Dictionary:
	var highest := -1
	for key in three_star_first_at_ms:
		if get_stars(int(String(key))) == 3 and int(three_star_first_at_ms[key]) > 0:
			highest = maxi(highest, int(String(key)))
	if highest < 0:
		return {}
	return {"level": highest + 1, "stars": 3,
		"achieved_at_ms": int(three_star_first_at_ms[str(highest)]),
		"nickname": get_nickname()}


func award_stars(idx: int, n: int, reward_cap: int = -1) -> int:
	## 처음 달성한 별 단계만 지급한다. 1/2/3단계 보상은 각각 별가루 1/2/3개다.
	## 예: 기존 1성에서 3성으로 갱신하면 2+3=5개를 한 번에 받는다.
	var previous := get_stars(idx)
	var achieved := clampi(n, 0, 3)
	if achieved <= previous:
		return 0
	var reward := calculate_stardust_reward(previous, achieved)
	if reward_cap >= 0:
		reward = mini(reward, reward_cap)
	stars[str(idx)] = achieved
	stardust += reward
	save_data()
	return reward


static func calculate_stardust_reward(previous: int, achieved: int) -> int:
	var reward := 0
	for tier in range(clampi(previous, 0, 3) + 1, clampi(achieved, 0, 3) + 1):
		reward += tier
	return reward


func get_stardust() -> int:
	return stardust


func refresh_daily_missions() -> bool:
	var today := Time.get_date_string_from_system()
	if daily_mission_date == today:
		return false
	daily_mission_date = today
	daily_mission_progress = {}
	for mission in DailyMissionCatalogLib.missions():
		daily_mission_progress[String(mission.get("id", ""))] = 0
	daily_mission_claimed = false
	save_data()
	return true


func record_daily_action(action_id: String, amount: int = 1) -> bool:
	refresh_daily_missions()
	if amount <= 0:
		return false
	for mission in DailyMissionCatalogLib.missions():
		if String(mission.get("id", "")) != action_id:
			continue
		var target := int(mission.get("target", 1))
		var previous := int(daily_mission_progress.get(action_id, 0))
		daily_mission_progress[action_id] = mini(target, previous + amount)
		if int(daily_mission_progress[action_id]) != previous:
			# 젤리 포획마다 디스크에 쓰지 않고 5마리/완료 지점에서만 체크포인트를 남긴다.
			var current := int(daily_mission_progress[action_id])
			if action_id != "capture" or current >= target or current % 5 == 0:
				save_data()
			return true
	return false


func get_daily_mission_progress(action_id: String) -> int:
	refresh_daily_missions()
	return int(daily_mission_progress.get(action_id, 0))


func get_daily_completed_count() -> int:
	refresh_daily_missions()
	var completed := 0
	for mission in DailyMissionCatalogLib.missions():
		var id := String(mission.get("id", ""))
		if get_daily_mission_progress(id) >= int(mission.get("target", 1)):
			completed += 1
	return completed


func can_claim_daily_mission_chest() -> bool:
	return not daily_mission_claimed and get_daily_completed_count() >= DailyMissionCatalogLib.missions().size()


func claim_daily_mission_chest() -> Dictionary:
	if not can_claim_daily_mission_chest():
		return {}
	var reward := DailyMissionCatalogLib.reward().duplicate(true)
	stardust += maxi(0, int(reward.get("stardust", 0)))
	energy += maxi(0, int(reward.get("energy", 0)))
	if energy >= MAX_ENERGY:
		energy_updated_at = _now()
	daily_mission_claimed = true
	save_data()
	return reward


func has_claimed_daily_mission_chest() -> bool:
	refresh_daily_missions()
	return daily_mission_claimed


func has_completed_daily_challenge() -> bool:
	return daily_challenge_date == Time.get_date_string_from_system()


func complete_daily_challenge() -> Dictionary:
	if has_completed_daily_challenge():
		return {}
	var reward: Dictionary = LiveProgressionCatalogLib.daily_challenge().get("reward", {}).duplicate(true)
	daily_challenge_date = Time.get_date_string_from_system()
	_apply_activity_reward(reward)
	record_retention_action("daily")
	add_season_xp(15)
	save_data()
	return reward


func record_jelly_capture(color_id: String, shiny: bool = false) -> void:
	if not G.COLORS.has(color_id):
		return
	var count := int(jelly_capture_counts.get(color_id, 0)) + 1
	jelly_capture_counts[color_id] = count
	if shiny and not shiny_discoveries.has(color_id):
		shiny_discoveries.append(color_id)
	# 포획 수는 5마리 단위와 신규 발견 시점에 저장한다.
	if count == 1 or count % 5 == 0 or shiny:
		save_data()
	record_retention_action("capture", 1)


func get_jelly_capture_count(color_id: String) -> int:
	return int(jelly_capture_counts.get(color_id, 0))


func has_discovered_jelly(color_id: String) -> bool:
	return get_jelly_capture_count(color_id) > 0


func has_discovered_shiny(color_id: String) -> bool:
	return shiny_discoveries.has(color_id)


func get_discovered_jelly_count() -> int:
	var count := 0
	for color_id in G.COLORS:
		if has_discovered_jelly(String(color_id)):
			count += 1
	return count


func claim_dex_milestone(count: int, reward: int) -> bool:
	if count <= 0 or reward <= 0 or claimed_dex_milestones.has(count) or get_discovered_jelly_count() < count:
		return false
	claimed_dex_milestones.append(count)
	stardust += reward
	save_data()
	return true


func has_claimed_dex_milestone(count: int) -> bool:
	return claimed_dex_milestones.has(count)


func set_preferences(sound: bool, haptics: bool, notifications: bool) -> void:
	sound_enabled = sound
	haptics_enabled = haptics
	notifications_enabled = notifications
	save_data()


func set_language(value: String) -> void:
	language = value if Localization.option_codes().has(value) else Localization.SYSTEM_LANGUAGE
	save_data()


func claim_mail(mail: Dictionary) -> bool:
	var id := String(mail.get("id", ""))
	if id.is_empty() or claimed_mail_ids.has(id):
		return false
	claimed_mail_ids.append(id)
	stardust += maxi(0, int(mail.get("stardust", 0)))
	energy += maxi(0, int(mail.get("energy", 0)))
	if energy >= MAX_ENERGY:
		energy_updated_at = _now()
	save_data()
	return true


func has_claimed_mail(id: String) -> bool:
	return claimed_mail_ids.has(id)


func progression_snapshot() -> Dictionary:
	## 서버 저장/분쟁 복구에 필요한 영구 진행 데이터만 반환한다.
	return {
		"schema": 1,
		"stars": stars.duplicate(true),
		"best_clear_times": best_clear_times.duplicate(true),
		"stardust": stardust,
		"energy": energy,
		"energy_updated_at": energy_updated_at,
		"owned_furniture": owned_furniture.duplicate(),
		"room_placements": room_placements.duplicate(true),
		"room_theme_id": get_room_theme(),
		"rescued_jellies": rescued_jellies.duplicate(),
		"resident_records": resident_records.duplicate(true),
		"resident_relationships": resident_relationships.duplicate(true),
		"album_memories": album_memories.duplicate(true),
		"nickname": nickname,
		"completed_tutorials": completed_tutorials.duplicate(),
		"jelly_capture_counts": jelly_capture_counts.duplicate(true),
		"shiny_discoveries": shiny_discoveries.duplicate(),
		"booster_inventory": booster_inventory.duplicate(true),
		"unlocked_level_segments": unlocked_level_segments.duplicate(),
		"claimed_shop_items": claimed_shop_items.duplicate(),
		"ads_removed": ads_removed,
		"vip_daily_support_date": vip_daily_support_date,
		"daily_challenge_date": daily_challenge_date,
		"weekly_key": weekly_key,
		"weekly_expedition_step": weekly_expedition_step,
		"weekly_expedition_claimed": weekly_expedition_claimed,
		"resident_requests": resident_requests.duplicate(true),
		"season_key": season_key,
		"season_xp": season_xp,
		"season_premium": season_premium,
		"restoration_points": restoration_points,
		"town_levels": town_levels.duplicate(true),
		"weekly_activity_best": weekly_activity_best,
	}


func get_booster_count(booster_id: String) -> int:
	return maxi(0, int(booster_inventory.get(booster_id, 0)))


func consume_booster(booster_id: String) -> bool:
	var count := get_booster_count(booster_id)
	if count <= 0:
		return false
	booster_inventory[booster_id] = count - 1
	save_data()
	return true


func add_booster(booster_id: String, amount: int = 1) -> void:
	if amount <= 0 or not booster_inventory.has(booster_id):
		return
	booster_inventory[booster_id] = get_booster_count(booster_id) + amount
	save_data()


func refresh_weekly_progress() -> void:
	var current := str(int(Time.get_unix_time_from_system()) / (7 * 24 * 60 * 60))
	if weekly_key == current:
		return
	weekly_key = current
	weekly_progress = {}
	weekly_claimed = false
	weekly_expedition_step = 0
	weekly_expedition_claimed = false
	weekly_activity_best = 0.0
	save_data()


func get_weekly_expedition_step() -> int:
	refresh_weekly_progress()
	return clampi(weekly_expedition_step, 0, 5)


func complete_weekly_expedition_step(expected_step: int) -> Dictionary:
	refresh_weekly_progress()
	if weekly_expedition_claimed or expected_step != weekly_expedition_step or expected_step < 0 or expected_step >= 5:
		return {}
	var config := LiveProgressionCatalogLib.weekly_expedition()
	var reward: Dictionary = config.get("step_reward", {}).duplicate(true)
	weekly_expedition_step += 1
	if weekly_expedition_step >= 5:
		weekly_expedition_claimed = true
		var final_reward: Dictionary = config.get("final_reward", {})
		reward["stardust"] = int(reward.get("stardust", 0)) + int(final_reward.get("stardust", 0))
		var combined_boosters: Dictionary = reward.get("boosters", {}).duplicate(true)
		for booster_id in final_reward.get("boosters", {}):
			combined_boosters[booster_id] = int(combined_boosters.get(booster_id, 0)) + int(final_reward.boosters[booster_id])
		reward["boosters"] = combined_boosters
	_apply_activity_reward(reward)
	record_retention_action("expedition")
	add_season_xp(35 if weekly_expedition_step >= 5 else 10)
	save_data()
	return reward


func _apply_activity_reward(reward: Dictionary) -> void:
	stardust += maxi(0, int(reward.get("stardust", 0)))
	energy += maxi(0, int(reward.get("energy", 0)))
	for booster_id in reward.get("boosters", {}):
		if booster_inventory.has(booster_id):
			booster_inventory[booster_id] = get_booster_count(String(booster_id)) + maxi(0, int(reward.boosters[booster_id]))


func record_weekly_action(action_id: String, amount: int = 1) -> void:
	refresh_weekly_progress()
	if amount <= 0:
		return
	weekly_progress[action_id] = maxi(0, int(weekly_progress.get(action_id, 0)) + amount)
	save_data()


func get_weekly_progress(action_id: String) -> int:
	refresh_weekly_progress()
	return maxi(0, int(weekly_progress.get(action_id, 0)))


func can_claim_weekly_reward() -> bool:
	refresh_weekly_progress()
	if weekly_claimed:
		return false
	for mission in LiveProgressionCatalogLib.weekly().get("missions", []):
		if get_weekly_progress(String(mission.get("id", ""))) < int(mission.get("target", 0)):
			return false
	return true


func claim_weekly_reward() -> Dictionary:
	if not can_claim_weekly_reward():
		return {}
	var reward: Dictionary = LiveProgressionCatalogLib.weekly().get("reward", {}).duplicate(true)
	weekly_claimed = true
	stardust += maxi(0, int(reward.get("stardust", 0)))
	for booster_id in reward.get("boosters", {}):
		booster_inventory[booster_id] = get_booster_count(String(booster_id)) + maxi(0, int(reward.boosters[booster_id]))
	save_data()
	return reward


func claim_season_milestone(star_target: int) -> Dictionary:
	if star_target <= 0 or claimed_season_milestones.has(star_target):
		return {}
	var total := 0
	for value in stars.values():
		total += int(value)
	if total < star_target:
		return {}
	for milestone in LiveProgressionCatalogLib.season().get("milestones", []):
		if int(milestone.get("stars", 0)) == star_target:
			claimed_season_milestones.append(star_target)
			stardust += maxi(0, int(milestone.get("stardust", 0)))
			var booster_id := String(milestone.get("booster", ""))
			if not booster_id.is_empty() and booster_inventory.has(booster_id):
				booster_inventory[booster_id] = get_booster_count(booster_id) + 1
			save_data()
			return milestone
	return {}


static func is_valid_nickname(value: String) -> bool:
	if value.is_empty() or value.length() > MAX_NICKNAME_LENGTH:
		return false
	# 일반/전각/줄바꿈뿐 아니라 보이지 않는 유니코드 공백도 닉네임에 포함할 수 없다.
	for i in range(value.length()):
		var code := value.unicode_at(i)
		if code <= 0x20 or code == 0xA0 or (code >= 0x2000 and code <= 0x200B) or code == 0x2028 or code == 0x2029 or code == 0x202F or code == 0x205F or code == 0x3000:
			return false
	return true


func has_nickname() -> bool:
	return is_valid_nickname(nickname)


func get_nickname() -> String:
	return nickname if has_nickname() else ""


func set_nickname(value: String) -> bool:
	if not is_valid_nickname(value):
		return false
	nickname = value
	save_data()
	return true


func has_seen_scenario(sequence_id: String) -> bool:
	return seen_scenarios.has(sequence_id)


func mark_scenario_seen(sequence_id: String) -> void:
	if sequence_id.is_empty() or seen_scenarios.has(sequence_id):
		return
	seen_scenarios.append(sequence_id)
	save_data()


func has_completed_tutorial(tutorial_id: String) -> bool:
	return completed_tutorials.has(tutorial_id)


func mark_tutorial_completed(tutorial_id: String) -> void:
	if tutorial_id.is_empty() or completed_tutorials.has(tutorial_id):
		return
	completed_tutorials.append(tutorial_id)
	save_data()


func spend_stardust(amount: int) -> bool:
	if amount <= 0 or stardust < amount:
		return false
	stardust -= amount
	save_data()
	return true


func grant_stardust(amount: int) -> bool:
	if amount <= 0:
		return false
	stardust += amount
	save_data()
	return true


func can_claim_attendance() -> bool:
	var today := Time.get_date_string_from_system()
	# ISO 날짜 문자열은 사전 순서가 날짜 순서와 같아 시계를 뒤로 돌린 중복 수령도 막는다.
	return attendance_last_claim_date.is_empty() or today > attendance_last_claim_date


func claim_attendance() -> Dictionary:
	if not can_claim_attendance():
		return {}
	var reward := get_attendance_next_reward()
	stardust += int(reward.get("stardust", 0))
	energy += int(reward.get("energy", 0))
	if energy >= MAX_ENERGY:
		# 최대치를 넘는 출석 하트도 유료 하트처럼 보유하며, 그동안 자연 회복은 멈춘다.
		energy_updated_at = _now()
	attendance_claimed_days += 1
	attendance_last_claim_date = Time.get_date_string_from_system()
	save_data()
	return reward


func get_attendance_claimed_days() -> int:
	return attendance_claimed_days


func get_attendance_week() -> int:
	return attendance_claimed_days / ATTENDANCE_DAYS_PER_WEEK + 1


func get_attendance_day_in_week() -> int:
	## 이번 주에 이미 받은 일수(0~6). 7일차 수령 뒤에는 다음 주 0일로 돌아간다.
	return attendance_claimed_days % ATTENDANCE_DAYS_PER_WEEK


static func attendance_reward_for_claim_count(claimed_count: int) -> Dictionary:
	var safe_count := maxi(0, claimed_count)
	var day := safe_count % ATTENDANCE_DAYS_PER_WEEK
	if safe_count < ATTENDANCE_DAYS_PER_WEEK:
		return {
			"stardust": ATTENDANCE_WEEK1_STARDUST[day],
			"energy": ATTENDANCE_WEEK1_ENERGY[day],
		}
	return {
		"stardust": ATTENDANCE_REPEAT_STARDUST[day],
		"energy": ATTENDANCE_REPEAT_ENERGY[day],
	}


func get_attendance_week_rewards() -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	var week_start := (get_attendance_week() - 1) * ATTENDANCE_DAYS_PER_WEEK
	for day in range(ATTENDANCE_DAYS_PER_WEEK):
		rewards.append(attendance_reward_for_claim_count(week_start + day))
	return rewards


func get_attendance_next_reward() -> Dictionary:
	return attendance_reward_for_claim_count(attendance_claimed_days)


func apply_verified_shop_item(item: Dictionary, persist: bool = true) -> bool:
	## 결제 공급자가 영수증 검증을 끝낸 뒤에만 호출하는 지급 지점.
	match String(item.get("type", "")):
		"stardust":
			var amount := maxi(0, int(item.get("amount", 0)))
			if amount <= 0:
				return false
			stardust += amount
		"remove_ads":
			if ads_removed:
				return false
			ads_removed = true
			claimed_shop_items.append(String(item.get("id", "remove_ads")))
			_grant_shop_furniture(item)
		"energy":
			var amount := maxi(0, int(item.get("amount", 0)))
			if amount <= 0:
				return false
			energy += amount
			energy_updated_at = _now()
		"bundle":
			var item_id := String(item.get("id", ""))
			if item_id.is_empty() or claimed_shop_items.has(item_id):
				return false
			stardust += maxi(0, int(item.get("stardust", 0)))
			energy += maxi(0, int(item.get("energy", 0)))
			if energy >= MAX_ENERGY:
				energy_updated_at = _now()
			for booster_id in item.get("boosters", {}):
				if booster_inventory.has(booster_id):
					booster_inventory[booster_id] = get_booster_count(String(booster_id)) + maxi(0, int(item.boosters[booster_id]))
			_grant_shop_furniture(item)
			claimed_shop_items.append(item_id)
		"season_pass":
			if persist: refresh_season()
			if season_premium:
				return false
			season_premium = true
			_grant_shop_furniture(item)
		_:
			return false
	if persist: save_data()
	return true

func apply_iap_delivery(transaction_id: String, item: Dictionary, season: String, entitlement_only: bool = false) -> bool:
	if transaction_id.is_empty() or not persistence_enabled: return false
	if iap_transactions.has(transaction_id) and not entitlement_only: return true
	var before := cloud_data().duplicate(true)
	var journal := iap_transactions.duplicate(true)
	var item_id := String(item.get("id", ""))
	var kind := String(item.get("type", ""))
	if kind == "season_pass" and season != str(int(Time.get_unix_time_from_system()) / (28 * 86400)):
		return false
	if entitlement_only:
		if kind == "remove_ads": ads_removed = true
		if kind == "season_pass":
			if season_key != season:
				season_key = season
				season_xp = 0
				claimed_season_free.clear()
				claimed_season_premium.clear()
			season_premium = true
		if not bool(item.get("consumable", true)) and not claimed_shop_items.has(item_id): claimed_shop_items.append(item_id)
		_grant_shop_furniture(item)
	elif not has_purchased_shop_item(item_id):
		if kind == "season_pass" and season_key != season:
			season_key = season
			season_xp = 0
			season_premium = false
			claimed_season_free.clear()
			claimed_season_premium.clear()
		if not (kind == "season_pass" and season_premium) and not apply_verified_shop_item(item, false):
			apply_cloud_data(before)
			return false
	if not entitlement_only: iap_transactions[transaction_id] = true
	if save_data(): return true
	apply_cloud_data(before)
	iap_transactions = journal
	return false


func _grant_shop_furniture(item: Dictionary) -> bool:
	var changed := false
	for raw_furniture_id in item.get("furniture_ids", []):
		var furniture_id := String(raw_furniture_id)
		if not furniture_id.is_empty() and not RoomDataLib.item_by_id(furniture_id).is_empty() and not owned_furniture.has(furniture_id):
			owned_furniture.append(furniture_id)
			changed = true
	return changed


func _sync_shop_entitlement_rewards() -> void:
	## 상품 구성 개선 전에 구매한 계정에도 신규 한정 가구를 소급 지급한다.
	var changed := false
	for item in ShopCatalogLib.load_items():
		var item_id := String(item.get("id", ""))
		if not has_purchased_shop_item(item_id):
			continue
		changed = _grant_shop_furniture(item) or changed
	if changed:
		save_data()


func has_removed_ads() -> bool:
	return ads_removed


func has_purchased_shop_item(item_id: String) -> bool:
	return (item_id == "remove_ads" and ads_removed) or claimed_shop_items.has(item_id)


func can_skip_rewarded_ad(placement: String) -> bool:
	if not ads_removed:
		return false
	return placement == "clear_reward_double" and vip_reward_skip_date != Time.get_date_string_from_system()


func consume_rewarded_ad_skip(placement: String) -> bool:
	if not can_skip_rewarded_ad(placement):
		return false
	if placement == "clear_reward_double":
		vip_reward_skip_date = Time.get_date_string_from_system()
		save_data()
	return true


func can_claim_vip_daily_support() -> bool:
	return ads_removed and vip_daily_support_date != Time.get_date_string_from_system()


func claim_vip_daily_support() -> Dictionary:
	if not can_claim_vip_daily_support():
		return {}
	vip_daily_support_date = Time.get_date_string_from_system()
	stardust += 8
	booster_inventory["time"] = get_booster_count("time") + 1
	save_data()
	return {"stardust":8,"boosters":{"time":1}}


func has_furniture(id: String) -> bool:
	return owned_furniture.has(id)


func get_owned_furniture() -> Array[String]:
	return owned_furniture.duplicate()


func purchase_furniture(id: String, price: int) -> bool:
	## 가구는 별/업적 진행도로 자동 해금하지 않고 별가루로 영구 구매한다.
	if id.is_empty() or price <= 0 or has_furniture(id) or RoomDataLib.item_by_id(id).is_empty():
		return false
	if stardust < price:
		return false
	stardust -= price
	owned_furniture.append(id)
	save_data()
	return true


func claim_level_furniture_reward(level_number: int) -> Dictionary:
	## JSON에 등록된 10단위 보상은 계정당 한 번만 지급한다.
	if claimed_furniture_reward_levels.has(level_number):
		return {}
	var reward := FurnitureRewardCatalogLib.reward_for_level(level_number)
	if reward.is_empty():
		return {}
	var id := String(reward.furniture_id)
	if RoomDataLib.item_by_id(id).is_empty():
		return {}
	claimed_furniture_reward_levels.append(level_number)
	var newly_owned := not owned_furniture.has(id)
	if newly_owned:
		owned_furniture.append(id)
	var result: Dictionary = reward.duplicate(true)
	result["newly_owned"] = newly_owned
	save_data()
	return result


func _sync_furniture_milestone_rewards() -> void:
	## 기능 추가 전 이미 완료한 10단위 레벨 보상도 다음 실행 시 소급 지급한다.
	var changed := false
	for reward in FurnitureRewardCatalogLib.load_rewards():
		var level_number := int(reward.level)
		if get_stars(level_number - 1) <= 0 or claimed_furniture_reward_levels.has(level_number):
			continue
		claimed_furniture_reward_levels.append(level_number)
		changed = true
		var id := String(reward.furniture_id)
		if not owned_furniture.has(id) and not RoomDataLib.item_by_id(id).is_empty():
			owned_furniture.append(id)
	if changed:
		save_data()


func get_room_placements() -> Array:
	# 과거 별/업적 자동 해금 시 배치했던 미보유 가구는 충돌 판정에서도 제외한다.
	var owned_placements: Array = []
	for placement in room_placements:
		if has_furniture(String(placement.get("id", ""))):
			owned_placements.append(placement)
	if owned_placements.size() != room_placements.size():
		room_placements = owned_placements
		save_data()
	return room_placements.duplicate(true)


func get_room_theme() -> String:
	return room_theme_id if is_room_theme_unlocked(room_theme_id) else RoomDataLib.DEFAULT_ROOM_THEME


func is_room_theme_unlocked(id: String) -> bool:
	var info := RoomDataLib.room_theme(id)
	if String(info.id) != id:
		return false
	var required_level := int(info.unlock_level)
	return required_level == 0 or get_stars(required_level - 1) > 0


func set_room_theme(id: String) -> bool:
	if not is_room_theme_unlocked(id):
		return false
	room_theme_id = id
	save_data()
	return true


func set_room_placements(value: Array) -> void:
	room_placements = value.duplicate(true)
	save_data()


func register_rescued_jelly(level_idx: int) -> bool:
	## 1~6챕터 첫 클리어에서 각 색 대표 주민을 한 명씩 아지트에 초대한다.
	var colors := ["R", "Y", "B", "G", "P", "O"]
	var color: String = colors[clampi(level_idx / 10, 0, 5)]
	if rescued_jellies.has(color) or rescued_jellies.size() >= 6:
		return false
	rescued_jellies.append(color)
	_create_resident_record(color, level_idx)
	save_data()
	return true


func get_rescued_jellies() -> Array[String]:
	return rescued_jellies.duplicate()


func _migrate_resident_records() -> void:
	for index in range(rescued_jellies.size()):
		var color_id := rescued_jellies[index]
		var exists := false
		for record in resident_records:
			if String(record.get("color", "")) == color_id:
				exists = true
				break
		if not exists:
			_create_resident_record(color_id, index * 10)


func _create_resident_record(color_id: String, level_idx: int) -> Dictionary:
	var profile := CharacterCatalogLib.profile(color_id)
	var record := {
		"id": "%s_%d_%d" % [color_id, level_idx + 1, resident_records.size() + 1],
		"color": color_id,
		"name": String(profile.get("name", G.COLOR_NAMES.get(color_id, "젤리몬"))),
		"personality": String(profile.get("personality", "다정한 친구")),
		"trait": String(profile.get("trait", "kind")),
		"rescued_level": level_idx + 1,
		"rescued_at": int(Time.get_unix_time_from_system()),
		"affection": 0,
		"affection_date": "",
		"affection_today": 0,
		"accessories": [],
		"favorite_furniture": String(profile.get("favorite_furniture", [""])[0]),
	}
	resident_records.append(record)
	return record


func get_resident_records() -> Array:
	_migrate_resident_records()
	return resident_records.duplicate(true)


func add_resident_affection(resident_id: String, amount: int = 1) -> Dictionary:
	## 방치/연속 터치로 무제한 성장하지 않도록 주민별 일일 상한을 적용한다.
	if amount <= 0:
		return {}
	var today := Time.get_date_string_from_system()
	var daily_cap := GameBalanceCatalogLib.retention("resident_affection_daily_cap", 5)
	for record in resident_records:
		if String(record.get("id", "")) == resident_id:
			if String(record.get("affection_date", "")) != today:
				record["affection_date"] = today
				record["affection_today"] = 0
			var earned_today := maxi(0, int(record.get("affection_today", 0)))
			var granted := mini(amount, maxi(0, daily_cap - earned_today))
			if granted <= 0:
				return {"granted": 0, "capped": true, "level": get_resident_bond_level(record), "affection": int(record.get("affection", 0))}
			var previous_level := get_resident_bond_level(record)
			record["affection"] = maxi(0, int(record.get("affection", 0)) + granted)
			record["affection_today"] = earned_today + granted
			var current_level := get_resident_bond_level(record)
			save_data()
			return {
				"granted": granted,
				"capped": int(record.affection_today) >= daily_cap,
				"level": current_level,
				"affection": int(record.affection),
				"level_up": current_level > previous_level,
			}
	return {}


func get_resident_bond_level(record: Dictionary) -> int:
	return MetaProgressionCatalogLib.bond_level(maxi(0, int(record.get("affection", 0))))


func get_resident_bond_progress(record: Dictionary) -> Dictionary:
	var affection := maxi(0, int(record.get("affection", 0)))
	var level := MetaProgressionCatalogLib.bond_level(affection)
	var info := MetaProgressionCatalogLib.bond_level_data(level)
	var next_affection := MetaProgressionCatalogLib.next_bond_affection(level)
	return {
		"level": level,
		"title": String(info.get("title", "친구")),
		"affection": affection,
		"next_affection": next_affection,
		"maxed": next_affection < 0,
	}


func record_resident_interaction(first_id: String, second_id: String, interaction_id: String) -> void:
	var pair := [first_id, second_id]
	pair.sort()
	var key := "%s|%s" % pair
	var data: Dictionary = resident_relationships.get(key, {"count": 0, "last": ""})
	data.count = int(data.get("count", 0)) + 1
	data.last = interaction_id
	resident_relationships[key] = data
	save_data()


func add_album_memory(kind: String, caption: String, residents: Array = []) -> void:
	album_memories.push_front({"kind": kind, "caption": caption, "residents": residents.duplicate(), "created_at": int(Time.get_unix_time_from_system())})
	var memory_limit := GameBalanceCatalogLib.retention("album_memory_limit", 30)
	if album_memories.size() > memory_limit:
		album_memories.resize(memory_limit)
	save_data()


func refresh_resident_requests() -> void:
	var today := Time.get_date_string_from_system()
	if resident_request_date == today:
		return
	resident_request_date = today
	resident_requests = []
	var templates := RetentionCatalogLib.requests()
	var residents := get_resident_records()
	if residents.is_empty() or templates.is_empty():
		return
	var date := Time.get_date_dict_from_system()
	var seed := int(date.year) * 372 + int(date.month) * 31 + int(date.day)
	var request_slots := 3 if season_premium else 2
	for slot in range(mini(request_slots, residents.size())):
		var resident: Dictionary = residents[posmod(seed + slot * 3, residents.size())]
		var request: Dictionary = templates[posmod(seed + slot * 2, templates.size())].duplicate(true)
		request["id"] = "%s_%s" % [today, String(resident.id)]
		request["resident_id"] = String(resident.id)
		request["resident_name"] = String(resident.name)
		request["color"] = String(resident.color)
		request["progress"] = 0
		request["claimed"] = false
		resident_requests.append(request)
	save_data()


func record_retention_action(action: String, amount: int = 1) -> void:
	refresh_resident_requests()
	var changed := false
	for request in resident_requests:
		if String(request.get("action", "")) == action and not bool(request.get("claimed", false)):
			request["progress"] = mini(int(request.get("target", 1)), int(request.get("progress", 0)) + amount)
			changed = true
	if changed:
		save_data()


func claim_resident_request(request_id: String) -> Dictionary:
	refresh_resident_requests()
	for request in resident_requests:
		if String(request.get("id", "")) != request_id or bool(request.get("claimed", false)) or int(request.get("progress", 0)) < int(request.get("target", 1)):
			continue
		request["claimed"] = true
		var bond := add_resident_affection(String(request.resident_id), int(request.get("affection", 2)))
		add_season_xp(int(request.get("season_xp", 8)))
		var line := RetentionCatalogLib.request_line(String(request.color))
		add_album_memory("resident_request", line, [String(request.resident_id)])
		var result: Dictionary = request.duplicate(true)
		result["line"] = line
		result["bond"] = bond
		return result
	return {}


func refresh_season() -> void:
	var current := str(int(Time.get_unix_time_from_system()) / (28 * 24 * 60 * 60))
	if season_key == current:
		return
	season_key = current
	season_xp = 0
	season_premium = false
	claimed_season_free.clear()
	claimed_season_premium.clear()
	save_data()


func add_season_xp(amount: int) -> void:
	refresh_season()
	season_xp += maxi(0, amount)
	save_data()


func season_level() -> int:
	refresh_season()
	var config := RetentionCatalogLib.season()
	return clampi(season_xp / maxi(1, int(config.get("xp_per_level", 20))) + 1, 1, int(config.get("levels", 20)))


func claim_retention_season_reward(level: int, premium: bool) -> Dictionary:
	refresh_season()
	var claimed: Array[int] = claimed_season_premium if premium else claimed_season_free
	if level > season_level() or claimed.has(level) or (premium and not season_premium):
		return {}
	var table: Dictionary = RetentionCatalogLib.season().get("premium_rewards" if premium else "free_rewards", {})
	var reward: Dictionary = table.get(str(level), {}).duplicate(true)
	if reward.is_empty():
		return {}
	claimed.append(level)
	stardust += int(reward.get("stardust", 0))
	var booster := String(reward.get("booster", ""))
	if booster_inventory.has(booster):
		booster_inventory[booster] = get_booster_count(booster) + int(reward.get("amount", 1))
	var furniture := String(reward.get("furniture", ""))
	if not furniture.is_empty() and not owned_furniture.has(furniture):
		owned_furniture.append(furniture)
	save_data()
	return reward


func grant_restoration_point(level_number: int) -> void:
	if level_number >= 301:
		restoration_points += 1
		save_data()


func upgrade_town(district_id: String) -> Dictionary:
	for district in RetentionCatalogLib.towns():
		if String(district.id) != district_id:
			continue
		var level := int(town_levels.get(district_id, 0))
		var costs: Array = district.costs
		if level >= costs.size() or get_stars(int(district.unlock_level) - 2) <= 0:
			return {}
		var cost := int(costs[level])
		if restoration_points < cost:
			return {}
		restoration_points -= cost
		town_levels[district_id] = level + 1
		stardust += int(district.reward)
		save_data()
		return {"name":district.name,"level":level + 1,"reward":int(district.reward)}
	return {}


func record_level_failure() -> void:
	consecutive_failures += 1
	save_data()


func record_level_success() -> void:
	consecutive_failures = 0
	record_retention_action("clear")
	add_season_xp(1)


func mark_beta_feedback_submitted() -> void:
	beta_feedback_submitted = true
	save_data()


func recommended_shop_item_id() -> String:
	if not has_purchased_shop_item("starter_rescue_pack") and RoomDataLib.clear_count(self) < 30:
		return "starter_rescue_pack"
	if not has_removed_ads() and RoomDataLib.clear_count(self) >= 100:
		return "remove_ads"
	if consecutive_failures >= 3 and not has_purchased_shop_item("chapter_rescue_pack"):
		return "chapter_rescue_pack"
	if not has_purchased_shop_item("hideout_decor_pack") and room_placements.size() >= 6:
		return "hideout_decor_pack"
	return "season_heart_star_pass" if not season_premium else ""


func room_share_text() -> String:
	return "젤리몬 아지트 · %s · 별 %d · 가구 %d개 · 마을 복구 %d단계" % [get_nickname() if has_nickname() else "구조 대원", RoomDataLib.total_stars(self), room_placements.size(), town_total_level()]


func town_total_level() -> int:
	var total := 0
	for value in town_levels.values(): total += int(value)
	return total


func adventure_support() -> Dictionary:
	## 친밀도와 마을 복구가 장식용 숫자에 머물지 않고 실제 원정에 영향을 준다.
	var time_bonus := 0.0
	var shiny_bonus := 0.0
	var free_hint := false
	var supporters: Array[String] = []
	for record in get_resident_records():
		var bond_level := get_resident_bond_level(record)
		if bond_level >= 3:
			time_bonus += 1.0
			supporters.append(String(record.get("name", "주민")))
		if bond_level >= 5:
			shiny_bonus += 0.003
		if bond_level >= 7:
			free_hint = true
	var town_level := town_total_level()
	return {
		"time_bonus": minf(6.0, time_bonus),
		"shiny_bonus": minf(0.018, shiny_bonus),
		"stardust_bonus": mini(5, town_level / 3),
		"free_hint": free_hint,
		"supporters": supporters.slice(0, 3),
	}


func room_share_code() -> String:
	var payload := {"name":get_nickname() if has_nickname() else "구조 대원","stars":RoomDataLib.total_stars(self),"town":town_total_level(),"furniture":room_placements.map(func(value): return String(value.get("id", "")))}
	return "JELLY1:" + Marshalls.raw_to_base64(JSON.stringify(payload).to_utf8_buffer())


func parse_room_share_code(code: String) -> Dictionary:
	if not code.begins_with("JELLY1:"): return {}
	var parsed = JSON.parse_string(Marshalls.base64_to_raw(code.trim_prefix("JELLY1:")).get_string_from_utf8())
	return parsed if parsed is Dictionary else {}


func record_weekly_activity_time(seconds: float) -> bool:
	if seconds <= 0.0 or (weekly_activity_best > 0.0 and seconds >= weekly_activity_best):
		return false
	weekly_activity_best = seconds
	save_data()
	return true


func is_unlocked(idx: int) -> bool:
	if idx == 0:
		return true
	return get_stars(idx - 1) > 0


func is_level_segment_unlocked(segment: int) -> bool:
	## 캠페인 진행은 실력과 이전 레벨 클리어만으로 열린다. 광고·결제 관문은 없다.
	return segment >= 0


func can_unlock_level_segment(segment: int) -> bool:
	return false


func unlock_level_segment(segment: int) -> bool:
	return segment >= 0


func next_unlockable_level_segment(total_levels: int) -> int:
	@warning_ignore("unused_parameter")
	var ignored_total := total_levels
	return -1


func _migrate_level_segments() -> void:
	## 이미 101·201… 레벨을 플레이한 구버전 저장은 해당 구간을 잠그지 않는다.
	var highest_started_segment := 0
	for raw_index in stars.keys():
		if int(stars.get(raw_index, 0)) > 0:
			highest_started_segment = maxi(highest_started_segment, int(String(raw_index)) / LEVEL_GATE_SIZE)
	for segment in range(1, highest_started_segment + 1):
		if not unlocked_level_segments.has(segment):
			unlocked_level_segments.append(segment)
	unlocked_level_segments.sort()
