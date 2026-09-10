extends Node
## Run: Godot --headless --path . res://tools/verify_home_themes.tscn -- --shots
## Add --render-home-themes without --headless to save visual review PNGs.

class FixtureMain extends "res://scripts/Main.gd":
	func _ready() -> void:
		pass

var root: Window:
	get:
		return get_tree().root

var errors: Array[String] = []
var test_dir := "res://tmp/home-theme-tests"

func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)
		push_error(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_dir))
	var ignore := FileAccess.open(test_dir + "/.gdignore", FileAccess.WRITE)
	ignore.close()
	var save_path := test_dir + "/save_%s.json" % Time.get_ticks_usec()
	var save := SaveGame.new()
	save.storage_path = save_path
	save.load_data()
	check(save.get_room_theme() == "b", "New player must default to B")
	check(save.get_room_placements().is_empty(), "New room must be empty")
	check(save.owned_furniture.size() == 4, "Starter furniture stays in inventory")
	var placed := [{"id":"lamp_y", "x":6, "y":0, "rotation":1}]
	save.set_room_placements(placed)
	for theme in RoomData.ROOM_THEMES:
		check(save.set_room_theme(String(theme.id)), "Theme selection rejected")
		check(save.get_room_placements() == placed, "Theme switch moved furniture")
		check(load(String(theme.asset)) != null, "Missing theme texture")
	save.set_room_placements([])
	var restored := SaveGame.new()
	restored.storage_path = save_path
	restored.load_data()
	check(restored.get_room_placements().is_empty(), "Empty room repopulated on reload")
	check(restored.get_room_theme() == "d", "Theme did not persist")
	check(restored.progression_snapshot().get("room_theme_id") == "d", "Theme missing from progression snapshot")
	check(not restored.set_room_theme("invalid"), "Invalid theme accepted")
	var legacy := FileAccess.open(save_path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"room_placements":placed,"room_grid_version":2,"owned_furniture":["lamp_y"],"stars":{"0":3}}))
	legacy.close()
	var migrated := SaveGame.new()
	migrated.storage_path = save_path
	migrated.load_data()
	check(migrated.get_room_theme() == "b", "Old save must default to B")
	var existing := migrated.get_room_placements()
	check(existing.size() == 1 and existing[0].id == "lamp_y" and int(existing[0].x) == 6 and int(existing[0].y) == 0 and int(existing[0].rotation) == 1, "Existing room arrangement lost")
	legacy = FileAccess.open(save_path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"room_theme_id":"unknown","room_placements":[],"room_grid_version":2}))
	legacy.close()
	var invalid := SaveGame.new()
	invalid.storage_path = save_path
	invalid.load_data()
	check(invalid.get_room_theme() == "b", "Unknown saved theme must fall back to B")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	# Instantiate the real home and real editor against an isolated, nonpersistent save.
	var main := FixtureMain.new()
	main.save.storage_path = save_path
	main.save.persistence_enabled = false
	root.add_child(main)
	main._initialize_runtime()
	main.save.nickname = "말랑"
	for i in range(76):
		main.save.stars[str(i)] = 2 if i < 55 else 1
	main.save.stardust = 230
	main.save.energy = 18
	main.save.rescued_jellies.assign(["R", "Y", "B", "G", "P", "O"])
	main.save._migrate_resident_records()
	main.save.completed_tutorials.append("home_character_touch")
	root.size = Vector2i(720, 1280)
	root.content_scale_size = Vector2i(720, 1280)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for id in ["a", "b", "d"]:
		main.save.set_room_theme(id)
		main.show_title()
		await get_tree().process_frame
		var home: Title = main.current_screen
		check(home.placements.is_empty(), "Runtime home should be empty")
		check(home.backdrop.room_theme_id == id, "Backdrop does not match save")
		check(home.adventure_button.get_theme_stylebox("normal").bg_color == ArtDirection.primary_color(), "CTA does not match theme")
		check(home.ui_layer.find_child("GrowthBar",true,false).get_theme_stylebox("fill").bg_color == ArtDirection.growth_color(), "Growth color does not match theme")
		var nav_icons := home.nav_bar.find_children("*","Control",true,false).filter(func(node): return node is HomeNavIcon)
		check(nav_icons.size() == 4,"Missing navigation icons")
		for icon in nav_icons:
			check(icon.botanical == (id == "b") and icon.night == (id == "d"), "Wrong navigation icon family")
		await snap(id.to_upper() + "_home")
		if id in ["b","d"]:
			home._show_shop_popup()
			var purchase := Button.new()
			ArtDirection.apply_button(purchase,ArtDirection.CORAL)
			check(purchase.get_theme_stylebox("normal").bg_color == ArtDirection.primary_color(),"Popup primary color mismatch")
			purchase.free()
			await snap(id.to_upper()+"_shop")
			home._close_shop_popup()
			home._show_home_menu()
			await snap(id.to_upper()+"_settings")
			home._close_home_menu()
	var home: Title = main.current_screen
	home._show_room_themes()
	await get_tree().process_frame
	await snap("theme_picker")
	var choose := home.room_theme_popup.find_child("Theme_b", true, false) as Button
	check(choose != null and not choose.disabled, "Theme B should be selectable")
	choose.pressed.emit()
	await get_tree().process_frame
	check(main.save.get_room_theme() == "b", "Theme picker did not select B")
	check(home.adventure_button.get_theme_stylebox("normal").bg_color == Color("#43bfb0"), "B color not applied immediately")
	await snap("B_after_switch")
	home._select_room_theme("d")
	await get_tree().process_frame
	check(home.adventure_button.get_theme_stylebox("normal").bg_color == Color("#efb24f"),"D gold CTA not applied immediately")
	check(home.ui_layer.find_child("GrowthBar",true,false).get_theme_stylebox("fill").bg_color == Color("#c1779c"),"D growth bar not pink")
	check(home.header_name_label.get_theme_color("font_color") == ArtDirection.ink(),"D name contrast")
	await snap("D_after_switch")
	home._enter_edit_mode()
	await get_tree().process_frame
	home._add_furniture("lamp_y")
	await get_tree().process_frame
	check(home.placements.size() == 1, "Furniture placement failed")
	var before := home.placements.duplicate(true)
	(home.palette.find_child("EditorTheme_a", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	check(home.placements == before, "Editor theme switch moved furniture")
	check(home.edit_mode and home.selected_index == 0, "Theme switch lost editor selection")
	check(home.adventure_button.get_theme_stylebox("normal").bg_color == ArtDirection.CORAL, "A color not restored")
	(home.palette.find_child("EditorTheme_b", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	check(home.placements == before, "Switching back to B moved furniture")
	check(home.adventure_button.get_theme_stylebox("normal").bg_color == Color("#43bfb0"), "B color not restored in editor")
	(home.palette.find_child("EditorTheme_d", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	check(home.placements == before and home.edit_mode and home.selected_index == 0,"Switch to D lost editor state")
	await snap("decorate")
	home.selected_index = 0
	home._remove_selected()
	home._leave_edit_mode()
	check(main.save.get_room_placements().is_empty(), "Removing last furniture repopulated room")
	# Responsive safe offset remains valid for a tall phone and a wider tablet.
	for bounds in [Vector2i(720, 1600), Vector2i(1024, 1280)]:
		root.size = bounds
		await get_tree().process_frame
		check(home.position == G.safe_offset(home.get_viewport_rect().size), "Safe area offset mismatch")
	print("[night theme UI] errors=", errors.size())
	main._request_shutdown(0 if errors.is_empty() else 1)

func snap(filename: String) -> void:
	if not OS.get_cmdline_user_args().has("--render-home-themes"):
		return
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var path := "res://output/theme-d/" + filename + ".png"
	check(root.get_texture().get_image().save_png(path) == OK, "Screenshot failed: " + path)
