extends RefCounted
class_name SaveGame
## 진행도 저장 (user://jellymon_save.json)

const PATH := "user://jellymon_save.json"

var stars := {}


func load_data() -> void:
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if typeof(d) == TYPE_DICTIONARY and d.has("stars"):
				stars = d["stars"]


func save_data() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"stars": stars}))


func get_stars(idx: int) -> int:
	return int(stars.get(str(idx), 0))


func set_stars(idx: int, n: int) -> void:
	if n > get_stars(idx):
		stars[str(idx)] = n
		save_data()


func is_unlocked(idx: int) -> bool:
	if idx == 0:
		return true
	return get_stars(idx - 1) > 0
