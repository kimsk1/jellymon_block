extends Node
class FixtureMain extends "res://scripts/Main.gd":
	func _ready() -> void: pass
class FakeBridge extends Node:
	var service: PlatformService
	var calls := 0
	var succeeds := false
	func has_java_method(method: String) -> bool: return method in ["disconnectAccount", "isGuestAccount"]
	func isGuestAccount() -> bool: return true
	func disconnectAccount(phrase: String, guest_delete: bool) -> void:
		assert(phrase == "DELETE ACCOUNT" and guest_delete)
		calls += 1
		service._on_account_disconnected.call_deferred(succeeds, "test failure" if not succeeds else "")

func _ready() -> void: call_deferred("run")
func run() -> void:
	var main := FixtureMain.new()
	main.save.persistence_enabled = false
	main.save.storage_path = "/tmp/jellymon-disconnect-ui-save.json"
	add_child(main)
	main._initialize_runtime()
	main.analytics.persistence_enabled = false
	main.save.nickname = "BeforeReset"
	main.save.stars = {"39": 3}
	main.save.best_clear_times = {"39": 12.5}
	main.save.three_star_first_at_ms = {"39": 123456789}
	main.save.stardust = 123
	main.save.room_theme_id = "d"
	main.save.sound_enabled = false
	main.save.hive_record_owner = "test-only"
	main.save.claimed_mail_ids = ["welcome"]
	main.save.booster_inventory = {"time": 99}
	var old_save := main.save
	var bridge := FakeBridge.new()
	add_child(bridge)
	bridge.service = main.platform
	main.platform._native_bridge = bridge
	main.platform.native_available = true
	main.platform.native_ready = true
	main.platform.logged_in = true
	main.platform.player_id = "test-only"
	var home: Title = main.current_screen
	home._show_home_menu()
	await get_tree().process_frame
	var button := home.menu_popup.find_child("AccountConnectionButton", true, false) as Button
	assert(button.text == "연결 해제" and not button.disabled)
	button.pressed.emit()
	var dialog := home.ui_layer.get_node("AccountDisconnectDialog")
	assert(dialog.scope_text.contains("게스트 Hive 계정을 삭제"))
	assert(dialog.scope_text.contains("모두 초기화"))
	assert(dialog.confirm_button.disabled)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://output/account-disconnect/guest-confirmation.png")
	dialog.input.text = "DELETE ACCOUNT "
	dialog.input.text_changed.emit(dialog.input.text)
	dialog._confirm()
	assert(bridge.calls == 0)
	dialog.input.text = "DELETE ACCOUNT"
	dialog.input.text_changed.emit(dialog.input.text)
	dialog._confirm()
	await get_tree().process_frame
	await get_tree().process_frame
	assert(bridge.calls == 1)
	assert(main.save == old_save and main.save.stardust == 123)
	assert(main.platform.logged_in and not dialog.busy)
	bridge.succeeds = true
	dialog._confirm()
	await get_tree().process_frame
	await get_tree().process_frame
	assert(bridge.calls == 2 and main.save != old_save)
	assert(not old_save.persistence_enabled)
	assert(main.save.stars.is_empty() and main.save.best_clear_times.is_empty())
	assert(main.save.three_star_first_at_ms.is_empty() and main.save.hive_record_owner.is_empty())
	assert(main.save.nickname.is_empty() and main.save.stardust == 0)
	assert(main.save.room_theme_id == RoomData.DEFAULT_ROOM_THEME and main.save.sound_enabled)
	assert(main.save.claimed_mail_ids.is_empty() and main.save.booster_inventory.time == 2)
	assert(main.ranking.save == main.save and main.adventure_cloud.save == main.save)
	# Persist and reload only the isolated fixture file to verify reset survives restart.
	main.save.persistence_enabled = true
	main.save.save_data()
	main.save.persistence_enabled = false
	var reloaded := SaveGame.new()
	reloaded.storage_path = main.save.storage_path
	reloaded.load_data()
	assert(reloaded.nickname.is_empty() and reloaded.stars.is_empty() and reloaded.stardust == 0)
	DirAccess.remove_absolute(main.save.storage_path)
	home = main.current_screen
	home._show_home_menu()
	await get_tree().process_frame
	button = home.menu_popup.find_child("AccountConnectionButton", true, false) as Button
	assert(button.text == "계정 연결" and not button.disabled)
	print("[disconnect UI] failure preservation, local reset, service references, reload and disconnected button PASSED")
	main._request_shutdown()
