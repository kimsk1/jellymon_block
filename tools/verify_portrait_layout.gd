extends Node
## Run with the graphical Godot runtime to exercise native window resizing.
class FixtureMain extends "res://scripts/Main.gd":
	func _ready() -> void:
		pass

var errors: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		push_error(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var window := get_tree().root
	check(window.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "Portrait aspect must be preserved")
	var main := FixtureMain.new()
	main.save.persistence_enabled = false
	add_child(main)
	main._initialize_runtime()
	main.show_title()
	await get_tree().process_frame
	var home: Title = main.current_screen
	home._show_home_menu()
	var card := home.menu_popup.get_child(0) as Control
	# Keep the same popup open through portrait, wide, tall-phone and landscape sizes.
	for dimensions in [Vector2i(720, 1280), Vector2i(1200, 1280), Vector2i(414, 896), Vector2i(1280, 720)]:
		window.size = dimensions
		await get_tree().create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		var viewport := home.get_viewport_rect()
		var bounds := card.get_global_rect()
		check(viewport.size.is_equal_approx(Vector2(720, 1280)), "Expanded viewport at %s: %s" % [dimensions, viewport.size])
		check(absf(bounds.get_center().x - viewport.get_center().x) < 1.0, "Menu off center at %s" % dimensions)
		check(viewport.encloses(bounds), "Menu clipped at %s: %s" % [dimensions, bounds])
		# Validate physical-window centering as well as logical UI coordinates.
		var physical_center := window.get_final_transform() * bounds.get_center()
		check(absf(physical_center.x - window.size.x * 0.5) < 1.0, "Menu off center in physical window at %s" % dimensions)
		window.get_texture().get_image().save_png("res://output/portrait-layout/menu-%dx%d.png" % [dimensions.x, dimensions.y])
		print("[portrait] size=", dimensions, " viewport=", viewport.size, " menu=", bounds)
	home._close_home_menu()
	home._show_room_themes()
	await get_tree().process_frame
	var theme_card := home.room_theme_popup.get_child(0) as Control
	check(absf(theme_card.get_global_rect().get_center().x - 360.0) < 1.0, "Theme picker off center")
	print("[portrait] errors=", errors.size())
	main._request_shutdown(0 if errors.is_empty() else 1)
