extends Control
class_name HomeNavIcon
## 홈 하단 메뉴에서 사용하는 코드 기반 전용 아이콘.
## 폰트 기호에 의존하지 않아 Android/iOS에서도 같은 모양으로 보인다.

var kind := "adventure"
var ink := Color.WHITE
var botanical := false
var night := false


func setup(icon_kind: String, color: Color = Color.WHITE) -> void:
	kind = icon_kind
	ink = color
	botanical = ArtDirection.is_botanical()
	night = ArtDirection.is_night()
	custom_minimum_size = Vector2(46, 46)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(46, 46))
	if botanical or (night and kind in ["star", "heart", "gift", "rescue"]):
		_draw_botanical()
		return
	if night and kind == "menu":
		for y in [10,22,34]:
			draw_style_box(_round_box(ink,ink,2,0),Rect2(7,y,32,5))
		return
	var c := Vector2(23, 23)
	match kind:
		"adventure":
			# 둥근 지도 핀과 그 안의 발바닥으로 '구조 모험'을 표현한다.
			draw_circle(c, 16, Color(1, 1, 1, 0.14))
			draw_arc(c, 15, 0, TAU, 28, ink, 3.2, true)
			draw_circle(c + Vector2(0, 5), 6, ink)
			for p in [Vector2(-8, -4), Vector2(-3, -9), Vector2(3, -9), Vector2(8, -4)]:
				draw_circle(c + p, 3.2, ink)
		"decorate":
			# 소파 실루엣.
			draw_style_box(_round_box(Color(1, 1, 1, 0.14), ink, 7, 3), Rect2(7, 17, 32, 19))
			draw_line(Vector2(12, 17), Vector2(12, 10), ink, 4, true)
			draw_line(Vector2(34, 17), Vector2(34, 10), ink, 4, true)
			draw_arc(Vector2(23, 14), 11, PI, TAU, 16, ink, 3, true)
			draw_line(Vector2(12, 36), Vector2(10, 41), ink, 3, true)
			draw_line(Vector2(34, 36), Vector2(36, 41), ink, 3, true)
		"shop":
			# 젤리 별이 담긴 쇼핑백.
			draw_style_box(_round_box(Color(1, 1, 1, 0.14), ink, 7, 3), Rect2(8, 16, 30, 25))
			draw_arc(Vector2(23, 17), 9, PI, TAU, 16, ink, 3, true)
			var star := PackedVector2Array()
			for i in range(10):
				var radius := 7.0 if i % 2 == 0 else 3.2
				var angle := -PI / 2.0 + i * PI / 5.0
				star.append(Vector2(23, 29) + Vector2(cos(angle), sin(angle)) * radius)
			draw_colored_polygon(star, ink)
		"menu":
			for y in [13.0, 23.0, 33.0]:
				draw_circle(Vector2(11, y), 3, ink)
				draw_line(Vector2(18, y), Vector2(37, y), ink, 4, true)


func _round_box(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


func _outlined(points: PackedVector2Array, fill: Color, border: Color, width: float = 1.5) -> void:
	draw_colored_polygon(points, fill)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, border, width, true)


func _draw_botanical() -> void:
	var green := Color("#9bbfa9")
	var pale := Color("#d5e6d8")
	var cream := Color("#fff8e9")
	match kind:
		"adventure":
			_outlined(PackedVector2Array([Vector2(3,31),Vector2(15,28),Vector2(28,31),Vector2(39,28),Vector2(44,42),Vector2(29,44),Vector2(15,41),Vector2(2,44)]), pale, ink)
			draw_line(Vector2(15,30),Vector2(15,40),cream,1.5,true)
			draw_line(Vector2(28,33),Vector2(29,42),cream,1.5,true)
			var pin := PackedVector2Array()
			for i in range(25):
				var angle := PI + float(i)*PI/24
				pin.append(Vector2(23,15)+Vector2(cos(angle),sin(angle))*13)
			pin.append(Vector2(35,22))
			pin.append(Vector2(23,38))
			pin.append(Vector2(11,22))
			_outlined(pin,green,ink,1.8)
			draw_circle(Vector2(23,14),7,cream)
			draw_arc(Vector2(23,14),7,0,TAU,24,ink,1.2,true)
		"decorate":
			draw_style_box(_round_box(green,ink,8,2),Rect2(9,6,28,29))
			draw_style_box(_round_box(pale,ink,4,2),Rect2(9,28,28,13))
			draw_style_box(_round_box(green,ink,5,2),Rect2(4,21,10,18))
			draw_style_box(_round_box(green,ink,5,2),Rect2(32,21,10,18))
			for x in [17,29]: draw_circle(Vector2(x,18),1.3,ink)
			for x in [10,36]: draw_line(Vector2(x,40),Vector2(x,44),ink,3,true)
		"shop":
			draw_line(Vector2(12,21),Vector2(17,5),ink,3,true)
			draw_line(Vector2(34,21),Vector2(29,5),ink,3,true)
			_outlined(PackedVector2Array([Vector2(6,22),Vector2(40,22),Vector2(35,42),Vector2(11,42)]),green,ink,1.8)
			draw_style_box(_round_box(pale,ink,3,2),Rect2(3,18,40,7))
			for x in [15,23,31]:
				draw_line(Vector2(x,29),Vector2(x,36),cream,3,true)
		"menu":
			for y in [10,22,34]:
				draw_style_box(_round_box(green,ink,3,1),Rect2(7,y,32,6))
		"leaf":
			draw_line(Vector2(24,42),Vector2(21,7),ink,1.7,true)
			for i in range(3):
				var y := 14.0+i*10.0
				_draw_leaf(Vector2(22,y+8),Vector2(9,y-3))
				_draw_leaf(Vector2(22,y+6),Vector2(36,y-5))
		"rescue":
			draw_circle(Vector2(23,23),20,Color("#d56d62"))
			draw_circle(Vector2(23,23),17,cream)
			for i in range(4):
				var angle := PI*0.25+i*PI*0.5
				draw_arc(Vector2(23,23),14,angle-0.28,angle+0.28,12,Color("#ed837c"),9,true)
			draw_circle(Vector2(23,23),9,cream)
			draw_arc(Vector2(23,23),9,0,TAU,28,Color("#bc7466"),1.4,true)
		"gift":
			draw_style_box(_round_box((Color("#eeb557") if night else Color("#ee7c7d")),Color("#ad5558"),4,1),Rect2(7,17,32,26))
			draw_style_box(_round_box((Color("#ffd477") if night else Color("#f79c91")),Color("#ad5558"),3,1),Rect2(4,13,38,9))
			draw_rect(Rect2(20,14,6,29),(Color("#b9688a") if night else Color("#f4cf79")))
			for x in [15,31]:
				draw_arc(Vector2(x,9),7,0,TAU,20,Color("#ddb052"),4,true)
			draw_circle(Vector2(23,13),4,Color("#ffe3a0"))
		"star":
			var points := PackedVector2Array()
			for i in range(10):
				var angle := -PI/2+i*PI/5
				points.append(Vector2(23,23)+Vector2(cos(angle),sin(angle))*(20 if i%2==0 else 11))
			_outlined(points,Color("#ffd56a"),Color("#dba341"),1.5)
			draw_line(Vector2(18,12),Vector2(21,8),cream,2.5,true)
		"heart":
			var points := PackedVector2Array()
			for i in range(65):
				var t := TAU*i/64.0
				points.append(Vector2(23+1.22*16*pow(sin(t),3),22-1.22*(13*cos(t)-5*cos(2*t)-2*cos(3*t)-cos(4*t))))
			_outlined(points,Color("#f88d9b"),Color("#c96878"),1.5)
			draw_arc(Vector2(14,14),5,PI*1.1,PI*1.7,12,cream,2,true)


func _draw_leaf(base: Vector2, tip: Vector2) -> void:
	var normal := (tip-base).orthogonal().normalized()
	var points := PackedVector2Array()
	for side in [1.0,-1.0]:
		for j in range(13):
			var t := float(j)/12.0 if side > 0 else 1.0-float(j)/12.0
			points.append(base.lerp(tip,t)+normal*sin(PI*t)*3.5*side)
	draw_colored_polygon(points,ink)
