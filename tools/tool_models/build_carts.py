"""QUARRY DAYS - the reinforced wheelbarrow and the hand cart, modelled in Blender (5.x, headless), lightweight and flat shaded like the rest:

    blender -b --factory-startup -P tools/tool_models/build_carts.py

Writes assets/vehicles/VEH_QD_WheelbarrowHD.glb (heavy-duty steel barrow: bigger painted tray with a rolled rim and ribs, heavy frame, braced handles with rubber
grips, wide legs with foot plates, a fat bolted wheel with a fender) and assets/vehicles/VEH_QD_HandCart.glb (a two-wheeled plank cart: spoked wheels on an
axle, planked bed with side and end boards, frame rails, a pull bar out front, a prop leg behind).
Conventions (scripts/cart.gd): the model faces -Z (forward) with the origin on the ground; nodes named "Body" (everything that tips about the axle) and
"Wheel" (barrow) or "Wheel_L" / "Wheel_R" (hand cart), each an empty at its hinge. Godot space: +Y up, wheels in front (-Z), handles / prop leg behind (+Z).
"""
import bpy, math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import qd_blender as Q
from qd_blender import empty
from tm import TM

OUT = os.path.join(Q.REPO, "assets", "vehicles")
SRC = os.path.join(Q.REPO, "assets", "tools", "src")

Q.MATERIALS.update({
    "PaintOrange": (None, (0.80, 0.42, 0.12), 0.85, 0.0, {}),
})


def spokes(w, r, n, mat, w_t=0.035):
    """Wheel spokes in the wheel's own frame (axle along X)."""
    for k in range(n):
        a = 2 * math.pi * k / n
        w.bar((0, 0, 0), (0, math.cos(a) * r, math.sin(a) * r), w_t, 0.025, mat, up=(1, 0, 0))


def reinforced(root):
    AX = (0.0, 0.29, -0.80)                       # axle: the wheel's centre and the tipping hinge
    # ---- wheel: a fat tyre, a bolted steel rim, hub and tread lugs
    w = TM("Wheel", root, loc=AX, holder=True)
    cx, cy, cz = AX
    w.cyl((cx, cy, cz), 0.29, 0.29, 0.15, "Rubber", seg=12, axis='x')                  # tyre
    w.cyl((cx, cy, cz), 0.19, 0.19, 0.17, "Steel", seg=12, axis='x')                   # rim
    w.cyl((cx, cy, cz), 0.07, 0.07, 0.26, "Bright", seg=8, axis='x')                   # hub and axle ends
    for k in range(8):
        a = 2 * math.pi * k / 8
        w.box((cx + 0.09, cy + math.cos(a) * 0.15, cz + math.sin(a) * 0.15), (0.02, 0.035, 0.035), "Bright")    # rim bolts (right face)
        w.box((cx - 0.09, cy + math.cos(a) * 0.15, cz + math.sin(a) * 0.15), (0.02, 0.035, 0.035), "Bright")
        w.box((cx, cy + math.cos(a) * 0.295, cz + math.sin(a) * 0.295), (0.16, 0.05, 0.05), "Rubber")              # tread lugs
    w.finish()
    # ---- body: tray, frame, handles, legs, fender (everything that tips about the axle)
    b = TM("Body", root, loc=AX, holder=True)
    # tray: a tapered steel tub, wide at the back, narrow at the wheel, painted orange outside, dark inside
    b.hexa([(-0.27, 0.50, 0.58), (0.27, 0.50, 0.58), (0.20, 0.52, -0.52), (-0.20, 0.52, -0.52),
            (-0.42, 0.96, 0.64), (0.42, 0.96, 0.64), (0.31, 1.0, -0.62), (-0.31, 1.0, -0.62)], "PaintOrange")
    b.hexa([(-0.255, 0.53, 0.55), (0.255, 0.53, 0.55), (0.19, 0.55, -0.49), (-0.19, 0.55, -0.49),
            (-0.40, 0.95, 0.60), (0.40, 0.95, 0.60), (0.295, 0.99, -0.59), (-0.295, 0.99, -0.59)], "Steel")
    for (p, q) in [((-0.42, 0.97, 0.64), (0.42, 0.97, 0.64)), ((0.42, 0.97, 0.64), (0.31, 1.01, -0.62)), ((0.31, 1.01, -0.62), (-0.31, 1.01, -0.62)), ((-0.31, 1.01, -0.62), (-0.42, 0.97, 0.64))]:
        b.bar(p, q, 0.07, 0.07, "Steel")                                                # a thick rolled rim all round
    for sx in (-1, 1):
        for yy in (0.66, 0.82):
            t = (yy - 0.5) / 0.46
            xb = 0.27 + (0.42 - 0.27) * t
            xf = 0.20 + (0.31 - 0.20) * t
            b.bar((sx * (xb + 0.012), yy, 0.60), (sx * (xf + 0.012), yy, -0.55), 0.04, 0.05, "Steel")      # two ribs down each side
    for zz in (0.35, 0.0, -0.35):
        b.bar((-0.30, 0.50, zz), (0.30, 0.50, zz), 0.05, 0.05, "Steel")                 # under-tray cross ribs
    # frame: heavy rails under the tray from the fork to the handles
    for sx in (-1, 1):
        b.bar((sx * 0.30, 0.46, 0.55), (sx * 0.40, 0.93, 1.55), 0.06, 0.06, "Steel")                      # handle tube (rail and handle in one)
        b.bar((sx * 0.20, 0.50, -0.40), (sx * 0.12, 0.29, -0.80), 0.07, 0.06, "Steel")                    # fork to the axle
        b.bar((sx * 0.30, 0.46, 0.55), (sx * 0.20, 0.50, -0.40), 0.06, 0.06, "Steel")                     # rail along the tray
        b.box((sx * 0.40, 0.93, 1.40), (0.075, 0.075, 0.30), "Rubber")                                    # rubber grip
        b.bar((sx * 0.31, 0.54, 0.30), (sx * 0.38, 0.84, 1.08), 0.04, 0.04, "Steel")                      # brace from the tray to the handle
        b.bar((sx * 0.31, 0.50, 0.50), (sx * 0.33, 0.04, 0.84), 0.06, 0.05, "Steel")                      # leg
        b.box((sx * 0.33, 0.025, 0.86), (0.14, 0.05, 0.20), "Rubber")                                     # foot plate
        b.cyl((sx * 0.12, 0.29, -0.80), 0.045, 0.045, 0.06, "Bright", seg=6, axis='x')                    # axle bolt heads (outside the fork)
    b.bar((-0.34, 0.30, 0.68), (0.34, 0.30, 0.68), 0.045, 0.045, "Steel")                                 # leg cross brace
    b.bar((-0.20, 0.55, -0.50), (0.20, 0.55, -0.50), 0.06, 0.05, "Steel")                                 # front cross bar
    # fender over the wheel
    for k in range(5):
        a0 = math.radians(-70 + k * 35)
        a1 = math.radians(-70 + (k + 1) * 35)
        r = 0.36
        b.bar((0, 0.29 + math.cos(a0) * r, -0.80 + math.sin(a0) * r), (0, 0.29 + math.cos(a1) * r, -0.80 + math.sin(a1) * r), 0.22, 0.02, "PaintOrange", up=(1, 0, 0))
    for sx in (-1, 1):
        for zz in (0.3, -0.3):
            b.cyl((sx * 0.355, 0.72, zz), 0.02, 0.02, 0.03, "Bright", seg=6, axis='x')                    # rivets on the tray side
    b.box((0.0, 0.30, 0.70), (0.30, 0.04, 0.02), "Rust")                                                  # a rust streak
    b.finish()


def hand_cart(root):
    AX = (0.0, 0.32, 0.10)
    for sx, name in ((-1, "Wheel_L"), (1, "Wheel_R")):
        c = (sx * 0.50, AX[1], AX[2])
        w = TM(name, root, loc=c, holder=True)
        w.cyl(c, 0.32, 0.32, 0.07, "Rubber", seg=12, axis='x')                       # iron-shod tyre
        w.cyl(c, 0.25, 0.25, 0.08, "Wood", seg=12, axis='x')                         # wooden wheel
        w.cyl(c, 0.075, 0.075, 0.14, "Bright", seg=8, axis='x')                      # hub
        for k in range(8):
            a = 2 * math.pi * k / 8
            w.bar(c, (c[0], c[1] + math.cos(a) * 0.30, c[2] + math.sin(a) * 0.30), 0.035, 0.03, "Wood", up=(1, 0, 0))     # spokes
        w.finish()
    b = TM("Body", root, loc=AX, holder=True)
    b.bar((-0.60, 0.32, 0.10), (0.60, 0.32, 0.10), 0.05, 0.05, "Steel")             # the axle
    # bed: three planks with gaps, side boards, end boards
    for xx in (-0.26, 0.0, 0.26):
        b.box((xx, 0.52, 0.0), (0.24, 0.05, 1.24), "Wood")
    for sx in (-1, 1):
        b.box((sx * 0.40, 0.69, 0.0), (0.05, 0.30, 1.24), "Wood")                    # side boards
        b.bar((sx * 0.30, 0.44, -0.70), (sx * 0.30, 0.44, 0.80), 0.07, 0.06, "Steel")    # frame rails under the bed
        b.bar((sx * 0.43, 0.84, -0.62), (sx * 0.43, 0.84, 0.62), 0.04, 0.04, "Steel")     # top rail of the side board
        for zz in (-0.60, 0.60):
            b.box((sx * 0.40, 0.69, zz), (0.07, 0.34, 0.05), "Steel")                     # corner posts
        # pull rails: the frame carries on forward to the bar the player pulls by
        b.bar((sx * 0.30, 0.46, -0.70), (sx * 0.31, 0.56, -1.55), 0.055, 0.05, "Wood")
    b.box((0.0, 0.69, -0.62), (0.82, 0.30, 0.05), "Wood")                             # front board
    b.box((0.0, 0.69, 0.62), (0.82, 0.30, 0.05), "Wood")                              # tailboard
    b.bar((-0.34, 0.56, -1.58), (0.34, 0.56, -1.58), 0.06, 0.06, "Rubber")            # the pull bar, with a rubber grip
    b.bar((-0.30, 0.50, -1.10), (0.30, 0.50, -1.10), 0.04, 0.04, "Steel")             # cross brace between the pull rails
    b.bar((0.0, 0.46, 0.78), (0.0, 0.05, 0.92), 0.06, 0.05, "Steel")                  # prop leg
    b.box((0.0, 0.025, 0.94), (0.16, 0.05, 0.14), "Rubber")                           # and its foot
    for sx in (-1, 1):
        b.cyl((sx * 0.60, AX[1], AX[2]), 0.05, 0.05, 0.04, "Bright", seg=6, axis='x')   # axle caps outside the hubs
    b.box((0.2, 0.55, 0.3), (0.28, 0.01, 0.2), "Rust")
    b.finish()


def build(name, fn, glb):
    Q.reset()
    root = empty("QD_" + name, size=0.1)
    fn(root)
    os.makedirs(SRC, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, name + ".blend"))
    path = os.path.join(OUT, glb)
    Q.export_glb(path)
    faces = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
    print("CART", name, os.path.getsize(path), "bytes", faces, "faces")


if __name__ == "__main__":
    build("wheelbarrow_hd", reinforced, "VEH_QD_WheelbarrowHD.glb")
    build("hand_cart", hand_cart, "VEH_QD_HandCart.glb")
    print("BUILD_OK")
