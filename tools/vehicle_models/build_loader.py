"""QUARRY DAYS - articulated wheel loader (Blender 5.x, headless). Same pipeline as the excavator / truck / bulldozer.

    blender -b --factory-startup -P tools/vehicle_models/build_loader.py -- [--no-export] [--no-anim]

Output: assets/vehicles/src/QD_Loader.blend and assets/vehicles/VEH_QD_Loader.glb (Y up, faces -Z, ground at 0).
Hierarchy: root > Shake (engine vibration) > Rear (frame, engine, cab, rear wheels) and Front (articulated about the centre hinge:
front frame, front wheels, tower) > Lift (arms on the tower pivot) > Bucket (rolls on the arm end). Hydraulics: two lift cylinders (frame -> arm)
and a tilt cylinder (arm -> bucket lug) whose pins stay connected for every arm / bucket angle (loader_kin.py).
"""
import bpy, math, os, sys
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import qd_blender as Q
import qd_parts as P
import loader_kin as L
from qd_blender import Mesher, empty

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
DO_EXPORT = "--no-export" not in argv
DO_ANIM = "--no-anim" not in argv
OUT_BLEND = os.path.join(Q.REPO, "assets", "vehicles", "src", "QD_Loader.blend")
OUT_GLB = os.path.join(Q.REPO, "assets", "vehicles", "VEH_QD_Loader.glb")

WR = L.WHEEL_R
WX = 0.98
HY = L.HINGE_Y
AXF, AXR = 0.95, -0.85
TW = 0.44
CAB_X0, CAB_X1 = -0.68, 0.68
CAB_Y0, CAB_Y1 = -1.12, -0.12
CAB_ZF, CAB_ZR = 1.06, 2.30
ROOF_T = 0.06
LIFT_X = 0.62
BW = 1.05                                  # bucket half width

Q.reset()
root = empty("QD_Loader", size=0.3)
shake = empty("Shake", root, size=0.15)

# ================================================================================ rear frame, engine, cab
rear = Mesher("Rear", shake, dirt=0.9)
m = rear
m.box((0, -0.85, 0.74), (1.30, 1.70, 0.38), "ExcDark")                                   # rear chassis
m.box((0, AXR, WR), (1.9, 0.18, 0.16), "ExcDark")                                         # rear axle
m.cyl((0, AXR, WR), 0.13, 0.5, 'y', "SteelPlate", seg=8)                                  # differential
for sx in (-1, 1):
    m.box((sx * 0.82, -0.85, 0.95), (0.62, 1.7, 0.05), "CabPaint", top=0.96)              # rear fenders
    m.box((sx * 1.12, -0.85, 0.85), (0.04, 1.7, 0.22), "CabPaint")
    m.box((sx * 0.72, -0.95, 1.12), (0.20, 0.5, 0.20), "ExcDark", top=0.9)                # tool / battery boxes
m.hexa([(-0.82, -1.78, 0.62), (0.82, -1.78, 0.62), (0.82, -1.18, 0.62), (-0.82, -1.18, 0.62),
        (-0.70, -1.72, 1.42), (0.70, -1.72, 1.42), (0.74, -1.18, 1.50), (-0.74, -1.18, 1.50)], "CabPaint")   # engine hood / counterweight
for z in (1.05, 1.15, 1.25):
    m.box((0, -1.795, z), (0.80, 0.02, 0.04), "SteelPlate")
m.box((0, -1.80, 0.80), (1.2, 0.03, 0.10), "Hazard")
for sx in (-1, 1):
    m.box((sx * 0.66, -1.80, 1.20), (0.14, 0.04, 0.08), "LampRed")
for i in range(5):
    m.box((0, -1.40 - i * 0.07, 1.505), (0.9, 0.04, 0.012), "SteelPlate")                  # roof vent slats
m.bar((0.55, -1.30, 1.45), (0.55, -1.30, 2.10), 0.08, 0.08, "ExcDark")                    # exhaust stack
m.box((0.55, -1.30, 2.13), (0.12, 0.12, 0.05), "SteelPlate")
m.box((0, HY - 0.02, 0.85), (0.9, 0.30, 0.55), "ExcDark")                                 # articulation joint housing (rear half)
m.cyl((0, HY, 0.86), 0.12, 0.7, 'z', "SteelPlate", seg=8)                                 # hinge pins
m.box((0, -1.82, 0.50), (0.3, 0.2, 0.14), "ExcDark")                                      # tow hitch
for sx in (-1, 1):
    m.box((sx * 1.0, -0.4, 0.78), (0.20, 0.40, 0.04), "ExcDark")                          # step
    m.box((sx * 1.10, -0.4, 0.78), (0.02, 0.40, 0.05), "Hazard")
rear_obj = m.finish()

cx = (CAB_X0 + CAB_X1) / 2
cw = CAB_X1 - CAB_X0
ZG0, ZG1 = 1.36, CAB_ZR - ROOF_T - 0.03
YF_B, YF_T = CAB_Y1 - 0.01, CAB_Y1 - 0.18
m = Mesher("Cab", shake, dirt=0.8)
m.hexa([(CAB_X0, CAB_Y0, CAB_ZF), (CAB_X1, CAB_Y0, CAB_ZF), (CAB_X1, CAB_Y1, CAB_ZF), (CAB_X0, CAB_Y1, CAB_ZF),
        (CAB_X0 + 0.02, CAB_Y0 + 0.02, 1.38), (CAB_X1 - 0.02, CAB_Y0 + 0.02, 1.38), (CAB_X1 - 0.02, CAB_Y1 - 0.02, 1.38), (CAB_X0 + 0.02, CAB_Y1 - 0.02, 1.38)], "CabPaint")
for x in (CAB_X0 + 0.03, CAB_X1 - 0.03):
    m.bar((x, YF_B, 1.36), (x, YF_T, CAB_ZR - ROOF_T), 0.07, 0.07, "CabPaint", up=(1, 0, 0))
    m.bar((x, CAB_Y0 + 0.03, 1.36), (x, CAB_Y0 + 0.03, CAB_ZR - ROOF_T), 0.07, 0.07, "CabPaint", up=(1, 0, 0))
    m.bar((x, -0.62, 1.38), (x, -0.62, CAB_ZR - ROOF_T), 0.05, 0.05, "CabPaint", up=(1, 0, 0))
m.bar((CAB_X0 + 0.03, YF_B, ZG0 - 0.01), (CAB_X1 - 0.03, YF_B, ZG0 - 0.01), 0.05, 0.05, "ExcDark")
m.bar((CAB_X0 + 0.03, YF_T, CAB_ZR - ROOF_T - 0.02), (CAB_X1 - 0.03, YF_T, CAB_ZR - ROOF_T - 0.02), 0.05, 0.05, "ExcDark")
for x in (CAB_X0 + 0.005, CAB_X1 - 0.005):
    m.bar((x, CAB_Y0 + 0.04, ZG0 - 0.01), (x, YF_B - 0.03, ZG0 - 0.01), 0.05, 0.05, "ExcDark")
    m.bar((x, CAB_Y0 + 0.04, ZG1 + 0.02), (x, YF_T, ZG1 + 0.02), 0.05, 0.05, "ExcDark")
m.bar((CAB_X0 + 0.03, CAB_Y0 + 0.01, ZG0 - 0.01), (CAB_X1 - 0.03, CAB_Y0 + 0.01, ZG0 - 0.01), 0.05, 0.05, "ExcDark")
m.bar((CAB_X0 + 0.03, CAB_Y0 + 0.01, ZG1 + 0.02), (CAB_X1 - 0.03, CAB_Y0 + 0.01, ZG1 + 0.02), 0.05, 0.05, "ExcDark")
m.box((cx, (CAB_Y0 + CAB_Y1) / 2 + 0.03, CAB_ZR - ROOF_T / 2), (cw + 0.10, CAB_Y1 - CAB_Y0 + 0.10, ROOF_T), "CabPaint", top=0.94, topy=0.94)
m.box((cx, CAB_Y1 + 0.05, CAB_ZR - 0.03), (cw + 0.06, 0.10, 0.03), "ExcDark")
m.box((cx, -0.62, CAB_ZR + 0.035), (0.36, 0.30, 0.05), "ExcDark")
for sx in (-1, 1):
    m.box((sx * (CAB_X1 + 0.006), -0.62, 1.20), (0.014, 0.5, 0.28), "ExcDark")
    m.box((sx * (CAB_X1 + 0.02), -0.45, 1.5), (0.03, 0.12, 0.03), "SteelPlate")
    m.bar((sx * (CAB_X1 + 0.05), -0.22, ZG0), (sx * (CAB_X1 + 0.05), -0.22, ZG1 - 0.1), 0.025, 0.025, "SteelPlate")
    m.bar((sx * (CAB_X1 + 0.02), -0.10, 1.9), (sx * (CAB_X1 + 0.18), -0.08, 1.98), 0.025, 0.025, "ExcDark")           # mirror arms
    m.box((sx * (CAB_X1 + 0.20), -0.08, 1.98), (0.05, 0.05, 0.24), "ExcDark")
m.bar((cx - 0.10, YF_B + 0.012, 1.40), (cx + 0.12, YF_T + 0.02, 1.84), 0.015, 0.012, "Rubber", up=(0, 1, 0))
m.finish()
m = Mesher("CabGlass", shake, dirt=0.0)
x0g, x1g, t_ = CAB_X0 + 0.07, CAB_X1 - 0.07, 0.012
m.hexa([(x0g, YF_B, ZG0), (x1g, YF_B, ZG0), (x1g, YF_T, ZG1), (x0g, YF_T, ZG1),
        (x0g, YF_B + t_, ZG0), (x1g, YF_B + t_, ZG0), (x1g, YF_T + t_, ZG1), (x0g, YF_T + t_, ZG1)], "Glass")
for x in (CAB_X0 + 0.006, CAB_X1 - 0.006):
    P.pane_x(m, x, -0.55, YF_T - 0.02, ZG0, ZG1)
    P.pane_x(m, x, CAB_Y0 + 0.07, -0.67, ZG0, ZG1)
m.hexa([(x0g, CAB_Y0 + 0.006, ZG0), (x1g, CAB_Y0 + 0.006, ZG0), (x1g, CAB_Y0 + 0.006, ZG1), (x0g, CAB_Y0 + 0.006, ZG1),
        (x0g, CAB_Y0 + 0.018, ZG0), (x1g, CAB_Y0 + 0.018, ZG0), (x1g, CAB_Y0 + 0.018, ZG1), (x0g, CAB_Y0 + 0.018, ZG1)], "Glass")
m.finish()

m = Mesher("CabInterior", shake, dirt=0.3)
SY = -0.78
m.box((cx, (CAB_Y0 + CAB_Y1) / 2, CAB_ZF + 0.015), (cw - 0.06, CAB_Y1 - CAB_Y0 - 0.06, 0.03), "CabFloor")
m.cyl((0, SY, 1.13), 0.07, 0.15, 'z', "ExcDark", seg=6)
m.box((0, SY, 1.25), (0.46, 0.44, 0.10), "Seat", top=0.96)
for sx in (-1, 1):
    m.box((sx * 0.21, SY, 1.29), (0.05, 0.44, 0.06), "Seat")
m.hexa([(-0.23, SY - 0.20, 1.27), (0.23, SY - 0.20, 1.27), (0.23, SY - 0.13, 1.27), (-0.23, SY - 0.13, 1.27),
        (-0.21, SY - 0.30, 1.80), (0.21, SY - 0.30, 1.80), (0.21, SY - 0.23, 1.80), (-0.21, SY - 0.23, 1.80)], "Seat")
m.box((0, SY - 0.31, 1.90), (0.22, 0.07, 0.14), "Seat")
m.box((0.44, SY + 0.10, 1.20), (0.14, 0.5, 0.20), "ExcDark")                                # right console (joystick)
m.box((0.44, SY + 0.14, 1.305), (0.10, 0.16, 0.02), "Rubber")
m.hexa([(CAB_X0 + 0.06, CAB_Y1 - 0.24, 1.14), (CAB_X1 - 0.06, CAB_Y1 - 0.24, 1.14), (CAB_X1 - 0.06, CAB_Y1 - 0.04, 1.14), (CAB_X0 + 0.06, CAB_Y1 - 0.04, 1.14),
        (CAB_X0 + 0.08, CAB_Y1 - 0.20, 1.34), (CAB_X1 - 0.08, CAB_Y1 - 0.20, 1.34), (CAB_X1 - 0.08, CAB_Y1 - 0.10, 1.38), (CAB_X0 + 0.08, CAB_Y1 - 0.10, 1.38)], "ExcDark")
m.box((0.20, CAB_Y1 - 0.18, 1.42), (0.26, 0.025, 0.12), "ExcDark")
m.box((0.20, CAB_Y1 - 0.195, 1.42), (0.22, 0.008, 0.09), "Screen")
for i in range(4):
    m.box((-0.40 + i * 0.07, CAB_Y1 - 0.15, 1.38), (0.04, 0.02, 0.022), "LampRed" if i == 3 else "SteelPlate")
for i, x in enumerate((-0.18, 0.0, 0.18)):                                                  # pedals
    m.bar((x, CAB_Y1 - 0.38, CAB_ZF + 0.02), (x, CAB_Y1 - 0.28, CAB_ZF + 0.10), 0.08, 0.02, "Rubber", up=(1, 0, 0))
m.finish()
col = empty("SteeringColumn", shake, loc=(0, CAB_Y1 - 0.42, 1.40), rot=(0.62, 0, 0), size=0.06)
mm = Mesher("SteeringWheel", col, dirt=0.2)
for i in range(12):
    a0, a1 = 2 * math.pi * i / 12, 2 * math.pi * (i + 1) / 12
    mm.bar((math.cos(a0) * 0.19, math.sin(a0) * 0.19, 0), (math.cos(a1) * 0.19, math.sin(a1) * 0.19, 0), 0.034, 0.034, "Rubber", up=(0, 0, 1))
for a in (math.pi / 2, math.pi * 7 / 6, math.pi * 11 / 6):
    mm.bar((0, 0, 0), (math.cos(a) * 0.19, math.sin(a) * 0.19, 0), 0.03, 0.025, "ExcDark", up=(0, 0, 1))
wheel_node = mm.finish()
mc = Mesher("SteeringShroud", col, dirt=0.2)
mc.bar((0, 0, 0), (0, 0, -0.32), 0.07, 0.07, "ExcDark")
mc.finish()
mj = Mesher("Joystick", shake, loc=(0.44, SY + 0.14, 1.315), dirt=0.2)
mj.cyl((0, 0, 0.09), 0.013, 0.18, 'z', "Rubber", seg=6)
mj.box((0, 0, 0.19), (0.05, 0.07, 0.08), "Rubber")
joystick = mj.finish()

# ================================================================================ front frame (articulated)
front = empty("Front", shake, loc=(0, HY, 0), size=0.2)
FY = lambda y: y - HY                                   # model y -> Front-local y
m = Mesher("FrontBody", front, dirt=0.9)
m.box((0, FY(0.85), 0.78), (1.30, 1.60, 0.42), "ExcDark")                                     # front frame
m.box((0, FY(AXF), WR), (1.9, 0.18, 0.16), "ExcDark")                                         # front axle
m.cyl((0, FY(AXF), WR), 0.13, 0.5, 'y', "SteelPlate", seg=8)
m.box((0, FY(0.02), 0.85), (0.9, 0.30, 0.55), "ExcDark")                                      # joint housing (front half)
for sx in (-1, 1):
    m.box((sx * 0.82, FY(0.95), 0.98), (0.62, 1.0, 0.05), "CabPaint", top=0.96)                # front fenders
    m.box((sx * 1.12, FY(0.95), 0.88), (0.04, 1.0, 0.22), "CabPaint")
    # tower plates carrying the arm pivot
    m.prism_yz([(FY(0.0), 0.95), (FY(0.62), 0.95), (FY(0.62), 1.30), (FY(0.45), 1.52), (FY(0.15), 1.52), (FY(0.0), 1.30)], sx * 0.72 - 0.04, sx * 0.72 + 0.04, "CabPaint")
    m.box((sx * LIFT_X, FY(L.LIFT_BASE[0]), L.LIFT_BASE[1] - 0.10), (0.14, 0.20, 0.22), "ExcDark")      # lift cylinder base brackets
    m.cyl((sx * LIFT_X, FY(L.LIFT_BASE[0]), L.LIFT_BASE[1]), 0.045, 0.16, 'x', "SteelPlate", seg=6)
m.cyl((0, FY(L.PIVOT[0]), L.PIVOT[1]), 0.07, 1.6, 'x', "SteelPlate", seg=8)                    # arm pivot pin
m.box((0, FY(1.52), 0.72), (1.0, 0.10, 0.30), "ExcDark")                                      # front bumper / weight
m.box((0, FY(1.57), 0.72), (0.6, 0.02, 0.06), "Hazard")
for sx in (-1, 1):
    m.box((sx * 0.50, FY(1.50), 1.05), (0.20, 0.06, 0.12), "ExcDark")
    m.box((sx * 0.50, FY(1.535), 1.05), (0.16, 0.012, 0.09), "LampLens")
front_body = m.finish()

# wheels (spin about X): front wheels hang on the articulated frame, rear wheels on the rear frame
WHEELS = []
def tyre(mm, sx, w):
    mm.cyl((0, 0, 0), WR, w - 0.12, 'x', "Tire", seg=12)
    mm.cyl((sx * (w / 2 - 0.06), 0, 0), WR * 0.78, 0.12, 'x', "Tire", seg=12, r2=WR * 0.94) if sx > 0 else mm.cyl((sx * (w / 2 - 0.06), 0, 0), WR * 0.94, 0.12, 'x', "Tire", seg=12, r2=WR * 0.78)
    mm.cyl((-sx * (w / 2 - 0.06), 0, 0), WR * 0.94, 0.12, 'x', "Tire", seg=12, r2=WR * 0.78) if sx > 0 else mm.cyl((-sx * (w / 2 - 0.06), 0, 0), WR * 0.78, 0.12, 'x', "Tire", seg=12, r2=WR * 0.94)
    for k in range(10):                                                                    # chunky tread lugs
        a = 2 * math.pi * k / 10
        mm.box((0, math.cos(a) * (WR + 0.01), math.sin(a) * (WR + 0.01)), (w - 0.14, 0.06, 0.07), "Tire")
    mm.cyl((0, 0, 0), 0.30, w + 0.02, 'x', "ExcDark", seg=10)
    o = sx * (w / 2 + 0.02)
    mm.cyl((o, 0, 0), 0.17, 0.06, 'x', "SteelPlate", seg=8)
    for k in range(8):
        a = 2 * math.pi * k / 8
        mm.box((o + sx * 0.02, math.cos(a) * 0.22, math.sin(a) * 0.22), (0.04, 0.05, 0.05), "SteelPlate")

for tag, sx in (("L", -1), ("R", 1)):
    mm = Mesher(f"Wheel_F{tag}", front, loc=(sx * WX, FY(AXF), WR), dirt=1.2)
    tyre(mm, sx, TW)
    WHEELS.append(mm.finish())
    mm = Mesher(f"Wheel_R{tag}", shake, loc=(sx * WX, AXR, WR), dirt=1.2)
    tyre(mm, sx, TW)
    WHEELS.append(mm.finish())

# ================================================================================ lift arms + bucket
lift = Mesher("Lift", front, loc=(0, FY(L.PIVOT[0]), L.PIVOT[1]), dirt=1.0)
m = lift
BPv = L.BUCKET_PIVOT
for sx in (-1, 1):
    x = sx * L.ARM_X
    m.bar((x, 0, 0), (x, 0.75, -0.12), 0.17, 0.24, "CabPaint")                                  # arm: rear section
    m.bar((x, 0.75, -0.12), (x, BPv[0], BPv[1]), 0.17, 0.22, "CabPaint")                        # arm: drooping front section
    m.cyl((x, 0, 0), 0.13, 0.22, 'x', "ExcDark", seg=8)                                         # pivot boss
    m.cyl((x, BPv[0], BPv[1]), 0.12, 0.22, 'x', "ExcDark", seg=8)                               # bucket pin boss
    m.bar((x, 0.0, 0.0), (sx * 0.62, L.TILT_BASE[0], L.TILT_BASE[1]), 0.08, 0.10, "ExcDark")     # post up to the tilt cylinder bracket
    m.box((sx * 0.71, L.LIFT_ROD[0], L.LIFT_ROD[1]), (0.12, 0.16, 0.14), "ExcDark")             # lift cylinder lug
m.box((0, 0.62, -0.10), (2 * L.ARM_X - 0.1, 0.14, 0.14), "ExcDark")                            # cross tube
m.box((0, L.TILT_BASE[0], L.TILT_BASE[1] + 0.02), (1.3, 0.10, 0.10), "ExcDark")                 # bracket beam
m.cyl((0, L.TILT_BASE[0], L.TILT_BASE[1]), 0.045, 0.22, 'x', "SteelPlate", seg=6)               # tilt cylinder base pin
m.cyl((sx * LIFT_X, L.LIFT_ROD[0], L.LIFT_ROD[1]), 0.04, 0.2, 'x', "SteelPlate", seg=6)
lift_obj = m.finish()

bucket = Mesher("Bucket", lift_obj, loc=(0, BPv[0], BPv[1]), zbase=0.5, dirt=1.6)
m = bucket
prof = [(0.80, -0.36), (0.62, -0.44), (0.10, -0.46), (-0.28, -0.44), (-0.40, -0.20), (-0.36, 0.30), (-0.24, 0.58), (-0.10, 0.62), (0.18, 0.60), (0.32, 0.30), (0.52, -0.24)]
# shell: floor + back as a thin extruded profile, then side plates
floor = [(0.80, -0.36), (0.62, -0.44), (0.10, -0.46), (-0.28, -0.44), (-0.40, -0.20), (-0.36, 0.30), (-0.24, 0.58), (-0.12, 0.60),
         (-0.18, 0.30), (-0.30, -0.18), (-0.20, -0.36), (0.10, -0.39), (0.62, -0.37), (0.80, -0.32)]
m.prism_yz(floor, -BW, BW, "SteelPlate")
for sx in (-1, 1):
    m.prism_yz([(0.80, -0.36), (0.62, -0.44), (0.10, -0.46), (-0.28, -0.44), (-0.40, -0.20), (-0.36, 0.30), (-0.24, 0.58), (-0.05, 0.60), (0.18, 0.34), (0.50, -0.05)],
               sx * BW - 0.02, sx * BW + 0.02, "SteelPlate")                                       # side plates
    m.box((sx * BW, 0.74, -0.40), (0.08, 0.14, 0.10), "ExcDark")                                   # side cutters
m.box((0, 0.80, -0.36), (2 * BW, 0.10, 0.06), "ExcDark")                                           # cutting edge
for k in range(7):
    m.box((-0.90 + k * 0.30, 0.86, -0.38), (0.10, 0.12, 0.05), "SteelPlate")                      # spade teeth
for x in (-0.6, 0.0, 0.6):
    m.box((x, -0.33, 0.10), (0.08, 0.06, 0.9), "ExcDark")                                          # back ribs
m.box((0, -0.15, 0.62), (2 * BW, 0.10, 0.06), "CabPaint")                                          # top rolled lip
for sx in (-1, 1):
    m.prism_yz([(-0.38, 0.20), (-0.15, 0.20), (-0.05, 0.62), (-0.36, 0.64)], sx * 0.55 - 0.03, sx * 0.55 + 0.03, "CabPaint")     # lug supports
m.cyl((0, 0, 0), 0.07, 1.7, 'x', "SteelPlate", seg=8)
tl = L.TILT_ROD
m.box((0, tl[0], tl[1]), (0.18, 0.12, 0.12), "ExcDark")
m.cyl((0, tl[0], tl[1]), 0.045, 0.24, 'x', "SteelPlate", seg=6)
bucket_obj = m.finish()
empty("Marker_BucketLoad", bucket_obj, (0, 0.18, -0.10))
empty("Marker_Lip", bucket_obj, (0, 0.80, -0.36))
empty("Pin_BucketPivot", lift_obj, (0, BPv[0], BPv[1]))
empty("Pin_Pivot", front, (0, FY(L.PIVOT[0]), L.PIVOT[1]))

# ================================================================================ hydraulics
def cyl(name, parent, loc, d_lo, d_hi, rb=0.07, rr=0.04):
    lb, lr = d_lo - 0.06, d_lo - 0.08
    mb = Mesher(name + "_Barrel", parent, loc=loc, dirt=0.7)
    mb.cyl((0, lb / 2, 0), rb, lb, 'y', "ExcDark", seg=8)
    mb.cyl((0, 0.035, 0), rb * 1.2, 0.07, 'y', "SteelPlate", seg=8)
    mb.cyl((0, 0, 0), 0.04, 0.20, 'x', "SteelPlate", seg=6)
    mb.cyl((0, lb - 0.02, 0), rb * 1.15, 0.05, 'y', "SteelPlate", seg=8)
    mb.cyl((0, lb * 0.5, 0), rb * 1.12, 0.045, 'y', "CabPaint", seg=8)
    barrel = mb.finish()
    mr = Mesher(name + "_Rod", barrel, loc=(0, d_lo, 0), dirt=0.2)
    mr.cyl((0, -lr / 2, 0), rr, lr, 'y', "MetalBrushed", seg=6)
    mr.cyl((0, 0, 0), 0.045, 0.18, 'x', "SteelPlate", seg=6)
    return barrel, mr.finish()

(l_lo, l_hi), (t_lo, t_hi) = L.ranges()
LIFT_CYL = {}
for sx, tag in ((-1, "L"), (1, "R")):
    LIFT_CYL[tag] = cyl(f"LiftCyl_{tag}", front, (sx * LIFT_X, FY(L.LIFT_BASE[0]), L.LIFT_BASE[1]), l_lo, l_hi)
TILT_CYL = cyl("TiltCyl", lift_obj, (0, L.TILT_BASE[0], L.TILT_BASE[1]), t_lo, t_hi, 0.075, 0.045)
for sx, tag in ((-1, "L"), (1, "R")):
    empty(f"Pin_LiftBase_{tag}", front, (sx * LIFT_X, FY(L.LIFT_BASE[0]), L.LIFT_BASE[1]))
    empty(f"Pin_LiftRod_{tag}", lift_obj, (sx * LIFT_X, L.LIFT_ROD[0], L.LIFT_ROD[1]))
empty("Pin_TiltBase", lift_obj, (0, L.TILT_BASE[0], L.TILT_BASE[1]))
empty("Pin_TiltRod", bucket_obj, (0, L.TILT_ROD[0], L.TILT_ROD[1]))

def lamp(name, parent, loc, size=(0.20, 0.06, 0.12)):
    mm = Mesher(name, parent, loc=loc, dirt=0.0)
    mm.box((0, 0, 0), size, "ExcDark")
    mm.box((0, size[1] / 2 + 0.004, 0), (size[0] * 0.8, 0.012, size[2] * 0.75), "LampLens")
    return mm.finish()
lamp("Lamp_Cab", shake, (0.0, CAB_Y1 + 0.13, CAB_ZR + 0.01), (0.5, 0.06, 0.07))
for nm, parent, loc in (("Light_Head_L", front, (-0.50, FY(1.62), 1.05)), ("Light_Head_R", front, (0.50, FY(1.62), 1.05)), ("Light_Rear", shake, (0.0, -1.95, 1.0)),
                        ("Marker_Seat", shake, (0, SY, 1.32)), ("Marker_Eye", shake, (0, SY + 0.12, 1.86)), ("Marker_ExhaustTip", shake, (0.55, -1.30, 2.20))):
    empty(nm, parent, loc)

def hull(name, loc, boxes):
    mm = Mesher(name, root, loc=loc, dirt=0.0)
    for c, s_ in boxes:
        mm.box(c, s_, "ExcDark")
    o = mm.finish(); o.hide_render = True; o.display_type = 'WIRE'
hull("ColHull_Body", (0, 0, 0), [((0, -0.1, 0.85), (2.3, 3.5, 0.9)), ((0, -0.62, 1.75), (1.45, 1.1, 1.2))])

# ================================================================================ pose + animation
def aim_x(obj, ang, d=None):
    obj.rotation_euler = (ang, 0, 0)

def pose(p):
    al, be = p.get("alpha", 0.0), p.get("beta", -p.get("alpha", 0.0))
    shake.location = (0, 0, p.get("vibe", 0.0))
    front.rotation_euler = (0, 0, -p.get("artic", 0.0))
    lift_obj.rotation_euler = (al, 0, 0)
    bucket_obj.rotation_euler = (be, 0, 0)
    ang, d = L.lift(al)
    for tag in ("L", "R"):
        b, r = LIFT_CYL[tag]
        b.rotation_euler = (ang, 0, 0)
        r.location = (0, d, 0)
    ang, d = L.tilt(be)
    TILT_CYL[0].rotation_euler = (ang, 0, 0)
    TILT_CYL[1].location = (0, d, 0)
    for o in WHEELS:
        o.rotation_euler = (-p.get("drive", 0.0) / WR, 0, 0)
    wheel_node.rotation_euler = (0, 0, p.get("artic", 0.0) * 3.0)
    joystick.rotation_euler = (-(al - 0.4) * 0.5, 0, -(be + al) * 0.4)

pose({})
CLIPS = Q.Clips()
if DO_ANIM:
    CLIPS.track(shake, "location")
    for o in (front, lift_obj, bucket_obj, wheel_node, joystick, TILT_CYL[0], *[b for b, r in LIFT_CYL.values()], *WHEELS):
        CLIPS.track(o)
    for o in (TILT_CYL[1], *[r for b, r in LIFT_CYL.values()]):
        CLIPS.track(o, "location")

def smooth(t): return t * t * (3 - 2 * t)
def keyed(keys, t):
    if t <= keys[0][0]: return keys[0][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1: return v0 + (v1 - v0) * smooth((t - t0) / (t1 - t0))
    return keys[-1][1]
def frames(n, step=1): return list(range(1, n + 2, step))

if DO_ANIM:
    def idle(f):
        t = (f - 1) / 24
        pose({"vibe": 0.003 * math.sin(t * 6 * math.pi) + 0.0012 * math.sin(t * 14 * math.pi)})
    CLIPS.bake("Idle", frames(24), idle)
    def start(f):
        t = (f - 1) / 54
        env = keyed([(0, 0.0), (0.15, 1.0), (0.55, 1.0), (0.7, 0.4), (1.0, 0.2)], t)
        pose({"vibe": (0.006 * math.sin(t * 90) + 0.003 * math.sin(t * 57)) * env * (0.3 if t > 0.55 else 1.0)})
    CLIPS.bake("EngineStart", frames(54), start)
    def stop(f):
        t = (f - 1) / 45
        env = keyed([(0, 0.2), (0.4, 0.5), (0.8, 0.12), (1.0, 0.0)], t)
        pose({"vibe": (0.005 * math.sin(t * 70) + 0.003 * math.sin(t * 43)) * env - 0.003 * smooth(min(1.0, t * 1.4))})
    CLIPS.bake("EngineStop", frames(45), stop)
    def liftclip(f):
        t = (f - 1) / 120
        pose({"alpha": keyed([(0, 0), (0.45, L.LIFT_MAX), (0.55, L.LIFT_MAX), (1, 0)], t)})
    CLIPS.bake("LiftUpDown", frames(120), liftclip)
    def tiltclip(f):
        t = (f - 1) / 120
        pose({"alpha": 0.3, "beta": keyed([(0, -0.3), (0.3, L.TILT_MAX), (0.7, L.TILT_MIN), (1, -0.3)], t)})
    CLIPS.bake("BucketTilt", frames(120), tiltclip)
    def steerclip(f):
        t = (f - 1) / 90
        pose({"artic": keyed([(0, 0), (0.25, L.ARTIC_MAX), (0.5, 0), (0.75, -L.ARTIC_MAX), (1, 0)], t), "drive": 0.8 * t})
    CLIPS.bake("Steer", frames(90, 2), steerclip)
    def scoop(f):
        t = (f - 1) / 240
        al = keyed([(0, 0.0), (0.45, 0.0), (0.6, 0.0), (0.85, 0.85), (1, 0.85)], t)
        be = keyed([(0, -0.05), (0.45, -0.05), (0.6, -0.95), (0.85, -0.95 - 0.0), (1, -0.95)], t)
        dist = keyed([(0, 0), (0.1, 0), (0.45, 2.0), (1, 2.0)], t)
        pose({"alpha": al, "beta": be, "drive": dist, "vibe": 0.004 * math.sin(f * 0.9) if 0.1 < t < 0.6 else 0.0})
    CLIPS.bake("ScoopCycle", frames(240), scoop)
    def dumpclip(f):
        t = (f - 1) / 180
        al = keyed([(0, 0.85), (0.5, 0.85), (1, 0.0)], t)
        be = keyed([(0, -0.95), (0.25, -0.95), (0.4, 0.2), (0.6, 0.2), (0.75, -0.9), (1, -0.1)], t)
        pose({"alpha": al, "beta": be})
    CLIPS.bake("DumpCycle", frames(180), dumpclip)
    def drive(f):
        t = (f - 1) / 24
        pose({"drive": 1.6 * t, "vibe": 0.004 * math.sin(t * 8 * math.pi)})
    CLIPS.bake("Drive", frames(24), drive)

pose({})
for o in bpy.data.objects:
    if o.animation_data:
        o.animation_data.action = None
os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
if DO_EXPORT:
    Q.export_glb(OUT_GLB)
    print("GLB", OUT_GLB, os.path.getsize(OUT_GLB), "bytes")
print("BUILD_OK", len([o for o in bpy.data.objects if o.type == 'MESH']), "meshes")
