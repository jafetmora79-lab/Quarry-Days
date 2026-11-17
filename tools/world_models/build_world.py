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
sys.path.insert(0, HERE)
import ground_models

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
    "PickGreen": (None, (0.30, 0.42, 0.31), 0.85, 0.0, {}),
    "PickDark":  (None, (0.19, 0.28, 0.21), 0.9, 0.0, {}),
    "PickWood":  (None, (0.45, 0.32, 0.20), 1.0, 0.0, {}),
    "PickSeat":  (None, (0.44, 0.30, 0.19), 1.0, 0.0, {}),
    "PickDash":  (None, (0.20, 0.18, 0.16), 1.0, 0.0, {}),
    "PickTrim":  (None, (0.66, 0.66, 0.62), 0.5, 0.4, {}),
    "PickTyre":  (None, (0.07, 0.07, 0.07), 1.0, 0.0, {}),
    "PickGlass": (None, (0.62, 0.78, 0.82), 0.2, 0.0, {}),
    "PickRed":   (None, (0.75, 0.12, 0.10), 0.6, 0.0, {"emit": 0.6}),
    "PickRust":  (None, (0.45, 0.24, 0.12), 1.0, 0.0, {}),
    "DinoSkin":  (None, (0.41, 0.36, 0.26), 0.95, 0.0, {}),
    "DinoSkinDk": (None, (0.30, 0.26, 0.19), 0.95, 0.0, {}),
    "DinoPlate": (None, (0.25, 0.22, 0.17), 0.85, 0.0, {}),
    "DinoPlateLt": (None, (0.43, 0.37, 0.27), 0.85, 0.0, {}),
    "DinoBelly": (None, (0.66, 0.60, 0.45), 0.95, 0.0, {}),
    "DinoBone":  (None, (0.88, 0.84, 0.70), 0.9, 0.0, {}),
    "DinoEye":   (None, (0.05, 0.04, 0.04), 0.4, 0.0, {}),
    "DinoWhite": (None, (0.96, 0.95, 0.90), 0.6, 0.0, {}),
    "DinoBlush": (None, (0.84, 0.52, 0.42), 1.0, 0.0, {}),
    "DinoMoss":  (None, (0.34, 0.42, 0.22), 1.0, 0.0, {}),
    "DinoHide2": (None, (0.52, 0.45, 0.33), 0.97, 0.0, {}),
    "DinoHide3": (None, (0.33, 0.30, 0.22), 0.97, 0.0, {}),
    "DinoClaw":  (None, (0.20, 0.17, 0.13), 0.8, 0.0, {}),
    "DinoIris":  (None, (0.74, 0.50, 0.14), 0.4, 0.0, {}),
    "DinoHorn":  (None, (0.64, 0.57, 0.42), 0.7, 0.0, {}),
    "DinoHornDk": (None, (0.42, 0.36, 0.26), 0.75, 0.0, {}),
    "EggShell":  (None, (0.86, 0.82, 0.66), 0.9, 0.0, {}),
    "EggSpot":   (None, (0.52, 0.44, 0.30), 1.0, 0.0, {}),
    "EggCrust":  (None, (0.62, 0.58, 0.50), 1.0, 0.0, {}),
    "EggInner":  (None, (0.92, 0.70, 0.40), 0.8, 0.0, {}),
    "Amber":     (None, (1.0, 0.72, 0.30), 0.5, 0.0, {"emit": 1.6}),
    "Straw":     (None, (0.82, 0.68, 0.34), 1.0, 0.0, {}),
    "StrawDk":   (None, (0.62, 0.48, 0.24), 1.0, 0.0, {}),
    "Wool":      (None, (0.88, 0.84, 0.76), 1.0, 0.0, {}),
    "Brass":     (None, (0.78, 0.60, 0.24), 0.45, 0.6, {}),
    "IncWood":   (None, (0.50, 0.34, 0.20), 1.0, 0.0, {}),
    "IncWoodDk": (None, (0.34, 0.22, 0.13), 1.0, 0.0, {}),
    "IncTin":    (None, (0.62, 0.64, 0.62), 0.5, 0.4, {}),
    "IncRed":    (None, (0.78, 0.18, 0.14), 0.6, 0.0, {}),
    "IncWater":  (None, (0.40, 0.62, 0.78), 0.4, 0.0, {}),
    "FossilBone": (None, (0.84, 0.78, 0.62), 1.0, 0.0, {}),
    "FossilEgg": (None, (0.66, 0.62, 0.54), 1.0, 0.0, {}),
    "Slab":      (None, (0.46, 0.42, 0.36), 1.0, 0.0, {}),
    "SlabLt":    (None, (0.60, 0.55, 0.46), 1.0, 0.0, {}),
    "HopSteel":  (None, (0.31, 0.39, 0.34), 0.75, 0.3, {}),
    "HopSteelDk": (None, (0.20, 0.26, 0.23), 0.8, 0.3, {}),
    "HopRust":   (None, (0.49, 0.27, 0.13), 1.0, 0.1, {}),
    "HopRustDk": (None, (0.33, 0.18, 0.09), 1.0, 0.1, {}),
    "HopYellow": (None, (0.90, 0.69, 0.13), 0.8, 0.0, {}),
    "HopIron":   (None, (0.15, 0.15, 0.16), 0.7, 0.5, {}),
    "HopBrass":  (None, (0.80, 0.61, 0.24), 0.45, 0.6, {}),
    "HopConcrete": (None, (0.50, 0.50, 0.47), 1.0, 0.0, {}),
    "HopStain":  (None, (0.22, 0.2, 0.17), 1.0, 0.0, {}),
    "HopScreen": (None, (0.10, 0.18, 0.12), 0.3, 0.0, {}),
    "HopLamp":   (None, (0.9, 0.2, 0.12), 0.4, 0.0, {"emit": 1.2}),
    "HopWood":   (None, (0.42, 0.29, 0.17), 1.0, 0.0, {}),
    "HopRock":   (None, (0.70, 0.68, 0.62), 1.0, 0.0, {}),
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


def pine_far(root):
    """The distant pine (about 40 faces): the same silhouette as pine_tall (a thin trunk and four cones), used beyond ~90 m where the forest is a dark mass."""
    t = TM("Body", root, holder=True)
    t.cyl((0, 3.0, 0), 0.28, 0.1, 6.0, "Bark", seg=4)
    for k, (y, rad, h, m) in enumerate([(1.4, 1.9, 3.0, "Pine"), (3.6, 1.45, 2.8, "PineLight"), (5.6, 1.0, 2.4, "Pine"), (7.2, 0.5, 1.8, "PineLight")]):
        t.cyl((0, y + h * 0.45, 0), rad, 0.05, h, m, seg=5, phase=k * 0.4)
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


def emit_field(t, groups, below):
    """Adds height-field quads with EVERY normal pointing away from `below` (a point far under the ground), so every face is front-facing from above and from the sides:
    a one-sided surface whose faces were oriented by guesswork showed up as holes and see-through peaks in the game."""
    for m, quads in groups.items():
        mesher = t._mesher(m)
        for q in quads:
            uvs = [(p[0] * 0.1, p[2] * 0.1) for p in q]
            mesher.raw_quad([t._p(p) for p in q], uvs, m, outward=t._p(below))


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
    emit_field(t, groups, (0.0, -60.0, 0.0))
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


def tunnel_mountain(root):
    """The mountain the west tunnel runs through, 100 x 80 m, centred where the tunnel's middle is. Local +X is EAST (the yard side): a sheer rock face stands at x = +43 (the
    portal is set into it), the ridge rises behind it and falls away to a second face at x = -42.5 (the tunnel's far exit), the flanks slope down to the ground at z = +-40. The
    surface is kept at least 9.5 m over the tunnel's line, so the tunnel is inside solid rock the whole way. One continuous, correctly oriented surface."""
    t = TM("Body", root, holder=True)
    r = rnd(91)
    W, D = 100.0, 80.0
    waves = [(r.uniform(0, math.tau), r.uniform(0.07, 0.2), r.uniform(0, 6.3), r.uniform(0.5, 1.0)) for _ in range(6)]
    def height(x, z):
        u = 43.0 - x
        if u <= 0.0:
            return 0.0
        face = 14.0 * min(1.0, (u / 3.2) ** 0.6)
        base = (face + 17.0 * smooth(3.0, 36.0, u) * (1.0 - 0.55 * smooth(55.0, 82.0, u))) * (1.0 - smooth(85.55, 85.65, u))
        lat = 1.0 - smooth(14.0, 40.0, abs(z))
        rg = 0.0
        for (ang, fr, ph, am) in waves:
            q = x * math.cos(ang) + z * math.sin(ang)
            rg += am * (1.0 - abs(math.sin(q * fr + ph)))
        rg /= len(waves)
        calm = smooth(7.0, 22.0, u) * (1.0 - smooth(70.0, 84.0, u))
        h = base * lat * (1.0 + 0.3 * (rg - 0.5) * 2.0 * calm)
        if 0.5 < u < 85.6:
            h = max(h, 9.5 * (1.0 - smooth(7.0, 17.0, abs(z))) * smooth(0.0, 1.2, u))
        return max(0.0, h)
    nx, nz = 80, 32
    pts = {}
    for i in range(nx + 1):
        for j in range(nz + 1):
            x = -W / 2 + W * i / nx
            z = -D / 2 + D * j / nz
            jit = 1.0 if (abs(z) > 9.0 and 0 < i < nx and 0 < j < nz) else 0.0
            x += r.uniform(-0.3, 0.3) * (W / nx) * jit
            z += r.uniform(-0.3, 0.3) * (D / nz) * jit
            pts[(i, j)] = (x, height(x, z), z)
    bands = ["RockD", "RockB", "RockA", "RockC", "RockB", "RockA"]
    groups = {}
    for i in range(nx):
        for j in range(nz):
            q = [pts[(i, j)], pts[(i, j + 1)], pts[(i + 1, j + 1)], pts[(i + 1, j)]]
            ym = sum(p[1] for p in q) / 4
            if max(p[1] for p in q) < 0.05:
                continue
            cu = 43.0 - sum(p[0] for p in q) / 4
            cz = sum(p[2] for p in q) / 4
            if abs(cz) < 3.9 and (-1.0 < cu < 1.4 or 85.3 < cu < 87.2):
                # the tunnel mouths are open, and the portal's stone head closes them up to 9.6 m: the rock above that height is kept (the face quads are cut there)
                cut = []
                for a, b in ((q[0], q[3]), (q[1], q[2])):
                    lo, hi = (a, b) if a[1] < b[1] else (b, a)
                    if hi[1] <= 9.6:
                        cut = []
                        break
                    k = max(0.0, (9.6 - lo[1]) / (hi[1] - lo[1]))
                    cut.append((lo, hi, tuple(lo[n] + (hi[n] - lo[n]) * k for n in range(3))))
                if len(cut) == 2:
                    nq = list(q)
                    for (lo, hi, nlo) in cut:
                        nq[nq.index(lo)] = nlo
                    groups.setdefault("RockB", []).append(nq)
                continue
            slope = (max(p[1] for p in q) - min(p[1] for p in q)) / (W / nx)
            band = int(ym / 32.0 * 7.0)
            if slope > 1.6:
                m = "RockD" if band % 2 == 0 else "RockB"
            elif ym < 7.0 and slope < 0.5:
                m = "Moss"
            else:
                m = bands[band % len(bands)]
            groups.setdefault(m, []).append(q)
    emit_field(t, groups, (0.0, -80.0, 0.0))
    for k in range(70):                                                                               # pines on the gentle lower flanks
        x, z = r.uniform(-45.0, 40.0), r.uniform(-38.0, 38.0)
        if abs(z) < 12.0:
            continue
        y = height(x, z)
        slope = abs(height(x + 0.8, z) - y) + abs(height(x, z + 0.8) - y)
        if y < 0.4 or y > 15.0 or slope > 1.0:
            continue
        hh = r.uniform(4.0, 7.5)
        t.cyl((x, y + 0.5, z), 0.14, 0.1, 1.0, "Bark", seg=4)
        t.cyl((x, y + 0.9 + hh * 0.5, z), r.uniform(1.2, 1.9), 0.06, hh, "Pine" if k % 2 else "PineLight", seg=5)
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
    """The entrance set into the mountain's face (the face plane is z = 0; the portal faces +Z, the tunnel runs toward -Z). A stone surround (two piers, an arch lintel with a
    keystone, a cap), the timber portal frame with knee braces, a hazard-striped steel lintel, two warning signs, caged wall lamps, a drainage ditch with grates.
    Clear opening 6.8 x 4.4 m. It is a frame only: the rock around it is the mountain itself."""
    t = TM("Body", root, holder=True)
    W2 = OW / 2
    for side in (-1, 1):                                                                              # stone piers, a little proud of the face
        t.box((side * (W2 + 0.75), (OH + 1.0) / 2, 0.15), (1.5, OH + 1.0, 1.7), "RockD")
        for k in range(5):
            t.box((side * (W2 + 0.75), 0.4 + k * 0.95, 1.02), (1.56, 0.12, 0.08), "RockB")        # mortar courses
        t.box((side * (W2 + 0.2), 0.12, 1.0), (0.5, 0.24, 1.9), "Concrete")
    t.box((0, OH + 0.75, 0.15), (OW + 4.4, 1.5, 1.7), "RockB")                                       # the arch lintel (wider than the cut in the face: it overlaps the rock)
    t.box((0, OH + 0.4, 1.02), (1.1, 1.1, 0.1), "RockB")                                             # the keystone
    t.box((0, (OH + 1.5 + 9.9) / 2, 0.15), (OW + 4.4, 9.9 - OH - 1.5, 1.7), "RockB")                # the stone head up to 9.9 m, closing the gap above the opening; the face carries on above it
    for side in (-1, 1):                                                                              # timber frame
        t.box((side * (W2 + 0.3), OH / 2, 1.0), (0.55, OH, 0.55), "Timber")
        t.bar((side * (W2 + 0.3), OH - 1.4, 1.0), (side * (W2 - 1.1), OH, 1.0), 0.2, 0.28, "Timber", up=(0, 0, 1))
    t.box((0, OH + 0.25, 1.0), (OW + 1.2, 0.5, 0.6), "Timber")
    t.box((0, OH + 0.62, 1.1), (OW + 1.4, 0.18, 0.7), "Steel")
    for k in range(9):
        t.box((-OW / 2 - 0.4 + k * (OW + 0.8) / 8, OH + 0.62, 1.46), ((OW + 0.8) / 16, 0.18, 0.03), "Hazard" if k % 2 == 0 else "Dark")
    for side in (-1, 1):                                                                              # warning signs on posts, caged lamps on the piers
        t.box((side * (W2 + 2.2), 1.4, 1.8), (0.07, 2.8, 0.07), "Steel")
        t.box((side * (W2 + 2.2), 2.5, 1.86), (0.9, 0.9, 0.04), "Paint")
        t.box((side * (W2 + 2.2), 2.5, 1.89), (0.62, 0.62, 0.02), "Dark")
        t.box((side * (W2 + 2.2), 2.62, 1.91), (0.08, 0.34, 0.02), "Paint")
        t.box((side * (W2 + 2.2), 2.3, 1.91), (0.08, 0.08, 0.02), "Paint")
        t.box((side * (W2 + 0.55), 3.3, 1.25), (0.4, 0.3, 0.3), "Lamp")
        for dz in (-0.18, 0.18):
            t.box((side * (W2 + 0.55), 3.3, 1.25 + dz), (0.46, 0.36, 0.03), "Steel")
    for side in (-1, 1):                                                                              # drainage ditch with grates along the road edges
        t.box((side * (W2 - 0.25), 0.04, 3.5), (0.5, 0.08, 7.0), "Concrete")
        for k in range(7):
            t.box((side * (W2 - 0.25), 0.1, 0.6 + k), (0.36, 0.03, 0.5), "Steel")
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


def pickup(root):
    """Grandpa Walt's old pickup, 5.4 m long, faded green, facing -Z (the driver sits on the left, -X). Holders: Body (paint, bed, bumpers, lamps), Interior (dash, seat, door cards,
    pedals), Glass (windscreen, side and rear windows: one transparent material), SteeringWheel (pivot at the hub, tilted back 70 degrees) and WheelFL/FR/BL/BR (pivot at the
    wheel centre, turn about X). Everything is chunky boxes and tapered boxes, flat shaded like the rest of the game."""
    t = TM("Body", root, holder=True)
    G, D, W, TR, Y = "PickGreen", "PickDark", "PickWood", "PickTrim", "PickDash"
    t.box((0, 0.58, 0.1), (1.8, 0.28, 4.9), Y)                                                        # chassis
    t.box((0, 0.98, -1.55), (1.84, 0.45, 1.55), G, taper=(0.93, 0.97))                               # hood
    t.box((0, 1.22, -1.55), (1.3, 0.05, 1.2), D)                                                     # the hood's raised centre
    t.box((0, 0.97, -2.35), (1.44, 0.46, 0.08), D)                                                   # grille shell
    for k in range(6):
        t.box((-0.5 + k * 0.2, 0.97, -2.4), (0.05, 0.38, 0.03), TR)                                  # grille bars
    for sx in (-1, 1):
        t.box((sx * 0.7, 1.02, -2.37), (0.34, 0.3, 0.1), TR)                                         # headlamp rims
        t.box((sx * 0.7, 1.02, -2.43), (0.24, 0.2, 0.05), "Lamp")                                    # headlamps
        t.box((sx * 0.96, 1.0, -1.55), (0.2, 0.14, 1.3), G, taper=(0.8, 1.0))                        # front wings
        t.box((sx * 1.0, 0.9, -1.55), (0.1, 0.4, 1.3), G)
        t.box((sx * 1.0, 0.9, 1.75), (0.1, 0.4, 1.3), G)                                             # rear arches
        t.box((sx * 0.96, 0.62, 0.0), (0.12, 0.06, 4.1), TR)                                         # running boards
        t.box((sx * 0.78, 0.5, 2.98), (0.12, 0.16, 0.06), "PickRed")                                 # tail lamps
        t.box((sx * 1.04, 1.52, -0.82), (0.05, 0.22, 0.14), Y)                                       # wing mirrors
        t.box((sx * 0.97, 1.44, -0.8), (0.1, 0.03, 0.03), Y)
    t.box((0, 0.55, -2.44), (1.98, 0.16, 0.16), TR)                                                  # bumpers
    t.box((0, 0.6, 2.97), (1.98, 0.16, 0.16), TR)
    t.box((0, 0.72, 2.99), (0.3, 0.12, 0.02), "PickTrim")                                            # number plate
    t.box((0.62, 0.42, 2.2), (0.1, 0.1, 0.5), Y)                                                     # exhaust
    # the cab shell: floor, door skins, pillars, roof, rear wall
    t.box((0, 0.66, -0.08), (1.86, 0.06, 1.42), Y)
    for sx in (-1, 1):
        t.box((sx * 0.93, 0.95, -0.08), (0.07, 0.58, 1.42), G)
        t.box((sx * 0.955, 1.22, -0.08), (0.03, 0.04, 1.42), TR)                                     # the window sills
        t.box((sx * 0.955, 0.95, 0.22), (0.02, 0.5, 0.02), D)                                        # door seams
        t.box((sx * 0.955, 0.95, -0.7), (0.02, 0.5, 0.02), D)
        t.box((sx * 0.97, 1.06, 0.12), (0.04, 0.04, 0.14), TR)                                       # outer door handles
        t.box((sx * 0.93, 1.67, -0.74), (0.1, 0.94, 0.1), G)                                         # A pillars
        t.box((sx * 0.93, 1.67, 0.6), (0.1, 0.94, 0.1), G)                                           # rear pillars
        t.box((sx * 0.93, 2.16, -0.08), (0.1, 0.06, 1.42), G)                                        # roof rails
    t.box((0, 2.17, -0.08), (1.96, 0.07, 1.5), G, taper=(0.95, 0.96))                               # roof
    t.box((0, 1.3, 0.6), (1.86, 0.3, 0.06), G)
    t.box((0, 2.1, 0.6), (1.86, 0.1, 0.06), G)
    t.box((0, 0.95, -0.78), (1.86, 0.55, 0.06), D)                                                   # firewall
    # the bed: floor, planked wooden sides, tailgate, a toolbox, a crate and a coil of rope
    t.box((0, 0.8, 1.78), (1.82, 0.12, 2.3), Y)
    for sx in (-1, 1):
        for k in range(3):
            t.box((sx * 0.9, 0.94 + k * 0.16, 1.78), (0.1, 0.14, 2.3), W)                            # side planks
        t.box((sx * 0.9, 1.34, 1.78), (0.14, 0.05, 2.34), TR)
    for k in range(3):
        t.box((0, 0.94 + k * 0.16, 0.68), (1.82, 0.14, 0.1), W)
        t.box((0, 0.94 + k * 0.16, 2.92), (1.82, 0.14, 0.1), W)
    t.box((0, 1.34, 2.97), (1.84, 0.05, 0.06), TR)
    t.box((-0.35, 1.02, 1.2), (0.5, 0.34, 0.4), "PickRust")                                          # toolbox
    t.box((-0.35, 1.2, 1.2), (0.52, 0.04, 0.42), TR)
    t.box((0.4, 0.95, 2.3), (0.45, 0.2, 0.45), "PickWood")
    t.cyl((0.45, 0.93, 1.3), 0.2, 0.2, 0.16, "PickSeat", seg=10)                                     # the coil of rope
    t.finish()

    i = TM("Interior", root, holder=True)
    S = "PickSeat"
    i.box((0, 0.95, -0.55), (1.8, 0.5, 0.42), Y)                                                     # dashboard
    i.box((0, 1.21, -0.62), (1.7, 0.03, 0.3), Y)
    i.box((-0.45, 1.12, -0.34), (0.5, 0.14, 0.04), "Dark")                                           # instrument binnacle
    for k in range(3):
        i.box((-0.58 + k * 0.13, 1.12, -0.315), (0.08, 0.08, 0.01), "Lamp")
    i.box((0.45, 1.0, -0.33), (0.6, 0.2, 0.04), Y)                                                   # glovebox
    i.box((0.45, 0.98, -0.305), (0.1, 0.03, 0.02), TR)
    i.box((0.0, 1.05, -0.33), (0.28, 0.16, 0.04), "Dark")                                            # radio
    i.box((0, 0.82, 0.1), (1.78, 0.22, 0.58), S)                                                     # bench seat
    i.box((0, 1.26, 0.42), (1.78, 0.66, 0.16), S)
    i.box((0, 0.98, 0.08), (0.04, 0.12, 0.5), "PickRust")
    i.box((0, 2.12, -0.08), (1.82, 0.03, 1.44), "PickSeat", taper=(1.0, 1.0))                        # headliner
    i.box((0, 1.98, -0.72), (0.16, 0.05, 0.02), "Dark")                                              # mirror
    i.box((0, 2.05, -0.72), (0.02, 0.1, 0.02), "Dark")
    i.box((0.1, 1.88, -0.72), (0.03, 0.07, 0.005), "Moss")                                           # the air freshener
    for sx in (-1, 1):
        i.box((sx * 0.45, 2.07, -0.62), (0.7, 0.03, 0.26), "Dark")                                   # sun visors
        i.box((sx * 0.88, 0.95, -0.08), (0.05, 0.5, 1.36), "PickRust")                               # door cards
        i.box((sx * 0.86, 1.12, -0.08), (0.08, 0.06, 0.5), "PickWood")                               # armrests
        i.box((sx * 0.86, 1.06, 0.2), (0.06, 0.05, 0.16), TR)
    i.box((0, 0.7, 0.0), (0.18, 0.1, 0.5), "Dark")
    i.bar((0.0, 0.8, -0.05), (0.0, 1.2, -0.17), 0.04, 0.04, "Dark", up=(1, 0, 0))                   # gear stick
    for sx, pz in ((-0.45, -0.1), (-0.3, -0.1), (-0.58, -0.1)):
        i.box((sx, 0.72, -0.42), (0.08, 0.04, 0.12), "Dark")                                         # pedals
    i.finish()

    g = TM("Glass", root, holder=True)
    g.box((0, 1.68, -0.8), (1.76, 0.92, 0.012), "PickGlass")                                         # windscreen
    for sx in (-1, 1):
        g.box((sx * 0.93, 1.67, -0.08), (0.012, 0.9, 1.32), "PickGlass")
    g.box((0, 1.78, 0.6), (1.5, 0.5, 0.012), "PickGlass")
    g.finish()

    sw = TM("SteeringWheel", root, loc=(-0.45, 1.2, -0.2), holder=True)                              # the wheel: a ring of eight bars, a hub and a column
    cx, cy, cz = -0.45, 1.2, -0.2
    ca, sa = math.cos(math.radians(70)), math.sin(math.radians(70))
    def wp(u, v, d=0.0):
        # u along the wheel's right, v along its tilted "up" in the plane, d along its normal
        return (cx + u, cy + v * (-sa) + d * ca, cz + v * ca + d * sa)
    for k in range(10):
        a0 = k * math.tau / 10
        a1 = (k + 1) * math.tau / 10
        sw.bar(wp(math.cos(a0) * 0.17, math.sin(a0) * 0.17), wp(math.cos(a1) * 0.17, math.sin(a1) * 0.17), 0.035, 0.03, "Dark", up=(0, 1, 0))
    for a in (90, 210, 330):
        sw.bar(wp(0, 0), wp(math.cos(math.radians(a)) * 0.17, math.sin(math.radians(a)) * 0.17), 0.025, 0.02, "Dark", up=(0, 1, 0))
    sw.box((cx, cy, cz), (0.1, 0.04, 0.1), TR)
    sw.finish()
    col = TM("Column", root, holder=True)
    col.bar((-0.45, 0.95, -0.55), (-0.45, 1.2, -0.2), 0.05, 0.05, "Dark", up=(1, 0, 0))
    col.finish()

    for (nm, x, z) in (("WheelFL", -0.9, -1.55), ("WheelFR", 0.9, -1.55), ("WheelBL", -0.9, 1.75), ("WheelBR", 0.9, 1.75)):
        w = TM(nm, root, loc=(x, 0.42, z), holder=True)
        w.cyl((x, 0.42, z), 0.42, 0.42, 0.28, "PickTyre", seg=14, axis='x')
        w.cyl((x, 0.42, z), 0.22, 0.22, 0.3, TR, seg=10, axis='x')
        w.cyl((x, 0.42, z), 0.1, 0.1, 0.34, D, seg=8, axis='x')
        for k in range(5):
            a = k * math.tau / 5
            w.box((x + (0.16 if x > 0 else -0.16), 0.42 + math.cos(a) * 0.14, z + math.sin(a) * 0.14), (0.04, 0.04, 0.04), TR)    # lug nuts
        w.finish()



# ------------------------------------------------------------------------------------------------------------------------------ the dinosaur set
def _bump(t, c, r, h, mat, seg=5):
    """A little armour cone standing on the back at c (a pyramid-like frustum)."""
    t.cyl(c, r, r * 0.25, h, mat, seg=seg)


def _lerp(a, b, k):
    return a + (b - a) * k


def _sec(secs, z):
    """Interpolated (halfwidth, ytop, ybot) of a list of (z, hw, ytop, ybot) sections at z."""
    if z <= secs[0][0]:
        return secs[0][1:]
    for (z0, *a), (z1, *b) in zip(secs, secs[1:]):
        if z0 <= z <= z1:
            k = (z - z0) / (z1 - z0)
            return tuple(_lerp(x, y, k) for x, y in zip(a, b))
    return secs[-1][1:]


def _ring(z, hw, ytop, ybot, n=16, p=2.5, xc=0.0):
    """One superellipse cross-section ring (godot space) at z: half-width hw, top ytop, bottom ybot; angle runs from +X toward +Y like TM.cyl."""
    ym, hh = (ytop + ybot) / 2, (ytop - ybot) / 2
    out = []
    for i in range(n):
        a = math.tau * i / n
        c, s_ = math.cos(a), math.sin(a)
        out.append((xc + hw * math.copysign(abs(c) ** (2 / p), c), ym + hh * math.copysign(abs(s_) ** (2 / p), s_), z))
    return out


def loft(t, secs, mat, n=16, p=2.5, caps=True):
    """A smooth organic solid through cross-sections [(z, hw, ytop, ybot), ...] (z ascending)."""
    return t._skin([_ring(z, hw, yt, yb, n, p) for (z, hw, yt, yb) in secs], mat, caps)


def _top(secs, z, f, p=2.5):
    """Height of the loft's surface at z, lateral fraction f (-1..1 of the half width): (x, y)."""
    hw, yt, yb = _sec(secs, z)
    f = max(-0.999, min(0.999, f))
    ym, hh = (yt + yb) / 2, (yt - yb) / 2
    return f * hw, ym + hh * (1 - abs(f) ** p) ** (1 / p)


def _scute(t, x, y, z, w, ln, h, tilt_x, mat, keel=True):
    """An osteoderm: a keeled, slightly pointed scute sitting on the hide at (x, y, z), w wide, ln long, h tall, leaning outward by tilt_x (0..1 of its height)."""
    t.hexa([(x - w / 2, y - 0.01, z + ln / 2), (x + w / 2, y - 0.01, z + ln / 2), (x + w / 2, y - 0.01, z - ln / 2), (x - w / 2, y - 0.01, z - ln / 2),
            (x - w * 0.12 + tilt_x * h, y + h * 0.7, z + ln * 0.2), (x + w * 0.12 + tilt_x * h, y + h * 0.7, z + ln * 0.2), (x + w * 0.12 + tilt_x * h, y + h * 0.7, z - ln * 0.2),
            (x - w * 0.12 + tilt_x * h, y + h * 0.7, z - ln * 0.2)], mat)
    if keel:
        t.hexa([(x - w * 0.1, y + h * 0.55, z + ln * 0.25), (x + w * 0.1, y + h * 0.55, z + ln * 0.25), (x + w * 0.1, y + h * 0.55, z - ln * 0.35), (x - w * 0.1, y + h * 0.55, z - ln * 0.35),
                (x + tilt_x * h, y + h * 1.05, z + ln * 0.05), (x + tilt_x * h, y + h * 1.05, z + ln * 0.05), (x + tilt_x * h, y + h * 1.05, z - ln * 0.28), (x + tilt_x * h, y + h * 1.05, z - ln * 0.28)], "DinoPlateLt")


BODY = [(-0.96, 0.34, 0.90, 0.56), (-0.80, 0.56, 0.99, 0.42), (-0.55, 0.70, 1.04, 0.36), (-0.2, 0.78, 1.07, 0.34), (0.2, 0.79, 1.07, 0.34), (0.55, 0.73, 1.04, 0.36),
        (0.8, 0.60, 0.99, 0.43), (0.98, 0.38, 0.91, 0.55)]


def dino(root):
    """The companion, drawn as a real ANKYLOSAUR (an armoured, club-tailed dinosaur of the late Cretaceous) in the same hard-surface, weathered style as the machines: a low,
    very wide barrel body lofted from cross-sections, a flat dorsal shield of keeled scutes in transverse bands and longitudinal rows, a row of spikes along each flank, a broad
    triangular skull with a horny beak, brow and cheek osteoderms and two big squamosal horns, columnar legs with blunt hoof claws, and a stiffened tail ending in a heavy bone club.
    Facing -Z, ground at y = 0, about 1.9 m long without the tail (the game scales it by growth stage). Holders (flat, each pivoting where the game's animation expects it): Body,
    Plates (0,1.07,0), Neck (0,0.84,-0.9), Head (0,0.82,-1.24), EyeL/EyeR, HipFL/FR/BL/BR (hip), ShinFL.. (hip - 0.3), FootFL.. (shin - 0.28), Tail1 (0,0.8,0.85), Tail2 (+0.7), Tail3 (+0.7), Club (+0.68)."""
    S, SD, H2, H3, PL, PLL, BE, HN, HND, CL = "DinoSkin", "DinoSkinDk", "DinoHide2", "DinoHide3", "DinoPlate", "DinoPlateLt", "DinoBelly", "DinoHorn", "DinoHornDk", "DinoClaw"
    r = rnd(7)
    # ---------------------------------------------------------------- body: the barrel, the belly, hide folds and mottling
    t = TM("Body", root, holder=True)
    loft(t, BODY, S, n=18, p=2.4)
    t.box((0, 0.36, 0.0), (0.9, 0.05, 1.8), BE, taper=(0.85, 0.9))                                    # the pale belly
    for k in range(9):                                                                                # skin folds: dark creases across the flanks
        z = -0.78 + k * 0.2
        for sx in (-1, 1):
            hw, yt, yb = _sec(BODY, z)
            t.hexa([(sx * (hw - 0.02), yb + 0.1, z - 0.012), (sx * (hw + 0.012), yb + 0.14, z - 0.012), (sx * (hw + 0.012), yb + 0.14, z + 0.012), (sx * (hw - 0.02), yb + 0.1, z + 0.012),
                    (sx * (hw - 0.02), yt - 0.18, z - 0.012), (sx * (hw + 0.012), yt - 0.2, z - 0.012), (sx * (hw + 0.012), yt - 0.2, z + 0.012), (sx * (hw - 0.02), yt - 0.18, z + 0.012)], H3)
    for k in range(14):                                                                               # lighter mottled patches of hide on the flanks and shoulders
        z = -0.75 + r.uniform(0, 1.5)
        sx = -1 if k % 2 else 1
        hw, yt, yb = _sec(BODY, z)
        y = r.uniform(yb + 0.18, yt - 0.14)
        t.box((sx * (hw - 0.01), y, z), (0.03, r.uniform(0.07, 0.16), r.uniform(0.1, 0.24)), H2 if k % 3 else H3, taper=(1.0, 0.8))
    t.finish()

    # ---------------------------------------------------------------- the dorsal shield (Plates holder: the game flattens it on hatchlings)
    pl = TM("Plates", root, loc=(0, 1.07, 0), holder=True)
    for k, z in enumerate([-0.82 + 0.135 * i for i in range(14)]):                                    # longitudinal rows of keeled scutes
        for f, big in ((0.0, 1.0), (-0.42, 0.85), (0.42, 0.85), (-0.74, 0.7), (0.74, 0.7)):
            ff = f + (0.03 if (k % 2) else -0.03) * (1 if f else 0)
            x, y = _top(BODY, z, ff)
            _scute(pl, x, y, z, 0.17 * big, 0.12, 0.05 + 0.05 * big, 0.25 * ff, PL if (k + int(f * 10)) % 3 else PLL)
    for z in (-0.95, -0.82, -0.69):                                                                   # the nuchal bands: thick transverse plates over the shoulders
        for f in [i / 3.0 for i in range(-3, 4)]:
            x, y = _top(BODY, z, f * 0.92)
            _scute(pl, x, y, z, 0.2, 0.1, 0.065, 0.3 * f, PL, keel=False)
    for sx in (-1, 1):                                                                                # flank spikes: a row of big triangular horns along each side, biggest at the shoulder
        for k in range(8):
            z = -0.78 + k * 0.215
            hw, yt, yb = _sec(BODY, z)
            big = 1.55 - 0.095 * k
            y = (yt + yb) / 2 + 0.05
            pl.hexa([(sx * (hw - 0.02), y - 0.05 * big, z + 0.07), (sx * (hw - 0.02), y - 0.05 * big, z - 0.07), (sx * (hw - 0.02), y + 0.05 * big, z - 0.07), (sx * (hw - 0.02), y + 0.05 * big, z + 0.07),
                     (sx * (hw + 0.25 * big), y + 0.01, z + 0.0), (sx * (hw + 0.25 * big), y + 0.01, z + 0.0), (sx * (hw + 0.25 * big), y + 0.01, z + 0.0), (sx * (hw + 0.25 * big), y + 0.01, z + 0.0)], HN)
            pl.box((sx * (hw + 0.01), y + 0.07 * big, z), (0.06, 0.05, 0.14), HND)                    # a bony skirt above each spike
    pl.finish()

    # ---------------------------------------------------------------- neck and head
    nk = TM("Neck", root, loc=(0, 0.84, -0.9), holder=True)
    loft(nk, [(-1.32, 0.2, 0.9, 0.7), (-1.18, 0.26, 0.96, 0.66), (-1.02, 0.3, 0.97, 0.62)], S, n=14, p=2.3)
    for z in (-1.1, -1.18, -1.26):                                                                    # cervical half-rings
        for f in (-0.6, -0.2, 0.2, 0.6):
            hw, yt, yb = _sec([(-1.32, 0.2, 0.9, 0.7), (-1.18, 0.26, 0.96, 0.66), (-1.02, 0.3, 0.97, 0.62)], z)
            x, y = _top([(-1.32, 0.2, 0.9, 0.7), (-1.18, 0.26, 0.96, 0.66), (-1.02, 0.3, 0.97, 0.62)], z, f)
            _scute(nk, x, y, z, 0.1, 0.07, 0.05, 0.2 * f, PL, keel=False)
    nk.finish()
    hd = TM("Head", root, loc=(0, 0.82, -1.24), holder=True)
    SK = [(-1.14, 0.31, 1.0, 0.70), (-1.28, 0.32, 0.98, 0.68), (-1.46, 0.27, 0.93, 0.68), (-1.64, 0.19, 0.87, 0.69), (-1.8, 0.11, 0.82, 0.71)]
    loft(hd, SK, S, n=12, p=2.3)                                                                      # the skull: broad at the back, a tapering muzzle
    hd.hexa([(-0.1, 0.7, -1.8), (0.1, 0.7, -1.8), (0.07, 0.7, -1.9), (-0.07, 0.7, -1.9), (-0.09, 0.8, -1.8), (0.09, 0.8, -1.8), (0.06, 0.77, -1.9), (-0.06, 0.77, -1.9)], HN)        # the horny beak
    hd.hexa([(-0.07, 0.74, -1.9), (0.07, 0.74, -1.9), (0.03, 0.74, -1.94), (-0.03, 0.74, -1.94), (-0.06, 0.78, -1.9), (0.06, 0.78, -1.9), (0.02, 0.75, -1.94), (-0.02, 0.75, -1.94)], HND)  # its hooked tip
    hd.box((0, 0.99, -1.4), (0.52, 0.05, 0.36), PL, taper=(0.9, 0.85))                                # the frontal shield
    for k in range(3):
        for f in (-0.6, 0.0, 0.6):
            x, y = _top(SK, -1.28 - k * 0.12, f)
            _scute(hd, x * 0.95, y, -1.28 - k * 0.12, 0.1, 0.09, 0.05, 0.2 * f, PL if k else PLL)
    for sx in (-1, 1):
        # squamosal horns: two big triangular horns sweeping back and out from the rear corners of the skull; small jugal horns below
        hd.hexa([(sx * 0.2, 0.9, -1.16), (sx * 0.28, 0.9, -1.16), (sx * 0.28, 0.9, -1.3), (sx * 0.2, 0.9, -1.3), (sx * 0.2, 1.0, -1.14), (sx * 0.28, 1.0, -1.14), (sx * 0.28, 0.99, -1.28), (sx * 0.2, 0.99, -1.28)], HND)
        hd.hexa([(sx * 0.24, 0.9, -1.12), (sx * 0.3, 0.9, -1.12), (sx * 0.3, 0.97, -1.12), (sx * 0.24, 0.97, -1.12), (sx * 0.52, 0.97, -0.99), (sx * 0.54, 0.97, -0.99), (sx * 0.54, 1.0, -0.99), (sx * 0.52, 1.0, -0.99)], HN)
        hd.hexa([(sx * 0.27, 0.74, -1.2), (sx * 0.27, 0.8, -1.2), (sx * 0.27, 0.8, -1.32), (sx * 0.27, 0.74, -1.32), (sx * 0.4, 0.7, -1.28), (sx * 0.4, 0.72, -1.28), (sx * 0.4, 0.72, -1.3), (sx * 0.4, 0.7, -1.3)], HN)
        hd.box((sx * 0.2, 0.96, -1.58), (0.14, 0.05, 0.12), PL, taper=(0.8, 0.8), rot_y=sx * 0.3)  # the brow osteoderm over each eye
        hd.box((sx * 0.06, 0.8, -1.86), (0.03, 0.025, 0.03), "DinoEye")                               # nostrils
        hd.box((sx * 0.13, 0.76, -1.62), (0.012, 0.012, 0.18), H3)                                    # the line of the mouth
    hd.finish()
    for sx, nm in ((-1, "EyeL"), (1, "EyeR")):                                                        # small, deep-set reptile eyes
        e = TM(nm, root, loc=(sx * 0.2, 0.89, -1.58), holder=True)
        e.box((sx * 0.2, 0.89, -1.58), (0.07, 0.06, 0.07), H3)                                        # the socket rim
        e.box((sx * 0.215, 0.89, -1.585), (0.04, 0.045, 0.05), "DinoIris")
        e.box((sx * 0.232, 0.89, -1.59), (0.012, 0.04, 0.02), "DinoEye")                              # a vertical pupil
        e.finish()

    # ---------------------------------------------------------------- legs: columnar, with hide folds, knee scutes and blunt hoof claws
    for (nm, x, z) in (("FL", -0.5, -0.6), ("FR", 0.5, -0.6), ("BL", -0.5, 0.58), ("BR", 0.5, 0.58)):
        sx = 1 if x > 0 else -1
        front = z < 0
        hp = TM("Hip" + nm, root, loc=(x, 0.62, z), holder=True)
        hp.tube([(x * 1.16, 0.74, z), (x * 1.06, 0.55, z + (0.02 if front else -0.02)), (x, 0.36, z)], [0.23, 0.205, 0.17], S, seg=10, squash=1.05)
        for k in range(3):
            hp.box((x + sx * 0.17, 0.62 - k * 0.1, z), (0.04, 0.05, 0.16), H3, taper=(0.8, 0.8))      # hide folds down the thigh
        _scute(hp, x + sx * 0.17, 0.66, z, 0.11, 0.1, 0.07, sx * 0.5, PL)
        hp.finish()
        sh = TM("Shin" + nm, root, loc=(x, 0.32, z), holder=True)
        sh.tube([(x, 0.36, z), (x, 0.2, z - 0.01), (x, 0.08, z - 0.02)], [0.17, 0.15, 0.155], S, seg=10)
        _scute(sh, x, 0.3, z - 0.15, 0.1, 0.09, 0.06, 0.0, PL, keel=False)                            # a knee scute
        for k in range(3):
            sh.cyl((x, 0.28 - k * 0.07, z), 0.16 - 0.004 * k, 0.16 - 0.004 * k, 0.012, H3, seg=10)    # wrinkle rings
        sh.finish()
        ft = TM("Foot" + nm, root, loc=(x, 0.04, z - 0.02), holder=True)
        ft.box((x, 0.04, z - 0.05), (0.3, 0.07, 0.3), SD, taper=(0.92, 0.9))
        for k, tx in enumerate((-0.095, 0.0, 0.095)):
            ft.hexa([(x + tx - 0.04, 0.0, z - 0.2), (x + tx + 0.04, 0.0, z - 0.2), (x + tx + 0.035, 0.0, z - 0.27), (x + tx - 0.035, 0.0, z - 0.27),
                     (x + tx - 0.04, 0.07, z - 0.2), (x + tx + 0.04, 0.07, z - 0.2), (x + tx + 0.03, 0.05, z - 0.26), (x + tx - 0.03, 0.05, z - 0.26)], CL)     # blunt hoof-like claws
        ft.finish()

    # ---------------------------------------------------------------- tail: three stiffening segments with scutes, then the club
    tails = [("Tail1", (0, 0.8, 0.85), 0.32, 0.24, 0.7), ("Tail2", (0, 0.8, 1.55), 0.24, 0.18, 0.7), ("Tail3", (0, 0.8, 2.25), 0.18, 0.14, 0.68)]
    for nm, loc, r0, r1, ln in tails:
        tt = TM(nm, root, loc=loc, holder=True)
        z0 = loc[2]
        tt.tube([(0, 0.8, z0), (0, 0.79, z0 + ln * 0.5), (0, 0.78, z0 + ln)], [r0, (r0 + r1) / 2, r1], S, seg=10, squash=0.85)
        tt.box((0, 0.78 - r0 * 0.55, z0 + ln / 2), (r0 * 1.1, r0 * 0.3, ln * 0.9), BE, taper=(0.8, 0.8))
        for k in range(4):
            zz = z0 + 0.08 + k * ln / 4.3
            rr = _lerp(r0, r1, k / 4.0)
            _scute(tt, 0, 0.8 + rr * 0.78, zz, rr * 0.7, 0.1, 0.06 + rr * 0.3, 0.0, PL)               # the dorsal row
            for sx in (-1, 1):
                tt.hexa([(sx * rr * 0.85, 0.82, zz - 0.04), (sx * rr * 0.85, 0.82, zz + 0.04), (sx * rr * 0.85, 0.74, zz + 0.04), (sx * rr * 0.85, 0.74, zz - 0.04),
                         (sx * (rr + 0.16), 0.78, zz), (sx * (rr + 0.16), 0.78, zz), (sx * (rr + 0.16), 0.78, zz), (sx * (rr + 0.16), 0.78, zz)], HN)          # lateral tail spikes
        tt.finish()
    cl = TM("Club", root, loc=(0, 0.8, 2.93), holder=True)
    prof = [(2.93, 0.14), (3.02, 0.22), (3.14, 0.34), (3.28, 0.42), (3.42, 0.38), (3.54, 0.22), (3.6, 0.1)]
    cl._skin([_ring(z, rr, 0.8 + rr * 0.78, 0.8 - rr * 0.78, n=14, p=2.2) for (z, rr) in prof], HN)   # the bone knob: a heavy, slightly flattened mace
    cl.box((0, 0.8, 3.28), (0.1, 0.7, 0.22), HND, taper=(1.0, 1.0))                                   # sutures where the fused plates meet
    for sx in (-1, 1):                                                                                # the two big lateral lobes and smaller knobs of the club
        cl.hexa([(sx * 0.26, 0.74, 3.12), (sx * 0.26, 0.86, 3.12), (sx * 0.26, 0.86, 3.4), (sx * 0.26, 0.74, 3.4), (sx * 0.5, 0.78, 3.2), (sx * 0.5, 0.82, 3.2), (sx * 0.5, 0.82, 3.34), (sx * 0.5, 0.78, 3.34)], HN)
        for k in range(3):
            _scute(cl, sx * (0.2 + 0.02 * k), 0.8 + 0.18 * (k - 1), 3.2 + 0.06 * k, 0.1, 0.1, 0.07, sx * 0.9, HND, keel=False)
    for k in range(5):
        a = k * 1.26
        cl.cyl((math.cos(a) * 0.2, 0.8 + math.sin(a) * 0.22, 3.4), 0.05, 0.02, 0.07, HND, seg=5, axis='z')    # studs on the face of the club
    cl.finish()


def egg(root):
    """The dinosaur egg (about 0.8 m tall, an elongated ovoid) in a straw nest. Holders: Shell (the whole egg, sealed in a pale calcite crust with a warm amber seam and
    speckles), Cracks (a dark crack pattern the game reveals while it hatches), ShellTop / ShellBottom (the two halves it splits into: jagged rims), Nest (straw ring and a wool pad)."""
    prof = [(0.00, 0.10), (0.06, 0.24), (0.16, 0.31), (0.30, 0.345), (0.46, 0.34), (0.62, 0.30), (0.78, 0.23), (0.92, 0.12), (1.0, 0.04)]    # (height fraction, radius): fat at the bottom third
    H = 0.82
    def rings(t, mat, lo=0.0, hi=1.0):
        for (f0, r0), (f1, r1) in zip(prof, prof[1:]):
            if f1 <= lo or f0 >= hi:
                continue
            a, b = max(f0, lo), min(f1, hi)
            ra = r0 + (r1 - r0) * (a - f0) / (f1 - f0)
            rb = r0 + (r1 - r0) * (b - f0) / (f1 - f0)
            t.cyl((0, 0.06 + (a + b) / 2 * H, 0), ra, rb, (b - a) * H, mat, seg=10)
    sh = TM("Shell", root, holder=True)
    rings(sh, "EggShell")
    for k in range(14):                                                                               # speckles
        a = k * 2.399
        f = 0.2 + (k * 0.113) % 0.7
        r = 0.31 * (1.0 - abs(f - 0.4) * 0.6)
        sh.box((math.cos(a) * r, 0.06 + f * H, math.sin(a) * r), (0.05, 0.04, 0.05), "EggSpot")
    for k in range(7):                                                                                # a crust of pale calcite lumps, thicker round the bottom
        a = k * 0.9 + 0.3
        f = 0.12 + (k * 0.071) % 0.35
        r = 0.33
        sh.box((math.cos(a) * r, 0.06 + f * H, math.sin(a) * r), (0.12, 0.09, 0.11), "EggCrust", taper=(0.7, 0.7))
    sh.cyl((0, 0.06 + 0.5 * H, 0), 0.352, 0.348, 0.035, "Amber", seg=10)                              # the warm seam round its middle
    sh.finish()
    ck = TM("Cracks", root, holder=True)
    for k, (a, f0, f1) in enumerate(((0.3, 0.3, 0.75), (2.3, 0.2, 0.62), (4.2, 0.35, 0.85), (5.3, 0.25, 0.5))):
        pts = []
        for i in range(5):
            f = f0 + (f1 - f0) * i / 4
            r = 0.33 * (1.0 - abs(f - 0.4) * 0.55)
            jig = 0.07 if i % 2 else -0.07
            pts.append((math.cos(a + jig) * (r + 0.004), 0.06 + f * H, math.sin(a + jig) * (r + 0.004)))
        for p0, p1 in zip(pts, pts[1:]):
            ck.bar(p0, p1, 0.022, 0.02, "DinoEye", up=(0, 1, 0))
    ck.finish()
    top = TM("ShellTop", root, holder=True)
    rings(top, "EggShell", lo=0.5)
    for k in range(9):
        a = k * math.tau / 9
        top.box((math.cos(a) * 0.3, 0.06 + 0.5 * H + 0.03, math.sin(a) * 0.3), (0.07, 0.1, 0.05), "EggShell", taper=(0.3, 0.5), rot_y=-a)       # a jagged rim
    top.finish()
    bot = TM("ShellBottom", root, holder=True)
    rings(bot, "EggShell", hi=0.5)
    bot.cyl((0, 0.06 + 0.2 * H, 0), 0.30, 0.30, 0.06, "EggInner", seg=10)                             # the inside of the shell
    for k in range(9):
        a = k * math.tau / 9 + 0.2
        bot.box((math.cos(a) * 0.3, 0.06 + 0.5 * H + 0.03, math.sin(a) * 0.3), (0.07, 0.1, 0.05), "EggShell", taper=(0.3, 0.5), rot_y=-a)
    bot.finish()
    ne = TM("Nest", root, holder=True)
    ne.cyl((0, 0.03, 0), 0.62, 0.55, 0.08, "StrawDk", seg=12)
    ne.cyl((0, 0.08, 0), 0.4, 0.4, 0.04, "Wool", seg=10)
    for k in range(26):                                                                               # straw stems radiating out of the ring
        a = k * math.tau / 26
        r0, r1 = 0.36, 0.66 + 0.06 * ((k * 7) % 3)
        ne.bar((math.cos(a) * r0, 0.1 + 0.02 * (k % 3), math.sin(a) * r0), (math.cos(a + 0.12) * r1, 0.06 + 0.1 * (k % 2), math.sin(a + 0.12) * r1), 0.035, 0.02, "Straw" if k % 2 else "StrawDk", up=(0, 1, 0))
    ne.finish()


def incubator(root):
    """The egg incubator Dr. Marsh sets up in Grandpa's living room: a little wooden cabinet on legs with a glass lid, a straw and wool bed, a hanging brooder lamp on an arm,
    a thermometer and a brass plaque. 0.9 m wide, 0.62 deep, 0.95 tall (the bed is at 0.62); faces -Z. Holders: Body, Glass (the lid), Lamp (the bulb and shade: the game pulses
    its glow) and Gauge (the thermometer's red bar)."""
    W, WD, TN, BR = "IncWood", "IncWoodDk", "IncTin", "Brass"
    t = TM("Body", root, holder=True)
    for sx in (-1, 1):
        for sz in (-1, 1):
            t.box((sx * 0.38, 0.26, sz * 0.24), (0.07, 0.52, 0.07), WD)                               # legs
    t.box((0, 0.5, 0), (0.86, 0.06, 0.6), WD)                                                         # the shelf under the cabinet
    t.box((0, 0.56, 0), (0.88, 0.08, 0.62), W)                                                        # the floor of the cabinet
    for sx in (-1, 1):
        t.box((sx * 0.42, 0.8, 0), (0.05, 0.42, 0.6), W)                                              # end walls
    t.box((0, 0.8, 0.28), (0.8, 0.42, 0.05), W)                                                       # back wall
    t.box((0, 0.68, -0.28), (0.8, 0.18, 0.05), W)                                                     # low front wall (the glass sits above it)
    t.box((0, 1.0, 0), (0.92, 0.04, 0.64), WD)                                                        # the top frame rail
    for sx in (-1, 1):
        t.box((sx * 0.43, 0.9, -0.28), (0.04, 0.22, 0.05), WD)                                        # front glass posts
    t.cyl((0, 0.62, 0), 0.34, 0.36, 0.06, "StrawDk", seg=12)                                          # the bed: straw...
    t.cyl((0, 0.66, 0), 0.22, 0.22, 0.04, "Wool", seg=10)                                             # ...and a wool pad
    for k in range(16):
        a = k * math.tau / 16
        t.bar((math.cos(a) * 0.2, 0.67, math.sin(a) * 0.2), (math.cos(a + 0.2) * 0.36, 0.64 + 0.03 * (k % 2), math.sin(a + 0.2) * 0.36), 0.03, 0.02, "Straw", up=(0, 1, 0))
    t.box((-0.28, 0.6, -0.1), (0.2, 0.05, 0.14), "IncWater")                                          # a little water tray
    t.box((-0.28, 0.63, -0.1), (0.22, 0.03, 0.16), TN)
    t.box((0.36, 0.5, -0.31), (0.12, 0.1, 0.02), BR)                                                  # a brass plaque on the front rail
    t.box((0.3, 0.76, -0.31), (0.08, 0.14, 0.02), TN)                                                 # the thermometer's tin plate
    t.box((-0.3, 0.76, -0.31), (0.09, 0.09, 0.03), BR)                                                # a dial
    t.cyl((-0.3, 0.76, -0.33), 0.03, 0.03, 0.02, "DinoWhite", seg=8, axis='z')
    t.bar((0.0, 1.0, 0.3), (0.0, 1.5, 0.3), 0.04, 0.04, TN)                                           # the lamp's stand rises behind the cabinet...
    t.bar((0.0, 1.5, 0.3), (0.0, 1.5, 0.0), 0.04, 0.04, TN)                                           # ...and its arm reaches over the bed
    t.box((0.0, 1.0, 0.3), (0.16, 0.04, 0.12), TN)
    t.box((0.4, 0.5, 0.34), (0.2, 0.2, 0.04), "IncRed")                                               # a switch box on the back
    t.finish()
    g = TM("Glass", root, holder=True)
    g.box((0, 0.9, -0.31), (0.8, 0.3, 0.012), "PickGlass")                                            # front pane
    for sx in (-1, 1):
        g.box((sx * 0.4, 0.92, 0), (0.012, 0.28, 0.56), "PickGlass")                                  # side panes
    g.box((0, 1.04, 0), (0.84, 0.012, 0.6), "PickGlass", taper=(1.0, 1.0))                            # and the lid
    g.finish()
    lp = TM("Lamp", root, loc=(0, 1.36, 0), holder=True)
    lp.cyl((0, 1.4, 0), 0.16, 0.07, 0.12, TN, seg=10)                                                 # the shade
    lp.cyl((0, 1.32, 0), 0.06, 0.06, 0.08, "Amber", seg=8)                                            # the warm bulb
    lp.finish()
    gg = TM("Gauge", root, loc=(0.3, 0.76, -0.33), holder=True)
    gg.box((0.3, 0.74, -0.32), (0.03, 0.1, 0.01), "IncRed")
    gg.finish()


def fossil_nest(root):
    """The buried fossil: an ankylosaur mother who curled round her nest 68 million years ago, lying in a slab of pale limestone (about 3.4 m long). Skull and club tail are
    stone-coloured bone, the ribs fan out of the spine, four fossil eggs sit in the hollow between her legs and fifth, sealed in calcite, still glows faintly. Holders: Body
    (slab, bones, fossil eggs) and Glow (the sealed egg: the game pulses its light)."""
    B, E, SL, SLL = "FossilBone", "FossilEgg", "Slab", "SlabLt"
    t = TM("Body", root, holder=True)
    t.box((0, 0.05, 0), (3.6, 0.1, 2.0), SL, taper=(0.92, 0.9))                                       # the slab she lies in, with chipped edges
    t.box((-0.9, 0.09, 0.7), (1.5, 0.08, 0.7), SLL, taper=(0.8, 0.8))
    t.box((1.1, 0.09, -0.6), (1.2, 0.08, 0.6), SLL, taper=(0.8, 0.8))
    for k in range(10):                                                                               # the spine curls: a row of vertebrae along an arc
        a = -0.4 + k * 0.17
        x = -0.4 - 1.5 * math.cos(a * 1.2)
        z = 0.2 + 1.05 * math.sin(a * 1.2) - 0.5
        t.box((-1.55 + k * 0.28, 0.24, 0.55 - 0.9 * math.sin(k * 0.34)), (0.2, 0.18, 0.22), B, taper=(0.7, 0.7))
    for k in range(9):                                                                                # ribs: curved bars fanning from the spine over the nest
        x = -1.2 + k * 0.28
        z0 = 0.55 - 0.9 * math.sin((k + 1.5) * 0.34)
        t.bar((x, 0.28, z0), (x + 0.04, 0.5, z0 - 0.35), 0.08, 0.08, B, up=(1, 0, 0))
        t.bar((x + 0.04, 0.5, z0 - 0.35), (x + 0.08, 0.2, z0 - 0.62), 0.07, 0.07, B, up=(1, 0, 0))
    t.hexa([(0.9, 0.1, -0.9), (1.6, 0.1, -0.9), (1.6, 0.1, -0.25), (0.9, 0.1, -0.25), (1.0, 0.45, -0.85), (1.5, 0.42, -0.85), (1.5, 0.4, -0.3), (1.0, 0.4, -0.3)], B)       # the skull, tucked down
    t.box((1.72, 0.2, -0.58), (0.3, 0.14, 0.3), B, taper=(0.7, 0.7))                                  # the beak
    t.box((1.2, 0.5, -0.58), (0.5, 0.07, 0.5), B, taper=(0.9, 0.9))                                   # brow armour
    for sz in (-1, 1):
        t.box((1.25, 0.28, -0.58 + sz * 0.42), (0.1, 0.12, 0.2), B, taper=(0.5, 0.5))                 # cheek horns
    for (lx, lz) in ((-0.9, -0.55), (-0.2, -0.85), (-1.5, 0.8), (-0.6, 0.95)):                        # leg bones
        t.bar((lx, 0.12, lz), (lx + 0.08, 0.32, lz + 0.05), 0.12, 0.12, B)
    t.bar((-1.55, 0.2, 0.25), (-1.7, 0.18, 1.0), 0.16, 0.14, B, up=(0, 1, 0))                         # the tail along the curve...
    t.bar((-1.7, 0.18, 1.0), (-1.2, 0.18, 1.45), 0.13, 0.12, B)
    t.cyl((-0.95, 0.24, 1.6), 0.26, 0.2, 0.34, B, seg=8, axis='x')                                    # ...ending in the club
    for sz in (-1, 1):
        t.cyl((-0.95, 0.24, 1.6 + sz * 0.3), 0.05, 0.01, 0.2, B, seg=5, axis='z')
    for k, (ex, ez) in enumerate(((0.1, -0.2), (-0.25, 0.05), (0.35, 0.18), (-0.15, -0.5))):         # the fossil eggs in the hollow
        t.cyl((ex, 0.24, ez), 0.17, 0.17, 0.3, E, seg=8)
        t.cyl((ex, 0.42, ez), 0.17, 0.06, 0.12, E, seg=8)
        t.cyl((ex, 0.08, ez), 0.1, 0.17, 0.12, E, seg=8)
    t.finish()
    gl = TM("Glow", root, loc=(0.55, 0.32, 0.05), holder=True)
    gl.cyl((0.55, 0.3, 0.05), 0.17, 0.17, 0.3, "EggShell", seg=8)
    gl.cyl((0.55, 0.48, 0.05), 0.17, 0.06, 0.12, "EggShell", seg=8)
    gl.cyl((0.55, 0.14, 0.05), 0.1, 0.17, 0.12, "EggShell", seg=8)
    gl.cyl((0.55, 0.3, 0.05), 0.176, 0.176, 0.04, "Amber", seg=8)
    for k in range(5):
        a = k * 1.3
        gl.box((0.55 + math.cos(a) * 0.17, 0.2 + 0.05 * k, 0.05 + math.sin(a) * 0.17), (0.07, 0.06, 0.06), "EggCrust", taper=(0.7, 0.7))
    gl.finish()


def cash_hopper(root):
    """Grandpa Walt's old Cash Hopper: a riveted, rusting steel hopper on a concrete plinth. Footprint 1.9 x 1.9 m, front (the display) faces -Z, a belt reaches it from any side. A wide
    octagonal funnel with a hazard rim on top of a riveted housing, a spoked cast flywheel on the +X side, a hinged flap on top, a piston ram, a status lamp, a blank sign board, a coin tray
    and a chute at the back. Named nodes for the game (scripts/cash_hopper_view.gd): Attach_Body, Attach_InputFunnel, Attach_Processor, Attach_ConveyorIn, Attach_RockSpawn, Attach_Audio,
    Attach_FloatText, Attach_Display, Pivot_Flywheel (spins about X), Pivot_Flap (hinge about X), Pivot_Piston (slides in Y), Pivot_Funnel (shakes while it works), Lamp_Status (its
    material is recoloured), Fill (the heap of rock waiting in the funnel: the game scales it)."""
    ST, SD, RU, RD, YE, IR, BR, CO, SN = "HopSteel", "HopSteelDk", "HopRust", "HopRustDk", "HopYellow", "HopIron", "HopBrass", "HopConcrete", "HopStain"
    r = rnd(23)
    t = TM("Body", root, holder=True)
    # ---- plinth, anchor bolts, oil stains
    t.box((0, 0.09, 0), (1.9, 0.18, 1.9), CO, taper=(0.97, 0.97))
    t.box((0, 0.19, 0), (1.76, 0.03, 1.76), CO)
    for sx in (-1, 1):
        for sz in (-1, 1):
            t.cyl((sx * 0.8, 0.22, sz * 0.8), 0.05, 0.05, 0.08, IR, seg=6)
            t.box((sx * 0.8, 0.185, sz * 0.8), (0.16, 0.012, 0.16), IR)
    for k in range(6):
        t.box((r.uniform(-0.8, 0.8), 0.195, r.uniform(-0.8, 0.8)), (r.uniform(0.15, 0.4), 0.004, r.uniform(0.1, 0.3)), SN, rot_y=r.uniform(0, 3))
    # ---- corner posts (steel angle), cross bracing
    for sx in (-1, 1):
        for sz in (-1, 1):
            t.box((sx * 0.78, 0.82, sz * 0.78), (0.14, 1.28, 0.14), SD)
            t.box((sx * 0.78, 0.22, sz * 0.78), (0.2, 0.06, 0.2), IR)
    for sz in (-1, 1):
        t.bar((-0.78, 0.3, sz * 0.84), (0.78, 1.1, sz * 0.84), 0.06, 0.05, SD, up=(0, 0, 1))
        t.bar((0.78, 0.3, sz * 0.84), (-0.78, 1.1, sz * 0.84), 0.06, 0.05, SD, up=(0, 0, 1))
    # ---- the housing: riveted panels with seams, vents, a service hatch at the back
    t.box((0, 0.86, 0), (1.62, 1.0, 1.62), ST, taper=(0.99, 0.99))
    for k in range(5):                                                                              # horizontal panel seams on all four faces
        y = 0.45 + k * 0.2
        t.box((0, y, -0.815), (1.64, 0.015, 0.01), SD)
        t.box((0, y, 0.815), (1.64, 0.015, 0.01), SD)
        t.box((-0.815, y, 0), (0.01, 0.015, 1.64), SD)
        t.box((0.815, y, 0), (0.01, 0.015, 1.64), SD)
    for k in range(9):                                                                              # rivet rows along the seams
        x = -0.7 + k * 0.175
        for y in (0.45, 0.85, 1.25):
            t.box((x, y + 0.02, -0.82), (0.03, 0.03, 0.02), IR)
            t.box((x, y + 0.02, 0.82), (0.03, 0.03, 0.02), IR)
    for k in range(6):                                                                              # rust blooms and scrapes
        sx = r.choice((-1, 1))
        t.box((sx * 0.815, r.uniform(0.5, 1.3), r.uniform(-0.6, 0.6)), (0.012, r.uniform(0.1, 0.3), r.uniform(0.15, 0.4)), RU if k % 2 else RD)
        t.box((r.uniform(-0.6, 0.6), r.uniform(0.5, 1.3), -0.82 if k % 2 else 0.82), (r.uniform(0.15, 0.4), r.uniform(0.1, 0.25), 0.012), RU if k % 3 else RD)
    for k in range(5):                                                                              # louvred vents on the -X side
        t.box((-0.83, 0.62 + k * 0.07, 0.0), (0.03, 0.03, 0.5), SD, taper=(1.0, 1.0))
    t.box((0, 0.75, 0.83), (0.8, 0.6, 0.03), SD)                                                    # the service hatch at the back, with hinges and a latch
    for sy in (0.55, 0.95):
        t.cyl((-0.4, sy, 0.855), 0.03, 0.03, 0.12, IR, seg=6, axis='z')
    t.box((0.3, 0.75, 0.86), (0.1, 0.05, 0.03), BR)
    # ---- the front: display bezel and screen housing, a brass plaque and a blank sign board hung on chains
    t.box((0, 1.0, -0.84), (1.34, 0.62, 0.08), IR)
    t.box((0, 1.0, -0.88), (1.2, 0.5, 0.03), "HopScreen")
    for sx in (-1, 1):
        for sy in (-1, 1):
            t.cyl((sx * 0.6, 1.0 + sy * 0.25, -0.89), 0.018, 0.018, 0.015, BR, seg=6, axis='z')
    t.box((0.5, 0.52, -0.83), (0.3, 0.1, 0.02), BR)                                                 # a brass plaque (blank)
    t.box((0, 0.64, -0.835), (0.62, 0.1, 0.03), IR)                                                 # the payout slot: a framed opening in the front, a sloped chute down to the tray
    t.box((0, 0.64, -0.852), (0.5, 0.045, 0.02), SN)
    t.slab(0.62, -0.86, 0.5, 0.47, -1.0, 0.54, 0.025, BR, x=0.0)
    for sx in (-1, 1):
        t.box((sx * 0.27, 0.57, -0.93), (0.025, 0.12, 0.17), BR)                                    # chute cheeks
    t.box((0, 0.48, -0.9), (0.9, 0.08, 0.1), SD)                                                    # the coin tray lip and its tray
    t.box((0, 0.42, -0.95), (0.8, 0.04, 0.2), BR)
    t.box((0, 0.46, -1.04), (0.8, 0.08, 0.02), BR)
    for sx in (-1, 1):
        t.bar((sx * 0.55, 1.62, -0.7), (sx * 0.55, 1.35, -0.86), 0.015, 0.015, IR, up=(1, 0, 0))   # the sign's chains
    t.box((0, 1.28, -0.9), (1.2, 0.2, 0.05), "HopWood")
    t.box((0, 1.28, -0.93), (1.12, 0.16, 0.01), "HopYellow")
    # ---- the top plate the funnel stands on, the funnel's four brackets, the rim
    t.box((0, 1.4, 0), (1.75, 0.12, 1.75), SD, taper=(0.98, 0.98))
    t.box((0, 1.47, 0), (1.62, 0.03, 1.62), RD)
    for sx in (-1, 1):
        for sz in (-1, 1):
            t.bar((sx * 0.65, 1.46, sz * 0.65), (sx * 0.42, 1.95, sz * 0.42), 0.09, 0.05, SD, up=(0, 1, 0))
    # ---- coin chute at the back (where belts meet it: the game links them by distance), and a drain pipe
    t.box((0, 0.55, 0.98), (0.7, 0.14, 0.3), IR)
    t.bar((0, 0.62, 0.84), (0, 0.5, 1.12), 0.64, 0.05, SD, up=(0, 1, 0))
    for sx in (-1, 1):
        t.box((sx * 0.35, 0.6, 1.05), (0.04, 0.2, 0.34), SD)
    t.cyl((-0.7, 0.5, 0.86), 0.05, 0.05, 1.0, IR, seg=6)
    # ---- the motor with its belt guard, next to the flywheel's axle
    t.box((0.9, 0.5, 0.4), (0.3, 0.3, 0.4), SD)
    t.cyl((0.9, 0.55, 0.4), 0.12, 0.12, 0.34, RU, seg=8, axis='x')
    t.box((0.9, 0.82, 0.22), (0.26, 0.16, 0.06), IR)
    t.bar((0.97, 0.6, 0.4), (0.97, 0.88, 0.05), 0.06, 0.05, IR, up=(1, 0, 0))                       # the drive belt from the motor up to the flywheel's axle
    t.finish()

    # ---- funnel: a wide octagonal frustum with ribs, a hazard rim, a dark throat
    fn = TM("Pivot_Funnel", root, loc=(0, 1.45, 0), holder=True)
    fn.cyl((0, 1.78, 0), 0.5, 0.98, 0.66, RU, seg=8)
    fn.cyl((0, 1.78, 0), 0.47, 0.94, 0.68, SN, seg=8)                                               # the inside, dark
    fn.cyl((0, 2.13, 0), 1.02, 1.02, 0.06, YE, seg=8)                                               # the hazard rim
    for k in range(8):
        a = math.tau * (k + 0.5) / 8
        fn.box((math.cos(a) * 0.74, 2.14, math.sin(a) * 0.74), (0.2, 0.05, 0.07), IR, rot_y=-a)       # black hazard segments on the rim
        fn.bar((math.cos(a) * 0.52, 1.5, math.sin(a) * 0.52), (math.cos(a) * 0.99, 2.1, math.sin(a) * 0.99), 0.07, 0.035, SD, up=(0, 1, 0))     # ribs
    for k in range(6):
        a = k * 1.1
        fn.box((math.cos(a) * 0.8, 1.9 + 0.05 * (k % 3), math.sin(a) * 0.8), (0.18, 0.12, 0.012), RD, rot_y=-a)                                # rust patches
    fn.finish()
    fl = TM("Fill", root, loc=(0, 1.9, 0), holder=True)                                             # the heap of rock waiting in the funnel
    for k in range(14):
        a = k * 2.4
        rr = 0.32 * math.sqrt(k / 14.0)
        fl.box((math.cos(a) * rr, 1.95 + 0.07 * (k % 4), math.sin(a) * rr), (r.uniform(0.2, 0.34), r.uniform(0.14, 0.26), r.uniform(0.2, 0.34)), "HopRock", taper=(0.7, 0.7), rot_y=r.uniform(0, 3))
    fl.finish()

    # ---- flywheel (+X side): rim, spokes, hub, bolts, axle and bearing blocks
    fw = TM("Pivot_Flywheel", root, loc=(0.97, 0.85, 0.0), holder=True)
    fw.cyl((1.0, 0.85, 0), 0.43, 0.43, 0.13, IR, seg=14, axis='x')
    fw.cyl((1.0, 0.85, 0), 0.34, 0.34, 0.145, SD, seg=14, axis='x')
    fw.cyl((1.0, 0.85, 0), 0.12, 0.12, 0.2, YE, seg=8, axis='x')
    for k in range(6):
        a = k * math.tau / 6
        fw.bar((1.0, 0.85, 0), (1.0, 0.85 + math.sin(a) * 0.36, math.cos(a) * 0.36), 0.07, 0.06, IR, up=(1, 0, 0))
        fw.box((1.065, 0.85 + math.sin(a) * 0.4, math.cos(a) * 0.4), (0.02, 0.05, 0.05), BR)
    fw.box((1.09, 0.85, 0), (0.02, 0.2, 0.05), YE)                                                  # a painted mark so the spin reads
    fw.finish()
    ax = TM("Axle", root, holder=True)
    ax.cyl((0.9, 0.85, 0), 0.05, 0.05, 0.3, IR, seg=8, axis='x')
    for sz in (-1, 1):
        ax.box((0.86, 0.72, sz * 0.2), (0.12, 0.2, 0.1), SD)
    ax.finish()

    # ---- flap: a hinged steel lid over the chute side of the top plate (kicks on every sale)
    fp = TM("Pivot_Flap", root, loc=(0, 1.5, 0.8), holder=True)
    fp.box((0, 1.52, 0.55), (1.2, 0.05, 0.5), YE)
    fp.box((0, 1.555, 0.55), (1.1, 0.012, 0.4), IR, taper=(0.9, 0.9))
    for sx in (-1, 1):
        fp.cyl((sx * 0.5, 1.5, 0.8), 0.035, 0.035, 0.14, IR, seg=6, axis='x')
    fp.finish()

    # ---- the piston ram (slides in Y while it works) on the front-left corner
    ps = TM("Pivot_Piston", root, loc=(-0.55, 1.2, -0.95), holder=True)
    ps.cyl((-0.55, 1.2, -0.95), 0.045, 0.045, 0.42, BR, seg=8)
    ps.cyl((-0.55, 1.43, -0.95), 0.07, 0.07, 0.05, IR, seg=8)
    ps.finish()
    cyl = TM("Cylinder", root, holder=True)
    cyl.cyl((-0.55, 0.95, -0.95), 0.09, 0.09, 0.5, SD, seg=10)
    cyl.cyl((-0.55, 0.7, -0.95), 0.11, 0.11, 0.06, IR, seg=10)
    cyl.finish()

    # ---- the status lamp: a caged dome on the corner of the top plate
    lm = TM("Lamp_Status", root, loc=(0.6, 1.5, -0.6), holder=True)
    lm.cyl((0.6, 1.55, -0.6), 0.07, 0.06, 0.1, "HopLamp", seg=8)
    lm.finish()
    cg = TM("LampCage", root, holder=True)
    cg.cyl((0.6, 1.5, -0.6), 0.1, 0.1, 0.04, IR, seg=8)
    for k in range(4):
        a = k * math.pi / 2
        cg.bar((0.6 + math.cos(a) * 0.08, 1.5, -0.6 + math.sin(a) * 0.08), (0.6 + math.cos(a) * 0.05, 1.63, -0.6 + math.sin(a) * 0.05), 0.012, 0.012, IR, up=(0, 1, 0))
    cg.finish()

    # ---- attachment points (empties) the game reads
    for nm, loc in (("Attach_Body", (0, 0, 0)), ("Attach_InputFunnel", (0, 1.45, 0)), ("Attach_Processor", (0, 0.55, 0)), ("Attach_ConveyorIn", (0, 0.55, 1.1)),
                    ("Attach_RockSpawn", (0, 2.35, 0)), ("Attach_Audio", (0, 1.2, 0)), ("Attach_FloatText", (0, 2.6, 0)), ("Attach_Display", (0, 0.95, -0.97))):
        TM(nm, root, loc=loc, holder=True).finish()


MODELS = {
    "pine_tall": pine_tall, "pine_young": pine_young, "birch": birch, "log": log, "stump": stump, "bush": bush, "fern": fern, "grass": grass, "flowers": flowers,
    "mossy_stone": mossy_stone, "peak_a": peak_a, "peak_b": peak_b, "ridge": ridge, "foothill": foothill, "cliff": cliff, "tunnel_mountain": tunnel_mountain,
    "tunnel_portal": tunnel_portal, "tunnel_set": tunnel_set, "cash_hopper": cash_hopper, "ore_pieces": ground_models.ore_pieces, "dirt_clods": ground_models.dirt_clods, "pine_far": pine_far, "pickup": pickup, "dino": dino, "egg": egg, "incubator": incubator, "fossil_nest": fossil_nest, "deer": deer, "rabbit": rabbit,
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
