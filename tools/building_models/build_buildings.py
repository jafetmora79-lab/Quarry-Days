"""QUARRY DAYS - yard buildings, modelled in Blender (5.x, headless), lightweight and flat shaded like the rest of the game:

    blender -b --factory-startup -P tools/building_models/build_buildings.py [office]

Writes assets/buildings/BLD_QD_<Name>.glb (+ assets/buildings/src/<name>.blend, ignored by Godot). The model is the SHELL of the building in the game's own frame:
origin at the building centre on the ground, +Y up, the door in the -Z (front) wall, walls at x = +-2.4 and z = +-2.35 (0.22 thick, split into a siding
outside half and a plaster inside half), plinth 0.16 m, wall height 2.8. The game keeps its invisible collision boxes and its interior furniture; this replaces the
old procedural walls and roof (scripts/art/quarry_art.gd, `_office`). Material names are swapped for the project's own materials at load
(scripts/art/building_models.gd).
"""
import bpy, math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "tool_models"))
import qd_blender as Q
from qd_blender import empty
from tm import TM

OUT = os.path.join(Q.REPO, "assets", "buildings")
SRC = os.path.join(OUT, "src")

Q.MATERIALS.update({
    "Siding":   (None, (0.80, 0.78, 0.70), 0.95, 0.0, {}),
    "Plaster":  (None, (0.85, 0.82, 0.72), 1.0, 0.0, {}),
    "Trim":     (None, (0.86, 0.84, 0.76), 0.9, 0.0, {}),
    "Concrete": (None, (0.55, 0.55, 0.53), 1.0, 0.0, {}),
    "Roof":     (None, (0.62, 0.20, 0.14), 0.8, 0.2, {}),
    "Roof2":    (None, (0.45, 0.47, 0.48), 0.8, 0.2, {}),
    "DarkWood": (None, (0.30, 0.20, 0.12), 1.0, 0.0, {}),
    "Green":    (None, (0.25, 0.5, 0.25), 1.0, 0.0, {}),
    "FlowerR":  (None, (0.85, 0.25, 0.2), 1.0, 0.0, {}),
    "FlowerY":  (None, (0.95, 0.8, 0.25), 1.0, 0.0, {}),
    "Lamp":     (None, (1.0, 0.86, 0.55), 0.5, 0.0, {"emit": 2.0}),
})

FLOOR = 0.16          # plinth / floor height
H = 2.8               # wall height
T = 0.26              # wall thickness (outer siding half + inner plaster half): inner faces at x = +-2.27, z = +-2.22, where the furniture and wall decor expect them


def wall_run(t, axis, fixed, a0, a1, y0, y1, openings, outer_mat="Siding", inner_mat="Plaster", outward=1.0):
    """A wall along `axis` ('x' or 'z') at coordinate `fixed` on the other axis, from a0 to a1, y0..y1, cut by openings [(centre, width, bottom, top), ...].
    Two slabs: the outer half in `outer_mat` (on the side `outward` points to), the inner half in `inner_mat`. Returns nothing."""
    ops = sorted(openings, key=lambda o: o[0])
    # (the two slabs each take half of T)
    spans = []                                     # full-height spans between openings
    cur = a0
    for (c, w, b, tp) in ops:
        spans.append((cur, c - w / 2, y0, y1))
        cur = c + w / 2
    spans.append((cur, a1, y0, y1))
    pieces = [s for s in spans if s[1] - s[0] > 0.001]
    for (c, w, b, tp) in ops:                      # the wall below and above each opening
        if b - y0 > 0.001:
            pieces.append((c - w / 2, c + w / 2, y0, b))
        if y1 - tp > 0.001:
            pieces.append((c - w / 2, c + w / 2, tp, y1))
    half = T / 2
    for (p0, p1, ya, yb) in pieces:
        for k, mat in ((0, outer_mat), (1, inner_mat)):
            off = fixed + outward * (half / 2 + 0.0) * (1 if k == 0 else -1) * 1.0
            off = fixed + outward * (T / 4) * (1 if k == 0 else -1)
            ctr = (p0 + p1) / 2
            ln = p1 - p0
            cy = (ya + yb) / 2
            if axis == 'z':      # wall runs along Z at x = off
                t.box((off, cy, ctr), (T / 2, yb - ya, ln), mat)
            else:                # wall runs along X at z = off
                t.box((ctr, cy, off), (ln, yb - ya, T / 2), mat)


def window(t, axis, fixed, centre, w, h, bottom, outward):
    """Frame, sill, glass and muntins for an opening on a wall (same convention as wall_run)."""
    cy = bottom + h / 2
    d = T + 0.06
    fb = 0.06
    def bar(a, ya, sa, sy):
        if axis == 'z':
            t.box((fixed, ya, a), (d, sy, sa), "Trim")
        else:
            t.box((a, ya, fixed), (sa, sy, d), "Trim")
    bar(centre - w / 2 + fb / 2, cy, fb, h)               # jambs
    bar(centre + w / 2 - fb / 2, cy, fb, h)
    bar(centre, bottom + fb / 2, w, fb)                   # head / sill bars
    bar(centre, bottom + h - fb / 2, w, fb)
    # sill sticking out on the outside
    if axis == 'z':
        t.box((fixed + outward * (T / 2 + 0.07), bottom - 0.03, centre), (0.18, 0.05, w + 0.16), "Trim")
        t.box((fixed, cy, centre), (0.03, h - 0.1, w - 0.1), "Glass")
        t.box((fixed, cy, centre), (0.05, h - 0.1, 0.03), "Trim")
        t.box((fixed, cy, centre), (0.05, 0.03, w - 0.1), "Trim")
    else:
        t.box((centre, bottom - 0.03, fixed + outward * (T / 2 + 0.07)), (w + 0.16, 0.05, 0.18), "Trim")
        t.box((centre, cy, fixed), (w - 0.1, h - 0.1, 0.03), "Glass")
        t.box((centre, cy, fixed), (0.03, h - 0.1, 0.05), "Trim")
        t.box((centre, cy, fixed), (w - 0.1, 0.03, 0.05), "Trim")


def flower_box(t, x, z, w):
    t.box((x, 0.80, z), (w, 0.16, 0.22), "DarkWood")
    n = int(w / 0.18)
    for k in range(n):
        xx = x - w / 2 + 0.09 + k * (w - 0.18) / max(1, n - 1)
        t.box((xx, 0.95, z), (0.14, 0.16, 0.14), "Green")
        t.box((xx, 1.05, z), (0.07, 0.07, 0.07), "FlowerR" if k % 2 == 0 else "FlowerY")


def office(root):
    t = TM("Shell", root, holder=True)
    # plinth: a concrete slab, top flush with the floor, 0.11 m proud of the walls
    t.box((0, FLOOR / 2, 0), (5.24, FLOOR, 5.24), "Concrete")
    # --- walls
    side_ops = {-1: [(-0.35, 1.1, 0.95, 2.25), (1.55, 1.1, 0.95, 2.25)], 1: [(-1.45, 1.1, 0.95, 2.25), (0.45, 1.1, 0.95, 2.25)]}
    for sx in (-1, 1):
        wall_run(t, 'z', sx * 2.4, -2.46, 2.46, FLOOR, H, side_ops[sx], outward=float(sx))
        for (c, w, b, tp) in side_ops[sx]:
            window(t, 'z', sx * 2.4, c, w, tp - b, b, float(sx))
    wall_run(t, 'x', 2.35, -2.51, 2.51, FLOOR, H, [(1.4, 0.8, 1.2, 2.2)], outward=1.0)                    # back wall, a small window high over the shelves
    window(t, 'x', 2.35, 1.4, 0.8, 1.0, 1.2, 1.0)
    front_ops = [(-1.6, 0.9, 1.0, 2.1), (1.6, 0.9, 1.0, 2.1), (0.0, 1.4, FLOOR, 2.25)]                   # a window each side of the door, the doorway itself (header above it)
    wall_run(t, 'x', -2.35, -2.51, 2.51, FLOOR, H, front_ops, outward=-1.0)
    window(t, 'x', -2.35, -1.6, 0.9, 1.1, 1.0, -1.0)
    window(t, 'x', -2.35, 1.6, 0.9, 1.1, 1.0, -1.0)
    # door frame: jambs, a header and a threshold
    for sx in (-1, 1):
        t.box((sx * 0.74, 1.2, -2.35), (0.1, 2.1, T + 0.06), "Trim")
    t.box((0, 2.28, -2.35), (1.58, 0.1, T + 0.06), "Trim")
    t.box((0, FLOOR + 0.01, -2.35), (1.4, 0.04, T + 0.02), "DarkWood")
    # corner boards
    for sx in (-1, 1):
        for sz in (-1, 1):
            t.box((sx * 2.53, FLOOR + H / 2, sz * 2.47), (0.1, H, 0.1), "Trim")
    # vertical battens on the outside (skipping the openings)
    def clear(axis, pos, ops):
        return all(abs(pos - o[0]) > o[1] / 2 + 0.08 for o in ops)
    for k in range(-5, 6):
        z = k * 0.45
        for sx in (-1, 1):
            if clear('z', z, side_ops[sx]):
                t.box((sx * 2.525, FLOOR + H / 2, z), (0.03, H, 0.07), "Trim")
        xx = k * 0.45
        if abs(xx) < 2.3 and clear('x', xx, front_ops):
            t.box((xx, FLOOR + H / 2, -2.495), (0.07, H, 0.03), "Trim")
    # --- gable roof, ridge along X: two sheets with generous eaves (the front one shelters the porch), gables in siding, fascia and ridge cap
    D, W, RISE, TH = 6.2, 5.9, 1.1, 0.10
    sheet = [(-D / 2, 0.0), (0.0, RISE), (D / 2, 0.0), (D / 2, TH), (0.0, RISE + TH), (-D / 2, TH)]
    t.prism(sheet, W, (0, H, 0), "Roof")
    zb = 2.51
    under = lambda z: RISE * (1.0 - abs(z) / (D / 2))
    gable = [(-zb, 0.0), (zb, 0.0), (zb, under(zb) + 0.02), (0.0, RISE + 0.02), (-zb, under(zb) + 0.02)]
    for sx in (-1, 1):
        t.prism(gable, T, (0, H, 0), "Siding", x=sx * 2.4)
        t.box((sx * 2.52, H + 0.62, 0), (0.05, 0.34, 0.5), "Trim")                         # a louvred attic vent in each gable
        for i in range(3):
            t.box((sx * 2.545, H + 0.52 + i * 0.1, 0), (0.02, 0.025, 0.42), "DarkWood")
    for sz in (-1, 1):
        t.box((0, H - 0.01, sz * (D / 2 - 0.02)), (W, 0.18, 0.05), "Trim")                  # fascia
        t.box((0, H + 0.04, sz * (D / 2 + 0.04)), (W, 0.07, 0.07), "Concrete")               # gutter
    slope = math.atan2(RISE, D / 2)
    for sx in (-1, 1):
        for sz in (-1, 1):                                                                   # rake boards up the gable edges
            mid_z = sz * D / 4
            ln = math.hypot(D / 2, RISE)
            t.bar((sx * (W / 2 - 0.02), H + 0.0, sz * (D / 2 - 0.02)), (sx * (W / 2 - 0.02), H + RISE - 0.04, 0.0), 0.05, 0.14, "Trim", up=(1, 0, 0))
    t.box((0, H + RISE + TH, 0), (W + 0.06, 0.08, 0.26), "Trim")                             # ridge cap
    t.cyl((1.7, H + 0.75, 1.3), 0.11, 0.11, 0.8, "Roof2", seg=8)                              # a stovepipe (stays below the ridge)
    t.cyl((1.7, H + 1.15, 1.3), 0.16, 0.14, 0.05, "Roof2", seg=8)
    # ceiling and beams inside
    t.box((0, H - 0.03, 0), (4.56, 0.06, 4.56), "Plaster")
    for z in (-1.3, 0.0, 1.3):
        t.box((0, H - 0.14, z), (4.5, 0.14, 0.12), "DarkWood")
    t.cyl((0, H - 0.3, 0.3), 0.008, 0.008, 0.3, "DarkWood", seg=4)                          # a small pendant lamp over the middle of the room, high enough to walk under
    t.cyl((0, H - 0.5, 0.3), 0.05, 0.13, 0.12, "Yellow", seg=8)
    t.box((0, H - 0.57, 0.3), (0.08, 0.03, 0.08), "Lamp")
    # baseboards round the inside
    for sx in (-1, 1):
        t.box((sx * 2.28, FLOOR + 0.06, 0), (0.03, 0.12, 4.5), "DarkWood")
    t.box((0, FLOOR + 0.06, 2.24), (4.5, 0.12, 0.03), "DarkWood")
    # porch: two posts and a beam under the front eave, a wall lamp, flower boxes under the front windows
    for sx in (-1, 1):
        t.box((sx * 1.55, FLOOR + 1.3, -2.95), (0.13, 2.6, 0.13), "DarkWood")
        t.bar((sx * 1.55, 2.0, -2.95), (sx * 1.55, 2.75, -2.55), 0.07, 0.07, "DarkWood", up=(1, 0, 0))     # knee brace
    t.box((0, 2.72, -2.95), (3.4, 0.2, 0.15), "DarkWood")
    flower_box(t, -1.6, -2.62, 1.0)
    flower_box(t, 1.6, -2.62, 1.0)
    t.finish()



def sell_kiosk(root):
    """The Quick Sell Station: an open-fronted stall with a counter, a weighing scale, a sign board and a shed roof, facing -Z. 2.8 x 2.0 footprint, 2.8 m high."""
    t = TM("Shell", root, holder=True)
    t.box((0, 0.05, 0), (3.0, 0.1, 2.3), "Concrete")                                    # slab
    # counter along the front, with a deeper top and a toe board
    t.box((0, 0.55, -0.55), (2.5, 1.0, 0.5), "DarkWood")
    t.box((0, 1.06, -0.58), (2.7, 0.07, 0.72), "Wood")
    for k in range(5):
        t.box((-1.0 + k * 0.5, 0.55, -0.81), (0.04, 0.9, 0.02), "Wood")                  # front planks
    # back wall with a window, side walls half height
    t.box((0, 1.25, 0.85), (2.6, 2.3, 0.12), "Siding")
    t.box((0, 1.65, 0.78), (1.0, 0.7, 0.04), "Glass")
    for sx in (-1, 1):
        t.box((sx * 1.24, 0.85, 0.2), (0.1, 1.5, 1.4), "Siding")
        t.box((sx * 1.3, 1.35, -0.7), (0.14, 2.5, 0.14), "DarkWood")                     # front posts
        t.box((sx * 1.3, 1.35, 0.9), (0.14, 2.5, 0.14), "DarkWood")
    # roof: a shed roof, high at the back, low and overhanging at the front
    t.hexa([(-1.6, 2.5, -1.2), (1.6, 2.5, -1.2), (1.6, 2.72, 1.1), (-1.6, 2.72, 1.1),
            (-1.6, 2.6, -1.2), (1.6, 2.6, -1.2), (1.6, 2.82, 1.1), (-1.6, 2.82, 1.1)], "Roof")
    t.box((0, 2.42, -0.72), (2.8, 0.2, 0.12), "DarkWood")                                # the beam the sign hangs from
    t.box((0, 2.15, -0.76), (2.3, 0.5, 0.06), "Yellow")                                  # the sign board (the game writes SELL MATERIALS on it)
    t.box((0, 2.15, -0.79), (2.34, 0.54, 0.02), "DarkWood")
    # the scale and its readout, a till and a ledger on the counter
    t.box((-0.7, 1.12, -0.6), (0.7, 0.06, 0.5), "Steel")
    t.cyl((-0.7, 1.18, -0.44), 0.16, 0.16, 0.06, "Bright", seg=10, axis='z')
    t.box((-0.7, 1.32, -0.34), (0.1, 0.2, 0.1), "Steel")
    t.box((0.55, 1.2, -0.6), (0.5, 0.22, 0.34), "Steel")                                 # a cash box
    t.box((0.55, 1.33, -0.6), (0.34, 0.04, 0.2), "Lamp")                                 # its glowing display
    t.box((1.0, 1.12, -0.5), (0.3, 0.05, 0.4), "Paper")                                  # a ledger
    # beside it: crates and a barrel, a hazard bollard each side
    t.box((-1.75, 0.3, -0.1), (0.6, 0.6, 0.6), "Wood")
    t.box((-1.75, 0.75, -0.1), (0.5, 0.3, 0.5), "Wood")
    t.cyl((1.75, 0.45, 0.0), 0.3, 0.3, 0.9, "Steel", seg=10)
    t.cyl((1.75, 0.92, 0.0), 0.3, 0.3, 0.04, "Rubber", seg=10)
    for sx in (-1, 1):
        t.cyl((sx * 1.55, 0.45, -1.15), 0.07, 0.07, 0.8, "Yellow", seg=6)
    t.finish()

def build(name, fn, glb):
    Q.reset()
    root = empty("QD_" + name, size=0.2)
    fn(root)
    os.makedirs(SRC, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, name.lower() + ".blend"))
    path = os.path.join(OUT, glb)
    Q.export_glb(path)
    faces = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
    print("BUILDING", name, os.path.getsize(path), "bytes", faces, "faces")


if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not only or "office" in only:
        build("Office", office, "BLD_QD_Office.glb")
    if not only or "sellkiosk" in only:
        build("SellKiosk", sell_kiosk, "BLD_QD_SellKiosk.glb")
    print("BUILD_OK")
