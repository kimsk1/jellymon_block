extends Control
class_name PremiumSurface
## 버튼/카드 안쪽의 림, 반사광, 하단 두께를 해상도 독립적으로 렌더링한다.

var corner_radius := 22.0
var accent := Color.WHITE
var intensity := 0.8


func setup(radius: float, color: Color, strength: float = 0.8) -> void:
	corner_radius = radius
	accent = color
	intensity = strength
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if size.x < 20.0 or size.y < 16.0:
		return
	var radius := minf(corner_radius, minf(size.x, size.y) * 0.42)
	var inset := clampf(radius * 0.42, 7.0, 16.0)
	var right := size.x - inset
	# 상단 여러 겹의 산란광: 단일 흰 선보다 둥근 유리 표면처럼 보인다.
	for i in range(6):
		var alpha := (0.22 - float(i) * 0.028) * intensity
		var y := 4.0 + float(i)
		draw_line(Vector2(inset, y), Vector2(right, y), Color(accent.r, accent.g, accent.b, alpha), 1.2, true)
	# 하단은 두꺼운 재질 단면처럼 단계적으로 어두워진다.
	for i in range(7):
		var alpha := (0.035 + float(i) * 0.018) * intensity
		var y := size.y - 10.0 + float(i)
		draw_line(Vector2(inset, y), Vector2(right, y), Color(0.055, 0.025, 0.13, alpha), 1.4, true)
	# 좌우 안쪽 림이 면과 외곽 프레임을 분리한다.
	draw_line(Vector2(5.0, radius), Vector2(5.0, size.y - radius), Color(1, 1, 1, 0.17 * intensity), 2.0, true)
	draw_line(Vector2(size.x - 5.0, radius), Vector2(size.x - 5.0, size.y - radius), Color(0.05, 0.02, 0.12, 0.16 * intensity), 2.0, true)
	# 왼쪽 위의 짧은 스펙큘러는 광원 방향을 모든 UI에 통일한다.
	var glint_start := Vector2(inset + 3.0, 10.5)
	var glint_end := Vector2(minf(right - 4.0, glint_start.x + maxf(18.0, size.x * 0.19)), 10.5)
	draw_line(glint_start, glint_end, Color(1, 1, 1, 0.48 * intensity), 3.0, true)
	draw_circle(glint_start - Vector2(5, 0), 2.3, Color(1, 1, 1, 0.44 * intensity))
