import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

export const EPOCH_MS = 1767225600000;
export const TIME_BUCKET = 500_000_000_000;
export interface RecordData { level: number; stars: number; achieved_at_ms: number; nickname: string }
export interface Entry extends RecordData { player_id: string; rank?: number }
export class APIError extends Error {
  constructor(public status: number, message: string) { super(message); }
}
export function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new APIError(400, '잘못된 요청입니다.');
  return value as Record<string, unknown>;
}
export function scoreFor(level: number, at: number): number {
  const elapsed = at - EPOCH_MS;
  if (!Number.isSafeInteger(level) || level < 1 || level > 1000 || !Number.isSafeInteger(at) || elapsed < 0 || elapsed >= TIME_BUCKET)
    throw new APIError(400, '지원하지 않는 레벨 또는 달성 시각입니다.');
  return level * TIME_BUCKET + TIME_BUCKET - 1 - elapsed;
}
export function validateRecord(value: unknown, now = Date.now()): RecordData {
  const r = object(value);
  if (r.stars !== 3 || typeof r.level !== 'number' || typeof r.achieved_at_ms !== 'number')
    throw new APIError(400, '별 3개 클리어 기록만 등록할 수 있습니다.');
  scoreFor(r.level, r.achieved_at_ms);
  if (r.achieved_at_ms > now + 60_000) throw new APIError(400, '기기의 날짜와 시간을 확인해 주세요.');
  if (r.nickname !== undefined && typeof r.nickname !== 'string') throw new APIError(400, '잘못된 닉네임입니다.');
  const nickname = Array.from(((r.nickname as string) || '').replace(/[\p{Cc}\p{Cf}]/gu, '').trim()).slice(0, 12).join('') || '구조 대원';
  return { level: r.level, stars: 3, achieved_at_ms: r.achieved_at_ms, nickname };
}
export function ordered(rows: Entry[]): Entry[] {
  return [...rows].sort((a, b) => b.level - a.level || a.achieved_at_ms - b.achieved_at_ms || a.player_id.localeCompare(b.player_id))
    .slice(0, 100).map((row, i) => ({ ...row, rank: i + 1 }));
}
export interface Hive {
  authenticate(headers: Headers, data: Record<string, unknown>): Promise<string>;
  submit(pid: string, record: RecordData): Promise<void>;
  top(): Promise<Entry[]>;
}
interface Stored { pid: string; level: number; at_ms: number; nickname: string; dirty: number }
export class RecordStore {
  readonly db: DatabaseSync;
  private running?: Promise<void>;
  private stopping = false;
  constructor(path: string) {
    if (path !== ':memory:') mkdirSync(dirname(resolve(path)), { recursive: true });
    this.db = new DatabaseSync(path);
    this.db.exec(`PRAGMA busy_timeout=5000; PRAGMA journal_mode=WAL;
      CREATE TABLE IF NOT EXISTS records (pid TEXT PRIMARY KEY, level INTEGER NOT NULL,
        at_ms INTEGER NOT NULL, nickname TEXT NOT NULL, dirty INTEGER NOT NULL DEFAULT 1)`);
  }
  accept(pid: string, r: RecordData): void {
    // One synchronous transaction per record; network I/O never holds the SQLite lock.
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const old = this.db.prepare('SELECT * FROM records WHERE pid=?').get(pid) as unknown as Stored | undefined;
      if (!old || r.level > old.level || (r.level === old.level && r.achieved_at_ms < old.at_ms)) {
        this.db.prepare(`INSERT INTO records VALUES (?,?,?,?,1) ON CONFLICT(pid) DO UPDATE SET
          level=excluded.level,at_ms=excluded.at_ms,nickname=excluded.nickname,dirty=1`).run(pid, r.level, r.achieved_at_ms, r.nickname);
      } else if (old.nickname !== r.nickname) {
        this.db.prepare('UPDATE records SET nickname=?,dirty=1 WHERE pid=?').run(r.nickname, pid);
      }
      this.db.exec('COMMIT');
    } catch (e) { this.db.exec('ROLLBACK'); throw e; }
  }
  pending(pid: string): boolean { return this.db.prepare('SELECT dirty FROM records WHERE pid=?').get(pid)?.dirty === 1; }
  flush(hive: Hive, onWrite = () => {}): Promise<void> {
    if (this.running) return this.running;
    this.running = this.send(hive, onWrite).finally(() => { this.running = undefined; });
    return this.running;
  }
  private async send(hive: Hive, onWrite: () => void): Promise<void> {
    for (let i = 0; i < 100 && !this.stopping; i++) {
      const row = this.db.prepare('SELECT * FROM records WHERE dirty=1 ORDER BY rowid LIMIT 1').get() as unknown as Stored | undefined;
      if (!row) return;
      await hive.submit(row.pid, { level: row.level, stars: 3, achieved_at_ms: row.at_ms, nickname: row.nickname });
      // A better record may arrive while awaiting Hive: don't acknowledge that newer record.
      this.db.prepare('UPDATE records SET dirty=0 WHERE pid=? AND level=? AND at_ms=? AND nickname=?')
        .run(row.pid, row.level, row.at_ms, row.nickname);
      onWrite();
    }
  }
  async close(): Promise<void> {
    this.stopping = true;
    await this.running?.catch(() => {});
    this.db.close();
  }
}
