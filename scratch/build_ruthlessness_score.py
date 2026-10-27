"""Build an adaptive local score from the exact user-provided reference MP4.

No remote source, pitch shifting, source separation model, or generated music.
Run with --analyze to inspect beat-grid candidates without exporting the score.
"""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import sys
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scratch/athena_animatic_preview/python_deps'))
import imageio_ffmpeg

SOURCE = Path(r'C:\Users\leiac\Downloads\vidssave.com Ruthlessness _ EPIC The Musical _ Animatic 720P.mp4')
OUT = ROOT / 'Assets/act4_poseidon_escape/music'
SR = 44100
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
BPM = 113.25
BEAT = 60.0 / BPM
LOOP_SAMPLES = round(SR * BEAT * 16)  # Four bars of the instrumental escape pulse.
INSTRUMENTAL_START = 239.711
WIND_RELEASE = 3.273
ESCAPE_DURATION = 16.35
CROSSFADE = .088

CUTS = [
    dict(id='impact_intro', start=21.6, end=24.24, loop=False,
         musical_role='Opening Poseidon call only, isolated before the first verse',
         cues=[]),
    dict(id='vamp_surge', start=INSTRUMENTAL_START, samples=LOOP_SAMPLES, loop=True,
         musical_role='Instrumental aftermath of the wind release, first phrase', cues=[]),
    dict(id='vamp_wrecks', start=INSTRUMENTAL_START + BEAT * 8,
         samples=LOOP_SAMPLES, loop=True,
         musical_role='Overlapping instrumental phrase shifted by two bars', cues=[]),
    dict(id='vamp_wrath', start=INSTRUMENTAL_START + BEAT * 12,
         samples=LOOP_SAMPLES, loop=True,
         musical_role='Overlapping later instrumental phrase, before Remember me', cues=[]),
]



def decode():
    cmd = [FFMPEG, '-hide_banner', '-loglevel', 'error', '-i', str(SOURCE),
           '-vn', '-ac', '2', '-ar', str(SR), '-f', 'f32le', '-']
    raw = subprocess.run(cmd, check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype='<f4').reshape(-1, 2).copy()


def onset_curve(audio, start, end):
    sr = SR / 4
    mono = audio[round(start * SR):round(end * SR):4].mean(axis=1)
    n, hop = 2048, 128
    frames = np.lib.stride_tricks.sliding_window_view(mono, n)[::hop]
    spectrum = np.abs(np.fft.rfft(frames * np.hanning(n), axis=1))
    # Spectral flux above 70 Hz. Log compression reduces single loud impacts.
    spectrum = np.log1p(15 * spectrum)
    spectrum[:, :13] = 0
    flux = np.maximum(0, np.diff(spectrum, axis=0)).sum(axis=1)
    flux -= np.percentile(flux, 30)
    flux = np.maximum(flux, 0)
    return (start + np.arange(len(flux)) * hop / sr), flux, hop / sr


def analyze(audio):
    for start, end in [(181, 204), (184, 197), (205, 234), (239, 253), (30, 150)]:
        times, flux, step = onset_curve(audio, start, end)
        centered = flux - flux.mean()
        ac = np.correlate(centered, centered, mode='full')[len(flux) - 1:]
        candidates = []
        for lag in range(round(.25 / step), round(1.0 / step)):
            if ac[lag] > ac[lag - 1] and ac[lag] >= ac[lag + 1]:
                candidates.append((float(ac[lag] / ac[0]), round(60 / (lag * step), 3)))
        print(start, end, 'BPM autocorrelation candidates:', sorted(candidates, reverse=True)[:8])
        # Strong flux peaks are an objective cue list, not automatically downbeats.
        peaks = np.where((flux[1:-1] > flux[:-2]) & (flux[1:-1] >= flux[2:]))[0] + 1
        strong = sorted(peaks, key=lambda j: -flux[j])[:35]
        print('Strong transients:', [round(float(times[j]), 3) for j in sorted(strong)])


def amp_db(value):
    return float(20 * np.log10(max(float(value), 1e-12)))


def metrics(audio, loop=False):
    rms = float(np.sqrt(np.mean(audio.astype(np.float64) ** 2)))
    peak = float(np.max(np.abs(audio)))
    result = dict(peak_dbfs=round(amp_db(peak), 4), rms_dbfs=round(amp_db(rms), 4),
                  dc_per_channel=[round(float(v), 8) for v in audio.mean(axis=0)],
                  clipped_samples=int(np.sum(np.abs(audio) >= .9999)))
    if loop:
        step = float(np.max(np.abs(audio[0] - audio[-1])))
        near = np.concatenate((audio[-441:], audio[:441]))
        natural = float(np.percentile(np.max(np.abs(np.diff(near, axis=0)), axis=1), 99))
        result.update(seam_step_dbfs=round(amp_db(step), 4),
                      seam_step_vs_nearby_99th=round(step / max(natural, 1e-9), 4),
                      head_rms_dbfs=round(amp_db(np.sqrt(np.mean(audio[:4410] ** 2))), 4),
                      tail_rms_dbfs=round(amp_db(np.sqrt(np.mean(audio[-4410:] ** 2))), 4))
    return result


def write_wav(path, audio):
    pcm = np.round(np.clip(audio, -.9999, .9999) * 32767).astype('<i2')
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def write_ogg(path, audio):
    subprocess.run([FFMPEG, '-hide_banner', '-loglevel', 'error', '-y',
                    '-f', 'f32le', '-ar', str(SR), '-ac', '2', '-i', '-',
                    '-c:a', 'libvorbis', '-q:a', '5', '-metadata',
                    'comment=Local gameplay adaptation of the user-provided reference audio', str(path)],
                   input=audio.astype('<f4').tobytes(), check=True)


def decode_ogg(path):
    r = subprocess.run([FFMPEG, '-hide_banner', '-loglevel', 'error', '-i', str(path),
                        '-f', 'f32le', '-ac', '2', '-ar', str(SR), '-'],
                       capture_output=True, check=True)
    return np.frombuffer(r.stdout, dtype='<f4').reshape(-1, 2)


def build(audio):
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = dict(
        version=2,
        source_file=str(SOURCE), source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        source_duration_seconds=round(len(audio) / SR, 6), source_channels=2,
        sample_rate=SR, source_encoding='AAC stereo from the exact attached MP4',
        method='PCM extraction; opening Poseidon call; instrumental-only escape-source phrase loops; 88 ms tail-to-preroll crossfade; no time stretch, pitch change or vocal cancellation',
        analysis='Log-compressed spectral-flux autocorrelation of the real PCM, source ASR for approximate narrative labels',
        perceptual_review='No full human listening review performed by this build script. Listen to preview_wrath_7s.wav and preview_score.ogg before final mix approval.',
        nominal_bpm=BPM, beats_per_bar=4, beat_seconds=BEAT,
        notes=[
            '113.25 BPM is a nominal gameplay pulse fitted to the instrumental tail. Spectral-flux autocorrelation gives a broad maximum near 112.35 BPM; this is an authored grid, not an assertion of exact performed tempo.',
            'The opening contains repeated Poseidon calls. Old source 8.893-23.115 loops were not clean instrumental and are no longer used.',
            'All gameplay and escape music comes from 239.711-254.54545, after the bag line and What, before Remember me at 255.92. No original post-verdict chorus or bag dialogue remains.',
            'The three four-bar loops intentionally overlap within this short instrumental passage; there is no claim of newly composed orchestration or separate stems.',
            'The opening call is selected from 21.6-24.24 using reference narrative timing. ASR alone cannot certify word boundaries or musical quality.',
            'Escape wind_release at 3.273 is now an authored musical cue, with the phrase downbeat edited onto it; it is not the original source wind transient.',
            'Crossfades prevent waveform clicks but do not establish perceptually seamless musical repetition. No subjective listening was possible in this execution environment.',
        ],
        section_map=dict(surge='vamp_surge', wrecks='vamp_wrecks', onslaught='vamp_wrath',
                         bag='vamp_wrath', escape='escape_release'), clips={})
    generated = {}
    for spec in CUTS:
        start = round(spec['start'] * SR)
        count = spec.get('samples', round((spec.get('end', spec['start']) - spec['start']) * SR))
        end = start + count
        clip = audio[start:end].copy()
        before = metrics(clip, spec['loop'])
        if spec['loop']:
            n = round(CROSSFADE * SR)
            t = np.linspace(0, 1, n, dtype=np.float64)
            weight = (t * t * (3 - 2 * t))[:, None]
            # Preserve the exact four-bar duration. The last 88 ms gradually
            # becomes the true source preroll immediately before this clip.
            # Therefore the wrap itself uses adjacent original PCM samples.
            clip[-n:] = clip[-n:] * (1 - weight) + audio[start - n:start] * weight
        else:
            # A short edge fade removes edit clicks; the escape has an audible tail.
            fade_in = round(.008 * SR)
            fade_out = round(.025 * SR)
            clip[:fade_in] *= np.linspace(0, 1, fade_in)[:, None]
            clip[-fade_out:] *= np.linspace(1, 0, fade_out)[:, None]
        clip -= clip.mean(axis=0)
        rms = np.sqrt(np.mean(clip.astype(np.float64) ** 2))
        # Match broad clip loudness, retain source dynamics, reserve mix headroom.
        gain_db = float(np.clip(-18.5 - amp_db(rms), -24.0, 3.0))
        gain = 10 ** (gain_db / 20)
        gain = min(gain, .88 / max(float(np.max(np.abs(clip))), 1e-9))
        clip *= gain
        path = OUT / (spec['id'] + '.ogg')
        write_ogg(path, clip)
        decoded = decode_ogg(path)
        entry = dict(file=path.name, sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                     source_start_seconds=round(start / SR, 6), source_end_seconds=round(end / SR, 6),
                     duration_seconds=round(count / SR, 9), samples=count,
                     decoded_samples=len(decoded), loop=spec['loop'], musical_role=spec['musical_role'],
                     gain_db=round(amp_db(gain), 4), raw_pcm_metrics=before,
                     edited_pcm_metrics=metrics(clip, spec['loop']),
                     vorbis_metrics=metrics(decoded, spec['loop']),
                     cue_points=[dict(id=label, seconds=round(at - start / SR, 6),
                                      source_seconds=at) for label, at in spec['cues']])
        if spec['loop']:
            entry.update(bpm=BPM, beats=16, bars=4, beat_seconds=BEAT,
                         loop_start_seconds=0, loop_end_seconds=count / SR,
                         crossfade_seconds=CROSSFADE,
                         beat_times_seconds=[round(j * BEAT, 9) for j in range(16)])
        else:
            entry.update(bpm=BPM, tempo_confidence='nominal; source performance varies')
        manifest['clips'][spec['id']] = entry
        generated[spec['id']] = clip
        print(spec['id'], entry['duration_seconds'], entry['vorbis_metrics'])

    # A phrase downbeat lands on the established gameplay wind cue. This is
    # an instrumental arrangement of existing source PCM, without the bag line.
    loop = generated['vamp_surge']
    lead = round(WIND_RELEASE * SR)
    length = round(ESCAPE_DURATION * SR)
    escape = np.concatenate((loop[-lead:], loop, loop))[:length].copy()
    fade_in, fade_out = round(.008 * SR), round(.5 * SR)
    escape[:fade_in] *= np.linspace(0, 1, fade_in)[:, None]
    escape[-fade_out:] *= np.linspace(1, 0, fade_out)[:, None]
    escape -= escape.mean(axis=0)
    gain = 10 ** ((-18.5 - amp_db(np.sqrt(np.mean(escape.astype(np.float64) ** 2)))) / 20)
    escape *= min(gain, .88 / max(float(np.max(np.abs(escape))), 1e-9))
    path = OUT / 'escape_release.ogg'
    write_ogg(path, escape)
    decoded = decode_ogg(path)
    manifest['clips']['escape_release'] = dict(
        file=path.name, sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
        duration_seconds=len(escape)/SR, samples=len(escape), decoded_samples=len(decoded),
        loop=False, bpm=BPM, tempo_confidence='nominal; cue intentionally arranged',
        source_segments=[dict(source_start_seconds=INSTRUMENTAL_START,
                              source_end_seconds=INSTRUMENTAL_START+LOOP_SAMPLES/SR,
                              arrangement='Crossfaded source loop tail 3.273s, then repetitions; final 0.5s fade')],
        musical_role='Instrumental escape; phrase head enters at the authored wind release cue',
        edited_pcm_metrics=metrics(escape), vorbis_metrics=metrics(decoded),
        cue_points=[dict(id='wind_release', seconds=WIND_RELEASE,
                         origin='authored phrase entry, not a source narrative timestamp')])
    generated['escape_release'] = escape
    print('escape_release', len(escape)/SR, metrics(decoded))

    manifest['sections'] = {}
    section_clips = dict(intro='impact_intro', surge='vamp_surge', wrecks='vamp_wrecks',
                         onslaught='vamp_wrath', bag='vamp_wrath', escape='escape_release')
    for section, clip_id in section_clips.items():
        info = manifest['clips'][clip_id]
        item = dict(clip=clip_id, file=info['file'], duration=info['duration_seconds'],
                    beat_period=60 / info['bpm'], beats=16 if info['loop'] else 0,
                    loop=info['loop'])
        if section == 'intro':
            item['opening_call'] = True
        if section == 'escape':
            item['wind_release'] = next(c['seconds'] for c in info['cue_points'] if c['id'] == 'wind_release')
            item['beat_grid_is_nominal'] = True
        manifest['sections'][section] = item

    # Seven seconds crossing the wrath loop seam at precisely t=3 seconds.
    wrath = generated['vamp_wrath']
    preview = np.concatenate((wrath[-3 * SR:], wrath[:4 * SR]))
    write_wav(OUT / 'preview_wrath_7s.wav', preview)
    # A compact listening reel; one complete cycle plus one repeat per vamp.
    pieces = [generated['impact_intro']]
    for name in ('vamp_surge', 'vamp_wrecks', 'vamp_wrath'):
        pieces.extend((generated[name], generated[name]))
    pieces.append(generated['escape_release'])
    write_ogg(OUT / 'preview_score.ogg', np.concatenate(pieces))
    old_preview = OUT / 'preview_score.wav'
    if old_preview.exists():
        old_preview.unlink()  # Only the obsolete preview created by this script.
    (OUT / 'score.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    (OUT / 'README.md').write_text(README, encoding='utf-8')
    assert all(v['vorbis_metrics']['clipped_samples'] == 0 for v in manifest['clips'].values())
    assert all(v['decoded_samples'] == v['samples'] for v in manifest['clips'].values())
    assert max(v['vorbis_metrics']['rms_dbfs'] for v in manifest['clips'].values()) - min(
        v['vorbis_metrics']['rms_dbfs'] for v in manifest['clips'].values()) < .15
    print('Exported', len(generated), 'clips and 2 listening previews to', OUT)


README = """# Ruthlessness — opening call and instrumental gameplay revision

Rebuild from the exact local MP4 supplied by the user:

```powershell
& 'C:/Users/leiac/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' scratch/build_ruthlessness_score.py
```

`impact_intro.ogg` now isolates 21.6–24.24s, the opening call of Poseidon before
Poseidon's first verse. The gameplay loops no longer use the opening choir,
post-verdict chorus, bag dialogue or sung final refrain. The former opening
loops 8.893–23.115s contained repeated Poseidon calls and were replaced.

All three vamps come from the instrumental interval after the bag is opened
and before the next vocal entrance: source 239.711–254.54545s. They overlap on
purpose, using starts 239.711s, 243.949411s and 246.068616s. Four-bar cycles use a
nominal 113.25 BPM pulse, 16 beats, 8.476825s at 44.1kHz. This pulse approximates the
performed accents; it is not a claim of perfectly constant source tempo.

The final 16.35s `escape_release` is built from the instrumental surge loop:
its last 3.273s lead into the phrase head, followed by repetitions and a 0.5s
closing fade. Thus `wind_release: 3.273` remains the API cue, now an authored
phrase-entry point rather than the original narrative sound in the MP4.

There is no synthesized replacement music, pitch shift, time stretch,
source-separation dependency, voice cancellation, API call or download.
Source speech was avoided by selecting the existing instrumental passage.
The build preserves source stereo, normalizes broad RMS near −18.5dBFS and
crossfades the final 88ms of each loop toward its true source preroll.

`score.json` records source SHA-256, precise cuts, arranged segments, sample
counts, BPM/sections and PCM/Vorbis clipping, DC and seam checks. Every decoded
clip must have the expected sample count and zero clipping. Listen to
`preview_wrath_7s.wav` (loop join at 3s) or `preview_score.ogg` to review the edits.

No subjective listening was available in this execution environment. ASR was
used as supporting evidence only; it hallucinated low-confidence words during
instrumental material and did not reliably name the opening call. Source
narrative timing and absence of the recorded vocal verses delimit the chosen
instrumental interval. Objective audio checks do not replace a human listen.
"""

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--analyze', action='store_true')
    args = parser.parse_args()
    audio = decode()
    print('Decoded source:', len(audio) / SR, 's stereo', SR, 'Hz')
    if args.analyze:
        analyze(audio)
    else:
        build(audio)


if __name__ == '__main__':
    main()
