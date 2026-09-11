extends Node
class_name MusicMgr
## 미리 제작한 OGG 루프를 재생한다. 화면 전환은 두 플레이어로 크로스페이드.

const THEMES := ["home", "map", "puzzle", "boss", "story"]
const GAIN := 0.25
const FADE_SECONDS := 0.65
var theme := "home"
var enabled := true
var game_paused := false
var players: Array[AudioStreamPlayer] = []
var streams := {}
var active_index := 0


func _ready() -> void:
	for name in THEMES:
		var stream := load("res://audio/bgm/%s.ogg" % name) as AudioStreamOggVorbis
		if stream:
			stream.loop = true
			stream.loop_offset = 0.0
			streams[name] = stream
	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.volume_linear = 0.0
		add_child(player)
		players.append(player)
	_start_active()


func switch_theme(next_theme: String) -> void:
	if not THEMES.has(next_theme) or theme == next_theme:
		return
	theme = next_theme
	if players.is_empty():
		return
	active_index = 1 - active_index
	players[active_index].stop()
	players[active_index].volume_linear = 0.0
	_start_active()


func _start_active() -> void:
	if not streams.has(theme):
		push_error("Missing BGM: %s" % theme)
		return
	var player := players[active_index]
	player.stream = streams[theme]
	player.play()
	player.stream_paused = not enabled
	set_process(true)


func set_enabled(value: bool) -> void:
	enabled = value
	if enabled:
		for player in players:
			player.stream_paused = false
	set_process(true)


func set_game_paused(value: bool) -> void:
	game_paused = value
	set_process(true)


func _process(delta: float) -> void:
	var settled := true
	for i in range(players.size()):
		var player := players[i]
		var target := GAIN * (0.22 if game_paused else 1.0) if enabled and i == active_index else 0.0
		player.volume_linear = move_toward(player.volume_linear, target, GAIN * delta / FADE_SECONDS)
		if not is_equal_approx(player.volume_linear, target):
			settled = false
		elif target == 0.0:
			if i != active_index:
				player.stop()
			elif not enabled:
				player.stream_paused = true
	if settled:
		set_process(false)


func _exit_tree() -> void:
	for player in players:
		player.stop()
		player.stream = null
	streams.clear()
