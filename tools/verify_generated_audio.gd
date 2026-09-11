extends Node
var errors: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var music := MusicMgr.new()
	add_child(music)
	check(music.streams.size() == 5, "Five BGM streams must load")
	for name in MusicMgr.THEMES:
		music.switch_theme(name)
		music._process(1.0)
		var player: AudioStreamPlayer = music.players[music.active_index]
		check(player.stream is AudioStreamOggVorbis and player.stream.loop, "Loop disabled: " + name)
		check(player.stream.get_length() > 20.0, "BGM too short: " + name)
		player.seek(player.stream.get_length() - 0.12)
		await get_tree().create_timer(0.4).timeout
		check(player.playing, "Loop stopped: " + name)
		check(player.get_playback_position() < 2.0, "Loop did not wrap: " + name)
	music.set_game_paused(true)
	music._process(1.0)
	check(is_equal_approx(music.players[music.active_index].volume_linear, MusicMgr.GAIN * 0.22), "Pause ducking")
	music.set_enabled(false)
	music._process(1.0)
	check(music.players[music.active_index].stream_paused, "Muted music still decoding")
	music.switch_theme("home")
	music.switch_theme("boss")
	music._process(1.0)
	check(music.players[music.active_index].stream_paused, "Theme change broke mute")
	music.set_game_paused(false)
	music.set_enabled(true)
	music._process(1.0)
	check(not music.players[music.active_index].stream_paused, "Unmute failed")
	check(is_equal_approx(music.players[music.active_index].volume_linear, MusicMgr.GAIN), "Unmute gain")
	var audio := AudioMgr.new()
	add_child(audio)
	check(audio.streams.size() == AudioMgr.NAMES.size(), "Missing SFX")
	for name in AudioMgr.NAMES:
		check(audio.streams.has(name) and audio.streams[name].get_length() > 0.02, "SFX invalid: " + name)
	var button := Button.new()
	add_child(button)
	await get_tree().process_frame
	button.button_down.emit()
	var click_played := false
	for player in audio.players:
		if player.playing and player.stream == audio.streams.get("ui_click"): click_played = true
	check(click_played, "Dynamic UI button has no sound")
	for player in audio.players: player.stop()
	audio.enabled = false
	audio.play("reward")
	for player in audio.players: check(not player.playing, "Disabled SFX played")
	print("[generated audio] failures=%d" % errors.size())
	for error in errors: push_error(error)
	music.queue_free()
	audio.queue_free()
	button.queue_free()
	await get_tree().process_frame
	# AudioServer applies stop/unreference commands on its next mix cycle.
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if errors.is_empty() else 1)
