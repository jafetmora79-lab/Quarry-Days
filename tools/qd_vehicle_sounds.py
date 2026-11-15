#!/usr/bin/env python3
"""Quarry Days machinery sounds, synthesized (deterministic, no samples).

    blender -b --factory-startup -P tools/qd_vehicle_sounds.py     (uses Blender's bundled numpy; plain python needs numpy installed)

Writes 16-bit mono 22.05 kHz WAVs into audio/: engine_loop, hydraulic_loop (exactly 1 s, seamless), engine_start, engine_stop,
dig_scrape, dump_clatter. Same helpers and style as tools/qd_sounds.py (chunky, low-fi, warm).
"""
import os
import wave

import numpy as np

SR = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audio")
rng = np.random.default_rng(11)


def t(sec): return np.arange(int(SR * sec)) / SR


def lowpass(x, k):
    y = np.zeros_like(x); acc = 0.0
    for i, v in enumerate(x):
        acc += k * (v - acc); y[i] = acc
    return y


def noise(sec): return rng.uniform(-1, 1, int(SR * sec))


def loopify(x, fade=0.06):
    """Crossfade the tail into the head so a 1 s loop has no click."""
    n = int(SR * fade)
    y = x[:-n].copy()
    ramp = np.linspace(0, 1, n)
    y[:n] = y[:n] * ramp + x[-n:] * (1 - ramp)
    return y


def write(name, x, gain=0.8):
    x = x / max(1e-6, np.max(np.abs(x))) * gain
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def firing(rate, sec, wobble=0.0):
    """Diesel chug: a decaying low burst per cylinder firing; `rate` may be an array of Hz per sample."""
    n = int(SR * sec)
    r = np.full(n, float(rate)) if np.isscalar(rate) else rate
    phase = np.cumsum(r) / SR
    out = np.zeros(n)
    frac = phase - np.floor(phase)
    shape = np.exp(-frac * 9.0) * (1 - np.exp(-frac * 120.0))                      # one burst per cycle
    tone = np.sin(2 * np.pi * np.cumsum(r * 2.2) / SR) + 0.5 * np.sin(2 * np.pi * np.cumsum(r * 4.4) / SR)
    out = shape * (tone + lowpass(noise(sec), 0.18) * 1.6 + wobble * np.sin(2 * np.pi * np.cumsum(r * 0.5) / SR))
    return lowpass(out, 0.35)


def main():
    # diesel idle: 24 firings/s, seamless 1 s loop
    x = loopify(firing(24.0, 1.06))
    write("engine_loop", x, 0.8)
    # hydraulic pump + flow: whine with a slow throb and a little hiss, seamless
    s = t(1.06)
    w = np.sin(2 * np.pi * 330 * s) * 0.5 + np.sin(2 * np.pi * 660 * s) * 0.25 + np.sin(2 * np.pi * 990 * s) * 0.1
    w *= 0.75 + 0.25 * np.sin(2 * np.pi * 7 * s)
    w += lowpass(noise(1.06), 0.5) * 0.35
    write("hydraulic_loop", loopify(w), 0.7)
    # engine start: starter crank, two coughs, catch and settle into idle
    n = int(SR * 2.1)
    rate = np.interp(np.arange(n) / SR, [0, 0.9, 1.0, 1.15, 1.3, 1.6, 2.1], [7, 8.5, 3, 11, 5, 17, 24])
    chug = firing(rate, 2.1)
    s = t(2.1)
    starter = (np.sin(2 * np.pi * np.cumsum(np.interp(s, [0, 0.9, 1.0], [95, 120, 0])) / SR) + lowpass(noise(2.1), 0.6) * 0.4) * np.interp(s, [0, 0.05, 0.85, 1.0], [0, 1, 1, 0])
    amp = np.interp(s, [0, 0.9, 1.3, 1.6, 2.1], [0.35, 0.5, 0.75, 0.95, 1.0])
    write("engine_start", chug * amp + starter * 0.55, 0.85)
    # engine stop: firing slows down, a last shudder and a metal tick
    n = int(SR * 1.5)
    s = t(1.5)
    rate = np.interp(s, [0, 0.7, 1.2, 1.5], [24, 15, 5, 2.2])
    stop = firing(rate, 1.5) * np.interp(s, [0, 0.8, 1.5], [1.0, 0.7, 0.0])
    tick = np.exp(-np.maximum(0, s - 1.18) * 60) * (s > 1.18) * np.sin(2 * np.pi * 540 * s) * 0.35
    write("engine_stop", stop + tick, 0.8)
    # bucket scraping into gravel: gritty sweep with a low thud at the start
    s = t(0.5)
    g = lowpass(noise(0.5), 0.45) - lowpass(noise(0.5), 0.05) * 0.8
    g *= np.interp(s, [0, 0.03, 0.3, 0.5], [0, 1, 0.8, 0])
    thud = np.sin(2 * np.pi * 95 * s) * np.exp(-s * 24)
    write("dig_scrape", g * 0.9 + thud * 0.8, 0.8)
    # dumping a load: rubble clatter that thins out, over a soft rumble
    s = t(1.0)
    out = lowpass(noise(1.0), 0.12) * np.interp(s, [0, 0.12, 0.5, 1.0], [0, 0.9, 0.35, 0]) * 0.8
    times = np.sort(np.concatenate([rng.uniform(0.0, 0.45, 12), rng.uniform(0.45, 0.95, 5)]))
    for tt in times:
        i = int(tt * SR); m = int(SR * 0.09)
        f = rng.uniform(180, 780)
        k = np.arange(m) / SR
        out[i:i + m] += (np.sin(2 * np.pi * f * k) * 0.6 + lowpass(noise(0.09), 0.5)[:m]) * np.exp(-k * 45) * rng.uniform(0.4, 1.0)
    write("dump_clatter", out, 0.85)
    print("wrote engine_loop, hydraulic_loop, engine_start, engine_stop, dig_scrape, dump_clatter ->", OUT)


if __name__ == "__main__":
    main()
