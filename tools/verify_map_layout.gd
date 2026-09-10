extends Node
class FixtureMain extends "res://scripts/Main.gd":
	func _ready() -> void:
		pass

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var main := FixtureMain.new()
	main.save.persistence_enabled = false
	add_child(main)
	main._initialize_runtime()
	for i in range(85):
		main.save.stars[str(i)] = 1
	main.show_map(true)
	await get_tree().create_timer(0.4).timeout
	var map: MapScreen = main.current_screen
	for chapter in range(10):
		var points := map._chapter_path_points(chapter)
		for i in range(9):
			assert(points[i + 1].y < points[i].y, "Levels must ascend")
		assert(points[9].y - 54 > 0, "Highest level must remain below header")
	var previous_y := -1.0
	for section in map.chapter_list.get_children():
		assert(section.position.y >= previous_y)
		previous_y = section.position.y
	var stage := map.scroll_target_stage
	var current_y := stage.global_position.y + map.current_scroll_target
	assert(current_y > map.map_scroll.global_position.y)
	assert(current_y < map.map_scroll.global_position.y + map.map_scroll.size.y)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/map-layout/current-level.png")
	map.map_scroll.scroll_vertical = int(stage.global_position.y - map.chapter_list.global_position.y)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/map-layout/chapter-header.png")
	map._shift_chapter(-1)
	await get_tree().create_timer(0.2).timeout
	assert(is_instance_valid(map.scroll_target_stage))
	print("[map-layout] ascending levels, header clearance, current-level scroll and chapter navigation passed")
	main._request_shutdown()
