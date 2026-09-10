import { APIError, object, ordered, scoreFor, validateRecord, type Entry, type Hive, type RecordData } from './ranking.js';
export interface Config { appId: string; boardId: string; key: string; zone: 'sandbox' | 'live' }
export function readConfig(env: NodeJS.ProcessEnv): Config {
  const appId = env.HIVE_APP_ID?.trim(), boardId = env.HIVE_LEADERBOARD_ID?.trim() ?? '163', key = env.HIVE_CERTIFICATION_KEY?.trim();
  if (!appId || !key || !/^[1-9]\d*$/.test(boardId)) throw new Error('HIVE_APP_ID, HIVE_CERTIFICATION_KEY, HIVE_LEADERBOARD_ID 설정을 확인하세요.');
  const zone = env.HIVE_ZONE ?? 'sandbox';
  if (zone !== 'sandbox' && zone !== 'live') throw new Error('HIVE_ZONE은 sandbox 또는 live여야 합니다.');
  return { appId, boardId, key, zone };
}
export class HiveAPI implements Hive {
  readonly base: string;
  constructor(private config: Config, private transport: typeof fetch = fetch) {
    this.base = `https://${config.zone === 'sandbox' ? 'sandbox-' : ''}api-leaderboard.withhive.com`;
  }
  private async request(url: string, method = 'GET', data?: unknown, headers: Record<string, string> = {}): Promise<unknown> {
    try {
      const response = await this.transport(url, { method, headers: { 'Content-Type': 'application/json', ...headers },
        body: data === undefined ? undefined : JSON.stringify(data), signal: AbortSignal.timeout(8000), redirect: 'error' });
      if (!response.ok) {
        console.warn(`[hive] HTTP ${response.status} ${new URL(url).pathname}`);
        if (response.status === 401 || response.status === 403)
          throw new APIError(502, 'Hive 인증 실패: Certification Key와 게임/환경 설정을 확인해 주세요.');
        if (response.status === 400 || response.status === 404)
          throw new APIError(502, 'Hive 보드 요청 실패: 163번 보드와 sandbox/live 설정을 확인해 주세요.');
        throw new APIError(502, `Hive 서비스 응답 오류 (HTTP ${response.status})`);
      }
      if (!response.body) return {};
      const reader = response.body.getReader();
      const chunks: Uint8Array[] = []; let size = 0;
      while (true) {
        const part = await reader.read();
        if (part.done) break;
        size += part.value.byteLength;
        if (size > 1024 * 1024) { await reader.cancel(); throw new Error('oversize'); }
        chunks.push(part.value);
      }
      const text = Buffer.concat(chunks).toString('utf8');
      return text ? JSON.parse(text) : {};
    } catch (e) {
      if (e instanceof APIError) throw e;
      throw new APIError(502, 'Hive 연결을 확인해 주세요.');
    }
  }
  async authenticate(headers: Headers, data: Record<string, unknown>): Promise<string> {
    const pid = data.player_id, did = data.did;
    const token = headers.get('x-hive-player-token'), access = headers.get('x-hive-access-token');
    if (typeof pid !== 'string' || !/^[1-9]\d{0,15}$/.test(pid) || !Number.isSafeInteger(Number(pid)) || typeof did !== 'string' || !did || did.length > 256 || !token || !access)
      throw new APIError(401, 'Hive 로그인이 필요합니다.');
    const hosts = this.config.zone === 'sandbox' ? ['https://sandbox-auth.qpyou.cn'] : ['https://auth.qpyou.cn', 'https://auth.globalwithhive.com'];
    let result: Record<string, unknown> | undefined;
    for (const [i, host] of hosts.entries()) {
      try {
        result = object(await this.request(host + '/v2/game/token/get-token', 'POST',
          { appid: this.config.appId, did, player_id: Number(pid), include_fields: ['is_blocked'] },
          { Authorization: token, 'X-Access-Token': access, ISCRYPT: '0' }));
        break;
      } catch (e) { if (i === hosts.length - 1) throw e; }
    }
    if (!result || result.result_code !== 0 || object(result.token_validation).result_code !== 0 ||
      (result.data && object(result.data).is_blocked)) throw new APIError(401, 'Hive 로그인 확인에 실패했습니다.');
    return pid;
  }
  async submit(pid: string, record: RecordData): Promise<void> {
    const extraData = JSON.stringify({ v: 1, ...record });
    if (Array.from(extraData).length > 256) throw new APIError(400, '닉네임 길이를 확인해 주세요.');
    await this.request(`${this.base}/leaderboards/${this.config.boardId}/score`, 'POST', {
      playerId: Number(pid), score: scoreFor(record.level, record.achieved_at_ms),
      achievementTimeUtc: new Date(record.achieved_at_ms).toISOString().replace(/Z$/, ''), extraData,
    }, { Authorization: `Bearer ${this.config.key}` });
  }
  async top(): Promise<Entry[]> {
    try {
      const value = object(await this.request(`${this.base}/leaderboards/${this.config.boardId}/ranks?page=1&rowcount=100`, 'GET', undefined,
        { Authorization: `Bearer ${this.config.key}` }));
      if (!Array.isArray(value.rankingList) || value.rankingList.length > 100) throw new Error();
      const seen = new Set<string>();
      return ordered(value.rankingList.map(raw => {
        const row = object(raw);
        if (typeof row.extraData !== 'string') throw new Error();
        const metadata = object(JSON.parse(row.extraData));
        const record = validateRecord(metadata);
        const pid = String(row.playerId);
        if (metadata.v !== 1 || scoreFor(record.level, record.achieved_at_ms) !== row.score ||
            !/^[1-9]\d*$/.test(pid) || !Number.isSafeInteger(Number(pid)) || seen.has(pid)) throw new Error();
        seen.add(pid);
        return { ...record, player_id: pid };
      }));
    } catch (e) {
      if (e instanceof APIError && e.status === 502) throw e;
      throw new APIError(502, '랭킹 데이터 형식 오류: 전용 보드의 extraData와 점수를 확인해 주세요.');
    }
  }
}
