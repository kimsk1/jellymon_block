extends SceneTree
## 후원 팩 한정 가구의 임시 아트 시트를 만든다.
## 정식 일러스트가 준비되기 전까지 VIP 명패 원화를 색 변환·회전한 대체 이미지를 사용한다.
## 실행: Godot --headless --path . --script tools/generate_supporter_art.gd
const SOURCE := "res://assets/furniture/special.png"
const TARGET := "res://assets/furniture/supporter.png"
const PLATE := Rect2i(22, 185, 381, 142) # vip_nameplate 원본 영역

func _init() -> void:
	var special := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if special == null:
		push_error("원본 시트를 열 수 없습니다: " + SOURCE)
		quit(1)
		return
	var plate := special.get_region(PLATE)
	_tint(plate, Color(1.0, 0.62, 0.72), 0.5) # 후원 명패: 로즈 골드
	var frame := special.get_region(PLATE)
	frame.rotate_90(CLOCKWISE)
	_tint(frame, Color(0.58, 0.70, 1.0), 0.5) # 추억 액자: 세로 프레임, 하늘빛
	var atlas := Image.create(PLATE.size.x + PLATE.size.y + 12, PLATE.size.x + 8, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	atlas.blit_rect(plate, Rect2i(Vector2i.ZERO, plate.get_size()), Vector2i(4, 4))
	atlas.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(PLATE.size.x + 8, 4))
	var error := atlas.save_png(ProjectSettings.globalize_path(TARGET))
	print("[supporter art] saved=", TARGET, " error=", error, " plate=", Rect2i(4, 4, plate.get_width(), plate.get_height()), " frame=", Rect2i(PLATE.size.x + 8, 4, frame.get_width(), frame.get_height()))
	quit(0 if error == OK else 1)

static func _tint(image: Image, tint: Color, amount: float) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c := image.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var lum := c.get_luminance()
			var colored := Color(tint.r * lum * 1.15, tint.g * lum * 1.15, tint.b * lum * 1.15, c.a)
			var mixed := c.lerp(colored, amount)
			mixed.a = c.a
			image.set_pixel(x, y, mixed)
