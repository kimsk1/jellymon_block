#include "hive_bridge.h"
#import <Foundation/Foundation.h>
#import <HIVEService/HIVEService-Swift.h>

// All SDK callbacks re-enter on the main queue. ObjectID + generation protects
// against destruction, account changes, timeout, and callbacks from older calls.
static void on_billing(ObjectID id, uint64_t generation, String owner, void (^work)(HiveBridge *)) {
	dispatch_async(dispatch_get_main_queue(), ^{
		auto *bridge = Object::cast_to<HiveBridge>(ObjectDB::get_instance(id));
		if (bridge && bridge->billing_matches(generation, owner)) work(bridge);
	});
}
static NSString *native_string(const String &value) {
	return [NSString stringWithUTF8String:value.utf8().get_data()];
}
static void send_billing(HiveBridge *bridge, const String &owner, const String &kind, NSDictionary *data) {
	NSMutableDictionary *body = [data mutableCopy];
	body[@"player_id"] = native_string(owner);
	NSData *json = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
	NSString *text = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
	bridge->billing_result(kind, String::utf8(text.UTF8String));
}
static void fail_billing(HiveBridge *bridge, const String &owner, HIVEResultAPI *result) {
	// Never log result descriptions, receipt objects, bypassInfo or authentication tokens.
	send_billing(bridge, owner, "error", @{
		@"message": @"App Store 구매가 취소되었거나 처리 중입니다. 잠시 후 구매 복원을 눌러 주세요.",
		@"code": result ? [NSString stringWithFormat:@"%ld", (long)[result getCode]] : @"missing_receipt"
	});
}
static NSDictionary *receipt_data(HIVEIAPV4Receipt *receipt) {
	if (!receipt.product.marketPid.length || !receipt.bypassInfo.length) return nil;
	return @{@"sku": receipt.product.marketPid, @"receipt": receipt.bypassInfo};
}

void HiveBridge::reset_billing() {
	billing_generation++;
	billing_busy = false;
	billing_connected = false;
}
bool HiveBridge::billing_matches(uint64_t generation, const String &owner) const {
	return generation == billing_generation && !disconnecting && !owner.is_empty() && owner == authenticated_player_id;
}
void HiveBridge::billing_result(const String &kind, const String &json) {
	billing_busy = false;
	emit_signal("billing_event", kind, json);
}
uint64_t HiveBridge::begin_billing() {
	if (!hive_ready || disconnecting || authenticated_player_id.is_empty() || billing_busy) return 0;
	billing_busy = true;
	const uint64_t generation = ++billing_generation;
	const ObjectID id = get_instance_id();
	const String owner = authenticated_player_id;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 175 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		auto *bridge = Object::cast_to<HiveBridge>(ObjectDB::get_instance(id));
		if (!bridge || !bridge->billing_matches(generation, owner) || !bridge->billing_busy) return;
		bridge->billing_generation++;
		send_billing(bridge, owner, "error", @{@"message": @"App Store 응답 대기 시간이 지났습니다. 구매 복원으로 다시 확인해 주세요.", @"code": @"timeout"});
	});
	return generation;
}
void HiveBridge::billing_initialize() {
	const uint64_t generation = begin_billing();
	if (!generation) return;
	billing_connected = false;
	const ObjectID id = get_instance_id();
	const String owner = authenticated_player_id;
	on_billing(id, generation, owner, ^(HiveBridge *) {
		[HIVEIAPV4 marketConnect:^(HIVEResultAPI *result, NSArray<NSNumber *> *markets) {
			on_billing(id, generation, owner, ^(HiveBridge *bridge) {
				if (![result isSuccess] || ![markets containsObject:@(HIVEIAPV4TypeAppStore)]) { fail_billing(bridge, owner, result); return; }
				[HIVEIAPV4 setMarketSelectionWithType:HIVEIAPV4TypeAppStore];
				[HIVEIAPV4 getProductInfo:^(HIVEResultAPI *product_result, NSArray<HIVEIAPV4Product *> *products, NSUInteger balance) {
					on_billing(id, generation, owner, ^(HiveBridge *current) {
						if (![product_result isSuccess]) { fail_billing(current, owner, product_result); return; }
						NSMutableArray *items = [NSMutableArray array];
						for (HIVEIAPV4Product *product in products) {
							if (product.marketPid.length && product.displayPrice.length)
								[items addObject:@{@"sku": product.marketPid, @"price": product.displayPrice}];
						}
						current->billing_connected = true;
						send_billing(current, owner, "products", @{@"products": items});
					});
				}];
			});
		}];
	});
}
void HiveBridge::billing_purchase(const String &p_sku, const String &p_payload) {
	const String sku = p_sku;
	const String payload = p_payload;
	if (!billing_connected || sku.is_empty() || payload.is_empty()) return;
	const uint64_t generation = begin_billing();
	if (!generation) return;
	const ObjectID id = get_instance_id();
	const String owner = authenticated_player_id;
	on_billing(id, generation, owner, ^(HiveBridge *) {
		[HIVEIAPV4 setMarketSelectionWithType:HIVEIAPV4TypeAppStore];
		[HIVEIAPV4 purchase:native_string(sku) iapPayload:native_string(payload) handler:^(HIVEResultAPI *result, HIVEIAPV4Receipt *receipt) {
			on_billing(id, generation, owner, ^(HiveBridge *bridge) {
				NSDictionary *entry = receipt_data(receipt);
				if (![result isSuccess] || !entry) { fail_billing(bridge, owner, result); return; }
				send_billing(bridge, owner, "receipts", @{@"receipts": @[entry]});
			});
		}];
	});
}
void HiveBridge::billing_restore() {
	if (!billing_connected) return;
	const uint64_t generation = begin_billing();
	if (!generation) return;
	const ObjectID id = get_instance_id();
	const String owner = authenticated_player_id;
	on_billing(id, generation, owner, ^(HiveBridge *) {
		[HIVEIAPV4 setMarketSelectionWithType:HIVEIAPV4TypeAppStore];
		[HIVEIAPV4 restore:^(HIVEResultAPI *result, NSArray<HIVEIAPV4Receipt *> *receipts) {
			on_billing(id, generation, owner, ^(HiveBridge *bridge) {
				if (![result isSuccess]) { fail_billing(bridge, owner, result); return; }
				NSMutableArray *items = [NSMutableArray array];
				for (HIVEIAPV4Receipt *receipt in receipts) {
					NSDictionary *entry = receipt_data(receipt);
					if (!entry) { fail_billing(bridge, owner, nil); return; }
					[items addObject:entry];
				}
				send_billing(bridge, owner, "receipts", @{@"receipts": items});
			});
		}];
	});
}
void HiveBridge::billing_finish(const String &p_sku) {
	const String sku = p_sku;
	if (!billing_connected || sku.is_empty()) return;
	const uint64_t generation = begin_billing();
	if (!generation) return;
	const ObjectID id = get_instance_id();
	const String owner = authenticated_player_id;
	on_billing(id, generation, owner, ^(HiveBridge *) {
		[HIVEIAPV4 transactionFinish:native_string(sku) handler:^(HIVEResultAPI *result, NSString *market_pid) {
			on_billing(id, generation, owner, ^(HiveBridge *bridge) {
				if (![result isSuccess] || ![market_pid isEqualToString:native_string(sku)]) { fail_billing(bridge, owner, result); return; }
				send_billing(bridge, owner, "finished", @{@"sku": market_pid});
			});
		}];
	});
}
