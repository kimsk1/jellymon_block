extends SceneTree
## Run: godot --headless --path . --script tools/verify_runtime_refactor.gd
const Solver = preload("res://scripts/levels/LevelSolver.gd")
const Presentation = preload("res://scripts/levels/LevelPresentation.gd")

class TimerHUD extends HUD:
	func _ready() -> void:
		time_label = Label.new()
		add_child(time_label)
		timer_bar = ProgressBar.new()
		add_child(timer_bar)
		_timer_fill = StyleBoxFlat.new()
		_timer_normal_color = Color.GREEN
		_timer_fill.bg_color = _timer_normal_color
		timer_bar.add_theme_stylebox_override("fill", _timer_fill)

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)

func run() -> void:
	var board := [".....", "..R..", "....."]
	var specs := [
		{"color": "R", "shape": "S1", "cell": [0, 1], "capacity": 1},
		{"color": "B", "shape": "S1", "cell": [1, 1], "capacity": 1},
	]
	var positions: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1)]
	var active: Array[bool] = [true, true]
	check(not Solver._test_can_place(board, specs, positions, active, 0, Vector2i(1, 1)), "Other catcher must block movement")
	var hit := Solver._find_reachable_jelly(board, specs, positions, active, 0)
	check(hit.origin == Vector2i(2, 1) and hit.dist == 4, "Search must route around the other catcher")
	active[1] = false
	hit = Solver._find_reachable_jelly(board, specs, positions, active, 0)
	check(hit.dist == 2, "Evacuated catcher must not leave stale occupancy")
	active[1] = true
	positions[1] = Vector2i(4, 1)
	hit = Solver._find_reachable_jelly(board, specs, positions, active, 0)
	check(hit.dist == 2, "Moved catcher must not leave stale occupancy")
	var target := Vector2i(2, 1)
	check(not Solver._test_can_place_full(board, specs, positions, active, 0, target), "Full catchers cannot cross jellies")
	check(Solver._test_can_place_full(board, specs, positions, active, 0, target, {"ghosts": {target: true}}), "Ghost exception must remain available")
	check(not Solver._test_can_place(board, specs, positions, active, 0, target, {"blocked_colors": {"R": true}}), "Color order must block early rescue")
	check(not Solver._test_can_place(board, specs, positions, active, 0, target, {"escort_cell": target, "escort_catcher": 1}), "Escort must require its assigned catcher")
	check(not Solver._one_way_allows({"one_ways": {target: Vector2i.LEFT}}, specs, 0, Vector2i(1, 1), target), "One-way entry must retain direction checks")
	var level := {"grid": [".R"], "catchers": [specs[0]], "time": 90.0}
	var original := level.duplicate(true)
	var decorated := Presentation.apply_early_campaign(level, 5, "Chapter")
	check(level == original and decorated.time == 98.0, "Presentation must not mutate cached source levels")
	check(Presentation.apply_early_campaign(level, 5, "Chapter").time == 98.0, "Repeated reads must not accumulate time bonuses")
	var hud := TimerHUD.new()
	root.add_child(hud)
	var fill_id := hud._timer_fill.get_instance_id()
	hud.set_time(9.9, 100.0)
	for frame in range(60):
		hud.set_time(9.9 - frame * 0.01, 100.0)
	check(hud.time_label.text == "0:09", "Timer text must retain second precision")
	check(hud.timer_bar.get_theme_stylebox("fill").get_instance_id() == fill_id, "Danger timer must reuse its style resource")
	check(hud._timer_fill.bg_color == ArtDirection.danger_color(), "Danger state must color the timer")
	hud.set_time(15.0, 100.0)
	check(hud._timer_fill.bg_color == hud._timer_normal_color, "Added time must restore the normal fill")
	hud.set_time(90.0, 100.0)
	check(hud.time_label.text == "1:30" and hud._timer_state == 0, "Continue must reset timer text and warning state")
	hud.free()
	print("[runtime refactor] failures=", failures)
	quit(0 if failures == 0 else 1)
