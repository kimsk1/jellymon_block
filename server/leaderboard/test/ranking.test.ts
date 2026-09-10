import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { once } from 'node:events';
import { APIError, EPOCH_MS, ordered, RecordStore, scoreFor, validateRecord, type RecordData, type Hive } from '../src/ranking.js';
import { HiveAPI, readConfig } from '../src/hive.js';
import { createRankingServer } from '../src/server.js';
const rec = (level = 50, at = EPOCH_MS + 1000): RecordData => ({ level, stars: 3, achieved_at_ms: at, nickname: '말랑' });
class FakeHive implements Hive {
  records = new Map<string, RecordData>();
  fail = false;
  async authenticate(headers: Headers, data: Record<string, unknown>) {
    if (headers.get('x-hive-access-token') !== 'test-only') throw new APIError(401, 'login');
    return String(data.player_id);
  }
  async submit(pid: string, r: RecordData) { if (this.fail) throw new APIError(502, 'offline'); this.records.set(pid, r); }
  async top() { return ordered([...this.records].map(([player_id, r]) => ({ player_id, ...r }))); }
}
test('only 3 stars, integral levels/times, future timestamps, exact score order', () => {
  for (const stars of [0, 1, 2, 4, true, '3']) assert.throws(() => validateRecord({ ...rec(), stars }));
  for (const level of [0, 1001, 1.1, '50', NaN]) assert.throws(() => validateRecord({ ...rec(), level }));
  assert.throws(() => validateRecord(rec(50, Date.now() + 120000)));
  assert.ok(scoreFor(51, EPOCH_MS + 20000) > scoreFor(50, EPOCH_MS));
  assert.ok(scoreFor(50, EPOCH_MS + 1) > scoreFor(50, EPOCH_MS + 2));
  assert.ok(Number.isSafeInteger(scoreFor(1000, EPOCH_MS)));
  assert.ok(scoreFor(1000, EPOCH_MS) <= 999999999999999);
});
test('higher levels, earliest time, no downgrade or duplicate', async () => {
  const store = new RecordStore(':memory:'), hive = new FakeHive();
  try {
    for (const [pid, r] of [['1', rec(99)], ['2', rec(100, EPOCH_MS + 20)], ['3', rec(100, EPOCH_MS + 10)], ['2', rec(1)], ['3', rec(100, EPOCH_MS + 99)]] as const) store.accept(pid, r);
    await store.flush(hive);
    assert.deepEqual((await hive.top()).map(r => r.player_id), ['3', '2', '1']);
    assert.equal(hive.records.get('3')!.achieved_at_ms, EPOCH_MS + 10);
  } finally { await store.close(); }
});
test('pending outbox survives restart', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'jelly-ranking-')), path = join(dir, 'rank.sqlite3');
  const hive = new FakeHive(); hive.fail = true;
  let store = new RecordStore(path);
  try {
    store.accept('1', rec());
    await assert.rejects(store.flush(hive));
    assert.equal(store.pending('1'), true);
    await store.close(); store = new RecordStore(path); hive.fail = false;
    await store.flush(hive); assert.equal(store.pending('1'), false);
    assert.equal(hive.records.get('1')!.level, 50);
  } finally { await store.close(); rmSync(dir, { recursive: true, force: true }); }
});
test('a newer record during in-flight submission is not acknowledged as the old record', async () => {
  const store = new RecordStore(':memory:'), hive = new FakeHive();
  let release!: () => void;
  const gate = new Promise<void>(resolve => { release = resolve; });
  const submit = hive.submit.bind(hive); let count = 0;
  hive.submit = async (pid, record) => { if (count++ === 0) await gate; await submit(pid, record); };
  try {
    store.accept('1', rec(50)); const flush = store.flush(hive);
    store.accept('1', rec(100)); assert.equal(store.flush(hive), flush);
    release(); await flush;
    assert.equal(hive.records.get('1')!.level, 100);
    assert.equal(store.pending('1'), false); assert.equal(count, 2);
  } finally { await store.close(); }
});
test('HTTP health, auth, invalid JSON, oversized body, top 100, persistence response', async () => {
  const store = new RecordStore(':memory:'), hive = new FakeHive();
  const app = createRankingServer(hive, store);
  app.server.listen(0, '127.0.0.1'); await once(app.server, 'listening');
  const address = app.server.address(); assert.ok(address && typeof address === 'object');
  const url = `http://127.0.0.1:${address.port}`;
  const post = (body: string, token = 'test-only') => fetch(url + '/v1/ranking/record', { method: 'POST', headers: { 'x-hive-access-token': token }, body });
  try {
    assert.deepEqual(await (await fetch(url + '/healthz')).json(), { status: 'ok', billing: false });
    assert.equal((await post('{')).status, 400);
    assert.equal((await post('[]')).status, 400);
    assert.equal((await post('x'.repeat(9000))).status, 413);
    assert.equal((await post(JSON.stringify({ player_id: '1', ...rec() }), 'bad')).status, 401);
    assert.equal(hive.records.size, 0);
    const result = await post(JSON.stringify({ player_id: '1', ...rec() }));
    assert.equal(result.status, 202); assert.deepEqual(await result.json(), { pending: true });
    await app.flush();
    for (let i = 1; i <= 120; i++) hive.records.set(String(i), rec(i));
    const top = await (await fetch(url + '/v1/ranking/top')).json() as { entries: {level: number}[]; limit: number };
    assert.equal(top.entries.length, 100); assert.equal(top.entries[0].level, 120); assert.equal(top.entries[99].level, 21);
    assert.equal((await fetch(url + '/missing')).status, 404);
  } finally { await app.close(); }
});
test('configuration defaults to board 163 and rejects invalid settings', () => {
  assert.equal(readConfig({ HIVE_APP_ID: 'app', HIVE_CERTIFICATION_KEY: 'test' }).boardId, '163');
  assert.throws(() => readConfig({ HIVE_APP_ID: 'app' }));
  assert.throws(() => readConfig({ HIVE_APP_ID: 'app', HIVE_CERTIFICATION_KEY: 'test', HIVE_ZONE: 'invalid' }));
});
test('Hive 163 payload, top metadata and authentication checks without real Hive calls', async () => {
  const calls: { url: string; init?: RequestInit }[] = [];
  let response: unknown = {};
  const transport: typeof fetch = async (input, init) => { calls.push({url: String(input), init}); return Response.json(response); };
  const hive = new HiveAPI(readConfig({ HIVE_APP_ID: 'app', HIVE_CERTIFICATION_KEY: 'test-cert' }), transport);
  await hive.submit('7', rec());
  assert.match(calls[0].url, /\/leaderboards\/163\/score$/);
  const payload = JSON.parse(calls[0].init!.body as string);
  assert.equal(payload.score, scoreFor(50, EPOCH_MS + 1000));
  assert.equal(JSON.parse(payload.extraData).stars, 3);
  response = { rankingList: [{playerId: 7, score: payload.score, extraData: payload.extraData}] };
  assert.equal((await hive.top())[0].nickname, '말랑');
  response = { rankingList: [{playerId: 7, score: 0, extraData: payload.extraData}] };
  await assert.rejects(hive.top());
  const headers = new Headers({ 'x-hive-player-token': 'p', 'x-hive-access-token': 'a' });
  response = { result_code: 0, token_validation: {result_code: 1} };
  await assert.rejects(hive.authenticate(headers, {player_id: '7', did: 'd'}));
  response = { result_code: 0, token_validation: {result_code: 0}, data: {is_blocked: true} };
  await assert.rejects(hive.authenticate(headers, {player_id: '7', did: 'd'}));
  response = { result_code: 0, token_validation: {result_code: 0} };
  assert.equal(await hive.authenticate(headers, {player_id: '7', did: 'd'}), '7');
  assert.equal(calls.at(-1)!.init!.redirect, 'error');
});

test('Hive authorization failures remain distinguishable without exposing tokens', async () => {
  const hive = new HiveAPI(readConfig({ HIVE_APP_ID: 'app', HIVE_CERTIFICATION_KEY: 'never-expose-this' }),
    async () => new Response('private upstream details', {status: 403}));
  await assert.rejects(hive.top(), (e: unknown) => e instanceof APIError && e.status === 502 &&
    e.message.includes('인증 실패') && !e.message.includes('never-expose-this') && !e.message.includes('private'));
});

test('iOS and Android tokens use their allowed App ID; unknown IDs never reach Hive', async () => {
  const sent: string[] = [];
  const hive = new HiveAPI(readConfig({ HIVE_APP_ID: 'android', HIVE_ALLOWED_APP_IDS: 'android, ios', HIVE_CERTIFICATION_KEY: 'test' }),
    async (_url, init) => {
      sent.push(JSON.parse(String(init?.body)).appid);
      return Response.json({ result_code: 0, token_validation: { result_code: 0 } });
    });
  const headers = new Headers({ 'x-hive-player-token': 'test', 'x-hive-access-token': 'test' });
  const data = { player_id: '7', did: 'test' };
  await hive.authenticate(headers, data);
  await hive.authenticate(headers, { ...data, app_id: 'ios' });
  await hive.authenticate(headers, { ...data, app_id: 'android' });
  for (const app_id of ['foreign', '', null, 7])
    await assert.rejects(hive.authenticate(headers, { ...data, app_id }), (e: unknown) => e instanceof APIError && e.status === 401);
  assert.deepEqual(sent, ['android', 'ios', 'android']);
});
