#!/usr/bin/env python3
"""Build JellyMon assets from Sound Studio downloads. Requires numpy, soundfile.
Input jobs.json and source WAVs stay outside exported resources in tmp/.
"""
import argparse
import hashlib
import io
import subprocess
import json
from pathlib import Path
import numpy as np
import soundfile as sf


def rms(x):
    return float(np.sqrt(np.mean(x.astype(np.float64) ** 2)))


def estimate_bpm(x, sr, requested):
    hop = round(sr * .01)
    mono = np.mean(x, axis=1)
    frames = np.lib.stride_tricks.sliding_window_view(mono, 2048)[::hop]
    spectrum = np.abs(np.fft.rfft(frames * np.hanning(2048), axis=1))
    onset = np.maximum(np.diff(np.log1p(spectrum * 10), axis=0), 0).mean(axis=1)
    onset -= onset.mean()
    ticks = np.arange(len(onset))
    best = (-float('inf'), requested)
    for bpm in np.arange(requested * .88, requested * 1.12, .05):
        lag = 60 * sr / (bpm * hop)
        score = 0.0
        for multiple in [1, 2, 4, 8]:
            shift = lag * multiple
            end = len(onset) - int(np.ceil(shift))
            score += float(np.mean(onset[:end] * np.interp(ticks[:end] + shift, ticks, onset)))
        if score > best[0]: best = (score, float(bpm))
    return best[1], best[0] / max(float(np.mean(onset**2)) * 4, 1e-12)


def loop_music(x, sr, bpm):
    # Preserve exactly 16 bars. Compare endpoint windows, then overlap a full
    # beat of the outgoing tail with the matching incoming head. No silent fades.
    measured_bpm, confidence = estimate_bpm(x, sr, bpm)
    effective_bpm = measured_bpm if confidence > .08 else bpm
    length = round(16 * 4 * 60 / effective_bpm * sr)
    overlap = round(60 / effective_bpm * sr)
    first = round(6 * sr)
    last = len(x) - length - overlap - round(2 * sr)
    if last < first:
        raise ValueError('Source too short for a 16-bar loop with handles')
    best = None
    window = np.hanning(overlap)[:, None]
    for start in range(first, last + 1, max(1, round(sr * .1))):
        a, b = x[start:start+overlap], x[start+length:start+length+overlap]
        # Spectral shape and energy proximity avoid joining unrelated sections.
        sa = np.log1p(np.abs(np.fft.rfft(a * window, axis=0))[::32])
        sb = np.log1p(np.abs(np.fft.rfft(b * window, axis=0))[::32])
        score = float(np.mean((sa-sb)**2)) + 3 * abs(np.log((rms(a)+1e-6)/(rms(b)+1e-6)))
        if best is None or score < best[0]:
            best = (score, start)
    start = best[1]
    end = start + length
    t = np.linspace(0, 1, overlap)[:, None]
    # Smooth complementary weights retain level for correlated musical phrases.
    w = .5 - .5 * np.cos(np.pi * t)
    blend = x[end:end+overlap] * (1-w) + x[start:start+overlap] * w
    y = np.concatenate((x[start+overlap:end], blend))
    return y, {'source_start_s':start/sr, 'bars':16, 'requested_bpm':bpm,
               'estimated_bpm':measured_bpm,'effective_bpm':effective_bpm,'tempo_confidence':confidence,
               'overlap_s':overlap/sr, 'method':'tail-to-head raised-cosine overlap, no silence'}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, default=Path('tmp/audio-generation'))
    parser.add_argument('--output', type=Path, default=Path('audio'))
    parser.add_argument('--manifest', type=Path, default=Path('docs/AUDIO_ASSET_MANIFEST.json'))
    parser.add_argument('--partial', action='store_true', help='Process downloaded jobs while the queue is running')
    args = parser.parse_args()
    entries = json.loads((args.source/'jobs.json').read_text())
    report = []
    for entry in entries:
        if not entry.get('downloaded'):
            if args.partial:
                continue
            raise ValueError('Incomplete generation: '+entry['name'])
        path = args.source/(entry['name']+'.wav')
        x, sr = sf.read(path, always_2d=True, dtype='float32')
        if not np.isfinite(x).all() or rms(x) < .0001:
            raise ValueError('Invalid/silent source: '+str(path))
        derivation = entry.get('derivation')
        if derivation:
            import imageio_ffmpeg
            factor = float(derivation['tempo_factor'])
            if not .5 <= factor <= 2: raise ValueError('Unsupported tempo factor')
            rendered = subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), '-v', 'error', '-i', str(path),
                '-af', f'atempo={factor}', '-f', 'wav', '-acodec', 'pcm_f32le', 'pipe:1'],
                check=True, capture_output=True).stdout
            x, sr = sf.read(io.BytesIO(rendered), always_2d=True, dtype='float32')
        x -= np.mean(x, axis=0)
        processing = {}
        if entry['kind'] == 'bgm':
            x, processing = loop_music(x, sr, entry['bpm'])
            target_rms, peak_limit = float(entry.get('target_rms', .12)), .75
            if derivation: processing['derivation'] = derivation
            processing['target_rms'] = target_rms
            dest = args.output/'bgm'/(entry['name']+'.ogg')
        else:
            x = np.mean(x, axis=1, keepdims=True)
            # Remove generated lead-in/tail silence; keep 5ms attack / 60ms tail.
            envelope = np.abs(x[:, 0])
            audible = np.flatnonzero(envelope > max(.001, float(envelope.max())*.018))
            lo, hi = max(0,int(audible[0])-round(sr*.005)), min(len(x),int(audible[-1])+round(sr*.06))
            x = x[lo:hi]
            fade = min(round(sr*.004), len(x)//4)
            x[:fade] *= np.linspace(0,1,fade)[:,None]
            x[-fade:] *= np.linspace(1,0,fade)[:,None]
            target_rms, peak_limit = (.11,.6) if entry['name'] in ['grab','ui_click','lock','pop'] else (.16,.8)
            dest = args.output/(entry['name']+'.wav')
            processing = {'trim_start_s':lo/sr,'trim_end_s':hi/sr,'edge_fade_ms':4,'mono':True}
        gain = min(target_rms / max(rms(x),1e-8), peak_limit / max(float(np.abs(x).max()),1e-8))
        x *= gain
        dest.parent.mkdir(parents=True,exist_ok=True)
        sf.write(dest,x,sr,subtype='VORBIS' if entry['kind']=='bgm' else 'PCM_16')
        decoded, rate = sf.read(dest,always_2d=True)
        peak = float(np.abs(decoded).max())
        level = rms(decoded)
        if peak >= .999 or level < .005:
            raise ValueError('Invalid mastered audio: '+str(dest))
        metrics = {'path':str(dest),'seconds':len(decoded)/rate,'bytes':dest.stat().st_size,
                   'sample_rate':rate,'channels':decoded.shape[1],'peak':peak,'rms':level}
        if entry['kind']=='bgm':
            seam = float(np.abs(decoded[0]-decoded[-1]).max())
            normal = float(np.percentile(np.abs(np.diff(decoded,axis=0)),99.9))
            metrics.update(seam_step=seam, interior_step_p999=normal)
            if seam > max(.035,normal*2):
                raise ValueError('Loop seam exceeds natural transients: '+str(dest))
        report.append({'name':entry['name'],'kind':entry['kind'],'request':entry['request'],
                       'job_id':entry['job']['id'],'asset_id':entry['job']['asset_id'],
                       'generation_prompt':entry['job'].get('generation_prompt'),
                       'source_metadata':entry.get('asset'),
                       'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                       'output_sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),
                       'processing':processing,'metrics':metrics})
        print(entry['name'],json.dumps(metrics),flush=True)
    (args.source/'processed.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')

if __name__=='__main__':main()
