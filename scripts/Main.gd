extends Node
## 루트: 화면 전환 + 저장 + 오디오 (02 문서 7장 상태 머신 간소판)

var audio: AudioMgr
var save := SaveGame.new()
var current_screen: Node = null
var game: Game = null


func _ready() -> void:
	randomize()
	var level_errors := Levels.validate_all()
	if SaveGame.calculate_stardust_reward(0, 1) != 1:
		level_errors.append("별가루 보상 오류: 0성→1성")
	if SaveGame.calculate_stardust_reward(1, 3) != 5:
		level_errors.append("별가루 보상 오류: 1성→3성")
	if SaveGame.calculate_stardust_reward(3, 3) != 0:
		level_errors.append("별가루 보상 오류: 3성 재클리어")
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
		stardust_reward = save.award_stars(idx, stars)
		if refund_reserved_energy:
			save.refund_energy()
	return stardust_reward


func _screenshot_run() -> void:
	## 개발용: 화면 캡처 (xvfb 환경 QA)
	await get_tree().create_timer(1.2).timeout
	await _snap("shot_title.png")
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
