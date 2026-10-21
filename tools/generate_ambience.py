#!/usr/bin/env python3
"""Generate looping wind/water ambience for the bridge slice (CC0 by design)."""
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SAMPLE_RATE = 44100
DURATION = 8.0
CROSSFADE = 0.75


def one_pole(samples, alpha):
    out = []
    value = 0.0
    for sample in samples:
        value += alpha * (sample - value)
        out.append(value)
    return out


def normalize(samples, peak=0.32):
    high = max(abs(s) for s in samples) or 1.0
    return [s / high * peak for s in samples]


def crossfade_loop(samples, fade_samples):
    n = len(samples)
    for i in range(fade_samples):
        t = i / fade_samples
        samples[n - fade_samples + i] = samples[n - fade_samples + i] * (1.0 - t) + samples[i] * t
    return samples


def write_wav(path, samples):
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for sample in samples:
            value = int(max(-1.0, min(1.0, sample)) * 32767)
            frames += struct.pack("<h", value)
        handle.writeframes(frames)


def wind():
    random.seed(20261021)
    n = int(SAMPLE_RATE * DURATION)
    noise = [random.uniform(-1.0, 1.0) for _ in range(n)]
    shaped = one_pole(noise, 0.08)
    out = []
    for i, value in enumerate(shaped):
        t = i / SAMPLE_RATE
        swell = 0.55 + 0.45 * math.sin(2 * math.pi * 0.07 * t + 0.8)
        gust = 0.15 * math.sin(2 * math.pi * 0.19 * t)
        out.append(value * (swell + gust))
    return normalize(crossfade_loop(out, int(CROSSFADE * SAMPLE_RATE)))


def water():
    random.seed(777)
    n = int(SAMPLE_RATE * DURATION)
    value = 0.0
    brown = []
    for _ in range(n):
        value = value * 0.985 + random.uniform(-1.0, 1.0) * 0.08
        brown.append(value)
    shimmer = one_pole([random.uniform(-1.0, 1.0) for _ in range(n)], 0.5)
    out = []
    for i, value in enumerate(brown):
        t = i / SAMPLE_RATE
        lap = 0.6 + 0.4 * math.sin(2 * math.pi * 0.11 * t + 1.7)
        out.append(value * lap + shimmer[i] * 0.06)
    return normalize(crossfade_loop(out, int(CROSSFADE * SAMPLE_RATE)), 0.22)


def main():
    sounds = ROOT / "sounds"
    sounds.mkdir(exist_ok=True)
    write_wav(sounds / "ambience_wind.wav", wind())
    write_wav(sounds / "ambience_water.wav", water())
    print("wrote ambience_wind.wav and ambience_water.wav")


if __name__ == "__main__":
    main()
