#!/usr/bin/env python3
"""Quarry Days pixel textures, painted the THE VEIL way (see THE_VEIL_ASSETS_V2/00_Art_Direction/ART_DIRECTION.md).

    python3 tools/qd_textures.py

* Every colour comes from the Greyhaven palette ramps (GREYHAVEN_PALETTE.json); shading steps along a ramp.
* 64 px per metre; tiling textures assume meter-UVs, so their material uv1_scale = 64 / size.
* Light from the top-left: blocks, stones, ribs and bolts are lit top-left and shadowed bottom-right.
* Clusters, not noise: periodic low-frequency noise only decides where wear goes.
* Lossless import, nearest filtering with mipmaps (material texture_filter = 4), like THE VEIL.
Deterministic. Writes assets/textures/T_QD_*.png (+ .import) and assets/materials/M_QD_*.tres.
"""
import hashlib
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, "assets", "textures")
MAT = os.path.join(ROOT, "assets", "materials")
PAL = json.load(open(os.path.join(ROOT, "THE_VEIL_ASSETS_V2", "00_Art_Direction", "GREYHAVEN_PALETTE.json")))


def ramp(name):
    return [tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) for h in PAL[name]]


def canvas(w, h):
    return np.zeros((h, w, 3), np.uint8)


def put(a, x, y, c):
    h, w = a.shape[:2]
    a[y % h, x % w] = c


def rect(a, x, y, w, h, c):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            put(a, xx, yy, c)


def pnoise(w, h, cells, seed):
    """periodic value noise in 0..1 (wraps seamlessly)"""
    rng = np.random.default_rng(seed)
    g = rng.random((cells, cells))
    ys, xs = np.mgrid[0:h, 0:w]
    fx, fy = xs / w * cells, ys / h * cells
    x0, y0 = np.floor(fx).astype(int), np.floor(fy).astype(int)
    tx, ty = fx - x0, fy - y0
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a, b = g[y0 % cells, x0 % cells], g[y0 % cells, (x0 + 1) % cells]
    c, d = g[(y0 + 1) % cells, x0 % cells], g[(y0 + 1) % cells, (x0 + 1) % cells]
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty


def stones(a, r, base, count, size, seed, light=1, dark=1):
    """1-4 px aggregate stones on a jittered grid, lit top-left"""
    rng = np.random.default_rng(seed)
    h, w = a.shape[:2]
    n = int(np.sqrt(count))
    for gy in range(n):
        for gx in range(n):
            x = int((gx + rng.random()) * w / n)
            y = int((gy + rng.random()) * h / n)
            s = int(rng.integers(size[0], size[1] + 1))
            lv = int(np.clip(base + rng.integers(-1, 2), 0, len(r) - 1))
            rect(a, x, y, s, s, r[lv])
            for k in range(s):
                put(a, x + k, y, r[min(len(r) - 1, lv + light)])
                put(a, x, y + k, r[min(len(r) - 1, lv + light)])
                put(a, x + k, y + s, r[max(0, lv - dark)])
                put(a, x + s, y + k, r[max(0, lv - dark)])


# ---------------------------------------------------------------------------------------------- rock
def strata(size, r, seed, seams=None, veins=None, drill=0):
    """Bedded quarry rock: horizontal beds split into blocks by jittered joints, each block lit top-left."""
    rng = np.random.default_rng(seed)
    a = canvas(size, size)
    wear = pnoise(size, size, 4, seed + 1)
    y = 0
    beds = []
    while y < size:
        hgt = int(rng.integers(7, 15))
        hgt = min(hgt, size - y) if size - y - hgt < 6 else hgt
        beds.append((y, hgt))
        y += hgt
    for bi, (y0, hgt) in enumerate(beds):
        base = int(rng.integers(2, len(r) - 2))
        x = int(rng.integers(0, 12))
        while x < size + 20:
            bw = int(rng.integers(10, 26))
            lv = int(np.clip(base + rng.integers(-1, 2), 1, len(r) - 2))
            for yy in range(y0, y0 + hgt):
                for xx in range(x, x + bw):
                    w = wear[yy % size, xx % size]
                    put(a, xx, yy, r[lv - (1 if w > 0.72 else 0)])
            for xx in range(x, x + bw):                     # top-left highlight, bottom shadow
                put(a, xx, y0, r[min(len(r) - 1, lv + 1)])
                put(a, xx, y0 + hgt - 1, r[max(0, lv - 2)])
            for yy in range(y0, y0 + hgt):
                put(a, x, yy, r[min(len(r) - 1, lv + 1)])
                put(a, x + bw - 1, yy, r[max(0, lv - 1)])
            for k in range(int(rng.integers(1, 4))):        # small pits / fossil specks
                px, py = x + int(rng.integers(2, max(3, bw - 2))), y0 + int(rng.integers(2, max(3, hgt - 2)))
                put(a, px, py, r[max(0, lv - 2)])
                put(a, px + 1, py + 1, r[min(len(r) - 1, lv + 1)])
            x += bw
        if seams and bi % 2 == 1:                           # dark seam bed boundary (coal etc.)
            sr, slv = seams
            for xx in range(size):
                put(a, xx, y0, sr[slv])
                if (xx * 7 + bi) % 5 == 0:
                    put(a, xx, y0 + 1, sr[slv + 1])
    if veins:
        vr, vlv, n = veins
        for k in range(n):
            x, y = int(rng.integers(0, size)), int(rng.integers(0, size))
            for t in range(int(rng.integers(8, 20))):
                put(a, x, y, vr[vlv + (1 if t % 4 == 0 else 0)])
                x += int(rng.integers(0, 2))
                y += int(rng.integers(-1, 2))
    for k in range(drill):                                   # quarry drill-hole traces (half pipes)
        x = int((k + 0.5) * size / drill)
        for yy in range(size):
            put(a, x, yy, r[1])
            put(a, x + 1, yy, r[min(len(r) - 1, 4)])
    return a


# ---------------------------------------------------------------------------------------------- ground
def cut_strata(size, r, seed):
    """Cut quarry-wall limestone: thick horizontal beds (about 0.4-0.6 m) with fine layer lines inside them, a dark
    seam and a light lip at every bed boundary, and only a few long vertical joints, so a wall reads as sawn,
    stratified stone instead of small bricks."""
    rng = np.random.default_rng(seed)
    a = canvas(size, size)
    wear = pnoise(size, size, 4, seed + 1)
    y = 0
    beds = []
    while y < size:
        hgt = int(rng.integers(24, 42))
        hgt = size - y if size - y - hgt < 18 else hgt
        beds.append((y, hgt))
        y += hgt
    for bi, (y0, hgt) in enumerate(beds):
        base = int(rng.integers(2, len(r) - 2))
        x = int(rng.integers(0, 30))
        while x < size + 60:
            bw = int(rng.integers(56, 128))
            lv = int(np.clip(base + rng.integers(-1, 2), 1, len(r) - 2))
            for yy in range(y0, y0 + hgt):
                for xx in range(x, x + bw):
                    w = wear[yy % size, xx % size]
                    put(a, xx, yy, r[lv - (1 if w > 0.7 else 0)])
            for k in range(int(rng.integers(2, 5))):               # fine layer lines inside the bed
                ly = y0 + int(rng.integers(4, hgt - 3))
                for xx in range(x + 2, x + bw - 2):
                    if (xx + k) % 7 != 0:
                        put(a, xx, ly, r[max(0, lv - 1)])
            for xx in range(x, x + bw):                            # light lip on top, dark seam below
                put(a, xx, y0, r[min(len(r) - 1, lv + 1)])
                put(a, xx, y0 + hgt - 1, r[0])
                put(a, xx, y0 + hgt - 2, r[max(0, lv - 2)])
            for yy in range(y0, y0 + hgt):                         # vertical joint
                put(a, x, yy, r[0])
                put(a, x + 1, yy, r[min(len(r) - 1, lv + 1)])
            for k in range(int(rng.integers(2, 6))):               # pits and fossil specks
                px, py = x + int(rng.integers(3, max(4, bw - 3))), y0 + int(rng.integers(3, max(4, hgt - 3)))
                put(a, px, py, r[max(0, lv - 2)])
                put(a, px + 1, py, r[max(0, lv - 1)])
                put(a, px, py + 1, r[min(len(r) - 1, lv + 1)])
            x += bw
    return a


def natural_strata(size, r, seed, seams=None, veins=None, drill=0, cracks=4):
    """Natural bedded rock without any block outlines: wavy horizontal beds of different thickness whose boundaries
    wander with periodic noise, fine layer lines inside each bed, soft low-frequency tone clusters, a few hairline
    cracks and small pits. Tiles seamlessly, so a surface mapped in world space reads as one continuous rock mass."""
    rng = np.random.default_rng(seed)
    a = canvas(size, size)
    n_lo = pnoise(size, size, 3, seed + 1)
    n_mid = pnoise(size, size, 8, seed + 2)
    n_hi = pnoise(size, size, 16, seed + 3)
    # bed thicknesses that add up to exactly `size` (so the texture tiles vertically)
    th = []
    left = size
    while left > 0:
        t = int(rng.integers(10, 26))
        if left - t < 8:
            t = left
        th.append(t)
        left -= t
    edges = np.cumsum([0] + th)
    bed_of = np.zeros(size, int)
    for bi in range(len(th)):
        bed_of[edges[bi]:edges[bi + 1]] = bi
    lv_bed = [int(np.clip(rng.integers(2, len(r) - 1), 1, len(r) - 2)) for _ in th]
    wobble = (n_lo - 0.5) * 12.0 + (n_mid - 0.5) * 4.0
    for y in range(size):
        for x in range(size):
            yy = int(round(y + wobble[y, x])) % size       # wavy bed boundaries
            bi = bed_of[yy]
            lv = lv_bed[bi]
            v = n_mid[y, x] * 0.6 + n_hi[y, x] * 0.4
            if v > 0.72:
                lv += 1
            elif v < 0.28:
                lv -= 1
            pos_in_bed = yy - edges[bi]
            if pos_in_bed == 0:
                lv += 1                                         # light lip where a bed starts
            elif pos_in_bed >= th[bi] - 1:
                lv -= 2                                         # thin dark seam where it ends
            elif (pos_in_bed * 7 + bi * 3 + (x // 23)) % 9 == 0 and n_hi[y, x] > 0.35:
                lv -= 1                                         # fine layer lines inside the bed
            a[y, x] = r[int(np.clip(lv, 0, len(r) - 1))]
    if seams:
        sr, slv = seams
        for bi in range(0, len(th), 2):
            for x in range(size):
                if n_hi[edges[bi] % size, x] > 0.3:
                    put(a, x, edges[bi], sr[slv])
    for k in range(cracks):                                    # hairline cracks (random walks, mostly vertical)
        x, y = int(rng.integers(0, size)), int(rng.integers(0, size))
        for t in range(int(rng.integers(14, 40))):
            put(a, x, y, r[0])
            y += 1
            x += int(rng.integers(-1, 2)) if rng.random() < 0.5 else 0
    for k in range(size // 3):                                  # pits
        px, py = int(rng.integers(0, size)), int(rng.integers(0, size))
        put(a, px, py, r[1])
    if veins:
        vr, vlv, nv = veins
        for k in range(nv):
            x, y = int(rng.integers(0, size)), int(rng.integers(0, size))
            for t in range(int(rng.integers(10, 26))):
                put(a, x, y, vr[vlv + (1 if t % 5 == 0 else 0)])
                x += int(rng.integers(0, 2))
                y += int(rng.integers(-1, 2))
    for k in range(drill):                                       # drill-hole traces
        x = int((k + 0.5) * size / drill)
        for yy in range(size):
            put(a, x, yy, r[1])
            put(a, x + 1, yy, r[min(len(r) - 1, 4)])
    return a


def calm_ground(size, r, seed, base=3):
    """Compacted dirt for the yard and pit floors: one dominant tone with sparse one-step speckle and a few small
    pebbles, no large blotches and no contrasting patches, so large floors look like one cohesive surface and
    neighbouring ground materials blend instead of forming a patchwork."""
    rng = np.random.default_rng(seed)
    a = canvas(size, size)
    n = pnoise(size, size, 8, seed)
    for y in range(size):
        for x in range(size):
            lv = base
            if n[y, x] > 0.9 and rng.random() < 0.35:
                lv += 1
            elif n[y, x] < 0.1 and rng.random() < 0.35:
                lv -= 1
            elif rng.random() < 0.035:
                lv += int(rng.choice([-1, 1]))
            a[y, x] = r[int(np.clip(lv, 0, len(r) - 1))]
    stones(a, r, base, (size // 10) ** 2, (1, 2), seed + 2)
    return a


def gravel(size, r, seed, base=3, dust=None):
    a = canvas(size, size)
    n = pnoise(size, size, 4, seed)
    for y in range(size):
        for x in range(size):
            a[y, x] = r[base - (1 if n[y, x] < 0.3 else 0) + (1 if n[y, x] > 0.75 else 0)]
    stones(a, r, base, (size // 4) ** 2, (1, 2), seed + 2)
    stones(a, r, base, (size // 14) ** 2, (2, 4), seed + 3)
    if dust:
        dr, dlv = dust
        for y in range(size):
            for x in range(size):
                if n[y, x] > 0.82 and (x + y) % 3 == 0:
                    a[y, x] = dr[dlv]
    return a


# ---------------------------------------------------------------------------------------------- metal
def corrugated(size, r, rust_r, seed):
    a = canvas(size, size)
    prof = [4, 4, 3, 3, 2, 1, 2, 3]                           # rib cross-section, lit from the left
    for y in range(size):
        for x in range(size):
            a[y, x] = r[prof[x % 8]]
    for x in range(0, size, 16):                            # sheet overlap + rivets
        for y in range(size):
            put(a, x, y, r[0])
    for y in (4, size // 2 + 4):
        for x in range(2, size, 8):
            put(a, x, y, r[-1])
            put(a, x + 1, y + 1, r[1])
            for t in range(2, 6 + (x * 3) % 7):              # rust streak running down from the rivet
                put(a, x + 1, y + t, rust_r[2 + (t % 2)])
    w = pnoise(size, size, 3, seed)
    for y in range(size):
        for x in range(size):
            if w[y, x] > 0.8 and y > size * 0.6:
                a[y, x] = rust_r[3 if (x + y) % 2 else 2]
    return a


def painted(size, r, seed, base=3, chips=None, grime=None, panels=True, bolts=None):
    """Painted machine panel: flat paint, panel seams, chipped edges to bare metal, grime toward the bottom."""
    rng = np.random.default_rng(seed)
    a = canvas(size, size)
    w = pnoise(size, size, 4, seed)
    for y in range(size):
        for x in range(size):
            a[y, x] = r[base + (1 if w[y, x] > 0.7 else 0) - (1 if w[y, x] < 0.2 else 0)]
    if panels:
        for x in range(size):
            put(a, x, 0, r[min(len(r) - 1, base + 1)])
            put(a, x, size - 1, r[max(0, base - 2)])
        for y in range(size):
            put(a, 0, y, r[min(len(r) - 1, base + 1)])
            put(a, size - 1, y, r[max(0, base - 2)])
    if bolts:
        br, blv = bolts
        for (x, y) in ((3, 3), (size - 5, 3), (3, size - 5), (size - 5, size - 5)):
            rect(a, x, y, 2, 2, br[blv])
            put(a, x, y, br[blv + 1])
            put(a, x + 1, y + 1, br[blv - 1])
    if chips:
        cr, clv = chips
        for k in range(size // 6):
            x, y = int(rng.integers(0, size)), int(rng.integers(0, size))
            if w[y, x] > 0.55:
                rect(a, x, y, int(rng.integers(1, 3)), int(rng.integers(1, 3)), cr[clv])
                put(a, x, y - 1, r[min(len(r) - 1, base + 1)])
    if grime:
        gr, glv = grime
        for y in range(size * 3 // 4, size):
            for x in range(size):
                if (x * 5 + y * 3) % (size - y + 3) == 0 or w[y, x] > 0.85:
                    a[y, x] = gr[glv]
    return a


def tread(w, h, r):
    a = canvas(w, h)
    a[:] = r[1]
    for y in range(0, h, 8):
        for x in range(w):
            k = (x + (y // 8) * 4) % 16
            if k < 6:
                put(a, x, y + (k // 2), r[3])
                put(a, x, y + (k // 2) + 1, r[2])
            put(a, x, y + 7, r[0])
    return a


def belt(w, h, r, m):
    a = canvas(w, h)
    a[:] = r[2]
    for y in range(0, h, 8):
        for x in range(w):
            put(a, x, y, r[4])
            put(a, x, y + 1, r[0])
    for y in range(h):
        put(a, 0, y, m[3])
        put(a, w - 1, y, m[1])
    return a


def hazard(size, yel, ink):
    a = canvas(size, size)
    for y in range(size):
        for x in range(size):
            a[y, x] = yel[3] if ((x + y) // 8) % 2 == 0 else ink[1]
    return a


# ---------------------------------------------------------------------------------------------- signs
FONT = {
    "A": "01110100011000111111100011000110001", "B": "11110100011111010001100011000111110", "C": "01111100001000010000100001000001111",
    "D": "11110100011000110001100011000111110", "E": "11111100001111010000100001000011111", "F": "11111100001111010000100001000010000",
    "G": "01111100001000010111100011000101111", "H": "10001100011111110001100011000110001", "I": "11111001000010000100001000010011111",
    "J": "00111000100001000010100101001001100", "K": "10001100101010011000101001001010001", "L": "10000100001000010000100001000011111",
    "M": "10001110111010110001100011000110001", "N": "10001110011010110011100011000110001", "O": "01110100011000110001100011000101110",
    "P": "11110100011000111110100001000010000", "Q": "01110100011000110001101011001001101", "R": "11110100011000111110101001001010001",
    "S": "01111100001000001110000010000111110", "T": "11111001000010000100001000010000100", "U": "10001100011000110001100011000101110",
    "V": "10001100011000110001100010101000100", "W": "10001100011000110101101011101110001", "X": "10001100010101000100010101000110001",
    "Y": "10001100010101000100001000010000100", "Z": "11111000010001000100010001000011111", " ": "0" * 35,
    "-": "00000000000000011111000000000000000", "!": "00100001000010000100001000000000100", "4": "00010001100101010010111110001000010",
    "0": "01110100011001110101110011000101110", "1": "00100011000010000100001000010001110", "2": "01110100010000100010001000100011111",
    "5": "11111100001111000001000011000101110", "%": "11001110010001000100010001001110011",
}


def sign(text, w, h, bg, fg, border):
    a = canvas(w, h)
    a[:] = bg
    rect(a, 0, 0, w, 1, border)
    rect(a, 0, h - 1, w, 1, border)
    rect(a, 0, 0, 1, h, border)
    rect(a, w - 1, 0, 1, h, border)
    lines = text.split("\n")
    total_h = len(lines) * 9 - 2
    y0 = (h - total_h) // 2
    for li, line in enumerate(lines):
        x0 = (w - len(line) * 6 + 1) // 2
        for ci, ch in enumerate(line):
            g = FONT.get(ch, FONT[" "])
            for gy in range(7):
                for gx in range(5):
                    if g[gy * 5 + gx] == "1":
                        put(a, x0 + ci * 6 + gx, y0 + li * 9 + gy, fg)
    return a


# ---------------------------------------------------------------------------------------------- output
def md5(s):
    return hashlib.md5(s.encode()).hexdigest()


def save(name, a, rough=0.95, metal_spec=0.2, tiling=True, alpha=False):
    os.makedirs(TEX, exist_ok=True)
    os.makedirs(MAT, exist_ok=True)
    png = os.path.join(TEX, name + ".png")
    Image.fromarray(a).save(png, optimize=True)
    res = f"res://assets/textures/{name}.png"
    dest = f"res://.godot/imported/{name}.png-{md5(res)}.ctex"
    open(png + ".import", "w", newline="\n").write(f"""[remap]

importer="texture"
type="CompressedTexture2D"
path="{dest}"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{res}"
dest_files=["{dest}"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
""")
    scale = 64.0 / a.shape[1] if tiling else 1.0
    m = "M" + name[1:]
    open(os.path.join(MAT, m + ".tres"), "w", newline="\n").write(f"""[gd_resource type="StandardMaterial3D" load_steps=2 format=3]

[ext_resource type="Texture2D" path="{res}" id="1_albedo"]

[resource]
resource_name = "{m}"
albedo_texture = ExtResource("1_albedo")
metallic_specular = {metal_spec}
roughness = {rough}
uv1_scale = Vector3({scale:g}, {scale:g}, 1)
texture_filter = 4
""")
    return png


def phase5(stone, conc, soil, ink, tar, metal, rust):
    """Phase 5 deep-layer rock: copper-stained greenstone, gold-bearing quartz, crushed gravel, deep wall."""
    moss, lichen, ochre, yel = ramp("moss"), ramp("lichen"), ramp("motif_ochre"), ramp("road_yellow")
    save("T_QD_RockCopper", natural_strata(128, [ink[0], tar[1], moss[0], tar[2], moss[1], lichen[1]], 15, seams=(ink, 0), veins=(lichen, 2, 18)))
    save("T_QD_RockGold", natural_strata(128, [ink[1], conc[1], tar[2], conc[2], conc[3], conc[4]], 16, seams=(ink, 0), veins=(yel, len(yel) - 2, 16)))
    save("T_QD_RockGravel", gravel(64, conc, 17, base=4, dust=(stone, 3)))
    ink_c = ink[0]
    for stage, (count, length) in enumerate([(3, 14), (6, 22), (10, 30)], start=1):
        a = np.zeros((64, 64, 4), np.uint8)
        r = np.random.default_rng(40 + stage)
        for k in range(count):
            x, y = float(r.integers(8, 56)), float(r.integers(8, 56))
            ang = r.uniform(0, 6.283)
            for step in range(length):
                ang += r.uniform(-0.6, 0.6)
                x, y = (x + np.cos(ang)) % 64, (y + np.sin(ang)) % 64
                a[int(y), int(x)] = (*ink_c, 235)
                hy, hx = (int(y) + 1) % 64, (int(x) + 1) % 64
                if a[hy, hx, 3] == 0:
                    a[hy, hx] = (*conc[5], 150)
        save("T_QD_Crack%d" % stage, a, tiling=False)
    save("T_QD_RockDeep", natural_strata(128, [ink[1], tar[1], soil[1], tar[2], soil[2], conc[2]], 18, seams=(ink, 0)))


def main():
    stone, conc, soil, mud = ramp("stone_warm"), ramp("concrete"), ramp("soil"), ramp("mud")
    rust, metal, rubber, ink, tar = ramp("rust"), ramp("metal"), ramp("rubber"), ramp("ink"), ramp("tar")
    mustard, red, orange, yel = ramp("paint_mustard"), ramp("paint_red"), ramp("paint_orange"), ramp("sign_yellow")
    back, white, navy, green = ramp("sign_backing"), ramp("paint_white"), ramp("paint_navy"), ramp("paint_green")
    rock_lime = [conc[2], conc[3], conc[4], stone[3] if len(stone) > 3 else conc[5], conc[5], conc[6]]
    save("T_QD_RockLimestone", natural_strata(128, rock_lime, 11))
    save("T_QD_RockCoal", natural_strata(128, [ink[0], tar[1], tar[2], tar[3], conc[1], conc[2]], 12, seams=(ink, 0), veins=(metal, 3, 10)))
    save("T_QD_RockIron", natural_strata(128, [rust[0], rust[1], soil[2], rust[2], soil[3], rust[3]], 13, veins=(rust, 4, 14)))
    save("T_QD_CutLimestone", natural_strata(128, [conc[3], stone[2], conc[4], stone[3], conc[5], stone[4]], 15, cracks=5))
    save("T_QD_CliffStrata", natural_strata(128, [conc[2], stone[2], conc[3], stone[3], conc[4], stone[4]], 14, cracks=6))
    save("T_QD_QuarryFloor", calm_ground(256, soil, 21, base=3))
    save("T_QD_ExcavatedDirt", calm_ground(128, soil, 22, base=3))
    save("T_QD_Corrugated", corrugated(64, metal, rust, 31), rough=0.6, metal_spec=0.5)
    save("T_QD_CorrugatedRed", corrugated(64, red, rust, 32), rough=0.7, metal_spec=0.4)
    save("T_QD_PaintYellow", painted(64, [mustard[0], mustard[1], mustard[2], mustard[3], mustard[4], yel[-1]], 41, base=3,
                                      chips=(metal, 2), grime=(soil, 1), bolts=(metal, 3)), rough=0.75, metal_spec=0.35)
    save("T_QD_PaintRed", painted(64, red, 42, base=3, chips=(metal, 2), grime=(soil, 1), bolts=(metal, 3)), rough=0.75, metal_spec=0.35)
    save("T_QD_PaintOrange", painted(64, orange, 43, base=2, chips=(metal, 2), grime=(soil, 1)), rough=0.75, metal_spec=0.35)
    save("T_QD_SteelPlate", painted(64, metal, 44, base=2, chips=(rust, 2), grime=(rust, 1), bolts=(metal, 3)), rough=0.6, metal_spec=0.5)
    save("T_QD_SteelGreen", painted(64, green, 45, base=1, chips=(metal, 2), grime=(soil, 1), bolts=(metal, 3)), rough=0.7, metal_spec=0.4)
    phase5(stone, conc, soil, ink, tar, metal, rust)
    save("T_QD_Tire", tread(64, 64, rubber), rough=1.0, metal_spec=0.1)
    save("T_QD_Belt", belt(32, 32, rubber, metal), rough=1.0, metal_spec=0.1)
    save("T_QD_Hazard", hazard(32, yel, ink), rough=0.8)
    signs = {
        "T_QD_Sign_Office": ("QUARRY DAYS\nSITE OFFICE", 128, 32, white[1], navy[1], navy[0]),
        "T_QD_Sign_Garage": ("EQUIPMENT GARAGE", 128, 16, yel[3], ink[1], ink[0]),
        "T_QD_Sign_Sales": ("SALES", 64, 16, green[2], white[-1], green[0]),
        "T_QD_Sign_Orders": ("MACHINERY\nORDERS", 64, 32, navy[1], white[-1], navy[0]),
        "T_QD_Sign_Safety": ("HARD HAT AREA\nKEEP CLEAR", 96, 32, yel[3], ink[1], ink[0]),
        "T_QD_Sign_Storage": ("STORAGE", 64, 16, back[2] if len(back) > 2 else white[1], ink[1], ink[0]),
        "T_QD_Sign_Upgrades": ("UPGRADES", 64, 16, white[1], ink[1], ink[0]),
        "T_QD_Sign_Home": ("HOME", 64, 16, green[2], white[-1], green[0]),
    }
    for name, (txt, w, h, bg, fg, bd) in signs.items():
        save(name, sign(txt, w, h, bg, fg, bd), rough=0.8, tiling=False)
    print("textures:", len(os.listdir(TEX)) // 2)


if __name__ == "__main__":
    main()
