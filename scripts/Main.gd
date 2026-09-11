extends Node
## 루트: 화면 전환 + 저장 + 오디오 (02 문서 7장 상태 머신 간소판)

const L10n = preload("res://scripts/LocalizedText.gd")
const StartupValidationLib = preload("res://scripts/validation/StartupValidation.gd")
const LiveProgressionCatalogLib = preload("res://scripts/LiveProgressionCatalog.gd")
const PlatformServiceLib = preload("res://scripts/PlatformService.gd")
const CharacterCatalogLib = preload("res://scripts/CharacterCatalog.gd")
const AnalyticsServiceLib = preload("res://scripts/AnalyticsService.gd")
const RetentionCatalogLib = preload("res://scripts/RetentionCatalog.gd")
const MusicMgrLib = preload("res://scripts/MusicMgr.gd")

signal rewarded_ad_requested(on_reward: Callable, on_unavailable: Callable)

var audio: AudioMgr
var music: Node
var ranking: Node
var billing: Node
var adventure_cloud: Node
var platform: Node
var analytics: Node
var save := SaveGame.new()
var current_screen: Node = null
var game: Game = null
var last_furniture_reward: Dictionary = {}
var last_new_resident: Dictionary = {}
var _level_gate_overlay: CanvasLayer = null
var active_activity := {}
var _shutting_down := false


func _ready() -> void:
	_startup_trace("main_ready")
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(_request_shutdown)
	randomize()
	if OS.get_cmdline_user_args().has("--validate-shutdown"):
		_initialize_runtime()
		_validate_shutdown()
		return
	if OS.get_cmdline_user_args().has("--validate-localization"):
		var localization_errors := Localization.validate_catalogs()
		for locale_code in Localization.SUPPORTED_LOCALES:
			Localization.apply_language(locale_code)
			var settings_copy := tr("환경 설정")
			if settings_copy.is_empty() or (locale_code != "ko" and settings_copy == "환경 설정"):
				localization_errors.append("localization runtime lookup failed: %s" % locale_code)
		print("[localization validation] locales=", Localization.SUPPORTED_LOCALES.size(), " errors=", localization_errors.size())
		for message in localization_errors:
			push_error(message)
		_request_shutdown(0 if localization_errors.is_empty() else 1)
		return
	# 전체 레벨의 풀이 가능성/기믹 정합성 검사는 빌드·CI 단계에서만 수행한다.
	# 일반 앱 실행에서 이 검사를 돌리면 레벨 수에 비례해 첫 화면이 늦어진다.
	if not _should_run_full_validation() and OS.get_cmdline_user_args().is_empty():
		_initialize_runtime()
		if DisplayServer.get_name() == "headless":
			_headless_smoke_test()
		return
	if OS.get_cmdline_user_args().has("--extend-levels"):
		var extend_error := Levels.extend_and_bake_levels()
		var extended_errors := Levels.validate_all() if extend_error == OK else PackedStringArray([L10n.text("레벨 확장 베이크 실패")])
		print("[level extend] levels=", Levels.level_count(), " error=", extend_error, " validation_errors=", extended_errors.size())
		_request_shutdown(0 if extend_error == OK and extended_errors.is_empty() else 1)
		return
	if OS.get_cmdline_user_args().has("--repair-baked-levels"):
		var repair_error := Levels.repair_and_bake_levels()
		var repaired_errors := Levels.validate_all() if repair_error == OK else PackedStringArray([L10n.text("레벨 복구 베이크 실패")])
		print("[level repair] levels=", Levels.level_count(), " error=", repair_error, " validation_errors=", repaired_errors.size())
		_request_shutdown(0 if repair_error == OK and repaired_errors.is_empty() else 1)
		return
	var level_errors := StartupValidationLib.validate(Localization)
	if not level_errors.is_empty():
		for message in level_errors:
			push_error("[level validation] " + message)
	if OS.get_cmdline_user_args().has("--bake-levels"):
		var bake_error := Levels.rebuild_and_bake_levels()
		var rebuilt_errors := Levels.validate_all()
		print("[level bake] path=", Levels.BAKED_LEVELS_PATH, " error=", bake_error, " validation_errors=", rebuilt_errors.size())
		_request_shutdown(0 if bake_error == OK and rebuilt_errors.is_empty() else 1)
		return
	if OS.get_cmdline_user_args().has("--bake-level-chunks"):
		var chunk_error := Levels.bake_current_levels()
		print("[level chunk bake] index=", Levels.LEVEL_INDEX_PATH, " error=", chunk_error, " validation_errors=", level_errors.size())
		_request_shutdown(0 if chunk_error == OK and level_errors.is_empty() else 1)
		return
	if OS.get_cmdline_user_args().has("--validate-levels"):
		print("[level validation] levels=", Levels.level_count(), " errors=", level_errors.size())
		var shape_counts := {}
		for level in Levels.all_levels():
			for spec in level.catchers:
				shape_counts[spec.shape] = int(shape_counts.get(spec.shape, 0)) + 1
		print("[level validation] shapes=", shape_counts)
		_request_shutdown(0 if level_errors.is_empty() else 1)
		return
	_initialize_runtime()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autoplay-level="):
			_run_autoplay_level(int(arg.get_slice("=", 1)) - 1)
			return
	if OS.get_cmdline_user_args().has("--shots"):
		_screenshot_run()
	elif OS.get_cmdline_user_args().has("--shot-map"):
		_screenshot_map()
	elif OS.get_cmdline_user_args().has("--shot-room-refresh"):
		_screenshot_room_refresh()
	elif OS.get_cmdline_user_args().has("--shot-home-menu"):
		_screenshot_home_menu()
	elif OS.get_cmdline_user_args().has("--shot-lifestyle"):
		_screenshot_lifestyle()
	elif OS.get_cmdline_user_args().has("--shot-room-edit"):
		_screenshot_room_edit()
	elif OS.get_cmdline_user_args().has("--shot-level-51"):
		_screenshot_level_51()
	elif OS.get_cmdline_user_args().has("--shot-level-39"):
		_screenshot_level_39()
	elif OS.get_cmdline_user_args().has("--shot-late-gimmicks"):
		_screenshot_late_gimmicks()
	elif OS.get_cmdline_user_args().has("--shot-endgame"):
		_screenshot_endgame()
	elif OS.get_cmdline_user_args().has("--shot-pause"):
		_screenshot_pause()
	elif OS.get_cmdline_user_args().has("--analytics-report"):
		print("[analytics report] ", JSON.stringify(analytics.local_quality_report()))
		_request_shutdown()
	elif OS.get_cmdline_user_args().has("--validate-story-localization") or OS.get_cmdline_user_args().has("--shot-story-localization"):
		_validate_story_localization(OS.get_cmdline_user_args().has("--shot-story-localization"))
	elif OS.get_cmdline_user_args().has("--validate-story-typing"):
		_headless_story_typing_test()
	elif OS.get_cmdline_user_args().has("--validate-story-overlay"):
		_headless_story_overlay_test()
	elif OS.get_cmdline_user_args().has("--validate-touch"):
		_headless_touch_test()
	elif OS.get_cmdline_user_args().has("--validate-delayed-trap"):
		_headless_delayed_trap_test()
	elif OS.get_cmdline_user_args().has("--validate-level-39"):
		_headless_level_39_test()
	elif OS.get_cmdline_user_args().has("--validate-level-17"):
		_headless_level_17_test()
	elif OS.get_cmdline_user_args().has("--validate-level-7"):
		_headless_level_7_test()
	elif OS.get_cmdline_user_args().has("--validate-level-44"):
		_headless_level_44_test()
	elif OS.get_cmdline_user_args().has("--validate-expansion"):
		_headless_expansion_test()
	elif OS.get_cmdline_user_args().has("--validate-advanced-expansion"):
		_headless_advanced_expansion_test()
	elif OS.get_cmdline_user_args().has("--validate-late-play"):
		_headless_late_play_test()
	elif OS.get_cmdline_user_args().has("--validate-endgame"):
		_headless_endgame_test()
	elif OS.get_cmdline_user_args().has("--validate-memory"):
		_headless_memory_stress_test()
	elif OS.get_cmdline_user_args().has("--validate-characters"):
		_headless_character_system_test()
	elif OS.get_cmdline_user_args().has("--validate-tutorial"):
		_headless_tutorial_test()
	elif OS.get_cmdline_user_args().has("--validate-pause"):
		_headless_pause_test()
	elif OS.get_cmdline_user_args().has("--validate-level-gate"):
		_headless_level_gate_test()
	elif DisplayServer.get_name() == "headless":
		_headless_smoke_test()


func _should_run_full_validation() -> bool:
	var args := OS.get_cmdline_user_args()
	return args.has("--validate-levels") or args.has("--bake-levels") or args.has("--bake-level-chunks") or args.has("--extend-levels") or args.has("--repair-baked-levels")


func _initialize_runtime() -> void:
	_startup_trace("runtime_begin")
	get_tree().root.theme = ArtDirection.ui_theme()
	audio = AudioMgr.new()
	add_child(audio)
	music = MusicMgrLib.new()
	add_child(music)
	platform = PlatformServiceLib.new()
	add_child(platform)
	_startup_trace("audio_ready")
	platform.initialize()
	_startup_trace("platform_initialize_returned")
	analytics = AnalyticsServiceLib.new()
	add_child(analytics)
	var automated: bool = DisplayServer.get_name() == "headless" or Array(OS.get_cmdline_user_args()).any(func(arg): return arg.begins_with("--shot") or arg.begins_with("--validate-") or arg.begins_with("--autoplay-"))
	analytics.initialize(not automated)
	analytics.track("session_start", {"build": "debug" if OS.is_debug_build() else "release", "platform": OS.get_name()})
	# 자동 QA는 메모리에서만 진행해 개발자의 실제 플레이 계정을 오염시키지 않는다.
	if automated:
		save.persistence_enabled = false
	save.load_data()
	adventure_cloud = preload("res://scripts/CloudSaveService.gd").new()
	add_child(adventure_cloud)
	adventure_cloud.configure(platform, save)
	adventure_cloud.restored.connect(_on_cloud_restored)
	adventure_cloud.conflict_found.connect(_on_cloud_conflict)
	ranking = preload("res://scripts/RankingService.gd").new()
	add_child(ranking)
	ranking.configure(platform, save)
	billing = preload("res://scripts/BillingService.gd").new()
	add_child(billing)
	billing.configure(platform, save)
	platform.cloud_state_changed.connect(func(_message): ranking.sync_record.call_deferred())
	platform.account_disconnect_completed.connect(_on_account_disconnect_completed)
	_startup_trace("save_loaded")
	ArtDirection.set_room_theme(save.get_room_theme())
	get_tree().root.theme = ArtDirection.ui_theme()
	Localization.apply_language(save.language)
	audio.enabled = save.sound_enabled
	music.set_enabled(save.sound_enabled)
	G.haptics_enabled = save.haptics_enabled
	if OS.get_cmdline_user_args().has("--shot-room-refresh") or OS.get_cmdline_user_args().has("--shot-room-edit"):
		save.room_placements = RoomData.default_placements()
	_startup_trace("home_begin")
	show_title()
	_startup_trace("home_built")
	if OS.is_debug_build() and DisplayServer.get_name() != "headless":
		_trace_first_frame()


func _on_cloud_restored() -> void:
	ArtDirection.set_room_theme(save.get_room_theme())
	get_tree().root.theme = ArtDirection.ui_theme()
	Localization.apply_language(save.language)
	audio.enabled = save.sound_enabled
	music.set_enabled(save.sound_enabled)
	G.haptics_enabled = save.haptics_enabled
	show_title.call_deferred()

func _on_cloud_conflict(local_data: Dictionary, remote_data: Dictionary) -> void:
	if has_node("CloudSaveConflict"): return
	var dialog := preload("res://scripts/CloudSaveDialog.gd").new()
	dialog.name = "CloudSaveConflict"
	dialog.local_data = local_data
	dialog.remote_data = remote_data
	add_child(dialog)
	dialog.selected.connect(func(use_cloud: bool): adventure_cloud.resolve_conflict(use_cloud))
	var cancel_on_logout := func(ok: bool, _id: String):
		if not ok and is_instance_valid(dialog): dialog.queue_free()
	platform.login_changed.connect(cancel_on_logout)
	dialog.tree_exiting.connect(func():
		if is_instance_valid(platform) and platform.login_changed.is_connected(cancel_on_logout): platform.login_changed.disconnect(cancel_on_logout)
	)


func _on_account_disconnect_completed(success: bool, _message: String) -> void:
	if success:
		# Rebuild after the SDK completion signal and popup callbacks have finished.
		_reset_local_account_data.call_deferred()


func _reset_local_account_data() -> void:
	var fresh := SaveGame.new()
	fresh.storage_path = save.storage_path
	fresh.persistence_enabled = save.persistence_enabled
	fresh.save_data()
	# Disable persistence on the previous instance so an old callback cannot restore it.
	save.persistence_enabled = false
	save = fresh
	adventure_cloud.bind_save(save)
	adventure_cloud._sent = {}
	adventure_cloud._account = ""
	adventure_cloud._verifying = false
	adventure_cloud._retry_seconds = 30.0
	ranking.save = save
	billing.save = save
	ranking._read.cancel_request()
	ranking.entries = []
	ranking.loading = false
	ranking.status = L10n.text("랭킹을 불러오는 중입니다.")
	ranking.submit_status = ""
	ranking._sent = {}
	ranking._account = ""
	platform._pending_reward = Callable()
	platform._pending_unavailable = Callable()
	if save.persistence_enabled:
		for path in [PlatformServiceLib.LOCAL_CLOUD_PATH, PlatformServiceLib.LOCAL_RANK_PATH]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		# Only the app-private photo fallback belongs to local game storage.
		# Photos exported to the system Pictures folder remain user-owned files.
		var photos := DirAccess.open("user://photos")
		if photos:
			for filename in photos.get_files():
				photos.remove(filename)
	analytics.reset_local_data()
	last_furniture_reward = {}
	last_new_resident = {}
	active_activity = {}
	ArtDirection.set_room_theme(save.get_room_theme())
	get_tree().root.theme = ArtDirection.ui_theme()
	Localization.apply_language(save.language)
	audio.enabled = save.sound_enabled
	music.set_enabled(save.sound_enabled)
	G.haptics_enabled = save.haptics_enabled
	show_title()


func _startup_trace(stage: String) -> void:
	if OS.is_debug_build():
		print("[startup] ", stage, " ticks_ms=", Time.get_ticks_msec())


func _trace_first_frame() -> void:
	await RenderingServer.frame_post_draw
	_startup_trace("first_frame_drawn")


func _clear_screen() -> void:
	if current_screen and is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = null
	game = null


func show_title() -> void:
	active_activity = {}
	if music:
		music.switch_theme("home")
		music.set_game_paused(false)
	_clear_screen()
	var t := Title.new()
	t.main = self
	add_child(t)
	current_screen = t
	if analytics:
		analytics.track("screen_view", {"screen": "home"})


func show_ranking() -> void:
	_clear_screen()
	var screen := preload("res://scripts/RankingScreen.gd").new()
	screen.main = self
	add_child(screen)
	current_screen = screen


func show_map(skip_pending_story: bool = false) -> void:
	active_activity = {}
	if music:
		music.switch_theme("map")
		music.set_game_paused(false)
	var interactive := not OS.get_cmdline_user_args().has("--shots") and DisplayServer.get_name() != "headless"
	if interactive and not skip_pending_story:
		for chapter_index in range(5):
			var final_level := chapter_index * 10 + 9
			var sequence_id := "chapter_%02d_end" % (chapter_index + 1)
			if save.get_stars(final_level) > 0 and not save.has_seen_scenario(sequence_id):
				show_story(ScenarioCatalog.chapter(chapter_index, "end"), func(): show_map(true))
				return
	_clear_screen()
	var m := MapScreen.new()
	m.main = self
	add_child(m)
	current_screen = m
	if analytics:
		analytics.track("screen_view", {"screen": "level_map"})


func show_story(sequence: Dictionary, on_finished: Callable) -> void:
	if sequence.is_empty():
		if on_finished.is_valid():
			on_finished.call_deferred()
		return
	if music:
		music.switch_theme("story")
	_clear_screen()
	var story := StoryScreen.new()
	story.main = self
	story.sequence = sequence
	story.on_finished = on_finished
	add_child(story)
	current_screen = story


func show_story_overlay(sequence: Dictionary, on_finished: Callable) -> void:
	## 클리어 직후 이야기는 게임 노드를 유지한 채 전체 화면 위에 재생한다.
	if sequence.is_empty():
		if on_finished.is_valid():
			on_finished.call_deferred()
		return
	if music:
		music.switch_theme("story")
	# HUD는 CanvasLayer라 일반 Control의 z_index보다 항상 위에 그려진다.
	# 시나리오도 더 높은 전용 CanvasLayer에 올려 플레이 힌트/HUD가 비치지 않게 한다.
	var story_layer := CanvasLayer.new()
	story_layer.name = "StoryOverlayLayer"
	story_layer.layer = 100
	add_child(story_layer)
	var story := StoryScreen.new()
	story.main = self
	story.sequence = sequence
	story.on_finished = func():
		if is_instance_valid(story_layer):
			story_layer.queue_free()
		if music and game:
			music.switch_theme("boss" if game.L.has("boss") else "puzzle")
		if on_finished.is_valid():
			on_finished.call_deferred()
	story_layer.add_child(story)


func play_intro_if_needed() -> bool:
	if not save.has_nickname() or save.has_seen_scenario("intro"):
		return false
	show_story(ScenarioCatalog.intro(), Callable(self, "show_title"))
	return true


func start_level(idx: int, bypass_energy: bool = false, skip_story: bool = false) -> void:
	if idx >= Levels.level_count():
		show_map()
		return
	if music:
		var level_data := Levels.get_level(idx)
		music.switch_theme("boss" if level_data.has("boss") else "puzzle")
		music.set_game_paused(false)
	if not bypass_energy and not save.is_level_segment_unlocked(idx / SaveGame.LEVEL_GATE_SIZE):
		request_level_segment_unlock(idx, func(): start_level(idx, false, skip_story))
		return
	# 현재 제작된 시나리오는 1~5장까지이며, 확장 챕터는 바로 게임으로 진입한다.
	if not bypass_energy and not skip_story and idx % 10 == 0 and idx < 50:
		var chapter_index := idx / 10
		var sequence_id := "chapter_%02d_start" % (chapter_index + 1)
		if not save.has_seen_scenario(sequence_id):
			show_story(ScenarioCatalog.chapter(chapter_index, "start"), func(): start_level(idx, false, true))
			return
	if not bypass_energy and not skip_story and [100, 150, 200, 250, 300, 500, 750].has(idx):
		var journey_level := idx + 1
		var journey_sequence := ScenarioCatalog.journey(journey_level, "start")
		var journey_id := String(journey_sequence.get("sequence_id", ""))
		if not journey_id.is_empty() and not save.has_seen_scenario(journey_id):
			show_story(journey_sequence, func(): start_level(idx, false, true))
			return
	var energy_reserved := false
	# L1~10은 핵심 규칙과 첫 보스를 부담 없이 익히는 보호 구간이다.
	# 두 번째 챕터부터 입장 시 예약 차감하고 클리어 시 반환한다.
	if idx >= 10 and not bypass_energy:
		if not save.reserve_energy():
			show_map()
			if current_screen is MapScreen:
				current_screen.call_deferred("show_energy_empty")
			return
		energy_reserved = true
	_clear_screen()
	var g := Game.new()
	save.record_daily_action("play")
	save.record_weekly_action("play")
	g.main = self
	g.level_idx = idx
	g.energy_reserved = energy_reserved
	add_child(g)
	current_screen = g
	game = g
	if analytics:
		analytics.track("level_start", {"level": idx + 1, "energy": save.get_energy(), "previous_stars": save.get_stars(idx)})


func start_daily_challenge() -> void:
	if save.has_completed_daily_challenge():
		show_title()
		return
	var level_number := LiveProgressionCatalogLib.daily_challenge_level()
	if level_number <= 0 or level_number > Levels.level_count():
		show_title()
		return
	var date := Time.get_date_dict_from_system()
	var seed := int(date.year) * 372 + int(date.month) * 31 + int(date.day)
	active_activity = {"kind": "daily", "step": 0, "level": level_number, "modifier": RetentionCatalogLib.modifier_for_seed(seed)}
	if analytics:
		analytics.track("live_activity", {"kind":"daily","modifier":String(active_activity.modifier.get("id", "")),"result":"start"})
	start_level(level_number - 1, true, true)


func start_weekly_expedition() -> void:
	var step := save.get_weekly_expedition_step()
	if step >= 5:
		show_title()
		return
	_start_weekly_expedition_step(step)


func _start_weekly_expedition_step(step: int) -> void:
	var level_number := LiveProgressionCatalogLib.weekly_expedition_level(step)
	if level_number <= 0 or level_number > Levels.level_count():
		show_title()
		return
	var week_seed := int(Time.get_unix_time_from_system()) / (7 * 24 * 60 * 60)
	active_activity = {"kind": "weekly_expedition", "step": step, "level": level_number, "modifier": RetentionCatalogLib.modifier_for_seed(week_seed + step)}
	if analytics:
		analytics.track("live_activity", {"kind":"weekly_expedition","modifier":String(active_activity.modifier.get("id", "")),"result":"start"})
	start_level(level_number - 1, true, true)


func retry_active_activity() -> void:
	if active_activity.is_empty():
		return
	var level_number := int(active_activity.get("level", 0))
	start_level(level_number - 1, true, true)


func advance_active_activity() -> void:
	if String(active_activity.get("kind", "")) != "weekly_expedition":
		show_title()
		return
	var next_step := save.get_weekly_expedition_step()
	if next_step >= 5:
		show_title()
		return
	_start_weekly_expedition_step(next_step)


func active_activity_title() -> String:
	var modifier_name := L10n.text(String(active_activity.get("modifier", {}).get("name", "")))
	match String(active_activity.get("kind", "")):
		"daily":
			return L10n.text("오늘의 특별 구조 · %s") % modifier_name
		"weekly_expedition":
			return L10n.text("주간 원정 %d/5 · %s") % [int(active_activity.get("step", 0)) + 1, modifier_name]
	return ""


func request_level_segment_unlock(target_level: int, on_unlocked: Callable = Callable()) -> void:
	var segment := target_level / SaveGame.LEVEL_GATE_SIZE
	# 강제 광고 관문을 폐지했다. 구버전 호출도 즉시 정상 진행시킨다.
	if segment >= 0:
		save.unlock_level_segment(segment)
		if on_unlocked.is_valid():
			on_unlocked.call_deferred()
		return
	if segment <= 0 or save.is_level_segment_unlocked(segment):
		if on_unlocked.is_valid():
			on_unlocked.call_deferred()
		return
	if not save.can_unlock_level_segment(segment) or _level_gate_overlay != null:
		return
	var first_level := segment * SaveGame.LEVEL_GATE_SIZE + 1
	var last_level := mini((segment + 1) * SaveGame.LEVEL_GATE_SIZE, Levels.level_count())
	var layer := CanvasLayer.new()
	layer.layer = 300
	add_child(layer)
	_level_gate_overlay = layer
	var dim := ColorRect.new()
	dim.theme = ArtDirection.ui_theme()
	dim.color = ArtDirection.dim_color()
	dim.position = Vector2.ZERO
	dim.size = get_viewport().get_visible_rect().size
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.position = G.safe_offset(get_viewport().get_visible_rect().size)
	center.size = Vector2(G.W, G.H)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	var panel_style := ArtDirection.glass_panel(Color("#fff8ed"), 0.99, 34)
	panel_style.set_border_width_all(1)
	panel_style.border_color = ArtDirection.border_color()
	panel_style.content_margin_left = 42
	panel_style.content_margin_right = 42
	panel_style.content_margin_top = 38
	panel_style.content_margin_bottom = 38
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 20)
	panel.add_child(content)
	var icon := Label.new()
	icon.text = "🔓"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 72)
	content.add_child(icon)
	var title := Label.new()
	title.text = L10n.text("새로운 모험을 열어요!")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(title)
	var guide := Label.new()
	guide.text = (L10n.text("LEVEL %d~%d 구간을\nVIP 혜택으로 바로 열 수 있어요.") if save.has_removed_ads() else L10n.text("LEVEL %d~%d 구간을 열려면\n보상형 광고를 끝까지 시청해 주세요.")) % [first_level, last_level]
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide.add_theme_font_size_override("font_size", 24)
	guide.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(guide)
	var status := Label.new()
	status.text = L10n.text("해금하면 이 구간은 계속 이용할 수 있어요.")
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_color", ArtDirection.ink())
	content.add_child(status)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	content.add_child(buttons)
	var cancel := Button.new()
	cancel.text = L10n.text("나중에")
	cancel.custom_minimum_size = Vector2(190, 72)
	cancel.add_theme_font_size_override("font_size", 25)
	ArtDirection.apply_button(cancel, Color("#8c8297"), 20)
	buttons.add_child(cancel)
	var unlock := Button.new()
	unlock.text = L10n.text("바로 열기") if save.has_removed_ads() else L10n.text("광고 보고 열기")
	unlock.custom_minimum_size = Vector2(280, 72)
	unlock.add_theme_font_size_override("font_size", 25)
	ArtDirection.apply_button(unlock, Color("#8e64c8"), 20)
	buttons.add_child(unlock)
	var close_overlay := func():
		if is_instance_valid(layer):
			layer.queue_free()
		_level_gate_overlay = null
	cancel.pressed.connect(close_overlay)
	unlock.pressed.connect(func():
		unlock.disabled = true
		cancel.disabled = true
		unlock.text = L10n.text("해금 중...") if save.has_removed_ads() else L10n.text("광고 재생 중...")
		status.text = L10n.text("VIP 구간 스킵을 적용하고 있어요.") if save.has_removed_ads() else L10n.text("광고를 닫지 말고 끝까지 시청해 주세요.")
		request_rewarded_ad(func():
			if not save.unlock_level_segment(segment):
				status.text = L10n.text("구간을 열지 못했어요. 다시 시도해 주세요.")
				unlock.disabled = false
				cancel.disabled = false
				return
			close_overlay.call()
			if on_unlocked.is_valid():
				on_unlocked.call_deferred(),
		func():
			unlock.disabled = false
			cancel.disabled = false
			unlock.text = L10n.text("광고 보고 열기")
			var reason := String(platform.rewarded_ad_message) if platform else ""
			status.text = L10n.text("광고를 끝까지 시청해야 열 수 있어요.") if reason.contains("완료되지") else L10n.text("광고를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."),
		"level_segment_unlock_%d" % segment)
	)


func play_chapter_end_if_needed(level_idx: int, destination: Callable) -> bool:
	# 자동 플레이는 입력을 만들지 않으므로 이야기 오버레이를 건너뛴다.
	if OS.get_cmdline_user_args().has("--shots") or DisplayServer.get_name() == "headless":
		return false
	var is_chapter_end := level_idx % 10 == 9 and level_idx < 50
	var chapter_index := level_idx / 10
	var sequence_id := "chapter_%02d_end" % (chapter_index + 1)
	if is_chapter_end and not save.has_seen_scenario(sequence_id):
		show_story_overlay(ScenarioCatalog.chapter(chapter_index, "end"), destination)
		return true
	var level_number := level_idx + 1
	if [150, 200, 250, 300, 500, 750, 1000].has(level_number):
		var journey_sequence := ScenarioCatalog.journey(level_number, "end")
		var journey_id := String(journey_sequence.get("sequence_id", ""))
		if not journey_id.is_empty() and not save.has_seen_scenario(journey_id):
			show_story_overlay(journey_sequence, destination)
			return true
	return false


func on_level_finished(idx: int, stars: int, cleared: bool, refund_reserved_energy: bool = false, reward_cap: int = -1, clear_time: float = 0.0) -> int:
	var stardust_reward := 0
	last_furniture_reward = {}
	last_new_resident = {}
	if cleared:
		save.record_daily_action("clear")
		save.record_weekly_action("clear")
		if not active_activity.is_empty():
			var activity_reward := {}
			match String(active_activity.get("kind", "")):
				"daily":
					activity_reward = save.complete_daily_challenge()
				"weekly_expedition":
					activity_reward = save.complete_weekly_expedition_step(int(active_activity.get("step", -1)))
			var activity_stardust := maxi(0, int(activity_reward.get("stardust", 0)))
			save.record_level_success()
			if String(active_activity.get("kind", "")) == "weekly_expedition":
				if save.record_weekly_activity_time(clear_time): platform.submit_weekly_record(int(clear_time * 1000.0))
			if analytics:
				analytics.track("currency_source", {"currency": "stardust", "amount": activity_stardust, "source": String(active_activity.get("kind", "activity"))})
				analytics.track("live_activity", {"kind":String(active_activity.get("kind", "activity")),"modifier":String(active_activity.get("modifier", {}).get("id", "")),"result":"clear"})
			return activity_stardust
		if clear_time > 0.0:
			save.record_clear_time(idx, clear_time)
		var first_clear := save.get_stars(idx) == 0
		stardust_reward = save.award_stars(idx, stars, reward_cap)
		save.record_three_star_clear(idx, stars)
		if analytics and stardust_reward > 0:
			analytics.track("currency_source", {"currency": "stardust", "amount": stardust_reward, "source": "level_star_reward"})
		if first_clear:
			save.grant_restoration_point(idx + 1)
			var support_bonus := int(save.adventure_support().get("stardust_bonus", 0))
			if support_bonus > 0:
				save.grant_stardust(support_bonus)
				stardust_reward += support_bonus
				if analytics:
					analytics.track("currency_source", {"currency":"stardust","amount":support_bonus,"source":"restored_town_support"})
			if save.register_rescued_jelly(idx):
				var records := save.get_resident_records()
				if not records.is_empty():
					last_new_resident = records.back()
			last_furniture_reward = save.claim_level_furniture_reward(idx + 1)
		save.record_level_success()
		if refund_reserved_energy:
			save.refund_energy()
		var total_stars := 0
		for value in save.stars.values():
			total_stars += int(value)
		platform.submit_score(total_stars)
		if adventure_cloud:
			adventure_cloud.sync()
		if ranking:
			ranking.sync_record()
	return stardust_reward


func request_rewarded_ad(on_reward: Callable, on_unavailable: Callable = Callable(), placement: String = "unknown") -> void:
	## 광고는 사용자가 직접 선택한 보상 위치에서만 요청한다. VIP는 하루 한 번 즉시 완료한다.
	if analytics:
		analytics.track("rewarded_ad_offer", {"placement": placement})
	var rewarded := func():
		if analytics:
			analytics.track("rewarded_ad_result", {"placement": placement, "result": "completed"})
		if on_reward.is_valid():
			on_reward.call()
	var unavailable := func():
		if analytics:
			analytics.track("rewarded_ad_result", {"placement": placement, "result": "unavailable"})
		if on_unavailable.is_valid():
			on_unavailable.call()
	if save.consume_rewarded_ad_skip(placement):
		if analytics:
			analytics.track("rewarded_ad_result", {"placement": placement, "result": "vip_skip"})
		if on_reward.is_valid():
			on_reward.call_deferred()
		return
	if platform:
		platform.show_rewarded_ad(rewarded, unavailable)
	elif not get_signal_connection_list("rewarded_ad_requested").is_empty():
		rewarded_ad_requested.emit(rewarded, unavailable)
	elif on_unavailable.is_valid():
		unavailable.call_deferred()


func _screenshot_run() -> void:
	## 개발용: 화면 캡처 (xvfb 환경 QA)
	await get_tree().create_timer(1.2).timeout
	if current_screen is Title and not save.has_nickname():
		current_screen._show_nickname_popup()
		await get_tree().create_timer(0.25).timeout
		await _snap("shot_nickname.png")
		current_screen.nickname_input.text = L10n.text("젤리친구")
		current_screen._confirm_nickname()
		await get_tree().create_timer(0.1).timeout
		if current_screen.attendance_popup:
			current_screen._close_attendance_popup()
	show_story(ScenarioCatalog.intro(), Callable(self, "show_title"))
	await get_tree().create_timer(0.45).timeout
	await _snap("shot_story_intro.png")
	if current_screen is StoryScreen:
		current_screen._finish()
	await get_tree().create_timer(0.12).timeout
	show_story(ScenarioCatalog.chapter(0, "start"), Callable(self, "show_title"))
	await get_tree().create_timer(0.45).timeout
	await _snap("shot_story_chapter_start.png")
	if current_screen is StoryScreen:
		current_screen._finish()
	await get_tree().create_timer(0.12).timeout
	show_story(ScenarioCatalog.chapter(4, "end"), Callable(self, "show_title"))
	await get_tree().create_timer(0.45).timeout
	await _snap("shot_story_chapter_end.png")
	if current_screen is StoryScreen:
		current_screen._finish()
	await get_tree().create_timer(0.12).timeout
	await _snap("shot_title.png")
	if current_screen is Title:
		current_screen._show_shop_popup()
	await get_tree().create_timer(0.2).timeout
	await _snap("shot_shop.png")
	var qa_buy_button := Button.new()
	if current_screen is Title:
		current_screen.add_child(qa_buy_button)
		current_screen._show_purchase_confirmation(ShopCatalog.item_by_id("heart_5"), qa_buy_button)
	await get_tree().create_timer(0.2).timeout
	await _snap("shot_purchase_confirm.png")
	if current_screen is Title:
		current_screen._close_purchase_confirmation()
	if is_instance_valid(qa_buy_button):
		qa_buy_button.queue_free()
	if current_screen is Title:
		current_screen._close_shop_popup()
		current_screen._show_attendance_popup()
	await get_tree().create_timer(0.2).timeout
	await _snap("shot_attendance.png")
	if current_screen is Title:
		current_screen._close_attendance_popup()
		current_screen._enter_edit_mode()
	await get_tree().create_timer(0.2).timeout
	await _snap("shot_room_edit.png")
	if current_screen is Title:
		current_screen._leave_edit_mode()
		current_screen._enter_photo_mode()
	await get_tree().create_timer(0.2).timeout
	await _snap("shot_room_photo.png")
	if current_screen is Title:
		await current_screen._save_photo()
		current_screen._leave_photo_mode()
		current_screen._show_album()
	await get_tree().create_timer(0.2).timeout
	await _snap("shot_room_album.png")
	show_map()
	await get_tree().create_timer(0.6).timeout
	await _snap("shot_map.png")
	if current_screen is MapScreen:
		current_screen.show_energy_empty()
	await get_tree().create_timer(0.2).timeout
	await _snap("shot_energy.png")
	# 색상별 젤리 배출구가 포함된 L10을 대표 시스템 시각 회귀 테스트 대상으로 사용한다.
	start_level(9, true)
	await get_tree().create_timer(1.2).timeout
	if game:
		await game.debug_capture_one()
	await get_tree().create_timer(0.14).timeout
	await _snap("shot_absorb.png")
	if game:
		await game.debug_capture_one()
	await get_tree().create_timer(0.14).timeout
	await _snap("shot_play.png")
	if game:
		game.set_paused(true)
	await get_tree().create_timer(0.12).timeout
	await _snap("shot_pause.png")
	if game:
		game.set_paused(false)
	if game:
		game.hud.show_result(3, 1234, 5, save.get_stardust(), 42.35, 39.2, true, func(): pass, func(): pass, func(): pass)
	await get_tree().create_timer(0.25).timeout
	await _snap("shot_clear_reward.png")
	if game:
		game.hud._request_clear_double_reward()
	await get_tree().create_timer(1.1).timeout
	await _snap("shot_clear_reward_doubled.png")
	start_level(9, true)
	await get_tree().create_timer(0.5).timeout
	# 개발 캡처에서만 임시 잔액을 사용해 별가루 이어하기 팝업을 시각 검수한다(저장하지 않음).
	if game:
		save.stardust = 27
		game._fail()
	await get_tree().create_timer(1.1).timeout
	await _snap("shot_fail_stardust.png")
	_request_shutdown()


func _screenshot_map() -> void:
	## 연속형 월드맵을 빠르게 확인하는 전용 시각 회귀 캡처.
	show_map(true)
	await get_tree().create_timer(0.8).timeout
	await _snap("shot_map.png")
	_request_shutdown()


func _snap(fname: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/jellymon_" + fname)
	print("[snap] ", fname)


func _screenshot_room_refresh() -> void:
	## 첫 방 그래픽만 빠르게 검수하는 전용 캡처. 실제 저장 데이터는 변경하지 않는다.
	await get_tree().create_timer(0.8).timeout
	if current_screen is Title:
		current_screen._show_home_interaction_hint()
	await get_tree().create_timer(0.1).timeout
	await _snap("room_refresh.png")
	_request_shutdown()


func _screenshot_home_menu() -> void:
	await get_tree().create_timer(0.45).timeout
	if current_screen is Title:
		current_screen._show_home_menu()
	await get_tree().create_timer(0.35).timeout
	await _snap("home_menu.png")
	_request_shutdown()


func _screenshot_lifestyle() -> void:
	## 시즌 생활 팝업의 텍스트 대비와 스크롤 배치를 빠르게 검수한다.
	await get_tree().create_timer(0.45).timeout
	if current_screen is Title:
		current_screen._show_lifestyle_popup()
	await get_tree().create_timer(0.35).timeout
	await _snap("lifestyle.png")
	_request_shutdown()


func _screenshot_room_edit() -> void:
	## 꾸미기 메뉴의 하단 정렬을 빠르게 검수한다.
	await get_tree().create_timer(0.4).timeout
	if current_screen is Title:
		current_screen._enter_edit_mode()
	await get_tree().create_timer(0.4).timeout
	await _snap("room_edit_bottom.png")
	_request_shutdown()


func _screenshot_level_51() -> void:
	## 확장 캠페인의 얼음 젤리 가독성을 빠르게 검수한다.
	start_level(50, true, true)
	await get_tree().create_timer(0.8).timeout
	await _snap("level_51_frost.png")
	_request_shutdown()


func _screenshot_level_39() -> void:
	## 파란 S1 시작 탈출 통로 회귀 검수용 캡처.
	start_level(38, true, true)
	await get_tree().create_timer(0.8).timeout
	await _snap("level_39_blue_escape.png")
	_request_shutdown()


func _screenshot_endgame() -> void:
	## 보스 3종과 신규 기믹/대체 승리 조건 대표 레벨의 실제 화면을 캡처한다.
	var picks := {}
	for index in range(100, Levels.level_count()):
		var data: Dictionary = Levels.get_level(index)
		if data.has("boss"):
			var key := "boss_" + String(data.boss.type)
			if not picks.has(key):
				picks[key] = index
		for condition in ["move_limit", "color_order", "escort"]:
			if data.has(condition) and not picks.has(condition):
				picks[condition] = index
		for name in ["ghost", "sticky", "one_way", "bomb"]:
			if Levels._level_has_gimmick(data, name) and not picks.has(name):
				picks[name] = index
	for key in picks:
		start_level(int(picks[key]), true, true)
		await get_tree().create_timer(0.5).timeout
		await _snap("endgame_%s_L%d.png" % [key, int(picks[key]) + 1])
	_request_shutdown()


func _screenshot_pause() -> void:
	start_level(9, true, true)
	await get_tree().create_timer(0.8).timeout
	if game:
		game.set_paused(true)
	await get_tree().create_timer(0.15).timeout
	await _snap("shot_pause.png")
	_request_shutdown()


func _screenshot_late_gimmicks() -> void:
	## 구간별 대표 기믹과 100레벨 복합 관문의 실제 화면을 연속 캡처한다.
	for level_index in [60, 70, 80, 99]:
		start_level(level_index, true, true)
		await get_tree().create_timer(0.45).timeout
		await _snap("level_%d_gimmick.png" % (level_index + 1))
	_request_shutdown()


func _headless_story_typing_test() -> void:
	show_story(ScenarioCatalog.intro(), Callable())
	await get_tree().create_timer(0.2).timeout
	var typing_valid: bool = current_screen is StoryScreen and current_screen.debug_validate_typewriter_advance()
	var auto_valid := false
	if current_screen is StoryScreen:
		current_screen.debug_start_auto_advance_test()
		await get_tree().create_timer(StoryScreen.AUTO_ADVANCE_DELAY_SEC + 0.2).timeout
		auto_valid = current_screen is StoryScreen and current_screen.line_index == 1 and current_screen.typing
	print("[story typing validation] next_line_retypes=", typing_valid, " auto_advance_2_5s=", auto_valid)
	_request_shutdown(0 if typing_valid and auto_valid else 1)


func _validate_story_localization(take_shots: bool) -> void:
	audio.enabled = false
	music.set_enabled(false)
	var errors := Localization.validate_catalogs()
	var sequences: Array = [ScenarioCatalog.intro()]
	for chapter in range(5):
		for phase in ["start", "end"]:
			sequences.append(ScenarioCatalog.chapter(chapter, phase))
	for level in [101, 150, 151, 200, 201, 250, 251, 300, 301, 500, 501, 750, 751, 1000]:
		sequences.append(ScenarioCatalog.journey(level, "start" if level % 10 == 1 else "end"))
	var hangul := RegEx.new()
	hangul.compile("[가-힣]")
	var line_checks := 0
	save.nickname = "Tester"
	if take_shots:
		DirAccess.make_dir_recursive_absolute("res://tmp/story-review")
	for locale in Localization.SUPPORTED_LOCALES:
		Localization.apply_language(locale)
		for sequence in sequences:
			show_story(sequence, Callable())
			await get_tree().process_frame
			var story: StoryScreen = current_screen
			story.set_process(false)
			for index in range(story.lines.size()):
				story._show_line(index)
				story.dialogue_label.visible_characters = -1
				await get_tree().process_frame
				line_checks += 1
				if locale != "ko" and (hangul.search(story.full_text) != null or hangul.search(story.speaker_label.text) != null):
					errors.append("untranslated story runtime: %s/%s/%d" % [locale, sequence.sequence_id, index])
				if story.full_text.contains("{player_name}") or story.dialogue_label.get_content_height() > story.dialogue_label.size.y:
					errors.append("story text overflow or unresolved name: %s/%s/%d" % [locale, sequence.sequence_id, index])
				if take_shots and sequence.sequence_id == "intro" and index == 7:
					await RenderingServer.frame_post_draw
					var result := get_viewport().get_texture().get_image().save_png("res://tmp/story-review/%s.png" % locale)
					if result != OK: errors.append("story screenshot failed: %s" % locale)
			if story.header_panel.get_rect().end.x > G.W or story.skip_button.get_rect().end.x > G.W:
				errors.append("story header overflow: %s/%s" % [locale, sequence.sequence_id])
	print("[story localization] locales=8 sequences=", sequences.size(), " lines=", line_checks, " errors=", errors.size())
	for error in errors:
		push_error(error)
	_request_shutdown(0 if errors.is_empty() else 1)


func _headless_story_overlay_test() -> void:
	start_level(0, true, true)
	await get_tree().process_frame
	var finished := [false]
	show_story_overlay(ScenarioCatalog.chapter(0, "end"), func(): finished[0] = true)
	await get_tree().process_frame
	var story_layer := get_node_or_null("StoryOverlayLayer") as CanvasLayer
	var story: StoryScreen = null
	if story_layer:
		for child in story_layer.get_children():
			if child is StoryScreen:
				story = child
				break
	var ordering_valid := story_layer != null and game != null and game.hud != null and story_layer.layer > game.hud.layer
	if story:
		story._finish()
	await get_tree().process_frame
	await get_tree().process_frame
	var cleanup_valid := get_node_or_null("StoryOverlayLayer") == null and bool(finished[0])
	print("[story overlay validation] above_hud=", ordering_valid, " cleanup=", cleanup_valid)
	_clear_screen()
	await get_tree().process_frame
	await get_tree().process_frame
	_request_shutdown(0 if ordering_valid and cleanup_valid else 1)


func _headless_touch_test() -> void:
	start_level(0, true, true)
	await get_tree().create_timer(0.4).timeout
	var offsets := [Vector2(0, 140), Vector2(0, 300), Vector2(40, 0), Vector2(180, 0)]
	var failed := false
	for offset in offsets:
		var valid := game != null and game.debug_validate_touch_mapping(offset)
		print("[touch validation] offset=", offset, " valid=", valid)
		failed = failed or not valid
	var smooth_drag_valid := game != null and game.debug_validate_smooth_drag()
	print("[touch validation] smooth_drag=", smooth_drag_valid)
	failed = failed or not smooth_drag_valid
	# 이동 흔적 파티클이 정상 해제된 뒤 종료해 QA 종료 자체를 누수로 오인하지 않게 한다.
	await get_tree().create_timer(0.7).timeout
	_request_shutdown(1 if failed else 0)


func _headless_delayed_trap_test() -> void:
	start_level(0, true, true)
	await get_tree().create_timer(0.4).timeout
	var before := game.jellies.size() if game else 0
	if game:
		await game.debug_capture_one()
	await get_tree().create_timer(0.08).timeout
	var reserved := 0
	var unlocked := true
	if game:
		for catcher in game.catchers:
			reserved += catcher.trapped_jellies
			unlocked = unlocked and not catcher.movement_locked
	var started := game != null and game.jellies.size() < before and game.active_absorptions > 0 and reserved > 0 and unlocked
	await get_tree().create_timer(0.24).timeout
	var held_before_burst := game != null and game.active_absorptions > 0
	await get_tree().create_timer(0.34).timeout
	var finished_after_half_second := game != null and game.active_absorptions == 0
	print("[delayed trap validation] started=", started, " held=", held_before_burst, " finished=", finished_after_half_second)
	_request_shutdown(0 if started and held_before_burst and finished_after_half_second else 1)


func _headless_level_39_test() -> void:
	start_level(38, true, true)
	await get_tree().create_timer(0.3).timeout
	var blue = null
	if game:
		for catcher in game.catchers:
			if catcher.color_id == "B" and catcher.shape_id == "S1":
				blue = catcher
				break
	var start_cell: Vector2i = blue.origin_cell if blue else Vector2i(-1, -1)
	var center_pick_valid := false
	var badge_pick_valid := false
	if blue:
		var blue_center := game.to_global(game.cell_pos(blue.origin_cell))
		center_pick_valid = game._pick_catcher(blue_center) == blue
		badge_pick_valid = game._pick_catcher(blue.badge_panel.get_global_rect().get_center()) == blue
	var moved_down: bool = blue != null and game._try_step(blue, Vector2i.DOWN)
	var valid: bool = center_pick_valid and badge_pick_valid and moved_down and blue.origin_cell == start_cell + Vector2i.DOWN
	print("[level 39 validation] blue_start=", start_cell, " center_pick=", center_pick_valid, " badge_pick=", badge_pick_valid, " moved_down=", moved_down, " valid=", valid)
	_request_shutdown(0 if valid else 1)


func _headless_level_17_test() -> void:
	start_level(16, true, true)
	await get_tree().create_timer(0.3).timeout
	var blue: Catcher = null
	if game:
		for catcher in game.catchers:
			if catcher.color_id == "B" and catcher.shape_id == "S1":
				blue = catcher
				break
	var start_cell := blue.origin_cell if blue else Vector2i(-1, -1)
	if blue:
		blue.set_full()
	var unlocked := blue != null and not blue.movement_locked
	var moved_up := blue != null and game._try_step(blue, Vector2i.UP)
	var valid := unlocked and moved_up and blue.origin_cell == start_cell + Vector2i.UP
	print("[level 17 validation] full_unlocked=", unlocked, " moved_up=", moved_up, " valid=", valid)
	_request_shutdown(0 if valid else 1)


func _headless_level_7_test() -> void:
	## 2×2 노랑 블록이 한 번에 겹치는 세 젤리를 빠짐없이 모두 가두는지 검증한다.
	start_level(6, true, true)
	await get_tree().create_timer(0.3).timeout
	var yellow: Catcher = null
	if game:
		for catcher in game.catchers:
			if catcher.color_id == "Y" and catcher.shape_id == "SQ":
				yellow = catcher
				break
	var before := game.jellies.size() if game else 0
	if yellow:
		for off in yellow.cells:
			game.catcher_at.erase(yellow.origin_cell + off)
		yellow.origin_cell = Vector2i(1, 1)
		for off in yellow.cells:
			game.catcher_at[yellow.origin_cell + off] = yellow
		yellow.position = game.origin + Vector2(yellow.origin_cell) * G.CELL
		yellow.slide_target = yellow.position
		game._absorb_footprint(yellow)
	var captured := before - game.jellies.size() if game else 0
	var reserved := yellow.trapped_jellies if yellow else 0
	var valid := yellow != null and captured == 3 and reserved == 3 and yellow.remaining_capacity == 1
	await get_tree().create_timer(0.65).timeout
	var burst_finished := game != null and game.active_absorptions == 0 and yellow.trapped_jellies == 0
	valid = valid and burst_finished
	print("[level 7 validation] captured=", captured, " reserved=", reserved, " remaining=", yellow.remaining_capacity if yellow else -1, " burst_finished=", burst_finished, " valid=", valid)
	_request_shutdown(0 if valid else 1)


func _headless_level_44_test() -> void:
	## L44의 큰 초록 V4가 위로 이동한 뒤 왼쪽 통로로 빠질 수 있는지 검증한다.
	start_level(43, true, true)
	await get_tree().create_timer(0.3).timeout
	var green_v4 = null
	if game:
		for catcher in game.catchers:
			if catcher.color_id == "G" and catcher.shape_id == "V4":
				green_v4 = catcher
				break
	var start_cell: Vector2i = green_v4.origin_cell if green_v4 else Vector2i(-1, -1)
	var moved_up: bool = green_v4 != null and game._try_step(green_v4, Vector2i.UP)
	var moved_left: bool = moved_up and game._try_step(green_v4, Vector2i.LEFT)
	var valid: bool = moved_left and green_v4.origin_cell == start_cell + Vector2i.UP + Vector2i.LEFT
	print("[level 44 validation] green_start=", start_cell, " moved_up=", moved_up, " moved_left=", moved_left, " valid=", valid)
	_request_shutdown(0 if valid else 1)


func _headless_expansion_test() -> void:
	## 10레벨 단위 공개, 4종 후반 기믹, 복합 관문, PC C 테스트 클리어를 검증한다.
	var test_save := SaveGame.new()
	test_save.persistence_enabled = false
	var visibility_valid := Levels.visible_chapter_count(test_save) == 5
	for chapter_end in [49, 59, 69, 79, 89]:
		test_save.award_stars(chapter_end, 1)
		visibility_valid = visibility_valid and Levels.visible_chapter_count(test_save) == 6 + (chapter_end - 49) / 10
	save = test_save
	var runtime_valid := true
	for level_index in [50, 60, 70, 80, 90, 91, 96, 99]:
		start_level(level_index, true, true)
		await get_tree().create_timer(0.25).timeout
		var flags := Levels._gimmick_flags(level_index + 1)
		var valid := game != null
		if valid:
			valid = (not game.frozen_at.is_empty()) == bool(flags.frost)
			valid = valid and ((not game.chain_at.is_empty()) == bool(flags.chain))
			valid = valid and ((not game.switch_at.is_empty() and not game.sealed_at.is_empty()) == bool(flags.switch))
			valid = valid and ((not game.key_unlock_at.is_empty() and not game.locked_catcher_indices.is_empty()) == bool(flags.key))
		print("[expansion validation] level=", level_index + 1, " flags=", flags, " runtime=", valid)
		runtime_valid = runtime_valid and valid
	start_level(50, true, true)
	await get_tree().create_timer(0.25).timeout
	if game:
		game._debug_clear_one_star_and_next()
	await get_tree().create_timer(0.35).timeout
	var debug_clear_valid := save.get_stars(50) == 1 and game != null and game.level_idx == 51
	print("[expansion validation] levels=", Levels.level_count(), " visibility=", visibility_valid, " runtime=", runtime_valid, " c_key_clear=", debug_clear_valid)
	_request_shutdown(0 if Levels.level_count() == Levels.TOTAL_LEVELS and visibility_valid and runtime_valid and debug_clear_valid else 1)


func _headless_advanced_expansion_test() -> void:
	## 501~1000 신규 규칙이 베이크 데이터뿐 아니라 실제 Game 런타임에도 연결됐는지 검증한다.
	var targets := {
		500: "portal",
		600: "fragile",
		700: "fog",
		800: "current",
		900: "time_rift",
	}
	var failed := false
	for level_index in targets:
		start_level(level_index, true, true)
		await get_tree().process_frame
		await get_tree().process_frame
		var runtime_count := 0
		if game:
			match String(targets[level_index]):
				"portal": runtime_count = game.portal_at.size()
				"fragile": runtime_count = game.fragile_at.size()
				"fog": runtime_count = game.fog_at.size()
				"current": runtime_count = game.current_at.size()
				"time_rift": runtime_count = game.time_rift_at.size()
		var valid := game != null and runtime_count > 0
		print("[advanced expansion] level=", level_index + 1, " gimmick=", targets[level_index], " runtime_count=", runtime_count, " valid=", valid)
		failed = failed or not valid
	var final_level := Levels.get_level(999)
	var final_valid := int(final_level.get("advanced_difficulty_tier", 0)) == 5 and int(final_level.get("mechanic_generation", 0)) == 5
	var cache_valid := Levels._chunk_cache.size() <= Levels.LEVEL_CHUNK_CACHE_LIMIT
	print("[advanced expansion] levels=", Levels.level_count(), " final_tier=", final_level.get("advanced_difficulty_tier", 0), " cached_chunks=", Levels._chunk_cache.size(), " valid=", final_valid and cache_valid and not failed)
	_clear_screen()
	await get_tree().process_frame
	await get_tree().process_frame
	_request_shutdown(0 if Levels.level_count() == 1000 and final_valid and cache_valid and not failed else 1)


func _headless_level_gate_test() -> void:
	## 100레벨 클리어 → 광고 없이 다음 레벨 자동 해금 흐름을 검증한다.
	var test_save := SaveGame.new()
	test_save.persistence_enabled = false
	for chapter_end in range(9, 100, 10):
		test_save.award_stars(chapter_end, 1)
	save = test_save
	show_map()
	await get_tree().process_frame
	var before_valid := save.is_unlocked(100) and Levels.visible_chapter_count(save) == 11 and save.next_unlockable_level_segment(Levels.level_count()) == -1
	request_level_segment_unlock(100, Callable(self, "show_map"))
	await get_tree().process_frame
	var button_found := _level_gate_overlay == null
	var after_valid := save.is_level_segment_unlocked(1) and save.is_unlocked(100) and Levels.visible_chapter_count(save) == 11 and _level_gate_overlay == null
	print("[level gate validation] automatic=", before_valid, " no_ad_ui=", button_found, " after=", after_valid)
	_request_shutdown(0 if before_valid and button_found and after_valid else 1)


func _headless_endgame_test() -> void:
	## 보스 3종·대체 승리 조건 3종·신규 기믹 4종이 런타임에서 실제로 작동하는지 검증한다.
	var failed := false
	var boss_levels: Array[int] = []
	var condition_levels := {"move_limit": -1, "color_order": -1, "escort": -1}
	var gimmick_levels := {"ghost": -1, "sticky": -1, "one_way": -1, "bomb": -1}
	for index in range(100, Levels.level_count()):
		var data: Dictionary = Levels.get_level(index)
		if data.has("boss") and boss_levels.size() < 3:
			var already := false
			for existing in boss_levels:
				if String(Levels.get_level(existing).boss.type) == String(data.boss.type):
					already = true
			if not already:
				boss_levels.append(index)
		for key in condition_levels:
			if int(condition_levels[key]) < 0 and data.has(key):
				condition_levels[key] = index
		for key in gimmick_levels:
			if int(gimmick_levels[key]) < 0 and Levels._level_has_gimmick(data, String(key)):
				gimmick_levels[key] = index
	var targets: Array[int] = []
	for index in boss_levels:
		targets.append(index)
	for key in condition_levels:
		if int(condition_levels[key]) >= 0:
			targets.append(int(condition_levels[key]))
	for key in gimmick_levels:
		if int(gimmick_levels[key]) >= 0:
			targets.append(int(gimmick_levels[key]))
	for key in condition_levels:
		if int(condition_levels[key]) < 0:
			print("[endgame validation] 대체 승리 조건 없음: ", key)
			failed = true
	for key in gimmick_levels:
		if int(gimmick_levels[key]) < 0:
			print("[endgame validation] 신규 기믹 없음: ", key)
			failed = true
	if boss_levels.size() < 3:
		print("[endgame validation] 보스 3종을 모두 찾지 못함: ", boss_levels.size())
		failed = true
	for level_index in targets:
		start_level(level_index, true, true)
		await get_tree().create_timer(0.25).timeout
		if game == null:
			print("[endgame validation] level=", level_index + 1, " 생성 실패")
			failed = true
			continue
		await game.debug_drive()
		var cleared := game != null and game.state == "clear"
		print("[endgame validation] level=", level_index + 1, " state=", game.state if game else "none", " cleared=", cleared)
		if not cleared:
			failed = true
	print("[endgame validation] bosses=", boss_levels, " conditions=", condition_levels, " gimmicks=", gimmick_levels, " failed=", failed)
	_request_shutdown(1 if failed else 0)


func _headless_late_play_test() -> void:
	## 대표 레벨을 실제 흡수·해제·배출 파이프라인으로 끝까지 자동 플레이한다.
	var failed := false
	for level_index in [50, 60, 70, 80, 90, 99]:
		start_level(level_index, true, true)
		await get_tree().create_timer(0.2).timeout
		var active_game := game
		if active_game:
			await active_game.debug_drive()
			await get_tree().create_timer(1.5).timeout
		var cleared := active_game != null and active_game.state == "clear" and save.get_stars(level_index) > 0
		print("[late play validation] level=", level_index + 1, " cleared=", cleared)
		failed = failed or not cleared
	_request_shutdown(1 if failed else 0)


func _headless_smoke_test() -> void:
	print("[smoke] start")
	var smoke_failed := false
	await get_tree().create_timer(0.4).timeout
	show_map()
	await get_tree().create_timer(0.4).timeout
	for lv in [0, 9, 19, 29, 38, 39, 49]:
		start_level(lv, true)
		await get_tree().create_timer(0.5).timeout
		if game:
			if not game.debug_validate_touch_mapping():
				push_error("[smoke] Android 긴 화면 터치 좌표/손가락 추적 오류: level=%d" % lv)
				smoke_failed = true
			if not await game.debug_drive():
				smoke_failed = true
		await get_tree().create_timer(1.0).timeout
	print("[smoke] done")
	_request_shutdown(1 if smoke_failed else 0)


func _headless_character_system_test() -> void:
	var errors := CharacterCatalogLib.validate()
	var mock := SaveGame.new()
	mock.persistence_enabled = false
	for chapter in range(6):
		if not mock.register_rescued_jelly(chapter * 10):
			errors.append("주민 등록 실패: chapter %d" % (chapter + 1))
	var residents := mock.get_resident_records()
	if residents.size() != 6:
		errors.append("주민 수 오류: %d/6" % residents.size())
	var colors: Array = residents.map(func(record): return String(record.get("color", "")))
	for color_id in ["R", "Y", "B", "G", "P", "O"]:
		if not colors.has(color_id):
			errors.append("주민 색 누락: %s" % color_id)
	print("[character validation] residents=", residents.size(), " interactions=", CharacterCatalogLib.interactions().size(), " errors=", errors.size())
	for message in errors:
		push_error("[character validation] " + message)
	_request_shutdown(0 if errors.is_empty() else 1)


func _headless_tutorial_test() -> void:
	var errors := PackedStringArray()
	for level_index in range(3):
		start_level(level_index, true, true)
		await get_tree().process_frame
		if game == null or not game.debug_validate_tutorial_flow():
			errors.append("상황형 튜토리얼 흐름 오류: LEVEL %d" % (level_index + 1))
	start_level(3, true, true)
	await get_tree().process_frame
	if game == null or String(game.L.get("tutorial", "")) != "color_match":
		errors.append("LEVEL 4 색상 매칭 튜토리얼 누락")
	print("[tutorial validation] core=4 late=4 errors=", errors.size())
	for message in errors:
		push_error("[tutorial validation] " + message)
	_request_shutdown(0 if errors.is_empty() else 1)


func _headless_pause_test() -> void:
	start_level(109, true, true)
	await get_tree().create_timer(0.25).timeout
	var waiting := game != null and is_equal_approx(game.time_left, game.total_time) and is_zero_approx(game.elapsed_play_time)
	if game:
		waiting = game.debug_validate_touch_mapping() and waiting
		game.set_paused(true)
		game.set_paused(false)
	await get_tree().create_timer(0.12).timeout
	waiting = waiting and game != null and is_equal_approx(game.time_left, game.total_time)
	var moved := game != null and game.debug_validate_smooth_drag()
	await get_tree().create_timer(0.12).timeout
	var started := moved and game.time_left < game.total_time and game.elapsed_play_time > 0.0
	var before := game.time_left if game else -1.0
	if game:
		game.set_paused(true)
	await get_tree().create_timer(0.18).timeout
	var held := game != null and game.state == "paused" and absf(game.time_left - before) < 0.02 and game.hud.pause_overlay != null
	if game:
		game.set_paused(false)
	await get_tree().create_timer(0.12).timeout
	var resumed := game != null and game.state == "play" and game.time_left < before and game.hud.pause_overlay == null
	print("[pause validation] waiting_for_move=", waiting, " started_on_move=", started, " held=", held, " resumed=", resumed)
	_clear_screen()
	await get_tree().process_frame
	await get_tree().process_frame
	_request_shutdown(0 if waiting and started and held and resumed else 1)


func _memory_snapshot() -> Dictionary:
	return {
		"static": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
	}


func _headless_memory_stress_test() -> void:
	## 모든 챕터의 텍스처/스타일 캐시를 한 번 워밍업한 뒤 같은 레벨을 다시
	## 순회한다. Godot 메모리 할당자의 정상적인 고점 예약을 누수로 오판하지 않고,
	## 두 번째 순회에서도 계속 증가하는 객체만 검출한다.
	for i in range(Levels.level_count()):
		start_level(i % Levels.level_count(), true, true)
		await get_tree().process_frame
		await get_tree().process_frame
	_clear_screen()
	await get_tree().process_frame
	await get_tree().process_frame
	var baseline := _memory_snapshot()
	for i in range(Levels.level_count()):
		start_level(i % Levels.level_count(), true, true)
		await get_tree().process_frame
		await get_tree().process_frame
	# 한 프레임에 비정상적으로 많은 장식 효과를 요청해도 상한을 넘지 않고 모두 회수되는지 확인한다.
	for i in range(400):
		game.fx.ring(Vector2(120 + i % 8 * 40, 320 + i % 10 * 34), Color("#ff7fa0"), 0.6)
	var effect_peak := game.fx.get_child_count()
	await get_tree().create_timer(1.0).timeout
	await get_tree().process_frame
	var effect_remaining := game.fx.get_child_count()
	# 샤이니 젤리의 주기 반짝임이 동시에 1~2개 생성될 수 있으므로 스트레스 링만 회수됐는지 본다.
	var effects_drained := effect_remaining <= 4
	_clear_screen()
	for i in range(4):
		await get_tree().process_frame
	var final := _memory_snapshot()
	var node_growth := int(final.nodes) - int(baseline.nodes)
	var orphan_growth := int(final.orphans) - int(baseline.orphans)
	var resource_growth := int(final.resources) - int(baseline.resources)
	var memory_growth := int(final.static) - int(baseline.static)
	var effect_budget_valid := effect_peak <= FX.MAX_TRANSIENT_NODES and effects_drained
	var valid := node_growth <= 12 and orphan_growth <= 4 and resource_growth <= 18 and memory_growth <= 32 * 1024 * 1024 and effect_budget_valid
	print("[memory validation] baseline=", baseline, " final=", final, " growth={static:", memory_growth, ", nodes:", node_growth, ", orphans:", orphan_growth, ", resources:", resource_growth, "} effects={peak:", effect_peak, ", remaining:", effect_remaining, ", drained:", effects_drained, "} valid=", valid)
	_request_shutdown(0 if valid else 1)


func _request_shutdown(exit_code: int = 0) -> void:
	if _shutting_down:
		return
	_shutting_down = true
	# 검증 코루틴이 반환된 뒤 화면과 진행 중인 연출을 정리한다.
	_shutdown.call_deferred(exit_code)


func _run_autoplay_level(level_index: int) -> void:
	start_level(level_index, true, true)
	await get_tree().process_frame
	var passed := await game.debug_drive()
	_request_shutdown(0 if passed else 1)


func _validate_shutdown() -> void:
	start_level(0, true, true)
	await get_tree().create_timer(0.2).timeout
	await game.debug_capture_one()
	print("[shutdown validation] pending_absorptions=", game.active_absorptions)
	_request_shutdown()


func _shutdown(exit_code: int) -> void:
	get_tree().paused = false
	for child in get_children():
		child.queue_free()
	current_screen = null
	game = null
	audio = null
	music = null
	platform = null
	analytics = null
	await get_tree().process_frame
	# 오디오 스레드가 중지 요청과 재생 참조 해제를 처리할 시간을 보장한다.
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(exit_code)
