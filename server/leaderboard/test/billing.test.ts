import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Billing, loadProducts, receiptVerifier, type BillingConfig } from '../src/billing.js';
const config: BillingConfig = { enabled: true, appId: 'com.jellymon.game', zone: 'sandbox', key: '', allowReal: false };
const products = loadProducts();
const data = { app_id: config.appId, install_id: 'a'.repeat(32), sku: products[0].android_product_id };
function fixture(path = ':memory:') {
  const db = new DatabaseSync(path);
  let response: Record<string, unknown> = {};
  const service = new Billing(db, config, products, async () => response);
  return { db, service, set: (r: Record<string, unknown>) => { response = r; } };
}
function verified(payload: string, tx = 'GO_test', sku = data.sku) {
  return { result: 0, hiveiap_market_id: 2, hiveiap_purchase_cancel_state: 0, hiveiap_account_uuid_compare: 1,
    hiveiap_purchase_test: 'Y', hiveiap_quantity: 1, hiveiap_market_pid: sku, hiveiap_transaction_id: tx,
    hiveiap_receipt: { purchase_data: { packageName: config.appId } }, hiveiap_iap_payload: payload };
}
test('deployment product catalog exactly matches the game catalog', () => {
  const canonical = JSON.parse(readFileSync(new URL('../../../../assets/data/item.json', import.meta.url), 'utf8'));
  assert.deepEqual(products, canonical.items);
  assert.equal(products.length, 8);
});
test('verified grant is durable, retries use one transaction, only originating install can ACK', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'jelly-iap-')), path = join(dir, 'billing.db');
  let f = fixture(path);
  try {
    const order: any = await f.service.handle('order', '10', data);
    f.set(verified(order.payload));
    const request = { ...data, receipt: 'opaque' };
    const grant: any = await f.service.handle('verify', '10', request);
    assert.equal(grant.delivered, false); assert.equal(grant.item.amount, 50);
    assert.deepEqual(await f.service.handle('verify', '10', request), grant);
    await assert.rejects(f.service.handle('verify', '20', request));
    await assert.rejects(f.service.handle('verify', '10', { ...request, install_id: 'b'.repeat(32) }));
    await assert.rejects(f.service.handle('ack', '10', { ...data, transaction_id: grant.transaction_id, install_id: 'b'.repeat(32) }));
    f.db.close(); f = fixture(path); f.set(verified(order.payload));
    assert.deepEqual(await f.service.handle('verify', '10', request), grant);
    await f.service.handle('ack', '10', { ...data, transaction_id: grant.transaction_id });
    const replay: any = await f.service.handle('verify', '10', { ...request, install_id: 'b'.repeat(32) });
    assert.equal(replay.delivered, true);
    assert.equal(f.db.prepare('SELECT count(*) n FROM iap_grants').get()!.n, 1);
  } finally { f.db.close(); rmSync(dir, { recursive: true }); }
});
test('invalid, refunded, foreign app, account, real payment and multi-quantity receipts never grant', async () => {
  const f = fixture();
  try {
    const order: any = await f.service.handle('order', '10', data);
    for (const invalid of [{ result: 1 }, { hiveiap_purchase_cancel_state: 1 }, { hiveiap_account_uuid_compare: 0 },
      { hiveiap_market_id: 1 }, { hiveiap_purchase_test: 'N' }, { hiveiap_quantity: 2 }, { hiveiap_market_pid: 'another.sku' },
      { hiveiap_iap_payload: '{}' }, { hiveiap_receipt: { purchase_data: { packageName: 'another.app' } } }]) {
      f.set({ ...verified(order.payload), ...invalid });
      await assert.rejects(f.service.handle('verify', '10', { ...data, receipt: 'opaque' }));
      assert.equal(f.db.prepare('SELECT count(*) n FROM iap_grants').get()!.n, 0);
    }
  } finally { f.db.close(); }
});
test('one-time ownership restores without a new currency grant; other account gets no entitlement', async () => {
  const f = fixture(), once = { ...data, sku: products[4].android_product_id };
  try {
    const order: any = await f.service.handle('order', '10', once);
    f.set(verified(order.payload, 'GO_pack', once.sku));
    await f.service.handle('verify', '10', { ...once, receipt: 'opaque' });
    await assert.rejects(f.service.handle('order', '10', once));
    assert.deepEqual(await f.service.handle('entitlements', '10', data), { entitlements: [] });
    await f.service.handle('ack', '10', { ...data, transaction_id: 'GO_pack' });
    const restored: any = await f.service.handle('entitlements', '10', data);
    assert.equal(restored.entitlements[0].item.id, 'starter_rescue_pack');
    assert.deepEqual(await f.service.handle('entitlements', '20', data), { entitlements: [] });
  } finally { f.db.close(); }
});
test('purchase payload cannot be reused for a second transaction', async () => {
  const f = fixture();
  try {
    const order: any = await f.service.handle('order', '10', data);
    f.set(verified(order.payload, 'GO_one')); await f.service.handle('verify', '10', { ...data, receipt: 'one' });
    f.set(verified(order.payload, 'GO_two')); await assert.rejects(f.service.handle('verify', '10', { ...data, receipt: 'two' }));
  } finally { f.db.close(); }
});
test('disabled billing and incorrect App ID fail before creating an order', async () => {
  const db = new DatabaseSync(':memory:');
  try {
    const disabled = new Billing(db, { ...config, enabled: false }, products, async () => ({}));
    await assert.rejects(disabled.handle('order', '10', data));
    const service = new Billing(db, config, products, async () => ({}));
    await assert.rejects(service.handle('order', '10', { ...data, app_id: 'wrong.app' }));
    await assert.rejects(service.handle('order', '10', { ...data, sku: 'invalid' }));
    assert.equal(db.prepare('SELECT count(*) n FROM iap_orders').get()!.n, 0);
  } finally { db.close(); }
});
test('verification sends original opaque receipt only to configured Hive endpoint, rejects redirects', async () => {
  const verify = receiptVerifier(config, (async (url, options) => {
    assert.equal(url, 'https://sandbox-hiveiap-verify.qpyou.cn/api_v4/verify');
    assert.equal(options!.redirect, 'error');
    const payload = JSON.parse(String(options!.body));
    assert.equal(payload.purchase_bypass_info, 'opaque-not-decoded'); assert.equal(payload.game_info.server_uid, '10');
    return new Response(JSON.stringify({ result: 0 }));
  }) as typeof fetch);
  assert.deepEqual(await verify('opaque-not-decoded', '10'), { result: 0 });
});
