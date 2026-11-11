#!/usr/bin/env python3
"""Quarry Days Phase 5 sound effects, synthesized (no samples, deterministic).

    python3 tools/qd_sounds.py

Writes 16-bit mono 22.05 kHz WAVs into audio/. Loops (`*_loop.wav`) are exactly 1 s with whole-number
frequencies so they repeat seamlessly; the game sets their loop mode when it loads them.
"""
import os
import wave

import numpy as np

SR = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audio")
rng = np.random.default_rng(5)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(x, attack, decay):
    n = len(x)
    e = np.minimum(1.0, np.arange(n) / max(1, int(SR * attack)))
    return x * e * np.exp(-np.arange(n) / (SR * decay))


def lowpass(x, k):
    """cheap one-pole low-pass, k in (0, 1]: smaller = darker"""
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += k * (v - acc)
        y[i] = acc
    return y


def noise(sec):
    return rng.uniform(-1, 1, int(SR * sec))


def write(name, x, gain=0.8):
    x = x / max(1e-6, np.max(np.abs(x))) * gain
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def main():
    # hand hammer: dull wooden-handled thud on rock
    s = t(0.2)
    write("hit_hammer", env(np.sin(2 * np.pi * 150 * s) * 0.8 + lowpass(noise(0.2), 0.25), 0.002, 0.045), 0.75)
    # basic pickaxe: steel point on stone, short clink
    s = t(0.25)
    x = np.sin(2 * np.pi * 1180 * s) * 0.5 + np.sin(2 * np.pi * 2630 * s) * 0.25 + lowpass(noise(0.25), 0.5) * 0.8
    write("hit_pick", env(x, 0.001, 0.05) + env(np.sin(2 * np.pi * 190 * s), 0.002, 0.06), 0.8)
    # reinforced pickaxe: heavier, brighter clank with a short ring
    s = t(0.34)
    x = np.sin(2 * np.pi * 860 * s) * 0.6 + np.sin(2 * np.pi * 1940 * s) * 0.35 + np.sin(2 * np.pi * 3120 * s) * 0.15
    write("hit_reinforced", env(x, 0.001, 0.09) + env(lowpass(noise(0.34), 0.6), 0.001, 0.04) + env(np.sin(2 * np.pi * 120 * s), 0.002, 0.07), 0.85)
    # power drill loop: motor whine + grinding
    s = t(1.0)
    whine = np.sign(np.sin(2 * np.pi * 210 * s)) * 0.15 + np.sin(2 * np.pi * 420 * s) * 0.3 + np.sin(2 * np.pi * 630 * s) * 0.15
    grind = lowpass(noise(1.0), 0.35) * (0.6 + 0.4 * np.sin(2 * np.pi * 12 * s))
    write("drill_loop", whine + grind * 0.9, 0.6)
    # jackhammer loop: 18 blows per second, each a thump + chisel crack
    s = t(1.0)
    x = np.zeros_like(s)
    period = int(SR / 18)
    blow = env(np.sin(2 * np.pi * 95 * t(period / SR)) + lowpass(noise(period / SR), 0.55) * 0.9, 0.001, 0.012)
    for k in range(18):
        x[k * period:k * period + period] += blow[: len(x[k * period:k * period + period])]
    write("jackhammer_loop", x + np.sin(2 * np.pi * 60 * s) * 0.15, 0.7)
    # chunk breaking off: crumbling rock
    s = t(0.7)
    x = np.zeros_like(s)
    for k in range(14):
        at = int(SR * (0.02 + 0.045 * k + rng.uniform(0, 0.02)))
        grain = env(lowpass(noise(0.08), rng.uniform(0.2, 0.6)), 0.001, 0.02) * (1.0 - k / 16.0)
        x[at:at + len(grain)] += grain[: len(x[at:at + len(grain)])]
    write("rock_break", x + env(np.sin(2 * np.pi * 70 * s), 0.003, 0.12) * 0.7, 0.85)
    # reward pop: soft rising tick
    s = t(0.07)
    write("ui_pop", env(np.sin(2 * np.pi * (880 + 3000 * s) * s), 0.002, 0.025), 0.45)
    # sale: two-tone register chime
    s = t(0.42)
    x = env(np.sin(2 * np.pi * 988 * s) + 0.3 * np.sin(2 * np.pi * 1976 * s), 0.002, 0.09)
    x[int(SR * 0.09):] += env(np.sin(2 * np.pi * 1319 * s[: len(s) - int(SR * 0.09)]) + 0.3 * np.sin(2 * np.pi * 2638 * s[: len(s) - int(SR * 0.09)]), 0.002, 0.14)
    write("coin", x, 0.55)
    # unlock / milestone: short major arpeggio
    s = t(0.9)
    x = np.zeros_like(s)
    for k, f in enumerate([523, 659, 784, 1047]):
        at = int(SR * 0.11 * k)
        n = len(s) - at
        x[at:] += env(np.sin(2 * np.pi * f * s[:n]) + 0.25 * np.sin(2 * np.pi * 2 * f * s[:n]), 0.004, 0.22)
    write("unlock", x, 0.5)
    # drilling rig loop: diesel power pack + rotary bit
    s = t(1.0)
    diesel = np.sin(2 * np.pi * 46 * s) * (0.7 + 0.3 * np.sign(np.sin(2 * np.pi * 23 * s))) + np.sin(2 * np.pi * 92 * s) * 0.3
    bit = lowpass(noise(1.0), 0.2) * (0.5 + 0.5 * np.sin(2 * np.pi * 6 * s) ** 2)
    write("rig_loop", diesel * 0.7 + bit, 0.55)
    # rock breaker blow: hydraulic hammer hit
    s = t(0.45)
    write("breaker_hit", env(np.sin(2 * np.pi * 62 * s) + lowpass(noise(0.45), 0.4) * 0.8 + np.sin(2 * np.pi * 410 * s) * 0.2, 0.002, 0.08), 0.9)
    print("sounds written to", OUT)


if __name__ == "__main__":
    main()
