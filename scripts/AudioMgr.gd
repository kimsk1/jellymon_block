extends Node
class_name AudioMgr
## 효과음 재생 풀.

const NAMES := ["pop", "pop_big", "merge", "grow", "clear", "fail", "shiny", "grab", "lock"]

var streams := {}
var players: Array = []


func _ready() -> void:
	for n in NAMES:
		var path := "res://audio/%s.wav" % n
		if ResourceLoader.exists(path):
			streams[n] = load(path)
	for i in range(14):
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func play(n: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not streams.has(n):
		return
	for p in players:
		if not p.playing:
			p.stream = streams[n]
			p.pitch_scale = pitch
			p.volume_db = vol_db
			p.play()
			return
