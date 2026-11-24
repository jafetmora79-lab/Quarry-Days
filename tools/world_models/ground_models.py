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


# ---------------------------------------------------------------------------------------------- the bucket
_mat("BucketSteel", (0.46, 0.49, 0.51), 0.7); _mat("BucketRim", (0.30, 0.32, 0.35), 0.7); _mat("BucketRust", (0.50, 0.28, 0.14))
_mat("BucketBand", (0.36, 0.38, 0.40), 0.7); _mat("BucketHandle", (0.16, 0.16, 0.17), 0.6); _mat("BucketDirt", (0.40, 0.28, 0.18))
_mat("BucketInner", (0.12, 0.11, 0.10))


def bucket(root):
    """Grandpa's old steel pail: a tapered body with a rolled rim, two ribs, a base ring, a wire bail handle on two ears, a few rust streaks and the load as a heap
    in a separate holder named "Fill" (the game scales and colours it by how full the bucket is). Origin on the ground at the centre of the base, 0.36 m tall."""
    import math
    t = TM("Body", root, holder=True)
    t.cyl((0, 0.17, 0), 0.175, 0.225, 0.34, "BucketSteel", seg=12)
    t.cyl((0, 0.335, 0), 0.215, 0.215, 0.012, "BucketInner", seg=12)                      # the dark inside, seen over the lip when empty
    t.cyl((0, 0.345, 0), 0.235, 0.235, 0.035, "BucketRim", seg=12)                         # the rolled rim
    t.cyl((0, 0.012, 0), 0.185, 0.185, 0.03, "BucketRim", seg=12)                          # the base ring
    for y, r in ((0.12, 0.198), (0.23, 0.214)):                                            # two pressed ribs
        t.cyl((0, y, 0), r, r, 0.022, "BucketBand", seg=12)
    r = random.Random(4)
    for k in range(5):                                                                     # rust streaks running down the body
        a = r.uniform(0, 6.28)
        rr = 0.21 + 0.004
        t.box((math.cos(a) * rr * 0.9, 0.2 - r.uniform(0, 0.08), math.sin(a) * rr * 0.9), (0.03, r.uniform(0.06, 0.16), 0.012), "BucketRust", rot_y=-a)
    for sx in (-1, 1):                                                                     # the ears the bail hangs from
        t.box((sx * 0.232, 0.325, 0), (0.03, 0.04, 0.05), "BucketRim")
    pts = []
    for i in range(0, 13):
        a = math.pi * i / 12
        pts.append((math.cos(a) * 0.235, 0.33 + math.sin(a) * 0.19, 0.0))
    t.tube(pts, 0.011, "BucketHandle", seg=5)
    t.finish()
    fl = TM("Fill", root, loc=(0, 0.3, 0), holder=True)                                    # the load: a heap that rises out of the pail
    rr = random.Random(9)
    chunk(fl, (0, 0.3, 0), (0.205, 0.14, 0.205), "BucketDirt", rr, 0.16, sub=1, base_clip=0.5)
    for k in range(4):
        a = k * 1.7
        chunk(fl, (math.cos(a) * 0.09, 0.36, math.sin(a) * 0.09), (0.07, 0.05, 0.07), "BucketDirt", rr, 0.3, sub=0, base_clip=0.5)
    fl.finish()


# ---------------------------------------------------------------------------------------------- scrub bushes and field stones (the quarry's surface decor)
_mat("BushDeep", (0.17, 0.29, 0.12)); _mat("BushMid", (0.28, 0.42, 0.16)); _mat("BushLight", (0.45, 0.55, 0.22)); _mat("BushDry", (0.58, 0.50, 0.24)); _mat("TwigBrown", (0.32, 0.23, 0.14))
_mat("FieldStoneA", (0.48, 0.42, 0.34)); _mat("FieldStoneB", (0.38, 0.34, 0.29)); _mat("FieldStoneC", (0.55, 0.48, 0.38)); _mat("FieldStoneMoss", (0.28, 0.36, 0.19))


def scrub_bush(root):
    """A scrub bush: a mound of overlapping leaf clumps in four greens (darker underneath, light and dry tips on top) on a few bare twigs. ~1.3 m wide, 0.8 m tall, origin on the ground."""
    t = TM("Body", root, holder=True)
    r = random.Random(31)
    for k in range(7):                                             # twigs showing at the base
        a = 2 * math.pi * k / 7 + r.uniform(-0.3, 0.3)
        d = r.uniform(0.05, 0.28)
        t.box((math.cos(a) * d, 0.12, math.sin(a) * d), (0.022, r.uniform(0.18, 0.3), 0.022), "TwigBrown", rot_y=a)
    mats = ["BushDeep", "BushMid", "BushMid", "BushLight"]
    for k in range(11):                                            # the body: clumps, low and wide at the bottom, smaller and lighter toward the top
        h = r.uniform(0.0, 1.0)
        a = r.uniform(0, 2 * math.pi)
        d = r.uniform(0.0, 0.42) * (1.1 - h * 0.7)
        sz = r.uniform(0.22, 0.34) * (1.0 - h * 0.35)
        y = 0.16 + h * 0.42
        chunk(t, (math.cos(a) * d, y, math.sin(a) * d), (sz * 1.15, sz * 0.85, sz * 1.1), mats[min(3, int(h * 3.4))] if k > 1 else "BushDeep", r, 0.20, sub=1, base_clip=0.6)
    for k in range(6):                                             # light and dry leaf tips poking out of the top
        a = r.uniform(0, 2 * math.pi)
        d = r.uniform(0.05, 0.4)
        sz = r.uniform(0.07, 0.12)
        chunk(t, (math.cos(a) * d, 0.55 + r.uniform(0.0, 0.2), math.sin(a) * d), (sz * 1.3, sz * 0.8, sz), "BushDry" if k % 3 == 0 else "BushLight", r, 0.25, sub=0, base_clip=0.5)
    t.finish()


def field_stone(root):
    """A field stone: one faceted boulder in two limestone tones with a flat-ish top, a smaller stone leaning against it, a couple of chips and a patch of moss low on the shaded side. ~1.0 m wide, 0.6 m tall."""
    t = TM("Body", root, holder=True)
    r = random.Random(58)
    chunk(t, (0.0, 0.0, 0.0), (0.46, 0.34, 0.40), "FieldStoneA", r, 0.18, sub=1, base_clip=0.45)
    chunk(t, (0.02, 0.22, 0.02), (0.34, 0.16, 0.30), "FieldStoneC", r, 0.16, sub=1, base_clip=0.2)          # the lighter weathered top
    chunk(t, (0.42, 0.0, 0.18), (0.22, 0.16, 0.2), "FieldStoneB", r, 0.2, sub=1, base_clip=0.4)
    chunk(t, (-0.38, 0.0, -0.2), (0.16, 0.11, 0.15), "FieldStoneB", r, 0.22, sub=0, base_clip=0.4)
    chunk(t, (-0.15, 0.0, 0.48), (0.1, 0.07, 0.09), "FieldStoneC", r, 0.25, sub=0, base_clip=0.4)
    chunk(t, (-0.18, 0.02, -0.34), (0.2, 0.1, 0.12), "FieldStoneMoss", r, 0.2, sub=0, base_clip=0.5)
    t.finish()
