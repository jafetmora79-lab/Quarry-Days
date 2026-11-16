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
    "Industrial": (None, (0.55, 0.58, 0.60), 0.9, 0.1, {}),
    "Corrugated": (None, (0.52, 0.54, 0.53), 0.8, 0.3, {}),
    "Chimney":  (None, (0.50, 0.28, 0.22), 1.0, 0.0, {}),
    "Fabric":   (None, (0.30, 0.44, 0.46), 1.0, 0.0, {}),
    "FabricRed": (None, (0.62, 0.28, 0.22), 1.0, 0.0, {}),
    "Tv":       (None, (0.08, 0.10, 0.14), 0.3, 0.0, {}),
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

# ----------------------------------------------------------------------------------------------------------------------------------------------
# The other yard buildings: Grandpa's house (with a living-room wing), the workshop and the storage shed. Same frame as the office.
# ----------------------------------------------------------------------------------------------------------------------------------------------

def gable_roof(t, cx, W, D, RISE, TH, east_x, west_x, gable_mat="Siding", vents=True, roof_mat="Roof"):
    """One long gable roof, ridge along X, centred on x=cx and W long, D deep. Gable ends in `gable_mat` standing in the end walls at east_x / west_x."""
    sheet = [(-D / 2, 0.0), (0.0, RISE), (D / 2, 0.0), (D / 2, TH), (0.0, RISE + TH), (-D / 2, TH)]
    t.prism(sheet, W, (0, H, 0), roof_mat, x=cx)
    zb = 2.51
    under = lambda z: RISE * (1.0 - abs(z) / (D / 2))
    gable = [(-zb, 0.0), (zb, 0.0), (zb, under(zb) + 0.02), (0.0, RISE + 0.02), (-zb, under(zb) + 0.02)]
    for gx, sx in ((east_x, 1), (west_x, -1)):
        t.prism(gable, T, (0, H, 0), gable_mat, x=gx)
        if vents:
            t.box((gx + sx * 0.12, H + 0.62, 0), (0.05, 0.34, 0.5), "Trim")
            for i in range(3):
                t.box((gx + sx * 0.145, H + 0.52 + i * 0.1, 0), (0.02, 0.025, 0.42), "DarkWood")
    for sz in (-1, 1):
        t.box((cx, H - 0.01, sz * (D / 2 - 0.02)), (W, 0.18, 0.05), "Trim")                     # fascia
        t.box((cx, H + 0.04, sz * (D / 2 + 0.04)), (W, 0.07, 0.07), "Concrete")                  # gutter
    for ex in (east_x + 0.13, west_x - 0.13):
        for sz in (-1, 1):
            t.bar((ex, H + 0.0, sz * (D / 2 - 0.02)), (ex, H + RISE - 0.04, 0.0), 0.05, 0.14, "Trim", up=(1, 0, 0))   # rake boards
    t.box((cx, H + RISE + TH, 0), (W + 0.06, 0.08, 0.26), "Trim")                                # ridge cap


def door_frame(t, axis, fixed, centre, w, top, sign=1.0):
    """Jambs, a header and a threshold round a doorway of width w and height `top` (axis 'x' = in a wall running along X; 'z' = along Z)."""
    for sx in (-1, 1):
        if axis == 'x':
            t.box((centre + sx * (w / 2 + 0.04), (FLOOR + top) / 2, fixed), (0.1, top - FLOOR, T + 0.06), "Trim")
        else:
            t.box((fixed, (FLOOR + top) / 2, centre + sx * (w / 2 + 0.04)), (T + 0.06, top - FLOOR, 0.1), "Trim")
    if axis == 'x':
        t.box((centre, top + 0.04, fixed), (w + 0.18, 0.1, T + 0.06), "Trim")
        t.box((centre, FLOOR + 0.01, fixed), (w, 0.04, T + 0.02), "DarkWood")
    else:
        t.box((fixed, top + 0.04, centre), (T + 0.06, 0.1, w + 0.18), "Trim")
        t.box((fixed, FLOOR + 0.01, centre), (T + 0.02, 0.04, w), "DarkWood")


def corner_boards(t, x0, x1, z0=-2.47, z1=2.47):
    for x in (x0, x1):
        for z in (z0, z1):
            t.box((x, FLOOR + H / 2, z), (0.1, H, 0.1), "Trim")


def house(root):
    """Grandpa's house: the old one-room cabin (kitchen, bedroom, bathroom: the game furnishes it) plus a LIVING-ROOM WING to the west, joined through a wide
    doorway in the west wall. Main block as the office frame (walls x +-2.4, z +-2.35), the wing from x -2.4 to -5.8 with its own windows, one long gable roof
    over both, a chimney, a porch light bracket and flower boxes."""
    t = TM("Shell", root, holder=True)
    AX = -4.1                                                                      # wing centre
    t.box((0, FLOOR / 2, 0), (5.24, FLOOR, 5.24), "Concrete")
    t.box((-4.125, FLOOR / 2, 0), (3.7, FLOOR, 5.24), "Concrete")
    # main block: east wall with two windows, west wall with the wide doorway to the wing, back wall with a window over the bed, front wall with the door
    east = [(-1.45, 1.1, 0.95, 2.25), (0.45, 1.1, 0.95, 2.25)]
    wall_run(t, 'z', 2.4, -2.46, 2.46, FLOOR, H, east, outward=1.0)
    for (c, w, b, tp) in east:
        window(t, 'z', 2.4, c, w, tp - b, b, 1.0)
    wall_run(t, 'z', -2.4, -2.46, 2.46, FLOOR, H, [(-0.15, 1.0, FLOOR, 2.2)], outward=-1.0)
    door_frame(t, 'z', -2.4, -0.15, 1.0, 2.2)
    wall_run(t, 'x', 2.35, -2.51, 2.51, FLOOR, H, [(-0.4, 0.8, 1.2, 2.2)], outward=1.0)
    window(t, 'x', 2.35, -0.4, 0.8, 1.0, 1.2, 1.0)
    front = [(-1.6, 0.6, 1.5, 2.1), (1.6, 0.9, 1.0, 2.1), (0.0, 1.4, FLOOR, 2.25)]
    wall_run(t, 'x', -2.35, -2.51, 2.51, FLOOR, H, front, outward=-1.0)
    window(t, 'x', -2.35, -1.6, 0.6, 0.6, 1.5, -1.0)
    window(t, 'x', -2.35, 1.6, 0.9, 1.1, 1.0, -1.0)
    door_frame(t, 'x', -2.35, 0.0, 1.4, 2.25)
    # the wing
    wfront = [(-5.0, 1.0, 1.0, 2.1), (-3.2, 0.9, 1.0, 2.1)]
    wall_run(t, 'x', -2.35, -5.9, -2.49, FLOOR, H, wfront, outward=-1.0)
    for (c, w, b, tp) in wfront:
        window(t, 'x', -2.35, c, w, tp - b, b, -1.0)
    wall_run(t, 'x', 2.35, -5.9, -2.49, FLOOR, H, [(-4.1, 1.6, 1.0, 2.1)], outward=1.0)
    window(t, 'x', 2.35, -4.1, 1.6, 1.1, 1.0, 1.0)
    wwest = [(-1.1, 1.0, 0.95, 2.15), (1.1, 1.0, 0.95, 2.15)]
    wall_run(t, 'z', -5.8, -2.46, 2.46, FLOOR, H, wwest, outward=-1.0)
    for (c, w, b, tp) in wwest:
        window(t, 'z', -5.8, c, w, tp - b, b, -1.0)
    corner_boards(t, 2.53, -5.93)
    # battens on the outer faces (main block east and front, wing west and front)
    def clear(pos, ops):
        return all(abs(pos - o[0]) > o[1] / 2 + 0.08 for o in ops)
    for k in range(-5, 6):
        z = k * 0.45
        if clear(z, east):
            t.box((2.525, FLOOR + H / 2, z), (0.03, H, 0.07), "Trim")
        if clear(z, wwest):
            t.box((-5.925, FLOOR + H / 2, z), (0.03, H, 0.07), "Trim")
    for k in range(-12, 6):
        x = k * 0.45 - 0.2
        if -2.3 < x < 2.3 and clear(x, front):
            t.box((x, FLOOR + H / 2, -2.495), (0.07, H, 0.03), "Trim")
        if -5.7 < x < -2.6 and clear(x, wfront):
            t.box((x, FLOOR + H / 2, -2.495), (0.07, H, 0.03), "Trim")
    # one long gable roof over both parts (x from -6.0 to +2.95)
    gable_roof(t, -1.525, 8.95, 6.2, 1.1, 0.10, 2.4, -5.8)
    # a brick-coloured chimney through the main slope, a pendant lamp in each room, ceiling and beams
    t.box((3.3, 2.2, 0.0), (0.5, 4.1, 0.6), "Chimney")                                          # a brick stack against the east gable, outside the roof's overhang
    t.box((3.3, 4.28, 0.0), (0.62, 0.08, 0.72), "Concrete")
    t.box((3.3, 0.3, 0.0), (0.7, 0.3, 0.8), "Concrete")
    t.box((-4.1, FLOOR + 0.006, 0), (3.2, 0.012, 4.4), "Wood")                                  # the wing's floorboards
    t.box((0, H - 0.03, 0), (4.56, 0.06, 4.56), "Plaster")
    t.box((-4.1, H - 0.03, 0), (3.3, 0.06, 4.56), "Plaster")
    for z in (-1.3, 0.0, 1.3):
        t.box((0, H - 0.14, z), (4.5, 0.14, 0.12), "DarkWood")
        t.box((-4.1, H - 0.14, z), (3.3, 0.14, 0.12), "DarkWood")
    t.cyl((-4.1, H - 0.3, 0.4), 0.008, 0.008, 0.3, "DarkWood", seg=4)
    t.cyl((-4.1, H - 0.5, 0.4), 0.05, 0.13, 0.12, "Yellow", seg=8)
    t.box((-4.1, H - 0.57, 0.4), (0.08, 0.03, 0.08), "Lamp")
    # baseboards in the wing
    t.box((-5.67, FLOOR + 0.06, 0), (0.03, 0.12, 4.4), "DarkWood")
    t.box((-4.1, FLOOR + 0.06, 2.2), (3.2, 0.12, 0.03), "DarkWood")
    # porch: a lean-to over the front door, two posts and a beam, flower boxes under the windows
    for sx in (-1, 1):
        t.box((sx * 1.2, FLOOR + 1.3, -2.95), (0.13, 2.6, 0.13), "DarkWood")
        t.bar((sx * 1.2, 2.0, -2.95), (sx * 1.2, 2.75, -2.55), 0.07, 0.07, "DarkWood", up=(1, 0, 0))
    t.box((0, 2.72, -2.95), (2.8, 0.2, 0.15), "DarkWood")
    flower_box(t, 1.6, -2.62, 0.9)
    flower_box(t, -5.0, -2.62, 1.0)
    # ------------- the living room (wing interior)
    t.box((-4.1, FLOOR + 0.012, 0.9), (2.4, 0.024, 1.9), "FabricRed")                           # rug
    # sofa against the back wall, facing the room
    t.box((-4.1, 0.4, 1.8), (2.0, 0.34, 0.8), "Fabric")                                       # seat
    t.box((-4.1, 0.78, 2.13), (2.0, 0.5, 0.18), "Fabric")                                     # back
    for sx in (-1, 1):
        t.box((-4.1 + sx * 1.0, 0.55, 1.8), (0.16, 0.5, 0.8), "Fabric")                       # arms
    for sx in (-1, 1):
        t.box((-4.1 + sx * 0.5, 0.62, 1.78), (0.8, 0.12, 0.62), "FabricRed")                 # cushions
    t.box((-4.1, 0.2, 1.8), (1.9, 0.1, 0.7), "DarkWood")                                       # plinth
    # coffee table with a mug and a magazine
    t.box((-4.1, 0.36, 0.7), (1.0, 0.05, 0.55), "Wood")
    for sx in (-1, 1):
        for sz in (-1, 1):
            t.box((-4.1 + sx * 0.44, 0.17, 0.7 + sz * 0.22), (0.05, 0.34, 0.05), "DarkWood")
    t.cyl((-3.85, 0.44, 0.7), 0.05, 0.05, 0.1, "Bright", seg=8)
    t.box((-4.35, 0.39, 0.72), (0.3, 0.015, 0.22), "Paper")
    # television on a cabinet against the front wall (beside the window), and a loudspeaker either side
    t.box((-3.2, 0.3, -2.0), (1.3, 0.6, 0.4), "DarkWood")
    t.box((-3.2, 0.96, -2.05), (0.95, 0.58, 0.08), "Rubber")
    t.box((-3.2, 0.96, -2.0), (0.86, 0.5, 0.02), "Tv")
    t.box((-3.2, 0.64, -2.0), (0.4, 0.04, 0.2), "Rubber")
    # armchair near the west wall, angled toward the room
    t.box((-5.1, 0.3, -0.5), (0.75, 0.3, 0.75), "FabricRed")
    t.box((-5.4, 0.62, -0.5), (0.14, 0.55, 0.75), "FabricRed")
    for sz in (-1, 1):
        t.box((-5.1, 0.5, -0.5 + sz * 0.4), (0.75, 0.3, 0.1), "FabricRed")
    # bookshelf on the west wall, full of books
    t.box((-5.55, 0.9, 1.3), (0.3, 1.8, 1.1), "DarkWood")
    cols = ["FabricRed", "Fabric", "Yellow", "Paper", "Green"]
    for row in range(4):
        for k in range(7):
            t.box((-5.52, 0.35 + row * 0.42, 0.85 + k * 0.15), (0.18, 0.3 + (k % 3) * 0.03, 0.1), cols[(row + k) % 5])
    # floor lamp and a plant in the back corners, pictures on the back wall
    t.cyl((-2.95, 0.7, 2.0), 0.02, 0.02, 1.4, "Steel", seg=6)
    t.cyl((-2.95, 1.5, 2.0), 0.1, 0.2, 0.25, "Lamp", seg=8)
    t.cyl((-5.45, 0.2, 2.0), 0.18, 0.14, 0.4, "Roof", seg=8)
    t.box((-5.45, 0.65, 2.0), (0.3, 0.5, 0.3), "Green")
    for k, c in enumerate((-4.6, -3.6)):
        t.box((c, 1.7, 2.2), (0.6, 0.45, 0.03), "DarkWood")
        t.box((c, 1.7, 2.185), (0.52, 0.37, 0.02), "FlowerY" if k == 0 else "Green")
    t.finish()


def workshop(root):
    """The workshop (the tool shed, upgrades): industrial siding, a steel awning with hazard striping over the 1.4 m doorway, big side windows, a roof vent."""
    t = TM("Shell", root, holder=True)
    t.box((0, FLOOR / 2, 0), (5.24, FLOOR, 5.24), "Concrete")
    side_ops = [(-0.6, 1.0, 1.0, 2.2), (0.9, 1.0, 1.0, 2.2)]
    for sx in (-1, 1):
        wall_run(t, 'z', sx * 2.4, -2.46, 2.46, FLOOR, H, side_ops, outer_mat="Industrial", outward=float(sx))
        for (c, w, b, tp) in side_ops:
            window(t, 'z', sx * 2.4, c, w, tp - b, b, float(sx))
    wall_run(t, 'x', 2.35, -2.51, 2.51, FLOOR, H, [], outer_mat="Industrial", outward=1.0)
    wall_run(t, 'x', -2.35, -2.51, 2.51, FLOOR, H, [(0.0, 1.4, FLOOR, 2.25)], outer_mat="Industrial", outward=-1.0)
    door_frame(t, 'x', -2.35, 0.0, 1.4, 2.25)
    corner_boards(t, 2.53, -2.53)
    gable_roof(t, 0.0, 5.9, 6.2, 0.9, 0.10, 2.4, -2.4, gable_mat="Industrial", vents=False, roof_mat="Roof2")
    t.box((0, 2.42, -2.95), (2.4, 0.07, 0.8), "Steel")                                           # the awning over the door, under the eave
    t.box((0, 2.455, -3.33), (2.4, 0.09, 0.05), "Hazard")
    for sx in (-1, 1):
        t.bar((sx * 1.15, 2.0, -2.5), (sx * 1.15, 2.4, -3.2), 0.06, 0.06, "Steel", up=(1, 0, 0))
    t.cyl((1.7, H + 0.55, 1.2), 0.22, 0.22, 0.5, "Steel", seg=8)                                   # a roof vent
    t.cyl((1.7, H + 0.85, 1.2), 0.3, 0.05, 0.12, "Steel", seg=8)
    t.box((0, H - 0.03, 0), (4.56, 0.06, 4.56), "Plaster")
    for sx in (-1, 1):
        t.box((sx * 2.28, FLOOR + 0.06, 0), (0.03, 0.12, 4.5), "DarkWood")
    t.box((0, FLOOR + 0.06, 2.24), (4.5, 0.12, 0.03), "DarkWood")
    t.box((2.55, 0.5, -1.4), (0.3, 1.0, 0.8), "Steel")                                             # a gas bottle cage beside the door
    t.cyl((2.62, 0.45, -1.4), 0.12, 0.12, 0.8, "Red", seg=8)
    t.finish()


def storage_shed(root):
    """The storage shed: corrugated steel walls and roof, a roll-up shutter door (drum and guides) over the 1.4 m opening, high clerestory windows, loading bumpers."""
    t = TM("Shell", root, holder=True)
    t.box((0, FLOOR / 2, 0), (5.24, FLOOR, 5.24), "Concrete")
    hi = [(-0.8, 1.2, 2.0, 2.5), (0.8, 1.2, 2.0, 2.5)]
    for sx in (-1, 1):
        wall_run(t, 'z', sx * 2.4, -2.46, 2.46, FLOOR, H, hi, outer_mat="Corrugated", outward=float(sx))
        for (c, w, b, tp) in hi:
            window(t, 'z', sx * 2.4, c, w, tp - b, b, float(sx))
    wall_run(t, 'x', 2.35, -2.51, 2.51, FLOOR, H, [], outer_mat="Corrugated", outward=1.0)
    wall_run(t, 'x', -2.35, -2.51, 2.51, FLOOR, H, [(0.0, 1.4, FLOOR, 2.3)], outer_mat="Corrugated", outward=-1.0)
    corner_boards(t, 2.53, -2.53)
    gable_roof(t, 0.0, 5.9, 6.2, 0.7, 0.10, 2.4, -2.4, gable_mat="Corrugated", vents=False, roof_mat="Roof")
    t.box((0, 2.2, -2.45), (1.5, 0.5, 0.05), "Corrugated")                                       # the rolled-up shutter curtain above the opening
    for sx in (-1, 1):                                                                              # dock bumpers
        t.box((sx * 1.2, 0.3, -2.58), (0.18, 0.3, 0.1), "Rubber")
    t.box((0, H - 0.03, 0), (4.56, 0.06, 4.56), "Plaster")
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
    if not only or "house" in only:
        build("Home", house, "BLD_QD_Home.glb")
    if not only or "workshop" in only:
        build("Workshop", workshop, "BLD_QD_Workshop.glb")
    if not only or "shed" in only:
        build("Shed", storage_shed, "BLD_QD_Shed.glb")
    print("BUILD_OK")
