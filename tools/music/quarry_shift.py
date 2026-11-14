#!/usr/bin/env python3
"""'Quarry Shift' - semi-energetic lo-fi gameplay loop for Quarry Days (synthesized, numpy only).

94 BPM, swung 16ths, F major / D minor colour. Electric piano 7th chords, boom-bap drums, sub bass,
a small pixel hook, vinyl crackle, light sidechain pump. 32 bars, tail wrapped for a seamless loop.
Usage: python3 tools/music/quarry_shift.py audio/music/quarry_shift.wav
"""
import sys
import wave

import numpy as np

SR = 32000
BPM = 94.0
BEAT = 60.0 / BPM
BAR = BEAT * 4
SWING = 0.17 * BEAT / 2  # delay of every off-beat 16th / 8th (lazy lo-fi feel)
rng = np.random.default_rng(11)


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def t(sec):
    return np.arange(int(sec * SR)) / SR


def filt(x, lo=None, hi=None):
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    X = np.fft.rfft(x)
    if hi:
        X *= 1.0 / (1.0 + (f / hi) ** 4)
    if lo:
        X *= (f / lo) ** 2 / (1.0 + (f / lo) ** 2)
    return np.fft.irfft(X, len(x))


class Track:
    def __init__(self, seconds):
        self.buf = np.zeros(int(seconds * SR) + SR * 5)

    def add(self, start, sig, gain=1.0):
        i = int(start * SR)
        self.buf[i:i + len(sig)] += sig * gain


# ---------------------------------------------------------------- instruments

def epiano(m, dur, vel=1.0):
    """Rhodes-like FM tine: 1:1 modulator with a decaying index, a bell partial, gentle tremolo + wow."""
    tt = t(dur + 0.6)
    f = hz(m)
    wow = 1 + 0.0025 * np.sin(2 * np.pi * 0.6 * tt)
    ph = 2 * np.pi * f * np.cumsum(wow) / SR
    index = (1.4 * vel) * np.exp(-tt * 3.0) + 0.25
    s = np.sin(ph + index * np.sin(ph))
    s += 0.18 * np.sin(14 * ph) * np.exp(-tt * 18) * vel  # tine "ping"
    env = np.minimum(1, tt / 0.004) * np.exp(-tt * 0.9) * np.where(tt < dur, 1.0, np.exp(-(tt - dur) * 9))
    trem = 1 + 0.08 * np.sin(2 * np.pi * 4.5 * tt)
    return s * env * trem


def sub(m, dur):
    tt = t(dur + 0.08)
    f = hz(m)
    s = np.tanh(1.6 * (np.sin(2 * np.pi * f * tt) + 0.2 * np.sin(4 * np.pi * f * tt)))
    env = np.minimum(1, tt / 0.01) * np.exp(-tt * 0.7) * np.where(tt < dur, 1.0, np.exp(-(tt - dur) * 40))
    return s * env


def hook(m, dur):
    """Pixel pluck: soft triangle-ish square, fast decay, the chiptune wink."""
    tt = t(dur + 0.2)
    ph = 2 * np.pi * hz(m) * tt
    s = np.sin(ph) + np.sin(3 * ph) / 6 + np.sin(5 * ph) / 15
    return s * np.minimum(1, tt / 0.004) * np.exp(-tt * 5.5)


def kick():
    tt = t(0.45)
    f = 46 + 95 * np.exp(-tt * 34)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 7.5)
    click = rng.uniform(-1, 1, len(tt)) * np.exp(-tt * 400) * 0.3
    return np.tanh(2.0 * (body + click))


def snare():
    tt = t(0.35)
    noise = filt(rng.uniform(-1, 1, len(tt)), lo=900, hi=6000) * np.exp(-tt * 16)
    tone = np.sin(2 * np.pi * 185 * tt) * np.exp(-tt * 24) * 0.7
    return np.tanh(1.5 * (noise * 1.2 + tone))


def hat(open_=False):
    tt = t(0.4 if open_ else 0.06)
    n = filt(rng.uniform(-1, 1, len(tt)), lo=6500, hi=12000)
    return n * np.exp(-tt * (9 if open_ else 80))


def crackle(seconds):
    n = int(seconds * SR)
    x = np.zeros(n)
    pops = rng.integers(0, n, int(seconds * 9))
    x[pops] = rng.uniform(-1, 1, len(pops)) * rng.uniform(0.2, 1.0, len(pops))
    hiss = filt(rng.uniform(-1, 1, n), lo=2000, hi=8000) * 0.04
    return filt(x, lo=800, hi=7000) + hiss


# ---------------------------------------------------------------- composition
# chord: bass root, electric-piano voicing (7ths / 9ths, close voiced around middle C)
CH = {
    "Bbmaj7": (46, [57, 62, 65, 69]),
    "Am7": (45, [55, 60, 64, 67]),
    "Gm7": (43, [53, 58, 62, 65]),
    "C7": (48, [55, 58, 64, 67]),
    "Dm9": (50, [57, 60, 64, 65]),
    "Fmaj7": (41, [57, 60, 64, 65]),
    "C9": (48, [55, 58, 62, 64]),
}
LOOP_A = ["Bbmaj7", "Am7", "Gm7", "C7"]
LOOP_B = ["Dm9", "Am7", "Bbmaj7", "C9"]
SECTIONS = [  # (name, chords, drums, hook)
    ("intro", LOOP_A, "hats", False),
    ("groove", LOOP_A * 2, "full", False),
    ("hook", LOOP_B * 2, "full", True),
    ("groove2", LOOP_A * 2, "full", "answer"),
    ("break", LOOP_B, "light", False),
]
# hook phrase over one 4-bar LOOP_B pass: (beat, length, midi)
HOOK = [(0, 0.5, 74), (0.75, 0.5, 72), (1.5, 1, 69), (3, 0.5, 72),
        (4, 0.5, 72), (4.75, 0.5, 69), (5.5, 1.5, 67), (7.5, 0.5, 64),
        (8, 0.5, 65), (8.75, 0.5, 69), (9.5, 0.5, 72), (10.5, 1.5, 77),
        (12, 0.5, 76), (12.75, 0.5, 72), (13.5, 2, 74)]
ANSWER = [(2, 0.5, 69), (2.75, 0.5, 72), (3.5, 0.5, 74), (6, 1, 72), (10, 0.5, 70), (10.75, 0.5, 69), (11.5, 1.5, 65)]

bars = sum(len(s[1]) for s in SECTIONS)
total = bars * BAR
keys, bas, drm, hk, kick_env = (Track(total) for _ in range(5))


def sw(beat):
    """Swing: delay every off-beat 8th."""
    return beat * BEAT + (SWING if abs(beat * 2 - round(beat * 2)) < 1e-6 and round(beat * 2) % 2 == 1 else 0.0)


bar_i = 0
for name, prog, drums, has_hook in SECTIONS:
    sec0 = bar_i * BAR
    for k, ch in enumerate(prog):
        t0 = (bar_i + k) * BAR
        root, v = CH[ch]
        # --- keys: a stab on 1, a lazy push on the "and" of 2, a soft re-hit on 4 (rolled chords)
        for beat, length, vel in ((0, 1.4, 1.0), (1.5, 1.0, 0.7), (3.5, 0.45, 0.55)):
            if name == "break" and beat > 0:
                continue
            for j, m in enumerate(v):
                keys.add(t0 + sw(beat) + j * 0.012, epiano(m, length * BEAT if name != "break" else BAR * 0.95, vel), 0.26 * vel)
        # --- sub bass: syncopated root / octave / fifth
        if name != "intro" or k >= 2:
            for beat, length, iv in ((0, 1.2, 0), (1.5, 0.4, 12), (2.5, 0.9, 0), (3.5, 0.4, 7)):
                if name == "break" and beat > 0:
                    continue
                bas.add(t0 + sw(beat), sub(root - 12 + iv, length * BEAT), 0.9 if beat == 0 else 0.7)
        # --- drums
        if drums in ("hats", "full", "light"):
            for e in range(8):  # swung 8th hats with human velocity
                vel = (0.8 if e % 2 == 0 else 0.5) * (0.85 + 0.3 * rng.random())
                drm.add(t0 + sw(e / 2), hat(), 0.16 * vel * (0.6 if drums == "hats" else 1.0))
            if drums == "full":
                if k % 2 == 1:
                    drm.add(t0 + sw(3.5), hat(True), 0.08)
                for beat in ((0, 1.75, 2.5) if k % 2 == 0 else (0, 2.5, 3.75)):
                    drm.add(t0 + sw(beat) if beat != 1.75 and beat != 3.75 else t0 + beat * BEAT, kick(), 0.85)
                    kick_env.add(t0 + beat * BEAT, np.exp(-t(0.3) * 9), 1.0)
                for beat in (1, 3):
                    drm.add(t0 + beat * BEAT + 0.012, snare(), 0.5)
                if k % 4 == 3:  # little ghost-note fill into the next phrase
                    drm.add(t0 + 3.75 * BEAT, snare(), 0.18)
            if drums == "light":
                drm.add(t0, kick(), 0.6)
                kick_env.add(t0, np.exp(-t(0.3) * 9), 1.0)
    if has_hook:
        phrase = HOOK if has_hook is True else ANSWER
        for rep in range(len(prog) // 4):
            base = sec0 + rep * 4 * BAR
            for beat, length, m in phrase:
                hk.add(base + sw(beat) if beat % 1 else base + beat * BEAT, hook(m, length * BEAT), 0.5 if rep == 0 else 0.45)
    bar_i += len(prog)

# ---------------------------------------------------------------- mix
n = int(total * SR)


def fold(x):
    y = x[:n].copy()
    tail = x[n:n + n]
    y[:len(tail)] += tail
    return y


duck = 1.0 - 0.35 * np.clip(fold(kick_env.buf), 0, 1)  # sidechain pump on keys + bass
k_ = filt(fold(keys.buf), lo=120, hi=4200) * duck
b_ = filt(fold(bas.buf), hi=380) * (0.6 + 0.4 * duck)
d_ = filt(fold(drm.buf), hi=9000)
h_ = filt(fold(hk.buf), lo=250, hi=3500)
dly = int(BEAT * 0.75 * SR)  # dotted-8th echo on the hook
h_ = h_ + 0.35 * np.roll(h_, dly) + 0.15 * np.roll(h_, 2 * dly)
vinyl = crackle(total)

mix = 0.95 * k_ + 0.75 * b_ + 0.9 * d_ + 0.38 * h_ + 0.35 * vinyl
# lo-fi bus: soft tape saturation, rolled-off top, gentle room
mix = filt(np.tanh(1.3 * mix / np.max(np.abs(mix)) * 1.4), lo=30, hi=7500)
mix = mix + 0.1 * np.roll(mix, int(0.037 * SR)) + 0.06 * np.roll(mix, int(0.061 * SR))
mix = mix / np.max(np.abs(mix)) * 0.89

out = sys.argv[1] if len(sys.argv) > 1 else "quarry_shift.wav"
with wave.open(out, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((mix * 32767).astype("<i2").tobytes())
print("wrote %s: %d bars, %.1f s loop" % (out, bars, total))
