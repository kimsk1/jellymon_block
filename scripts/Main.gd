extends Node
## 루트: 화면 전환 + 저장 + 오디오 (02 문서 7장 상태 머신 간소판)

const DailyMissionCatalogLib = preload("res://scripts/DailyMissionCatalog.gd")
const JellyDexCatalogLib = preload("res://scripts/JellyDexCatalog.gd")
const LiveMessageCatalogLib = preload("res://scripts/LiveMessageCatalog.gd")
const LiveProgressionCatalogLib = preload("res://scripts/LiveProgressionCatalog.gd")
const PlatformServiceLib = preload("res://scripts/PlatformService.gd")

signal rewarded_ad_requested(on_reward: Callable, on_unavailable: Callable)

var audio: AudioMgr
var platform: Node
var save := SaveGame.new()
var current_screen: Node = null
var game: Game = null
var last_furniture_reward: Dictionary = {}


func _ready() -> void:
	randomize()
	var level_errors := Levels.validate_all()
	level_errors.append_array(RoomData.validate_catalog())
	level_errors.append_array(ShopCatalog.validate_catalog())
	level_errors.append_array(FurnitureRewardCatalog.validate())
	level_errors.append_array(ScenarioCatalog.validate())
	level_errors.append_array(DailyMissionCatalogLib.validate())
	level_errors.append_array(JellyDexCatalogLib.validate())
	level_errors.append_array(LiveMessageCatalogLib.validate())
	level_errors.append_array(LiveProgressionCatalogLib.validate())
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
	if not shop_test_save.apply_verified_shop_item(ShopCatalog.item_by_id("remove_ads")) or not shop_test_save.has_removed_ads():
		level_errors.append("광고 제거 상점 지급 오류")
	if shop_test_save.apply_verified_shop_item(ShopCatalog.item_by_id("remove_ads")):
		level_errors.append("광고 제거 중복 구매 차단 오류")
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
	if not level_errors.is_empty():
		for message in level_errors:
			push_error("[level validation] " + message)
	if OS.get_cmdline_user_args().has("--bake-levels"):
		var bake_error := Levels.rebuild_and_bake_levels()
		var rebuilt_errors := Levels.validate_all()
		print("[level bake] path=", Levels.BAKED_LEVELS_PATH, " error=", bake_error, " validation_errors=", rebuilt_errors.size())
		get_tree().quit(0 if bake_error == OK and rebuilt_errors.is_empty() else 1)
		return
	if OS.get_cmdline_user_args().has("--validate-levels"):
		print("[level validation] levels=", Levels.LEVELS.size(), " errors=", level_errors.size())
		var shape_counts := {}
		for level in Levels.LEVELS:
			for spec in level.catchers:
				shape_counts[spec.shape] = int(shape_counts.get(spec.shape, 0)) + 1
		print("[level validation] shapes=", shape_counts)
		get_tree().quit(0 if level_errors.is_empty() else 1)
		return
	audio = AudioMgr.new()
	add_child(audio)
	platform = PlatformServiceLib.new()
	add_child(platform)
	platform.initialize()
	# 자동 QA는 메모리에서만 진행해 개발자의 실제 플레이 계정을 오염시키지 않는다.
	if OS.get_cmdline_user_args().has("--shots") or OS.get_cmdline_user_args().has("--shot-room-refresh") or OS.get_cmdline_user_args().has("--shot-home-menu") or OS.get_cmdline_user_args().has("--shot-room-edit") or OS.get_cmdline_user_args().has("--shot-level-39") or OS.get_cmdline_user_args().has("--shot-level-51") or OS.get_cmdline_user_args().has("--shot-late-gimmicks") or DisplayServer.get_name() == "headless":
		save.persistence_enabled = false
	save.load_data()
	audio.enabled = save.sound_enabled
	G.haptics_enabled = save.haptics_enabled
	if OS.get_cmdline_user_args().has("--shot-room-refresh") or OS.get_cmdline_user_args().has("--shot-room-edit"):
		save.room_placements = RoomData.default_placements()
	show_title()
	if OS.get_cmdline_user_args().has("--shots"):
		_screenshot_run()
	elif OS.get_cmdline_user_args().has("--shot-room-refresh"):
		_screenshot_room_refresh()
	elif OS.get_cmdline_user_args().has("--shot-home-menu"):
		_screenshot_home_menu()
	elif OS.get_cmdline_user_args().has("--shot-room-edit"):
		_screenshot_room_edit()
	elif OS.get_cmdline_user_args().has("--shot-level-51"):
		_screenshot_level_51()
	elif OS.get_cmdline_user_args().has("--shot-level-39"):
		_screenshot_level_39()
	elif OS.get_cmdline_user_args().has("--shot-late-gimmicks"):
		_screenshot_late_gimmicks()
	elif OS.get_cmdline_user_args().has("--validate-story-typing"):
		_headless_story_typing_test()
	elif OS.get_cmdline_user_args().has("--validate-touch"):
		_headless_touch_test()
	elif OS.get_cmdline_user_args().has("--validate-delayed-trap"):
		_headless_delayed_trap_test()
	elif OS.get_cmdline_user_args().has("--validate-level-39"):
		_headless_level_39_test()
	elif OS.get_cmdline_user_args().has("--validate-level-17"):
		_headless_level_17_test()
	elif OS.get_cmdline_user_args().has("--validate-level-7"):
		_headless_level_7_test()
	elif OS.get_cmdline_user_args().has("--validate-level-44"):
		_headless_level_44_test()
	elif OS.get_cmdline_user_args().has("--validate-expansion"):
		_headless_expansion_test()
	elif OS.get_cmdline_user_args().has("--validate-late-play"):
		_headless_late_play_test()
	elif OS.get_cmdline_user_args().has("--validate-memory"):
		_headless_memory_stress_test()
	elif DisplayServer.get_name() == "headless":
		_headless_smoke_test()


func _clear_screen() -> void:
	if current_screen and is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = null
	game = null


func show_title() -> void:
	_clear_screen()
	var t := Title.new()
	t.main = self
	add_child(t)
	current_screen = t


func show_map(skip_pending_story: bool = false) -> void:
	var interactive := not OS.get_cmdline_user_args().has("--shots") and DisplayServer.get_name() != "headless"
	if interactive and not skip_pending_story:
		for chapter_index in range(5):
			var final_level := chapter_index * 10 + 9
			var sequence_id := "chapter_%02d_end" % (chapter_index + 1)
			if save.get_stars(final_level) > 0 and not save.has_seen_scenario(sequence_id):
				show_story(ScenarioCatalog.chapter(chapter_index, "end"), func(): show_map(true))
				return
	_clear_screen()
	var m := MapScreen.new()
	m.main = self
	add_child(m)
	current_screen = m


func show_story(sequence: Dictionary, on_finished: Callable) -> void:
	if sequence.is_empty():
		if on_finished.is_valid():
			on_finished.call_deferred()
		return
	_clear_screen()
	var story := StoryScreen.new()
	story.main = self
	story.sequence = sequence
	story.on_finished = on_finished
	add_child(story)
	current_screen = story


func show_story_overlay(sequence: Dictionary, on_finished: Callable) -> void:
	## 클리어 직후 이야기는 게임 노드를 유지한 채 전체 화면 위에 재생한다.
	if sequence.is_empty():
		if on_finished.is_valid():
			on_finished.call_deferred()
		return
	var story := StoryScreen.new()
	story.main = self
	story.sequence = sequence
	story.on_finished = on_finished
	story.z_index = 200
	add_child(story)


func play_intro_if_needed() -> bool:
	if not save.has_nickname() or save.has_seen_scenario("intro"):
		return false
	show_story(ScenarioCatalog.intro(), Callable(self, "show_title"))
	return true


func start_level(idx: int, bypass_energy: bool = false, skip_story: bool = false) -> void:
	if idx >= Levels.LEVELS.size():
		show_map()
		return
	# 현재 제작된 시나리오는 1~5장까지이며, 확장 챕터는 바로 게임으로 진입한다.
	if not bypass_energy and not skip_story and idx % 10 == 0 and idx < 50:
		var chapter_index := idx / 10
		var sequence_id := "chapter_%02d_start" % (chapter_index + 1)
		if not save.has_seen_scenario(sequence_id):
			show_story(ScenarioCatalog.chapter(chapter_index, "start"), func(): start_level(idx, false, true))
			return
	var energy_reserved := false
	# L1~5는 튜토리얼 보호 구간. 이후에는 입장 시 예약 차감하고 클리어 시 반환한다.
	if idx >= 5 and not bypass_energy:
		if not save.reserve_energy():
			show_map()
			if current_screen is MapScreen:
				current_screen.call_deferred("show_energy_empty")
			return
		energy_reserved = true
	_clear_screen()
	var g := Game.new()
	save.record_daily_action("play")
	save.record_weekly_action("play")
	g.main = self
	g.level_idx = idx
	g.energy_reserved = energy_reserved
	add_child(g)
	current_screen = g
	game = g


func play_chapter_end_if_needed(level_idx: int, destination: Callable) -> bool:
	# 자동 플레이는 입력을 만들지 않으므로 이야기 오버레이를 건너뛴다.
	if OS.get_cmdline_user_args().has("--shots") or DisplayServer.get_name() == "headless":
		return false
	var is_chapter_end := level_idx % 10 == 9 and level_idx < 50
	var chapter_index := level_idx / 10
	var sequence_id := "chapter_%02d_end" % (chapter_index + 1)
	if is_chapter_end and not save.has_seen_scenario(sequence_id):
		show_story_overlay(ScenarioCatalog.chapter(chapter_index, "end"), destination)
		return true
	return false


func on_level_finished(idx: int, stars: int, cleared: bool, refund_reserved_energy: bool = false, reward_cap: int = -1, clear_time: float = 0.0) -> int:
	var stardust_reward := 0
	last_furniture_reward = {}
	if cleared:
		save.record_daily_action("clear")
		save.record_weekly_action("clear")
		if clear_time > 0.0:
			save.record_clear_time(idx, clear_time)
		var first_clear := save.get_stars(idx) == 0
		stardust_reward = save.award_stars(idx, stars, reward_cap)
		if first_clear:
			save.register_rescued_jelly(idx)
			last_furniture_reward = save.claim_level_furniture_reward(idx + 1)
		if refund_reserved_energy:
			save.refund_energy()
		var total_stars := 0
		for value in save.stars.values():
			total_stars += int(value)
		platform.submit_score(total_stars)
		platform.save_cloud_snapshot(save.progression_snapshot())
	return stardust_reward


func request_rewarded_ad(on_reward: Callable, on_unavailable: Callable = Callable()) -> void:
	## 광고 제거 보유자는 광고 없이 즉시 완료한다.
	if save.has_removed_ads():
		if on_reward.is_valid():
			on_reward.call_deferred()
		return
	if platform:
		platform.show_rewarded_ad(on_reward, on_unavailable)
	elif not get_signal_connection_list("rewarded_ad_requested").is_empty():
		rewarded_ad_requested.emit(on_reward, on_unavailable)
	elif on_unavailable.is_valid():
		on_unavailable.call_deferred()


func _screenshot_run() -> void:
	## 개발용: 화면 캡처 (xvfb 환경 QA)
	await get_tree().create_timer(1.2).timeout
	if current_screen is Title and not save.has_nickname():
		current_screen._show_nickname_popup()
		await get_tree().create_timer(0.25).timeout
		await _snap("shot_nickname.png")
		current_screen.nickname_input.text = "젤리친구"
		current_screen._confirm_nickname()
		await get_tree().create_timer(0.1).timeout
		if current_screen.attendance_popup:
			current_screen._close_attendance_popup()
	show_story(ScenarioCatalog.intro(), Callable(self, "show_title"))
	await get_tree().create_timer(0.45).timeout
	await _snap("shot_story_intro.png")
	if current_screen is StoryScreen:
		current_screen._finish()
	await get_tree().create_timer(0.12).timeout
	show_story(ScenarioCatalog.chapter(0, "start"), Callable(self, "show_title"))
	await get_tree().create_timer(0.45).timeout
	await _snap("shot_story_chapter_start.png")
	if current_screen is StoryScreen:
		current_screen._finish()
	await get_tree().create_timer(0.12).timeout
	show_story(ScenarioCatalog.chapter(4, "end"), Callable(self, "show_title"))
	await get_tree().create_timer(0.45).timeout
	await _snap("shot_story_chapter_end.png")
	if current_screen is StoryScreen:
		current_screen._finish()
	await get_tree().create_timer(0.12).timeout
	await _snap("shot_title.png")
	if current_screen is Title:
		current_screen._show_shop_popup()
	await get_tree().create_timer(0.2).timeout
	await _snap("shot_shop.png")
	var qa_buy_button := Button.new()
	if current_screen is Title:
		current_screen.add_child(qa_buy_button)
		current_screen._show_purchase_confirmation(ShopCatalog.item_by_id("heart_5"), qa_buy_button)
	await get_tree().create_timer(0.2).timeout
	await _snap("shot_purchase_confirm.png")
	if current_screen is Title:
		current_screen._close_purchase_confirmation()
	if is_instance_valid(qa_buy_button):
		qa_buy_button.queue_free()
	if current_screen is Title:
		current_screen._close_shop_popup()
		current_screen._show_attendance_popup()
	await get_tree().create_timer(0.2).timeout
	await _snap("shot_attendance.png")
	if current_screen is Title:
		current_screen._close_attendance_popup()
		current_screen._enter_edit_mode()
	await get_tree().create_timer(0.2).timeout
	await _snap("shot_room_edit.png")
	if current_screen is Title:
		current_screen._leave_edit_mode()
		current_screen._enter_photo_mode()
	await get_tree().create_timer(0.2).timeout
	await _snap("shot_room_photo.png")
	if current_screen is Title:
		await current_screen._save_photo()
		current_screen._leave_photo_mode()
		current_screen._show_album()
	await get_tree().create_timer(0.2).timeout
	await _snap("shot_room_album.png")
	show_map()
	await get_tree().create_timer(0.6).timeout
	await _snap("shot_map.png")
	if current_screen is MapScreen:
		current_screen.show_energy_empty()
	await get_tree().create_timer(0.2).timeout
	await _snap("shot_energy.png")
	# 색상별 젤리 배출구가 포함된 L10을 대표 시스템 시각 회귀 테스트 대상으로 사용한다.
	start_level(9, true)
	await get_tree().create_timer(1.2).timeout
	if game:
		game.debug_capture_one()
	await get_tree().create_timer(0.14).timeout
	await _snap("shot_absorb.png")
	if game:
		game.debug_capture_one()
	await get_tree().create_timer(0.14).timeout
	await _snap("shot_play.png")
	if game:
		game.hud.show_result(3, 1234, 5, save.get_stardust(), 42.35, 39.2, true, func(): pass, func(): pass, func(): pass)
	await get_tree().create_timer(0.25).timeout
	await _snap("shot_clear_reward.png")
	if game:
		game.hud._request_clear_double_reward()
	await get_tree().create_timer(1.1).timeout
	await _snap("shot_clear_reward_doubled.png")
	start_level(9, true)
	await get_tree().create_timer(0.5).timeout
	# 개발 캡처에서만 임시 잔액을 사용해 별가루 이어하기 팝업을 시각 검수한다(저장하지 않음).
	if game:
		save.stardust = 27
		game._fail()
	await get_tree().create_timer(1.1).timeout
	await _snap("shot_fail_stardust.png")
	get_tree().quit()


func _snap(fname: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/jellymon_" + fname)
	print("[snap] ", fname)


func _screenshot_room_refresh() -> void:
	## 첫 방 그래픽만 빠르게 검수하는 전용 캡처. 실제 저장 데이터는 변경하지 않는다.
	await get_tree().create_timer(0.8).timeout
	await _snap("room_refresh.png")
	get_tree().quit()


func _screenshot_home_menu() -> void:
	await get_tree().create_timer(0.45).timeout
	if current_screen is Title:
		current_screen._show_home_menu()
	await get_tree().create_timer(0.35).timeout
	await _snap("home_menu.png")
	get_tree().quit()


func _screenshot_room_edit() -> void:
	## 꾸미기 메뉴의 하단 정렬을 빠르게 검수한다.
	await get_tree().create_timer(0.4).timeout
	if current_screen is Title:
		current_screen._enter_edit_mode()
	await get_tree().create_timer(0.4).timeout
	await _snap("room_edit_bottom.png")
	get_tree().quit()


func _screenshot_level_51() -> void:
	## 확장 캠페인의 얼음 젤리 가독성을 빠르게 검수한다.
	start_level(50, true, true)
	await get_tree().create_timer(0.8).timeout
	await _snap("level_51_frost.png")
	get_tree().quit()


func _screenshot_level_39() -> void:
	## 파란 S1 시작 탈출 통로 회귀 검수용 캡처.
	start_level(38, true, true)
	await get_tree().create_timer(0.8).timeout
	await _snap("level_39_blue_escape.png")
	get_tree().quit()


func _screenshot_late_gimmicks() -> void:
	## 구간별 대표 기믹과 100레벨 복합 관문의 실제 화면을 연속 캡처한다.
	for level_index in [60, 70, 80, 99]:
		start_level(level_index, true, true)
		await get_tree().create_timer(0.45).timeout
		await _snap("level_%d_gimmick.png" % (level_index + 1))
	get_tree().quit()


func _headless_story_typing_test() -> void:
	show_story(ScenarioCatalog.intro(), Callable())
	await get_tree().create_timer(0.2).timeout
	var typing_valid: bool = current_screen is StoryScreen and current_screen.debug_validate_typewriter_advance()
	var auto_valid := false
	if current_screen is StoryScreen:
		current_screen.debug_start_auto_advance_test()
		await get_tree().create_timer(StoryScreen.AUTO_ADVANCE_DELAY_SEC + 0.2).timeout
		auto_valid = current_screen is StoryScreen and current_screen.line_index == 1 and current_screen.typing
	print("[story typing validation] next_line_retypes=", typing_valid, " auto_advance_2_5s=", auto_valid)
	get_tree().quit(0 if typing_valid and auto_valid else 1)


func _headless_touch_test() -> void:
	start_level(0, true, true)
	await get_tree().create_timer(0.4).timeout
	var offsets := [Vector2(0, 140), Vector2(0, 300), Vector2(40, 0), Vector2(180, 0)]
	var failed := false
	for offset in offsets:
		var valid := game != null and game.debug_validate_touch_mapping(offset)
		print("[touch validation] offset=", offset, " valid=", valid)
		failed = failed or not valid
	var smooth_drag_valid := game != null and game.debug_validate_smooth_drag()
	print("[touch validation] smooth_drag=", smooth_drag_valid)
	failed = failed or not smooth_drag_valid
	# 이동 흔적 파티클이 정상 해제된 뒤 종료해 QA 종료 자체를 누수로 오인하지 않게 한다.
	await get_tree().create_timer(0.7).timeout
	get_tree().quit(1 if failed else 0)


func _headless_delayed_trap_test() -> void:
	start_level(0, true, true)
	await get_tree().create_timer(0.4).timeout
	var before := game.jellies.size() if game else 0
	if game:
		game.debug_capture_one()
	await get_tree().create_timer(0.08).timeout
	var reserved := 0
	var unlocked := true
	if game:
		for catcher in game.catchers:
			reserved += catcher.trapped_jellies
			unlocked = unlocked and not catcher.movement_locked
	var started := game != null and game.jellies.size() < before and game.active_absorptions > 0 and reserved > 0 and unlocked
	await get_tree().create_timer(0.24).timeout
	var held_before_burst := game != null and game.active_absorptions > 0
	await get_tree().create_timer(0.34).timeout
	var finished_after_half_second := game != null and game.active_absorptions == 0
	print("[delayed trap validation] started=", started, " held=", held_before_burst, " finished=", finished_after_half_second)
	get_tree().quit(0 if started and held_before_burst and finished_after_half_second else 1)


func _headless_level_39_test() -> void:
	start_level(38, true, true)
	await get_tree().create_timer(0.3).timeout
	var blue = null
	if game:
		for catcher in game.catchers:
			if catcher.color_id == "B" and catcher.shape_id == "S1":
				blue = catcher
				break
	var start_cell: Vector2i = blue.origin_cell if blue else Vector2i(-1, -1)
	var center_pick_valid := false
	var badge_pick_valid := false
	if blue:
		var blue_center := game.to_global(game.cell_pos(blue.origin_cell))
		center_pick_valid = game._pick_catcher(blue_center) == blue
		badge_pick_valid = game._pick_catcher(blue.badge_panel.get_global_rect().get_center()) == blue
	var moved_down: bool = blue != null and game._try_step(blue, Vector2i.DOWN)
	var valid: bool = center_pick_valid and badge_pick_valid and moved_down and blue.origin_cell == start_cell + Vector2i.DOWN
	print("[level 39 validation] blue_start=", start_cell, " center_pick=", center_pick_valid, " badge_pick=", badge_pick_valid, " moved_down=", moved_down, " valid=", valid)
	get_tree().quit(0 if valid else 1)


func _headless_level_17_test() -> void:
	start_level(16, true, true)
	await get_tree().create_timer(0.3).timeout
	var blue: Catcher = null
	if game:
		for catcher in game.catchers:
			if catcher.color_id == "B" and catcher.shape_id == "S1":
				blue = catcher
				break
	var start_cell := blue.origin_cell if blue else Vector2i(-1, -1)
	if blue:
		blue.set_full()
	var unlocked := blue != null and not blue.movement_locked
	var moved_up := blue != null and game._try_step(blue, Vector2i.UP)
	var valid := unlocked and moved_up and blue.origin_cell == start_cell + Vector2i.UP
	print("[level 17 validation] full_unlocked=", unlocked, " moved_up=", moved_up, " valid=", valid)
	get_tree().quit(0 if valid else 1)


func _headless_level_7_test() -> void:
	## 2×2 노랑 블록이 한 번에 겹치는 세 젤리를 빠짐없이 모두 가두는지 검증한다.
	start_level(6, true, true)
	await get_tree().create_timer(0.3).timeout
	var yellow: Catcher = null
	if game:
		for catcher in game.catchers:
			if catcher.color_id == "Y" and catcher.shape_id == "SQ":
				yellow = catcher
				break
	var before := game.jellies.size() if game else 0
	if yellow:
		for off in yellow.cells:
			game.catcher_at.erase(yellow.origin_cell + off)
		yellow.origin_cell = Vector2i(1, 1)
		for off in yellow.cells:
			game.catcher_at[yellow.origin_cell + off] = yellow
		yellow.position = game.origin + Vector2(yellow.origin_cell) * G.CELL
		yellow.slide_target = yellow.position
		game._absorb_footprint(yellow)
	var captured := before - game.jellies.size() if game else 0
	var reserved := yellow.trapped_jellies if yellow else 0
	var valid := yellow != null and captured == 3 and reserved == 3 and yellow.remaining_capacity == 1
	await get_tree().create_timer(0.65).timeout
	var burst_finished := game != null and game.active_absorptions == 0 and yellow.trapped_jellies == 0
	valid = valid and burst_finished
	print("[level 7 validation] captured=", captured, " reserved=", reserved, " remaining=", yellow.remaining_capacity if yellow else -1, " burst_finished=", burst_finished, " valid=", valid)
	get_tree().quit(0 if valid else 1)


func _headless_level_44_test() -> void:
	## L44의 큰 초록 V4가 위로 이동한 뒤 왼쪽 통로로 빠질 수 있는지 검증한다.
	start_level(43, true, true)
	await get_tree().create_timer(0.3).timeout
	var green_v4 = null
	if game:
		for catcher in game.catchers:
			if catcher.color_id == "G" and catcher.shape_id == "V4":
				green_v4 = catcher
				break
	var start_cell: Vector2i = green_v4.origin_cell if green_v4 else Vector2i(-1, -1)
	var moved_up: bool = green_v4 != null and game._try_step(green_v4, Vector2i.UP)
	var moved_left: bool = moved_up and game._try_step(green_v4, Vector2i.LEFT)
	var valid: bool = moved_left and green_v4.origin_cell == start_cell + Vector2i.UP + Vector2i.LEFT
	print("[level 44 validation] green_start=", start_cell, " moved_up=", moved_up, " moved_left=", moved_left, " valid=", valid)
	get_tree().quit(0 if valid else 1)


func _headless_expansion_test() -> void:
	## 10레벨 단위 공개, 4종 후반 기믹, 복합 관문, PC C 테스트 클리어를 검증한다.
	var test_save := SaveGame.new()
	test_save.persistence_enabled = false
	var visibility_valid := Levels.visible_chapter_count(test_save) == 5
	for chapter_end in [49, 59, 69, 79, 89]:
		test_save.award_stars(chapter_end, 1)
		visibility_valid = visibility_valid and Levels.visible_chapter_count(test_save) == 6 + (chapter_end - 49) / 10
	save = test_save
	var runtime_valid := true
	for level_index in [50, 60, 70, 80, 90, 91, 96, 99]:
		start_level(level_index, true, true)
		await get_tree().create_timer(0.25).timeout
		var flags := Levels._gimmick_flags(level_index + 1)
		var valid := game != null
		if valid:
			valid = (not game.frozen_at.is_empty()) == bool(flags.frost)
			valid = valid and ((not game.chain_at.is_empty()) == bool(flags.chain))
			valid = valid and ((not game.switch_at.is_empty() and not game.sealed_at.is_empty()) == bool(flags.switch))
			valid = valid and ((not game.key_unlock_at.is_empty() and not game.locked_catcher_indices.is_empty()) == bool(flags.key))
		print("[expansion validation] level=", level_index + 1, " flags=", flags, " runtime=", valid)
		runtime_valid = runtime_valid and valid
	start_level(50, true, true)
	await get_tree().create_timer(0.25).timeout
	if game:
		game._debug_clear_one_star_and_next()
	await get_tree().create_timer(0.35).timeout
	var debug_clear_valid := save.get_stars(50) == 1 and game != null and game.level_idx == 51
	print("[expansion validation] levels=", Levels.LEVELS.size(), " visibility=", visibility_valid, " runtime=", runtime_valid, " c_key_clear=", debug_clear_valid)
	get_tree().quit(0 if Levels.LEVELS.size() == 100 and visibility_valid and runtime_valid and debug_clear_valid else 1)


func _headless_late_play_test() -> void:
	## 대표 레벨을 실제 흡수·해제·배출 파이프라인으로 끝까지 자동 플레이한다.
	var failed := false
	for level_index in [50, 60, 70, 80, 90, 99]:
		start_level(level_index, true, true)
		await get_tree().create_timer(0.2).timeout
		var active_game := game
		if active_game:
			await active_game.debug_drive()
			await get_tree().create_timer(1.5).timeout
		var cleared := active_game != null and active_game.state == "clear" and save.get_stars(level_index) > 0
		print("[late play validation] level=", level_index + 1, " cleared=", cleared)
		failed = failed or not cleared
	get_tree().quit(1 if failed else 0)


func _headless_smoke_test() -> void:
	print("[smoke] start")
	var smoke_failed := false
	await get_tree().create_timer(0.4).timeout
	show_map()
	await get_tree().create_timer(0.4).timeout
	for lv in [0, 9, 19, 29, 38, 39, 49]:
		start_level(lv, true)
		await get_tree().create_timer(0.5).timeout
		if game:
			if not game.debug_validate_touch_mapping():
				push_error("[smoke] Android 긴 화면 터치 좌표/손가락 추적 오류: level=%d" % lv)
				smoke_failed = true
			await game.debug_drive()
		await get_tree().create_timer(1.0).timeout
	print("[smoke] done")
	get_tree().quit(1 if smoke_failed else 0)


func _memory_snapshot() -> Dictionary:
	return {
		"static": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
	}


func _headless_memory_stress_test() -> void:
	## 모든 챕터의 텍스처/스타일 캐시를 한 번 워밍업한 뒤 같은 레벨을 다시
	## 순회한다. Godot 메모리 할당자의 정상적인 고점 예약을 누수로 오판하지 않고,
	## 두 번째 순회에서도 계속 증가하는 객체만 검출한다.
	for i in range(Levels.LEVELS.size()):
		start_level(i % Levels.LEVELS.size(), true, true)
		await get_tree().process_frame
		await get_tree().process_frame
	_clear_screen()
	await get_tree().process_frame
	await get_tree().process_frame
	var baseline := _memory_snapshot()
	for i in range(Levels.LEVELS.size()):
		start_level(i % Levels.LEVELS.size(), true, true)
		await get_tree().process_frame
		await get_tree().process_frame
	# 한 프레임에 비정상적으로 많은 장식 효과를 요청해도 상한을 넘지 않고 모두 회수되는지 확인한다.
	for i in range(400):
		game.fx.ring(Vector2(120 + i % 8 * 40, 320 + i % 10 * 34), Color("#ff7fa0"), 0.6)
	var effect_peak := game.fx.get_child_count()
	await get_tree().create_timer(1.0).timeout
	await get_tree().process_frame
	var effect_remaining := game.fx.get_child_count()
	# 샤이니 젤리의 주기 반짝임이 동시에 1~2개 생성될 수 있으므로 스트레스 링만 회수됐는지 본다.
	var effects_drained := effect_remaining <= 4
	_clear_screen()
	for i in range(4):
		await get_tree().process_frame
	var final := _memory_snapshot()
	var node_growth := int(final.nodes) - int(baseline.nodes)
	var orphan_growth := int(final.orphans) - int(baseline.orphans)
	var resource_growth := int(final.resources) - int(baseline.resources)
	var memory_growth := int(final.static) - int(baseline.static)
	var effect_budget_valid := effect_peak <= FX.MAX_TRANSIENT_NODES and effects_drained
	var valid := node_growth <= 12 and orphan_growth <= 4 and resource_growth <= 18 and memory_growth <= 32 * 1024 * 1024 and effect_budget_valid
	print("[memory validation] baseline=", baseline, " final=", final, " growth={static:", memory_growth, ", nodes:", node_growth, ", orphans:", orphan_growth, ", resources:", resource_growth, "} effects={peak:", effect_peak, ", remaining:", effect_remaining, ", drained:", effects_drained, "} valid=", valid)
	get_tree().quit(0 if valid else 1)
