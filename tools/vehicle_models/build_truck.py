"""QUARRY DAYS - six-wheel dump truck (Blender 5.x, headless). Same pipeline as build_excavator.py.

    blender -b --factory-startup -P tools/vehicle_models/build_truck.py -- [--no-export] [--no-anim]

Output: assets/vehicles/src/QD_DumpTruck.blend and assets/vehicles/VEH_QD_DumpTruck.glb (Y up, faces -Z, ground at 0, centred).
Hierarchy: root > [Axles, wheels (unsprung: Steer_L/R > Wheel_FL/FR, Wheel_R1L.. spin)] and Sprung (chassis, cab, bed - the game
bounces it on the suspension) > Bed (hinge at the rear, tips) > Tailgate (hinged at the top, swings open) and a telescoping tipping ram
(barrel on the chassis, rod pinned under the bed) whose pins stay connected for any bed angle (truck_kin.py).
"""
import bpy, math, os, sys
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import qd_blender as Q
import truck_kin as T
from qd_blender import Mesher, empty

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
DO_EXPORT = "--no-export" not in argv
DO_ANIM = "--no-anim" not in argv
OUT_BLEND = os.path.join(Q.REPO, "assets", "vehicles", "src", "QD_DumpTruck.blend")
OUT_GLB = os.path.join(Q.REPO, "assets", "vehicles", "VEH_QD_DumpTruck.glb")

WR = T.WHEEL_R
WX = 0.90                                  # wheel centre x
TW_F, TW_R = 0.40, 0.48                    # tyre widths
HX, HY, HZ = 0.0, T.HINGE[0], T.HINGE[1]   # bed hinge
CAB_X0, CAB_X1 = -0.95, 0.95
CAB_Y0, CAB_Y1 = 0.86, 1.78
CAB_ZF, CAB_ZR = 0.98, 2.25
ROOF_T = 0.06
SEAT = (-0.46, 1.16)                       # seat centre (x, y): left-hand drive

Q.reset()
root = empty("QD_DumpTruck", size=0.3)
sprung = empty("Sprung", root, size=0.2)          # code-driven suspension (pitch / roll / bounce)
shake = empty("Shake", sprung, size=0.15)         # clip-driven engine vibration; everything sprung hangs from it

# ================================================================================ axles, springs, steering linkage (unsprung)
m = Mesher("Axles", root, dirt=1.0)
for name, y in T.AXLES.items():
    m.box((0, y, WR), (1.72, 0.16, 0.14), "ExcDark")                                   # axle beam
    m.cyl((0, y, WR), 0.10, 0.34, 'y', "SteelPlate", seg=8)                              # differential / centre hub (axis along travel)
    for sx in (-1, 1):
        m.box((sx * 0.55, y, 0.58), (0.10, 0.95 if name != "F" else 0.85, 0.05), "SteelPlate")   # leaf-spring packs
        m.box((sx * 0.55, y, 0.54), (0.10, 0.75 if name != "F" else 0.70, 0.04), "SteelPlate")
        m.box((sx * 0.55, y, 0.535 + 0.0), (0.16, 0.12, 0.10), "ExcDark")               # spring seat on the axle
m.bar((-0.62, T.AXLES["F"] - 0.22, 0.40), (0.62, T.AXLES["F"] - 0.22, 0.40), 0.05, 0.05, "SteelPlate")   # tie rod
m.finish()

# ================================================================================ wheels
WHEELS = []
def tyre(mm, sx, width):
    mm.cyl((0, 0, 0), WR, width - 0.10, 'x', "Tire", seg=10)                              # tread band
    for s2 in (-1, 1):
        mm.cyl((s2 * (width / 2 - 0.05), 0, 0), WR * 0.93, 0.10, 'x', "Tire", seg=10, r2=WR * 0.80) if s2 > 0 else mm.cyl((s2 * (width / 2 - 0.05), 0, 0), WR * 0.80, 0.10, 'x', "Tire", seg=10, r2=WR * 0.93)
    mm.cyl((0, 0, 0), 0.27, width + 0.02, 'x', "ExcDark", seg=10)                         # rim
    o = sx * (width / 2 + 0.02)
    mm.cyl((o, 0, 0), 0.16, 0.06, 'x', "SteelPlate", seg=8)                               # hub cap
    for i in range(8):                                                                    # lug nuts
        a = 2 * math.pi * i / 8
        mm.box((o + sx * 0.02, math.cos(a) * 0.2, math.sin(a) * 0.2), (0.04, 0.045, 0.045), "SteelPlate")

for tag, sx in (("L", -1), ("R", 1)):
    st = empty(f"Steer_{tag}", root, loc=(sx * WX, T.AXLES["F"], WR), size=0.1)
    mm = Mesher(f"Wheel_F{tag}", st, dirt=1.2)
    tyre(mm, sx, TW_F)
    WHEELS.append(mm.finish())
    for ax, nm in (("R1", "R1"), ("R2", "R2")):
        mm = Mesher(f"Wheel_{nm}{tag}", root, loc=(sx * WX, T.AXLES[ax], WR), dirt=1.2)
        tyre(mm, sx, TW_R)
        WHEELS.append(mm.finish())
steer_l, steer_r = bpy.data.objects["Steer_L"], bpy.data.objects["Steer_R"]

# ================================================================================ chassis (sprung)
m = Mesher("Chassis", shake, dirt=1.0)
for sx in (-1, 1):
    x = sx * 0.55
    m.box((x, -0.1, 0.62), (0.16, 4.5, 0.05), "ExcDark")                                 # rail: web
    m.box((x, -0.1, 0.70), (0.16, 4.5, 0.05), "ExcDark")                                 # top flange
    m.box((x, -0.1, 0.545), (0.16, 4.5, 0.05), "ExcDark")                                # bottom flange
    m.box((sx * 0.36, -0.9, 0.80), (0.20, 2.9, 0.18), "ExcDark")                           # sub-frame runner under the bed
for y in (-2.12, -1.25, -0.35, 0.55, 1.45):
    m.box((0, y, 0.62), (1.10, 0.10, 0.10), "ExcDark")                                   # cross-members
m.box((0, -2.28, 0.62), (1.7, 0.10, 0.26), "SteelPlate")                                 # rear bumper beam
m.box((0, -2.30, 0.50), (0.14, 0.12, 0.12), "ExcDark")                                   # tow pin
for sx in (-1, 1):
    m.box((sx * 0.83, -2.31, 0.96), (0.24, 0.05, 0.10), "LampRed")                         # tail lights
    m.box((sx * 0.90, -2.04, 0.36), (0.44, 0.015, 0.36), "Rubber")                         # mud flaps behind the tandem
    m.box((sx * 0.90, 1.18, 0.36), (0.44, 0.015, 0.34), "Rubber")                          # and behind the front wheels
# fenders over every wheel: paint slab with a lipped front
for sx in (-1, 1):
    for nm, y, ln in (("F", T.AXLES["F"], 0.98), ("R", -1.25, 1.95)):
        z = 0.97 if nm == "F" else 0.93
        m.box((sx * 0.88, y, z), (0.60, ln, 0.05), "CabPaint" if nm == "F" else "BedPaint", top=0.96)
        m.box((sx * 1.16, y, z - 0.06), (0.05, ln, 0.16), "CabPaint" if nm == "F" else "BedPaint")
# fuel tank (right), battery box (left), air tanks, exhaust stack
m.cyl((0.74, 0.05, 0.50), 0.22, 1.0, 'y', "SteelPlate", seg=8)
for yy in (-0.35, 0.45):
    m.box((0.74, yy, 0.50), (0.50, 0.05, 0.10), "ExcDark")                               # tank straps
m.box((-0.74, 0.05, 0.50), (0.40, 0.50, 0.30), "ExcDark")                                # battery box
m.cyl((-0.70, -0.55, 0.43), 0.10, 0.60, 'x', "ExcDark", seg=6)                           # air tank
# hydraulic power-take-off pump + ram mount: cross-member bracket with the base pin
bx, by = T.RAM_BASE
m.box((0, by, 0.62), (0.46, 0.18, 0.08), "ExcDark")
for sx in (-1, 1):
    m.box((sx * 0.13, by, by * 0 + T.RAM_BASE[1] + 0.02), (0.05, 0.16, 0.16), "ExcDark")  # clevis ears
m.cyl((0, by, T.RAM_BASE[1]), 0.04, 0.34, 'x', "SteelPlate", seg=6)
# hinge brackets at the rear + pin
for sx in (-1, 1):
    m.box((sx * 0.40, HY + 0.02, HZ - 0.12), (0.12, 0.26, 0.22), "ExcDark")
m.cyl((0, HY, HZ), 0.07, 1.10, 'x', "SteelPlate", seg=8)
# exhaust stack behind the cab (right)
m.bar((0.99, 0.80, 0.9), (0.99, 0.80, 2.45), 0.09, 0.09, "ExcDark")
m.box((0.99, 0.80, 2.50), (0.13, 0.13, 0.06), "SteelPlate")
m.box((0.99, 0.86, 1.20), (0.12, 0.02, 0.05), "SteelPlate")
m.finish()

# ================================================================================ cab (sprung)
cx = (CAB_X0 + CAB_X1) / 2
cw = CAB_X1 - CAB_X0
ZG0, ZG1 = 1.36, CAB_ZR - ROOF_T - 0.03
YW_B, YW_T = CAB_Y1 - 0.02, CAB_Y1 - 0.22              # windscreen leans back
m = Mesher("Cab", shake, dirt=0.9)
m.hexa([(CAB_X0, CAB_Y0, CAB_ZF), (CAB_X1, CAB_Y0, CAB_ZF), (CAB_X1, CAB_Y1, CAB_ZF), (CAB_X0, CAB_Y1, CAB_ZF),
        (CAB_X0 + 0.02, CAB_Y0 + 0.02, 1.38), (CAB_X1 - 0.02, CAB_Y0 + 0.02, 1.38), (CAB_X1 - 0.02, CAB_Y1 - 0.02, 1.38), (CAB_X0 + 0.02, CAB_Y1 - 0.02, 1.38)], "CabPaint")   # lower body
for x in (CAB_X0 + 0.03, CAB_X1 - 0.03):
    m.bar((x, YW_B, 1.36), (x, YW_T, CAB_ZR - ROOF_T), 0.07, 0.07, "CabPaint", up=(1, 0, 0))     # raked A pillars
    m.bar((x, CAB_Y0 + 0.03, 1.36), (x, CAB_Y0 + 0.03, CAB_ZR - ROOF_T), 0.07, 0.07, "CabPaint", up=(1, 0, 0))   # rear pillars
    m.bar((x, 1.30, 1.38), (x, 1.30, CAB_ZR - ROOF_T), 0.05, 0.05, "CabPaint", up=(1, 0, 0))          # door posts
# glass surrounds
m.bar((CAB_X0 + 0.03, YW_B, ZG0 - 0.01), (CAB_X1 - 0.03, YW_B, ZG0 - 0.01), 0.05, 0.05, "ExcDark")
m.bar((CAB_X0 + 0.03, YW_T, CAB_ZR - ROOF_T - 0.02), (CAB_X1 - 0.03, YW_T, CAB_ZR - ROOF_T - 0.02), 0.05, 0.05, "ExcDark")
for x in (CAB_X0 + 0.005, CAB_X1 - 0.005):
    m.bar((x, CAB_Y0 + 0.04, ZG0 - 0.01), (x, YW_B - 0.03, ZG0 - 0.01), 0.05, 0.05, "ExcDark")
    m.bar((x, CAB_Y0 + 0.04, ZG1 + 0.02), (x, YW_T, ZG1 + 0.02), 0.05, 0.05, "ExcDark")
m.bar((CAB_X0 + 0.03, CAB_Y0 + 0.01, ZG0 - 0.01), (CAB_X1 - 0.03, CAB_Y0 + 0.01, ZG0 - 0.01), 0.05, 0.05, "ExcDark")
m.bar((CAB_X0 + 0.03, CAB_Y0 + 0.01, ZG1 + 0.02), (CAB_X1 - 0.03, CAB_Y0 + 0.01, ZG1 + 0.02), 0.05, 0.05, "ExcDark")
# roof with a visor + sun shade, and a roof lamp bar
m.box((cx, (CAB_Y0 + CAB_Y1) / 2 + 0.04, CAB_ZR - ROOF_T / 2), (cw + 0.10, CAB_Y1 - CAB_Y0 + 0.10, ROOF_T), "CabPaint", top=0.95, topy=0.94)
m.box((cx, CAB_Y1 + 0.02, CAB_ZR - 0.05), (cw + 0.06, 0.10, 0.03), "ExcDark")
m.box((cx, 1.20, CAB_ZR + 0.03), (0.60, 0.26, 0.05), "ExcDark")                           # roof vent
# hood, grille, bumper
m.hexa([(-0.78, CAB_Y1, 0.80), (0.78, CAB_Y1, 0.80), (0.74, 2.30, 0.80), (-0.74, 2.30, 0.80),
        (-0.70, CAB_Y1, 1.44), (0.70, CAB_Y1, 1.44), (0.64, 2.30, 1.26), (-0.64, 2.30, 1.26)], "CabPaint")
m.box((0, 2.315, 1.02), (1.28, 0.04, 0.46), "ExcDark")                                      # grille
for z in (0.88, 0.96, 1.04, 1.12, 1.20):
    m.box((0, 2.34, z), (1.10, 0.02, 0.025), "SteelPlate")
m.box((0, 2.33, 0.66), (2.0, 0.17, 0.20), "SteelPlate")                                      # bumper
m.box((0, 2.34, 0.66), (1.2, 0.02, 0.06), "Hazard")
m.box((0.0, 1.795, 1.30), (0.34, 0.02, 0.05), "SteelPlate")                                  # hood hinge
# doors: panel lines + handles + steps
for sx in (-1, 1):
    m.box((sx * (CAB_X1 + 0.006), 1.22, 1.12), (0.014, 0.52, 0.30), "ExcDark")
    m.box((sx * (CAB_X1 + 0.02), 1.02, 1.32), (0.03, 0.12, 0.03), "SteelPlate")
    m.box((sx * (CAB_X1 + 0.10), 1.28, 0.82), (0.22, 0.44, 0.04), "ExcDark")                 # step
    m.box((sx * (CAB_X1 + 0.20), 1.28, 0.82), (0.02, 0.44, 0.045), "Hazard")
    m.bar((sx * (CAB_X1 + 0.06), 1.05, ZG0 + 0.0), (sx * (CAB_X1 + 0.06), 1.05, ZG1 - 0.1), 0.025, 0.025, "SteelPlate")   # grab handle
    m.bar((sx * (CAB_X1 + 0.02), 1.78, 1.85), (sx * (CAB_X1 + 0.20), 1.80, 1.95), 0.025, 0.025, "ExcDark")               # mirror arm
    m.box((sx * (CAB_X1 + 0.22), 1.80, 1.95), (0.05, 0.05, 0.26), "ExcDark")                                           # mirror head
    m.box((sx * (CAB_X1 + 0.22), 1.775, 1.95), (0.04, 0.01, 0.22), "MetalBrushed")
cab_body = m.finish()

def pane_x(mm, x, y0, y1, zb, zt, t=0.012):
    return mm.hexa([(x - t / 2, y0, zb), (x - t / 2, y1, zb), (x - t / 2, y1, zt), (x - t / 2, y0, zt),
                    (x + t / 2, y0, zb), (x + t / 2, y1, zb), (x + t / 2, y1, zt), (x + t / 2, y0, zt)], "Glass")

m = Mesher("CabGlass", shake, dirt=0.0)
x0g, x1g = CAB_X0 + 0.07, CAB_X1 - 0.07
t_ = 0.012
m.hexa([(x0g, YW_B, ZG0), (x1g, YW_B, ZG0), (x1g, YW_T, ZG1), (x0g, YW_T, ZG1),
        (x0g, YW_B + t_, ZG0), (x1g, YW_B + t_, ZG0), (x1g, YW_T + t_, ZG1), (x0g, YW_T + t_, ZG1)], "Glass")
for x in (CAB_X0 + 0.006, CAB_X1 - 0.006):
    pane_x(m, x, 1.34, YW_T - 0.02, ZG0, ZG1)                                          # door windows
    pane_x(m, x, CAB_Y0 + 0.07, 1.26, ZG0, ZG1)
m.hexa([(x0g, CAB_Y0 + 0.006, ZG0), (x1g, CAB_Y0 + 0.006, ZG0), (x1g, CAB_Y0 + 0.006, ZG1), (x0g, CAB_Y0 + 0.006, ZG1),
        (x0g, CAB_Y0 + 0.018, ZG0), (x1g, CAB_Y0 + 0.018, ZG0), (x1g, CAB_Y0 + 0.018, ZG1), (x0g, CAB_Y0 + 0.018, ZG1)], "Glass")
m.finish()

# interior: seat, dash, pedals, gear stick, hand brake, hoist lever
m = Mesher("CabInterior", shake, dirt=0.4)
m.box((cx, (CAB_Y0 + CAB_Y1) / 2, CAB_ZF + 0.015), (cw - 0.06, CAB_Y1 - CAB_Y0 - 0.06, 0.03), "CabFloor")     # floor mat
SX, SY = SEAT
m.cyl((SX, SY, 1.06), 0.07, 0.15, 'z', "ExcDark", seg=6)
m.box((SX, SY, 1.18), (0.46, 0.44, 0.10), "Seat", top=0.96)                              # cushion
for sx in (-1, 1):
    m.box((SX + sx * 0.21, SY, 1.22), (0.05, 0.44, 0.06), "Seat")
m.hexa([(SX - 0.23, SY - 0.20, 1.20), (SX + 0.23, SY - 0.20, 1.20), (SX + 0.23, SY - 0.13, 1.20), (SX - 0.23, SY - 0.13, 1.20),
        (SX - 0.21, SY - 0.30, 1.72), (SX + 0.21, SY - 0.30, 1.72), (SX + 0.21, SY - 0.23, 1.72), (SX - 0.21, SY - 0.23, 1.72)], "Seat")      # backrest
m.box((SX, SY - 0.31, 1.82), (0.22, 0.07, 0.14), "Seat")                                # headrest
m.box((SX + 0.28, SY - 0.02, 1.34), (0.05, 0.28, 0.04), "Rubber")                       # armrest
# dashboard binnacle with instrument cluster and a screen
m.hexa([(CAB_X0 + 0.06, CAB_Y1 - 0.30, 1.14), (CAB_X1 - 0.06, CAB_Y1 - 0.30, 1.14), (CAB_X1 - 0.06, CAB_Y1 - 0.04, 1.14), (CAB_X0 + 0.06, CAB_Y1 - 0.04, 1.14),
        (CAB_X0 + 0.08, CAB_Y1 - 0.26, 1.40), (CAB_X1 - 0.08, CAB_Y1 - 0.26, 1.40), (CAB_X1 - 0.08, CAB_Y1 - 0.12, 1.46), (CAB_X0 + 0.08, CAB_Y1 - 0.12, 1.46)], "ExcDark")
m.box((SX, CAB_Y1 - 0.25, 1.40), (0.34, 0.03, 0.12), "ExcDark")                          # instrument hood
for gx in (-0.07, 0.07):
    m.cyl((SX + gx, CAB_Y1 - 0.268, 1.40), 0.045, 0.012, 'y', "SteelPlate", seg=8)           # gauges
m.box((0.30, CAB_Y1 - 0.20, 1.44), (0.24, 0.025, 0.14), "ExcDark")
m.box((0.30, CAB_Y1 - 0.215, 1.44), (0.20, 0.008, 0.11), "Screen")
for i in range(4):
    m.box((0.05 + i * 0.07, CAB_Y1 - 0.19, 1.38), (0.04, 0.02, 0.022), "LampRed" if i == 3 else "SteelPlate")
# floor pedals (clutch, brake, accelerator) and levers
for i, x in enumerate((SX - 0.14, SX, SX + 0.17)):
    m.bar((x, CAB_Y1 - 0.40, CAB_ZF + 0.02), (x, CAB_Y1 - 0.30, CAB_ZF + 0.10), 0.07 if i < 2 else 0.05, 0.02, "Rubber", up=(1, 0, 0))
    m.box((x, CAB_Y1 - 0.42, CAB_ZF + 0.03), (0.05, 0.04, 0.04), "ExcDark")
m.cyl((0.0, 1.34, 1.18), 0.014, 0.30, 'z', "ExcDark", seg=6)                            # gear stick
m.box((0.0, 1.34, 1.34), (0.05, 0.05, 0.05), "Rubber")
m.bar((SX + 0.36, 1.16, 1.20), (SX + 0.36, 1.30, 1.42), 0.03, 0.03, "ExcDark")           # hand brake
m.bar((SX + 0.30, 0.98, 1.20), (SX + 0.30, 1.06, 1.46), 0.025, 0.025, "ExcDark")         # bed-hoist lever
m.box((SX + 0.30, 1.07, 1.47), (0.04, 0.04, 0.05), "LampRed")
m.box((0.62, 0.96, 1.46), (0.16, 0.05, 0.10), "ExcDark")                                  # radio
m.finish()

# steering column (tilted) + wheel (spins about its own axis)
col = empty("SteeringColumn", shake, loc=(SX, SY + 0.40, 1.46), rot=(0.55, 0, 0), size=0.06)
mm = Mesher("SteeringWheel", col, dirt=0.2)
for i in range(12):
    a0, a1 = 2 * math.pi * i / 12, 2 * math.pi * (i + 1) / 12
    mm.bar((math.cos(a0) * 0.20, math.sin(a0) * 0.20, 0.0), (math.cos(a1) * 0.20, math.sin(a1) * 0.20, 0.0), 0.034, 0.034, "Rubber", up=(0, 0, 1))
for a in (math.pi / 2, math.pi * 7 / 6, math.pi * 11 / 6):
    mm.bar((0, 0, 0), (math.cos(a) * 0.20, math.sin(a) * 0.20, 0.0), 0.03, 0.025, "ExcDark", up=(0, 0, 1))
mm.cyl((0, 0, 0), 0.045, 0.05, 'z', "ExcDark", seg=8)
wheel_obj = mm.finish()
mc = Mesher("SteeringShroud", col, dirt=0.2)
mc.bar((0, 0, 0), (0, 0, -0.34), 0.07, 0.07, "ExcDark")
shroud = mc.finish()

# headlights + lamps (emissive lenses), light markers
def lamp(name, loc, size=(0.22, 0.06, 0.14), rot=(0, 0, 0)):
    mm = Mesher(name, shake, loc=loc, rot=rot, dirt=0.0)
    mm.box((0, 0, 0), size, "ExcDark")
    mm.box((0, size[1] / 2 + 0.004, 0), (size[0] * 0.8, 0.012, size[2] * 0.75), "LampLens")
    return mm.finish()
lamp("Lamp_Head_L", (-0.80, 2.28, 1.02))
lamp("Lamp_Head_R", (0.80, 2.28, 1.02))
lamp("Lamp_Cab", (0.0, CAB_Y1 + 0.14, CAB_ZR + 0.01), (0.5, 0.06, 0.07))
for nm, loc in (("Light_Head_L", (-0.80, 2.40, 1.02)), ("Light_Head_R", (0.80, 2.40, 1.02)), ("Light_Rear", (0.0, -2.45, 1.0)),
                ("Marker_Seat", (SEAT[0], SEAT[1], 1.24)), ("Marker_Eye", (SEAT[0], SEAT[1] + 0.12, 1.78)), ("Marker_ExhaustTip", (0.99, 0.80, 2.56))):
    empty(nm, shake, loc)

# ================================================================================ tipping bed (origin = hinge)
bed = Mesher("Bed", shake, loc=(HX, HY, HZ), zbase=1.4, dirt=1.3)
m = bed
BL = 2.92                                                             # bed length from the hinge
side = [(0.0, 0.10), (BL, 0.10), (BL, 1.08), (1.8, 0.96), (0.0, 0.88)]
m.box((0, BL / 2, 0.06), (2.0, BL, 0.12), "BedPaint")                  # floor
for sx in (-1, 1):
    m.prism_yz(side, sx * 1.0 - 0.04, sx * 1.0 + 0.04, "BedPaint")      # sides
    for y in (0.35, 1.05, 1.75, 2.45):
        m.box((sx * 1.05, y, 0.50), (0.05, 0.08, 0.74), "SteelPlate")   # side ribs
    m.bar((sx * 1.04, 0.0, 0.90), (sx * 1.04, 1.8, 0.98), 0.07, 0.07, "ExcDark")      # top rails
    m.bar((sx * 1.04, 1.8, 0.98), (sx * 1.04, BL, 1.10), 0.07, 0.07, "ExcDark")
    m.box((sx * 1.05, 0.04, 0.46), (0.10, 0.10, 0.18), "SteelPlate")                  # tailgate hinge lugs
m.box((0, BL - 0.05, 0.60), (2.0, 0.10, 1.00), "BedPaint")               # headboard
m.box((0, BL - 0.30, 1.12), (1.96, 0.5, 0.05), "BedPaint")               # cab guard canopy
m.bar((-0.95, BL - 0.10, 1.08), (-0.95, BL - 0.50, 1.12), 0.05, 0.05, "ExcDark")
m.bar((0.95, BL - 0.10, 1.08), (0.95, BL - 0.50, 1.12), 0.05, 0.05, "ExcDark")
m.box((0, BL - 0.0, 0.98), (2.0, 0.03, 0.08), "Hazard")
for y in (0.35, 1.0, 1.65, 2.3):
    m.box((0, y, -0.02), (2.0, 0.12, 0.10), "ExcDark")                                 # under-floor cross beams
for sx in (-1, 1):
    m.box((sx * 0.45, BL / 2, -0.02), (0.14, BL, 0.10), "ExcDark")                      # long beams
for sx in (-1, 1):
    m.box((sx * 0.40, 0.0, 0.0), (0.14, 0.24, 0.20), "ExcDark")                         # hinge knuckles
m.cyl((0, 0, 0), 0.075, 0.95, 'x', "SteelPlate", seg=8)
rl = T.RAM_ROD
for sx in (-1, 1):
    m.prism_yz([(rl[0] - 0.16, 0.0), (rl[0] + 0.16, 0.0), (rl[0] + 0.07, rl[1] - 0.03), (rl[0] - 0.07, rl[1] - 0.03)], sx * 0.10 - 0.025, sx * 0.10 + 0.025, "ExcDark")   # rod lugs
m.cyl((0, rl[0], rl[1]), 0.04, 0.28, 'x', "SteelPlate", seg=6)
bed_obj = m.finish()
# tailgate (origin = its top hinge, hangs down)
gate = Mesher("Tailgate", bed_obj, loc=(0.0, 0.06, 0.90), zbase=1.0, dirt=1.4)
m = gate
m.box((0, 0.0, -0.40), (1.94, 0.06, 0.78), "BedPaint")
m.box((0, -0.04, -0.40), (1.7, 0.03, 0.06), "ExcDark")
m.box((0, -0.04, -0.22), (1.7, 0.03, 0.05), "ExcDark")
m.box((0, -0.04, -0.58), (1.7, 0.03, 0.05), "ExcDark")
m.box((0, 0.0, -0.76), (1.94, 0.04, 0.06), "Hazard")
m.cyl((0, 0, 0), 0.04, 2.0, 'x', "SteelPlate", seg=6)                                   # hinge rod
for sx in (-1, 1):
    m.cyl((sx * 0.95, 0.0, -0.30), 0.03, 0.12, 'y', "SteelPlate", seg=6)                # latch pins
gate_obj = m.finish()
empty("Marker_BedLoad", bed_obj, (0, 1.45, 0.14))
empty("Marker_Dust", bed_obj, (0, -0.15, 0.05))
empty("Pin_RamRod", bed_obj, (0, T.RAM_ROD[0], T.RAM_ROD[1]))
empty("Pin_RamBase", shake, (0, T.RAM_BASE[0], T.RAM_BASE[1]))
empty("Pin_BedHinge", shake, (0, T.HINGE[0], T.HINGE[1]))

# tipping ram: barrel (origin = base pin) + rod (origin = rod-end pin, slides along the barrel)
d_lo, d_hi = T.ram_range()
lb, lr = d_lo - 0.07, d_lo - 0.09
mb = Mesher("BedCyl_Barrel", shake, loc=(0, T.RAM_BASE[0], T.RAM_BASE[1]), dirt=0.7)
mb.cyl((0, lb / 2, 0), 0.085, lb, 'y', "ExcDark", seg=8)
mb.cyl((0, 0.04, 0), 0.10, 0.08, 'y', "SteelPlate", seg=8)
mb.cyl((0, 0, 0), 0.05, 0.24, 'x', "SteelPlate", seg=6)
mb.cyl((0, lb - 0.02, 0), 0.095, 0.06, 'y', "SteelPlate", seg=8)
mb.cyl((0, lb * 0.5, 0), 0.092, 0.05, 'y', "BedPaint", seg=8)
barrel = mb.finish()
mr = Mesher("BedCyl_Rod", barrel, loc=(0, d_lo, 0), dirt=0.2)
mr.cyl((0, -lr / 2, 0), 0.05, lr, 'y', "MetalBrushed", seg=6)
mr.cyl((0, 0, 0), 0.055, 0.20, 'x', "SteelPlate", seg=6)
rod = mr.finish()

# ================================================================================ collision proxies (hidden by the rig)
def hull(name, parent, loc, boxes):
    mm = Mesher(name, parent, loc=loc, dirt=0.0)
    for c, s_ in boxes:
        mm.box(c, s_, "ExcDark")
    o = mm.finish(); o.hide_render = True; o.display_type = 'WIRE'
hull("ColHull_Chassis", root, (0, 0, 0), [((0, -0.1, 0.62), (2.1, 4.6, 0.4))])
hull("ColHull_Cab", root, (0, 0, 0), [((0, 1.3, 1.6), (1.95, 1.0, 1.3)), ((0, 2.0, 1.0), (1.5, 0.6, 0.6))])
hull("ColHull_Bed", root, (0, 0, 0), [((0, -0.7, 1.55), (2.1, 3.0, 1.1))])

# ================================================================================ pose + animation
def pose(p):
    """p: dict(bed, drive, steer, vibe, roll, pitch)"""
    th = p.get("bed", 0.0)
    shake.location = (0, 0, p.get("vibe", 0.0))
    shake.rotation_euler = (p.get("pitch", 0.0), p.get("roll", 0.0), 0)
    bed_obj.rotation_euler = (th, 0, 0)
    gate_obj.rotation_euler = (T.gate(th), 0, 0)
    ang, d = T.ram(th)
    barrel.rotation_euler = (ang, 0, 0)
    rod.location = (0, d, 0)
    st = p.get("steer", 0.0)
    steer_l.rotation_euler = (0, 0, st); steer_r.rotation_euler = (0, 0, st)
    wheel_obj.rotation_euler = (0, 0, -st * T.STEER_RATIO)
    for o in WHEELS:
        o.rotation_euler = (-p.get("drive", 0.0) / WR, 0, 0)

pose({})
CLIPS = Q.Clips()
if DO_ANIM:
    CLIPS.track(shake, "location", "rotation_euler")
    for o in (bed_obj, gate_obj, barrel, steer_l, steer_r, wheel_obj, *WHEELS):
        CLIPS.track(o)
    CLIPS.track(rod, "location")

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
        pose({"vibe": 0.003 * math.sin(t * 6 * math.pi) + 0.0012 * math.sin(t * 14 * math.pi), "pitch": 0.0015 * math.sin(t * 8 * math.pi)})
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
    def dump_clip(name, n, keys):
        def fn(f):
            t = (f - 1) / n
            th = keyed(keys, t)
            pose({"bed": th, "vibe": 0.002 * math.sin(f * 0.8) if 0.1 < th < T.BED_MAX - 0.02 else 0.0, "pitch": -0.012 * (th / T.BED_MAX)})
        CLIPS.bake(name, frames(n), fn)
    dump_clip("DumpUp", 90, [(0, 0.0), (1, T.BED_MAX)])
    dump_clip("DumpDown", 90, [(0, T.BED_MAX), (1, 0.0)])
    dump_clip("DumpCycle", 240, [(0, 0.0), (0.38, T.BED_MAX), (0.58, T.BED_MAX), (0.95, 0.0), (1, 0.0)])
    def drive(f):
        t = (f - 1) / 24
        pose({"drive": 1.5 * t, "vibe": 0.004 * math.sin(t * 8 * math.pi), "roll": 0.004 * math.sin(t * 4 * math.pi)})
    CLIPS.bake("Drive", frames(24), drive)
    def steer(f):
        t = (f - 1) / 90
        pose({"steer": keyed([(0, 0), (0.25, T.STEER_MAX), (0.5, 0), (0.75, -T.STEER_MAX), (1, 0)], t), "drive": 0.4 * t})
    CLIPS.bake("Steer", frames(90, 2), steer)

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
