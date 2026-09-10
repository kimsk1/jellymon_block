"""Hive-backed three-star leaderboard. WSGI entry point: create_app()."""
import json
from contextlib import contextmanager
import os
import sqlite3
import threading
import time
from datetime import datetime, timezone
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError
from urllib.parse import urlencode, quote

EPOCH_MS = 1767225600000  # 2026-01-01 UTC
TIME_BUCKET = 500_000_000_000  # Millisecond ordering, valid through 2041.
MAX_LEVEL = 1000
DEFAULT_LEADERBOARD_ID = '163'


class APIError(Exception):
    def __init__(self, status, message):
        self.status, self.message = status, message


def utc_string(ms):
    return datetime.fromtimestamp(ms / 1000, timezone.utc).isoformat(timespec='milliseconds').removesuffix('+00:00')


def score_for(level, at_ms):
    elapsed = at_ms - EPOCH_MS
    if not 1 <= level <= MAX_LEVEL or not 0 <= elapsed < TIME_BUCKET:
        raise APIError(400, '지원하지 않는 레벨 또는 달성 시각입니다.')
    return level * TIME_BUCKET + TIME_BUCKET - 1 - elapsed


def validate_record(data, now_ms):
    for field in ('level', 'stars', 'achieved_at_ms'):
        if type(data.get(field)) is not int:
            raise APIError(400, '잘못된 기록입니다.')
    if data['stars'] != 3:
        raise APIError(400, '별 3개 클리어 기록만 등록할 수 있습니다.')
    at = data['achieved_at_ms']
    if at > now_ms + 60_000:
        raise APIError(400, '기기의 날짜와 시간을 확인해 주세요.')
    score_for(data['level'], at)
    name = data.get('nickname', '')
    if not isinstance(name, str):
        raise APIError(400, '잘못된 닉네임입니다.')
    name = ''.join(c for c in name.strip() if c.isprintable())[:12] or '구조 대원'
    return dict(level=data['level'], stars=3, achieved_at_ms=at, nickname=name)


class HiveAPI:
    def __init__(self, app_id, board_id, certification_key, sandbox=True):
        if not app_id or not board_id or not certification_key:
            raise ValueError('HIVE_APP_ID, HIVE_LEADERBOARD_ID, HIVE_CERTIFICATION_KEY are required')
        self.app_id, self.board_id, self.key = app_id, quote(board_id, safe=''), certification_key
        self.base = 'https://' + ('sandbox-' if sandbox else '') + 'api-leaderboard.withhive.com'
        self.auth_hosts = ['https://sandbox-auth.qpyou.cn'] if sandbox else ['https://auth.qpyou.cn', 'https://auth.globalwithhive.com']

    def request(self, url, method='GET', data=None, headers=None):
        payload = json.dumps(data, ensure_ascii=False).encode() if data is not None else None
        req = Request(url, data=payload, method=method, headers={'Content-Type': 'application/json', **(headers or {})})
        try:
            with urlopen(req, timeout=8) as response:
                raw = response.read(1024 * 1024)
                return json.loads(raw) if raw else {}
        except (URLError, TimeoutError, ValueError):
            # Do not expose upstream requests, credentials or response bodies.
            raise APIError(502, 'Hive 연결을 확인해 주세요.') from None

    def authenticate(self, headers, data):
        pid, did = str(data.get('player_id', '')), str(data.get('did', ''))
        token, access = headers.get('HTTP_X_HIVE_PLAYER_TOKEN', ''), headers.get('HTTP_X_HIVE_ACCESS_TOKEN', '')
        if not pid.isdecimal() or int(pid) <= 0 or len(pid) > 18 or not did or not token or not access:
            raise APIError(401, 'Hive 로그인이 필요합니다.')
        body = {'appid': self.app_id, 'did': did, 'player_id': int(pid), 'include_fields': ['is_blocked']}
        auth_headers = {'Authorization': token, 'X-Access-Token': access, 'ISCRYPT': '0'}
        result = None
        for i, host in enumerate(self.auth_hosts):
            try:
                result = self.request(host + '/v2/game/token/get-token', 'POST', body, auth_headers)
                break
            except APIError:
                if i == len(self.auth_hosts) - 1:
                    raise
        if result.get('result_code') != 0 or result.get('token_validation', {}).get('result_code') != 0 or result.get('data', {}).get('is_blocked', False):
            raise APIError(401, 'Hive 로그인 확인에 실패했습니다. 다시 연결해 주세요.')
        return pid

    def submit(self, pid, record):
        extra = json.dumps({'v': 1, **record}, ensure_ascii=False, separators=(',', ':'))
        assert len(extra) <= 256
        self.request(self.base + '/leaderboards/' + self.board_id + '/score', 'POST', {
            'playerId': int(pid), 'score': score_for(record['level'], record['achieved_at_ms']),
            'achievementTimeUtc': utc_string(record['achieved_at_ms']), 'extraData': extra,
        }, {'Authorization': 'Bearer ' + self.key})

    def top(self):
        value = self.request(self.base + '/leaderboards/' + self.board_id + '/ranks?' + urlencode({'page': 1, 'rowcount': 100}), headers={'Authorization': 'Bearer ' + self.key})
        rows = value.get('rankingList')
        if not isinstance(rows, list):
            raise APIError(502, '랭킹 응답을 확인할 수 없습니다.')
        result = []
        for row in rows:
            try:
                record = json.loads(row['extraData'])
                if record.get('v') != 1 or record.get('stars') != 3:
                    raise ValueError()
                if score_for(record['level'], record['achieved_at_ms']) != row['score']:
                    raise ValueError()
                result.append({'player_id': str(row['playerId']), **{key: record[key] for key in ('level', 'stars', 'achieved_at_ms', 'nickname')}})
            except (KeyError, ValueError, TypeError, APIError):
                # A dedicated board must not contain scores from other game modes.
                raise APIError(502, '랭킹 데이터 형식을 확인해 주세요.') from None
        result.sort(key=lambda r: (-r['level'], r['achieved_at_ms'], r['player_id']))
        return [dict(rank=i + 1, **r) for i, r in enumerate(result[:100])]


class RecordStore:
    def __init__(self, path):
        self.path = path
        with self.connect() as db:
            db.execute('CREATE TABLE IF NOT EXISTS records (pid TEXT PRIMARY KEY, level INTEGER NOT NULL, at_ms INTEGER NOT NULL, nickname TEXT NOT NULL, dirty INTEGER NOT NULL DEFAULT 1)')

    @contextmanager
    def connect(self):
        db = sqlite3.connect(self.path, timeout=30)
        db.row_factory = sqlite3.Row
        try:
            with db:
                yield db
        finally:
            db.close()

    def accept(self, pid, record):
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            old = db.execute('SELECT * FROM records WHERE pid=?', (pid,)).fetchone()
            better = old is None or record['level'] > old['level'] or (record['level'] == old['level'] and record['achieved_at_ms'] < old['at_ms'])
            if better:
                db.execute('INSERT INTO records VALUES (?,?,?,?,1) ON CONFLICT(pid) DO UPDATE SET level=excluded.level,at_ms=excluded.at_ms,nickname=excluded.nickname,dirty=1', (pid, record['level'], record['achieved_at_ms'], record['nickname']))
            elif old['nickname'] != record['nickname']:
                db.execute('UPDATE records SET nickname=?,dirty=1 WHERE pid=?', (record['nickname'], pid))

    def flush(self, hive, limit=100):
        # SQLite transaction serializes workers through acknowledgement, preventing
        # an older in-flight request from overwriting a newer Hive score.
        for _ in range(limit):
            with self.connect() as db:
                db.execute('BEGIN IMMEDIATE')
                row = db.execute('SELECT * FROM records WHERE dirty=1 ORDER BY rowid LIMIT 1').fetchone()
                if row is None:
                    return
                hive.submit(row['pid'], dict(level=row['level'], stars=3, achieved_at_ms=row['at_ms'], nickname=row['nickname']))
                db.execute('UPDATE records SET dirty=0 WHERE pid=?', (row['pid'],))

    def pending(self, pid):
        with self.connect() as db:
            row = db.execute('SELECT dirty FROM records WHERE pid=?', (pid,)).fetchone()
            return bool(row and row['dirty'])


class Application:
    def __init__(self, hive, store):
        self.hive, self.store = hive, store
        self._cache = None
        self._cache_at = 0.0
        self._cache_lock = threading.Lock()

    def __call__(self, environ, start_response):
        try:
            path, method = environ.get('PATH_INFO'), environ.get('REQUEST_METHOD')
            if path == '/healthz' and method == 'GET':
                with self.store.connect() as db:
                    db.execute('SELECT 1')
                status, value = 200, {'status': 'ok'}
            elif path == '/v1/ranking/top' and method == 'GET':
                with self._cache_lock:
                    if self._cache is None or time.monotonic() - self._cache_at >= 10:
                        self._cache = self.hive.top()
                        self._cache_at = time.monotonic()
                    value = {'entries': self._cache, 'limit': 100}
                status = 200
            elif path == '/v1/ranking/record' and method == 'POST':
                try:
                    size = int(environ.get('CONTENT_LENGTH', '0'))
                    if not 0 < size <= 8192: raise ValueError()
                    data = json.loads(environ['wsgi.input'].read(size))
                    if not isinstance(data, dict): raise ValueError()
                except (ValueError, TypeError):
                    raise APIError(400, '잘못된 요청입니다.') from None
                record = validate_record(data, int(time.time() * 1000))
                pid = self.hive.authenticate(environ, data)
                self.store.accept(pid, record)
                try:
                    self.store.flush(self.hive, 10)
                except APIError:
                    pass # Durable outbox is retried by the worker and client.
                pending = self.store.pending(pid)
                status, value = (202 if pending else 200), {'pending': pending}
                self._cache_at = 0
            else:
                raise APIError(404, '페이지를 찾을 수 없습니다.')
        except APIError as exc:
            status, value = exc.status, {'message': exc.message}
        except Exception:
            status, value = 500, {'message': '랭킹 서버 오류입니다. 잠시 후 다시 시도해 주세요.'}
        payload = json.dumps(value, ensure_ascii=False).encode()
        reasons = {200:'OK',202:'Accepted',400:'Bad Request',401:'Unauthorized',404:'Not Found',500:'Internal Server Error',502:'Bad Gateway'}
        start_response(f'{status} {reasons[status]}', [('Content-Type','application/json; charset=utf-8'),('Content-Length',str(len(payload))),('Cache-Control','no-store')])
        return [payload]


def create_app():
    zone = os.environ.get('HIVE_ZONE', 'sandbox')
    if zone not in ('sandbox', 'live'):
        raise ValueError('HIVE_ZONE must be sandbox or live')
    hive = HiveAPI(os.environ.get('HIVE_APP_ID'), os.environ.get('HIVE_LEADERBOARD_ID', DEFAULT_LEADERBOARD_ID), os.environ.get('HIVE_CERTIFICATION_KEY'), zone == 'sandbox')
    db_path = os.environ.get('RANKING_DB_PATH', 'data/ranking.sqlite3')
    os.makedirs(os.path.dirname(os.path.abspath(db_path)), exist_ok=True)
    store = RecordStore(db_path)
    def retry():
        while True:
            try: store.flush(hive)
            except Exception: pass # No credentials or player data in logs.
            time.sleep(30)
    threading.Thread(target=retry, daemon=True).start()
    return Application(hive, store)


if __name__ == '__main__':
    from wsgiref.simple_server import make_server
    # Local development only. Deploy WSGI behind HTTPS for the game client.
    with make_server('127.0.0.1', int(os.environ.get('PORT','8787')), create_app()) as server:
        server.serve_forever()
