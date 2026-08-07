extends RefCounted
class_name SaveGame
## 진행도 저장 (user://jellymon_save.json)

const PATH := "user://jellymon_save.json"
const MAX_ENERGY := 5
const ENERGY_REGEN_SECONDS := 10 * 60

var stars := {}
var stardust := 0
var energy := MAX_ENERGY
var energy_updated_at := 0


func load_data() -> void:
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if typeof(d) == TYPE_DICTIONARY:
				stars = d.get("stars", {})
				stardust = maxi(0, int(d.get("stardust", 0)))
				energy = clampi(int(d.get("energy", MAX_ENERGY)), 0, MAX_ENERGY)
				energy_updated_at = int(d.get("energy_updated_at", _now()))
	if energy_updated_at <= 0:
		energy_updated_at = _now()
	refresh_energy()


func save_data() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"stars": stars,
			"stardust": stardust,
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
		energy = MAX_ENERGY
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
	energy = mini(MAX_ENERGY, energy + 1)
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


func spend_stardust(amount: int) -> bool:
	if amount <= 0 or stardust < amount:
		return false
	stardust -= amount
	save_data()
	return true


func is_unlocked(idx: int) -> bool:
	if idx == 0:
		return true
	return get_stars(idx - 1) > 0
