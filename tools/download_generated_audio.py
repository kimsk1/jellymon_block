#!/usr/bin/env python3
"""Recover the exact generated WAVs from the project's audio manifest.
Does not submit new generation jobs or overwrite existing source WAVs.
"""
import argparse
import hashlib
import json
from pathlib import Path
import urllib.request


def get_json(url):
    with urllib.request.urlopen(url, timeout=30) as response:
        return json.load(response)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--base-url', default='http://10.10.4.71:8991')
    parser.add_argument('--output', type=Path, default=Path('tmp/audio-generation'))
    parser.add_argument('--manifest', type=Path, default=Path('docs/AUDIO_ASSET_MANIFEST.json'))
    args = parser.parse_args()
    entries = json.loads(args.manifest.read_text())
    args.output.mkdir(parents=True, exist_ok=True)
    jobs = []
    for entry in entries:
        asset_id = entry['asset_id']
        path = args.output/(entry['name']+'.wav')
        if not path.exists():
            with urllib.request.urlopen(args.base_url.rstrip('/')+'/api/assets/'+asset_id+'/file', timeout=90) as response:
                data = response.read()
            if hashlib.sha256(data).hexdigest() != entry['source_sha256']:
                raise ValueError('Downloaded source hash mismatch: '+entry['name'])
            path.write_bytes(data)
        elif hashlib.sha256(path.read_bytes()).hexdigest() != entry['source_sha256']:
            raise ValueError('Existing source differs; choose another --output: '+str(path))
        job = get_json(args.base_url.rstrip('/')+'/api/jobs/'+entry['job_id'])
        if job['status'] != 'completed' or job['asset_id'] != asset_id:
            raise ValueError('Server job no longer matches manifest: '+entry['name'])
        item = {'name':entry['name'],'kind':entry['kind'],'request':entry['request'],
                'job':job,'asset':entry['source_metadata'],'downloaded':True}
        if entry['kind']=='bgm':
            item['bpm'] = entry['processing']['requested_bpm']
            if 'derivation' in entry['processing']: item['derivation'] = entry['processing']['derivation']
            if 'target_rms' in entry['processing']: item['target_rms'] = entry['processing']['target_rms']
        jobs.append(item)
        print(entry['name'], 'verified')
    (args.output/'jobs.json').write_text(json.dumps(jobs,ensure_ascii=False,indent=2)+'\n')

if __name__=='__main__':main()
