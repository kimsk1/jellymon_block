extends Node
class Fixture extends "res://scripts/Main.gd":
	func _ready() -> void: pass
var errors: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
func buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button: result.append(node)
	for child in node.get_children(): result.append_array(buttons(child))
	return result
func click(node: Node, label: String) -> bool:
	for button in buttons(node):
		if label in button.text and not button.disabled:
			button.pressed.emit()
			return true
	return false
func _ready() -> void: call_deferred("run")
func run() -> void:
	var main := Fixture.new()
	main.save.storage_path = "/tmp/jellymon-no-rewarded-flow-save.json"
	main.save.persistence_enabled = false
	add_child(main)
	main._initialize_runtime()
	var save = main.save
	for i in range(10): save.stars[str(i)] = 3
	save.nickname = "젤리친구"
	main.show_title()
	await get_tree().process_frame
	main.current_screen._show_attendance_popup()
	var before: int = save.stardust
	check(click(main.current_screen, "광고 보고 별가루"), "Home gift entry")
	var offer = main.get_node("RewardedOffer")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/jellymon-rewarded-offer.png")
	offer._watch()
	await get_tree().create_timer(0.8).timeout
	check(save.stardust == before + 5, "Home gift granted through desktop ad callback")
	check(not click(main.current_screen, "광고 보고 별가루"), "Claimed button disabled")
	main.show_map()
	await get_tree().process_frame
	save.energy = 0
	save.energy_updated_at = int(Time.get_unix_time_from_system())
	main.current_screen.show_energy_empty()
	check(click(main.current_screen, "광고 보고 하트"), "Energy entry")
	main.get_node("RewardedOffer")._watch()
	await get_tree().create_timer(0.8).timeout
	check(save.get_energy() == 1, "Energy delivered")
	main.start_level(9, true, true)
	await get_tree().create_timer(0.2).timeout
	var game = main.game
	save.booster_inventory["time"] = 0
	game.state = "play"
	game.time_left = 10.0
	game.use_booster("time")
	check(game.state == "reward_ad", "Timer paused while considering ad")
	await get_tree().create_timer(0.1).timeout
	check(game.time_left == 10.0, "No timer loss in offer")
	main.get_node("RewardedOffer")._close()
	await get_tree().process_frame
	check(game.state == "play" and save.rewarded_remaining("booster_time") == 2, "Cancel resumes without quota")
	game.use_booster("time")
	main.get_node("RewardedOffer")._watch()
	await get_tree().create_timer(0.8).timeout
	check(game.state == "play" and game.time_left > 24 and save.get_booster_count("time") == 0, "Temporary 15 seconds")
	game.state = "fail"
	game.time_left = 0.0
	check(game.can_ad_continue(), "Timeout eligible")
	game.hud.show_fail("시간이 다 됐어요!", save.stardust, true, game._continue_with_stardust, func(): pass, func(): pass)
	check(click(game.hud, "광고 보고 30초"), "Failure UI ad entry")
	main.get_node("RewardedOffer")._watch()
	await get_tree().create_timer(0.8).timeout
	check(game.time_left > 29.0 and not game.can_ad_continue(), "Shared once-per-run continuation")
	save.stardust = 100
	game.state = "fail"
	check(not game._continue_with_stardust() and save.stardust == 100, "No paid continue after ad")
	game.continued_after_fail = false
	game.time_left = 5.0
	check(not game.can_ad_continue(), "Move limit failure not eligible")
	await get_tree().create_timer(1.0).timeout
	if errors.is_empty(): print("PASS: home, energy, booster cancel/timer/reward, timeout continuation and paid exclusion")
	else:
		for error in errors: push_error(error)
	main._request_shutdown(0 if errors.is_empty() else 1)
