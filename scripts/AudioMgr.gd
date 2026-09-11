extends Node
class_name AudioMgr
## 효과음 재생 풀.

const NAMES := ["pop", "pop_big", "merge", "grow", "clear", "fail", "shiny", "grab", "lock", "fever", "ui_click", "reward"]

var streams := {}
var players: Array = []
var enabled := true:
	set(value):
		enabled = value
		if not enabled:
			for player in players:
				player.stop()


func _ready() -> void:
	for n in NAMES:
		var path := "res://audio/%s.wav" % n
		if ResourceLoader.exists(path):
			streams[n] = load(path)
	for i in range(14):
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	get_tree().node_added.connect(_on_node_added)
	_wire_existing_buttons(get_tree().root)


func _wire_existing_buttons(node: Node) -> void:
	_wire_button(node)
	for child in node.get_children():
		_wire_existing_buttons(child)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_wire_button.call_deferred(node)


func _wire_button(node) -> void:
	if not is_instance_valid(node) or not node is BaseButton:
		return
	var callback := play.bind("ui_click", 1.0, -10.0)
	if not node.button_down.is_connected(callback):
		node.button_down.connect(callback)


func play(n: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not enabled or not streams.has(n):
		return
	for p in players:
		if not p.playing:
			p.stream = streams[n]
			p.pitch_scale = pitch
			p.volume_db = vol_db
			p.play()
			return
