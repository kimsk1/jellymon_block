class_name FurnitureArt
## 가구 아틀라스를 공유하고 각 가구의 투명 영역을 제외한 그림을 반환한다.

const CATALOG_PATH := "res://assets/data/furniture_art.json"
static var _catalog: Dictionary = {}
static var _atlases: Dictionary = {}
static var _textures: Dictionary = {}

static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		if parsed is Dictionary:
			_catalog = parsed.get("items", {})
	return _catalog

static func texture(id: String) -> Texture2D:
	if _textures.has(id):
		return _textures[id] as Texture2D
	var entry: Dictionary = catalog().get(id, {})
	if entry.is_empty():
		push_error("가구 이미지 누락: " + id)
		return null
	var path := String(entry.atlas)
	if not _atlases.has(path):
		_atlases[path] = load(path)
	var atlas := _atlases[path] as Texture2D
	if atlas == null:
		return null
	var rect: Array = entry.region
	var result := AtlasTexture.new()
	result.atlas = atlas
	result.region = Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
	result.filter_clip = true
	_textures[id] = result
	return result
