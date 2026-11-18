"""QUARRY DAYS - the machinery garage, modelled in Blender (5.x, headless):

    blender -b --factory-startup -P tools/building_models/build_garage.py

Writes assets/buildings/BLD_QD_Garage.glb (+ src/garage.blend). Model space: origin at the garage's centre on the ground (x = (x0+x1)/2, z = 18.65 in the game's
frame), 19.2 m wide (x -9.6..9.6), 7.5 m deep (z -3.75..3.75). The FRONT (-Z) is open for the whole width: machines are driven in and parked left to right, so
nothing solid stands in the row; it carries a steel portal (header beam and four columns) with a rolled-up sectional door hood over each of the three bays. The BACK
wall (+Z) has the 5.4 m x 3.7 m service doorway (centre x = -4.4) the delivery logic uses, with a framed rolled-up door above it. Roof: one slope, underside 5.0 m at
the front falling to 4.6 m at the back, on steel rafters. The roof sheet is its own holder, "Roof", so the game can hide it while a machine is driven inside.
The floor is NOT in the model (the game lays the concrete slab so the machines' ground-follow keeps working). Colliders stay the game's (scripts/art/quarry_art.gd).
"""
import bpy, math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "tool_models"))
sys.path.insert(0, HERE)
import qd_blender as Q
from qd_blender import empty
from tm import TM
import build_buildings as BB

Q.MATERIALS.update({
    "SteelGreen":  (None, (0.22, 0.36, 0.30), 0.8, 0.2, {}),
    "Paint":       (None, (0.90, 0.78, 0.20), 0.9, 0.0, {}),
    "PaintOrange": (None, (0.85, 0.45, 0.12), 0.8, 0.0, {}),
    "PaintRed":    (None, (0.62, 0.14, 0.10), 0.8, 0.0, {}),
})

W2, D2 = 13.0, 3.75                       # 26 m wide: room for five machines in the row (it used to be 19.2 m and three)
DOOR_C, DOOR_W, DOOR_H = -5.3, 5.4, 3.7
UNDER_F, UNDER_B = 5.0, 4.6               # roof underside at the front and the back


def under(z):
    return UNDER_F + (UNDER_B - UNDER_F) * (z + D2) / (2 * D2)


def ibeam(t, a, b, w=0.2, h=0.3, mat="SteelGreen"):
    """An I-section beam from a to b (godot coords) along X or Z: two flanges and a web."""
    ax = 'x' if abs(a[0] - b[0]) > abs(a[2] - b[2]) else 'z'
    cx, cy, cz = [(a[i] + b[i]) / 2 for i in range(3)]
    L = abs(a[0] - b[0]) if ax == 'x' else abs(a[2] - b[2])
    sx, sz = (L, w) if ax == 'x' else (w, L)
    t.box((cx, cy + h / 2 - 0.02, cz), (sx, 0.04, sz), mat)
    t.box((cx, cy - h / 2 + 0.02, cz), (sx, 0.04, sz), mat)
    t.box((cx, cy, cz), ((L if ax == 'x' else 0.04), h - 0.06, (0.04 if ax == 'x' else L)), mat)


def garage(root):
    t = TM("Body", root, holder=True)
    T = 0.2
    # ---- concrete plinth band round the base (inside and out), under the corrugated walls
    for sx in (-1, 1):
        t.box((sx * (W2 + 0.02), 0.4, 0), (T + 0.1, 0.8, 2 * D2 + 0.1), "Concrete")
    # ---- side walls: corrugated sheet up to the roof line, with three clerestory windows each
    prof = lambda z0, z1: [(z0, 0.8), (z1, 0.8), (z1, under(z1) + 0.02), (z0, under(z0) + 0.02)]
    wins = [-2.2, 0.0, 2.2]
    for sx in (-1, 1):
        zs = [-D2] + [w + s * 0.7 for w in wins for s in (-1, 1)] + [D2]
        for i in range(0, len(zs), 2):
            t.prism(prof(zs[i], zs[i + 1]), T, (0, 0, 0), "Corrugated", x=sx * W2)
        for w in wins:                                                          # the window under each gap, glass between steel frames
            yb, yt = 3.0, 4.0
            t.prism([(w - 0.7, yb), (w + 0.7, yb), (w + 0.7, yt), (w - 0.7, yt)], T, (0, 0, 0), "Corrugated", x=sx * W2) if False else None
            t.box((sx * W2, (yb + yt) / 2, w), (0.06, yt - yb - 0.1, 1.3), "Glass")
            for zz in (-0.7, 0.0, 0.7):
                t.box((sx * W2, (yb + yt) / 2, w + zz), (0.1, yt - yb, 0.06), "SteelGreen")
            for yy in (yb, yt):
                t.box((sx * W2, yy, w), (0.12, 0.06, 1.46), "SteelGreen")
            # the wall below and above the window opening
            t.box((sx * W2, (0.8 + yb) / 2, w), (T, yb - 0.8, 1.4), "Corrugated")
            yt2 = under(w) + 0.02
            if yt2 - yt > 0.01:
                t.box((sx * W2, (yt + yt2) / 2, w), (T, yt2 - yt, 1.4), "Corrugated")
    # ---- back wall with the service doorway
    zb = D2
    segs = [(-W2, DOOR_C - DOOR_W / 2), (DOOR_C + DOOR_W / 2, W2)]
    for (xa, xb) in segs:
        t.box(((xa + xb) / 2, 0.4, zb), (xb - xa, 0.8, T + 0.1), "Concrete")
        t.box(((xa + xb) / 2, (0.8 + under(zb)) / 2, zb), (xb - xa, under(zb) - 0.8 + 0.02, T), "Corrugated")
    t.box((DOOR_C, (DOOR_H + under(zb)) / 2 + 0.0, zb), (DOOR_W, under(zb) - DOOR_H + 0.02, T), "Corrugated")      # the wall over the doorway
    for s in (-1, 1):                                                                           # steel jambs
        t.box((DOOR_C + s * (DOOR_W / 2 + 0.12), DOOR_H / 2, zb - 0.02), (0.24, DOOR_H, T + 0.1), "SteelGreen")
    t.box((DOOR_C, DOOR_H + 0.12, zb - 0.02), (DOOR_W + 0.5, 0.24, T + 0.1), "SteelGreen")      # the header
    t.box((DOOR_C, DOOR_H - 0.04, zb - 0.16), (DOOR_W, 0.12, 0.04), "Hazard")                   # hazard edge on the lintel
    # the rolled-up door: a drum in a hood over the doorway inside
    t.box((DOOR_C, DOOR_H + 0.45, zb - 0.45), (DOOR_W + 0.2, 0.55, 0.55), "SteelGreen")
    t.cyl((DOOR_C, DOOR_H + 0.4, zb - 0.45), 0.2, 0.2, DOOR_W - 0.1, "Corrugated", seg=10, axis='x')
    for s in (-1, 1):
        t.box((DOOR_C + s * (DOOR_W / 2 - 0.02), DOOR_H / 2, zb - 0.28), (0.08, DOOR_H, 0.1), "Steel")     # door guides
    # ---- the open front: a portal frame. Four columns on concrete footings, a header beam across the full width, rolled-door hoods over the three bays
    NB = 5                                                                                      # five bays
    xs = [-W2 + k * (2 * W2 / NB) for k in range(NB + 1)]
    beam_top = UNDER_F
    for x in xs:
        t.box((x, 0.12, -D2 + 0.05), (0.7, 0.24, 0.7), "Concrete")                                # footing
        t.box((x, (beam_top - 0.5) / 2 + 0.2, -D2 + 0.05), (0.28, beam_top - 0.5 - 0.0, 0.28), "SteelGreen")
        t.box((x, 0.26, -D2 + 0.05), (0.44, 0.04, 0.44), "Steel")                                 # base plate
        for dx in (-0.15, 0.15):
            for dz in (-0.15, 0.15):
                t.cyl((x + dx, 0.3, -D2 + 0.05 + dz), 0.025, 0.025, 0.06, "Bright", seg=6)
        t.box((x, 0.5, -D2 - 0.12), (0.3, 1.0, 0.04), "Hazard")                                    # hazard wrap on the lower metre
    ibeam(t, (-W2 - 0.2, beam_top - 0.25, -D2 + 0.05), (W2 + 0.2, beam_top - 0.25, -D2 + 0.05), w=0.3, h=0.5)
    for k in range(NB):
        cx = (xs[k] + xs[k + 1]) / 2
        bw = xs[k + 1] - xs[k] - 0.5
        t.box((cx, beam_top - 0.62, -D2 - 0.1), (bw, 0.32, 0.36), "SteelGreen")                    # the door hood
        t.cyl((cx, beam_top - 0.62, -D2 - 0.1), 0.15, 0.15, bw - 0.1, "Corrugated", seg=10, axis='x')
        t.box((cx, beam_top - 0.83, -D2 - 0.3), (bw, 0.06, 0.04), "Hazard")                        # hazard edge of the hood
        for s in (-1, 1):
            t.box((cx + s * (bw / 2 + 0.02), 2.2, -D2 - 0.12), (0.06, 4.0, 0.08), "Steel")        # door guide rails
    t.box((0, beam_top - 0.02, -D2 - 0.1), (2 * W2 + 0.4, 0.06, 0.04), "Hazard")                   # the header's stripe under the roof edge
    # ---- structure under the roof: steel rafters every 3.2 m front to back, purlins along X
    for x in [-12.0 + k * 3.0 for k in range(9)]:
        za, zb2 = -D2 + 0.1, D2 - 0.1                                                          # a sloped I-beam: two flanges and a web following the roof line
        for dy, hh, ww in ((0.13, 0.04, 0.18), (-0.13, 0.04, 0.18), (0.0, 0.22, 0.04)):
            t.bar((x, under(za) - 0.17 + dy, za), (x, under(zb2) - 0.17 + dy, zb2), hh, ww, "SteelGreen", up=(0, 1, 0))
    for z in (-2.3, 0.0, 2.3):
        ibeam(t, (-W2, under(z) - 0.05, z), (W2, under(z) - 0.05, z), w=0.1, h=0.16, mat="Steel")
    # monorail with a chain hoist over the parking row
    t.box((0, 4.2, 0.2), (2 * W2 - 1.0, 0.18, 0.2), "Steel") if False else ibeam(t, (-W2 + 0.6, 4.3, -0.4), (W2 - 0.6, 4.3, -0.4), w=0.18, h=0.24, mat="PaintOrange")
    t.box((-3.0, 4.0, -0.4), (0.5, 0.34, 0.4), "Paint")
    t.cyl((-3.0, 3.76, -0.4), 0.025, 0.025, 0.4, "Steel", seg=6)
    t.box((-3.0, 3.55, -0.4), (0.12, 0.1, 0.06), "Steel")
    # strip lights hanging from the rafters
    for lx in (-10.0, -6.0, -2.0, 2.0, 6.0, 10.0):
        for lz in (-1.4, 1.4):
            t.box((lx, under(lz) - 0.4, lz), (1.2, 0.06, 0.18), "Lamp")
            t.cyl((lx - 0.4, under(lz) - 0.3, lz), 0.012, 0.012, 0.2, "Steel", seg=4)
            t.cyl((lx + 0.4, under(lz) - 0.3, lz), 0.012, 0.012, 0.2, "Steel", seg=4)
    # ---- work area on the west wall: a long workbench with a vise, a tool chest, and a pegboard of hung tools
    bx0 = -W2 + 0.125
    t.box((bx0 + 0.45, 0.93, 1.55), (0.75, 0.07, 3.6), "Wood")
    for dz in (-1.7, 1.7):
        for dx in (0.1, 0.8):
            t.box((bx0 + dx, 0.45, 1.55 + dz), (0.07, 0.9, 0.07), "DarkWood")
    t.box((bx0 + 0.45, 0.3, 1.55), (0.68, 0.05, 3.4), "Wood")                                       # lower shelf
    t.box((bx0 + 0.1, 0.5, 1.55), (0.04, 0.4, 3.4), "DarkWood")
    t.box((bx0 + 0.45, 1.06, 0.2), (0.3, 0.18, 0.1), "Steel")                                       # vise
    t.box((bx0 + 0.45, 1.16, 0.2), (0.12, 0.03, 0.3), "Steel")
    t.box((bx0 + 0.45, 1.12, 2.4), (0.5, 0.22, 0.3), "Red")                                         # a toolbox
    t.box((bx0 + 0.45, 1.25, 2.4), (0.4, 0.03, 0.06), "Steel")
    t.box((bx0 + 0.07, 1.65, 1.55), (0.04, 1.0, 3.4), "DarkWood")                                  # pegboard
    for k in range(9):
        z = 0.0 + k * 0.38
        kind = k % 3
        if kind == 0:
            t.box((bx0 + 0.12, 1.65, z), (0.03, 0.5, 0.05), "Steel")                              # a wrench
            t.box((bx0 + 0.12, 1.92, z), (0.04, 0.08, 0.12), "Steel")
        elif kind == 1:
            t.box((bx0 + 0.12, 1.7, z), (0.03, 0.4, 0.05), "Wood")                                # a hammer
            t.box((bx0 + 0.13, 1.92, z), (0.05, 0.1, 0.16), "Steel")
        else:
            t.box((bx0 + 0.12, 1.55, z), (0.03, 0.3, 0.14), "Yellow")                             # a saw
    t.box((bx0 + 0.4, 0.5, -0.5), (0.6, 1.0, 0.8), "Red")                                           # rolling tool chest on the west wall in front of the doorway lane end
    for k in range(4):
        t.box((bx0 + 0.71, 0.25 + k * 0.22, -0.5), (0.02, 0.17, 0.7), "Steel")
    # ---- storage along the back wall, east of the doorway: three steel rack bays with boxes, a drum cage and the electrical panel
    for rx in (-0.5, 2.3, 5.1, 8.9):
        for s in (-1, 1):
            for dz in (-0.25, 0.25):
                t.box((rx + s * 1.1, 1.0, D2 - 0.45 + dz), (0.06, 2.0, 0.06), "SteelGreen")           # uprights
        for y in (0.15, 0.85, 1.55):
            t.box((rx, y, D2 - 0.45), (2.3, 0.05, 0.62), "Steel")                                   # shelves
        for y in (0.15, 0.85, 1.55):
            for k in range(3):
                t.box((rx - 0.7 + k * 0.7, y + 0.2, D2 - 0.45), (0.5, 0.34, 0.45), "Wood" if (k + int(y * 10)) % 2 else "Paper")
    t.box((6.9, 1.0, D2 - 0.18), (0.8, 1.6, 0.25), "Steel")                                          # the electrical cabinet
    t.box((6.9, 1.2, D2 - 0.3), (0.06, 0.5, 0.02), "Lamp")
    for k in range(3):                                                                              # oil drums by the east wall (kept clear of the parking row)
        t.cyl((12.1 - 0.6 * (k % 2), 0.45, 0.35 + 0.62 * k), 0.29, 0.29, 0.9, "PaintRed" if k != 1 else "SteelGreen", seg=8)
    # ---- floor marking: painted bay lines and a keep-clear stripe along the doorway
    for x in xs[1:-1]:
        t.box((x, 0.081, 0.0), (0.12, 0.008, 5.6), "Paint")
    t.box((DOOR_C, 0.081, 2.6), (DOOR_W, 0.008, 0.12), "Hazard")
    t.finish()
    # ---- the roof sheet: its own holder so the game can hide it while a machine is driven inside
    rf = TM("Roof", root, loc=(0, 5.0, 0), holder=True)
    zf, zk = -D2 - 0.6, D2 + 0.3
    sheet = [(zf, under(zf)), (zk, under(zk)), (zk, under(zk) + 0.12), (zf, under(zf) + 0.12)]      # a 12 cm sheet whose underside is the roof line
    rf.prism(sheet, 2 * W2 + 0.7, (0, 0, 0), "Roof", x=0.0)
    rf.finish()


if __name__ == "__main__":
    BB.build("Garage", garage, "BLD_QD_Garage.glb")
    print("BUILD_OK")
