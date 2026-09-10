extends Node
func _ready() -> void:
	var save := SaveGame.new()
	save.persistence_enabled = false
	assert(RoomData.ROOM_THEMES[0].id == "b")
	assert(save.get_room_theme() == "b")
	assert(save.set_room_theme("b"))
	assert(not save.set_room_theme("a"))
	assert(not save.set_room_theme("d"))
	save.stars["18"] = 3
	assert(not save.set_room_theme("a"))
	save.stars["19"] = 1
	assert(save.set_room_theme("a"))
	save.stars["38"] = 3
	assert(not save.set_room_theme("d"))
	save.stars["39"] = 1
	assert(save.set_room_theme("d"))
	assert(not save.set_room_theme("invalid"))
	save.stars.clear()
	assert(save.get_room_theme() == "b")
	assert(RoomData.room_theme("invalid").id == "b")
	print("[theme unlocks] default order, level 20/40 boundaries and locked selection PASSED")
	get_tree().quit()
