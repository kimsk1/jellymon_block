extends Node
## 루트: 화면 전환 + 저장 + 오디오 (02 문서 7장 상태 머신 간소판)

var audio: AudioMgr
var save := SaveGame.new()
var current_screen: Node = null
var game: Game = null


func _ready() -> void:
	randomize()
	var level_errors := Levels.validate_all()
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


func start_level(idx: int) -> void:
	if idx >= Levels.LEVELS.size():
		show_map()
		return
	_clear_screen()
	var g := Game.new()
	g.main = self
	g.level_idx = idx
	add_child(g)
	current_screen = g
	game = g


func on_level_finished(idx: int, stars: int, cleared: bool) -> void:
	if cleared:
		save.set_stars(idx, stars)


func _screenshot_run() -> void:
	## 개발용: 화면 캡처 (xvfb 환경 QA)
	await get_tree().create_timer(1.2).timeout
	await _snap("shot_title.png")
	show_map()
	await get_tree().create_timer(0.6).timeout
	await _snap("shot_map.png")
	start_level(36)
	await get_tree().create_timer(1.2).timeout
	if game:
		game.debug_capture_one()
	await get_tree().create_timer(0.14).timeout
	await _snap("shot_absorb.png")
	if game:
		game.debug_capture_one()
	await get_tree().create_timer(0.14).timeout
	await _snap("shot_play.png")
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
	for lv in [0, 9, 19, 29, 39, 49]:
		start_level(lv)
		await get_tree().create_timer(0.5).timeout
		if game:
			await game.debug_drive()
		await get_tree().create_timer(1.0).timeout
	print("[smoke] done")
	get_tree().quit()
