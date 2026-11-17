#!/usr/bin/env python3
"""Ground textures of the quarry (overhaul): packed earth that reads as dug soil with soft clods, and warm rounded gravel.
    python tools/qd_ground_textures.py
Writes assets/textures/T_QD_ExcavatedDirt.png and T_QD_RockGravel.png (+ .import and materials) through qd_textures.save()."""
import os
import sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qd_textures as Q


def disc(a, cx, cy, r, base, lit, shade):
    """one rounded pebble / clod, lit top-left: lit crescent, body, shaded lower right"""
    h, w = a.shape[:2]
    for dy in range(-r - 1, r + 2):
        for dx in range(-r - 1, r + 2):
            d2 = dx * dx + dy * dy
            if d2 > r * r + r * 0.6:
                continue
            c = base
            rim = d2 > (r - 1) * (r - 1)
            if rim and dx + dy < 0:
                c = lit
            elif rim and dx + dy > 0:
                c = shade
            a[(cy + dy) % h, (cx + dx) % w] = c


def earth(size, seed):
    soil, mud = Q.ramp("soil"), Q.ramp("mud")
    r = [mud[2], mud[3], soil[1], soil[2], soil[3], soil[4]]
    rng = np.random.default_rng(seed)
    a = Q.canvas(size, size)
    big = Q.pnoise(size, size, 4, seed)          # very soft broad light / dark drift
    mid = Q.pnoise(size, size, 10, seed + 1)
    for y in range(size):
        for x in range(size):
            lv = 3.0 + (big[y, x] - 0.5) * 1.0 + (mid[y, x] - 0.5) * 0.9
            if rng.random() < 0.05:
                lv += rng.choice([-1, 1])
            a[y, x] = r[int(np.clip(round(lv), 2, 4))]
    # soft clods: small rounded lumps with a lit top-left edge and a dark underside
    for _ in range((size // 8) ** 2):
        cx, cy = int(rng.integers(0, size)), int(rng.integers(0, size))
        rad = int(rng.integers(2, 4))
        disc(a, cx, cy, rad, r[3], r[4], r[2])
    # tiny stones and a few dry roots
    for _ in range((size // 14) ** 2):
        cx, cy = int(rng.integers(0, size)), int(rng.integers(0, size))
        disc(a, cx, cy, 1, Q.ramp("stone_warm")[3], Q.ramp("stone_warm")[4], r[1])
    for _ in range(size // 32):
        x, y = int(rng.integers(0, size)), int(rng.integers(0, size))
        for k in range(int(rng.integers(5, 10))):
            a[(y + k // 3) % size, (x + k) % size] = soil[4] if k % 2 else r[2]
    return a


def gravel(size, seed):
    conc, stone, soil = Q.ramp("concrete"), Q.ramp("stone_warm"), Q.ramp("soil")
    warm = [soil[1], soil[2], stone[1], stone[2], stone[3], stone[4]]
    cool = [stone[0], stone[1], stone[2], stone[3], stone[4], stone[4]]
    rng = np.random.default_rng(seed)
    a = Q.canvas(size, size)
    a[:, :] = soil[1]                                  # dark fines between the pebbles
    n = Q.pnoise(size, size, 6, seed)
    for k in range((size // 3) ** 2 // 2):
        cx, cy = int(rng.integers(0, size)), int(rng.integers(0, size))
        rad = int(rng.choice([1, 2, 2, 3, 3, 4]))
        ramp = warm if rng.random() < 0.7 else cool
        lv = int(np.clip(2 + round((n[cy % size, cx % size] - 0.5) * 3) + rng.integers(-1, 2), 1, 4))
        disc(a, cx, cy, rad, ramp[lv], ramp[min(5, lv + 1)], ramp[max(0, lv - 1)])
    return a


if __name__ == "__main__":
    Q.save("T_QD_ExcavatedDirt", earth(128, 22))
    Q.save("T_QD_RockGravel", gravel(128, 17))
    print("ok")
