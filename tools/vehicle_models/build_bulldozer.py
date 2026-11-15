"""QUARRY DAYS - crawler bulldozer (Blender 5.x, headless). Same pipeline as the excavator and truck.

    blender -b --factory-startup -P tools/vehicle_models/build_bulldozer.py -- [--no-export] [--no-anim]

Output: assets/vehicles/src/QD_Bulldozer.blend and assets/vehicles/VEH_QD_Bulldozer.glb (Y up, faces -Z, ground at 0, centred).
Hierarchy: root > tracks (belts that scroll) + wheels (sprockets, idlers, rollers, carriers: spin) and Shake (engine vibration) >
body, cab (framed glass, seat, levers) and Lift (the C-frame, hinged on the track-frame trunnions) > Blade (tilts about the forward axis).
Hydraulics: two lift cylinders (y/z) and one tilt cylinder (x/z); their pins stay connected for any blade height / tilt (dozer_kin.py).
"""
import bpy, math, os, sys
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import qd_blender as Q
import qd_parts as P
import dozer_kin as D
from qd_blender import Mesher, empty

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
DO_EXPORT = "--no-export" not in argv
DO_ANIM = "--no-anim" not in argv
OUT_BLEND = os.path.join(Q.REPO, "assets", "vehicles", "src", "QD_Bulldozer.blend")
OUT_GLB = os.path.join(Q.REPO, "assets", "vehicles", "VEH_QD_Bulldozer.glb")

TRK_X, TRK_Y = 0.85, 1.05
TRK_RO, TRK_RI, TRK_W = 0.45, 0.39, 0.46
TRK_Z = TRK_RO
TX, TY, TZ = 0.0, D.TRUNNION[0], D.TRUNNION[1]        # lift axis (x, y, z)
BW = 1.25                                              # blade half width
CAB_X0, CAB_X1 = -0.72, 0.72
CAB_Y0, CAB_Y1 = -1.02, 0.26
CAB_ZF, CAB_ZR = 1.08, 2.38
ROOF_T = 0.06

Q.reset()
root = empty("QD_Bulldozer", size=0.3)

# ================================================================================ undercarriage
m = Mesher("Undercarriage", root, dirt=1.0)
m.box((0, 0, 0.78), (1.12, 3.0, 0.46), "ExcDark", top=0.94)                          # belly / main frame
for sx in (-1, 1):
    x = sx * TRK_X
    m.box((x, 0, 0.42), (0.28, 2.4, 0.26), "ExcDark", top=0.9)                       # track frame beam
    for yy in (-0.55, -0.18, 0.18, 0.55):
        m.box((x, yy, 0.30), (0.34, 0.14, 0.05), "SteelPlate")                       # roller brackets
    m.box((x, 0, TRK_Z + TRK_RO + 0.04), (0.58, 2.3, 0.03), "ExcDark", top=0.96)     # track guard over the top run
    m.box((sx * 1.10, TY, TZ), (0.26, 0.40, 0.34), "ExcDark")                         # trunnion housing on the track frame
    m.cyl((sx * 1.19, TY, TZ), 0.10, 0.16, 'x', "SteelPlate", seg=8)                  # trunnion pin end
    m.box((sx * 1.14, D.LIFT_BASE[0], D.LIFT_BASE[1]), (0.40, 0.22, 0.20), "ExcDark")  # lift cylinder base bracket
    m.box((sx * 0.80, -1.18, 0.46), (0.30, 0.16, 0.20), "ExcDark")                    # rear sprocket hub housing
m.finish()
for sx, nm in ((-1, "Track_L"), (1, "Track_R")):
    P.track_belt(root, nm, sx * TRK_X, -TRK_Y, TRK_Y, TRK_Z, TRK_RO, TRK_RI, TRK_W)

WHEELS = {"L": [], "R": []}
def wheel(name, sx, y, z, r, builder, width):
    mm = Mesher(name, root, loc=(sx * TRK_X, y, z), dirt=1.0)
    builder(mm, r, width)
    o = mm.finish()
    WHEELS["L" if sx < 0 else "R"].append((o, r))
    return o
for sx, tag in ((-1, "L"), (1, "R")):
    wheel(f"Sprocket_{tag}", sx, -TRK_Y, TRK_Z, 0.34, P.sprocket, 0.34)
    wheel(f"Idler_{tag}", sx, TRK_Y, TRK_Z, 0.35, P.idler, 0.30)
    for i, yy in enumerate((-0.55, -0.18, 0.18, 0.55)):
        wheel(f"Roller_{tag}{i}", sx, yy, TRK_Z - TRK_RI + 0.115, 0.115, P.roller, 0.30)
    for i, yy in enumerate((-0.35, 0.35)):
        wheel(f"Carrier_{tag}{i}", sx, yy, TRK_Z + TRK_RI - 0.085, 0.085, P.roller, 0.22)

shake = empty("Shake", root, size=0.15)                 # clip-driven engine vibration

# ================================================================================ body: hood, fenders, rear, exhaust
m = Mesher("Body", shake, dirt=0.9)
for sx in (-1, 1):
    m.box((sx * 0.85, -0.05, 1.02), (0.66, 2.9, 0.05), "CabPaint", top=0.96)         # fenders
    m.box((sx * 1.17, -0.05, 0.92), (0.04, 2.9, 0.22), "CabPaint")                    # fender skirts
    m.box((sx * 0.85, 1.43, 0.97), (0.64, 0.12, 0.05), "CabPaint")
    m.box((sx * 0.85, -1.52, 0.92), (0.66, 0.05, 0.12), "ExcDark")
    m.box((sx * 0.82, -0.95, 1.10), (0.20, 0.5, 0.22), "ExcDark", top=0.9)           # fuel / tool boxes on the fenders
m.box((0, -0.38, 1.04), (1.30, 1.30, 0.06), "ExcDark")                                # cab deck
# engine hood: sloped, tapered, with louvres and a grille
m.hexa([(-0.62, 0.26, 1.00), (0.62, 0.26, 1.00), (0.60, 1.60, 1.00), (-0.60, 1.60, 1.00),
        (-0.52, 0.26, 1.56), (0.52, 0.26, 1.56), (0.46, 1.60, 1.34), (-0.46, 1.60, 1.34)], "CabPaint")
for i in range(5):
    m.box((0, 1.615, 1.06 + i * 0.06), (0.74, 0.02, 0.03), "SteelPlate")              # grille slats
m.box((0, 1.60, 1.20), (0.88, 0.03, 0.40), "ExcDark")
for sx in (-1, 1):
    m.box((sx * 0.62, 0.9, 1.15), (0.012, 0.7, 0.24), "ExcDark")                      # side service doors
    for i in range(4):
        m.box((sx * 0.63, 0.9, 1.07 + i * 0.05), (0.012, 0.55, 0.014), "SteelPlate")  # louvres
m.box((0, 0.62, 1.50), (0.7, 0.5, 0.02), "ExcDark")                                   # hood top plate
m.bar((-0.50, 1.00, 1.50), (-0.50, 1.00, 2.10), 0.08, 0.08, "ExcDark")                # exhaust stack
m.box((-0.50, 1.00, 2.13), (0.12, 0.12, 0.05), "SteelPlate")
m.bar((0.50, 0.85, 1.48), (0.50, 0.85, 1.95), 0.07, 0.07, "ExcDark")                  # air intake pipe
m.box((0.50, 0.85, 1.97), (0.10, 0.10, 0.05), "SteelPlate")
# rear: counterweight housing + drawbar
m.hexa([(-0.66, -1.62, 0.70), (0.66, -1.62, 0.70), (0.66, -0.98, 0.70), (-0.66, -0.98, 0.70),
        (-0.58, -1.56, 1.40), (0.58, -1.56, 1.40), (0.60, -0.98, 1.46), (-0.60, -0.98, 1.46)], "CabPaint")
m.box((0, -1.64, 1.0), (0.9, 0.03, 0.10), "Hazard")
for sx in (-1, 1):
    m.box((sx * 0.52, -1.64, 1.28), (0.14, 0.04, 0.08), "LampRed")
m.box((0, -1.78, 0.56), (0.32, 0.30, 0.14), "ExcDark")                                # drawbar
m.cyl((0, -1.88, 0.56), 0.05, 0.20, 'z', "SteelPlate", seg=6)
m.finish()

# ================================================================================ cab
cx = (CAB_X0 + CAB_X1) / 2
cw = CAB_X1 - CAB_X0
ZG0, ZG1 = 1.38, CAB_ZR - ROOF_T - 0.03
YF_B, YF_T = CAB_Y1 - 0.01, CAB_Y1 - 0.20
m = Mesher("Cab", shake, dirt=0.8)
m.hexa([(CAB_X0, CAB_Y0, CAB_ZF), (CAB_X1, CAB_Y0, CAB_ZF), (CAB_X1, CAB_Y1, CAB_ZF), (CAB_X0, CAB_Y1, CAB_ZF),
        (CAB_X0 + 0.02, CAB_Y0 + 0.02, 1.40), (CAB_X1 - 0.02, CAB_Y0 + 0.02, 1.40), (CAB_X1 - 0.02, CAB_Y1 - 0.02, 1.40), (CAB_X0 + 0.02, CAB_Y1 - 0.02, 1.40)], "CabPaint")
for x in (CAB_X0 + 0.03, CAB_X1 - 0.03):
    m.bar((x, YF_B, 1.38), (x, YF_T, CAB_ZR - ROOF_T), 0.07, 0.07, "CabPaint", up=(1, 0, 0))         # raked front pillars (ROPS)
    m.bar((x, CAB_Y0 + 0.03, 1.38), (x, CAB_Y0 + 0.03, CAB_ZR - ROOF_T), 0.07, 0.07, "CabPaint", up=(1, 0, 0))
    m.bar((x, -0.38, 1.40), (x, -0.38, CAB_ZR - ROOF_T), 0.05, 0.05, "CabPaint", up=(1, 0, 0))
m.bar((CAB_X0 + 0.03, YF_B, ZG0 - 0.01), (CAB_X1 - 0.03, YF_B, ZG0 - 0.01), 0.05, 0.05, "ExcDark")
m.bar((CAB_X0 + 0.03, YF_T, CAB_ZR - ROOF_T - 0.02), (CAB_X1 - 0.03, YF_T, CAB_ZR - ROOF_T - 0.02), 0.05, 0.05, "ExcDark")
for x in (CAB_X0 + 0.005, CAB_X1 - 0.005):
    m.bar((x, CAB_Y0 + 0.04, ZG0 - 0.01), (x, YF_B - 0.03, ZG0 - 0.01), 0.05, 0.05, "ExcDark")
    m.bar((x, CAB_Y0 + 0.04, ZG1 + 0.02), (x, YF_T, ZG1 + 0.02), 0.05, 0.05, "ExcDark")
m.bar((CAB_X0 + 0.03, CAB_Y0 + 0.01, ZG0 - 0.01), (CAB_X1 - 0.03, CAB_Y0 + 0.01, ZG0 - 0.01), 0.05, 0.05, "ExcDark")
m.bar((CAB_X0 + 0.03, CAB_Y0 + 0.01, ZG1 + 0.02), (CAB_X1 - 0.03, CAB_Y0 + 0.01, ZG1 + 0.02), 0.05, 0.05, "ExcDark")
m.box((cx, (CAB_Y0 + CAB_Y1) / 2 + 0.03, CAB_ZR - ROOF_T / 2), (cw + 0.10, CAB_Y1 - CAB_Y0 + 0.10, ROOF_T), "CabPaint", top=0.94, topy=0.94)
m.box((cx, CAB_Y1 + 0.05, CAB_ZR - 0.03), (cw + 0.06, 0.10, 0.03), "ExcDark")                         # visor
m.box((cx, -0.4, CAB_ZR + 0.035), (0.36, 0.30, 0.05), "ExcDark")                                       # roof hatch
for sx in (-1, 1):
    m.box((sx * (CAB_X1 + 0.006), -0.38, 1.22), (0.014, 0.5, 0.30), "ExcDark")                       # door panel line
    m.box((sx * (CAB_X1 + 0.02), -0.22, 1.56), (0.03, 0.12, 0.03), "SteelPlate")
    m.box((sx * (CAB_X1 + 0.08), -0.35, 0.98), (0.18, 0.34, 0.04), "ExcDark")                       # step
    m.bar((sx * (CAB_X1 + 0.05), 0.20, ZG0), (sx * (CAB_X1 + 0.05), 0.20, ZG1 - 0.1), 0.025, 0.025, "SteelPlate")
m.bar((cx - 0.10, YF_B + 0.012, 1.40), (cx + 0.12, YF_T + 0.02, 1.86), 0.015, 0.012, "Rubber", up=(0, 1, 0))   # wiper
m.finish()
m = Mesher("CabGlass", shake, dirt=0.0)
x0g, x1g, t_ = CAB_X0 + 0.07, CAB_X1 - 0.07, 0.012
m.hexa([(x0g, YF_B, ZG0), (x1g, YF_B, ZG0), (x1g, YF_T, ZG1), (x0g, YF_T, ZG1),
        (x0g, YF_B + t_, ZG0), (x1g, YF_B + t_, ZG0), (x1g, YF_T + t_, ZG1), (x0g, YF_T + t_, ZG1)], "Glass")
for x in (CAB_X0 + 0.006, CAB_X1 - 0.006):
    P.pane_x(m, x, -0.32, YF_T - 0.02, ZG0, ZG1)
    P.pane_x(m, x, CAB_Y0 + 0.07, -0.44, ZG0, ZG1)
m.hexa([(x0g, CAB_Y0 + 0.006, ZG0), (x1g, CAB_Y0 + 0.006, ZG0), (x1g, CAB_Y0 + 0.006, ZG1), (x0g, CAB_Y0 + 0.006, ZG1),
        (x0g, CAB_Y0 + 0.018, ZG0), (x1g, CAB_Y0 + 0.018, ZG0), (x1g, CAB_Y0 + 0.018, ZG1), (x0g, CAB_Y0 + 0.018, ZG1)], "Glass")
m.finish()

m = Mesher("CabInterior", shake, dirt=0.3)
SY = -0.58
m.box((cx, (CAB_Y0 + CAB_Y1) / 2, CAB_ZF + 0.015), (cw - 0.06, CAB_Y1 - CAB_Y0 - 0.06, 0.03), "CabFloor")
m.cyl((0, SY, 1.15), 0.07, 0.15, 'z', "ExcDark", seg=6)
m.box((0, SY, 1.27), (0.46, 0.44, 0.10), "Seat", top=0.96)
for sx in (-1, 1):
    m.box((sx * 0.21, SY, 1.31), (0.05, 0.44, 0.06), "Seat")
    m.box((sx * 0.30, SY - 0.02, 1.40), (0.05, 0.28, 0.035), "Rubber")                     # armrests
m.hexa([(-0.23, SY - 0.20, 1.29), (0.23, SY - 0.20, 1.29), (0.23, SY - 0.13, 1.29), (-0.23, SY - 0.13, 1.29),
        (-0.21, SY - 0.30, 1.82), (0.21, SY - 0.30, 1.82), (0.21, SY - 0.23, 1.82), (-0.21, SY - 0.23, 1.82)], "Seat")
m.box((0, SY - 0.31, 1.92), (0.22, 0.07, 0.14), "Seat")
for sx in (-1, 1):
    m.box((sx * 0.50, SY + 0.12, 1.20), (0.14, 0.50, 0.20), "ExcDark")                      # side consoles
    m.box((sx * 0.50, SY + 0.16, 1.305), (0.10, 0.16, 0.02), "Rubber")
# instrument panel under the windscreen
m.hexa([(CAB_X0 + 0.06, CAB_Y1 - 0.26, 1.16), (CAB_X1 - 0.06, CAB_Y1 - 0.26, 1.16), (CAB_X1 - 0.06, CAB_Y1 - 0.04, 1.16), (CAB_X0 + 0.06, CAB_Y1 - 0.04, 1.16),
        (CAB_X0 + 0.08, CAB_Y1 - 0.22, 1.36), (CAB_X1 - 0.08, CAB_Y1 - 0.22, 1.36), (CAB_X1 - 0.08, CAB_Y1 - 0.10, 1.40), (CAB_X0 + 0.08, CAB_Y1 - 0.10, 1.40)], "ExcDark")
m.box((0, CAB_Y1 - 0.20, 1.44), (0.30, 0.025, 0.12), "ExcDark")
m.box((0, CAB_Y1 - 0.215, 1.44), (0.26, 0.008, 0.09), "Screen")
for i in range(4):
    m.box((-0.30 + i * 0.07, CAB_Y1 - 0.16, 1.40), (0.04, 0.02, 0.022), "LampRed" if i == 3 else "SteelPlate")
for i, x in enumerate((-0.12, 0.12)):                                                         # pedals: decelerator + brake
    m.bar((x, CAB_Y1 - 0.38, CAB_ZF + 0.02), (x, CAB_Y1 - 0.28, CAB_ZF + 0.10), 0.09, 0.02, "Rubber", up=(1, 0, 0))
m.box((0.0, 0.0, 1.12), (0.30, 0.08, 0.06), "ExcDark")
m.finish()
# levers: own nodes (origin at the base) - left = steering / direction, right = blade (lift + tilt)
def lever(name, x):
    mm = Mesher(name, shake, loc=(x, SY + 0.16, 1.315), dirt=0.2)
    mm.cyl((0, 0, 0.10), 0.013, 0.20, 'z', "Rubber", seg=6)
    mm.box((0, 0, 0.21), (0.05, 0.07, 0.08), "Rubber")
    mm.box((0, 0.03, 0.22), (0.015, 0.015, 0.02), "LampRed")
    return mm.finish()
lever_l = lever("Lever_L", -0.50)
lever_r = lever("Lever_R", 0.50)

def lamp(name, loc, size=(0.20, 0.06, 0.12), rot=(0, 0, 0)):
    mm = Mesher(name, shake, loc=loc, rot=rot, dirt=0.0)
    mm.box((0, 0, 0), size, "ExcDark")
    mm.box((0, size[1] / 2 + 0.004, 0), (size[0] * 0.8, 0.012, size[2] * 0.75), "LampLens")
    return mm.finish()
lamp("Lamp_Head_L", (-0.46, 1.62, 1.26))
lamp("Lamp_Head_R", (0.46, 1.62, 1.26))
lamp("Lamp_Cab", (0.0, CAB_Y1 + 0.13, CAB_ZR + 0.01), (0.5, 0.06, 0.07))
for nm, loc in (("Light_Head_L", (-0.46, 1.74, 1.26)), ("Light_Head_R", (0.46, 1.74, 1.26)), ("Light_Rear", (0.0, -1.9, 1.2)),
                ("Marker_Seat", (0, SY, 1.34)), ("Marker_Eye", (0, SY + 0.12, 1.88)), ("Marker_ExhaustTip", (-0.50, 1.00, 2.20))):
    empty(nm, shake, loc)

# ================================================================================ lift frame (C-frame) + blade
lift = Mesher("Lift", shake, loc=(TX, TY, TZ), dirt=1.0)
m = lift
AL = D.ARM_LEN
for sx in (-1, 1):
    m.bar((sx * D.ARM_X, 0, 0), (sx * (D.ARM_X - 0.05), AL, 0), 0.20, 0.26, "CabPaint")                # push arms
    m.cyl((sx * D.ARM_X, 0, 0), 0.15, 0.24, 'x', "ExcDark", seg=8)                                       # trunnion boss
    m.box((sx * (D.ARM_X + 0.09), D.LIFT_ROD[0], D.LIFT_ROD[1] - 0.06), (0.08, 0.20, 0.26), "ExcDark")    # lift cylinder lugs
    m.cyl((sx * D.CYL_X, D.LIFT_ROD[0], D.LIFT_ROD[1]), 0.04, 0.22, 'x', "SteelPlate", seg=6)
    m.bar((sx * (D.ARM_X - 0.05), AL - 0.2, 0.05), (sx * (D.ARM_X - 0.12), AL, 0.05), 0.14, 0.10, "ExcDark")
for sx in (-1, 1):                                                                                     # tilt brace posts (A-frame) up to the tilt cylinder base
    m.bar((sx * 1.1, AL - 0.25, 0.1), (D.TILT_BASE[0] * (1 if sx > 0 else -1) * 0.9, AL - 0.14, D.TILT_BASE[1]), 0.07, 0.07, "ExcDark")
m.box((0, AL - 0.14, D.TILT_BASE[1] + 0.02), (2 * D.TILT_BASE[0] * 0.9 + 0.12, 0.10, 0.10), "ExcDark")  # brace top beam
m.cyl((D.TILT_BASE[0], AL - 0.14, D.TILT_BASE[1]), 0.045, 0.22, 'y', "SteelPlate", seg=6)             # tilt base pin
lift_obj = m.finish()

blade = Mesher("Blade", lift_obj, loc=(0, AL, 0), zbase=0.6, dirt=1.6)
m = blade
front = [(0.30, -0.50), (0.24, -0.36), (0.12, -0.12), (0.08, 0.14), (0.14, 0.38), (0.24, 0.52)]
back = [(y - 0.07, z) for y, z in front]
poly = front + back[::-1]
m.prism_yz(poly, -BW, BW, "CabPaint")                                                                   # moulboard
m.box((0, 0.27, -0.50), (2 * BW, 0.12, 0.10), "SteelPlate")                                             # cutting edge
for sx in (-1, 1):
    m.hexa([(sx * (BW - 0.10), 0.20, -0.52), (sx * (BW + 0.06), 0.20, -0.52), (sx * (BW + 0.06), 0.38, -0.52), (sx * (BW - 0.10), 0.38, -0.52),
            (sx * (BW - 0.10), 0.22, -0.28), (sx * (BW + 0.06), 0.22, -0.28), (sx * (BW + 0.06), 0.30, -0.28), (sx * (BW - 0.10), 0.30, -0.28)], "SteelPlate")   # corner bits
    m.prism_yz([(0.34, -0.20), (0.34, 0.45), (0.20, 0.55), (0.0, 0.55), (0.0, -0.20)], sx * BW - 0.02, sx * BW + 0.02, "CabPaint")                              # side wings
m.box((0, 0.26, 0.54), (2 * BW, 0.07, 0.05), "ExcDark")                                                 # top rolled lip
for x in (-1.0, -0.5, 0.0, 0.5, 1.0):
    m.box((x, -0.12, 0.0), (0.10, 0.10, 0.95), "ExcDark")                                               # back ribs
m.box((0, -0.14, 0.05), (2 * BW - 0.1, 0.12, 0.12), "ExcDark")                                          # back beam
m.box((0, -0.14, 0.40), (2 * BW - 0.1, 0.10, 0.08), "ExcDark")
for sx in (-1, 1):
    m.cyl((sx * 1.15, -0.12, 0.0), 0.11, 0.20, 'x', "SteelPlate", seg=8)                                # ball brackets at the arm ends
tr = D.TILT_ROD
m.box((tr[0], -0.14, tr[1]), (0.12, 0.08, 0.16), "ExcDark")                                             # tilt rod lug
m.cyl((tr[0], -0.14, tr[1]), 0.045, 0.22, 'y', "SteelPlate", seg=6)
blade_obj = m.finish()
empty("Marker_Edge", blade_obj, (0, 0.30, -0.50))
empty("Marker_Pile", blade_obj, (0, 0.55, -0.05))

# ================================================================================ hydraulics
def cyl(name, parent, loc, d_lo, d_hi, r_barrel=0.07, r_rod=0.04):
    lb, lr = d_lo - 0.06, d_lo - 0.08
    mb = Mesher(name + "_Barrel", parent, loc=loc, dirt=0.7)
    mb.cyl((0, lb / 2, 0), r_barrel, lb, 'y', "ExcDark", seg=8)
    mb.cyl((0, 0.035, 0), r_barrel * 1.2, 0.07, 'y', "SteelPlate", seg=8)
    mb.cyl((0, 0, 0), 0.04, 0.20, 'x', "SteelPlate", seg=6)
    mb.cyl((0, lb - 0.02, 0), r_barrel * 1.15, 0.05, 'y', "SteelPlate", seg=8)
    mb.cyl((0, lb * 0.5, 0), r_barrel * 1.12, 0.045, 'y', "CabPaint", seg=8)
    barrel = mb.finish()
    mr = Mesher(name + "_Rod", barrel, loc=(0, d_lo, 0), dirt=0.2)
    mr.cyl((0, -lr / 2, 0), r_rod, lr, 'y', "MetalBrushed", seg=6)
    mr.cyl((0, 0, 0), 0.045, 0.18, 'x', "SteelPlate", seg=6)
    return barrel, mr.finish()

(l_lo, l_hi), (t_lo, t_hi) = D.ranges()
LIFT_CYL = {}
for sx, tag in ((-1, "L"), (1, "R")):
    LIFT_CYL[tag] = cyl(f"LiftCyl_{tag}", shake, (sx * D.CYL_X, D.LIFT_BASE[0], D.LIFT_BASE[1]), l_lo, l_hi)
TILT_CYL = cyl("TiltCyl", lift_obj, (D.TILT_BASE[0], AL - 0.14, D.TILT_BASE[1]), t_lo, t_hi, 0.06, 0.035)
for sx, tag in ((-1, "L"), (1, "R")):
    empty(f"Pin_LiftBase_{tag}", shake, (sx * D.CYL_X, D.LIFT_BASE[0], D.LIFT_BASE[1]))
    empty(f"Pin_LiftRod_{tag}", lift_obj, (sx * D.CYL_X, D.LIFT_ROD[0], D.LIFT_ROD[1]))
empty("Pin_TiltBase", lift_obj, (D.TILT_BASE[0], AL - 0.14, D.TILT_BASE[1]))
empty("Pin_TiltRod", blade_obj, (D.TILT_ROD[0], -0.14, D.TILT_ROD[1]))
empty("Pin_Trunnion", shake, (0, TY, TZ))

# collision proxies (hidden by the rig; the game keeps its own body hull)
def hull(name, loc, boxes):
    mm = Mesher(name, root, loc=loc, dirt=0.0)
    for c, s_ in boxes:
        mm.box(c, s_, "ExcDark")
    o = mm.finish(); o.hide_render = True; o.display_type = 'WIRE'
hull("ColHull_Body", (0, 0, 0), [((0, -0.1, 0.9), (2.3, 3.4, 1.0)), ((0, -0.4, 1.7), (1.5, 1.4, 1.4))])
hull("ColHull_Blade", (0, 0, 0), [((0, 2.5, 0.55), (2.6, 0.6, 1.1))])

# ================================================================================ pose + animation
def aim_xz(obj, dx, dz):
    """Point the cylinder (+Y axis) along (dx, 0, dz) in its parent's frame."""
    obj.rotation_euler = Vector((dx, 0, dz)).to_track_quat('Y', 'Z').to_euler()

def pose(p):
    al, th = p.get("alpha", 0.0), p.get("tilt", 0.0)
    shake.location = (0, 0, p.get("vibe", 0.0))
    lift_obj.rotation_euler = (al, 0, 0)
    blade_obj.rotation_euler = (0, th, 0)
    ang, d = D.lift(al)
    for tag in ("L", "R"):
        b, r = LIFT_CYL[tag]
        b.rotation_euler = (ang, 0, 0)
        r.location = (0, d, 0)
    dx, dz, dl = D.tilt(th)
    aim_xz(TILT_CYL[0], dx, dz)
    TILT_CYL[1].location = (0, dl, 0)
    for side, key in (("L", "drive_l"), ("R", "drive_r")):
        for o, r in WHEELS[side]:
            o.rotation_euler = (-p.get(key, 0.0) / r, 0, 0)
    lever_l.rotation_euler = (p.get("lev_x", 0.0), 0, p.get("lev_z", 0.0))
    lever_r.rotation_euler = (-(al - 0.19) * 0.6, 0, -th * 1.6)

pose({})
CLIPS = Q.Clips()
if DO_ANIM:
    CLIPS.track(shake, "location")
    for o in (lift_obj, blade_obj, lever_l, lever_r, TILT_CYL[0], *[b for b, r in LIFT_CYL.values()]):
        CLIPS.track(o)
    for o in (TILT_CYL[1], *[r for b, r in LIFT_CYL.values()]):
        CLIPS.track(o, "location")
    for side in WHEELS.values():
        for o, r in side:
            CLIPS.track(o)

def smooth(t): return t * t * (3 - 2 * t)
def keyed(keys, t):
    if t <= keys[0][0]: return keys[0][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1: return v0 + (v1 - v0) * smooth((t - t0) / (t1 - t0))
    return keys[-1][1]
def frames(n, step=1): return list(range(1, n + 2, step))
REST_A = 0.20

if DO_ANIM:
    def idle(f):
        t = (f - 1) / 24
        pose({"alpha": REST_A, "vibe": 0.003 * math.sin(t * 6 * math.pi) + 0.0012 * math.sin(t * 14 * math.pi)})
    CLIPS.bake("Idle", frames(24), idle)
    def start(f):
        t = (f - 1) / 54
        env = keyed([(0, 0.0), (0.15, 1.0), (0.55, 1.0), (0.7, 0.4), (1.0, 0.2)], t)
        pose({"alpha": REST_A, "vibe": (0.006 * math.sin(t * 90) + 0.003 * math.sin(t * 57)) * env * (0.3 if t > 0.55 else 1.0)})
    CLIPS.bake("EngineStart", frames(54), start)
    def stop(f):
        t = (f - 1) / 45
        env = keyed([(0, 0.2), (0.4, 0.5), (0.8, 0.12), (1.0, 0.0)], t)
        pose({"alpha": REST_A, "vibe": (0.005 * math.sin(t * 70) + 0.003 * math.sin(t * 43)) * env - 0.003 * smooth(min(1.0, t * 1.4))})
    CLIPS.bake("EngineStop", frames(45), stop)
    def blade_updown(f):
        t = (f - 1) / 120
        pose({"alpha": keyed([(0, REST_A), (0.3, D.LIFT_MAX), (0.7, D.LIFT_MIN), (1, REST_A)], t)})
    CLIPS.bake("BladeUpDown", frames(120), blade_updown)
    def blade_tilt(f):
        t = (f - 1) / 120
        pose({"alpha": 0.0, "tilt": keyed([(0, 0), (0.25, D.TILT_MAX), (0.5, 0), (0.75, -D.TILT_MAX), (1, 0)], t)})
    CLIPS.bake("BladeTilt", frames(120), blade_tilt)
    def push(f):
        t = (f - 1) / 240
        al = keyed([(0, REST_A), (0.12, -0.08), (0.72, -0.08), (0.82, D.LIFT_MAX), (1, REST_A)], t)
        dist = keyed([(0, 0), (0.12, 0.0), (0.72, 3.2), (0.82, 3.2), (1, 3.2)], t)
        pose({"alpha": al, "tilt": 0.05 * math.sin(t * 9) if 0.15 < t < 0.7 else 0.0, "drive_l": dist, "drive_r": dist, "vibe": 0.004 * math.sin(f * 0.9) if 0.12 < t < 0.72 else 0.0})
    CLIPS.bake("PushCycle", frames(240), push)
    def drive(f):
        t = (f - 1) / 24
        pose({"alpha": REST_A, "drive_l": 1.5 * t, "drive_r": 1.5 * t, "vibe": 0.004 * math.sin(t * 8 * math.pi)})
    CLIPS.bake("Drive", frames(24), drive)
    def turn(f):
        t = (f - 1) / 24
        pose({"alpha": REST_A, "drive_l": 0.5 * t, "drive_r": 1.5 * t, "lev_x": 0.0, "lev_z": -0.25, "vibe": 0.004 * math.sin(t * 8 * math.pi)})
    CLIPS.bake("Turn", frames(24), turn)

pose({"alpha": REST_A})
for o in bpy.data.objects:
    if o.animation_data:
        o.animation_data.action = None
os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
if DO_EXPORT:
    Q.export_glb(OUT_GLB)
    print("GLB", OUT_GLB, os.path.getsize(OUT_GLB), "bytes")
print("BUILD_OK", len([o for o in bpy.data.objects if o.type == 'MESH']), "meshes")
