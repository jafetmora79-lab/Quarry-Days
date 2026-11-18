"""QUARRY DAYS - an ORIGINAL meme-phonk track for the deer-vs-rabbit aura battle (scripts/forest_aura_battle.gd), synthesised with numpy only: 808 sub bass, cowbell, hats, claps, a pluck arp,
a choir pad, a record scratch, a sad trombone for the deer and a bright fanfare for the winning bunnies. Composed from scratch (its own motifs and chords): no sample, melody or lyric from any existing song.
    python tools/make_aura_music.py        ->  audio/aura_battle.wav   (mono, 32 kHz, 16 bit, 30 s)
Timeline in real seconds (the battle runs its poses 1.3x real time): stare 0-1.5, six-seven drop 1.5, boat roll 6.2, crossed breakdown 11.5, pockets 15.4, result 18.5 (scratch + sad trombone),
bunnies and confetti 21.8, final hit 27.7."""
import os
import wave
import numpy as np

SR = 32000
DUR = 30.0
BPM = 132.0
STEP = 60.0 / BPM / 4.0                       # a 16th note
N = int(SR * DUR)
out = np.zeros(N)
rng = np.random.default_rng(5)


def add(t0, sig, gain=1.0):
    i = int(t0 * SR)
    if i >= N or i < 0:
        return
    j = min(N, i + len(sig))
    out[i:j] += sig[:j - i] * gain


def tt(d):
    return np.arange(int(SR * d)) / SR


def lp(x, k):
    return np.convolve(x, np.ones(k) / k, mode="same")


def kick():
    t = tt(0.45)
    f = 42.0 + 110.0 * np.exp(-t * 28.0)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 7.0) + 0.35 * np.exp(-t * 400.0) * rng.standard_normal(len(t))


def sub(freq, d=0.42):
    t = tt(d)
    f = freq * (1.0 + 0.9 * np.exp(-t * 30.0))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.tanh(2.2 * np.sin(ph)) * np.exp(-t * 4.2) * 0.8


def clap():
    t = tt(0.22)
    n = rng.standard_normal(len(t))
    n = n - lp(n, 6)
    return n * (np.exp(-t * 28.0) + 0.6 * np.exp(-((t - 0.012) * 90.0) ** 2)) * 0.8 + np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30.0) * 0.4


def hat(open_=False):
    t = tt(0.16 if open_ else 0.045)
    n = rng.standard_normal(len(t))
    n = n - lp(n, 4)
    return n * np.exp(-t * (14.0 if open_ else 90.0)) * 0.3


def cowbell(semi=0.0, d=0.2):
    t = tt(d)
    f1, f2 = 560.0 * 2 ** (semi / 12.0), 845.0 * 2 ** (semi / 12.0)
    sq = np.sign(np.sin(2 * np.pi * f1 * t)) + np.sign(np.sin(2 * np.pi * f2 * t))
    return lp(sq, 3) * np.exp(-t * 16.0) * 0.28


def pluck(freq, d=0.3):
    t = tt(d)
    saw = 2.0 * ((t * freq) % 1.0) - 1.0
    return lp(saw, 5) * np.exp(-t * 11.0) * 0.3


def bell(freq, d=0.6):
    t = tt(d)
    return (np.sin(2 * np.pi * freq * t) + 0.5 * np.sin(2 * np.pi * freq * 2.76 * t) + 0.3 * np.sin(2 * np.pi * freq * 5.4 * t)) * np.exp(-t * 6.0) * 0.28


def choir(freqs, d):
    t = tt(d)
    sig = np.zeros(len(t))
    for f in freqs:
        for det in (-0.004, 0.0, 0.004):
            ff = f * (1.0 + det)
            sig += (2.0 * ((t * ff) % 1.0) - 1.0)
    sig = lp(sig, 22) * 0.07
    env = np.minimum(1.0, t / 0.5) * np.minimum(1.0, (d - t) / 0.6)
    vib = 1.0 + 0.1 * np.sin(2 * np.pi * 5.0 * t)
    return sig * env * vib


def riser(d, lo=300.0, hi=3000.0):
    t = tt(d)
    n = rng.standard_normal(len(t))
    k = np.linspace(40, 6, len(t))
    ph = np.cumsum(np.linspace(lo, hi, len(t))) / SR * 2 * np.pi
    return (n * 0.2 + np.sin(ph) * 0.3) * (t / d) ** 2 * 0.5


def scratch():
    t = tt(0.55)
    f = 900.0 * np.sin(2 * np.pi * 3.2 * t) ** 2 + 120.0
    ph = np.cumsum(f) / SR * 2 * np.pi
    n = rng.standard_normal(len(t)) * 0.15
    return (np.sign(np.sin(ph)) * 0.25 + n) * np.exp(-t * 3.0)


def trombone(f0, f1, d):
    t = tt(d)
    f = np.linspace(f0, f1, len(t)) * (1.0 + 0.015 * np.sin(2 * np.pi * 5.5 * t))
    ph = np.cumsum(f) / SR * 2 * np.pi
    saw = 2.0 * ((ph / (2 * np.pi)) % 1.0) - 1.0
    return lp(saw, 12) * np.minimum(1.0, t / 0.04) * np.minimum(1.0, (d - t) / 0.12) * 0.55


def crash(d=1.6):
    t = tt(d)
    n = rng.standard_normal(len(t))
    n = n - lp(n, 3)
    return n * np.exp(-t * 3.0) * 0.35


def hz(note):                                                 # semitones from A4
    return 440.0 * 2 ** (note / 12.0)


# ---- the grid
total_steps = int(DUR / STEP)
KICK = {0, 6, 8, 11}
SNARE = {4, 12}
BASS = {0: -33, 6: -33, 8: -33, 11: -30}                         # A1 ... C2
COW = [(0, 0), (3, 3), (6, 7), (8, 5), (10, 3), (12, 0), (14, -2)]
ARP = [0, 3, 7, 12, 7, 3, 0, 3, 7, 12, 15, 12, 7, 3, 7, 3]           # A minor arpeggio, in semitones above A4
t_res = 18.5
t_party = 21.8

for s in range(total_steps):
    t = s * STEP
    bar_step = s % 16
    if t < 1.5:                                                    # the stare: a low drone, a rising swell
        if s == 0:
            add(0, choir([hz(-33), hz(-21)], 1.6), 1.2)
            add(0.0, riser(1.5, 200, 2200), 0.9)
        continue
    if t_res <= t < t_party:                                       # the result: nothing but the scratch and the sad trombone (added below)
        continue
    party = t >= t_party
    breakdown = 11.5 <= t < 15.4
    pockets = 15.4 <= t < t_res
    if party:
        if bar_step % 4 == 0:
            add(t, kick(), 0.9)
        if bar_step in (4, 12):
            add(t, clap(), 0.9)
        if bar_step % 2 == 0:
            add(t, hat(bar_step % 8 == 6), 0.7)
        if bar_step in (0, 6, 10):
            add(t, sub(hz(-33 + 3), 0.3), 0.9)                       # C2 bouncing
        if bar_step in (3, 8, 13):
            add(t, sub(hz(-33 + 10), 0.25), 0.7)                     # G2
        melody = {0: 3, 3: 7, 6: 10, 8: 12, 10: 10, 12: 7, 14: 3}   # C major bell tune (original), C5 = 3 semitones above A4
        if bar_step in melody:
            add(t, bell(hz(melody[bar_step] + 12)), 1.0)
        continue
    if breakdown or pockets:
        if bar_step in (0, 8):
            add(t, kick(), 0.8)
            add(t, sub(hz(-33), 0.8), 0.7)
        if bar_step == 8 and breakdown:
            add(t, clap(), 0.8)
        if bar_step % 4 == 2 and breakdown:
            add(t, hat(), 0.5)
        if bar_step == 0 and breakdown:
            add(t, choir([hz(0), hz(3), hz(7)] if (s // 16) % 2 == 0 else [hz(-4), hz(0), hz(3)], 3.3), 1.0)
        if pockets and bar_step in (0, 8):
            add(t, cowbell(0, 0.3), 0.6)
        continue
    # the main groove: six-seven drop and the boat roll
    if bar_step in KICK:
        add(t, kick(), 0.95)
    if bar_step in BASS:
        add(t, sub(hz(BASS[bar_step]), 0.5), 0.9)
    if bar_step in SNARE:
        add(t, clap(), 0.9)
    add(t, hat(bar_step % 8 == 6), 0.55 + 0.2 * (bar_step % 2 == 0))
    for (cs, semi) in COW:
        if bar_step == cs:
            add(t, cowbell(semi), 1.0)
    if t >= 6.2:
        add(t, pluck(hz(ARP[bar_step] - 12 + (12 if (s // 16) % 2 else 0))), 0.8)
    if bar_step == 15 and rng.random() < 0.5:
        add(t, hat(True), 0.5)

# ---- the result: record scratch, a sad trombone for the deer, a crash for the confetti
add(t_res, scratch(), 1.0)
for k, (n0, n1, st, du) in enumerate([(hz(-2), hz(-2), 0.55, 0.55), (hz(-3), hz(-3), 1.1, 0.55), (hz(-4), hz(-4), 1.65, 0.55), (hz(-5), hz(-12), 2.2, 1.0)]):
    add(t_res + st, trombone(n0 * 0.5, n1 * 0.5, du), 1.0)
add(t_party - 0.05, riser(0.5, 400, 3500), 0.8)
add(t_party, crash(), 1.0)
add(27.7, crash(2.2), 1.2)
add(27.7, kick(), 1.0)
add(27.7, bell(hz(15)), 1.0)
add(27.7, choir([hz(3), hz(7), hz(10), hz(15)], 2.3), 1.2)

# ---- master: soft limit, fade the tail
env = np.ones(N)
env[int(29.0 * SR):] = np.linspace(1, 0, N - int(29.0 * SR))
out = np.tanh(out * 1.1) * env
out = out / max(1e-6, np.abs(out).max()) * 0.9
pcm = (out * 32767).astype(np.int16)
os.makedirs(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio"), exist_ok=True)
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio", "aura_battle.wav")
with wave.open(path, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print("WROTE", os.path.abspath(path), len(pcm) / SR, "s")
