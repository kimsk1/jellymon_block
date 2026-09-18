import { test } from 'node:test';
import assert from 'node:assert/strict';
import { HiveAPI, readConfig } from '../src/hive.js';
const config = (seconds = 0) => readConfig({ HIVE_APP_ID: 'app', HIVE_ALLOWED_APP_IDS: 'app,ios', HIVE_CERTIFICATION_KEY: 'test', HIVE_AUTH_CACHE_SECONDS: String(seconds), HIVE_SINGLE_LOGIN_CONFIRMED: 'true' });
const data = { player_id: '7', did: 'device' };
const headers = (exp = 10000, token = 'player') => new Headers({ 'x-hive-player-token': token, 'x-hive-access-token': `e30.${Buffer.from(JSON.stringify({ exp })).toString('base64url')}.signature` });
const ok = () => Response.json({ result_code: 0, token_validation: { result_code: 0 }, data: { is_blocked: false } });
test('cache disabled by default; policy and TTL bounds required', () => {
  assert.equal(readConfig({ HIVE_APP_ID: 'app', HIVE_CERTIFICATION_KEY: 't' }).authCacheSeconds, 0);
  for (const v of [-1,301,NaN,1.5]) assert.throws(() => config(v));
  assert.throws(() => readConfig({ HIVE_APP_ID: 'app', HIVE_CERTIFICATION_KEY: 't', HIVE_AUTH_CACHE_SECONDS: '60' }));
});
test('concurrent requests share verification; errors fan out and retry works', async () => {
  let release!: () => void, calls = 0, fail = false;
  const gate = new Promise<void>(resolve => { release = resolve; });
  const api = new HiveAPI(config(), async () => { calls++; await gate; if(fail) throw Error('offline'); return ok(); });
  const jobs = Array.from({length:10}, () => api.authenticate(headers(), data));
  assert.equal(calls,1); release(); await Promise.all(jobs); assert.equal(api.authMetrics().joined,9);
  await api.authenticate(headers(),data); assert.equal(calls,2);
  fail=true;
  const results=await Promise.allSettled([api.authenticate(headers(),data),api.authenticate(headers(),data)]);
  assert.ok(results.every(r=>r.status==='rejected')); assert.equal(calls,3);
  await assert.rejects(api.authenticate(headers(),data)); assert.equal(calls,4);
});
test('fixed TTL, token/device/player/app isolation and fresh validation', async () => {
  let now=1000000,calls=0;
  const api=new HiveAPI(config(60),async()=>{calls++;return ok();},()=>now);
  await api.authenticate(headers(),data);
  now+=59000; await api.authenticate(headers(),data); assert.equal(calls,1);
  now+=1001; await api.authenticate(headers(),data); assert.equal(calls,2);
  await api.authenticate(headers(),data,{forceFresh:true}); assert.equal(calls,3);
  await api.authenticate(headers(10001),data); await api.authenticate(headers(10001,'other'),data);
  await api.authenticate(headers(),{...data,did:'other'}); await api.authenticate(headers(),{...data,player_id:'8'});
  await api.authenticate(headers(),{...data,app_id:'ios'}); assert.equal(calls,8);
});
test('expiration caps cache; opaque tokens not cached; failed force check evicts', async () => {
  let now=1000000,calls=0,blocked=false;
  const api=new HiveAPI(config(300),async()=>{calls++;return blocked?Response.json({result_code:0,token_validation:{result_code:0},data:{is_blocked:true}}):ok();},()=>now);
  await api.authenticate(headers(1010),data); now+=5001; await api.authenticate(headers(1010),data); assert.equal(calls,2);
  const opaque=headers();opaque.set('x-hive-access-token','opaque');
  await api.authenticate(opaque,data);await api.authenticate(opaque,data);assert.equal(calls,4);
  await api.authenticate(headers(),data);blocked=true;
  await assert.rejects(api.authenticate(headers(),data,{forceFresh:true}));
  await assert.rejects(api.authenticate(headers(),data));assert.equal(calls,7);assert.equal(api.authMetrics().cached,0);
});
