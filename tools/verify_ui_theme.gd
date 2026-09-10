extends Node
class FixtureMain extends "res://scripts/Main.gd":
	func _ready() -> void: pass
var main: FixtureMain
var count := 0
var night := "--night-theme" in OS.get_cmdline_user_args()
var errors: Array[String] = []
func _ready() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		push_error(message)
func run() -> void:
	main = FixtureMain.new()
	main.save.storage_path = "res://tmp/ui-theme/isolated-save.json"
	main.save.persistence_enabled = false
	get_tree().root.add_child(main)
	main._initialize_runtime()
	if night: main.save.set_room_theme("d")
	main.save.nickname = "말랑"
	main.save.stardust = 230
	main.save.energy = 18
	for i in range(23): main.save.stars[str(i)] = 2
	main.save.completed_tutorials.append("home_character_touch")
	get_tree().root.size = Vector2i(720,1280)
	get_tree().root.content_scale_size = Vector2i(720,1280)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	main.show_title()
	await snap("home")
	for entry in [["shop","_show_shop_popup"],["attendance","_show_attendance_popup"],["missions","_show_daily_mission_popup"],["lifestyle","_show_lifestyle_popup"],["dex","_show_jelly_dex"],["settings","_show_home_menu"],["album","_show_album"],["nickname","_show_nickname_popup"],["themes","_show_room_themes"],["decorate","_enter_edit_mode"],["feedback","_show_beta_feedback_popup"],["photo","_enter_photo_mode"]]:
		main.show_title()
		await get_tree().process_frame
		main.current_screen.call(entry[1])
		if entry[0] == "lifestyle": check(main.current_screen.lifestyle_popup != null,"Lifestyle popup did not open")
		await snap(entry[0])
	main.show_title()
	var settings: Title = main.current_screen
	settings._show_home_menu()
	await get_tree().create_timer(0.1).timeout
	var option := settings.menu_popup.find_children("*", "OptionButton", true, false)[0] as OptionButton
	option.show_popup()
	check(option.get_popup().theme == ArtDirection.ui_theme(), "Language popup theme missing")
	await snap("language_options")
	option.get_popup().hide()
	var preference := settings._preference_row("QA",true,Color.GREEN)
	var switch: Button = preference.toggle
	check(switch.get_theme_stylebox("normal").bg_color == ArtDirection.selected_color(),"ON state missing")
	settings._set_preference_switch_style(switch,false,Color.GREEN)
	check(switch.get_theme_stylebox("normal").bg_color == ArtDirection.disabled_color(),"OFF state missing")
	preference.row.free()
	main.show_title()
	var home: Title = main.current_screen
	home._show_shop_popup()
	var dummy := Button.new()
	home.add_child(dummy)
	home._show_purchase_confirmation(ShopCatalog.item_by_id("heart_5"),dummy)
	await snap("purchase")
	main.show_title()
	main.current_screen._show_toast("사진을 저장했어요!")
	await snap("toast")
	main.show_map()
	await snap("map")
	main.current_screen._show_level_card(13)
	await snap("level_card")
	main.show_map()
	main.save.energy = 0
	main.current_screen.show_energy_empty()
	await snap("energy")
	main.save.energy = 18
	main.show_story(ScenarioCatalog.intro(), Callable(main,"show_title"))
	main.current_screen.revealed = 9999
	await snap("story")
	main.start_level(9,true)
	await get_tree().create_timer(0.5).timeout
	await snap("game")
	main.game.hud.show_tutorial_step("젤리를 같은 색 마음 블록으로 옮겨 주세요",Vector2(180,520),Vector2(420,740))
	await snap("tutorial")
	main.game.hud.clear_tutorial_step()
	main.game.set_paused(true)
	await snap("pause")
	main.game.set_paused(false)
	main.game.hud.show_result(3,1234,5,230,42.35,39.2,true,func():pass,func():pass,func():pass)
	await snap("clear")
	main.start_level(9,true)
	await get_tree().create_timer(0.3).timeout
	main.game.hud.show_fail("시간이 다 됐어요",230,true,func():pass,func():pass,func():pass)
	await snap("fail")
	# Common controls must retain their state distinction and a visible keyboard focus.
	var button := Button.new()
	ArtDirection.apply_button(button,Color.CORNFLOWER_BLUE)
	check(button.get_theme_stylebox("normal").bg_color == ArtDirection.panel_color(),"Secondary button palette")
	check(button.get_theme_stylebox("disabled").bg_color != button.get_theme_stylebox("normal").bg_color,"Disabled state missing")
	check(button.get_theme_stylebox("focus").get_border_width_min() > 0,"Keyboard focus missing")
	button.free()
	check(get_tree().root.theme.get_stylebox("panel","PopupMenu").bg_color == ArtDirection.panel_color(),"Native popup theme missing")
	print("[UI theme] screens=",count," errors=",errors.size())
	main._request_shutdown(0 if errors.is_empty() else 1)
func snap(id: String) -> void:
	await get_tree().create_timer(0.4).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(get_tree().root.get_texture().get_image().save_png(("res://output/theme-d/screens/" if night else "res://output/ui-theme/")+id+".png") == OK,"Screenshot: "+id)
	if id in ["energy","level_card"]:
		for child in main.current_screen.get_children():
			if child is ColorRect and child.mouse_filter == Control.MOUSE_FILTER_STOP:
				check(child.z_index > 9,"Map marker appears above popup")
	count += 1
