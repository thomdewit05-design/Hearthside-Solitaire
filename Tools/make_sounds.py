#!/usr/bin/env python3
"""Synthesises Hearthside's soft sound effects (16-bit mono WAV, 44.1 kHz).
Everything is generated from scratch, so the sounds are our own work (CC0).
Run: python3 Tools/make_sounds.py  -> Hearthside/Resources/sounds/*.wav"""
import math, os, random, struct, wave

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Hearthside", "Resources", "sounds")


def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = 0.85 / peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))


def lowpass(samples, alpha):
    out, prev = [], 0.0
    for s in samples:
        prev = prev + alpha * (s - prev)
        out.append(prev)
    return out


def noise_burst(duration, decay, alpha, seed, body_freq=None):
    rng = random.Random(seed)
    n = int(RATE * duration)
    raw = [rng.uniform(-1, 1) * math.exp(-i / (RATE * decay)) for i in range(n)]
    samples = lowpass(raw, alpha)
    if body_freq:  # a little wooden "tock" from the table
        samples = [s + 0.6 * math.sin(2 * math.pi * body_freq * i / RATE) * math.exp(-i / (RATE * decay * 1.4))
                   for i, s in enumerate(samples)]
    fade = int(RATE * 0.004)
    return [s * min(1, i / fade) for i, s in enumerate(samples)]


def bell(freqs, duration, decay, delays=None):
    n = int(RATE * duration)
    out = [0.0] * n
    delays = delays or [0] * len(freqs)
    for f, d in zip(freqs, delays):
        start = int(RATE * d)
        for i in range(start, n):
            t = (i - start) / RATE
            env = math.exp(-t / decay) * min(1, t / 0.01)
            out[i] += env * (math.sin(2 * math.pi * f * t) + 0.3 * math.sin(2 * math.pi * f * 2.01 * t)
                             + 0.12 * math.sin(2 * math.pi * f * 3.02 * t))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    write("card_place", noise_burst(0.09, 0.012, 0.35, 1, body_freq=180))
    write("card_flip", noise_burst(0.06, 0.008, 0.55, 2))
    write("card_foundation", [a + 0.25 * b for a, b in zip(noise_burst(0.35, 0.012, 0.35, 3, body_freq=200),
                                                            bell([784], 0.35, 0.12))])
    shuffle = []
    for k in range(7):
        shuffle += noise_burst(0.05, 0.01, 0.5, 10 + k) + [0.0] * int(RATE * 0.015)
    write("shuffle", shuffle)
    write("win", bell([523.25, 659.25, 783.99, 1046.5], 2.2, 0.6, delays=[0, 0.12, 0.24, 0.36]))
    write("warmth", bell([659.25, 987.77], 1.0, 0.35, delays=[0, 0.08]))
    print("Wrote sounds to", OUT)


if __name__ == "__main__":
    main()
