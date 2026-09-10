extends Node
## Isolated furniture catalog/geometry checks and optional rendered review scenes.
const Art = preload("res://scripts/FurnitureArt.gd")
class FixtureMain extends "res://scripts/Main.gd":
	func _ready() -> void:
		pass
var errors: Array[String] = []
var root: Window:
	get: return get_tree().root
func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		push_error(message)
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var items := RoomData.all_items()
	check(Art.catalog().size() == items.size(), "Every furniture item needs exactly one image")
	for item in items:
		var tex := Art.texture(item.id)
		check(tex != null, "Missing image: " + item.id)
		if tex == null: continue
		check(tex.get_image().detect_alpha() != Image.ALPHA_NONE, "No transparency: " + item.id)
		for turn in range(4):
			var node := RoomFurniture.new()
			node.setup(item, {"x":1,"y":1,"rotation":turn}, true)
			check(node.cells == RoomData.rotated_cells(item.shape, turn), "Occupancy changed: " + item.id)
			check(node.position == RoomData.ORIGIN + Vector2.ONE * RoomData.CELL, "Placement changed")
			check(node._bounds().encloses(node.art_bounds()), "Image overflows footprint: " + item.id)
			check(is_equal_approx(node.art_bounds().size.aspect(), tex.get_size().aspect()), "Image stretched: " + item.id)
			node.free()
	var main := FixtureMain.new()
	main.save.persistence_enabled = false
	main.save.storage_path = "res://tmp/furniture-refresh/fixture-save.json"
	root.add_child(main)
	main._initialize_runtime()
	main.save.nickname = "말랑"
	for level in range(12): main.save.stars[str(level)] = 2
	main.save.stardust = 230
	main.save.energy = 18
	main.save.completed_tutorials.append("home_character_touch")
	for item in items:
		if not main.save.owned_furniture.has(item.id): main.save.owned_furniture.append(item.id)
	var placed := [
		{"id":"shelf_g","x":0,"y":0,"rotation":0},
		{"id":"lamp_y","x":6,"y":0,"rotation":0},
		{"id":"sofa_p","x":0,"y":2,"rotation":0},
		{"id":"plant_g","x":6,"y":2,"rotation":0},
		{"id":"cushion_r","x":1,"y":5,"rotation":0},
		{"id":"table_b","x":5,"y":5,"rotation":0}]
	main.save.set_room_placements(placed)
	root.size = Vector2i(720,1280)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for theme in ["a","b","d"]:
		main.save.set_room_theme(theme)
		main.show_title()
		await get_tree().process_frame
		check(main.current_screen.furniture_nodes.size() == placed.size(), "Home furniture missing")
		check(main.save.get_room_placements() == placed, "Theme changed placements")
		await snap(theme.to_upper() + "_furnished")
	var home: Title = main.current_screen
	home._enter_edit_mode()
	check(home.edit_mode and home.palette != null, "Editor did not open")
	await get_tree().process_frame
	await snap("furniture_palette")
	home.selected_index = 1
	home._rotate_selected()
	check(int(home.placements[1].rotation) == 1, "Rotation failed")
	home._remove_selected()
	check(home.placements.size() == placed.size() - 1, "Removal failed")
	home._leave_edit_mode()
	if OS.get_cmdline_user_args().has("--render-furniture"):
		main.current_screen.hide()
		root.size = Vector2i(1200,600)
		root.content_scale_size = root.size
		for group in range(5):
			var gallery := Control.new()
			root.add_child(gallery)
			var bg := ColorRect.new()
			bg.color = Color("#f4ebde")
			bg.size = Vector2(1200,600)
			gallery.add_child(bg)
			for j in range(10):
				var entry: Dictionary = items[group*10+j]
				var pic := TextureRect.new()
				pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				pic.texture = Art.texture(entry.id)
				pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				pic.position = Vector2((j%5)*240+20, (j/5)*300+15)
				pic.size = Vector2(200,235)
				gallery.add_child(pic)
				var label := Label.new()
				label.text = entry.name
				label.position = Vector2((j%5)*240, (j/5)*300+258)
				label.size = Vector2(240,32)
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				label.add_theme_color_override("font_color",Color("#584c45"))
				gallery.add_child(label)
			await snap("catalog_" + str(group+1))
			gallery.queue_free()
			await get_tree().process_frame
	print("[furniture art] items=", items.size(), " rotations=", items.size()*4, " errors=", errors.size())
	main._request_shutdown(0 if errors.is_empty() else 1)
func snap(filename: String) -> void:
	if not OS.get_cmdline_user_args().has("--render-furniture"): return
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://output/furniture-refresh/" + filename + ".png") == OK, "Screenshot failed")
