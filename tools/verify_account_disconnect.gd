extends Node
class FakeBridge extends Node:
	var calls := 0
	var allow_delete := false
	func has_java_method(method: String) -> bool:
		return method in ["disconnectAccount", "isGuestAccount"]
	func isGuestAccount() -> bool: return true
	func disconnectAccount(_confirmation: String, allow_guest_delete: bool) -> void:
		calls += 1
		allow_delete = allow_guest_delete

func _ready() -> void:
	var service := PlatformService.new()
	var bridge := FakeBridge.new()
	add_child(service)
	add_child(bridge)
	service._native_bridge = bridge
	service.native_available = true
	service.native_ready = true
	service.logged_in = true
	service.player_id = "test-account"
	service.player_name = "테스트"
	assert(service.is_guest_account())
	for phrase in ["", "delete account", "DELETE ACCOUNT ", " DELETE ACCOUNT"]:
		assert(not service.disconnect_account(phrase, true))
	assert(bridge.calls == 0)
	assert(service.disconnect_account("DELETE ACCOUNT", true))
	assert(service.account_disconnect_pending)
	assert(service.logged_in) # SDK has not confirmed yet.
	assert(not service.disconnect_account("DELETE ACCOUNT", true))
	assert(bridge.calls == 1 and bridge.allow_delete)
	service._on_account_disconnected(false, "offline")
	assert(service.logged_in and service.player_id == "test-account")
	assert(not service.account_disconnect_pending)
	assert(service.disconnect_account("DELETE ACCOUNT", false))
	assert(not bridge.allow_delete)
	service._on_account_disconnected(true, "")
	assert(not service.logged_in and service.player_id.is_empty() and service.player_name.is_empty())
	assert(not service.account_disconnect_pending and service.native_ready)
	assert(service.status_text() == "HIVE 계정 연결 대기")
	print("[disconnect] exact phrase, duplicate guard, failure preservation, guest mode and confirmed logout PASSED")
	get_tree().quit()
