class_name G
## 전역 상수/유틸

const CELL := 84.0
const W := 720.0
const H := 1280.0
static var haptics_enabled := true


static func safe_offset(viewport_size: Vector2) -> Vector2:
	## expand 스트레치가 추가한 폴드폰/태블릿 여백 안에서 720×1280 게임 영역을 중앙에 둔다.
	return Vector2(
		maxf(0.0, (viewport_size.x - W) * 0.5),
		maxf(0.0, (viewport_size.y - H) * 0.5)
	)

const COLORS := {
	"R": Color(1.0, 0.353, 0.431),
	"Y": Color(1.0, 0.788, 0.235),
	"B": Color(0.31, 0.659, 1.0),
	"G": Color(0.341, 0.839, 0.42),
	"P": Color(0.69, 0.424, 0.941),
	"O": Color("#f4f0ea"),
}

const COLOR_NAMES := {"R": "빨강", "Y": "노랑", "B": "파랑", "G": "초록", "P": "보라", "O": "진주"}

const INK := Color(0.24, 0.14, 0.28)

## 폴리오미노 블록 모양 (빠지냥식 다양한 모양의 젤리 블록)
const SHAPES := {
	"S1": [Vector2i(0, 0)],
	"H2": [Vector2i(0, 0), Vector2i(1, 0)],
	"V2": [Vector2i(0, 0), Vector2i(0, 1)],
	"H3": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	"V3": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],
	"H4": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
	"V4": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)],
	"SQ": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	"LA": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
	"LB": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
	"L4A": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)],
	"L4B": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 2)],
	"L4C": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	"L4D": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)],
	"TU": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
	"TD": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	"TL": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
	"TR": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)],
	"SH": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
	"ZH": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
	"SV": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
	"ZV": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)],
}


# O는 기존 레벨·저장 데이터의 식별자로 유지하고 표시 팔레트만 진주색으로 조정한다.
static var _pearl_jelly_texture: Texture2D


static func _pearl_jelly_tex() -> Texture2D:
	if _pearl_jelly_texture != null:
		return _pearl_jelly_texture
	var source: Texture2D = load("res://assets/jelly_O_v5.png")
	var pixels := source.get_image()
	if pixels.is_compressed():
		pixels.decompress()
	# 원화의 표정, 반사광, 투명도를 보존하며 몸체와 꽃무늬의 대비를 조정한다.
	# 최초 요청에서 한 번 생성하여 홈·퍼즐·도감이 같은 텍스처를 공유한다.
	for y in range(pixels.get_height()):
		for x in range(pixels.get_width()):
			var pixel := pixels.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			var original := pixel
			if pixel.s > 0.24 and pixel.h > 0.025 and pixel.h < 0.20:
				# 채도를 낮추고 원화의 명암을 살려 진주색 몸체와 회갈색 외곽을 만든다.
				var pearl_value := clampf(pixel.v * 0.55 + pixel.g * 0.45 + 0.10, 0.0, 1.0)
				pixel = Color.from_hsv(0.10, 0.04, pearl_value, pixel.a)
			# 밝은 몸체에서도 꽃무늬를 읽을 수 있도록 배의 흰 꽃만 회갈색으로 전환한다.
			var uv := Vector2(x, y) / Vector2(pixels.get_size())
			if uv.x > 0.37 and uv.x < 0.62 and uv.y > 0.63 and uv.y < 0.83 and original.v > 0.85:
				var flower_weight := 1.0 - smoothstep(0.18, 0.32, original.s)
				pixel = pixel.lerp(Color("#796d66"), flower_weight)
				pixel.a = original.a
			pixels.set_pixel(x, y, pixel)
	_pearl_jelly_texture = ImageTexture.create_from_image(pixels)
	return _pearl_jelly_texture


static func jelly_tex(c: String) -> Texture2D:
	# 기존 젤리몬의 단순하고 읽기 쉬운 손발 없는 실루엣을 유지한다.
	if c == "O":
		return _pearl_jelly_tex()
	if c == "G":
		return load("res://assets/jelly_G_v4.png")
	if ["R", "Y", "B", "P", "O"].has(c):
		return load("res://assets/jelly_%s_v5.png" % c)
	return load("res://assets/jelly_%s.png" % c)


static func hero_tex() -> Texture2D:
	return load("res://assets/jelly_R_v2.png")


static func catcher_tex(shape: String, c: String) -> Texture2D:
	return load("res://assets/catchers/%s_%s.png" % [shape, c])


static func haptic(ms: int) -> void:
	if haptics_enabled:
		Input.vibrate_handheld(ms)
