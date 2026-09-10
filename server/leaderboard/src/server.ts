import { createServer, type IncomingMessage } from 'node:http';
import { APIError, object, validateRecord, type Entry, type Hive, RecordStore } from './ranking.js';
async function body(req: IncomingMessage): Promise<Record<string, unknown>> {
  const chunks: Buffer[] = []; let size = 0;
  for await (const part of req) {
    size += part.length;
    if (size > 8192) throw new APIError(413, '요청이 너무 큽니다.');
    chunks.push(Buffer.from(part));
  }
  try { return object(JSON.parse(Buffer.concat(chunks).toString('utf8'))); }
  catch { throw new APIError(400, '잘못된 요청입니다.'); }
}
export function createRankingServer(hive: Hive, store: RecordStore, retryMs = 30_000) {
  let cache: Entry[] | undefined, cacheAt = 0, generation = 0;
  let read: Promise<Entry[]> | undefined;
  const invalidate = () => { generation++; cacheAt = 0; };
  const flush = () => store.flush(hive, invalidate).catch(() => {
    console.warn('[ranking] Hive 전송 대기: 자동 재시도 예정');
  });
  const timer = setInterval(() => void flush(), retryMs);
  timer.unref();
  const server = createServer({ maxHeaderSize: 32768, requestTimeout: 15_000, headersTimeout: 10_000 }, async (req, res) => {
    try {
      let status = 200, value: unknown;
      const path = req.url?.split('?')[0];
      if (req.method === 'GET' && path === '/healthz') {
        store.db.prepare('SELECT 1').get(); value = { status: 'ok' };
      } else if (req.method === 'GET' && path === '/v1/ranking/top') {
        if (!cache || Date.now() - cacheAt >= 10_000) {
          if (!read) {
            const revision = generation;
            read = hive.top().then(rows => { cache = rows; cacheAt = revision === generation ? Date.now() : 0; return rows; })
              .finally(() => { read = undefined; });
          }
          value = { entries: await read, limit: 100 };
        } else value = { entries: cache, limit: 100 };
      } else if (req.method === 'POST' && path === '/v1/ranking/record') {
        const data = await body(req), record = validateRecord(data);
        const headers = new Headers();
        for (const key of ['x-hive-player-token', 'x-hive-access-token']) {
          const value = req.headers[key]; if (typeof value === 'string') headers.set(key, value);
        }
        const pid = await hive.authenticate(headers, data);
        store.accept(pid, record);
        const pending = store.pending(pid);
        status = pending ? 202 : 200; value = { pending };
        invalidate();
        // Return after durable acceptance; slow Hive writes do not hold the HTTP request.
        void flush();
      } else throw new APIError(404, '페이지를 찾을 수 없습니다.');
      res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
      res.end(JSON.stringify(value));
    } catch (e) {
      res.writeHead(e instanceof APIError ? e.status : 500, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
      res.end(JSON.stringify({ message: e instanceof APIError ? e.message : '랭킹 서버 오류입니다. 잠시 후 다시 시도해 주세요.' }));
    }
  });
  return { server, flush, async close() {
    clearInterval(timer);
    if (server.listening) await new Promise<void>((resolve, reject) => server.close(e => e ? reject(e) : resolve()));
    await store.close();
  } };
}
