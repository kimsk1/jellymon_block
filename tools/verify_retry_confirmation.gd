extends SceneTree

class FakeGame extends Node:
	var state := "play"
	func set_paused(value: bool) -> void:
		state = "paused" if value else "play"

class FixtureHUD extends HUD:
	func _ready() -> void:
		root = Control.new()
		root.size = Vector2(G.W, G.H)
		add_child(root)

var starts := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := FakeGame.new()
	root.add_child(game)
	var hud := FixtureHUD.new()
	hud.game = game
	root.add_child(hud)
	for initial_state in ["play", "paused", "clear", "fail"]:
		game.state = initial_state
		var before := starts
		hud.confirm_retry(func(): starts += 1)
		assert(starts == before, "Opening the dialog must not restart")
		if initial_state == "play":
			assert(game.state == "paused", "Pause while confirming")
		var first := hud.retry_overlay
		hud.confirm_retry(func(): starts += 1)
		assert(hud.retry_overlay == first, "Prevent duplicate dialogs")
		hud.retry_overlay.find_child("CancelRetry", true, false).pressed.emit()
		await process_frame
		assert(starts == before and game.state == initial_state, "Cancel preserves prior state")
		hud.confirm_retry(func(): starts += 1)
		var confirm := hud.retry_overlay.find_child("ConfirmRetry", true, false)
		confirm.pressed.emit()
		confirm.pressed.emit()
		assert(starts == before + 1, "Confirm restarts exactly once")
		await process_frame
	game.state = "play"
	hud.confirm_retry(func(): starts += 1)
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	hud._input(escape)
	assert(game.state == "play", "Back cancels and resumes")
	print("[retry-confirmation] play/pause/result cancellation, confirmation, duplicate input and back passed")
	quit()
