"""QUARRY DAYS - wheelbarrow (Blender 5.x, headless). Same pipeline as the vehicles.

    blender -b --factory-startup -P tools/vehicle_models/build_wheelbarrow.py

Output: assets/vehicles/src/QD_Wheelbarrow.blend and assets/vehicles/VEH_QD_Wheelbarrow.glb (Y up, faces -Z with the wheel in front).
Hierarchy: root > Wheel (spins about the axle) and Body (origin = the axle: tray, frame, handles and legs; tips forward about the axle).
"""
import bpy, math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import qd_blender as Q
from qd_blender import Mesher, empty

OUT_BLEND = os.path.join(Q.REPO, "assets", "vehicles", "src", "QD_Wheelbarrow.blend")
OUT_GLB = os.path.join(Q.REPO, "assets", "vehicles", "VEH_QD_Wheelbarrow.glb")
AXLE = (0.75, 0.26)                      # (y, z): the wheel centre, the tipping pivot
WR = 0.26

Q.reset()
root = empty("QD_Wheelbarrow", size=0.2)

# ---- wheel: chunky tyre, rim, hub; origin at the axle
mm = Mesher("Wheel", root, loc=(0, AXLE[0], AXLE[1]), dirt=1.2)
mm.cyl((0, 0, 0), WR, 0.10, 'x', "Tire", seg=10)
mm.cyl((0, 0, 0), WR * 0.62, 0.115, 'x', "ExcDark", seg=10)
mm.cyl((0, 0, 0), 0.05, 0.19, 'x', "SteelPlate", seg=6)
for k in range(6):
    a = 2 * math.pi * k / 6
    mm.box((0, math.cos(a) * (WR + 0.005), math.sin(a) * (WR + 0.005)), (0.11, 0.05, 0.05), "Tire")        # tread lugs
wheel = mm.finish()

# ---- body (origin = the axle): tray, frame, handles, legs. Coordinates below are in model space, shifted into the axle frame.
body = Mesher("Body", root, loc=(0, AXLE[0], AXLE[1]), shift=(0, -AXLE[0], -AXLE[1]), zbase=0.4, dirt=1.4)
m = body
# tapered steel-and-paint tub: wide at the back, narrow at the wheel, with a rolled rim
m.hexa([(-0.22, 0.45, 0.46), (0.22, 0.45, 0.46), (0.30, -0.45, 0.50), (-0.30, -0.45, 0.50),
        (-0.30, 0.52, 0.84), (0.30, 0.52, 0.84), (0.40, -0.52, 0.88), (-0.40, -0.52, 0.88)], "CabPaint")
m.hexa([(-0.215, 0.43, 0.49), (0.215, 0.43, 0.49), (0.285, -0.43, 0.53), (-0.285, -0.43, 0.53),
        (-0.285, 0.50, 0.80), (0.285, 0.50, 0.80), (0.375, -0.50, 0.84), (-0.375, -0.50, 0.84)], "ExcDark")                  # dark inside
m.bar((-0.30, 0.52, 0.85), (0.30, 0.52, 0.85), 0.045, 0.045, "SteelPlate")                                       # rolled rim
m.bar((0.30, 0.52, 0.85), (0.40, -0.52, 0.89), 0.045, 0.045, "SteelPlate")
m.bar((0.40, -0.52, 0.89), (-0.40, -0.52, 0.89), 0.045, 0.045, "SteelPlate")
m.bar((-0.40, -0.52, 0.89), (-0.30, 0.52, 0.85), 0.045, 0.045, "SteelPlate")
for y in (0.1, -0.2):
    m.box((0, y, 0.44), (0.6, 0.05, 0.05), "SteelPlate")                                                      # under-tray ribs
for sx in (-1, 1):
    m.bar((sx * 0.28, 0.42, 0.42), (sx * 0.12, AXLE[0], AXLE[1] + 0.02), 0.05, 0.05, "ExcDark")               # front fork to the axle
    m.bar((sx * 0.26, 0.40, 0.46), (sx * 0.34, -1.05, 0.60), 0.06, 0.05, "ExcDark")                           # frame rails under the tray out to the handles
    m.bar((sx * 0.34, -0.55, 0.60), (sx * 0.34, -0.88, 0.80), 0.045, 0.045, "SteelPlate")                      # handle
    m.box((sx * 0.34, -0.96, 0.82), (0.055, 0.22, 0.055), "Rubber")                                           # rubber grip
    m.bar((sx * 0.32, -0.45, 0.50), (sx * 0.30, -0.70, 0.04), 0.05, 0.05, "ExcDark")                          # leg
    m.box((sx * 0.30, -0.72, 0.03), (0.10, 0.14, 0.04), "Rubber")                                             # leg foot
    m.cyl((sx * 0.12, AXLE[0], AXLE[1]), 0.035, 0.05, 'x', "SteelPlate", seg=6)                               # axle bolt heads
m.bar((-0.34, -0.74, 0.50), (0.34, -0.74, 0.50), 0.04, 0.04, "ExcDark")                                       # leg cross brace
for sx in (-1, 1):
    for y in (0.2, -0.3):
        m.cyl((sx * 0.355, y, 0.70), 0.018, 0.03, 'x', "SteelPlate", seg=6)                                   # rivets
body_obj = m.finish()
empty("Marker_Load", body_obj, (0, -0.30 - 0.0, 0.0))                                                           # placeholder (the game centres the load itself)

# ---- animation: tip the body forward about the axle (handles up), wheel spin
CLIPS = Q.Clips()
CLIPS.track(body_obj)
CLIPS.track(wheel)
def smooth(t): return t * t * (3 - 2 * t)
def keyed(keys, t):
    if t <= keys[0][0]: return keys[0][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1: return v0 + (v1 - v0) * smooth((t - t0) / (t1 - t0))
    return keys[-1][1]
def tip(f):
    t = (f - 1) / 60
    body_obj.rotation_euler = (-keyed([(0, 0), (0.4, 0.85), (0.6, 0.85), (1, 0)], t), 0, 0)
    wheel.rotation_euler = (0, 0, 0)
CLIPS.bake("Tip", list(range(1, 62)), tip)
def roll(f):
    t = (f - 1) / 24
    body_obj.rotation_euler = (0.0, 0, 0)
    wheel.rotation_euler = (-(1.2 * t) / WR, 0, 0)
CLIPS.bake("Roll", list(range(1, 26)), roll)
body_obj.rotation_euler = (0, 0, 0)
wheel.rotation_euler = (0, 0, 0)
for o in bpy.data.objects:
    if o.animation_data:
        o.animation_data.action = None
os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
Q.export_glb(OUT_GLB)
print("GLB", OUT_GLB, os.path.getsize(OUT_GLB), "bytes")
print("BUILD_OK", len([o for o in bpy.data.objects if o.type == 'MESH']), "meshes")
