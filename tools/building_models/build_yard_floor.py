"""QUARRY DAYS - the industrial yard's floor details, modelled in Blender (5.x, headless):

    blender -b --factory-startup -P tools/building_models/build_yard_floor.py

Writes assets/buildings/BLD_QD_YardFloor.glb. Model space: origin at the garage slab's centre on the ground, x along the garage (26 m), z front to back (7.6 m slab, plus a strip of
apron to the front). Everything is a few millimetres tall and sits on the game's flat concrete slab: poured-slab joints (a seam every 4.7 m with a darker sealant line), stepped
joint bands, oil stains under each bay, tyre scuffs along the drive lane, hairline cracks, a drain channel with a grating, a double painted bay line per bay with a number plate,
a hazard-striped walkway at the back wall, steel plates at the door and a painted keep-clear box. It replaces nothing: the slab quad is still the floor.
"""
import bpy, math, os, sys, random
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "tool_models"))
sys.path.insert(0, HERE)
import qd_blender as Q
from qd_blender import empty
from tm import TM
import build_buildings as BB

Q.MATERIALS.update({
    "FloorJoint": (None, (0.16, 0.16, 0.17), 0.95, 0.0, {}),
    "Stain":      (None, (0.07, 0.07, 0.075), 0.55, 0.0, {}),
    "Crack":      (None, (0.12, 0.12, 0.13), 1.0, 0.0, {}),
    "PaintWhite": (None, (0.86, 0.86, 0.82), 0.9, 0.0, {}),
    "Paint":      (None, (0.90, 0.78, 0.20), 0.9, 0.0, {}),
    "Grate":      (None, (0.22, 0.23, 0.25), 0.5, 0.6, {}),
})

W2 = 13.0
NB = 5
Y = 0.085                       # just over the slab (the slab quad is at 0.075)


def floor(root):
    rnd = random.Random(7)
    t = TM("Body", root, holder=True)
    bw = 2 * W2 / NB
    xs = [-W2 + k * bw for k in range(NB + 1)]
    # ---- slab joints: a long seam down the middle of each bay row and cross seams every bay, sealant dark, with a lighter band beside it
    for x in xs[1:-1]:
        t.box((x, Y, 0.0), (0.05, 0.004, 7.6), "FloorJoint")
    for z in (-1.9, 1.9):
        t.box((0.0, Y, z), (2 * W2 - 0.3, 0.004, 0.05), "FloorJoint")
    # ---- painted bay lines: a double line each side, wheel stops at the back, a bay number plate at the front
    for k in range(NB + 1):
        for off in (-0.07, 0.07):
            t.box((xs[k] + off, Y + 0.002, 0.2), (0.07, 0.004, 5.4), "Paint")
    for k in range(NB):
        cx = (xs[k] + xs[k + 1]) / 2
        t.box((cx, Y + 0.002, -2.45), (0.9, 0.004, 0.45), "PaintWhite")                  # the bay number plate (the game does not write on it)
        t.box((cx, Y + 0.003, -2.45), (0.7, 0.004, 0.25), "FloorJoint")
        for sx in (-1, 1):                                                              # wheel stops
            t.box((cx + sx * 0.9, Y + 0.06, 2.55), (0.9, 0.12, 0.22), "Paint")
    # ---- oil stains: irregular dark blotches under the engine position of each bay, several overlapping flat discs
    for k in range(NB):
        cx = (xs[k] + xs[k + 1]) / 2
        for i in range(rnd.randint(3, 5)):
            r = rnd.uniform(0.25, 0.6)
            t.cyl((cx + rnd.uniform(-0.8, 0.8), Y + 0.001 + i * 0.0004, rnd.uniform(-1.2, 0.6)), r, r * rnd.uniform(0.8, 1.0), 0.003, "Stain", seg=10, phase=rnd.random(), squash=rnd.uniform(0.6, 1.0))
    # ---- tyre scuffs along the drive lane at the front: pairs of long dark smears
    for k in range(10):
        x = rnd.uniform(-W2 + 1, W2 - 1)
        for dz in (-0.45, 0.45):
            t.box((x, Y + 0.001, -3.2 + dz), (rnd.uniform(1.5, 3.5), 0.003, 0.18), "FloorJoint", rot_y=rnd.uniform(-0.05, 0.05))
    # ---- hairline cracks: thin boxes at random angles in small chains
    for k in range(14):
        x, z = rnd.uniform(-W2 + 1, W2 - 1), rnd.uniform(-3.2, 3.2)
        ang = rnd.uniform(0, math.pi)
        for seg in range(rnd.randint(2, 4)):
            ln = rnd.uniform(0.4, 0.9)
            t.box((x + math.cos(ang) * ln / 2, Y + 0.002, z + math.sin(ang) * ln / 2), (ln, 0.003, 0.025), "Crack", rot_y=-ang)
            x += math.cos(ang) * ln
            z += math.sin(ang) * ln
            ang += rnd.uniform(-0.6, 0.6)
    # ---- a drain channel with a grating across the front of the slab
    t.box((0.0, Y - 0.02, -3.55), (2 * W2 - 2.0, 0.03, 0.34), "FloorJoint")
    for i in range(int((2 * W2 - 2.2) / 0.16)):
        t.box((-W2 + 1.1 + i * 0.16, Y + 0.0, -3.55), (0.05, 0.02, 0.3), "Grate")
    t.box((0.0, Y + 0.01, -3.72), (2 * W2 - 2.0, 0.03, 0.04), "Grate")
    t.box((0.0, Y + 0.01, -3.38), (2 * W2 - 2.0, 0.03, 0.04), "Grate")
    # ---- the hazard-striped walkway along the back wall (a person's lane, kept clear) and steel diamond plates at the door
    for z in (2.85, 3.35):
        t.box((0.0, Y + 0.002, z), (2 * W2 - 0.5, 0.004, 0.08), "Hazard")
    for x in (-5.3,):
        t.box((x, Y + 0.004, 3.2), (5.6, 0.008, 1.1), "Steel")
        for i in range(8):
            t.box((x - 2.4 + i * 0.7, Y + 0.009, 3.2), (0.04, 0.004, 0.9), "Hazard") if False else None
    t.finish()


if __name__ == "__main__":
    BB.build("YardFloor", floor, "BLD_QD_YardFloor.glb")
    print("BUILD_OK")
