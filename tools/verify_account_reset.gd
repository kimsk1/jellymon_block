extends Node
var confirmed_count := 0

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var dialog := preload("res://scripts/AccountResetDialog.gd").new()
	dialog.scope_text = "초기화 대상 데이터는 복구할 수 없습니다."
	get_tree().root.theme = ArtDirection.ui_theme()
	add_child(dialog)
	dialog.confirmed.connect(func(): confirmed_count += 1)
	for invalid in ["", "delete account", "DELETE", "DELETEACCOUNT", " DELETE ACCOUNT", "DELETE ACCOUNT ", "DELETE  ACCOUNT"]:
		dialog.input.text = invalid
		dialog.input.text_changed.emit(invalid)
		assert(dialog.confirm_button.disabled)
		dialog._confirm()
		assert(confirmed_count == 0)
	dialog.input.text = "DELETE ACCOUNT"
	dialog.input.text_changed.emit(dialog.input.text)
	assert(not dialog.confirm_button.disabled)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/account-reset/confirmation.png")
	dialog._confirm()
	dialog._confirm()
	assert(confirmed_count == 1, "Must reject double submission")
	assert(dialog.confirm_button.disabled)
	dialog.show_error("저장 실패 시 다시 시도할 수 있습니다.")
	assert(not dialog.confirm_button.disabled)
	print("[account-reset] exact phrase, invalid input, action guard and double-submit checks passed")
	get_tree().quit()
