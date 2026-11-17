"""Quarry ground models (Blender): faceted ore and rock chunks with real ore features, and clods of dug earth.
Registered by build_world.py:  ore_pieces (holders "<resource>_<0..2>"), dirt_clods.
Low-poly, flat shaded; materials carry NAMES only (scripts/art/world_models.gd COLOURS gives the game colours)."""
import math
import random

import qd_blender as Q
from tm import TM


def _mat(name, rgb, rough=1.0, emit=0.0):
    Q.MATERIALS[name] = (None, rgb, rough, 0.0, ({"emit": emit} if emit else {}))


_mat("LimeDark", (0.66, 0.62, 0.54)); _mat("LimeLight", (0.86, 0.82, 0.72)); _mat("LimeBand", (0.74, 0.58, 0.44))
_mat("CoalBody", (0.10, 0.10, 0.11)); _mat("CoalDark", (0.05, 0.05, 0.06)); _mat("CoalSheen", (0.42, 0.46, 0.52), 0.5)
_mat("IronRock", (0.36, 0.26, 0.21)); _mat("IronRed", (0.66, 0.24, 0.11)); _mat("IronBlack", (0.15, 0.13, 0.13))
_mat("CopperRock", (0.28, 0.36, 0.30)); _mat("Malachite", (0.20, 0.64, 0.46), 0.7); _mat("CopperOrange", (0.82, 0.44, 0.19), 0.6)
_mat("QuartzRock", (0.70, 0.68, 0.64)); _mat("QuartzWhite", (0.92, 0.92, 0.88)); _mat("GoldNugget", (1.0, 0.78, 0.16), 0.5, 0.35)
_mat("PebbleA", (0.58, 0.52, 0.44)); _mat("PebbleB", (0.45, 0.41, 0.37)); _mat("PebbleC", (0.70, 0.64, 0.54))
_mat("ClodDark", (0.27, 0.18, 0.12)); _mat("ClodMid", (0.40, 0.28, 0.18)); _mat("ClodLight", (0.52, 0.37, 0.25)); _mat("ClodStone", (0.62, 0.57, 0.49))

PHI = (1 + 5 ** 0.5) / 2


def _ico(sub):
    v = [(-1, PHI, 0), (1, PHI, 0), (-1, -PHI, 0), (1, -PHI, 0), (0, -1, PHI), (0, 1, PHI), (0, -1, -PHI), (0, 1, -PHI), (PHI, 0, -1), (PHI, 0, 1), (-PHI, 0, -1), (-PHI, 0, 1)]
    f = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9),
         (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    v = [tuple(c / math.sqrt(x * x + y * y + z * z) for c in (x, y, z)) for (x, y, z) in v]
    for _ in range(sub):
        cache, nf = {}, []

        def mid(a, b):
            k = (min(a, b), max(a, b))
            if k not in cache:
                p = tuple((v[a][i] + v[b][i]) / 2 for i in range(3))
                l = math.sqrt(sum(c * c for c in p))
                v.append(tuple(c / l for c in p))
                cache[k] = len(v) - 1
            return cache[k]
        for a, b, c in f:
            ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
            nf += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        f = nf
    return v, f


_ICO = {0: _ico(0), 1: _ico(1)}


def chunk(t, c, size, mat, r, jitter=0.22, sub=1, base_clip=0.5):
    """A faceted boulder at c with half-extents `size` (x, y, z), flattened underneath so it sits on the ground."""
    v, f = _ICO[sub]
    out = []
    for (x, y, z) in v:
        k = 1.0 + (r.random() - 0.5) * 2 * jitter
        py = y * size[1] * k
        py = max(py, -size[1] * base_clip)
        out.append((c[0] + x * size[0] * k, c[1] + py, c[2] + z * size[2] * k))
    t.solid(out, f, mat)


def crystal(t, base, direction, length, rad, mat, seg=5):
    """A hexagonal-ish crystal spike from `base` along `direction`."""
    dx, dy, dz = direction
    l = math.sqrt(dx * dx + dy * dy + dz * dz)
    d = (dx / l, dy / l, dz / l)
    ref = (0, 1, 0) if abs(d[1]) < 0.9 else (1, 0, 0)
    ux = (d[1] * ref[2] - d[2] * ref[1], d[2] * ref[0] - d[0] * ref[2], d[0] * ref[1] - d[1] * ref[0])
    ul = math.sqrt(sum(c * c for c in ux))
    ux = tuple(c / ul for c in ux)
    uy = (d[1] * ux[2] - d[2] * ux[1], d[2] * ux[0] - d[0] * ux[2], d[0] * ux[1] - d[1] * ux[0])
    ring0, ring1 = [], []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        off = tuple(ux[k] * math.cos(a) * rad + uy[k] * math.sin(a) * rad for k in range(3))
        ring0.append(tuple(base[k] + off[k] for k in range(3)))
        ring1.append(tuple(base[k] + d[k] * length * 0.7 + off[k] * 0.7 for k in range(3)))
    tip = tuple(base[k] + d[k] * length for k in range(3))
    verts = ring0 + ring1 + [tip, tuple(base)]
    faces = []
    for i in range(seg):
        j = (i + 1) % seg
        faces += [(i, j, seg + j, seg + i), (seg + i, seg + j, 2 * seg)]
        faces.append((j, i, 2 * seg + 1))
    t.solid(verts, [tuple(f) for f in faces], mat)


def _on_body(r, size, lift=0.0):
    """A point on the surface of a body ellipsoid, biased to the upper half, and its outward direction."""
    a = r.uniform(0, 2 * math.pi)
    e = r.uniform(0.15, 1.1)
    x, y, z = math.cos(a) * math.cos(e), math.sin(e), math.sin(a) * math.cos(e)
    return (x * size[0], y * size[1] + lift, z * size[2]), (x, y, z)


def piece(t, res, i):
    r = random.Random(900 + i * 17 + len(res))
    s = (r.uniform(0.24, 0.31), r.uniform(0.18, 0.24), r.uniform(0.22, 0.30))
    cy = s[1] * 0.45
    if res == "limestone":
        chunk(t, (0, cy, 0), s, "LimeDark", r, 0.18)
        chunk(t, (r.uniform(-0.03, 0.03), cy + s[1] * 0.42, r.uniform(-0.03, 0.03)), (s[0] * 0.86, s[1] * 0.5, s[2] * 0.86), "LimeLight", r, 0.16, base_clip=0.2)
        chunk(t, (0, cy + s[1] * 0.1, 0), (s[0] * 1.03, s[1] * 0.12, s[2] * 1.03), "LimeBand", r, 0.1, sub=0, base_clip=1.0)
    elif res == "coal":
        chunk(t, (0, cy, 0), s, "CoalBody", r, 0.3)
        for k in range(3):
            p, n = _on_body(r, (s[0] * 0.9, s[1] * 0.9, s[2] * 0.9), cy)
            chunk(t, p, (0.075, 0.03, 0.075), "CoalSheen", r, 0.2, sub=0, base_clip=1.0)
        chunk(t, (s[0] * 0.5, cy - s[1] * 0.2, s[2] * 0.3), (s[0] * 0.5, s[1] * 0.55, s[2] * 0.5), "CoalDark", r, 0.25, sub=0)
    elif res == "iron_ore":
        chunk(t, (0, cy, 0), s, "IronRock", r, 0.24)
        for k in range(4):
            p, n = _on_body(r, s, cy)
            chunk(t, p, (r.uniform(0.07, 0.11), 0.045, r.uniform(0.07, 0.11)), "IronRed", r, 0.25, sub=0, base_clip=1.0)
        for k in range(3):
            p, n = _on_body(r, s, cy)
            chunk(t, p, (0.045, 0.03, 0.045), "IronBlack", r, 0.2, sub=0, base_clip=1.0)
    elif res == "copper_ore":
        chunk(t, (0, cy, 0), s, "CopperRock", r, 0.24)
        for k in range(4):
            p, n = _on_body(r, s, cy)
            crystal(t, (p[0] * 0.92, p[1] * 0.92, p[2] * 0.92), (n[0], n[1] + 0.3, n[2]), r.uniform(0.09, 0.15), r.uniform(0.025, 0.04), "Malachite")
        for k in range(2):
            p, n = _on_body(r, s, cy)
            chunk(t, p, (0.06, 0.04, 0.06), "CopperOrange", r, 0.25, sub=0, base_clip=1.0)
    elif res == "gold_ore":
        chunk(t, (0, cy, 0), s, "QuartzRock", r, 0.22)
        chunk(t, (s[0] * 0.2, cy + s[1] * 0.55, -s[2] * 0.1), (s[0] * 0.45, s[1] * 0.4, s[2] * 0.45), "QuartzWhite", r, 0.25, sub=0, base_clip=0.2)
        for k in range(5):
            p, n = _on_body(r, s, cy)
            chunk(t, p, (r.uniform(0.035, 0.06),) * 3, "GoldNugget", r, 0.3, sub=0, base_clip=1.0)
    elif res == "gravel":
        for k in range(8):
            a = r.uniform(0, 2 * math.pi)
            d = r.uniform(0.0, 0.2)
            rr = r.uniform(0.06, 0.12)
            chunk(t, (math.cos(a) * d, rr * 0.4, math.sin(a) * d), (rr, rr * 0.7, rr * 0.9), r.choice(["PebbleA", "PebbleB", "PebbleC"]), r, 0.25, sub=0)
    else:  # soil, topsoil
        chunk(t, (0, cy * 0.8, 0), (s[0] * 1.05, s[1] * 0.8, s[2] * 1.05), "ClodMid", r, 0.3)
        chunk(t, (s[0] * 0.5, cy * 0.5, s[2] * 0.4), (s[0] * 0.55, s[1] * 0.55, s[2] * 0.5), "ClodDark", r, 0.3, sub=0)
        chunk(t, (-s[0] * 0.45, cy * 0.4, s[2] * 0.2), (s[0] * 0.4, s[1] * 0.45, s[2] * 0.4), "ClodLight", r, 0.3, sub=0)
        chunk(t, (-s[0] * 0.1, cy * 0.45, -s[2] * 0.55), (0.06, 0.05, 0.06), "ClodStone", r, 0.2, sub=0)


RESOURCES = ["limestone", "coal", "iron_ore", "copper_ore", "gold_ore", "gravel", "soil"]


def ore_pieces(root):
    for res in RESOURCES:
        for i in range(3):
            t = TM("%s_%d" % (res, i), root, holder=True)
            piece(t, res, i)
            t.finish()


def dirt_clods(root):
    """A scatter of dug-earth clods (replaces the flat tan patches): a cluster of lumps with a few crumbs and stones."""
    t = TM("Body", root, holder=True)
    r = random.Random(77)
    for k in range(6):
        a = 2 * math.pi * k / 6 + r.uniform(-0.3, 0.3)
        d = r.uniform(0.15, 0.55) if k else 0.0
        s = r.uniform(0.16, 0.30)
        chunk(t, (math.cos(a) * d, 0.0, math.sin(a) * d), (s, s * r.uniform(0.45, 0.7), s * r.uniform(0.8, 1.1)), ["ClodMid", "ClodDark", "ClodLight"][k % 3], r, 0.28, sub=0, base_clip=0.3)
    for k in range(7):
        a = r.uniform(0, 2 * math.pi)
        d = r.uniform(0.5, 0.9)
        s = r.uniform(0.04, 0.08)
        chunk(t, (math.cos(a) * d, 0.0, math.sin(a) * d), (s, s * 0.6, s), "ClodStone" if k % 3 == 0 else "ClodDark", r, 0.3, sub=0, base_clip=0.3)
    t.finish()
