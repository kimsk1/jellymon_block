extends Node
class_name MusicMgr
## 라이선스 의존성 없이 재생되는 젤리몬 전용 소프트 신스 BGM.

const MIX_RATE := 22050.0
const CHORDS := {
	"home": [[60, 64, 67, 71], [57, 60, 64, 69], [65, 69, 72, 76], [67, 71, 74, 77]],
	"map": [[60, 64, 67], [62, 65, 69], [57, 60, 64], [55, 59, 62]],
	"puzzle": [[62, 65, 69], [60, 64, 67], [57, 62, 65], [59, 62, 67]],
	"boss": [[57, 60, 64], [58, 62, 65], [55, 59, 62], [57, 60, 63]],
	"story": [[60, 64, 67, 71], [64, 67, 71, 74], [57, 60, 64, 67], [65, 69, 72, 76]],
}
const BPM := {"home": 76.0, "map": 90.0, "puzzle": 104.0, "boss": 114.0, "story": 68.0}

var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var theme := "home"
var sample_cursor := 0
var enabled := true
var game_paused := false
var current_gain := 0.0


func _ready() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 0.7
	player = AudioStreamPlayer.new()
	player.stream = generator
	player.volume_db = -13.0
	add_child(player)
	player.play()
	playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	set_process(true)


func switch_theme(next_theme: String) -> void:
	if not CHORDS.has(next_theme) or theme == next_theme:
		return
	theme = next_theme
	sample_cursor = 0


func _exit_tree() -> void:
	set_process(false)
	if is_instance_valid(player):
		player.stop()
		player.stream = null
	playback = null


func set_enabled(value: bool) -> void:
	enabled = value


func set_game_paused(value: bool) -> void:
	game_paused = value


func _process(_delta: float) -> void:
	if playback == null:
		return
	var available := playback.get_frames_available()
	while available > 0:
		var frame_count := mini(available, 2048)
		var frames := PackedVector2Array()
		frames.resize(frame_count)
		for i in range(frame_count):
			var target_gain := 0.0 if not enabled else (0.22 if game_paused else 1.0)
			current_gain = move_toward(current_gain, target_gain, 0.0007)
			var value := _sample(float(sample_cursor) / MIX_RATE) * current_gain
			frames[i] = Vector2(value, value * 0.96)
			sample_cursor += 1
		playback.push_buffer(frames)
		available -= frame_count


func _sample(t: float) -> float:
	var beat_seconds: float = 60.0 / float(BPM[theme])
	var beat_index := int(t / beat_seconds)
	var beat_t := fmod(t, beat_seconds) / beat_seconds
	var chord_index := (beat_index / 4) % 4
	var chord: Array = CHORDS[theme][chord_index]
	var attack := smoothstep(0.0, 0.08, beat_t)
	var release := 1.0 - smoothstep(0.58, 1.0, beat_t)
	var pulse_env := attack * release
	var pad := 0.0
	for midi in chord:
		var f := _midi_frequency(float(midi) - 12.0)
		pad += sin(TAU * f * t) + 0.22 * sin(TAU * f * 2.0 * t)
	pad = pad / float(chord.size()) * 0.11
	var bass_f := _midi_frequency(float(chord[0]) - 24.0)
	var bass := sin(TAU * bass_f * t) * 0.13 * (0.72 + 0.28 * pulse_env)
	var melody_step: int = int([0, 2, 1, 3, 2, 1, 3, 1][beat_index % 8]) % chord.size()
	var melody_f := _midi_frequency(float(chord[melody_step]) + (12.0 if theme != "boss" else 0.0))
	var bell := (sin(TAU * melody_f * t) + 0.34 * sin(TAU * melody_f * 2.01 * t)) * 0.095 * pulse_env
	var sparkle := 0.0
	if theme == "home" or theme == "story":
		var sparkle_f := _midi_frequency(float(chord[(beat_index + 1) % chord.size()]) + 24.0)
		sparkle = sin(TAU * sparkle_f * t) * 0.035 * pow(maxf(0.0, release), 3.0)
	var urgency := 1.2 if theme == "boss" else 1.0
	return clampf((pad + bass + bell + sparkle) * urgency, -0.48, 0.48)


func _midi_frequency(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)
