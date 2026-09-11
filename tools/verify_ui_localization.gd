extends Node
const L10n = preload("res://scripts/LocalizedText.gd")
const CloudDialog = preload("res://scripts/CloudSaveDialog.gd")
class Fixture extends "res://scripts/Main.gd":
	func _ready() -> void: pass
var errors: Array[String] = []
var selections: Array[bool] = []
func _ready() -> void: call_deferred("run")
func scan(node: Node) -> void:
	if node is Label or node is Button or node is RichTextLabel:
		var raw := String(node.text)
		var translated := String(node.tr(raw))
		if L10n._has_korean(translated) and translated != "한국어":
			var entry := str(node.get_path()) + ": " + translated
			if not errors.has(entry): errors.append(entry)
	for child in node.get_children(): scan(child)
func buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button: result.append(node)
	for child in node.get_children(): result.append_array(buttons(child))
	return result
func run() -> void:
	var main := Fixture.new()
	main.save.persistence_enabled = false
	get_tree().root.add_child(main)
	main._initialize_runtime()
	main.save.nickname = "Tester"
	for chapter in range(6): main.save.register_rescued_jelly(chapter * 10)
	main.save.add_album_memory("pose", "모두 함께 기념사진 포즈!", [])
	for i in range(100): main.save.stars[i] = 3
	for locale in ["en", "ja", "zh_CN", "zh_TW", "fr", "de", "es"]:
		get_tree().root.get_node("Localization").apply_language(locale)
		for choice in range(3):
			var dialog := CloudDialog.new()
			dialog.local_data = {"nickname": "Local", "stars": {}, "stardust": 10}
			dialog.remote_data = {"nickname": "Cloud", "stars": {}, "stardust": 20}
			dialog.selected.connect(func(use_cloud: bool): selections.append(use_cloud))
			add_child(dialog)
			scan(dialog)
			var before := selections.size()
			buttons(dialog)[choice].pressed.emit()
			if choice == 2:
				if selections.size() != before: errors.append("Cancel selected save data")
			elif selections.size() != before + 1 or selections.back() != (choice == 0):
				errors.append("Translated save button selected the wrong data")
			await get_tree().process_frame
		for method in ["", "_show_room_themes", "_show_home_menu", "_show_attendance_popup", "_show_daily_mission_popup", "_show_lifestyle_popup", "_show_shop_popup", "_show_jelly_dex", "_show_album", "_show_nickname_popup", "_show_beta_feedback_popup", "_show_account_disconnect"]:
			main.show_title()
			await get_tree().process_frame
			if method != "": main.current_screen.call(method)
			await get_tree().process_frame
			scan(main.current_screen)
		main.show_map()
		await get_tree().process_frame
		scan(main.current_screen)
		main.show_ranking()
		await get_tree().process_frame
		scan(main.current_screen)
		for index in [0, 49, 109, 160, 999]:
			main.start_level(index,true,true)
			await get_tree().process_frame
			scan(main.game)
	# Player-entered names must never be translated, even when they match a UI key.
	main.save.nickname = "가구"
	main.show_title()
	await get_tree().process_frame
	if main.current_screen.header_name_label.text != "가구": errors.append("Player nickname was translated")
	if not L10n._has_korean(Levels.get_level(999).name): errors.append("Source level metadata was modified")
	for error in errors: print("UNTRANSLATED ", error)
	print("[ui locale coverage] failures=",errors.size())
	main._request_shutdown(0 if errors.is_empty() else 1)
