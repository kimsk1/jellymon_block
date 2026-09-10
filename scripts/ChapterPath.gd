extends Control
class_name ChapterPath
## 챕터별 지형과 연속 구조 원정 경로를 그리는 월드맵 레이어.

var points: Array = []
var accent := Color("#e67892")
var unlocked_count := 0
var chapter_index := 0


func setup(path_points: Array, color: Color, unlocked: int, chapter: int) -> void:
	points = path_points.duplicate()
	accent = color
	unlocked_count = unlocked
	chapter_index = chapter
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	if points.size() < 2:
		return
	_draw_terrain()
	# 작은 장식 군집으로 챕터가 단순한 빈 카드가 아니라 실제 지역처럼 보이게 한다.
	for i in range(13):
		var x := 46.0 + float(posmod(i * 137 + chapter_index * 61, 540))
		var y := 48.0 + float(posmod(i * 83 + chapter_index * 47, 680))
		var r := 7.0 + float(posmod(i * 5, 9))
		var col := accent.lightened(0.26 if i % 2 == 0 else 0.12)
		draw_circle(Vector2(x, y) + Vector2(3, 5), r + 2.0, Color(0.08, 0.04, 0.16, 0.12))
		draw_circle(Vector2(x, y), r, Color(col.r, col.g, col.b, 0.24))
		draw_circle(Vector2(x - r * 0.3, y - r * 0.35), maxf(2.0, r * 0.22), Color(1, 1, 1, 0.42))
	# 위·아래 챕터와 연결되는 진입로를 먼저 그려 하나의 긴 여행길처럼 보이게 한다.
	_draw_path_segment(Vector2(points[0].x, size.y), points[0], true)
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var active := i < maxi(0, unlocked_count - 1)
		_draw_path_segment(a, b, active)
	_draw_path_segment(points[-1], Vector2(points[-1].x, 0), unlocked_count >= points.size())
	# 5레벨 보상 거점: 금빛 상자 실루엣.
	var reward: Vector2 = points[4] + Vector2(-67, -7)
	draw_rect(Rect2(reward + Vector2(3, 6), Vector2(48, 34)), Color(0.08, 0.04, 0.15, 0.22), true)
	draw_rect(Rect2(reward, Vector2(48, 34)), Color("#d58a2f"), true)
	draw_rect(Rect2(reward + Vector2(4, 5), Vector2(40, 23)), Color("#ffd05a"), true)
	draw_line(reward + Vector2(24, 4), reward + Vector2(24, 30), Color("#fff0a8"), 5, true)
	# 10레벨은 길 끝의 왕관 깃발로 보스 관문을 예고한다.
	var gate: Vector2 = points[9] + Vector2(70, -40)
	draw_line(gate, gate + Vector2(0, 67), Color("#6a4b8f"), 7.0, true)
	var flag := PackedVector2Array([gate, gate + Vector2(48, 10), gate + Vector2(31, 34), gate + Vector2(0, 27)])
	draw_colored_polygon(flag, Color("#8f62c8"))
	var flag_outline := flag.duplicate()
	flag_outline.append(flag[0])
	draw_polyline(flag_outline, Color("#f2d47b"), 4.0, true)


func _draw_path_segment(a: Vector2, b: Vector2, active: bool) -> void:
	var path_color := accent.lightened(0.2) if active else Color("#aaa4b6")
	draw_line(a + Vector2(3, 7), b + Vector2(3, 7), Color(0.06, 0.03, 0.14, 0.3), 25.0, true)
	draw_line(a, b, Color(path_color.r, path_color.g, path_color.b, 0.9), 19.0, true)
	draw_line(a - Vector2(0, 3), b - Vector2(0, 3), Color(1, 1, 1, 0.5 if active else 0.24), 4.0, true)


func _draw_terrain() -> void:
	## 다섯 챕터마다 지형군이 바뀌며, 같은 틀 안에서도 언덕·물·수정·숲의 비율이 달라진다.
	var biome := (chapter_index / 5) % 5
	var base := accent.lightened(0.38)
	var deep := accent.darkened(0.08)
	for band in range(5):
		var y := 118.0 + band * 172.0
		var side := -22.0 if (band + chapter_index) % 2 == 0 else size.x - 150.0
		draw_circle(Vector2(side + 72, y + 28), 118.0, Color(base.r, base.g, base.b, 0.24))
		draw_circle(Vector2(side + 118, y + 55), 82.0, Color(deep.r, deep.g, deep.b, 0.12))
	if biome == 1 or biome == 3:
		var water := PackedVector2Array([
			Vector2(-20, 330), Vector2(130, 300), Vector2(280, 340),
			Vector2(430, 316), Vector2(size.x + 20, 350), Vector2(size.x + 20, 430),
			Vector2(420, 400), Vector2(260, 425), Vector2(90, 390), Vector2(-20, 420),
		])
		draw_colored_polygon(water, Color("#6fd7e8") if biome == 3 else Color("#93c9f1"))
		draw_polyline(water, Color(1, 1, 1, 0.48), 5.0, true)
	for i in range(8):
		var x := 36.0 + float(posmod(i * 173 + chapter_index * 79, 520))
		var y := 132.0 + float(posmod(i * 149 + chapter_index * 41, 630))
		if biome == 2:
			_draw_crystal(Vector2(x, y), 16.0 + float(i % 3) * 5.0)
		elif biome == 4:
			_draw_star_shrub(Vector2(x, y), 12.0 + float(i % 2) * 4.0)
		else:
			_draw_candy_tree(Vector2(x, y), 15.0 + float(i % 3) * 4.0)


func _draw_candy_tree(at: Vector2, radius: float) -> void:
	draw_line(at + Vector2(0, radius * 0.5), at + Vector2(0, radius * 1.8), Color("#8b5b52"), 7.0, true)
	draw_circle(at + Vector2(3, 4), radius + 3.0, Color(0.12, 0.06, 0.18, 0.16))
	draw_circle(at, radius, accent.lightened(0.15))
	draw_circle(at - Vector2(radius * 0.3, radius * 0.35), radius * 0.28, Color(1, 1, 1, 0.46))


func _draw_crystal(at: Vector2, radius: float) -> void:
	var crystal := PackedVector2Array([at + Vector2(0, -radius), at + Vector2(radius * 0.65, 0), at + Vector2(0, radius * 1.25), at + Vector2(-radius * 0.65, 0)])
	draw_colored_polygon(crystal, accent.lightened(0.2))
	var outline := crystal.duplicate()
	outline.append(crystal[0])
	draw_polyline(outline, Color(1, 1, 1, 0.58), 3.0, true)


func _draw_star_shrub(at: Vector2, radius: float) -> void:
	draw_circle(at, radius, accent.lightened(0.16))
	draw_circle(at + Vector2(radius * 0.75, 3), radius * 0.72, accent.lightened(0.28))
	draw_circle(at - Vector2(radius * 0.7, -2), radius * 0.62, accent)
	draw_circle(at + Vector2(-2, -radius * 0.35), radius * 0.2, Color("#fff3a0"))
