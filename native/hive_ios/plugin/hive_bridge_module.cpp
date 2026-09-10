#include "hive_bridge_module.h"

#include "core/config/engine.h"
#include "hive_bridge.h"

static HiveBridge *hive_bridge = nullptr;

void register_hive_bridge_types() {
	hive_bridge = memnew(HiveBridge);
	Engine::get_singleton()->add_singleton(Engine::Singleton("HiveBridge", hive_bridge));
}

void unregister_hive_bridge_types() {
	if (hive_bridge) {
		Engine::get_singleton()->remove_singleton("HiveBridge");
		memdelete(hive_bridge);
		hive_bridge = nullptr;
	}
}
