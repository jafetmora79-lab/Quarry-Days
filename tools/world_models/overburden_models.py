"""QUARRY DAYS - the overburden: what lies on top of the rock in the starter cut and has to be cleared first (Blender, low-poly and flat shaded).
Registered by build_world.py:  overburden_weeds (a tangle of dry weeds with seed heads, docks and thistles on a mound of earth),
overburden_rubble (a heap of broken limestone blocks on a skirt of earth, with pebbles and moss). Footprints ~1.2 m and ~1.6 m; the game scales the rubble down as it is broken.
Materials carry NAMES only (scripts/art/world_models.gd): the foliage names sway in the wind; the rock names get the game's strata texture."""
import math
import random

from tm import TM
import ground_models as G


def weeds(root):
    t = TM("Body", root, holder=True)
    r = random.Random(11)
    for k in range(5):                                                                    # the mound of earth the weeds grow from
        a = k * 1.26 + r.uniform(-0.2, 0.2)
        d = 0.0 if k == 0 else r.uniform(0.25, 0.5)
        G.chunk(t, (math.cos(a) * d, 0.0, math.sin(a) * d), (r.uniform(0.28, 0.4), r.uniform(0.1, 0.16), r.uniform(0.28, 0.4)), ["ClodMid", "ClodDark", "ClodLight"][k % 3], r, 0.25, sub=0, base_clip=0.3)
    mats = ["Grass", "Leaf", "LeafWarm", "Grass", "Fern"]
    for k in range(34):                                                                   # blades
        a = r.uniform(0, math.tau)
        d = r.uniform(0.0, 0.5)
        h = r.uniform(0.45, 1.1)
        lean = r.uniform(0.05, 0.4)
        bx, bz = math.cos(a) * d, math.sin(a) * d
        t.bar((bx, 0.05, bz), (bx + math.cos(a) * lean, h, bz + math.sin(a) * lean), 0.05, 0.08, mats[k % 5], up=(0, 1, 0))
    for k in range(7):                                                                    # tall dead stalks with seed heads
        a = r.uniform(0, math.tau)
        d = r.uniform(0.05, 0.4)
        h = r.uniform(1.0, 1.4)
        lean = r.uniform(0.05, 0.25)
        x0, z0 = math.cos(a) * d, math.sin(a) * d
        x1, z1 = x0 + math.cos(a) * lean, z0 + math.sin(a) * lean
        t.bar((x0, 0.05, z0), (x1, h, z1), 0.03, 0.03, "StrawDk", up=(1, 0, 0))
        t.box((x1, h + 0.06, z1), (0.07, 0.16, 0.07), "Straw", taper=(0.6, 0.6))
    for k in range(3):                                                                    # thistles
        a = k * 2.1 + 0.4
        x, z = math.cos(a) * 0.32, math.sin(a) * 0.32
        t.bar((x, 0.05, z), (x, 0.8 + 0.1 * k, z), 0.03, 0.03, "Fern", up=(1, 0, 0))
        t.box((x, 0.86 + 0.1 * k, z), (0.13, 0.1, 0.13), "FlowerP")
        t.box((x, 0.8 + 0.1 * k, z), (0.09, 0.05, 0.09), "Leaf")
    for k in range(5):                                                                    # broad dock leaves lying out from the root
        a = k * 1.25 + 0.3
        t.bar((math.cos(a) * 0.1, 0.12, math.sin(a) * 0.1), (math.cos(a) * 0.62, 0.32 - 0.05 * (k % 2), math.sin(a) * 0.62), 0.34, 0.03, "Leaf", up=(0, 1, 0))
    t.finish()


def rubble(root):
    t = TM("Body", root, holder=True)
    r = random.Random(31)
    for k in range(5):                                                                    # a skirt of earth round the foot
        a = k * 1.26 + 0.3
        G.chunk(t, (math.cos(a) * 0.75, 0.0, math.sin(a) * 0.65), (r.uniform(0.35, 0.5), r.uniform(0.1, 0.16), r.uniform(0.3, 0.45)), ["ClodMid", "ClodDark"][k % 2], r, 0.25, sub=0, base_clip=0.3)
    blocks = [  # centre, half extents, material: a pile of broken blocks, big at the foot, smaller on top
        ((0.0, 0.0, 0.0), (0.62, 0.42, 0.55), "RockC"), ((0.7, 0.0, 0.25), (0.42, 0.3, 0.4), "RockA"), ((-0.62, 0.0, 0.3), (0.38, 0.28, 0.36), "RockB"),
        ((0.12, 0.0, -0.55), (0.45, 0.32, 0.38), "RockA"), ((-0.3, 0.0, -0.4), (0.3, 0.24, 0.3), "RockC"), ((0.55, 0.0, -0.35), (0.3, 0.22, 0.28), "RockB"),
        ((0.1, 0.4, 0.05), (0.42, 0.28, 0.38), "RockA"), ((-0.25, 0.5, 0.1), (0.26, 0.2, 0.24), "RockC"), ((0.3, 0.55, -0.1), (0.22, 0.18, 0.22), "RockB"),
        ((0.0, 0.78, 0.0), (0.2, 0.15, 0.2), "RockC"),
    ]
    for (c, s, m) in blocks:
        G.chunk(t, c, s, m, r, 0.32, sub=0, base_clip=0.5)
    for k in range(5):                                                                    # slabs: a few flat broken plates leaning on the pile
        a = k * 1.3 + 0.2
        t.box((math.cos(a) * 0.55, 0.3 + 0.1 * (k % 2), math.sin(a) * 0.5), (0.5, 0.1, 0.34), "RockD", rot_y=a, taper=(0.9, 0.8))
    for k in range(14):                                                                   # pebbles and chips round the foot
        a = r.uniform(0, math.tau)
        d = r.uniform(0.8, 1.15)
        s = r.uniform(0.05, 0.12)
        G.chunk(t, (math.cos(a) * d, 0.0, math.sin(a) * d), (s, s * 0.6, s * 0.9), ["PebbleA", "PebbleB", "PebbleC"][k % 3], r, 0.3, sub=0, base_clip=0.3)
    for (x, y, z) in [(0.0, 0.85, 0.02), (-0.5, 0.36, 0.25), (0.62, 0.5, 0.2)]:              # moss and a tuft of grass in the cracks
        t.box((x, y, z), (0.22, 0.05, 0.2), "Moss")
    for k in range(4):
        a = k * 1.6
        t.bar((math.cos(a) * 0.9, 0.0, math.sin(a) * 0.8), (math.cos(a) * 1.0, 0.4, math.sin(a) * 0.9), 0.04, 0.08, "Grass", up=(0, 1, 0))
    t.finish()
