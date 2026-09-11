import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import type { DatabaseSync } from 'node:sqlite';
import { APIError, object } from './ranking.js';

export type Product = Record<string, unknown> & { id: string; android_product_id: string; ios_product_id: string; type: string; consumable: boolean };
export interface BillingConfig { enabled: boolean; appId: string; zone: 'sandbox' | 'live'; key: string; allowReal: boolean; iosAppId?: string; iosBundleId?: string }
export type Verifier = (receipt: string, pid: string) => Promise<Record<string, unknown>>;
export const seasonNow = () => String(Math.floor(Date.now() / (28 * 86400_000)));
export function loadProducts(): Product[] {
  return JSON.parse(readFileSync(new URL('../../config/iap-products.json', import.meta.url), 'utf8')).items;
}
export function receiptVerifier(config: BillingConfig, transport: typeof fetch = fetch): Verifier {
  return async (receipt, pid) => {
    try {
      const response = await transport(`https://${config.zone === 'sandbox' ? 'sandbox-' : ''}hiveiap-verify.qpyou.cn/api_v4/verify`, {
        method: 'POST', redirect: 'error', signal: AbortSignal.timeout(8000),
        headers: { 'Content-Type': 'application/json', ...(config.key ? { Authorization: `Bearer ${config.key}` } : {}) },
        body: JSON.stringify({ purchase_bypass_info: receipt, game_info: { server_uid: pid, server_type: config.zone === 'sandbox' ? 'qa' : 'live' } }),
      });
      if (!response.ok) throw new Error();
      // No raw receipt, access token, or complete upstream response is logged.
      return object(await response.json());
    } catch { throw new APIError(502, '결제 확인 서버에 연결하지 못했습니다. 구매 복원을 다시 눌러 주세요.'); }
  };
}
interface Order { id: string; pid: string; app: string; sku: string; season: string; market: number }
interface Grant { tx: string; order_id: string; pid: string; app: string; sku: string; season: string; install: string; delivered: number; item: string; market: number }
export class Billing {
  constructor(private db: DatabaseSync, readonly config: BillingConfig, private products: Product[], private verify: Verifier) {
    db.exec(`CREATE TABLE IF NOT EXISTS iap_orders(id TEXT PRIMARY KEY,pid TEXT NOT NULL,app TEXT NOT NULL,sku TEXT NOT NULL,season TEXT NOT NULL,created INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS iap_grants(tx TEXT PRIMARY KEY,order_id TEXT UNIQUE NOT NULL,pid TEXT NOT NULL,app TEXT NOT NULL,sku TEXT NOT NULL,season TEXT NOT NULL,install TEXT NOT NULL,delivered INTEGER NOT NULL DEFAULT 0,item TEXT NOT NULL);
      CREATE INDEX IF NOT EXISTS iap_owner ON iap_grants(pid,app,sku,season);`);
    // Additive migration: existing Google Play orders/grants remain market 2.
    for (const table of ['iap_orders', 'iap_grants']) {
      if (!db.prepare(`PRAGMA table_info(${table})`).all().some(row => row.name === 'market'))
        db.exec(`ALTER TABLE ${table} ADD COLUMN market INTEGER NOT NULL DEFAULT 2`);
    }
  }
  private product(sku: unknown, market = 2): Product {
    const p = this.products.find(p => (market === 1 ? p.ios_product_id : p.android_product_id) === sku);
    if (!p) throw new APIError(400, '등록되지 않은 상품입니다.');
    return p;
  }
  private check(data: Record<string, unknown>) {
    if (!this.config.enabled) throw new APIError(503, '상점 결제를 준비 중입니다.');
    const platform = data.platform ?? 'android'; // Older Android clients omit this field.
    if (platform !== 'android' && platform !== 'ios') throw new APIError(400, '지원하지 않는 결제 플랫폼입니다.');
    const market = platform === 'ios' ? 1 : 2;
    const app = market === 1 ? this.config.iosAppId : this.config.appId;
    const bundle = market === 1 ? this.config.iosBundleId : this.config.appId;
    if (!app || !bundle) throw new APIError(503, '이 플랫폼의 결제를 준비 중입니다.');
    if (data.app_id !== app) throw new APIError(400, '이 앱의 결제 설정을 확인해 주세요.');
    return { market, app, bundle };
  }

  private install(data: Record<string, unknown>): string {
    if (typeof data.install_id !== 'string' || !/^[a-f0-9]{32}$/.test(data.install_id)) throw new APIError(400, '기기 저장소를 확인해 주세요.');
    return data.install_id;
  }
  async handle(action: string, pid: string, data: Record<string, unknown>): Promise<unknown> {
    const { market, app, bundle } = this.check(data);
    if (action === 'entitlements') {
      const rows = this.db.prepare('SELECT item,season FROM iap_grants WHERE pid=? AND app=? AND market=? AND delivered=1').all(pid, app, market);
      return { entitlements: rows.map(r => ({ item: JSON.parse(String(r.item)), season: r.season })).filter(r => !r.item.consumable || (r.item.type === 'season_pass' && r.season === seasonNow())) };
    }
    const install = this.install(data);
    if (action === 'order') {
      const item = this.product(data.sku, market), sku = market === 1 ? item.ios_product_id : item.android_product_id, season = item.type === 'season_pass' ? seasonNow() : '';
      if (!item.consumable || season) {
        const owned = this.db.prepare('SELECT tx FROM iap_grants WHERE pid=? AND app=? AND sku=? AND season=? AND market=?').get(pid, app, sku, season, market);
        if (owned) throw new APIError(409, '이미 구매한 상품입니다. 구매 복원으로 지급을 확인해 주세요.');
      }
      // Reuse an unfinished intent (double taps / delayed payment), rather than opening independent orders.
      let order = this.db.prepare('SELECT o.* FROM iap_orders o LEFT JOIN iap_grants g ON g.order_id=o.id WHERE o.pid=? AND o.app=? AND o.sku=? AND o.season=? AND o.market=? AND g.tx IS NULL ORDER BY o.created DESC LIMIT 1').get(pid, app, sku, season, market) as unknown as Order | undefined;
      if (!order) {
        order = { id: randomUUID(), pid, app, sku, season, market };
        this.db.prepare('INSERT INTO iap_orders(id,pid,app,sku,season,created,market) VALUES(?,?,?,?,?,?,?)').run(order.id, pid, order.app, order.sku, season, Date.now(), market);
      }
      return { payload: JSON.stringify({ order_id: order.id }), sku: order.sku, season };
    }
    if (action === 'ack') {
      if (typeof data.transaction_id !== 'string') throw new APIError(400, '거래 ID가 필요합니다.');
      const grant = this.db.prepare('SELECT * FROM iap_grants WHERE tx=?').get(data.transaction_id) as unknown as Grant | undefined;
      if (!grant || grant.pid !== pid || grant.app !== app || grant.market !== market || grant.install !== install) throw new APIError(403, '구매 기기와 계정을 확인해 주세요.');
      this.db.prepare('UPDATE iap_grants SET delivered=1 WHERE tx=?').run(grant.tx);
      return { acknowledged: true, transaction_id: grant.tx, sku: grant.sku };
    }
    if (action !== 'verify') throw new APIError(404, '결제 요청을 찾을 수 없습니다.');
    if (typeof data.receipt !== 'string' || !data.receipt || data.receipt.length > 200000) throw new APIError(400, '영수증을 확인해 주세요.');
    const verified = await this.verify(data.receipt, pid);
    if (verified.result !== 0 || Number(verified.hiveiap_market_id) !== market || verified.hiveiap_purchase_cancel_state !== 0 || verified.hiveiap_account_uuid_compare !== 1)
      throw new APIError(422, '유효한 스토어 구매를 확인하지 못했습니다.');
    if (!['Y', 'N'].includes(String(verified.hiveiap_purchase_test)) || (!this.config.allowReal && verified.hiveiap_purchase_test !== 'Y'))
      throw new APIError(422, '현재 테스트 구매만 지원합니다. 고객 지원에 문의해 주세요.');
    if (Number(verified.hiveiap_quantity ?? 1) !== 1) throw new APIError(422, '단일 수량 구매만 지원합니다. 고객 지원에 문의해 주세요.');
    if (market === 1) validateAppleReceipt(verified, bundle);
    else {
      const receipt = object(verified.hiveiap_receipt), purchase = object(receipt.purchase_data);
      if (purchase.packageName !== bundle) throw new APIError(422, '구매 앱이 일치하지 않습니다.');
    }
    let payload: Record<string, unknown>;
    try { payload = object(JSON.parse(String(verified.hiveiap_iap_payload))); } catch { throw new APIError(422, '구매 주문을 확인하지 못했습니다. 고객 지원에 문의해 주세요.'); }
    const order = this.db.prepare('SELECT * FROM iap_orders WHERE id=?').get(String(payload.order_id)) as unknown as Order | undefined;
    if (!order || order.pid !== pid || order.app !== app || order.market !== market || order.sku !== verified.hiveiap_market_pid)
      throw new APIError(403, '구매 계정과 상품이 일치하지 않습니다.');
    const item = this.product(order.sku, market), tx = verified.hiveiap_transaction_id;
    if (typeof tx !== 'string' || !tx || tx.length > 256) throw new APIError(422, '거래 번호를 확인하지 못했습니다.');
    // No await in the transaction: concurrent verification cannot allocate the same purchase twice.
    this.db.exec('BEGIN IMMEDIATE');
    try {
      let grant = this.db.prepare('SELECT * FROM iap_grants WHERE tx=? OR order_id=?').get(tx, order.id) as unknown as Grant | undefined;
      if (grant && (grant.tx !== tx || grant.pid !== pid || grant.app !== order.app || grant.sku !== order.sku || grant.market !== market)) throw new APIError(409, '중복 주문입니다. 고객 지원에 문의해 주세요.');
      if (!grant) {
        if ((!item.consumable || order.season) && this.db.prepare('SELECT tx FROM iap_grants WHERE pid=? AND app=? AND sku=? AND season=? AND market=?').get(pid, order.app, order.sku, order.season, market))
          throw new APIError(409, '이미 지급된 상품입니다. 고객 지원에 문의해 주세요.');
        this.db.prepare('INSERT INTO iap_grants(tx,order_id,pid,app,sku,season,install,delivered,item,market) VALUES(?,?,?,?,?,?,?,0,?,?)').run(tx, order.id, pid, order.app, order.sku, order.season, install, JSON.stringify(item), market);
        grant = this.db.prepare('SELECT * FROM iap_grants WHERE tx=?').get(tx) as unknown as Grant;
      }
      if (!grant.delivered && grant.install !== install) throw new APIError(409, '구매한 기기에서 먼저 구매 복원을 완료해 주세요.');
      this.db.exec('COMMIT');
      return { transaction_id: tx, sku: grant.sku, item: JSON.parse(grant.item), season: grant.season, delivered: Boolean(grant.delivered) };
    } catch (e) { this.db.exec('ROLLBACK'); throw e; }
  }
}

// Inspect only Hive's verified Apple response, never client-decoded bypassInfo/JWS.
function validateAppleReceipt(verified: Record<string, unknown>, bundle: string): void {
  const result = object(verified.hiveiap_receipt_verify_result), receipt = object(result.receipt);
  if (result.status !== 0) throw new APIError(422, 'App Store 영수증 검증에 실패했습니다.');
  const marketTx = verified.hiveiap_market_transaction_id;
  let transaction: Record<string, unknown>;
  if (receipt.bundleId !== undefined) { // StoreKit 2: one verified transaction.
    if (receipt.bundleId !== bundle || (marketTx && receipt.transactionId !== marketTx))
      throw new APIError(422, 'App Store 앱 또는 거래가 일치하지 않습니다.');
    transaction = receipt;
  } else { // StoreKit 1: select this transaction, not another entry in the app receipt.
    if (receipt.bundle_id !== bundle || typeof marketTx !== 'string' || !marketTx)
      throw new APIError(422, 'App Store 앱 또는 거래를 확인하지 못했습니다.');
    const entries = Array.isArray(receipt.in_app) ? receipt.in_app : [];
    transaction = object(entries.find(entry => object(entry).transaction_id === marketTx));
  }
  if ((transaction.productId ?? transaction.product_id) !== verified.hiveiap_market_pid ||
      Number(transaction.quantity) !== 1 || transaction.revocationDate != null ||
      transaction.cancellation_date != null || transaction.cancellation_date_ms != null)
    throw new APIError(422, 'App Store 상품·수량·취소 상태가 유효하지 않습니다.');
}
