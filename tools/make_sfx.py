#!/usr/bin/env python3
"""Synthesised digging sounds (no recordings): deterministic, numpy only, 16-bit mono WAV at 22.05 kHz.

    python tools/make_sfx.py

Writes audio/dig_*.wav, three variants of each hit so repeated blows never sound identical:
  chink_N          a tool bouncing off rock: 8 ms noise burst + two decaying sines (2.2 kHz, 3.4 kHz, ~80 ms) with a slight pitch drop
  thud_soil_N      low sine (~90 Hz, ~120 ms) + low-passed noise: a spade into earth
  squelch_clay_N   noise through a low-pass whose cutoff sweeps down, with a short wet click
  crunch_gravel_N  5 short noise grains over ~150 ms
  crack_rock_N     noise burst, a 600 Hz body (~160 ms) and a high click: a pick breaking stone
  pour_dirt        a hiss of filtered noise (0.6 s);  pour_rock  clattering grains (0.6 s)
  scrape_metal     band-passed noise, a loop for a bucket grinding on rock
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio")


def t_axis(sec):
    return np.arange(int(SR * sec)) / SR


def lowpass(x, cutoff):
    """one-pole low-pass; cutoff may be an array (Hz) of the same length"""
    c = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = 1.0 - np.exp(-2.0 * np.pi * c / SR)
    y = np.zeros_like(x)
    s = 0.0
    for i in range(len(x)):
        s += a[i] * (x[i] - s)
        y[i] = s
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def env_exp(sec, decay):
    return np.exp(-t_axis(sec) / decay)


def norm(x, peak=0.8):
    m = np.max(np.abs(x))
    return x / m * peak if m > 0 else x


def save(name, x, loop=False):
    x = np.clip(x, -1.0, 1.0)
    fade = min(len(x) // 20, 200)
    if fade > 0 and not loop:
        x[-fade:] *= np.linspace(1, 0, fade)
    pcm = (x * 32767).astype("<i2")
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    return path


def chink(rng, k):
    sec = 0.28
    t = t_axis(sec)
    burst = rng.standard_normal(len(t)) * np.exp(-t / 0.004)
    f1, f2 = 2200 * (1 + 0.06 * (k - 1)), 3400 * (1 + 0.05 * (1 - k))
    drop = 1.0 - 0.04 * t / sec
    s = np.sin(2 * np.pi * f1 * t * drop) * np.exp(-t / 0.08) + 0.7 * np.sin(2 * np.pi * f2 * t * drop) * np.exp(-t / 0.06)
    s += 0.25 * np.sin(2 * np.pi * f1 * 1.5 * t) * np.exp(-t / 0.15)           # the faint ring
    return norm(0.5 * burst + s)


def thud_soil(rng, k):
    sec = 0.25
    t = t_axis(sec)
    f = 90 * (1 + 0.1 * (k - 1))
    body = np.sin(2 * np.pi * f * t * (1 - 0.3 * t / sec)) * np.exp(-t / 0.05)
    noise = lowpass(rng.standard_normal(len(t)), 700) * np.exp(-t / 0.04)
    return norm(body + 0.9 * noise)


def squelch_clay(rng, k):
    sec = 0.32
    t = t_axis(sec)
    cut = 2200 * np.exp(-t / 0.08) + 200
    n = lowpass(rng.standard_normal(len(t)), cut) * np.exp(-t / 0.1)
    click = np.sin(2 * np.pi * (500 + 120 * k) * t) * np.exp(-t / 0.006)
    return norm(n + 0.5 * click)


def crunch_gravel(rng, k):
    sec = 0.3
    out = np.zeros(int(SR * sec))
    for g in range(5):
        start = int(SR * (0.02 * g + rng.uniform(0, 0.012)))
        n = int(SR * rng.uniform(0.012, 0.03))
        grain = highpass(rng.standard_normal(n), 1500) * np.exp(-np.arange(n) / (SR * 0.006))
        out[start:start + n] += grain * rng.uniform(0.5, 1.0)
    return norm(out)


def crack_rock(rng, k):
    sec = 0.35
    t = t_axis(sec)
    burst = rng.standard_normal(len(t)) * np.exp(-t / 0.01)
    body = np.sin(2 * np.pi * 600 * (1 + 0.08 * (k - 1)) * t * (1 - 0.2 * t / sec)) * np.exp(-t / 0.055)
    click = highpass(rng.standard_normal(len(t)), 4000) * np.exp(-t / 0.003)
    return norm(0.7 * burst + body + 0.8 * click)


def pour(rng, rock):
    sec = 0.6
    t = t_axis(sec)
    if not rock:
        n = lowpass(highpass(rng.standard_normal(len(t)), 800), 5000) * (0.4 + 0.2 * np.sin(2 * np.pi * 6 * t))
        env = np.minimum(1, t / 0.08) * np.minimum(1, (sec - t) / 0.12)
        return norm(n * env, 0.5)
    out = np.zeros(len(t))
    for g in range(26):
        start = int(SR * rng.uniform(0, sec - 0.06))
        n = int(SR * rng.uniform(0.01, 0.03))
        out[start:start + n] += highpass(rng.standard_normal(n), 1200) * np.exp(-np.arange(n) / (SR * 0.006)) * rng.uniform(0.3, 1.0)
    return norm(out, 0.6)


def scrape_metal(rng):
    sec = 1.0
    t = t_axis(sec)
    n = rng.standard_normal(len(t))
    band = lowpass(highpass(n, 900), 3200)
    wob = 0.7 + 0.3 * np.sin(2 * np.pi * 7 * t)
    band += 0.3 * np.sin(2 * np.pi * 1450 * t) * wob
    x = band * wob
    fade = int(SR * 0.05)                                   # crossfade the ends so it loops without a click
    x[:fade] *= np.linspace(0, 1, fade)
    x[-fade:] *= np.linspace(1, 0, fade)
    return norm(x, 0.55)


def main():
    os.makedirs(OUT, exist_ok=True)
    made = []
    for name, fn in (("chink", chink), ("thud_soil", thud_soil), ("squelch_clay", squelch_clay), ("crunch_gravel", crunch_gravel), ("crack_rock", crack_rock)):
        for k in range(3):
            rng = np.random.default_rng(1000 + 10 * len(made) + k)
            made.append(save("dig_%s_%d" % (name, k), fn(rng, k)))
    made.append(save("dig_pour_dirt", pour(np.random.default_rng(71), False)))
    made.append(save("dig_pour_rock", pour(np.random.default_rng(72), True)))
    made.append(save("dig_scrape_metal", scrape_metal(np.random.default_rng(73)), loop=True))
    print("wrote", len(made), "files to", OUT)


if __name__ == "__main__":
    main()
