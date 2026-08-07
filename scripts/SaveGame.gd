extends RefCounted
class_name SaveGame
## 진행도 저장 (user://jellymon_save.json)

const RoomDataLib = preload("res://scripts/RoomData.gd")

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

var stars := {}
var stardust := 0
var room_placements: Array = []
var room_grid_version := ROOM_GRID_VERSION
var rescued_jellies: Array[String] = []
var attendance_claimed_days := 0
var attendance_last_claim_date := ""
var ads_removed := false
var nickname := ""
var seen_scenarios: Array[String] = []
var energy := MAX_ENERGY
var energy_updated_at := 0
var persistence_enabled := true


func load_data() -> void:
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if typeof(d) == TYPE_DICTIONARY:
				stars = d.get("stars", {})
				stardust = maxi(0, int(d.get("stardust", 0)))
				room_placements = d.get("room_placements", [])
				room_grid_version = int(d.get("room_grid_version", 1))
				# 구버전의 0~7일 기록을 그대로 이어받고, 이후에는 주차 제한 없이 누적한다.
				attendance_claimed_days = maxi(0, int(d.get("attendance_claimed_days", 0)))
				attendance_last_claim_date = String(d.get("attendance_last_claim_date", ""))
				ads_removed = bool(d.get("ads_removed", false))
				nickname = String(d.get("nickname", ""))
				for scenario_id in d.get("seen_scenarios", []):
					var value := String(scenario_id)
					if not value.is_empty() and not seen_scenarios.has(value):
						seen_scenarios.append(value)
				for color in d.get("rescued_jellies", []):
					if G.COLORS.has(String(color)) and not rescued_jellies.has(String(color)) and rescued_jellies.size() < 5:
						rescued_jellies.append(String(color))
				# 구매한 보너스 하트는 최대치 5를 넘어 보유할 수 있다.
				energy = maxi(0, int(d.get("energy", MAX_ENERGY)))
				energy_updated_at = int(d.get("energy_updated_at", _now()))
	if energy_updated_at <= 0:
		energy_updated_at = _now()
	if room_placements.is_empty():
		room_placements = RoomDataLib.default_placements()
		room_grid_version = ROOM_GRID_VERSION
	elif room_grid_version < ROOM_GRID_VERSION:
		# 6×5 구형 방의 화면상 위치를 유지한 채 새 왼쪽 열만 추가한다.
		for placement in room_placements:
			placement["x"] = int(placement.get("x", 0)) + 1
		room_grid_version = ROOM_GRID_VERSION
		save_data()
	# 구버전 저장 파일은 주민 목록이 없으므로 완료한 챕터 기록에서 최대 5마리를 복원한다.
	if rescued_jellies.is_empty() and not stars.is_empty():
		var chapter_colors := ["R", "Y", "B", "G", "P"]
		for chapter in range(5):
			for idx in range(chapter * 10, chapter * 10 + 10):
				if get_stars(idx) > 0:
					rescued_jellies.append(chapter_colors[chapter])
					break
	refresh_energy()


func save_data() -> void:
	if not persistence_enabled:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"stars": stars,
			"stardust": stardust,
			"room_placements": room_placements,
			"room_grid_version": room_grid_version,
			"rescued_jellies": rescued_jellies,
			"attendance_claimed_days": attendance_claimed_days,
			"attendance_last_claim_date": attendance_last_claim_date,
			"ads_removed": ads_removed,
			"nickname": nickname,
			"seen_scenarios": seen_scenarios,
			"energy": energy,
			"energy_updated_at": energy_updated_at,
		}))


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


func award_stars(idx: int, n: int) -> int:
	## 처음 달성한 별 단계만 지급한다. 1/2/3단계 보상은 각각 별가루 1/2/3개다.
	## 예: 기존 1성에서 3성으로 갱신하면 2+3=5개를 한 번에 받는다.
	var previous := get_stars(idx)
	var achieved := clampi(n, 0, 3)
	if achieved <= previous:
		return 0
	var reward := calculate_stardust_reward(previous, achieved)
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


func apply_verified_shop_item(item: Dictionary) -> bool:
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
		"energy":
			var amount := maxi(0, int(item.get("amount", 0)))
			if amount <= 0:
				return false
			energy += amount
			energy_updated_at = _now()
		_:
			return false
	save_data()
	return true


func has_removed_ads() -> bool:
	return ads_removed


func get_room_placements() -> Array:
	if room_placements.is_empty():
		room_placements = RoomDataLib.default_placements()
	return room_placements.duplicate(true)


func set_room_placements(value: Array) -> void:
	room_placements = value.duplicate(true)
	save_data()


func register_rescued_jelly(level_idx: int) -> bool:
	## 각 챕터에서 처음 클리어한 순간 대표 주민 한 마리를 아지트에 초대한다(최대 5마리).
	var colors := ["R", "Y", "B", "G", "P"]
	var color: String = colors[clampi(level_idx / 10, 0, 4)]
	if rescued_jellies.has(color) or rescued_jellies.size() >= 5:
		return false
	rescued_jellies.append(color)
	save_data()
	return true


func get_rescued_jellies() -> Array[String]:
	return rescued_jellies.duplicate()


func is_unlocked(idx: int) -> bool:
	if idx == 0:
		return true
	return get_stars(idx - 1) > 0
