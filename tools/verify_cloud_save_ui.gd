extends Node
class Fixture extends "res://scripts/Main.gd":
	func _ready() -> void: pass
func _ready() -> void:
	var main := Fixture.new()
	main.save.storage_path = "/tmp/jellymon-cloud-ui-unused.json"
	main.save.persistence_enabled = false
	add_child(main)
	main._initialize_runtime()
	var local := main.save.cloud_data()
	local.nickname = "기기젤리"
	local.stardust = 15
	var remote := local.duplicate(true)
	remote.nickname = "구름젤리"
	remote.stardust = 30
	main._on_cloud_conflict(local, remote)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/cloud-save/conflict.png")
	main.get_node("CloudSaveConflict").queue_free()
	main._request_shutdown()
