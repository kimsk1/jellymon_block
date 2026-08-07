class_name ScenarioCatalog
## JSON 시나리오를 런타임 재생 형식으로 변환하고 자산 참조를 검증한다.

const ROOT := "res://assets/data/scenarios"
const MANIFEST_PATH := ROOT + "/manifest.json"


static func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func manifest() -> Dictionary:
	return _read_json(MANIFEST_PATH)


static func intro() -> Dictionary:
	var data := _read_json(ROOT + "/intro.json")
	if data.is_empty():
		return {}
	var lines: Array = []
	for scene in data.get("scenes", []):
		for line in scene.get("lines", []):
			lines.append(line)
	data["sequence_id"] = "intro"
	data["phase"] = "intro"
	data["lines"] = lines
	data["cast"] = manifest().get("cast", {})
	return data


static func chapter(chapter_index: int, phase: String) -> Dictionary:
	if chapter_index < 0 or chapter_index >= 5 or not ["start", "end"].has(phase):
		return {}
	var path := ROOT + "/chapter_%02d.json" % (chapter_index + 1)
	var data := _read_json(path)
	if data.is_empty() or not data.has(phase):
		return {}
	var sequence: Dictionary = Dictionary(data[phase]).duplicate(true)
	sequence["sequence_id"] = "chapter_%02d_%s" % [chapter_index + 1, phase]
	sequence["chapter"] = chapter_index + 1
	sequence["phase"] = phase
	sequence["title"] = "CHAPTER %d  %s" % [chapter_index + 1, String(data.get("title", ""))]
	sequence["subtitle"] = String(data.get("subtitle", ""))
	sequence["cast"] = manifest().get("cast", {})
	return sequence


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var meta := manifest()
	if meta.is_empty():
		errors.append("시나리오 manifest.json 로드 실패")
		return errors
	var sequences: Array[Dictionary] = [intro()]
	for chapter_index in range(5):
		sequences.append(chapter(chapter_index, "start"))
		sequences.append(chapter(chapter_index, "end"))
	var ids := {}
	for sequence in sequences:
		var sequence_id := String(sequence.get("sequence_id", ""))
		if sequence_id.is_empty() or ids.has(sequence_id):
			errors.append("시나리오 ID 누락 또는 중복: %s" % sequence_id)
		ids[sequence_id] = true
		var background := String(sequence.get("background_asset", ""))
		if background.is_empty() or not FileAccess.file_exists(background):
			errors.append("시나리오 배경 누락: %s" % sequence_id)
		var lines: Array = sequence.get("lines", [])
		if lines.is_empty():
			errors.append("시나리오 대사 누락: %s" % sequence_id)
		for line in lines:
			if String(line.get("text", "")).is_empty():
				errors.append("빈 시나리오 대사: %s" % sequence_id)
			var speaker := String(line.get("speaker", "narrator"))
			if not Dictionary(meta.get("cast", {})).has(speaker):
				errors.append("등록되지 않은 화자 %s: %s" % [speaker, sequence_id])
	return errors
