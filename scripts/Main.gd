extends Node
## 루트: 화면 전환 + 저장 + 오디오 (02 문서 7장 상태 머신 간소판)

signal rewarded_ad_requested(on_reward: Callable, on_unavailable: Callable)

var audio: AudioMgr
var save := SaveGame.new()
var current_screen: Node = null
var game: Game = null


func _ready() -> void:
	randomize()
	var level_errors := Levels.validate_all()
	level_errors.append_array(RoomData.validate_catalog())
	level_errors.append_array(ShopCatalog.validate_catalog())
	if SaveGame.calculate_stardust_reward(0, 1) != 1:
		level_errors.append("별가루 보상 오류: 0성→1성")
	if SaveGame.calculate_stardust_reward(1, 3) != 5:
		level_errors.append("별가루 보상 오류: 1성→3성")
	if SaveGame.calculate_stardust_reward(3, 3) != 0:
		level_errors.append("별가루 보상 오류: 3성 재클리어")
	if SaveGame.ATTENDANCE_REWARDS != [10, 20, 30, 40, 50, 60, 100]:
		level_errors.append("7일 출석 보상 구성 오류")
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
	# 자동 QA는 메모리에서만 진행해 개발자의 실제 플레이 계정을 오염시키지 않는다.
	if OS.get_cmdline_user_args().has("--shots") or DisplayServer.get_name() == "headless":
		save.persistence_enabled = false
	save.load_data()
	show_title()
	if OS.get_cmdline_user_args().has("--shots"):
		_screenshot_run()
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


func show_map() -> void:
	_clear_screen()
	var m := MapScreen.new()
	m.main = self
	add_child(m)
	current_screen = m


func start_level(idx: int, bypass_energy: bool = false) -> void:
	if idx >= Levels.LEVELS.size():
		show_map()
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
	g.main = self
	g.level_idx = idx
	g.energy_reserved = energy_reserved
	add_child(g)
	current_screen = g
	game = g


func on_level_finished(idx: int, stars: int, cleared: bool, refund_reserved_energy: bool = false) -> int:
	var stardust_reward := 0
	if cleared:
		var first_clear := save.get_stars(idx) == 0
		stardust_reward = save.award_stars(idx, stars)
		if first_clear:
			save.register_rescued_jelly(idx)
		if refund_reserved_energy:
			save.refund_energy()
	return stardust_reward


func request_rewarded_ad(on_reward: Callable, on_unavailable: Callable = Callable()) -> void:
	## 광고 제거 보유자는 광고 없이 즉시 완료한다.
	if save.has_removed_ads():
		if on_reward.is_valid():
			on_reward.call_deferred()
		return
	# 개발 빌드에서는 실제 광고 과금/네트워크 없이 완료 콜백을 검증한다.
	if OS.is_debug_build():
		await get_tree().create_timer(0.9).timeout
		if on_reward.is_valid():
			on_reward.call()
		return
	# 출시 빌드에서는 광고 SDK 연결부가 이 신호를 받아 시청 완료 후 on_reward를 호출한다.
	if not get_signal_connection_list("rewarded_ad_requested").is_empty():
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
		game.hud.show_result(3, 1234, 5, save.get_stardust(), true, func(): pass, func(): pass, func(): pass)
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


func _headless_smoke_test() -> void:
	print("[smoke] start")
	await get_tree().create_timer(0.4).timeout
	show_map()
	await get_tree().create_timer(0.4).timeout
	for lv in [0, 9, 19, 29, 38, 39, 49]:
		start_level(lv, true)
		await get_tree().create_timer(0.5).timeout
		if game:
			await game.debug_drive()
		await get_tree().create_timer(1.0).timeout
	print("[smoke] done")
	get_tree().quit()
