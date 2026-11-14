#!/usr/bin/env python3
"""'Walt's Hammer' - cozy background loop for Quarry Days (synthesized, deterministic, numpy only).

88 BPM, F major. Sections: A (morning) -> B (working, melody + beat) -> A' -> C (breather, pad).
The tail of the last bar is wrapped onto the start so the file loops seamlessly.
Usage: python3 tools/music/walts_hammer.py audio/music/walts_hammer.wav
"""
import sys
import wave

import numpy as np

SR = 32000
BPM = 88.0
BEAT = 60.0 / BPM
BAR = BEAT * 4
rng = np.random.default_rng(7)


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def lowpass(x, cutoff):
    """Zero-phase FFT low-pass with a soft roll-off (whole-signal, so it is loop-safe)."""
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    X = np.fft.rfft(x)
    X *= 1.0 / (1.0 + (f / cutoff) ** 4)
    return np.fft.irfft(X, len(x))


def highpass(x, cutoff):
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    X = np.fft.rfft(x)
    X *= (f / cutoff) ** 2 / (1.0 + (f / cutoff) ** 2)
    return np.fft.irfft(X, len(x))


class Track:
    def __init__(self, seconds):
        self.buf = np.zeros(int(seconds * SR) + SR * 4)

    def add(self, start, sig, gain=1.0):
        i = int(start * SR)
        self.buf[i:i + len(sig)] += sig * gain


def t(sec):
    return np.arange(int(sec * SR)) / SR


def pluck(m, dur=1.6, bright=1.0):
    """Nylon-ish pluck: harmonics that decay faster the higher they are, plus a tiny pick noise."""
    tt = t(dur)
    f = hz(m)
    out = np.zeros_like(tt)
    for n in range(1, 9):
        if f * n > SR / 2.5:
            break
        amp = (1.0 / n ** 1.4) * (0.6 + 0.4 * np.sin(n * 1.7) ** 2)
        decay = 2.2 + n * 1.3 / bright
        out += amp * np.sin(2 * np.pi * f * n * tt + n) * np.exp(-decay * tt)
    pick = rng.uniform(-1, 1, len(tt)) * np.exp(-tt * 90) * 0.15
    att = np.minimum(1, tt / 0.003)
    return (out + pick) * att


def lead(m, dur):
    """Soft square (odd harmonics) with a gentle delayed vibrato - the 'pixel' voice."""
    tt = t(dur + 0.25)
    f = hz(m)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * tt) * np.minimum(1, tt / 0.35)
    ph = 2 * np.pi * f * np.cumsum(vib) / SR
    sq = sum(np.sin(k * ph) / k for k in (1, 3, 5, 7))
    env = np.minimum(1, tt / 0.03) * np.where(tt < dur, 1.0, np.exp(-(tt - dur) * 14)) * (0.85 + 0.15 * np.exp(-tt * 3))
    return sq * env


def bass(m, dur):
    tt = t(dur + 0.15)
    f = hz(m)
    s = np.sin(2 * np.pi * f * tt) + 0.25 * np.sin(4 * np.pi * f * tt) + 0.08 * np.sin(6 * np.pi * f * tt)
    env = np.minimum(1, tt / 0.012) * np.exp(-tt * 1.2) * np.where(tt < dur, 1.0, np.exp(-(tt - dur) * 25))
    return s * env


def pad(ms, dur):
    tt = t(dur + 1.5)
    s = np.zeros_like(tt)
    for m in ms:
        for det in (-0.07, 0.0, 0.06):
            f = hz(m + det)
            s += np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(4 * np.pi * f * tt + 1.0)
    env = np.minimum(1, tt / 1.2) * np.where(tt < dur, 1.0, np.exp(-(tt - dur) * 2.5))
    return s * env / len(ms)


def kick():
    tt = t(0.35)
    f = 48 + 70 * np.exp(-tt * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 11)


def rim():
    tt = t(0.12)
    return (np.sin(2 * np.pi * 1650 * tt) * 0.6 + rng.uniform(-1, 1, len(tt)) * 0.5) * np.exp(-tt * 70)


def shaker(accent):
    tt = t(0.11)
    n = rng.uniform(-1, 1, len(tt))
    return n * np.minimum(1, tt / 0.01) * np.exp(-tt * 45) * accent


def anvil(m):
    """Tuned 'ting' of a mallet on metal: inharmonic partials, long ring."""
    tt = t(2.5)
    f = hz(m)
    s = sum(a * np.sin(2 * np.pi * f * r * tt) * np.exp(-tt * d) for r, a, d in ((1, 1, 1.6), (2.76, 0.5, 3.2), (5.4, 0.25, 6.0), (8.93, 0.12, 9.0)))
    return s * np.minimum(1, tt / 0.002)


# ---------------------------------------------------------------- composition
CH = {  # chord: bass root (midi), guitar voicing (low -> high)
    "F": (41, [53, 60, 65, 69, 72]),
    "Am": (45, [57, 64, 69, 72, 76]),
    "Bb": (46, [58, 62, 65, 70, 74]),
    "C": (48, [55, 60, 64, 67, 72]),
    "Dm": (50, [57, 62, 65, 69, 74]),
}
A = ["F", "Am", "Bb", "C", "F", "Am", "Bb", "C"]
B = ["F", "Am", "Bb", "C", "Dm", "Bb", "F", "C"]
C = ["Bb", "F", "Bb", "C", "Dm", "Bb", "Bb", "C"]
SECTIONS = [("A", A), ("B", B), ("B2", B), ("A2", A), ("C", C)]

# melody for the B section: (beat offset within 8 bars, length in beats, midi)
MELODY = [
    (0, 1.5, 72), (1.5, 0.5, 74), (2, 1, 76), (3, 1, 72),
    (4, 2, 76), (6, 1, 77), (7, 1, 76),
    (8, 1.5, 74), (9.5, 0.5, 72), (10, 1, 70), (11, 1, 74),
    (12, 3, 72), (15, 1, 67),
    (16, 1, 69), (17, 1, 72), (18, 1.5, 74), (19.5, 0.5, 72),
    (20, 2, 70), (22, 1, 69), (23, 1, 67),
    (24, 1.5, 65), (25.5, 0.5, 67), (26, 1, 69), (27, 1, 72),
    (28, 3, 67), (31, 1, 0),
]
# answer phrase for the second time through B: same shape, ends home on F
MELODY2 = MELODY[:24] + [(24, 1.5, 69), (25.5, 0.5, 70), (26, 1, 72), (27, 1, 76), (28, 4, 77)]

bars = sum(len(s) for _, s in SECTIONS)
total = bars * BAR
guitar, mel, bas, drums, pads, metal = (Track(total) for _ in range(6))

bar_i = 0
for name, prog in SECTIONS:
    sec_start = bar_i * BAR
    for k, ch in enumerate(prog):
        t0 = (bar_i + k) * BAR
        root, v = CH[ch]
        # --- guitar: gentle 8th-note arpeggio, a light swing on the off-beats
        pattern = [0, 2, 3, 2, 4, 2, 3, 1] if name != "A2" else [0, 3, 2, 4, 3, 2, 1, 2]
        if name != "C":
            for e, idx in enumerate(pattern):
                swing = 0.03 if e % 2 else 0.0
                vel = (1.0 if e == 0 else 0.62) * (0.9 + 0.2 * rng.random())
                guitar.add(t0 + e * BEAT / 2 + swing, pluck(v[idx], 1.8, 0.9 if name == "A" else 1.1), vel)
        else:
            guitar.add(t0, pluck(v[0], 2.6, 0.7), 0.55)  # breather: one soft strum per bar
            for j, idx in enumerate([1, 2, 3]):
                guitar.add(t0 + 0.035 * (j + 1), pluck(v[idx], 2.6, 0.7), 0.4)
        # --- bass: root, fifth, a walking approach into the next chord
        nxt = CH[prog[(k + 1) % len(prog)]][0]
        bas.add(t0, bass(root, BEAT * 1.8), 1.0)
        bas.add(t0 + 2 * BEAT, bass(root + 7, BEAT * 1.4), 0.75)
        if name not in ("C",):
            bas.add(t0 + 3.5 * BEAT, bass(nxt + (1 if nxt < root + 7 else -1), BEAT * 0.45), 0.55)
        # --- drums: brushed and soft; only shaker in the morning, nothing in the breather
        if name != "C":
            for e in range(8):
                drums.add(t0 + e * BEAT / 2 + (0.03 if e % 2 else 0), shaker(0.55 if e % 2 else 0.9), 0.22)
        if name in ("B", "B2", "A2"):
            drums.add(t0, kick(), 0.7)
            drums.add(t0 + 2 * BEAT, kick(), 0.5)
            drums.add(t0 + BEAT, rim(), 0.18)
            drums.add(t0 + 3 * BEAT, rim(), 0.18)
        # --- pad: warm under the working sections, carrying the breather
        if name in ("B", "B2", "C"):
            pads.add(t0, pad(v[1:4], BAR * 0.98), 0.5 if name == "C" else 0.22)
        # --- quarry colour: a tuned anvil ting every four bars
        if k % 4 == 0 and name != "C":
            metal.add(t0 + (0 if name == "A" else 3.5 * BEAT), anvil(84 if k == 0 else 79), 0.12)
    if name in ("B", "B2"):
        for beat, length, m in (MELODY if name == "B" else MELODY2):
            if m:
                mel.add(sec_start + beat * BEAT, lead(m, length * BEAT * 0.92), 0.5)
    bar_i += len(prog)

# ---------------------------------------------------------------- mix
n = int(total * SR)


def fold(x):
    """Wrap the ringing tail past the loop point back onto the start (seamless loop)."""
    y = x[:n].copy()
    tail = x[n:]
    y[:len(tail)] += tail
    return y


g = lowpass(fold(guitar.buf), 3800)
m = lowpass(fold(mel.buf), 2600)
# a little slap-back echo on the lead for space
d = int(BEAT * 0.75 * SR)
m = m + 0.28 * np.roll(m, d) + 0.1 * np.roll(m, 2 * d)
b = lowpass(fold(bas.buf), 900)
dr = fold(drums.buf)
p = lowpass(fold(pads.buf), 1800)
mt = lowpass(fold(metal.buf), 7000)

mix = 0.55 * g + 0.33 * m + 0.6 * b + 0.45 * dr + 0.32 * p + 0.5 * mt
mix = highpass(mix, 35)
# small room: two short diffuse reflections
room = np.roll(mix, int(0.043 * SR)) * 0.12 + np.roll(mix, int(0.071 * SR)) * 0.08
mix = mix + room
mix = np.tanh(mix / np.max(np.abs(mix)) * 1.6) / np.tanh(1.6) * 0.84

out = sys.argv[1] if len(sys.argv) > 1 else "walts_hammer.wav"
with wave.open(out, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((mix * 32767).astype("<i2").tobytes())
print("wrote %s: %d bars, %.1f s loop" % (out, bars, total))
