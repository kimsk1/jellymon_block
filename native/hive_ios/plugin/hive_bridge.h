#ifndef JELLYMON_HIVE_BRIDGE_H
#define JELLYMON_HIVE_BRIDGE_H

#include "core/object/class_db.h"

class HiveBridge : public Object {
	GDCLASS(HiveBridge, Object);

	static HiveBridge *singleton;
	static void _bind_methods();

	bool hive_ready = false;
	bool auto_sign_in = false;
	bool disconnecting = false;
	bool adiz_ready = false;
	bool pending_ad_show = false;
	bool reward_granted = false;
	String authenticated_player_id;
	void *ad_listener = nullptr;
	void *rewarded_ad = nullptr;

	void initialize_adiz(bool p_test_ads, bool p_sandbox);
	void create_rewarded_ad();
	void emit_ad_state(const String &p_state, const String &p_message);

public:
	static HiveBridge *get_singleton();

	void initialize(bool p_test_ads, bool p_sandbox);
	bool login();
	bool is_guest_account() const;
	void disconnect_account(const String &p_confirmation, bool p_allow_guest_delete);
	void prepare_ranking_auth(int64_t p_request_id, const String &p_player_id);
	void load_adventure_record(int64_t p_request_id, const String &p_player_id);
	void save_adventure_record(int64_t p_request_id, const String &p_player_id, const String &p_json);
	void load_game_snapshot(int64_t p_request_id, const String &p_player_id);
	void save_game_snapshot(int64_t p_request_id, const String &p_player_id, const String &p_json);
	bool is_rewarded_ad_ready() const;
	bool show_rewarded_ad();
	void reload_rewarded_ad();

	void ad_loaded();
	void ad_failed(const String &p_message);
	void ad_shown();
	void ad_rewarded();
	void ad_closed();

	HiveBridge();
	~HiveBridge();
};

#endif
