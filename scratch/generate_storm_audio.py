"""Deterministic original storm effects: stereo wind/waves and a thunder strike."""
from array import array
from pathlib import Path
import math
import random
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Assets" / "act4_storm"
RATE = 32000


def write(name, channels):
    peak = max(abs(v) for channel in channels for v in channel)
    gain = 0.85 / peak
    samples = array("h")
    for pair in zip(*channels):
        samples.extend(round(v * gain * 32767) for v in pair)
    if sys.byteorder != "little":
        samples.byteswap()
    with wave.open(str(OUT / name), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(samples.tobytes())
    rms = math.sqrt(sum(v * v for v in channels[0]) / len(channels[0])) * gain
    print(f"{name}: {len(channels[0]) / RATE:.1f}s, stereo, peak 0.85, RMS {rms:.3f}")


def wind_channel(seed, seconds, phase):
    rng = random.Random(seed)
    result = []
    low = mid = slow = 0.0
    for index in range(int(RATE * seconds)):
        t = index / RATE
        noise = rng.uniform(-1, 1)
        low += (noise - low) * 0.008
        mid += (noise - mid) * 0.075
        slow += (noise - slow) * 0.0013
        gust = 0.65 + 0.2 * math.cos(math.tau * t / seconds + phase)
        surf = (0.5 + 0.5 * math.sin(math.tau * 3 * t / seconds + phase)) ** 3
        hiss = noise - mid
        value = low * 2.3 * gust + slow * 2.7 + mid * 0.6 * surf + hiss * (0.028 + 0.10 * surf)
        result.append(value)
    # Smoothly connect the final 100ms to the first sample, without a loop click.
    seam = int(RATE * 0.1)
    start = result[0]
    for offset in range(seam):
        mix = 0.5 - 0.5 * math.cos(math.pi * offset / (seam - 1))
        index = len(result) - seam + offset
        result[index] = result[index] * (1 - mix) + start * mix
    return result


def thunder_channel(seed, phase):
    rng = random.Random(seed)
    result = []
    bass = body = 0.0
    for index in range(RATE * 6):
        t = index / RATE
        noise = rng.uniform(-1, 1)
        bass += (noise - bass) * 0.006
        body += (noise - body) * 0.06
        attack = min(t / 0.004, 1.0)
        tail = min((6 - t) / 0.5, 1.0)
        crack = noise * math.exp(-t * 35) * 0.8
        rolls = 0.65 + 0.35 * math.sin(t * 8.3 + phase) ** 2
        rumble = (bass * 5.2 + body * 0.9 + math.sin(math.tau * 42 * t + phase) * 0.045)
        result.append((crack + rumble * math.exp(-t * 0.72) * rolls) * attack * tail)
    return result


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    write("storm_loop.wav", [wind_channel(4201, 12, 0), wind_channel(4202, 12, 0.3)])
    write("thunder.wav", [thunder_channel(4301, 0), thunder_channel(4302, 0.2)])
