import io
import json
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from app import APIError, Application, EPOCH_MS, HiveAPI, MAX_LEVEL, RecordStore, score_for, validate_record

class FakeHive:
    def __init__(self): self.records = {}; self.fail = False; self.posts = []
    def authenticate(self, headers, data):
        if headers.get('HTTP_X_HIVE_ACCESS_TOKEN') != 'test-only': raise APIError(401, 'login')
        return str(data['player_id'])
    def submit(self, pid, record):
        if self.fail: raise APIError(502, 'offline')
        self.records[pid] = record.copy(); self.posts.append((pid,record.copy()))
    def top(self):
        rows = sorted((dict(player_id=p,**r) for p,r in self.records.items()), key=lambda r:(-r['level'],r['achieved_at_ms'],r['player_id']))[:100]
        return [dict(rank=i+1,**r) for i,r in enumerate(rows)]

def rec(level=50, at=EPOCH_MS+1000, stars=3, nickname='말랑'):
    return dict(level=level, achieved_at_ms=at, stars=stars, nickname=nickname)

class Tests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(); self.store=RecordStore(str(Path(self.tmp.name)/'rank.db')); self.hive=FakeHive(); self.app=Application(self.hive,self.store)
    def tearDown(self): self.tmp.cleanup()
    def call(self, path, data=None, token='test-only'):
        raw=json.dumps(data).encode() if data is not None else b''; status=[]
        response=self.app({'PATH_INFO':path,'REQUEST_METHOD':'POST' if data is not None else 'GET','CONTENT_LENGTH':str(len(raw)),'wsgi.input':io.BytesIO(raw),'HTTP_X_HIVE_ACCESS_TOKEN':token},lambda s,h:status.append(int(s.split()[0])))
        return status[0],json.loads(b''.join(response))
    def test_health_does_not_contact_hive(self):
        self.hive.top = lambda: self.fail('health must not query Hive')
        self.assertEqual(self.call('/healthz'), (200, {'status': 'ok'}))

    def test_bad_requests_do_not_write(self):
        self.assertEqual(self.call('/v1/ranking/record', [1, 2])[0], 400)
        self.assertEqual(self.call('/v1/ranking/record', {'nickname': 'x' * 9000})[0], 400)
        self.assertEqual(self.call('/unknown')[0], 404)
        self.assertEqual(self.hive.records, {})

    def test_three_stars_only_and_auth(self):
        for stars in [0,1,2,4,True]:
            self.assertEqual(self.call('/v1/ranking/record',dict(player_id='1',**rec(stars=stars)))[0],400)
        self.assertEqual(self.call('/v1/ranking/record',dict(player_id='1',**rec()),token='bad')[0],401)
        self.assertEqual(self.hive.records,{})
    def test_highest_then_earliest_and_no_duplicates(self):
        for pid,r in [('1',rec(99, EPOCH_MS+30)),('2',rec(100,EPOCH_MS+20)),('3',rec(100,EPOCH_MS+10)),('2',rec(1,EPOCH_MS+1)),('3',rec(100,EPOCH_MS+99))]:
            self.assertEqual(self.call('/v1/ranking/record',dict(player_id=pid,**r))[0],200)
        rows=self.call('/v1/ranking/top')[1]['entries']
        self.assertEqual([r['player_id'] for r in rows],['3','2','1'])
        self.assertEqual(rows[0]['achieved_at_ms'],EPOCH_MS+10)
    def test_top_100(self):
        for i in range(120): self.hive.records[str(i+1)]=rec(i+1)
        rows=self.call('/v1/ranking/top')[1]['entries']
        self.assertEqual(len(rows),100);self.assertEqual(rows[0]['level'],120);self.assertEqual(rows[-1]['level'],21)
    def test_offline_outbox_survives_restart(self):
        self.hive.fail=True
        status,_=self.call('/v1/ranking/record',dict(player_id='1',**rec()))
        self.assertEqual(status,202);self.assertTrue(self.store.pending('1'))
        self.hive.fail=False;RecordStore(self.store.path).flush(self.hive)
        self.assertEqual(self.hive.records['1']['level'],50)
    def test_concurrent_requests_keep_best(self):
        def submit(level): self.store.accept('1',rec(level));self.store.flush(self.hive)
        with ThreadPoolExecutor(max_workers=4) as pool: list(pool.map(submit,[100,98,105,102,99,120,119]))
        self.assertEqual(self.hive.records['1']['level'],120)
    def test_score_has_exact_millisecond_order_and_bounds(self):
        self.assertGreater(score_for(51,EPOCH_MS+20000),score_for(50,EPOCH_MS))
        self.assertGreater(score_for(50,EPOCH_MS+1),score_for(50,EPOCH_MS+2))
        self.assertLessEqual(score_for(MAX_LEVEL,EPOCH_MS),999999999999999)
        with self.assertRaises(APIError): validate_record(rec(at=EPOCH_MS+100000),EPOCH_MS)
    def test_hive_payload_and_response(self):
        api=HiveAPI('app','123','test-cert')
        calls=[]
        def request(url, method='GET', data=None, headers=None):
            calls.append((url,method,data,headers));return {}
        api.request=request;api.submit('7',rec())
        self.assertIn('/leaderboards/123/score',calls[0][0]);self.assertEqual(calls[0][2]['score'],score_for(50,EPOCH_MS+1000))
        self.assertEqual(json.loads(calls[0][2]['extraData'])['stars'],3)
        raw={'rank':1,'playerId':7,'score':score_for(50,EPOCH_MS+1000),'extraData':calls[0][2]['extraData']}
        api.request=lambda *a,**kw:{'rankingList':[raw]}
        self.assertEqual(api.top()[0]['nickname'],'말랑')
        raw['extraData']='{}'
        with self.assertRaises(APIError): api.top()
    def test_auth_v2_requires_both_success_codes(self):
        api=HiveAPI('app','123','test-cert');headers={'HTTP_X_HIVE_PLAYER_TOKEN':'p','HTTP_X_HIVE_ACCESS_TOKEN':'a'}
        api.request=lambda *a,**kw:{'result_code':0,'token_validation':{'result_code':1}}
        with self.assertRaises(APIError): api.authenticate(headers,{'player_id':'7','did':'d'})
        api.request=lambda *a,**kw:{'result_code':0,'token_validation':{'result_code':0}}
        self.assertEqual(api.authenticate(headers,{'player_id':'7','did':'d'}),'7')

if __name__=='__main__': unittest.main()
