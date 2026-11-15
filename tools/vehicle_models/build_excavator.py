# FINISHING PASS applied (cab, body, bucket detail, track guards)
"""QUARRY DAYS - hydraulic excavator (Blender 5.x, headless).

    blender -b --factory-startup -P tools/vehicle_models/build_excavator.py -- [--render <dir>] [--no-export] [--no-anim]

Output
    assets/vehicles/src/QD_Excavator.blend   editable source (all parts named, hinges at the origins)
    assets/vehicles/VEH_QD_Excavator.glb     game export (Y up, faces -Z, ground at 0, centred between the tracks)

Mechanics (shared with the game via tools/vehicle_models/exc_kin.py and scripts/art/excavator_rig.gd)
    Turret (swing, Z) -> Boom (boom, X) -> Stick (X) -> Bucket (X). Every hydraulic cylinder is a barrel + rod pair whose far end
    is pinned to the real pin on the moving part; the bucket uses a real 4-bar linkage (idler link + bucket link + cylinder at J).
"""
import bpy, math, os, sys, random
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import qd_blender as Q
import exc_kin as K
from qd_blender import Mesher, empty

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER = argv[argv.index("--render") + 1] if "--render" in argv else None
DO_EXPORT = "--no-export" not in argv
DO_ANIM = "--no-anim" not in argv
OUT_BLEND = os.path.join(Q.REPO, "assets", "vehicles", "src", "QD_Excavator.blend")
OUT_GLB = os.path.join(Q.REPO, "assets", "vehicles", "VEH_QD_Excavator.glb")

S = K.ARM_S
T0 = 0.78                       # slewing-ring height: the Turret origin
AX = 0.45                       # x of the boom / stick / bucket plane
TRK_X = 0.80                    # track centre x
TRK_Y = 1.34                    # sprocket / idler centre y
TRK_Z = 0.335
TRK_W = 0.44
TRK_RO, TRK_RI = 0.335, 0.27
CAB_X0, CAB_X1 = -0.97, -0.19
CAB_Y0, CAB_Y1 = -0.42, 0.58
CAB_ZF, CAB_ZR = 0.90, 2.14     # cab floor, roof top
ROOF_T = 0.06


def sp(p): return (p[0] * S, p[1] * S)


Q.reset()
root = empty("QD_Excavator", size=0.3)

# ================================================================================ undercarriage
m = Mesher("Undercarriage", root, dirt=0.9)
m.box((0, 0, 0.42), (1.14, 2.3, 0.34), "ExcDark", top=0.92)                      # centre frame
m.box((0, 1.28, 0.40), (1.0, 0.22, 0.26), "ExcDark", top=0.9)                      # front cross beam
m.box((0, -1.28, 0.40), (1.0, 0.22, 0.26), "ExcDark", top=0.9)                     # rear cross beam
m.cyl((0, 0, 0.67), 0.64, 0.14, 'z', "ExcDark", seg=14)                            # slew bearing housing
m.cyl((0, 0, 0.745), 0.69, 0.05, 'z', "SteelPlate", seg=14)                        # bearing race (the turret turns on this)
for sx in (-1, 1):
    x = sx * TRK_X
    m.box((x, 0, 0.36), (0.26, 2.2, 0.20), "ExcDark", top=0.9)                     # track frame beam
    for yy in (-0.7, -0.24, 0.24, 0.7):
        m.box((x, yy, 0.20), (0.30, 0.14, 0.05), "SteelPlate")                      # roller brackets
    m.box((sx * 0.57, 0, 0.5), (0.04, 2.0, 0.1), "SteelPlate")                      # inner guard rail
    # travel motor housing on the rear sprocket
    m.cyl((sx * 0.62, -TRK_Y, TRK_Z), 0.15, 0.1, 'x', "ExcDark", seg=8)
    m.cyl((sx * 1.04 - sx * 0.0, -TRK_Y, TRK_Z), 0.1, 0.05, 'x', "SteelPlate", seg=8)  # sprocket cap
    m.box((x, 0.0, TRK_Z + TRK_RO + 0.035), (0.50, 2.1, 0.03), "ExcDark", top=0.96)                  # track guard over the top run
    for yy in (-0.95, 0.95):
        m.box((x, yy, TRK_Z + TRK_RO + 0.0), (0.06, 0.06, 0.07), "SteelPlate")                       # guard brackets
    # track-frame bolts
    for yy in (-0.9, -0.3, 0.3, 0.9):
        m.box((sx * 0.935, yy, 0.46), (0.03, 0.05, 0.05), "SteelPlate")
    # front idler yoke + track tension cylinder (grease cylinder)
    m.box((sx * 0.74, 1.0, 0.32), (0.06, 0.5, 0.06), "SteelPlate")
    m.cyl((sx * 0.87, 1.0, 0.3), 0.04, 0.5, 'y', "ExcDark", seg=6)
m_under = m.finish()
Q.empty  # (kept for clarity)

# ---------------------------------------------------------------- tracks (belt meshes: the texture scrolls in-game)
def track_belt(name, sx):
    mm = Mesher(name, root, loc=(sx * TRK_X, 0, 0), dirt=0.8)
    pts_o, pts_i, arc = [], [], []
    seg = 9
    path = []
    # bottom run (rear -> front), front arc, top run (front -> rear), rear arc
    def add(y, z, ny, nz): path.append((y, z, ny, nz))
    add(-TRK_Y, TRK_Z - TRK_RO, 0, -1)
    add(TRK_Y, TRK_Z - TRK_RO, 0, -1)
    for i in range(1, seg):
        a = -math.pi / 2 + math.pi * i / seg
        add(TRK_Y + math.cos(a) * 1.0 * TRK_RO, TRK_Z + math.sin(a) * TRK_RO, math.cos(a), math.sin(a))
    add(TRK_Y, TRK_Z + TRK_RO, 0, 1)
    add(-TRK_Y, TRK_Z + TRK_RO, 0, 1)
    for i in range(1, seg):
        a = math.pi / 2 + math.pi * i / seg
        add(-TRK_Y + math.cos(a) * TRK_RO, TRK_Z + math.sin(a) * TRK_RO, math.cos(a), math.sin(a))
    n = len(path)
    # arclength of the outer surface
    cum = [0.0]
    for i in range(1, n + 1):
        a, b = path[i - 1], path[i % n]
        cum.append(cum[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    total = cum[-1]
    pitch = 0.2
    reps = round(total / pitch)                         # whole number of grousers so the texture wraps seamlessly
    hw = TRK_W / 2
    ctr = (0, 0, TRK_Z)
    for i in range(n):
        a, b = path[i], path[(i + 1) % n]
        u0, u1 = cum[i] / total * reps, cum[i + 1] / total * reps
        def P(p, x, k):                                 # k: 1 outer, 0 inner
            r = TRK_RO if k else TRK_RI
            # point on the loop offset along its normal
            cy, cz = p[0] - p[2] * TRK_RO, p[1] - p[3] * TRK_RO
            return (x, cy + p[2] * r, cz + p[3] * r)
        mm.raw_quad([P(a, -hw, 1), P(b, -hw, 1), P(b, hw, 1), P(a, hw, 1)], [(u0, 0), (u1, 0), (u1, 1), (u0, 1)], "ExcTrack", outward=ctr)
        mm.raw_quad([P(a, -hw, 0), P(b, -hw, 0), P(b, hw, 0), P(a, hw, 0)], [(u0, 0.1), (u1, 0.1), (u1, 0.9), (u0, 0.9)], "ExcTrack", outward=(0, 99, 99) if False else None)
        for x, dirn in ((-hw, -1), (hw, 1)):            # side walls
            mm.raw_quad([P(a, x, 0), P(b, x, 0), P(b, x, 1), P(a, x, 1)], [(u0, 0), (u1, 0), (u1, 0.05), (u0, 0.05)], "ExcTrack",
                        outward=(x - dirn * 5, 0, TRK_Z))
    # guide lugs on the inside of the belt (static, tiny)
    return mm.finish()


for sx, nm in ((-1, "Track_L"), (1, "Track_R")):
    track_belt(nm, sx)

# ---------------------------------------------------------------- track wheels (origins at their axles; rotate about X)
WHEELS = []     # (obj, radius)
def wheel_obj(name, sx, y, z, r, builder):
    mm = Mesher(name, root, loc=(sx * TRK_X, y, z), dirt=1.1)
    builder(mm)
    o = mm.finish()
    WHEELS.append((o, r))
    return o

def sprocket(mm):
    mm.cyl((0, 0, 0), 0.20, 0.34, 'x', "ExcDark", seg=10)
    mm.cyl((0, 0, 0), 0.07, 0.40, 'x', "SteelPlate", seg=6)
    for i in range(10):
        a = 2 * math.pi * i / 10
        c, s_ = math.cos(a), math.sin(a)
        mm.bar((0, c * 0.18, s_ * 0.18), (0, c * 0.255, s_ * 0.255), 0.30, 0.07, "SteelPlate", up=(1, 0, 0))

def idler(mm):
    mm.cyl((0, 0, 0), 0.25, 0.24, 'x', "ExcDark", seg=12)
    for x in (-0.13, 0.13):
        mm.cyl((x, 0, 0), 0.265, 0.05, 'x', "SteelPlate", seg=12)
    mm.cyl((0, 0, 0), 0.07, 0.40, 'x', "SteelPlate", seg=6)

def roller(mm):
    mm.cyl((0, 0, 0), 0.095, 0.30, 'x', "ExcDark", seg=8)
    for x in (-0.11, 0.11):
        mm.cyl((x, 0, 0), 0.105, 0.05, 'x', "SteelPlate", seg=8)

def carrier(mm):
    mm.cyl((0, 0, 0), 0.065, 0.22, 'x', "ExcDark", seg=6)
    mm.cyl((0, 0, 0), 0.075, 0.05, 'x', "SteelPlate", seg=6)

for sx, tag in ((-1, "L"), (1, "R")):
    wheel_obj(f"Sprocket_{tag}", sx, -TRK_Y, TRK_Z, 0.25, sprocket)
    wheel_obj(f"Idler_{tag}", sx, TRK_Y, TRK_Z, 0.26, idler)
    for i, yy in enumerate((-0.72, -0.24, 0.24, 0.72)):
        wheel_obj(f"Roller_{tag}{i}", sx, yy, TRK_Z - TRK_RI + 0.095, 0.095, roller)
    wheel_obj(f"Carrier_{tag}", sx, 0.0, TRK_Z + TRK_RI - 0.065 - 0.005, 0.065, carrier)

# ================================================================================ turret
turret = empty("Turret", root, loc=(0, 0, T0), size=0.25)
TS = (0, 0, -T0)                                         # model space -> turret-local shift

# ---------------------------------------------------------------- body: deck, counterweight, engine bay, tanks   (FINISHING PASS: lower, tapered, rounded)
m = Mesher("TurretBody", turret, shift=TS, zbase=T0, dirt=1.0)
deck = [(-0.98, 0.95), (0.98, 0.95), (0.98, -0.95), (0.80, -1.30), (0.50, -1.46), (-0.50, -1.46), (-0.80, -1.30), (-0.98, -0.95)]
m.prism_xy(deck, 0.78, 0.90, "ExcDark")                                                       # deck plate
for sx in (-1, 1):
    m.box((sx * 0.975, 0.55, 0.84), (0.03, 0.8, 0.10), "ExcPaint")                              # side skirts

def loft(x0, x1, y0, y1, zb, zt0, zt1, inset, mat):
    """Hood block: rectangular footprint, top face inset in x and sloping from zt0 (at y0) to zt1 (at y1)."""
    return m.hexa([(x0, y0, zb), (x1, y0, zb), (x1, y1, zb), (x0, y1, zb),
                   (x0 + inset, y0, zt0), (x1 - inset, y0, zt0), (x1 - inset, y1, zt1), (x0 + inset, y1, zt1)], mat)

def side_x(z, x_edge, zb, zt, inset, sign=1):
    """x of a hood's sloped side at height z (louvres and doors sit on it)."""
    return x_edge - sign * inset * max(0.0, min(1.0, (z - zb) / max(0.01, zt - zb)))

# counterweight: elliptical rear, lower and tapered
cwx = [(0.94, -0.80), (0.95, -1.00)]
for a in range(-20, -180, -20):
    cwx.append((0.95 * math.cos(math.radians(a)), -1.0 + 0.5 * math.sin(math.radians(a))))
cwx += [(-0.95, -1.00), (-0.94, -0.80)]
m.prism_xy(cwx, 0.90, 1.42, "ExcPaint", top_k=0.90)
rear_y = lambda x: -1.0 - 0.5 * math.sqrt(max(0.0, 1.0 - (x / 0.95) ** 2)) * 0.9      # approx rear surface y at x (inset by taper)
m.box((0, -1.50, 1.02), (0.9, 0.04, 0.11), "Hazard")
m.box((0, -1.485, 1.27), (0.46, 0.05, 0.13), "ExcDark")                                       # rear service plate
for z in (1.23, 1.27, 1.31):
    m.box((0, -1.515, z), (0.40, 0.012, 0.016), "SteelPlate")
m.cyl((0, -1.1, 1.445), 0.055, 0.05, 'z', "SteelPlate", seg=8)                               # lifting eye
for sx in (-1, 1):
    m.box((sx * 0.66, rear_y(0.66) - 0.01, 1.12), (0.12, 0.05, 0.08), "LampRed")             # tail lights on the curve
# engine hood on the right and the bay behind the cab: lower, with sloped shoulders
HOOD = (0.0, 0.96, -0.80, 0.34, 0.90, 1.34, 1.16, 0.12)
loft(*HOOD, "ExcPaint")
loft(-0.98, 0.0, -0.80, CAB_Y0, 0.90, 1.32, 1.30, 0.10, "ExcPaint")
xs = lambda z: side_x(z, 0.96, 0.90, 1.25, 0.12)
m.box((xs(1.12) + 0.004, -0.2, 1.12), (0.014, 0.66, 0.30), "ExcDark")                          # access door recess
for i in range(6):
    m.box((xs(1.0 + i * 0.045) + 0.012, -0.2, 1.0 + i * 0.045), (0.014, 0.56, 0.016), "SteelPlate")   # louvres
m.box((xs(1.15) + 0.016, 0.1, 1.15), (0.02, 0.035, 0.10), "ExcDark")                           # door handle
for i in range(6):
    m.box((0.48, -0.32 - i * 0.075, 1.33 - 0.02), (0.62, 0.04, 0.012), "SteelPlate")            # roof vent slats
m.box((0.48, -0.54, 1.318), (0.66, 0.34, 0.01), "ExcDark")
# hydraulic oil + fuel tank, right front, with filler caps
m.box((0.88, 0.50, 1.04), (0.20, 0.55, 0.28), "ExcPaint", top=0.9)
m.cyl((0.88, 0.40, 1.19), 0.04, 0.035, 'z', "SteelPlate", seg=6)
m.cyl((0.88, 0.62, 1.175), 0.035, 0.03, 'z', "ExcDark", seg=6)
# grab rail on the right + step bar at the front left
m.bar((0.96, -0.55, 1.30), (0.96, 0.78, 1.24), 0.035, 0.035, "SteelPlate")
for yy in (-0.50, 0.15, 0.74):
    m.bar((0.96, yy, 1.02), (0.96, yy, 1.25), 0.03, 0.03, "SteelPlate")
m.box((-0.55, 0.88, 0.82), (0.7, 0.14, 0.06), "Hazard")                                       # front step
# boom foot housing + lugs, boom cylinder base clevis blocks (unchanged pins)
m.box((AX, 0.62, 0.99), (0.78, 0.66, 0.18), "ExcPaint", top=0.85)
for sx in (-1, 1):
    m.prism_yz([(0.42, 1.05), (0.82, 1.05), (0.80, 1.22), (0.72, 1.30), (0.52, 1.30), (0.44, 1.22)], AX + sx * 0.205 - 0.035, AX + sx * 0.205 + 0.035, "ExcPaint")
    m.box((AX + sx * 0.30, K.BOOM_CYL["base"][0], 0.93), (0.12, 0.2, 0.2), "ExcDark")            # cylinder base clevis
    m.cyl((AX + sx * 0.30, K.BOOM_CYL["base"][0], K.BOOM_CYL["base"][1]), 0.045, 0.16, 'x', "SteelPlate", seg=6)
m.cyl((AX, K.P0[0], K.P0[1]), 0.07, 0.50, 'x', "SteelPlate", seg=8)                          # boom foot pin
m.finish()

# ---------------------------------------------------------------- exhaust
mx = Mesher("Exhaust", turret, loc=(0.74, -0.58, 1.30 - T0), dirt=0.8)
mx.cyl((0, 0, 0.12), 0.095, 0.30, 'z', "ExcDark", seg=8)                                        # muffler
mx.cyl((0, 0, 0.55), 0.045, 0.70, 'z', "SteelPlate", seg=6)                                     # pipe
mx.cyl((0, 0, 0.92), 0.06, 0.06, 'z', "ExcDark", seg=6)                                          # collar
mx.bar((0, 0, 0.03), (0, -0.08, 0.0), 0.2, 0.06, "ExcDark")
exh = mx.finish()
cap = Mesher("ExhaustCap", exh, loc=(0.0, -0.045, 0.95), dirt=0.5)                               # hinge at the rear of the pipe mouth
cap.cyl((0, 0.045, 0.012), 0.062, 0.025, 'z', "ExcDark", seg=8)
exh_cap = cap.finish()

# ---------------------------------------------------------------- cab (frame, glass, interior)   (FINISHING PASS: slimmer, raked windscreen, framed glass, full interior)
cx = (CAB_X0 + CAB_X1) / 2
cw_x = CAB_X1 - CAB_X0
ZG0, ZG1 = 1.22, CAB_ZR - ROOF_T - 0.03             # glass bottom / top
YF_B, YF_T = CAB_Y1 - 0.02, CAB_Y1 - 0.16           # windscreen leans back: bottom edge / top edge
m = Mesher("CabFrame", turret, shift=TS, zbase=T0, dirt=0.9)
m.hexa([(CAB_X0, CAB_Y0, CAB_ZF), (CAB_X1, CAB_Y0, CAB_ZF), (CAB_X1, CAB_Y1, CAB_ZF), (CAB_X0, CAB_Y1, CAB_ZF),
        (CAB_X0 + 0.03, CAB_Y0 + 0.03, 1.16), (CAB_X1 - 0.03, CAB_Y0 + 0.03, 1.16), (CAB_X1 - 0.03, CAB_Y1 - 0.01, 1.16), (CAB_X0 + 0.03, CAB_Y1 - 0.01, 1.16)], "ExcPaint")   # lower body, chamfered
m.box((cx, CAB_Y1 - 0.05, 1.2), (cw_x - 0.04, 0.10, 0.06), "ExcDark")                          # sill under the windscreen
for x in (CAB_X0 + 0.03, CAB_X1 - 0.03):
    m.bar((x, YF_B, 1.16), (x, YF_T, CAB_ZR - ROOF_T), 0.06, 0.06, "ExcPaint", up=(1, 0, 0))     # raked A pillars
    m.bar((x, CAB_Y0 + 0.03, 1.14), (x, CAB_Y0 + 0.03, CAB_ZR - ROOF_T), 0.06, 0.06, "ExcPaint", up=(1, 0, 0))   # rear pillars
    m.bar((x, 0.08, 1.16), (x, 0.08, CAB_ZR - ROOF_T), 0.045, 0.045, "ExcPaint", up=(1, 0, 0))       # door / window divider
# frames around every pane (dark rubber surround) so the glass reads as glass
m.bar((CAB_X0 + 0.03, YF_T, CAB_ZR - ROOF_T - 0.02), (CAB_X1 - 0.03, YF_T, CAB_ZR - ROOF_T - 0.02), 0.05, 0.05, "ExcDark")      # windscreen header
m.bar((CAB_X0 + 0.03, YF_B - 0.0, ZG0 - 0.01), (CAB_X1 - 0.03, YF_B, ZG0 - 0.01), 0.05, 0.05, "ExcDark")
for x in (CAB_X0 + 0.005, CAB_X1 - 0.005):
    m.bar((x, CAB_Y0 + 0.04, ZG0 - 0.01), (x, CAB_Y1 - 0.03, ZG0 - 0.01), 0.05, 0.05, "ExcDark")                              # side sills
    m.bar((x, CAB_Y0 + 0.04, ZG1 + 0.02), (x, YF_T, ZG1 + 0.02), 0.05, 0.05, "ExcDark")                                       # side headers
m.bar((CAB_X0 + 0.03, CAB_Y0 + 0.01, ZG0 - 0.01), (CAB_X1 - 0.03, CAB_Y0 + 0.01, ZG0 - 0.01), 0.05, 0.05, "ExcDark")         # rear sill
m.bar((CAB_X0 + 0.03, CAB_Y0 + 0.01, ZG1 + 0.02), (CAB_X1 - 0.03, CAB_Y0 + 0.01, ZG1 + 0.02), 0.05, 0.05, "ExcDark")         # rear header
# roof: slim painted slab with a front visor and a vent hatch
m.box((cx, (CAB_Y0 + CAB_Y1) / 2 + 0.03, CAB_ZR - ROOF_T / 2), (cw_x + 0.10, CAB_Y1 - CAB_Y0 + 0.12, ROOF_T), "ExcPaint", top=0.94, topy=0.93)
m.box((cx, CAB_Y1 + 0.07, CAB_ZR - 0.03), (cw_x + 0.06, 0.10, 0.03), "ExcDark")               # visor
m.box((cx - 0.08, -0.05, CAB_ZR + 0.035), (0.30, 0.26, 0.05), "ExcDark")                      # roof hatch
m.box((cx, (CAB_Y0 + CAB_Y1) / 2, CAB_ZF + 0.02), (cw_x - 0.04, CAB_Y1 - CAB_Y0 - 0.04, 0.03), "CabFloor")   # floor mat
# door detail (right side), wiper, hand holds, steps
m.box((CAB_X1 + 0.012, 0.30, 1.50), (0.03, 0.14, 0.03), "SteelPlate")
for z in (1.28, 1.95):
    m.box((CAB_X1 + 0.012, 0.09, z), (0.03, 0.05, 0.08), "SteelPlate")                        # door hinges
m.bar((cx - 0.12, YF_B + 0.012, 1.26), (cx + 0.10, YF_T + 0.024, 1.72), 0.015, 0.012, "Rubber", up=(0, 1, 0))     # wiper arm
m.bar((CAB_X1 + 0.04, YF_B - 0.02, 1.24), (CAB_X1 + 0.04, YF_T, 1.92), 0.025, 0.025, "SteelPlate")              # grab handle
m.box((CAB_X1 + 0.11, 0.18, 0.84), (0.20, 0.34, 0.04), "ExcDark")                              # step
m.box((CAB_X1 + 0.20, 0.18, 0.84), (0.02, 0.34, 0.045), "Hazard")
cab_obj = m.finish()

def pane_x(x, y0, y1, zb, zt, t=0.012):
    return m.hexa([(x - t / 2, y0, zb), (x - t / 2, y1, zb), (x - t / 2, y1, zt), (x - t / 2, y0, zt),
                   (x + t / 2, y0, zb), (x + t / 2, y1, zb), (x + t / 2, y1, zt), (x + t / 2, y0, zt)], "Glass")

m = Mesher("CabGlass", turret, shift=TS, zbase=T0, dirt=0.0)
t_ = 0.012
x0g, x1g = CAB_X0 + 0.065, CAB_X1 - 0.065
m.hexa([(x0g, YF_B, ZG0), (x1g, YF_B, ZG0), (x1g, YF_T, ZG1), (x0g, YF_T, ZG1),
        (x0g, YF_B + t_, ZG0), (x1g, YF_B + t_, ZG0), (x1g, YF_T + t_, ZG1), (x0g, YF_T + t_, ZG1)], "Glass")                   # raked windscreen
pane_x(CAB_X0 + 0.006, 0.11, YF_T - 0.04, ZG0, ZG1)                                              # left window, front
pane_x(CAB_X0 + 0.006, CAB_Y0 + 0.07, 0.05, ZG0, ZG1)                                           # left window, rear
pane_x(CAB_X1 - 0.006, 0.11, YF_T - 0.04, ZG0, ZG1)                                              # door window
pane_x(CAB_X1 - 0.006, CAB_Y0 + 0.07, 0.05, ZG0, ZG1)
m.hexa([(x0g, CAB_Y0 + 0.006, ZG0), (x1g, CAB_Y0 + 0.006, ZG0), (x1g, CAB_Y0 + 0.006, ZG1), (x0g, CAB_Y0 + 0.006, ZG1),
        (x0g, CAB_Y0 + 0.018, ZG0), (x1g, CAB_Y0 + 0.018, ZG0), (x1g, CAB_Y0 + 0.018, ZG1), (x0g, CAB_Y0 + 0.018, ZG1)], "Glass")   # rear window
m.finish()

m = Mesher("CabInterior", turret, shift=TS, zbase=T0, dirt=0.4)
SX, SY = -0.58, -0.10                                      # seat centre
m.cyl((SX, SY, 1.0), 0.07, 0.16, 'z', "ExcDark", seg=6)                                        # pedestal
m.box((SX, SY, 1.075), (0.30, 0.30, 0.025), "ExcDark")                                          # seat rails
m.box((SX, SY + 0.0, 1.13), (0.42, 0.42, 0.09), "Seat", top=0.96)                              # cushion
for sx in (-1, 1):
    m.box((SX + sx * 0.19, SY, 1.17), (0.05, 0.42, 0.06), "Seat")                               # bolsters
m.hexa([(SX - 0.21, SY - 0.19, 1.14), (SX + 0.21, SY - 0.19, 1.14), (SX + 0.21, SY - 0.12, 1.14), (SX - 0.21, SY - 0.12, 1.14),
        (SX - 0.19, SY - 0.31, 1.62), (SX + 0.19, SY - 0.31, 1.62), (SX + 0.19, SY - 0.24, 1.62), (SX - 0.19, SY - 0.24, 1.62)], "Seat")   # reclined backrest
m.box((SX, SY - 0.33, 1.72), (0.20, 0.07, 0.13), "Seat")                                        # headrest
m.bar((SX, SY - 0.30, 1.62), (SX, SY - 0.32, 1.66), 0.04, 0.03, "ExcDark")
for sx in (-1, 1):
    m.box((SX + sx * 0.25, SY - 0.02, 1.25), (0.05, 0.26, 0.035), "Rubber")                     # armrests
# control consoles either side of the seat (joystick bases)
for x in (-0.86, -0.30):
    m.box((x, 0.04, 1.08), (0.13, 0.52, 0.24), "ExcDark")
    m.box((x, 0.10, 1.205), (0.10, 0.14, 0.02), "Rubber")
    m.box((x, -0.12, 1.205), (0.09, 0.07, 0.015), "LampRed" if x > -0.5 else "SteelPlate")      # switch pads
# dashboard: sloped binnacle under the windscreen with monitor and switches
m.hexa([(CAB_X0 + 0.05, CAB_Y1 - 0.20, 1.12), (CAB_X1 - 0.05, CAB_Y1 - 0.20, 1.12), (CAB_X1 - 0.05, CAB_Y1 - 0.04, 1.12), (CAB_X0 + 0.05, CAB_Y1 - 0.04, 1.12),
        (CAB_X0 + 0.07, CAB_Y1 - 0.18, 1.30), (CAB_X1 - 0.07, CAB_Y1 - 0.18, 1.30), (CAB_X1 - 0.07, CAB_Y1 - 0.08, 1.34), (CAB_X0 + 0.07, CAB_Y1 - 0.08, 1.34)], "ExcDark")
m.box((cx + 0.15, CAB_Y1 - 0.19, 1.36), (0.20, 0.025, 0.14), "ExcDark")                         # monitor housing
m.box((cx + 0.15, CAB_Y1 - 0.207, 1.36), (0.17, 0.008, 0.11), "Screen")                         # screen
for i in range(4):
    m.box((cx - 0.26 + i * 0.07, CAB_Y1 - 0.15, 1.32), (0.04, 0.02, 0.022), "LampRed" if i == 3 else "SteelPlate")
m.cyl((cx - 0.14, CAB_Y1 - 0.16, 1.33), 0.04, 0.02, 'y', "SteelPlate", seg=8)                  # gauge
# travel levers + foot pedals
for x in (-0.50, -0.66):
    m.cyl((x, 0.34, 1.06), 0.014, 0.26, 'z', "ExcDark", seg=6)
    m.box((x, 0.34, 1.20), (0.045, 0.05, 0.06), "Rubber")
    m.bar((x, 0.40, 0.935), (x, 0.50, 0.99), 0.09, 0.022, "Rubber", up=(1, 0, 0))                # pedal plates
    m.box((x, 0.36, 0.935), (0.07, 0.07, 0.03), "ExcDark")                                       # pedal pivots
# small details: extinguisher, radio, lunch box
m.cyl((-0.90, -0.34, 1.12), 0.04, 0.24, 'z', "LampRed", seg=6)
m.box((-0.90, -0.34, 1.26), (0.05, 0.05, 0.05), "Rubber")
m.box((CAB_X1 - 0.08, -0.30, 1.40), (0.10, 0.12, 0.08), "ExcDark")
m.box((-0.30, -0.34, 1.12), (0.18, 0.12, 0.14), "ExcPaint")
m.finish()

# joysticks: own nodes, origin at the base, tilt while working
def joystick(name, x):
    mm = Mesher(name, turret, loc=(x, 0.10, 1.215 - T0), dirt=0.2)
    mm.cyl((0, 0, 0.07), 0.012, 0.14, 'z', "Rubber", seg=6)
    mm.box((0, 0, 0.15), (0.05, 0.07, 0.08), "Rubber")
    mm.box((0.0, 0.03, 0.16), (0.015, 0.015, 0.02), "LampRed")
    return mm.finish()
joy_l = joystick("Joystick_L", -0.86)
joy_r = joystick("Joystick_R", -0.30)

# lamps (emissive lenses; the game adds real lights on the Light_* markers)
def lamp(name, parent, loc, rot=(0, 0, 0)):
    mm = Mesher(name, parent, loc=loc, rot=rot, dirt=0.0)
    mm.box((0, 0, 0), (0.15, 0.06, 0.09), "ExcDark")
    mm.box((0, 0.032, 0), (0.12, 0.012, 0.065), "LampLens")
    return mm.finish()
lamp("Lamp_Cab_L", turret, (-0.80, CAB_Y1 + 0.16, CAB_ZR - T0 + 0.01))
lamp("Lamp_Cab_R", turret, (-0.30, CAB_Y1 + 0.16, CAB_ZR - T0 + 0.01))
lamp("Lamp_Rear", turret, (0.0, -1.53, 1.62 - T0), rot=(0, 0, math.pi))
for nm, loc in (("Light_Cab_L", (-0.80, CAB_Y1 + 0.22, CAB_ZR - T0)), ("Light_Cab_R", (-0.30, CAB_Y1 + 0.22, CAB_ZR - T0)), ("Light_Rear", (0.0, -1.60, 1.62 - T0)),
                ("Marker_Seat", (-0.58, -0.10, 1.20 - T0)), ("Marker_Eye", (-0.58, 0.04, 1.70 - T0)), ("Marker_ExhaustTip", (0.74, -0.58, 2.26 - T0))):
    empty(nm, turret, loc)

# ================================================================================ boom, stick, bucket
boom_pt = lambda p: (AX, p[0], p[1])
b_top = [(-0.12, 0.20), (0.45, 0.30), (1.2, 0.66), (1.7, 0.58), (2.15, 0.30), (2.42, 0.18)]
b_bot = [(2.42, -0.20), (2.05, -0.12), (1.5, 0.15), (1.05, 0.18), (0.45, -0.10), (-0.12, -0.22)]
boom_poly = [sp(p) for p in b_top + b_bot]
boom = Mesher("Boom", turret, loc=(AX, K.P0[0], K.P0[1] - T0), rot=(K.REST["boom"], 0, 0), zbase=1.9, dirt=0.9)
m = boom
m.prism_yz(boom_poly, -0.17, 0.17, "ExcPaint")
m.prism_yz([sp(p) for p in [(0.2, 0.31), (1.2, 0.68), (1.7, 0.60), (2.0, 0.40), (1.7, 0.44), (1.2, 0.52), (0.5, 0.26)]], -0.10, 0.10, "ExcPaint")   # top spine plate
for sx in (-1, 1):                                                                              # side wear plates
    m.prism_yz([sp(p) for p in [(1.15, 0.50), (1.6, 0.46), (1.55, 0.22), (1.1, 0.26)]], sx * 0.17, sx * 0.185, "SteelPlate")
m.cyl((0, 0, 0), 0.115, 0.36, 'x', "ExcDark", seg=8)                                              # foot boss
m.cyl((0, 0, 0), 0.07, 0.50, 'x', "SteelPlate", seg=8) if False else None
m.cyl((0, K.BOOM_E[0], K.BOOM_E[1]), 0.105, 0.40, 'x', "ExcDark", seg=8)                          # elbow boss
m.cyl(K.BOOM_E + (0,) if False else (0, K.BOOM_E[0], K.BOOM_E[1]), 0.06, 0.50, 'x', "SteelPlate", seg=6)  # elbow pin
# boom cylinder lug (the rod end of both boom cylinders pins here)
rb = K.BOOM_CYL["rod"]
m.prism_yz([(rb[0] - 0.14, 0.06), (rb[0] + 0.14, 0.12), (rb[0] + 0.07, rb[1]), (rb[0] - 0.07, rb[1])], -0.30, 0.30, "ExcDark") if False else None
for sx in (-1, 1):
    m.prism_yz([(rb[0] - 0.16, 0.12), (rb[0] + 0.12, 0.18), (rb[0] + 0.05, rb[1] + 0.02), (rb[0] - 0.05, rb[1] + 0.02)], sx * 0.26 - 0.03, sx * 0.26 + 0.03, "ExcPaint")
m.box((0, rb[0] - 0.02, 0.0), (0.56, 0.18, 0.12), "ExcPaint") if False else None
m.prism_yz([(rb[0] - 0.22, 0.0), (rb[0] + 0.22, 0.2), (rb[0] + 0.2, 0.0)], -0.26, 0.26, "ExcPaint") if False else None
m.cyl((0, rb[0], rb[1]), 0.05, 0.64, 'x', "SteelPlate", seg=6)                                    # pin through both lugs
m.box((0, rb[0] - 0.05, rb[1] + 0.12), (0.52, 0.34, 0.18), "ExcPaint") if False else None
# stick cylinder base lugs on top of the boom
sb = K.STICK_CYL["base"]
for sx in (-1, 1):
    m.prism_yz([(sb[0] - 0.16, 0.38), (sb[0] + 0.16, 0.40), (sb[0] + 0.05, sb[1] + 0.05), (sb[0] - 0.05, sb[1] + 0.05)], sx * 0.075 - 0.02, sx * 0.075 + 0.02, "ExcPaint")
m.cyl((0, sb[0], sb[1]), 0.04, 0.2, 'x', "SteelPlate", seg=6)
# hydraulic hoses riding along the boom
m.bar(sp((0.3, 0.42)), sp((1.15, 0.78)), 0.03, 0.03, "Rubber") if False else None
m.bar((0.17, 0.1, 0.18), (0.17, 1.2 * S, 0.55 * S + 0.12), 0.03, 0.03, "Rubber")
m.bar((0.17, 1.2 * S, 0.55 * S + 0.12), (0.17, 2.1 * S, 0.34 * S + 0.1), 0.03, 0.03, "Rubber")
boom_obj = m.finish()
lamp("Lamp_Boom", boom_obj, (0.17 + 0.07, 1.62 * S, 0.62 * S + 0.04), rot=(0, 0, math.pi / 2 * 0 + 0.0))
empty("Light_Boom", boom_obj, (0.24, 1.62 * S + 0.12, 0.62 * S + 0.04))

# stick (origin = elbow pin)
stick = Mesher("Stick", boom_obj, loc=(0, K.BOOM_E[0], K.BOOM_E[1]), rot=(K.REST["stick"], 0, 0), zbase=1.7, dirt=1.0)
m = stick
st = [(-0.14, 0.60), (0.24, 0.62), (0.33, 0.30), (0.34, -0.40), (0.40, -1.05), (0.30, -1.22), (0.16, -1.20), (0.06, -0.90), (-0.16, -0.20), (-0.30, 0.20)]
m.prism_yz([sp(p) for p in st], -0.11, 0.11, "ExcPaint")
for sx in (-1, 1):
    m.prism_yz([sp(p) for p in [(0.30, -0.15), (0.33, -0.7), (0.36, -1.0), (0.2, -0.95), (0.05, -0.4)]], sx * 0.11, sx * 0.125, "SteelPlate")   # reinforcing plates
m.cyl((0, 0, 0), 0.11, 0.24, 'x', "ExcDark", seg=8)
m.cyl((0, 0, 0), 0.06, 0.52, 'x', "SteelPlate", seg=6)
m.cyl(K.STICK_W if False else (0, K.STICK_W[0], K.STICK_W[1]), 0.095, 0.24, 'x', "ExcDark", seg=8)
m.cyl((0, K.STICK_W[0], K.STICK_W[1]), 0.05, 0.50, 'x', "SteelPlate", seg=6)                         # bucket pin
kk = K.LINK_K
m.cyl((0, kk[0], kk[1]), 0.04, 0.34, 'x', "SteelPlate", seg=6)                                       # idler-link pin
# stick-cylinder rod lug and bucket-cylinder base lug on the hump
sr = K.STICK_CYL["rod"]; bc = K.BUCKET_CYL["base"]
for sx in (-1, 1):
    m.prism_yz([(sr[0] - 0.08, sr[1] - 0.15), (sr[0] + 0.1, sr[1] - 0.15), (sr[0] + 0.07, sr[1] + 0.02), (sr[0] - 0.07, sr[1] + 0.02)], sx * 0.09 - 0.02, sx * 0.09 + 0.02, "ExcPaint")
    m.prism_yz([(bc[0] - 0.08, bc[1] - 0.14), (bc[0] + 0.08, bc[1] - 0.14), (bc[0] + 0.06, bc[1] + 0.02), (bc[0] - 0.06, bc[1] + 0.02)], sx * 0.09 - 0.02, sx * 0.09 + 0.02, "ExcPaint")
m.cyl((0, sr[0], sr[1]), 0.04, 0.24, 'x', "SteelPlate", seg=6)
m.cyl((0, bc[0], bc[1]), 0.04, 0.24, 'x', "SteelPlate", seg=6)
stick_obj = m.finish()

# bucket (origin = bucket pin), mouth opens to +Y and up at the rest orientation
bucket = Mesher("Bucket", stick_obj, loc=(0, K.STICK_W[0], K.STICK_W[1]), rot=(K.REST["bucket"], 0, 0), zbase=0.9, dirt=1.6)   # hoe bucket: teeth at the rear-bottom
m = bucket
cc = (-0.10 * S, -0.46 * S); R_out, R_in = 0.46 * S, 0.41 * S
def arc(r, a0, a1, n):
    return [(cc[0] - r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cc[1] + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]
outer = arc(R_out, -5, -235, 10)
inner = arc(R_in, -5, -235, 10)
HW = 0.37
# shell: strip between outer and inner arc
for i in range(10):
    quad = [outer[i], outer[i + 1], inner[i + 1], inner[i]]
    m.prism_yz(quad, -HW, HW, "SteelPlate")
for sx in (-1, 1):                                                                                # side plates: filled circular segments
    plate = outer + [sp((0.10, 0.12)), sp((-0.10, 0.14)), sp((-0.17, 0.02))]
    m.prism_yz(plate, sx * HW - (0.0 if sx > 0 else -0.03), sx * HW + (0.03 if sx > 0 else 0.0), "SteelPlate")
lip = outer[0]
outer2 = arc(R_out + 0.035, -5, -235, 10)
for xr in (-0.22, 0.0, 0.22):                                                                      # reinforcing ribs over the shell
    for i in range(1, 9):
        m.prism_yz([outer[i], outer[i + 1], outer2[i + 1], outer2[i]], xr - 0.025, xr + 0.025, "ExcDark")
m.box((0, lip[0] + 0.02, lip[1] + 0.02), (2 * HW, 0.10, 0.07), "SteelPlate")                       # reinforced lip plate
for i in range(5):                                                                                # teeth: adapter block + pointed tooth
    x = -0.30 + i * 0.15
    m.box((x, lip[0] - 0.02, lip[1] - 0.01), (0.10, 0.09, 0.09), "SteelPlate")                      # adapter
    m.hexa([(x - 0.045, lip[0] - 0.05, lip[1] - 0.05), (x + 0.045, lip[0] - 0.05, lip[1] - 0.05), (x + 0.045, lip[0] - 0.05, lip[1] + 0.04), (x - 0.045, lip[0] - 0.05, lip[1] + 0.04),
            (x - 0.010, lip[0] - 0.24 * S, lip[1] - 0.12), (x + 0.010, lip[0] - 0.24 * S, lip[1] - 0.12), (x + 0.010, lip[0] - 0.24 * S, lip[1] - 0.075), (x - 0.010, lip[0] - 0.24 * S, lip[1] - 0.075)], "ExcDark")
for sx in (-1, 1):
    m.box((sx * (HW + 0.02), lip[0] + 0.0, lip[1] + 0.0), (0.07, 0.16, 0.12), "SteelPlate")          # side cutters
# ears with the pin + link pin
for sx in (-1, 1):
    m.prism_yz([sp(p) for p in [(-0.14, 0.40), (0.10, 0.40), (0.16, 0.0), (0.10, -0.14), (-0.10, -0.14), (-0.17, 0.0)]], sx * 0.215 - 0.02, sx * 0.215 + 0.02, "ExcPaint")
m.cyl((0, 0, 0), 0.05, 0.50, 'x', "SteelPlate", seg=6)
ll = K.LINK_L
m.cyl((0, ll[0], ll[1]), 0.04, 0.50, 'x', "SteelPlate", seg=6)
m.box((0, 0.05 * S, -0.10 * S), (0.44, 0.14 * S, 0.12), "ExcPaint")                                # back brace between the ears
for sx in (-1, 1):
    m.box((sx * 0.22, 0.2 * S, -0.34 * S), (0.03, 0.4 * S, 0.1), "ExcDark") if False else None
bucket_obj = m.finish()
empty("Marker_BucketLoad", bucket_obj, (0, -0.12 * S, -0.30 * S))
empty("Marker_BucketTip", bucket_obj, (0, K.TIP[0], K.TIP[1]))
empty("Marker_Pin_Bucket", bucket_obj, (0, 0, 0))

# ================================================================================ hydraulic cylinders and linkage
CYL_R_BARREL, CYL_R_ROD = 0.062, 0.034

def cylinder(name, parent, loc, d_min, d_max):
    """Barrel (origin = base pin, axis +Y) and rod (origin = rod-end pin, child of the barrel, slides along +Y)."""
    lb = d_min - 0.07
    lr = d_min - 0.09
    mb = Mesher(name + "_Barrel", parent, loc=loc, dirt=0.7)
    mb.cyl((0, lb / 2, 0), CYL_R_BARREL, lb, 'y', "ExcDark", seg=8)
    mb.cyl((0, 0.035, 0), 0.075, 0.07, 'y', "SteelPlate", seg=8)                                   # base cap
    mb.cyl((0, 0, 0), 0.04, 0.20, 'x', "SteelPlate", seg=6)                                       # base eye
    mb.cyl((0, lb - 0.02, 0), 0.072, 0.05, 'y', "SteelPlate", seg=8)                              # gland nut
    mb.cyl((0, lb * 0.5, 0), 0.07, 0.04, 'y', "ExcPaint", seg=8)                                   # paint band
    barrel = mb.finish()
    mr = Mesher(name + "_Rod", barrel, loc=(0, d_min, 0), dirt=0.2)
    mr.cyl((0, -lr / 2, 0), CYL_R_ROD, lr, 'y', "MetalBrushed", seg=6)
    mr.cyl((0, 0, 0), 0.045, 0.16, 'x', "SteelPlate", seg=6)                                       # rod eye / pin
    mr.cyl((0, -0.02, 0), 0.05, 0.05, 'y', "ExcDark", seg=6)
    rod = mr.finish()
    return barrel, rod

def link(name, parent, loc, length, x_thick=0.04):
    mm = Mesher(name, parent, loc=loc, dirt=0.8)
    mm.bar((0, 0, 0), (0, length, 0), 0.05, x_thick, "ExcDark", up=(1, 0, 0))
    mm.cyl((0, 0, 0), 0.04, x_thick, 'x', "SteelPlate", seg=6)
    mm.cyl((0, length, 0), 0.04, x_thick, 'x', "SteelPlate", seg=6)
    return mm.finish()

CR = K.cyl_ranges()
bs, rs = K.BOOM_CYL["base"], None
CYL = {}
for sx, tag in ((-1, "L"), (1, "R")):
    CYL["boom" + tag] = cylinder(f"BoomCyl_{tag}", turret, (AX + sx * 0.30, bs[0], bs[1] - T0), *CR["BoomCyl"])
CYL["stick"] = cylinder("StickCyl", boom_obj, (0.0, K.STICK_CYL["base"][0], K.STICK_CYL["base"][1]), *CR["StickCyl"])
CYL["bucket"] = cylinder("BucketCyl", stick_obj, (0.0, K.BUCKET_CYL["base"][0], K.BUCKET_CYL["base"][1]), *CR["BucketCyl"])
rl = K.rest_link()
LINKS = {}
for sx, tag in ((-1, "L"), (1, "R")):
    LINKS["idler" + tag] = link(f"IdlerLink_{tag}", stick_obj, (sx * 0.135, K.LINK_K[0], K.LINK_K[1]), rl["lk"])
    LINKS["bucket" + tag] = link(f"BucketLink_{tag}", bucket_obj, (sx * 0.175, K.LINK_L[0], K.LINK_L[1]), rl["ll"])

# ================================================================================ pin markers (validation + the game's runtime rig read these)
for sx, tag in ((-1, "L"), (1, "R")):
    empty(f"Pin_BoomCylBase_{tag}", turret, (AX + sx * 0.30, K.BOOM_CYL["base"][0], K.BOOM_CYL["base"][1] - T0))
    empty(f"Pin_BoomCylRod_{tag}", boom_obj, (sx * 0.30, K.BOOM_CYL["rod"][0], K.BOOM_CYL["rod"][1]))
    empty(f"Pin_IdlerK_{tag}", stick_obj, (sx * 0.135, K.LINK_K[0], K.LINK_K[1]))
    empty(f"Pin_BucketL_{tag}", bucket_obj, (sx * 0.175, K.LINK_L[0], K.LINK_L[1]))
empty("Pin_StickCylBase", boom_obj, (0, K.STICK_CYL["base"][0], K.STICK_CYL["base"][1]))
empty("Pin_StickCylRod", stick_obj, (0, K.STICK_CYL["rod"][0], K.STICK_CYL["rod"][1]))
empty("Pin_BucketCylBase", stick_obj, (0, K.BUCKET_CYL["base"][0], K.BUCKET_CYL["base"][1]))
empty("Pin_BoomFoot", turret, (AX, K.P0[0], K.P0[1] - T0))
empty("Pin_Elbow", boom_obj, (0, K.BOOM_E[0], K.BOOM_E[1]))
empty("Pin_BucketPin", stick_obj, (0, K.STICK_W[0], K.STICK_W[1]))

# ================================================================================ collision proxies (hidden convex hulls; the game turns them into shapes)
def hull(name, parent, loc, boxes):
    mm = Mesher(name, parent, loc=loc, dirt=0.0)
    for c, s_ in boxes:
        mm.box(c, s_, "ExcDark")
    o = mm.finish()
    o.hide_render = True
    o.display_type = 'WIRE'
    return o
hull("ColHull_Tracks", root, (0, 0, 0), [((-TRK_X, 0, 0.32), (0.46, 3.3, 0.64)), ((TRK_X, 0, 0.32), (0.46, 3.3, 0.64)), ((0, 0, 0.5), (1.2, 2.3, 0.3))])
hull("ColHull_Upper", turret, (0, 0, 0), [((0, -0.25, 0.28 + 0.0), (1.96, 2.4, 0.9)), ((0, -0.2, 0.62 - 0.0), (1.9, 1.4, 0.2))])
hull("ColHull_Cab", turret, (0, 0, 0), [(((CAB_X0 + CAB_X1) / 2, (CAB_Y0 + CAB_Y1) / 2, (1.12 + CAB_ZR) / 2 - T0), (cw_x + 0.1, CAB_Y1 - CAB_Y0 + 0.1, CAB_ZR - 1.12))])

# ================================================================================ posing + animation
turret_o = turret
CYL_TARGETS = {}

def aim_x(obj, base, target):
    """Rotate `obj` about X so its +Y axis points from base to target (2D, in the parent's (y, z) plane). Returns the distance."""
    dy, dz = target[0] - base[0], target[1] - base[1]
    obj.rotation_euler = (math.atan2(dz, dy), 0, 0)
    return math.hypot(dy, dz)

def pose(p):
    """Set every mechanical node from a parameter dict (swing, boom, stick, bucket, drive, vibe, joy*, cap)."""
    swing, b, s, k = p.get("swing", 0.0), p.get("boom", K.REST["boom"]), p.get("stick", K.REST["stick"]), p.get("bucket", K.REST["bucket"])
    turret.rotation_euler = (0, 0, swing)
    turret.location = (0, 0, T0 + p.get("vibe", 0.0))
    boom_obj.rotation_euler = (b, 0, 0)
    stick_obj.rotation_euler = (s, 0, 0)
    bucket_obj.rotation_euler = (k, 0, 0)
    pose_k = K.Pose(b, s, k)
    # boom cylinders: base pin in the turret plane, rod pin on the boom
    base = K.BOOM_CYL["base"]
    tgt = pose_k.boom_pt(K.BOOM_CYL["rod"])
    for tag in ("L", "R"):
        barrel, rod = CYL["boom" + tag]
        d = aim_x(barrel, base, tgt)
        rod.location = (0, d, 0)
    # stick cylinder: base pin on the boom, rod pin on the stick (both in boom-local coordinates)
    barrel, rod = CYL["stick"]
    base = K.STICK_CYL["base"]
    tgt = K.add(K.BOOM_E, K.rot(K.STICK_CYL["rod"], s))
    rod.location = (0, aim_x(barrel, base, tgt), 0)
    # bucket 4-bar, solved in stick-local coordinates
    q = K.Pose(0, 0, k)
    J = K.sub(K.bucket_j(q, -1), q.E)                                 # J in the stick frame
    barrel, rod = CYL["bucket"]
    base = K.BUCKET_CYL["base"]
    rod.location = (0, aim_x(barrel, base, J), 0)
    for tag in ("L", "R"):
        aim_x(LINKS["idler" + tag], K.LINK_K, J)
        Jb = K.rot(K.sub(J, K.STICK_W), -k)                              # J in the bucket frame
        aim_x(LINKS["bucket" + tag], K.LINK_L, Jb)
    # wheels
    d = p.get("drive", 0.0)
    for o, r in WHEELS:
        o.rotation_euler = (-d / r, 0, 0)
    # cab and exhaust details
    joy_l.rotation_euler = (p.get("jl_x", 0.0), 0, p.get("jl_y", 0.0))
    joy_r.rotation_euler = (p.get("jr_x", 0.0), 0, p.get("jr_y", 0.0))
    exh_cap.rotation_euler = (p.get("cap", 0.0), 0, 0)

pose({})

CLIPS = Q.Clips()
if DO_ANIM:
    CLIPS.track(turret, "location", "rotation_euler")
    for o in (boom_obj, stick_obj, bucket_obj, joy_l, joy_r, exh_cap):
        CLIPS.track(o)
    for o, _ in WHEELS:
        CLIPS.track(o)
    for v in CYL.values():
        for o in (v if isinstance(v, tuple) else ()):
            CLIPS.track(o, "rotation_euler", "location") if "Rod" in o.name else CLIPS.track(o)
    for o in LINKS.values():
        CLIPS.track(o)

def smooth(t): return t * t * (3 - 2 * t)
def keyed(keys, t):
    """keys: [(time, value)...] with smoothstep easing between them; clamps outside."""
    if t <= keys[0][0]: return keys[0][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1:
            return v0 + (v1 - v0) * smooth((t - t0) / (t1 - t0))
    return keys[-1][1]

def sampled(n, step=1, start=1):
    return list(range(start, start + n + 1, step))

rest = {"swing": 0.0, "boom": K.REST["boom"], "stick": K.REST["stick"], "bucket": K.REST["bucket"]}

def bake_all():
    if not DO_ANIM:
        return
    # --- Idle: engine idling vibration (loop, 24 frames)
    def idle(f):
        t = (f - 1) / 24
        p = dict(rest); p["vibe"] = 0.0035 * math.sin(t * 2 * math.pi * 3) + 0.0015 * math.sin(t * 2 * math.pi * 7)
        p["cap"] = 0.05 + 0.04 * math.sin(t * 2 * math.pi * 2)
        pose(p)
    CLIPS.bake("Idle", sampled(24), idle)
    # --- EngineStart: crank (big shudder), catch, settle (60 frames)
    def start(f):
        t = (f - 1) / 60
        env = keyed([(0, 0.0), (0.15, 1.0), (0.55, 1.0), (0.7, 0.45), (1.0, 0.22)], t)
        p = dict(rest)
        p["vibe"] = (0.007 * math.sin(t * 90) + 0.004 * math.sin(t * 61)) * env * (0.3 if t > 0.55 else 1.0)
        p["cap"] = keyed([(0, 0.0), (0.58, 0.0), (0.64, 0.9), (0.8, 0.12), (1.0, 0.07)], t)
        pose(p)
    CLIPS.bake("EngineStart", sampled(60), start)
    # --- EngineStop: shudder out, sag, cap snaps shut (48 frames)
    def stop(f):
        t = (f - 1) / 48
        env = keyed([(0, 0.22), (0.4, 0.5), (0.8, 0.12), (1.0, 0.0)], t)
        p = dict(rest)
        p["vibe"] = (0.005 * math.sin(t * 70) + 0.003 * math.sin(t * 43)) * env - 0.004 * smooth(min(1.0, t * 1.4))
        p["cap"] = keyed([(0, 0.07), (0.1, 0.5), (0.3, 0.0), (1.0, 0.0)], t)
        pose(p)
    CLIPS.bake("EngineStop", sampled(48), stop)
    # --- Swing (turret left 90, right 90, back) 120 frames
    def swing_clip(f):
        t = (f - 1) / 120
        p = dict(rest)
        p["swing"] = keyed([(0, 0), (0.25, math.pi / 2), (0.5, 0), (0.75, -math.pi / 2), (1.0, 0)], t)
        p["jl_y"] = p["swing"] * 0.16
        pose(p)
    CLIPS.bake("Swing", sampled(120, 2), swing_clip)
    # --- BoomUpDown, StickInOut, BucketCurlDump (90 frames each, full mechanical range)
    def one_joint(name, key):
        lo, hi = K.LIMITS[key]
        def fn(f):
            t = (f - 1) / 90
            p = dict(rest)
            p[key] = keyed([(0, rest[key]), (0.3, hi), (0.7, lo), (1.0, rest[key])], t)
            if key == "boom": p["jr_x"] = (p[key] - rest[key]) * 0.2
            if key == "stick": p["jl_x"] = (p[key] - rest[key]) * 0.2
            if key == "bucket": p["jr_y"] = (p[key] - rest[key]) * 0.2
            pose(p)
        CLIPS.bake(name, sampled(90, 2), fn)
    one_joint("BoomUpDown", "boom")
    one_joint("StickInOut", "stick")
    one_joint("BucketCurlDump", "bucket")
    # --- TrackDrive: tracks rolling forward, loop = 1.2 m of travel in 24 frames
    def drive(f):
        t = (f - 1) / 24
        p = dict(rest); p["drive"] = 1.2 * t
        p["vibe"] = 0.004 * math.sin(t * 2 * math.pi * 3)
        pose(p)
    CLIPS.bake("TrackDrive", sampled(24), drive)

    # --- digging poses solved with planar IK: tip target (y, z) + bucket attitude
    def ik(y, z, attitude):
        b, s, k, e = K.ik_tip((y, z), attitude)
        return {"boom": b, "stick": s, "bucket": k}
    far = ik(3.35, 0.08, 0.35)       # reach out, teeth at ground level
    mid = ik(2.8, -0.12, 0.1)        # bite
    near = ik(2.2, 0.05, -0.6)       # drag in, bucket curled
    lift = ik(2.4, 1.9, -1.1)        # carried up
    high = ik(2.9, 2.55, -1.1)       # held high over a truck bed
    dump = ik(3.1, 1.9, 0.95)          # bucket opened
    dumph = ik(3.2, 2.5, 1.0)

    def cycle(name, frames, keys_fn):
        def fn(f):
            t = (f - 1) / frames
            p = dict(rest)
            for kname in ("swing", "boom", "stick", "bucket"):
                p[kname] = keyed(keys_fn(kname), t)
            p["vibe"] = 0.003 * math.sin(f * 0.9)
            p["jl_x"] = (p["stick"] - rest["stick"]) * 0.12
            p["jr_x"] = (p["boom"] - rest["boom"]) * 0.12
            p["jr_y"] = (p["bucket"] - rest["bucket"]) * 0.1
            p["jl_y"] = p["swing"] * 0.15
            pose(p)
        CLIPS.bake(name, sampled(frames, 1), fn)

    def dig_keys(kname):
        T = [0.0, 0.14, 0.28, 0.42, 0.55, 0.70, 0.84, 1.0]
        seq = {"swing": [0, 0, 0, 0, math.pi / 2 * 0.9, math.pi / 2 * 0.9, math.pi / 2 * 0.9 * 0.0 + 0.0, 0],
               "boom": [rest["boom"], far["boom"], mid["boom"], near["boom"], lift["boom"], lift["boom"], lift["boom"], rest["boom"]],
               "stick": [rest["stick"], far["stick"], mid["stick"], near["stick"], lift["stick"], lift["stick"], lift["stick"], rest["stick"]],
               "bucket": [rest["bucket"], far["bucket"], mid["bucket"], near["bucket"], near["bucket"], dump["bucket"], rest["bucket"], rest["bucket"]]}
        seq["swing"] = [0, 0, 0, 0, math.pi / 2 * 0.9, math.pi / 2 * 0.9, math.pi / 2 * 0.9, 0]
        return list(zip(T, seq[kname]))
    cycle("DigCycle", 210, dig_keys)

    def load_keys(kname):
        T = [0.0, 0.12, 0.24, 0.36, 0.50, 0.64, 0.78, 0.9, 1.0]
        sw = math.pi * 0.62
        seq = {"swing": [0, 0, 0, 0, sw, sw, sw, 0, 0],
               "boom": [rest["boom"], far["boom"], mid["boom"], near["boom"], high["boom"], high["boom"], high["boom"], rest["boom"], rest["boom"]],
               "stick": [rest["stick"], far["stick"], mid["stick"], near["stick"], high["stick"], high["stick"], high["stick"], rest["stick"], rest["stick"]],
               "bucket": [rest["bucket"], far["bucket"], mid["bucket"], near["bucket"], near["bucket"], dumph["bucket"], dumph["bucket"], rest["bucket"], rest["bucket"]]}
        return list(zip(T, seq[kname]))
    cycle("TruckLoad", 270, load_keys)

bake_all()
pose({})

# markers for the game
empty("Marker_ModelSize", root, (0, 0, 0)).empty_display_size = 0.01

for o in bpy.data.objects:
    if o.type == 'MESH':
        o.data.update()
# keep the old animation data from sticking to the active slot
for o in bpy.data.objects:
    if o.animation_data:
        o.animation_data.action = None

if RENDER:
    views = {"front34": ((6.2, 6.0, 3.4), (0.4, 0.3, 1.1)), "rear34": ((-5.5, -6.5, 3.8), (0.2, 0.2, 1.1)),
             "side": ((8.5, 0.5, 1.6), (0.3, 0.8, 1.1)), "top": ((0.01, -0.5, 9.5), (0.0, 0.5, 0.5)),
             "cab": ((-2.9, 2.6, 2.3), (-0.5, 0.0, 1.5)), "arm": ((4.8, 5.2, 2.6), (0.45, 2.3, 1.2))}
    Q.render_views(RENDER, "exc", views)

os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
if DO_EXPORT:
    Q.export_glb(OUT_GLB)
    print("GLB", OUT_GLB, os.path.getsize(OUT_GLB), "bytes")
print("BUILD_OK", len([o for o in bpy.data.objects if o.type == 'MESH']), "meshes")
