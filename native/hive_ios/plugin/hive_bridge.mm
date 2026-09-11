#include "hive_bridge.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <HIVECore/HIVECore-Swift.h>
#import <HIVEService/HIVEService-Swift.h>
#import <HiveAdiz/HiveAdiz-Swift.h>
#import <CommonCrypto/CommonDigest.h>

// Diagnostic listener persists the DataStore provisioning flags and key digest.
@interface JellyMonDataStoreConfigurationProbe : NSObject <LoggerListener>
@end
@implementation JellyMonDataStoreConfigurationProbe
- (void)inspectValue:(id)value {
	if ([value isKindOfClass:NSDictionary.class]) {
		NSDictionary *dict = value;
		if (dict[@"data_store"] || dict[@"data_store_key"]) {
			NSString *key = [dict[@"data_store_key"] isKindOfClass:NSString.class] ? dict[@"data_store_key"] : @"";
			NSData *bytes = [key dataUsingEncoding:NSUTF8StringEncoding];
			unsigned char digest[CC_SHA256_DIGEST_LENGTH];
			CC_SHA256(bytes.bytes, (CC_LONG)bytes.length, digest);
			NSMutableString *hash = [NSMutableString string];
			for (NSUInteger i = 0; i < sizeof(digest); i++) [hash appendFormat:@"%02x", digest[i]];
			NSDictionary *summary = @{@"data_store": [dict[@"data_store"] respondsToSelector:@selector(boolValue)] ? @([dict[@"data_store"] boolValue]) : NSNull.null,
				@"key_present": @(key.length > 0), @"key_length": @(key.length), @"key_sha256": hash};
			NSURL *directory = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
			[[NSJSONSerialization dataWithJSONObject:summary options:0 error:nil] writeToURL:[directory URLByAppendingPathComponent:@"hive_datastore_configuration.json"] atomically:YES];
			NSLog(@"[JellyMonDataStoreConfig] enabled=%@ key_present=%d key_length=%lu sha256=%@", summary[@"data_store"], key.length > 0, (unsigned long)key.length, hash);
		}
		for (id child in dict.allValues) [self inspectValue:child];
	} else if ([value isKindOfClass:NSArray.class]) {
		for (id child in value) [self inspectValue:child];
	}
}
- (void)onLogEvent:(enum HIVELogType)type tag:(NSString *)tag message:(NSString *)message {
	static dispatch_once_t once;
	dispatch_once(&once, ^{ NSLog(@"[JellyMonDataStoreConfig] SDK diagnostic listener active"); });
	if (![message containsString:@"data_store"]) return;
	NSMutableDictionary *fields = [NSMutableDictionary dictionary];
	for (NSString *name in @[@"data_store", @"data_store_key"]) {
		NSString *pattern = [NSString stringWithFormat:@"[\\\"]?%@[\\\"]?\\s*[:=]\\s*(\\\"[^\\\"]*\\\"|true|false|[0-9]+)", name];
		NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
		NSTextCheckingResult *match = [regex firstMatchInString:message options:0 range:NSMakeRange(0, message.length)];
		if (match) {
			NSString *raw = [message substringWithRange:[match rangeAtIndex:1]];
			id field = [NSJSONSerialization JSONObjectWithData:[raw dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingFragmentsAllowed error:nil];
			if (field) fields[name] = field;
		}
	}
	if (fields.count) { [self inspectValue:fields]; return; }
	NSRange start = [message rangeOfString:@"{"];
	NSRange end = [message rangeOfString:@"}" options:NSBackwardsSearch];
	if (start.location == NSNotFound || end.location == NSNotFound || end.location < start.location) return;
	NSString *json = [message substringWithRange:NSMakeRange(start.location, end.location - start.location + 1)];
	id value = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
	if (value) [self inspectValue:value];
}
@end

static NSString *const kSnapshotKey = @"jellymon_save_v1";
static NSString *const kAdventureKey = @"jellymon_adventure_v1";
static NSString *const kManualDisconnectKey = @"jellymon_manual_disconnect";

static String godot_string(NSString *value) {
	return value ? String::utf8(value.UTF8String) : String();
}

static NSString *ns_string(const String &value) {
	return [NSString stringWithUTF8String:value.utf8().get_data()];
}

static String result_message(HIVEResultAPI *result) {
	if (!result) {
		return "Hive 응답이 없습니다.";
	}
	NSString *message = [NSString stringWithFormat:@"%ld: %@", (long)[result getCode], [result getMessage]];
	return godot_string(message);
}

static UIViewController *root_view_controller() {
	UIWindow *window = UIApplication.sharedApplication.delegate.window;
	// Godot 4.7 uses SwiftUI scenes; the app delegate may not own a window.
	for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
		if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
		for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
			if (candidate.isKeyWindow && candidate.rootViewController) {
				window = candidate;
				break;
			}
		}
		if (window.isKeyWindow) break;
	}
	UIViewController *controller = window.rootViewController;
	while (controller.presentedViewController) {
		controller = controller.presentedViewController;
	}
	return controller;
}

@interface JellyMonAdizListener : NSObject <AdizListener>
@property(nonatomic, assign) HiveBridge *bridge;
@end

@implementation JellyMonAdizListener
- (void)onLoad { if (_bridge) _bridge->ad_loaded(); }
- (void)onFail:(AdizError *)error {
	NSString *message = [NSString stringWithFormat:@"%ld: %@", (long)[error getCode], [error getMessage] ?: @""];
	if (_bridge) _bridge->ad_failed(godot_string(message));
}
- (void)onShow { if (_bridge) _bridge->ad_shown(); }
- (void)onRewarded:(RewardItem *)rewardItem { if (_bridge) _bridge->ad_rewarded(); }
- (void)onClose { if (_bridge) _bridge->ad_closed(); }
@end

HiveBridge *HiveBridge::singleton = nullptr;

void HiveBridge::_bind_methods() {
	ClassDB::bind_method(D_METHOD("billingInitialize"), &HiveBridge::billing_initialize);
	ClassDB::bind_method(D_METHOD("billingPurchase", "sku", "payload"), &HiveBridge::billing_purchase);
	ClassDB::bind_method(D_METHOD("billingRestore"), &HiveBridge::billing_restore);
	ClassDB::bind_method(D_METHOD("billingFinish", "sku"), &HiveBridge::billing_finish);
	ADD_SIGNAL(MethodInfo("billing_event", PropertyInfo(Variant::STRING, "kind"), PropertyInfo(Variant::STRING, "json")));
	ClassDB::bind_method(D_METHOD("initialize", "test_ads", "sandbox"), &HiveBridge::initialize);
	ClassDB::bind_method(D_METHOD("login"), &HiveBridge::login);
	ClassDB::bind_method(D_METHOD("isGuestAccount"), &HiveBridge::is_guest_account);
	ClassDB::bind_method(D_METHOD("disconnectAccount", "confirmation", "allow_guest_delete"), &HiveBridge::disconnect_account);
	ClassDB::bind_method(D_METHOD("prepareRankingAuth", "request_id", "player_id"), &HiveBridge::prepare_ranking_auth);
	ClassDB::bind_method(D_METHOD("loadAdventureRecord", "request_id", "player_id"), &HiveBridge::load_adventure_record);
	ClassDB::bind_method(D_METHOD("saveAdventureRecord", "request_id", "player_id", "json"), &HiveBridge::save_adventure_record);
	ClassDB::bind_method(D_METHOD("loadGameSnapshot", "request_id", "player_id"), &HiveBridge::load_game_snapshot);
	ClassDB::bind_method(D_METHOD("saveGameSnapshot", "request_id", "player_id", "json"), &HiveBridge::save_game_snapshot);
	ClassDB::bind_method(D_METHOD("isRewardedAdReady"), &HiveBridge::is_rewarded_ad_ready);
	ClassDB::bind_method(D_METHOD("showRewardedAd"), &HiveBridge::show_rewarded_ad);
	ClassDB::bind_method(D_METHOD("reloadRewardedAd"), &HiveBridge::reload_rewarded_ad);

	ADD_SIGNAL(MethodInfo("hive_setup_completed", PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "message"), PropertyInfo(Variant::BOOL, "auto_sign_in")));
	ADD_SIGNAL(MethodInfo("hive_login_completed", PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "player_id"), PropertyInfo(Variant::STRING, "name"), PropertyInfo(Variant::STRING, "error")));
	ADD_SIGNAL(MethodInfo("rewarded_ad_state", PropertyInfo(Variant::STRING, "state"), PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo("rewarded_ad_completed", PropertyInfo(Variant::BOOL, "rewarded"), PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo("adventure_record_loaded", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "json"), PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo("adventure_record_saved", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo("game_snapshot_loaded", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "json"), PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo("game_snapshot_saved", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo("ranking_auth_ready", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "json")));
	ADD_SIGNAL(MethodInfo("account_disconnect_completed", PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "message")));
}

HiveBridge *HiveBridge::get_singleton() { return singleton; }

HiveBridge::HiveBridge() {
	singleton = this;
	ad_listener = (__bridge_retained void *)[JellyMonAdizListener new];
	((__bridge JellyMonAdizListener *)ad_listener).bridge = this;
}

HiveBridge::~HiveBridge() {
	if (rewarded_ad) {
		[(__bridge AdizRewarded *)rewarded_ad destroy];
		CFBridgingRelease(rewarded_ad);
	}
	((__bridge JellyMonAdizListener *)ad_listener).bridge = nullptr;
	CFBridgingRelease(ad_listener);
	ad_listener = nullptr;
	rewarded_ad = nullptr;
	if (singleton == this) singleton = nullptr;
}

void HiveBridge::initialize(bool p_test_ads, bool p_sandbox) {
	dispatch_async(dispatch_get_main_queue(), ^{
		[HIVEConfiguration setZone:p_sandbox ? HIVEZoneTypeSandbox : HIVEZoneTypeReal];
		[HIVEConfiguration setUseLog:p_sandbox];
#ifdef DEBUG_ENABLED
		JellyMonDataStoreConfigurationProbe *probe = p_sandbox ? [JellyMonDataStoreConfigurationProbe new] : nil;
		if (probe) {
			[Logger addListener:probe];
			[HIVELogger setLogFilter:[[HIVELogFilter alloc] initWithCoreLog:HIVELogTypeVerbose serviceLog:HIVELogTypeVerbose]];
			NSURL *directory = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
			[NSFileManager.defaultManager removeItemAtURL:[directory URLByAppendingPathComponent:@"hive_datastore_configuration.json"] error:nil];
		}
#endif
		[NSFileManager.defaultManager removeItemAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"hive_cloud_trace.log"] error:nil];
		// Hercules is optional and is not included in this target's Podfile.
		// The SDK defaults to enabled and aborts after setup unless explicitly disabled.
		[HIVEConfiguration setUseHercules:NO];
		NSURL *diagnostic_directory = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
		[NSFileManager.defaultManager removeItemAtURL:[diagnostic_directory URLByAppendingPathComponent:@"hive_setup_debug.log"] error:nil];
		[NSFileManager.defaultManager removeItemAtURL:[diagnostic_directory URLByAppendingPathComponent:@"hive_datastore_log_shape.txt"] error:nil];
		NSLog(@"[JellyMonHive] configuration appId=%@ market=%@ sandbox=%d", [HIVEConfiguration getAppId], [HIVEConfiguration getMarket], p_sandbox);
		[HIVEAuthV4 setup:^(HIVEResultAPI *result, BOOL is_auto_sign_in, NSString *did, NSArray<NSNumber *> *providers) {
#ifdef DEBUG_ENABLED
			if (probe) {
				[Logger removeListener:probe];
				[HIVELogger setLogFilter:[HIVELogFilter new]];
			}
#endif
			hive_ready = [result isSuccess];
			NSDictionary *diagnostics = @{@"success": @(hive_ready), @"code": @([result getCode]), @"message": [result getMessage] ?: @"", @"did_present": @(did.length > 0)};
			NSURL *directory = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
			NSData *diagnostic_data = [NSJSONSerialization dataWithJSONObject:diagnostics options:0 error:nil];
			[diagnostic_data writeToURL:[directory URLByAppendingPathComponent:@"hive_initialization_status.json"] atomically:YES];
			NSLog(@"[JellyMonHive] setup success=%d code=%ld did_present=%d", hive_ready, (long)[result getCode], did.length > 0);
			bool manually_disconnected = [NSUserDefaults.standardUserDefaults boolForKey:kManualDisconnectKey];
			auto_sign_in = is_auto_sign_in && !manually_disconnected;
			String message = hive_ready ? String("준비 완료 · iOS") : result_message(result);
			emit_signal("hive_setup_completed", hive_ready, message, auto_sign_in);
			if (hive_ready || p_test_ads) initialize_adiz(p_test_ads, p_sandbox);
		}];
	});
}

bool HiveBridge::login() {
	if (!hive_ready) {
		emit_signal("hive_login_completed", false, "", "", "HIVE SDK가 아직 준비되지 않았습니다.");
		return false;
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		[NSUserDefaults.standardUserDefaults setBool:NO forKey:kManualDisconnectKey];
		void (^handler)(HIVEResultAPI *, HIVEPlayerInfo *) = ^(HIVEResultAPI *result, HIVEPlayerInfo *info) {
			// Record the missing configuration key without logging login tokens or identity.
			NSString *missing_key = [result getCode] == HIVEResultAPICodeAuthV4ProviderMissingKey ? ([result getMessage] ?: @"") : @"";
			NSLog(@"[JellyMonHive] login success=%d code=%ld missing_key=%@", [result isSuccess], (long)[result getCode], missing_key);
			NSDictionary *diagnostics = @{@"success": @([result isSuccess]), @"code": @([result getCode]), @"missing_key": missing_key};
			NSURL *directory = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
			[[NSJSONSerialization dataWithJSONObject:diagnostics options:0 error:nil] writeToURL:[directory URLByAppendingPathComponent:@"hive_login_status.json"] atomically:YES];
			reset_billing();
			if ([result isSuccess] && info) {
				authenticated_player_id = String::num_int64(info.playerID);
				emit_signal("hive_login_completed", true, authenticated_player_id, godot_string(info.playerName), "");
			} else {
				authenticated_player_id = "";
				emit_signal("hive_login_completed", false, "", "", result_message(result));
			}
		};
		if (auto_sign_in) [HIVEAuthV4 signIn:HIVEProviderTypeAuto handler:handler];
		else [HIVEAuthV4 showSignIn:handler];
	});
	return true;
}

bool HiveBridge::is_guest_account() const {
	HIVEPlayerInfo *info = [HIVEAuthV4 getPlayerInfo];
	return info && info.providerInfoData.count == 0;
}

void HiveBridge::disconnect_account(const String &p_confirmation, bool p_allow_guest_delete) {
	if (p_confirmation != "DELETE ACCOUNT" || disconnecting) return;
	dispatch_async(dispatch_get_main_queue(), ^{
		HIVEPlayerInfo *info = [HIVEAuthV4 getPlayerInfo];
		if (!info || authenticated_player_id.is_empty()) {
			emit_signal("account_disconnect_completed", false, "Hive 로그인 상태를 확인해 주세요.");
			return;
		}
		bool guest = info.providerInfoData.count == 0;
		if (guest && !p_allow_guest_delete) {
			emit_signal("account_disconnect_completed", false, "Hive 게스트 계정은 일반 로그아웃을 지원하지 않습니다.");
			return;
		}
		reset_billing();
		disconnecting = true;
		void (^handler)(HIVEResultAPI *) = ^(HIVEResultAPI *result) {
			disconnecting = false;
			if ([result isSuccess]) {
				authenticated_player_id = "";
				auto_sign_in = false;
				[NSUserDefaults.standardUserDefaults setBool:YES forKey:kManualDisconnectKey];
			}
			emit_signal("account_disconnect_completed", [result isSuccess], [result isSuccess] ? String() : result_message(result));
		};
		if (guest) [HIVEAuthV4 playerDelete:handler];
		else [HIVEAuthV4 signOut:handler];
	});
}

void HiveBridge::prepare_ranking_auth(int64_t p_request_id, const String &p_player_id) {
	if (p_player_id.is_empty() || p_player_id != authenticated_player_id) {
		emit_signal("ranking_auth_ready", p_request_id, false, "");
		return;
	}
	[HIVEAuthV4 refreshAccessToken:^(HIVEResultAPI *result, NSString *access_token) {
		HIVEPlayerInfo *info = [HIVEAuthV4 getPlayerInfo];
		if (![result isSuccess] || !info || !access_token.length || String::num_int64(info.playerID) != authenticated_player_id) {
			emit_signal("ranking_auth_ready", p_request_id, false, "");
			return;
		}
		NSDictionary *credentials = @{ @"player_id": ns_string(authenticated_player_id), @"did": info.did ?: @"", @"player_token": info.playerToken ?: @"", @"access_token": access_token };
		NSData *data = [NSJSONSerialization dataWithJSONObject:credentials options:0 error:nil];
		emit_signal("ranking_auth_ready", p_request_id, true, godot_string([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]));
	}];
}

static bool valid_player(const String &requested, const String &authenticated) {
	return !requested.is_empty() && requested == authenticated;
}

static void log_datastore_result(NSString *operation, HIVEResultAPI *result) {
	// Persist result metadata only; never write cloud payloads or credentials to logs.
	NSLog(@"[JellyMonDataStore] operation=%@ success=%d code=%ld message=%@", operation, [result isSuccess], (long)[result getCode], [result getMessage]);
	NSDictionary *diagnostics = @{@"operation": operation, @"success": @([result isSuccess]), @"code": @([result getCode]), @"message": [result getMessage] ?: @""};
	NSURL *directory = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
	[[NSJSONSerialization dataWithJSONObject:diagnostics options:0 error:nil] writeToURL:[directory URLByAppendingPathComponent:@"hive_datastore_status.json"] atomically:YES];
}

void HiveBridge::load_adventure_record(int64_t p_request_id, const String &p_player_id) {
	if (!hive_ready || !valid_player(p_player_id, authenticated_player_id)) {
		emit_signal("adventure_record_loaded", p_request_id, false, "", "Hive 로그인이 필요합니다."); return;
	}
	// Own the caller's String before the asynchronous block outlives the Godot call.
	const String requested_player = p_player_id;
	[HIVEDataStore get:kAdventureKey handler:^(HIVEResultAPI *result, NSString *data) {
		log_datastore_result(@"load_adventure", result);
		bool missing = [result getCode] == HIVEResultAPICodeDataStoreNotExistKey;
		bool success = ([result isSuccess] || missing) && valid_player(requested_player, authenticated_player_id);
		emit_signal("adventure_record_loaded", p_request_id, success, success && !missing ? godot_string(data) : String(), success ? String() : result_message(result));
	}];
}

void HiveBridge::save_adventure_record(int64_t p_request_id, const String &p_player_id, const String &p_json) {
	if (!hive_ready || !valid_player(p_player_id, authenticated_player_id)) {
		emit_signal("adventure_record_saved", p_request_id, false, "Hive 로그인이 필요합니다."); return;
	}
	const String requested_player = p_player_id;
	[HIVEDataStore set:kAdventureKey value:ns_string(p_json) handler:^(HIVEResultAPI *result) {
		log_datastore_result(@"save_adventure", result);
		bool success = [result isSuccess] && valid_player(requested_player, authenticated_player_id);
		emit_signal("adventure_record_saved", p_request_id, success, success ? String() : result_message(result));
	}];
}

void HiveBridge::load_game_snapshot(int64_t p_request_id, const String &p_player_id) {
	if (!hive_ready || !valid_player(p_player_id, authenticated_player_id)) {
		emit_signal("game_snapshot_loaded", p_request_id, false, "", "Hive 로그인이 필요합니다."); return;
	}
	// Own the caller's String before the asynchronous block outlives the Godot call.
	const String requested_player = p_player_id;
	[HIVEDataStore get:kSnapshotKey handler:^(HIVEResultAPI *result, NSString *data) {
		log_datastore_result(@"load_snapshot", result);
		// Only an explicit missing-key result means a new save. Server failures stay failures.
		bool missing = [result getCode] == HIVEResultAPICodeDataStoreNotExistKey;
		bool success = ([result isSuccess] || missing) && valid_player(requested_player, authenticated_player_id);
		emit_signal("game_snapshot_loaded", p_request_id, success, success && !missing ? godot_string(data) : String(), success ? String() : result_message(result));
	}];
}

void HiveBridge::save_game_snapshot(int64_t p_request_id, const String &p_player_id, const String &p_json) {
	if (!hive_ready || !valid_player(p_player_id, authenticated_player_id)) {
		emit_signal("game_snapshot_saved", p_request_id, false, "Hive 로그인이 필요합니다."); return;
	}
	const String requested_player = p_player_id;
	[HIVEDataStore set:kSnapshotKey value:ns_string(p_json) handler:^(HIVEResultAPI *result) {
		log_datastore_result(@"save_snapshot", result);
		bool success = [result isSuccess] && valid_player(requested_player, authenticated_player_id);
		emit_signal("game_snapshot_saved", p_request_id, success, success ? String() : result_message(result));
	}];
}

void HiveBridge::initialize_adiz(bool p_test_ads, bool p_sandbox) {
	UIViewController *controller = root_view_controller();
	NSLog(@"[JellyMonAdiz] initialize controller=%@ delegate_window=%d test=%d sandbox=%d", controller ? NSStringFromClass(controller.class) : @"missing", UIApplication.sharedApplication.delegate.window != nil, p_test_ads, p_sandbox);
	if (!controller) { emit_ad_state("failed", "iOS 화면 컨트롤러를 찾을 수 없습니다."); return; }
	emit_ad_state("loading", "광고 서비스 초기화 중");
	[Adiz setTestMode:p_test_ads];
	[Adiz setLogEnable:p_test_ads];
	[Adiz setZone:p_sandbox ? AdizZoneTypeSandbox : AdizZoneTypeReal];
	[Adiz initialize:controller handler:^(AdizError *error, NSDictionary<NSString *, id> *data) {
		adiz_ready = error.isSuccess;
		NSLog(@"[JellyMonAdiz] initialized success=%d code=%ld message=%@", adiz_ready, (long)[error getCode], [error getMessage]);
		if (!adiz_ready) {
			NSString *message = [NSString stringWithFormat:@"%ld: %@", (long)[error getCode], [error getMessage] ?: @""];
			emit_ad_state("failed", godot_string(message));
			return;
		}
		create_rewarded_ad();
	}];
}

void HiveBridge::create_rewarded_ad() {
	UIViewController *controller = root_view_controller();
	if (!controller) { emit_ad_state("failed", "iOS 화면 컨트롤러를 찾을 수 없습니다."); return; }
	rewarded_ad = (__bridge_retained void *)[AdizRewarded initialize:controller adizListener:(__bridge JellyMonAdizListener *)ad_listener];
	emit_ad_state("loading", "");
	[(__bridge AdizRewarded *)rewarded_ad load];
}

void HiveBridge::emit_ad_state(const String &p_state, const String &p_message) {
	NSLog(@"[JellyMonAdiz] state=%@ message=%@", ns_string(p_state), ns_string(p_message));
	emit_signal("rewarded_ad_state", p_state, p_message);
}
bool HiveBridge::is_rewarded_ad_ready() const { return adiz_ready && rewarded_ad && [(__bridge AdizRewarded *)rewarded_ad isLoaded]; }

bool HiveBridge::show_rewarded_ad() {
	if (pending_ad_show) return false;
	if (!is_rewarded_ad_ready()) {
		emit_signal("rewarded_ad_completed", false, "광고를 준비 중입니다. 잠시 후 다시 시도해 주세요.");
		reload_rewarded_ad(); return false;
	}
	pending_ad_show = true;
	reward_granted = false;
	[(__bridge AdizRewarded *)rewarded_ad show];
	return true;
}

void HiveBridge::reload_rewarded_ad() { if (adiz_ready && rewarded_ad) { emit_ad_state("loading", ""); [(__bridge AdizRewarded *)rewarded_ad load]; } }
void HiveBridge::ad_loaded() { emit_ad_state("ready", ""); }
void HiveBridge::ad_failed(const String &p_message) { bool requested = pending_ad_show; pending_ad_show = false; reward_granted = false; emit_ad_state("failed", p_message); if (requested) emit_signal("rewarded_ad_completed", false, p_message); }
void HiveBridge::ad_shown() { emit_ad_state("showing", ""); }
void HiveBridge::ad_rewarded() { if (pending_ad_show) reward_granted = true; }
void HiveBridge::ad_closed() { if (!pending_ad_show) return; bool granted = reward_granted; pending_ad_show = false; reward_granted = false; emit_signal("rewarded_ad_completed", granted, granted ? String() : String("광고 시청이 완료되지 않았습니다.")); reload_rewarded_ad(); }
