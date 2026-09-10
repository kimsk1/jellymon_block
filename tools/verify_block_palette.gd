extends Node

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	get_tree().root.size = Vector2i(720, 900)
	get_tree().root.content_scale_size = Vector2i(720, 900)
	get_tree().root.theme = ArtDirection.ui_theme()
	var bg := ColorRect.new()
	bg.color = Color("#fff7e9")
	bg.size = Vector2(720,900)
	add_child(bg)
	var title := Label.new()
	title.add_theme_color_override("font_color", Color("#765338"))
	title.text = "블록 색상 비교 · 진주색"
	title.position = Vector2(70,35)
	title.add_theme_font_size_override("font_size",32)
	add_child(title)
	var ids := ["Y", "O", "G", "B", "R", "P"]
	for i in ids.size():
		var cid: String = ids[i]
		var origin := Vector2(75 + (i % 3) * 220, 120 + (i / 3) * 365)
		var label := Label.new()
		label.add_theme_color_override("font_color", Color("#765338"))
		label.text = G.COLOR_NAMES[cid]
		label.position = origin
		label.add_theme_font_size_override("font_size",26)
		add_child(label)
		var jelly := Jelly.new()
		add_child(jelly)
		jelly.setup(cid,false)
		jelly.position = origin + Vector2(55,95)
		var block := Catcher.new()
		add_child(block)
		block.setup(cid,"H2",2)
		block.set_process(false)
		block.position = origin + Vector2(-25,170)
	assert(G.COLOR_NAMES["O"] == "진주")
	assert(G.jelly_tex("O") == G.jelly_tex("O"))
	var original: Texture2D = load("res://assets/jelly_O_v5.png")
	var before := original.get_image()
	var after := G.jelly_tex("O").get_image()
	assert(before.get_size() == after.get_size())
	for y in range(before.get_height()):
		for x in range(before.get_width()):
			assert(is_equal_approx(before.get_pixel(x,y).a,after.get_pixel(x,y).a))
	await get_tree().create_timer(0.5).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(get_tree().root.get_texture().get_image().save_png("res://output/block-palette/pearl_comparison.png") == OK)
	print("[block palette] six colors rendered; cached texture and alpha preservation passed")
	get_tree().quit()
