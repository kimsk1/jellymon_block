extends Node
const Service = preload("res://scripts/RankingService.gd")
const Screen = preload("res://scripts/RankingScreen.gd")
class FixtureMain extends "res://scripts/Main.gd":
	func _ready() -> void: pass

var errors: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var save := SaveGame.new()
	save.storage_path = "res://output/hive-ranking/test-save.json"
	save.stars = {"9":3,"99":2}
	check(save.three_star_ranking_record().is_empty(), "Legacy time must not be invented")
	check(not save.record_three_star_clear(99,2), "Two stars excluded")
	check(save.record_three_star_clear(9,3), "Three star completion captured")
	var first := save.three_star_ranking_record()
	check(first.level == 10, "Highest overall two-star level excluded")
	check(not save.record_three_star_clear(9,3), "Replay must not change first achievement")
	check(save.three_star_ranking_record() == first, "First timestamp immutable")
	save.stars["19"] = 3
	save.record_three_star_clear(19,3)
	check(save.three_star_ranking_record().level == 20, "Higher three-star level wins")
	var restored := SaveGame.new()
	restored.storage_path = save.storage_path
	restored.load_data()
	check(restored.three_star_ranking_record() == save.three_star_ranking_record(), "Ranking record persists")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.storage_path))
	var main := FixtureMain.new()
	main.save.persistence_enabled = false
	main.save.stars["999"] = 3
	main.save.three_star_first_at_ms["999"] = 1788900001234
	main.platform = PlatformService.new()
	main.platform.logged_in = true
	main.platform.player_id = "2"
	main.ranking = Service.new()
	main.add_child(main.platform)
	main.add_child(main.ranking)
	get_tree().root.add_child(main)
	main.ranking.configure(main.platform, main.save)
	main.ranking.refresh()
	check(main.ranking.entries.is_empty() and main.ranking.status.contains("준비 중"), "Unconfigured service never shows fake live ranks")
	var rows := []
	for i in range(100):
		rows.append({"player_id":str(i+1),"nickname":"구조대원 %03d" % (i+1),"level":1000-i/2,"stars":3,"achieved_at_ms":1788900000000+i*1234})
	rows[0].nickname = "별빛젤리구조대장말랑이"
	rows.reverse()
	main.ranking._on_read(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"entries":rows}).to_utf8_buffer())
	check(main.ranking.entries.size() == 100 and main.ranking.entries[0].player_id == "1", "Top100 level and first-time ordering")
	var invalid := rows.duplicate(true)
	invalid[0].stars = 2
	main.ranking._on_read(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"entries":invalid}).to_utf8_buffer())
	check(main.ranking.status.contains("형식"), "Invalid eligibility in server response rejected")
	for theme in ["a", "b", "d"]:
		ArtDirection.set_room_theme(theme)
		get_tree().root.theme = ArtDirection.ui_theme()
		var screen := Screen.new()
		screen.main = main
		main.add_child(screen)
		main.ranking.status = "미리보기 · 가상 유저 100명 (실제 랭킹 아님)"
		main.ranking.changed.emit()
		await get_tree().process_frame
		check(screen._list.get_child_count() == 100, "All 100 rows rendered")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://output/hive-ranking/preview-" + theme + ".png")
		if theme == "b" and DisplayServer.get_name() != "headless":
			var scroll: ScrollContainer = screen._list.get_parent()
			scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://output/hive-ranking/preview-bottom.png")
		screen.queue_free()
		await get_tree().process_frame
	main.queue_free()
	if errors.is_empty(): print("[Ranking] eligibility, first achievement, migration, ordering, unavailable state and 100-row A/B/D UI PASSED")
	for error in errors: push_error(error)
	get_tree().quit(0 if errors.is_empty() else 1)
