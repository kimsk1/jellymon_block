import { HiveAPI, readConfig } from './hive.js';
import { RecordStore } from './ranking.js';
import { createRankingServer } from './server.js';
import { Billing, loadProducts, receiptVerifier } from './billing.js';

try {
  const config = readConfig(process.env);
  const port = Number(process.env.PORT ?? 8787);
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('PORT 설정을 확인하세요.');
  const store = new RecordStore(process.env.RANKING_DB_PATH || 'data/ranking.sqlite3');
  const billingConfig = { enabled: process.env.HIVE_IAP_ENABLED === 'true', appId: config.appId, zone: config.zone,
    key: process.env.HIVE_IAP_AUTH_KEY?.trim() || '', allowReal: config.zone === 'live' && process.env.HIVE_IAP_ALLOW_REAL === 'true' };
  const billing = new Billing(store.db, billingConfig, loadProducts(), receiptVerifier(billingConfig));
  const app = createRankingServer(new HiveAPI(config), store, 30000, billing);
  app.server.on('error', () => { console.error('랭킹 서버 포트를 열 수 없습니다.'); process.exit(1); });
  app.server.listen(port, process.env.HOST || '127.0.0.1', () => {
    console.log(`[ranking] port=${port} board=${config.boardId} zone=${config.zone}`);
    void app.flush();
  });
  let stopping = false;
  for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => {
    if (stopping) return; stopping = true;
    const timeout = setTimeout(() => process.exit(1), 25_000); timeout.unref();
    void app.close().then(() => { clearTimeout(timeout); process.exit(0); });
  });
} catch {
  console.error('랭킹 서버 시작 실패: .env의 Hive 설정, PORT 및 DB 경로/권한을 확인하세요.');
  process.exit(1);
}
