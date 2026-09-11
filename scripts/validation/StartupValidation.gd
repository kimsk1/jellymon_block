extends RefCounted
## 카탈로그 및 저장/보상 규칙의 개발용 회귀 검사. 실제 사용자 저장은 쓰지 않는다.

const DailyMissionCatalogLib = preload("res://scripts/DailyMissionCatalog.gd")
const JellyDexCatalogLib = preload("res://scripts/JellyDexCatalog.gd")
const LiveMessageCatalogLib = preload("res://scripts/LiveMessageCatalog.gd")
const LiveProgressionCatalogLib = preload("res://scripts/LiveProgressionCatalog.gd")
const CharacterCatalogLib = preload("res://scripts/CharacterCatalog.gd")
const GameBalanceCatalogLib = preload("res://scripts/GameBalanceCatalog.gd")
const MetaProgressionCatalogLib = preload("res://scripts/MetaProgressionCatalog.gd")
const AnalyticsServiceLib = preload("res://scripts/AnalyticsService.gd")
const RetentionCatalogLib = preload("res://scripts/RetentionCatalog.gd")
const EarlyCampaignCatalogLib = preload("res://scripts/EarlyCampaignCatalog.gd")


static func validate(localization: Node) -> PackedStringArray:
	var level_errors := Levels.validate_all()
	level_errors.append_array(RoomData.validate_catalog())
	level_errors.append_array(ShopCatalog.validate_catalog())
	level_errors.append_array(FurnitureRewardCatalog.validate())
	level_errors.append_array(ScenarioCatalog.validate())
	level_errors.append_array(DailyMissionCatalogLib.validate())
	level_errors.append_array(JellyDexCatalogLib.validate())
	level_errors.append_array(LiveMessageCatalogLib.validate())
	level_errors.append_array(LiveProgressionCatalogLib.validate())
	level_errors.append_array(CharacterCatalogLib.validate())
	level_errors.append_array(GameBalanceCatalogLib.validate())
	level_errors.append_array(MetaProgressionCatalogLib.validate())
	level_errors.append_array(AnalyticsServiceLib.validate_schema())
	level_errors.append_array(RetentionCatalogLib.validate())
	level_errors.append_array(localization.validate_catalogs())
	if GameBalanceCatalogLib.economy("max_energy") != SaveGame.MAX_ENERGY or GameBalanceCatalogLib.economy("energy_regen_seconds") != SaveGame.ENERGY_REGEN_SECONDS:
		level_errors.append("게임 밸런스 JSON과 하트 상수가 일치하지 않습니다")
	if SaveGame.calculate_stardust_reward(0, 1) != 1:
		level_errors.append("별가루 보상 오류: 0성→1성")
	if SaveGame.calculate_stardust_reward(1, 3) != 5:
		level_errors.append("별가루 보상 오류: 1성→3성")
	if SaveGame.calculate_stardust_reward(3, 3) != 0:
		level_errors.append("별가루 보상 오류: 3성 재클리어")
	var continued_reward_test := SaveGame.new()
	continued_reward_test.persistence_enabled = false
	var continued_reward := continued_reward_test.award_stars(999, 3, 1)
	if continued_reward != 1 or continued_reward_test.get_stars(999) != 3 or continued_reward_test.get_stardust() != 1:
		level_errors.append("이어하기 클리어 별가루 1개 제한 오류")
	if continued_reward_test.award_stars(999, 3, 1) != 0:
		level_errors.append("이어하기 클리어 별가루 중복 지급 오류")
	var clear_time_test := SaveGame.new()
	clear_time_test.persistence_enabled = false
	if not clear_time_test.record_clear_time(999, 42.37):
		level_errors.append("최초 클리어 시간 기록 오류")
	if clear_time_test.record_clear_time(999, 48.0) or not is_equal_approx(clear_time_test.get_best_clear_time(999), 42.37):
		level_errors.append("느린 클리어 시간으로 최고 기록이 덮어써짐")
	if not clear_time_test.record_clear_time(999, 39.21) or not is_equal_approx(clear_time_test.get_best_clear_time(999), 39.21):
		level_errors.append("빠른 클리어 시간 갱신 오류")
	if SaveGame.ATTENDANCE_WEEK1_STARDUST != [10, 20, 30, 40, 50, 60, 100] or SaveGame.ATTENDANCE_WEEK1_ENERGY != [5, 5, 5, 5, 5, 5, 5]:
		level_errors.append("1주차 출석 보상 구성 오류")
	if SaveGame.ATTENDANCE_REPEAT_STARDUST != [10, 0, 15, 0, 20, 0, 20] or SaveGame.ATTENDANCE_REPEAT_ENERGY != [0, 5, 0, 7, 0, 10, 10]:
		level_errors.append("2주차 이후 출석 보상 구성 오류")
	var attendance_cases := {
		0: {"stardust": 10, "energy": 5},
		6: {"stardust": 100, "energy": 5},
		7: {"stardust": 10, "energy": 0},
		8: {"stardust": 0, "energy": 5},
		13: {"stardust": 20, "energy": 10},
		14: {"stardust": 10, "energy": 0},
	}
	for claimed_count in attendance_cases:
		if SaveGame.attendance_reward_for_claim_count(claimed_count) != attendance_cases[claimed_count]:
			level_errors.append("출석 순환 보상 오류: 누적 %d일" % claimed_count)
	var attendance_test_save := SaveGame.new()
	attendance_test_save.persistence_enabled = false
	attendance_test_save.energy = 0
	attendance_test_save.energy_updated_at = int(Time.get_unix_time_from_system())
	var attendance_grant := attendance_test_save.claim_attendance()
	if attendance_grant != {"stardust": 10, "energy": 5} or attendance_test_save.get_stardust() != 10 or attendance_test_save.get_energy() != 5:
		level_errors.append("출석 별가루/하트 동시 지급 오류")
	if not attendance_test_save.claim_attendance().is_empty():
		level_errors.append("출석 당일 중복 수령 차단 오류")
	if SaveGame.is_valid_nickname("") or SaveGame.is_valid_nickname("공백 이름") or SaveGame.is_valid_nickname("전각　공백") or SaveGame.is_valid_nickname("가나다라마바사아자차카타파") or not SaveGame.is_valid_nickname("젤리친구"):
		level_errors.append("닉네임 입력 규칙 오류")
	var shop_test_save := SaveGame.new()
	shop_test_save.persistence_enabled = false
	if not shop_test_save.apply_verified_shop_item(ShopCatalog.item_by_id("stardust_50")) or shop_test_save.get_stardust() != 50:
		level_errors.append("별가루 50 상점 지급 오류")
	if not shop_test_save.apply_verified_shop_item(ShopCatalog.item_by_id("stardust_110")) or shop_test_save.get_stardust() != 160:
		level_errors.append("별가루 110 상점 지급 오류")
	if not shop_test_save.apply_verified_shop_item(ShopCatalog.item_by_id("heart_5")) or shop_test_save.get_energy() != 10:
		level_errors.append("하트 5 상점 지급 오류")
	if not shop_test_save.apply_verified_shop_item(ShopCatalog.item_by_id("remove_ads")) or not shop_test_save.has_removed_ads() or not shop_test_save.has_furniture("vip_nameplate"):
		level_errors.append("광고 제거 상점 지급 오류")
	if shop_test_save.apply_verified_shop_item(ShopCatalog.item_by_id("remove_ads")):
		level_errors.append("광고 제거 중복 구매 차단 오류")
	if not shop_test_save.consume_rewarded_ad_skip("clear_reward_double") or shop_test_save.can_skip_rewarded_ad("clear_reward_double"):
		level_errors.append("VIP 선택형 보상 광고 일일 스킵 오류")
	var starter_pack := ShopCatalog.item_by_id("starter_rescue_pack")
	var starter_dust_before := shop_test_save.get_stardust()
	if not shop_test_save.apply_verified_shop_item(starter_pack) or shop_test_save.get_stardust() != starter_dust_before + int(starter_pack.get("stardust", 0)) or not shop_test_save.has_furniture("sofa_p"):
		level_errors.append("새내기 구조대 패키지 지급 오류")
	if shop_test_save.apply_verified_shop_item(starter_pack) or not shop_test_save.has_purchased_shop_item("starter_rescue_pack"):
		level_errors.append("패키지 중복 구매 차단/보유 기록 오류")
	var decor_pack := ShopCatalog.item_by_id("hideout_decor_pack")
	if not shop_test_save.apply_verified_shop_item(decor_pack):
		level_errors.append("아지트 꾸미기 패키지 지급 오류")
	for exclusive_furniture_id in decor_pack.get("furniture_ids", []):
		if not shop_test_save.has_furniture(String(exclusive_furniture_id)):
			level_errors.append("꾸미기 팩 한정 가구 누락: %s" % String(exclusive_furniture_id))
	var segment_test_save := SaveGame.new()
	segment_test_save.persistence_enabled = false
	if not segment_test_save.is_level_segment_unlocked(1) or segment_test_save.can_unlock_level_segment(1):
		level_errors.append("광고 없는 캠페인 구간 공개 오류")
	segment_test_save.award_stars(99, 1)
	if not segment_test_save.is_unlocked(100):
		level_errors.append("100레벨 클리어 후 다음 레벨 자동 해금 오류")
	for campaign_level in range(1, 51):
		var campaign_design := EarlyCampaignCatalogLib.design_for_level(campaign_level)
		if campaign_design.is_empty():
			level_errors.append("초반 캠페인 설계 누락: LEVEL %d" % campaign_level)
	if float(Levels.get_level(0).get("time", 0.0)) < 95.0 or float(Levels.get_level(9).get("time", 0.0)) < 88.0 or float(Levels.get_level(19).get("time", 0.0)) < 78.0:
		level_errors.append("초반 20레벨 학습 시간 보호 오류")
	var feature_test := SaveGame.new()
	feature_test.persistence_enabled = false
	if feature_test.home_feature_unlocked("attendance") or feature_test.home_feature_unlocked("shop"):
		level_errors.append("신규 계정 홈 기능 순차 해금 오류")
	feature_test.award_stars(1, 1)
	if not feature_test.home_feature_unlocked("attendance") or feature_test.home_feature_unlocked("decorate"):
		level_errors.append("출석/꾸미기 순차 해금 경계 오류")
	feature_test.award_stars(2, 1)
	if not feature_test.home_feature_unlocked("decorate"):
		level_errors.append("꾸미기 해금 오류")
	feature_test.award_stars(8, 1)
	if not feature_test.home_feature_unlocked("shop"):
		level_errors.append("상점 해금 오류")
	for campaign_error in EarlyCampaignCatalogLib.validate():
		level_errors.append(campaign_error)
	for signature_level in range(5, 51, 5):
		var signature_data: Dictionary = Levels.get_level(signature_level - 1).get("signature", {})
		if signature_data.is_empty() or String(signature_data.get("reward_line", "")).is_empty():
			level_errors.append("시그니처 레벨 런타임 연결 오류: LEVEL %d" % signature_level)
	var furniture_test_save := SaveGame.new()
	furniture_test_save.persistence_enabled = false
	furniture_test_save.grant_stardust(1000)
	var sofa_price := RoomData.furniture_price("sofa_p")
	if not furniture_test_save.purchase_furniture("sofa_p", sofa_price) or not furniture_test_save.has_furniture("sofa_p") or furniture_test_save.get_stardust() != 1000 - sofa_price:
		level_errors.append("가구 별가루 구매/영구 보유 오류")
	if furniture_test_save.purchase_furniture("sofa_p", sofa_price):
		level_errors.append("가구 중복 구매 차단 오류")
	var milestone_test_save := SaveGame.new()
	milestone_test_save.persistence_enabled = false
	var milestone_reward := milestone_test_save.claim_level_furniture_reward(10)
	if String(milestone_reward.get("furniture_id", "")) != "ach_first" or not milestone_test_save.has_furniture("ach_first"):
		level_errors.append("10단위 가구 보상 지급 오류")
	if not milestone_test_save.claim_level_furniture_reward(10).is_empty():
		level_errors.append("10단위 가구 보상 중복 지급 차단 오류")
	var journey_reward := milestone_test_save.claim_level_furniture_reward(300)
	if String(journey_reward.get("furniture_id", "")) != "journey_throne" or not milestone_test_save.has_furniture("journey_throne"):
		level_errors.append("300레벨 장기 가구 보상 지급 오류")
	var live_test_save := SaveGame.new()
	live_test_save.persistence_enabled = false
	var first_mail: Dictionary = LiveMessageCatalogLib.mail()[0]
	if not live_test_save.claim_mail(first_mail) or live_test_save.claim_mail(first_mail):
		level_errors.append("우편 보상 중복 수령 차단 오류")
	var initial_time_boosters := live_test_save.get_booster_count("time")
	if not live_test_save.consume_booster("time") or live_test_save.get_booster_count("time") != initial_time_boosters - 1:
		level_errors.append("구조 보조 아이템 소모 오류")
	for mission in LiveProgressionCatalogLib.weekly().get("missions", []):
		live_test_save.record_weekly_action(String(mission.get("id", "")), int(mission.get("target", 0)))
	if live_test_save.claim_weekly_reward().is_empty() or not live_test_save.claim_weekly_reward().is_empty():
		level_errors.append("주간 보상 수령/중복 차단 오류")
	var daily_activity_reward := live_test_save.complete_daily_challenge()
	if daily_activity_reward.is_empty() or not live_test_save.has_completed_daily_challenge() or not live_test_save.complete_daily_challenge().is_empty():
		level_errors.append("일일 특별 구조 보상/중복 차단 오류")
	for expedition_step in range(5):
		if live_test_save.complete_weekly_expedition_step(expedition_step).is_empty():
			level_errors.append("주간 원정 %d단계 보상 오류" % (expedition_step + 1))
	if live_test_save.get_weekly_expedition_step() != 5 or not live_test_save.complete_weekly_expedition_step(4).is_empty():
		level_errors.append("주간 원정 완주/중복 차단 오류")
	if MetaProgressionCatalogLib.hero_stage(0) != 1 or MetaProgressionCatalogLib.hero_stage(300) != 7 or MetaProgressionCatalogLib.hero_stage(900) != 13:
		level_errors.append("대표 젤리몬 장기 성장 단계 오류")
	var bond_test_save := SaveGame.new()
	bond_test_save.persistence_enabled = false
	bond_test_save.register_rescued_jelly(0)
	var bond_records := bond_test_save.get_resident_records()
	if bond_records.is_empty():
		level_errors.append("주민 친밀도 테스트용 주민 생성 오류")
	else:
		var bond_id := String(bond_records[0].get("id", ""))
		var first_bond_gain := bond_test_save.add_resident_affection(bond_id, 99)
		var capped_bond_gain := bond_test_save.add_resident_affection(bond_id, 1)
		var updated_bond: Dictionary = bond_test_save.get_resident_records()[0]
		if int(first_bond_gain.get("granted", 0)) != GameBalanceCatalogLib.retention("resident_affection_daily_cap", 5) or int(capped_bond_gain.get("granted", -1)) != 0 or int(updated_bond.get("affection", 0)) != 5:
			level_errors.append("주민 친밀도 일일 상한 오류")
	var retention_test := SaveGame.new()
	retention_test.persistence_enabled = false
	retention_test.register_rescued_jelly(0)
	retention_test.register_rescued_jelly(10)
	retention_test.refresh_resident_requests()
	if retention_test.resident_requests.size() != 2:
		level_errors.append("일일 주민 부탁 생성 오류")
	else:
		for request in retention_test.resident_requests:
			retention_test.record_retention_action(String(request.action), int(request.target))
		for request in retention_test.resident_requests:
			if retention_test.claim_resident_request(String(request.id)).is_empty():
				level_errors.append("주민 부탁 완료/보상 오류")
	retention_test.add_season_xp(100)
	if retention_test.season_level() < 5 or retention_test.claim_retention_season_reward(5, false).is_empty():
		level_errors.append("28일 무료 시즌 보상 오류")
	var season_product := ShopCatalog.item_by_id("season_heart_star_pass")
	if not retention_test.apply_verified_shop_item(season_product) or not retention_test.season_premium or not retention_test.has_furniture("season_welcome_sign"):
		level_errors.append("프리미엄 시즌 상품 지급 오류")
	if retention_test.claim_retention_season_reward(5, true).is_empty():
		level_errors.append("프리미엄 시즌 보상 수령 오류")
	retention_test.award_stars(299, 1)
	for _point in range(5): retention_test.grant_restoration_point(301)
	if retention_test.upgrade_town("plaza").is_empty() or int(retention_test.town_levels.get("plaza", 0)) != 1:
		level_errors.append("301레벨 이후 마을 복구 오류")
	if retention_test.get_resident_records().is_empty():
		retention_test.register_rescued_jelly(0)
	if not retention_test.get_resident_records().is_empty():
		retention_test.resident_records[0]["affection"] = 60
	var support_test: Dictionary = retention_test.adventure_support()
	if float(support_test.get("time_bonus", 0.0)) <= 0.0 or not bool(support_test.get("free_hint", false)):
		level_errors.append("주민 친밀도 원정 지원 연결 오류")
	var vip_test := SaveGame.new()
	vip_test.persistence_enabled = false
	if not vip_test.apply_verified_shop_item(ShopCatalog.item_by_id("remove_ads")) or vip_test.claim_vip_daily_support().is_empty() or not vip_test.claim_vip_daily_support().is_empty():
		level_errors.append("VIP 일일 구조 지원 오류")
	if not retention_test.record_weekly_activity_time(42.5) or retention_test.record_weekly_activity_time(50.0):
		level_errors.append("주간 특별 구조 최고 기록 오류")
	var shared_room := retention_test.parse_room_share_code(retention_test.room_share_code())
	if shared_room.is_empty() or int(shared_room.get("stars", 0)) <= 0:
		level_errors.append("아지트 방문 코드 생성/해석 오류")
	var analytics_test := AnalyticsServiceLib.new()
	analytics_test.initialize(false)
	if not analytics_test.track("screen_view", {"screen": "validation"}):
		level_errors.append("분석 이벤트 기록 오류")
	if not analytics_test.track("resident_request", {"request_id":"validation","resident_id":"R_1","result":"claimed"}):
		level_errors.append("리텐션 분석 이벤트 기록 오류")
	analytics_test.flush()
	analytics_test.free()
	return level_errors
