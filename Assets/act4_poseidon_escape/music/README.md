# Ruthlessness — opening call and instrumental gameplay revision

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
