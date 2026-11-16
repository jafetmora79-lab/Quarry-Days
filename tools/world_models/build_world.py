"""QUARRY DAYS - the living landscape, modelled in Blender (5.x, headless), low-poly and flat shaded like the rest of the game:

    blender -b --factory-startup -P tools/world_models/build_world.py [-- pine_tall deer ...]

Writes assets/world/WLD_QD_<name>.glb (+ src/<name>.blend, ignored by Godot). Godot model space: metres, +Y up, origin on the ground at the model's centre, an animal
or a portal faces -Z. Materials carry NAMES only; the game swaps its own in (scripts/art/world_models.gd).
Sets: forest (pine_tall, pine_young, birch, log, stump, bush, fern, grass, flowers, mossy_stone), mountains (peak_a, peak_b, ridge, cliff, foothill), the tunnel
(tunnel_portal, tunnel_set) and wildlife (deer, rabbit: static body plus named holders at their hinges for the game's simple animation).
"""
import bpy, math, os, sys, random
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "tool_models"))
import qd_blender as Q
from qd_blender import empty
from tm import TM

OUT = os.path.join(Q.REPO, "assets", "world")
SRC = os.path.join(OUT, "src")

Q.MATERIALS.update({
    "Bark":      (None, (0.34, 0.23, 0.15), 1.0, 0.0, {}),
    "BirchBark": (None, (0.86, 0.84, 0.77), 1.0, 0.0, {}),
    "Pine":      (None, (0.16, 0.33, 0.20), 1.0, 0.0, {}),
    "PineLight": (None, (0.25, 0.43, 0.24), 1.0, 0.0, {}),
    "Leaf":      (None, (0.42, 0.55, 0.20), 1.0, 0.0, {}),
    "LeafWarm":  (None, (0.68, 0.58, 0.20), 1.0, 0.0, {}),
    "Moss":      (None, (0.28, 0.44, 0.20), 1.0, 0.0, {}),
    "Grass":     (None, (0.50, 0.56, 0.25), 1.0, 0.0, {}),
    "Fern":      (None, (0.20, 0.45, 0.23), 1.0, 0.0, {}),
    "FlowerW":   (None, (0.95, 0.94, 0.88), 1.0, 0.0, {}),
    "FlowerY":   (None, (0.96, 0.80, 0.22), 1.0, 0.0, {}),
    "FlowerP":   (None, (0.66, 0.40, 0.76), 1.0, 0.0, {}),
    "FlowerR":   (None, (0.85, 0.28, 0.22), 1.0, 0.0, {}),
    "RockA":     (None, (0.62, 0.55, 0.45), 1.0, 0.0, {}),
    "RockB":     (None, (0.50, 0.45, 0.39), 1.0, 0.0, {}),
    "RockC":     (None, (0.72, 0.65, 0.52), 1.0, 0.0, {}),
    "RockD":     (None, (0.42, 0.40, 0.38), 1.0, 0.0, {}),
    "Fur":       (None, (0.62, 0.42, 0.25), 1.0, 0.0, {}),
    "FurLight":  (None, (0.88, 0.78, 0.62), 1.0, 0.0, {}),
    "Antler":    (None, (0.82, 0.74, 0.56), 1.0, 0.0, {}),
    "Dark":      (None, (0.10, 0.09, 0.08), 1.0, 0.0, {}),
    "RabbitFur": (None, (0.60, 0.50, 0.40), 1.0, 0.0, {}),
    "RabbitWhite": (None, (0.93, 0.91, 0.86), 1.0, 0.0, {}),
    "Pink":      (None, (0.92, 0.62, 0.62), 1.0, 0.0, {}),
    "Timber":    (None, (0.45, 0.31, 0.18), 1.0, 0.0, {}),
    "Steel":     (None, (0.38, 0.40, 0.42), 0.65, 0.2, {}),
    "Concrete":  (None, (0.55, 0.55, 0.53), 1.0, 0.0, {}),
    "Hazard":    (None, (0.90, 0.72, 0.10), 0.8, 0.0, {}),
    "Lamp":      (None, (1.0, 0.86, 0.55), 0.5, 0.0, {"emit": 2.0}),
    "Paint":     (None, (0.90, 0.78, 0.20), 0.9, 0.0, {}),
})


def rnd(seed):
    return random.Random(seed)


def blob(t, c, r, h, mat, seg=6, squash=1.0):
    """A chunky low-poly lump: a short double cone (wide in the middle)."""
    x, y, z = c
    t.cyl((x, y - h * 0.25, z), r * 0.55, r, h * 0.5, mat, seg=seg)
    t.cyl((x, y + h * 0.25, z), r, r * 0.35, h * 0.5, mat, seg=seg)


# ------------------------------------------------------------------------------------------------------------------------------ forest
def pine_tall(root):
    t = TM("Body", root, holder=True)
    t.cyl((0, 1.6, 0), 0.30, 0.17, 3.2, "Bark", seg=5)                                          # trunk, visible up the middle
    t.cyl((0, 5.0, 0), 0.17, 0.08, 3.6, "Bark", seg=5)
    tiers = [(1.4, 1.9, 2.4, "Pine"), (2.9, 1.6, 2.2, "PineLight"), (4.3, 1.3, 2.0, "Pine"), (5.6, 1.0, 1.8, "PineLight"), (6.8, 0.7, 1.6, "Pine"), (7.8, 0.35, 1.2, "PineLight")]
    r = rnd(11)
    for (y, rad, h, m) in tiers:
        t.cyl((r.uniform(-0.05, 0.05), y + h * 0.45, r.uniform(-0.05, 0.05)), rad, 0.06, h, m, seg=7, phase=r.uniform(0, 1))
        t.cyl((0, y - 0.02, 0), rad * 0.2, rad, 0.12, m, seg=7)                                  # the skirt of each tier
    t.finish()


def pine_young(root):
    t = TM("Body", root, holder=True)
    t.cyl((0, 0.5, 0), 0.12, 0.07, 1.0, "Bark", seg=5)
    for k, (y, rad, h) in enumerate([(0.5, 1.0, 1.3), (1.4, 0.78, 1.2), (2.2, 0.52, 1.0)]):
        t.cyl((0, y + h * 0.45, 0), rad, 0.05, h, "PineLight" if k % 2 == 0 else "Pine", seg=6, phase=k * 0.3)
    t.finish()


def birch(root):
    t = TM("Body", root, holder=True)
    t.cyl((0, 1.6, 0), 0.2, 0.12, 3.4, "BirchBark", seg=5)
    for k in range(4):                                                                               # dark bands on the white bark
        t.cyl((0, 0.7 + k * 0.75, 0), 0.19 - k * 0.012, 0.19 - k * 0.012, 0.05, "Dark", seg=5)
    t.bar((0, 2.4, 0), (0.6, 3.5, 0.2), 0.1, 0.1, "BirchBark", up=(0, 0, 1))
    t.bar((0, 2.7, 0), (-0.55, 3.7, -0.25), 0.1, 0.1, "BirchBark", up=(0, 0, 1))
    r = rnd(5)
    for (x, y, z, rad, m) in [(0, 4.2, 0, 1.25, "Leaf"), (0.7, 3.5, 0.3, 0.9, "LeafWarm"), (-0.7, 3.7, -0.3, 1.0, "Leaf"), (0.1, 5.0, -0.1, 0.8, "Leaf"), (-0.2, 3.2, 0.7, 0.75, "Leaf")]:
        blob(t, (x, y, z), rad, rad * 1.1, m, seg=6)
    t.finish()


def log(root):
    t = TM("Body", root, holder=True)
    t.cyl((0, 0.3, 0), 0.3, 0.28, 2.4, "Bark", seg=7, axis='x')
    t.cyl((1.21, 0.3, 0), 0.26, 0.26, 0.04, "FurLight", seg=7, axis='x')                          # the cut end
    t.cyl((-1.21, 0.3, 0), 0.26, 0.26, 0.04, "FurLight", seg=7, axis='x')
    t.box((0.2, 0.62, 0.05), (1.0, 0.07, 0.3), "Moss")
    t.bar((-0.4, 0.4, 0.28), (-0.9, 0.6, 0.65), 0.07, 0.07, "Bark", up=(0, 1, 0))                 # a broken branch stub
    t.finish()


def stump(root):
    t = TM("Body", root, holder=True)
    t.cyl((0, 0.25, 0), 0.4, 0.32, 0.5, "Bark", seg=7)
    t.cyl((0, 0.51, 0), 0.31, 0.31, 0.03, "FurLight", seg=7)
    t.cyl((0, 0.53, 0), 0.14, 0.14, 0.02, "Fur", seg=7)
    t.box((0.18, 0.08, 0.3), (0.3, 0.16, 0.18), "Moss")
    for a in (0.3, 2.2, 4.0):                                                                          # roots
        t.bar((math.cos(a) * 0.3, 0.15, math.sin(a) * 0.3), (math.cos(a) * 0.62, 0.02, math.sin(a) * 0.62), 0.12, 0.1, "Bark", up=(0, 1, 0))
    t.finish()


def bush(root):
    t = TM("Body", root, holder=True)
    r = rnd(21)
    for k in range(5):
        a = k * 1.3
        blob(t, (math.cos(a) * 0.45, 0.35 + r.uniform(0, 0.2), math.sin(a) * 0.45), r.uniform(0.45, 0.6), 0.7, "Leaf" if k % 2 == 0 else "Moss", seg=5)
    blob(t, (0, 0.55, 0), 0.6, 0.9, "Leaf", seg=6)
    for k in range(5):
        a = k * 1.25 + 0.5
        t.box((math.cos(a) * 0.55, 0.72, math.sin(a) * 0.55), (0.07, 0.07, 0.07), "FlowerR")       # berries
    t.finish()


def fern(root):
    t = TM("Body", root, holder=True)
    for k in range(8):
        a = k * math.tau / 8
        ln = 0.9 + 0.2 * (k % 2)
        t.bar((0, 0.06, 0), (math.cos(a) * ln, 0.5 - 0.1 * (k % 2), math.sin(a) * ln), 0.04, 0.2, "Fern", up=(0, 1, 0))
        t.bar((math.cos(a) * ln * 0.5, 0.36, math.sin(a) * ln * 0.5), (math.cos(a) * ln, 0.42 - 0.1 * (k % 2), math.sin(a) * ln), 0.03, 0.34, "Moss", up=(0, 1, 0))
    t.finish()


def grass(root):
    t = TM("Body", root, holder=True)
    r = rnd(31)
    for k in range(11):
        a = r.uniform(0, math.tau)
        d = r.uniform(0.0, 0.28)
        h = r.uniform(0.35, 0.8)
        bx, bz = math.cos(a) * d, math.sin(a) * d
        lean = r.uniform(0.05, 0.25)
        t.bar((bx, 0.0, bz), (bx + math.cos(a) * lean, h, bz + math.sin(a) * lean), 0.04, 0.09, "Grass" if k % 3 else "Leaf", up=(0, 1, 0))
    t.finish()


def flowers(root):
    t = TM("Body", root, holder=True)
    r = rnd(41)
    cols = ["FlowerW", "FlowerY", "FlowerP", "FlowerR"]
    for k in range(7):
        a = r.uniform(0, math.tau)
        d = r.uniform(0.05, 0.4)
        x, z = math.cos(a) * d, math.sin(a) * d
        h = r.uniform(0.3, 0.55)
        t.bar((x, 0.0, z), (x, h, z), 0.03, 0.03, "Fern", up=(1, 0, 0))
        t.box((x, h + 0.03, z), (0.11, 0.05, 0.11), cols[k % 4])
        t.box((x, h + 0.05, z), (0.04, 0.04, 0.04), "FlowerY")
    for k in range(4):
        a = k * 1.6
        t.bar((0, 0.0, 0), (math.cos(a) * 0.35, 0.18, math.sin(a) * 0.35), 0.04, 0.12, "Grass", up=(0, 1, 0))
    t.finish()


def mossy_stone(root):
    t = TM("Body", root, holder=True)
    t.hexa([(-0.5, 0.0, -0.4), (0.5, 0.0, -0.45), (0.55, 0.0, 0.4), (-0.45, 0.0, 0.45), (-0.38, 0.55, -0.25), (0.3, 0.6, -0.3), (0.35, 0.5, 0.25), (-0.3, 0.48, 0.3)], "RockD")
    t.hexa([(-0.4, 0.5, -0.27), (0.3, 0.55, -0.32), (0.36, 0.46, 0.26), (-0.32, 0.44, 0.32), (-0.3, 0.68, -0.18), (0.22, 0.72, -0.2), (0.25, 0.62, 0.18), (-0.22, 0.6, 0.2)], "Moss")
    t.hexa([(0.55, 0.0, -0.1), (0.95, 0.0, -0.05), (0.9, 0.0, 0.3), (0.5, 0.0, 0.25), (0.62, 0.3, -0.05), (0.88, 0.32, 0.0), (0.84, 0.28, 0.24), (0.58, 0.26, 0.2)], "RockB")
    t.finish()


# ------------------------------------------------------------------------------------------------------------------------------ mountains
def smooth(a, b, x):
    k = max(0.0, min(1.0, (x - a) / (b - a)))
    return k * k * (3 - 2 * k)


def mountain(root, seed, W, D, H, bumps, res=34, ridged=0.42, trees=True):
    """A mountain as a faceted height field: gaussian masses at the given summits (x, z, radius, height factor) shaped by ridged noise, fading to the ground at the edge.
    Faces are coloured by height band (alternating strata) and by steepness (dark crags on the steep ones, moss on the gentle low ones); a skirt of pines stands on the gentle
    lower slopes. The silhouette is irregular and crooked: no two peaks are alike. Visual only (it stands beyond the property)."""
    t = TM("Body", root, holder=True)
    r = rnd(seed)
    waves = [(r.uniform(0, math.tau), r.uniform(0.05, 0.16), r.uniform(0, 6.3), r.uniform(0.5, 1.0)) for _ in range(6)]
    def height(x, z):
        nx, nz = x / (W * 0.5), z / (D * 0.5)
        edge = smooth(1.0, 0.45, math.sqrt(nx * nx + nz * nz))
        mass = 0.0
        for (bx, bz, br, bh) in bumps:
            d2 = ((x - bx * W * 0.5) ** 2 + (z - bz * D * 0.5) ** 2) / (br * W * 0.5) ** 2
            mass = max(mass, bh * math.exp(-d2 * 1.4))
        rg = 0.0
        for (ang, fr, ph, am) in waves:
            u = x * math.cos(ang) + z * math.sin(ang)
            rg += am * (1.0 - abs(math.sin(u * fr + ph)))
        rg /= len(waves)
        hgt = H * edge * mass * (1.0 - ridged + ridged * 2.0 * rg)
        return max(0.0, hgt)
    n = res
    pts = {}
    for i in range(n + 1):
        for j in range(n + 1):
            x = -W / 2 + W * i / n + (r.uniform(-0.3, 0.3) * W / n if 0 < i < n else 0)
            z = -D / 2 + D * j / n + (r.uniform(-0.3, 0.3) * D / n if 0 < j < n else 0)
            pts[(i, j)] = (x, height(x, z), z)
    bands = ["RockD", "RockB", "RockA", "RockC", "RockB", "RockA"]
    groups = {}
    for i in range(n):
        for j in range(n):
            q = [pts[(i, j)], pts[(i, j + 1)], pts[(i + 1, j + 1)], pts[(i + 1, j)]]
            ym = sum(p[1] for p in q) / 4
            if ym < 0.05 and max(p[1] for p in q) < 0.1:
                continue
            slope = (max(p[1] for p in q) - min(p[1] for p in q)) / (W / n)
            band = int(ym / H * 7.0)
            if slope > 1.1:
                m = "RockD" if band % 2 == 0 else "RockB"
            elif ym < H * 0.32 and slope < 0.55:
                m = "Moss"
            else:
                m = bands[band % len(bands)]
            groups.setdefault(m, []).append(q)
    for m, quads in groups.items():
        verts, faces = [], []
        for q in quads:
            base = len(verts)
            verts += q
            faces.append((base, base + 1, base + 2, base + 3))
        t.solid(verts, faces, m)
    if trees:
        for k in range(int(W * D / 90)):
            x, z = r.uniform(-W * 0.48, W * 0.48), r.uniform(-D * 0.48, D * 0.48)
            y = height(x, z)
            e = 0.8
            slope = abs(height(x + e, z) - y) + abs(height(x, z + e) - y)
            if y < 0.5 or y > H * 0.5 or slope > 1.1:
                continue
            hh = r.uniform(4.0, 8.0)
            t.cyl((x, y + 0.5, z), 0.14, 0.1, 1.0, "Bark", seg=4)
            t.cyl((x, y + 0.9 + hh * 0.5, z), r.uniform(1.2, 2.0), 0.06, hh, "Pine" if k % 2 else "PineLight", seg=5)
    t.finish()


def peak_a(root):
    mountain(root, 71, 90.0, 70.0, 52.0, [(0.0, 0.0, 0.55, 1.0), (0.5, 0.3, 0.35, 0.7), (-0.5, -0.2, 0.3, 0.6)])


def peak_b(root):
    mountain(root, 72, 110.0, 50.0, 42.0, [(-0.4, 0.0, 0.35, 0.85), (0.3, 0.05, 0.4, 1.0), (0.75, -0.1, 0.25, 0.6)], res=36)


def ridge(root):
    mountain(root, 73, 150.0, 40.0, 30.0, [(-0.7, 0, 0.2, 0.7), (-0.3, 0.05, 0.22, 1.0), (0.1, 0, 0.22, 0.8), (0.5, 0.05, 0.2, 0.95), (0.85, 0, 0.15, 0.55)], res=44)


def foothill(root):
    mountain(root, 74, 50.0, 40.0, 14.0, [(0, 0, 0.6, 1.0), (0.4, 0.1, 0.3, 0.6)], res=24)


def cliff(root):
    """A cliff wall 28 m long: vertical strata slabs, a broken top edge, a talus slope at the foot with boulders (the quarry's rim and the property's far edge)."""
    t = TM("Body", root, holder=True)
    r = rnd(75)
    mats = ["RockA", "RockB", "RockC", "RockD"]
    for k in range(7):
        x0 = -14.0 + k * 4.0
        h = r.uniform(11.0, 16.0)
        for li in range(5):
            lh = h / 5
            jx = r.uniform(-0.3, 0.3) + li * r.uniform(-0.1, 0.1)
            w = 4.2 - li * 0.2
            t.hexa([(x0 + jx - w / 2, li * lh, -2.2), (x0 + jx + w / 2, li * lh, -2.1), (x0 + jx + w / 2, li * lh, 2.0), (x0 + jx - w / 2, li * lh, 2.2),
                    (x0 + jx - w / 2 + 0.2, (li + 1) * lh, -2.0 + li * 0.25), (x0 + jx + w / 2 - 0.1, (li + 1) * lh, -1.9 + li * 0.25), (x0 + jx + w / 2 - 0.1, (li + 1) * lh, 1.7), (x0 + jx - w / 2 + 0.2, (li + 1) * lh, 1.8)], mats[(k + li) % 4])
    for k in range(10):
        x = r.uniform(-14, 14)
        s = r.uniform(0.8, 1.8)
        t.hexa([(x - s, 0, -2.4 - s), (x + s, 0, -2.4 - s), (x + s, 0, -2.4 + s), (x - s, 0, -2.4 + s), (x - s * 0.6, s * 0.9, -2.4 - s * 0.6), (x + s * 0.6, s, -2.4 - s * 0.6), (x + s * 0.6, s * 0.8, -2.4 + s * 0.6), (x - s * 0.6, s * 0.9, -2.4 + s * 0.6)], mats[k % 4])
    t.finish()


# ------------------------------------------------------------------------------------------------------------------------------ tunnel
OW, OH = 6.8, 4.4               # the opening the game's tunnel interior has


def tunnel_portal(root):
    """The carved entrance, facing +Z (the tunnel runs toward -Z from z = 0). A rock face with an arched cut, a timber portal frame and braces, a hazard-striped steel
    lintel, two warning signs, wall lamps with cages, and a drainage ditch with a grate beside the road. Clear opening 6.8 x 4.4 m."""
    t = TM("Body", root, holder=True)
    r = rnd(81)
    W2 = OW / 2
    # the rock face: a left and right mass beside the opening, a head above it, each in layered slabs
    for side in (-1, 1):
        for li in range(5):
            y0 = li * 2.0
            w = 7.5 - li * 1.0
            x0 = side * (W2 + 0.6 + w / 2)
            t.hexa([(x0 - w / 2, y0, -2.5), (x0 + w / 2, y0, -2.5), (x0 + w / 2, y0, 1.2 - li * 0.25), (x0 - w / 2, y0, 1.2 - li * 0.25),
                    (x0 - w / 2 + 0.3, y0 + 2.05, -2.3), (x0 + w / 2 - 0.3, y0 + 2.05, -2.3), (x0 + w / 2 - 0.3, y0 + 2.05, 0.9 - li * 0.25), (x0 - w / 2 + 0.3, y0 + 2.05, 0.9 - li * 0.25)],
                   ["RockA", "RockB", "RockC", "RockB", "RockA"][li])
    for li in range(4):                                                                              # the head over the opening
        y0 = OH + 0.9 + li * 1.8
        w = OW + 2.4 + 2.4 - li * 1.5
        t.hexa([(-w / 2, y0, -2.5), (w / 2, y0, -2.5), (w / 2, y0, 1.0 - li * 0.3), (-w / 2, y0, 1.0 - li * 0.3),
                (-w / 2 + 0.3, y0 + 1.85, -2.3), (w / 2 - 0.3, y0 + 1.85, -2.3), (w / 2 - 0.3, y0 + 1.85, 0.8 - li * 0.3), (-w / 2 + 0.3, y0 + 1.85, 0.8 - li * 0.3)], ["RockB", "RockA", "RockC", "RockB"][li])
    t.box((0, OH + 0.45, -0.7), (OW + 2.0, 0.9, 3.4), "RockD")                                       # the arch's stone lining above the frame
    # timber frame: posts, header, knee braces, a steel lintel with hazard stripes
    for side in (-1, 1):
        t.box((side * (W2 + 0.3), OH / 2, 1.0), (0.55, OH, 0.55), "Timber")
        t.box((side * (W2 + 0.3), 0.2, 1.0), (0.8, 0.4, 0.8), "Concrete")
        t.bar((side * (W2 + 0.3), OH - 1.4, 1.0), (side * (W2 - 1.1), OH, 1.0), 0.2, 0.28, "Timber", up=(0, 0, 1))
    t.box((0, OH + 0.25, 1.0), (OW + 1.2, 0.5, 0.6), "Timber")
    t.box((0, OH + 0.62, 1.1), (OW + 1.4, 0.18, 0.7), "Steel")
    for k in range(9):
        t.box((-OW / 2 - 0.4 + k * (OW + 0.8) / 8, OH + 0.62, 1.46), ((OW + 0.8) / 16, 0.18, 0.03), "Hazard" if k % 2 == 0 else "Dark")
    # warning signs on posts, wall lamps with cages
    for side in (-1, 1):
        t.box((side * (W2 + 1.5), 1.4, 1.6), (0.07, 2.8, 0.07), "Steel")
        t.box((side * (W2 + 1.5), 2.5, 1.66), (0.9, 0.9, 0.04), "Paint")
        t.box((side * (W2 + 1.5), 2.5, 1.69), (0.62, 0.62, 0.02), "Dark")
        t.box((side * (W2 + 1.5), 2.62, 1.71), (0.08, 0.34, 0.02), "Paint")
        t.box((side * (W2 + 1.5), 2.3, 1.71), (0.08, 0.08, 0.02), "Paint")
        t.box((side * (W2 + 0.05), 3.4, 1.4), (0.5, 0.3, 0.3), "Lamp")
        for dz in (-0.18, 0.18):
            t.box((side * (W2 + 0.05), 3.4, 1.4 + dz), (0.56, 0.36, 0.03), "Steel")
    # drainage: a concrete ditch along the road's right edge, with grates, and gravel bedding at the road edges
    for side in (-1, 1):
        t.box((side * (W2 - 0.25), 0.04, 3.5), (0.5, 0.08, 7.0), "Concrete")
        for k in range(7):
            t.box((side * (W2 - 0.25), 0.1, 0.6 + k), (0.36, 0.03, 0.5), "Steel")
    # roots and moss on the rock, a few pines on the head
    r2 = rnd(82)
    for k in range(6):
        x = r2.uniform(-9, 9)
        t.box((x, 8.8 + r2.uniform(-1.5, 2), r2.uniform(-1.5, 0.2)), (r2.uniform(1.0, 2.2), 0.3, r2.uniform(0.8, 1.6)), "Moss")
    t.finish()


def tunnel_set(root):
    """One 3.2 m section of the tunnel lining (lengthwise along Z, centred on z = 0), repeated by the game: a timber set (two posts, a cap beam, corner braces), concrete
    drainage gutters either side, a caged wall lamp each side and a ceiling lamp. Fits the 6.8 x 4.4 m interior."""
    t = TM("Body", root, holder=True)
    W2 = OW / 2
    for side in (-1, 1):
        t.box((side * (W2 - 0.14), 2.1, 0), (0.28, 4.0, 0.3), "Timber")
        t.bar((side * (W2 - 0.2), OH - 1.2, 0), (side * (W2 - 1.4), OH - 0.15, 0), 0.22, 0.3, "Timber", up=(0, 0, 1))
        t.box((side * (W2 - 0.55), 0.06, 0), (0.5, 0.12, 3.0), "Concrete")                          # the gutter
        t.box((side * (W2 - 0.55), 0.13, 0), (0.36, 0.03, 2.8), "Steel")
        t.box((side * (W2 - 0.05), 2.0, 1.0), (0.1, 0.24, 0.5), "Lamp")
        t.box((side * (W2 - 0.1), 2.0, 1.0), (0.04, 0.34, 0.6), "Steel")
    t.box((0, OH - 0.1, 0), (OW - 0.6, 0.26, 0.34), "Timber")
    t.box((0, OH - 0.3, 1.0), (1.4, 0.08, 0.3), "Lamp")
    t.box((0, OH - 0.22, 1.0), (1.5, 0.06, 0.34), "Steel")
    t.finish()


# ------------------------------------------------------------------------------------------------------------------------------ wildlife
def deer(root):
    """A stylised deer, 1.5 m long, 1.2 m at the shoulder, facing -Z. Static Body (torso, rump, belly), and holders at their hinges: Head (pivot at the base of the neck,
    pitches down to graze, turns), EarL/EarR, Tail, LegFL/LegFR/LegBL/LegBR (pivot at shoulder / hip, swing about X), Antlers (on the head)."""
    t = TM("Body", root, holder=True)
    t.hexa([(-0.24, 0.78, 0.45), (0.24, 0.78, 0.45), (0.22, 0.78, -0.45), (-0.22, 0.78, -0.45), (-0.2, 1.1, 0.5), (0.2, 1.1, 0.5), (0.2, 1.08, -0.42), (-0.2, 1.08, -0.42)], "Fur")
    t.hexa([(-0.2, 0.78, 0.45), (0.2, 0.78, 0.45), (0.2, 0.78, 0.7), (-0.2, 0.78, 0.7), (-0.17, 1.06, 0.45), (0.17, 1.06, 0.45), (0.15, 1.0, 0.72), (-0.15, 1.0, 0.72)], "Fur")         # rump
    t.box((0, 0.76, 0.05), (0.38, 0.1, 0.9), "FurLight")                                              # pale belly line
    t.box((0, 0.99, 0.74), (0.14, 0.12, 0.04), "FurLight")                                            # the white rump patch
    t.bar((0, 1.0, -0.4), (0, 1.28, -0.62), 0.3, 0.26, "Fur", up=(0, 1, 0))                          # the neck base (the neck itself is part of the Head)
    t.finish()
    h = TM("Head", root, loc=(0, 1.2, -0.55), holder=True)
    h.bar((0, 1.2, -0.55), (0, 1.62, -0.78), 0.26, 0.2, "Fur", up=(0, 1, 0))                          # neck
    h.hexa([(-0.1, 1.52, -0.8), (0.1, 1.52, -0.8), (0.1, 1.52, -1.0), (-0.1, 1.52, -1.0), (-0.09, 1.72, -0.8), (0.09, 1.72, -0.8), (0.08, 1.66, -1.0), (-0.08, 1.66, -1.0)], "Fur")      # skull
    h.hexa([(-0.07, 1.54, -1.0), (0.07, 1.54, -1.0), (0.06, 1.54, -1.22), (-0.06, 1.54, -1.22), (-0.07, 1.66, -1.0), (0.07, 1.66, -1.0), (0.05, 1.62, -1.22), (-0.05, 1.62, -1.22)], "FurLight")  # muzzle
    h.box((0, 1.62, -1.22), (0.08, 0.06, 0.03), "Dark")                                                # nose
    for s in (-1, 1):
        h.box((s * 0.1, 1.67, -0.95), (0.03, 0.04, 0.04), "Dark")                                     # eyes
    h.finish()
    an = TM("Antlers", root, loc=(0, 1.72, -0.82), holder=True)
    for s in (-1, 1):
        an.bar((s * 0.07, 1.7, -0.82), (s * 0.2, 2.0, -0.86), 0.04, 0.04, "Antler", up=(0, 0, 1))
        an.bar((s * 0.2, 2.0, -0.86), (s * 0.3, 2.28, -0.95), 0.035, 0.035, "Antler", up=(0, 0, 1))
        an.bar((s * 0.15, 1.86, -0.84), (s * 0.28, 1.98, -1.02), 0.03, 0.03, "Antler", up=(0, 0, 1))
        an.bar((s * 0.24, 2.1, -0.9), (s * 0.36, 2.2, -0.78), 0.03, 0.03, "Antler", up=(0, 0, 1))
    an.finish()
    for s, nm in ((-1, "EarL"), (1, "EarR")):
        e = TM(nm, root, loc=(s * 0.1, 1.7, -0.82), holder=True)
        e.hexa([(s * 0.1 - 0.02, 1.7, -0.82), (s * 0.1 + 0.02, 1.7, -0.82), (s * 0.1 + 0.02, 1.7, -0.78), (s * 0.1 - 0.02, 1.7, -0.78),
                (s * 0.2 - 0.03, 1.88, -0.82), (s * 0.2 + 0.03, 1.88, -0.82), (s * 0.2 + 0.03, 1.88, -0.78), (s * 0.2 - 0.03, 1.88, -0.78)], "Fur")
        e.box((s * 0.15, 1.8, -0.8), (0.03, 0.12, 0.02), "Pink")
        e.finish()
    tl = TM("Tail", root, loc=(0, 1.06, 0.72), holder=True)
    tl.box((0, 1.02, 0.78), (0.1, 0.16, 0.08), "FurLight")
    tl.finish()
    for (nm, x, z) in (("LegFL", -0.15, -0.38), ("LegFR", 0.15, -0.38), ("LegBL", -0.14, 0.55), ("LegBR", 0.14, 0.55)):
        lg = TM(nm, root, loc=(x, 0.8, z), holder=True)
        top = 0.22 if z > 0 else 0.16
        lg.bar((x, 0.8, z), (x, 0.42, z + (0.06 if z > 0 else 0.0)), top, top, "Fur", up=(0, 0, 1))        # upper leg
        lg.bar((x, 0.42, z + (0.06 if z > 0 else 0.0)), (x, 0.06, z), 0.07, 0.07, "Fur", up=(0, 0, 1))       # lower leg
        lg.box((x, 0.03, z), (0.09, 0.06, 0.12), "Dark")                                                  # hoof
        lg.finish()


def rabbit(root):
    """A stylised rabbit, 0.4 m long, facing -Z: a round body, a head with long ears (EarL/EarR holders), a white tail, and holders for hopping (Head, LegF, LegB, Tail)."""
    t = TM("Body", root, holder=True)
    t.cyl((0, 0.2, 0.02), 0.16, 0.15, 0.3, "RabbitFur", seg=7)
    t.cyl((0, 0.22, 0.14), 0.15, 0.1, 0.18, "RabbitFur", seg=7)
    t.box((0, 0.1, -0.02), (0.18, 0.07, 0.3), "RabbitWhite")
    t.finish()
    h = TM("Head", root, loc=(0, 0.28, -0.12), holder=True)
    h.cyl((0, 0.32, -0.19), 0.1, 0.085, 0.16, "RabbitFur", seg=7)
    h.hexa([(-0.05, 0.3, -0.25), (0.05, 0.3, -0.25), (0.045, 0.3, -0.31), (-0.045, 0.3, -0.31), (-0.04, 0.36, -0.25), (0.04, 0.36, -0.25), (0.035, 0.34, -0.31), (-0.035, 0.34, -0.31)], "RabbitWhite")
    h.box((0, 0.345, -0.31), (0.03, 0.025, 0.02), "Pink")
    for s in (-1, 1):
        h.box((s * 0.07, 0.355, -0.24), (0.02, 0.025, 0.025), "Dark")
    h.finish()
    for s, nm in ((-1, "EarL"), (1, "EarR")):
        e = TM(nm, root, loc=(s * 0.04, 0.38, -0.15), holder=True)
        e.bar((s * 0.04, 0.38, -0.15), (s * 0.07, 0.62, -0.12), 0.05, 0.028, "RabbitFur", up=(0, 0, 1))
        e.bar((s * 0.04, 0.4, -0.15), (s * 0.065, 0.6, -0.125), 0.025, 0.014, "Pink", up=(0, 0, 1))
        e.finish()
    tl = TM("Tail", root, loc=(0, 0.2, 0.2), holder=True)
    tl.cyl((0, 0.2, 0.22), 0.045, 0.045, 0.06, "RabbitWhite", seg=6)
    tl.finish()
    lf = TM("LegF", root, loc=(0, 0.1, -0.1), holder=True)
    for s in (-1, 1):
        lf.box((s * 0.06, 0.05, -0.12), (0.04, 0.1, 0.05), "RabbitFur")
    lf.finish()
    lb = TM("LegB", root, loc=(0, 0.1, 0.1), holder=True)
    for s in (-1, 1):
        lb.box((s * 0.1, 0.07, 0.1), (0.06, 0.12, 0.2), "RabbitFur")
        lb.box((s * 0.1, 0.02, 0.0), (0.05, 0.03, 0.14), "RabbitFur")
    lb.finish()


MODELS = {
    "pine_tall": pine_tall, "pine_young": pine_young, "birch": birch, "log": log, "stump": stump, "bush": bush, "fern": fern, "grass": grass, "flowers": flowers,
    "mossy_stone": mossy_stone, "peak_a": peak_a, "peak_b": peak_b, "ridge": ridge, "foothill": foothill, "cliff": cliff,
    "tunnel_portal": tunnel_portal, "tunnel_set": tunnel_set, "deer": deer, "rabbit": rabbit,
}


def build(name, fn):
    Q.reset()
    root = empty("QD_" + name, size=0.2)
    fn(root)
    os.makedirs(SRC, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, name + ".blend"))
    path = os.path.join(OUT, "WLD_QD_%s.glb" % name)
    Q.export_glb(path)
    faces = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
    print("WORLD", name, os.path.getsize(path), "bytes", faces, "faces")


if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    os.makedirs(OUT, exist_ok=True)
    for name, fn in MODELS.items():
        if not only or name in only:
            build(name, fn)
    print("BUILD_OK")
