"""QUARRY DAYS - production equipment, modelled in Blender (5.x, headless), low-poly and flat shaded like the rest of the game:

    blender -b --factory-startup -P tools/equipment_models/build_equipment.py [-- crusher belt ...]

Writes assets/equipment/EQP_QD_<name>.glb (+ assets/equipment/src/<name>.blend, ignored by Godot). Coordinates are GODOT model space: metres, +Y up, the machine's
FLOW runs toward -Z (a crusher discharges at -Z and is fed from +Z; a belt carries material from +Z to -Z). The origin is on the ground at the machine's centre.
Structure of every file: root -> "Body" (every static part, one mesh per material) and, where the game animates or toggles something, a named holder at its
hinge: Flywheel_L / Flywheel_R / Jaw (crushers, rotate about X), Mantle (cone crusher, rotates about Y), EndCap_In / EndCap_Out (belts: shown when that end is
not connected). The mesh whose material is named "Belt" is the running surface: the game scrolls its texture while the belt carries material.

Port geometry the game's connection system relies on (scripts/business.gd): crusher discharge tip at z = -1.05 (tier 2: -1.25), feed lip at z = +0.85 (tier 2:
+1.25); belt pieces are 2.0 m (straight, merger, splitter, corner legs), 1.0 m (short) or 3.0 m (incline) between their end faces; bins take belts on all four
sides at a belt height of 0.27 m through an inlet spout.
"""
import bpy, math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "tool_models"))
import qd_blender as Q
from qd_blender import empty
from tm import TM

OUT = os.path.join(Q.REPO, "assets", "equipment")
SRC = os.path.join(OUT, "src")

Q.MATERIALS.update({
    "SteelGreen":  (None, (0.22, 0.36, 0.30), 0.8, 0.2, {}),
    "PaintOrange": (None, (0.85, 0.45, 0.12), 0.8, 0.0, {}),
    "PaintRed":    (None, (0.62, 0.14, 0.10), 0.8, 0.0, {}),
    "Belt":        (None, (0.07, 0.07, 0.08), 1.0, 0.0, {}),
    "Lamp":        (None, (1.0, 0.86, 0.55), 0.5, 0.0, {"emit": 2.0}),
})

BELT_Y = 0.25          # belt surface height (top at +0.015)


# ------------------------------------------------------------------------------------------------------------------------------ belts
def lane(t, x, z0, z1, w=0.74, rails=True, legs=True):
    """A belt lane along Z at x between z0 < z1 (so material runs toward z0): running surface, two side channels, end rollers, legs."""
    L = z1 - z0
    zc = (z0 + z1) / 2
    t.box((x, BELT_Y, zc), (w, 0.03, L - 0.06), "Belt")
    if rails:
        for s in (-1, 1):
            t.box((x + s * (w / 2 + 0.05), 0.2, zc), (0.06, 0.14, L), "SteelGreen")
    for zz in (z0 + 0.03, z1 - 0.03):
        t.cyl((x, 0.22, zz), 0.07, 0.07, w + 0.04, "SteelPlate", seg=8, axis='x')
    if legs:
        for s in (-1, 1):
            for zz in (z0 + 0.2, z1 - 0.2):
                t.box((x + s * (w / 2 + 0.05), 0.07, zz), (0.07, 0.14, 0.07), "SteelPlate")


def arrow(t, x, z, y=0.275, flip=False):
    """A travel arrow painted on the belt (points to -Z)."""
    t.box((x, y, z), (0.16, 0.012, 0.26), "Hazard")
    d = -1 if not flip else 1
    t.box((x, y, z + d * 0.16), (0.3, 0.012, 0.08), "Hazard")


def end_cap(root, z, name):
    """A hinged-free end guard: a steel plate across the open end with two rubber bumpers. Shown by the game while that end is not connected."""
    c = TM(name, root, loc=(0, 0.2, z), holder=True)
    s = 1 if z > 0 else -1
    c.box((0, 0.2, z + s * 0.015), (0.96, 0.24, 0.03), "SteelPlate")
    c.box((0, 0.2, z + s * 0.045), (0.5, 0.06, 0.03), "Hazard")
    for x in (-0.36, 0.36):
        c.box((x, 0.12, z + s * 0.045), (0.1, 0.1, 0.04), "Rubber")
    c.finish()


def belt_straight(root, L=2.0, caps=True):
    t = TM("Body", root, holder=True)
    lane(t, 0, -L / 2, L / 2)
    for k in range(int(L // 1.0)):
        arrow(t, 0, L / 2 - 0.5 - k * 1.0 if L >= 2 else 0.0)
    if L >= 2.0:
        t.box((0, 0.1, 0.0), (1.0, 0.05, 0.05), "SteelPlate")                 # a cross brace between the channels
    for zz in (-L / 2 + 0.03, L / 2 - 0.03):
        t.box((0, 0.02, zz), (1.0, 0.04, 0.08), "Hazard")                     # the crossing marks on the ground
    t.finish()
    if caps:
        end_cap(root, L / 2, "EndCap_In")
        end_cap(root, -L / 2, "EndCap_Out")


def belt_short(root):
    belt_straight(root, 1.0)


def belt_incline(root):
    """A 3 m incline: low end (z +1.5) at belt height, the exit (z -1.5) 1.1 m higher, so it can drop material into the top of a bin or a crusher's feed trough.
    Cleated belt on a sloped frame with braced legs and a discharge hood."""
    t = TM("Body", root, holder=True)
    top0, top1 = BELT_Y, BELT_Y + 1.1
    def h(z):          # belt height at z (z=+1.5 -> top0, z=-1.5 -> top1)
        return top0 + (top1 - top0) * (1.5 - z) / 3.0
    t.bar((0, h(1.47), 1.47), (0, h(-1.47), -1.47), 0.03, 0.74, "Belt", up=(0, 1, 0))
    for s in (-1, 1):
        x = s * 0.42
        t.bar((x, h(1.5) - 0.05, 1.5), (x, h(-1.5) - 0.05, -1.5), 0.14, 0.06, "SteelGreen", up=(0, 1, 0))
        for zz in (1.2, 0.2, -0.8, -1.35):
            top = h(zz) - 0.12
            t.box((x, top / 2, zz), (0.07, top, 0.07), "SteelPlate")                 # legs, growing with the belt
    for zz in (1.2, 0.2, -0.8, -1.35):
        t.box((0, h(zz) - 0.2, zz), (0.84, 0.05, 0.05), "SteelPlate")                  # cross ties
    for k in range(6):                                                                  # cleats across the belt
        zz = 1.1 - k * 0.5
        t.bar((-0.33, h(zz) + 0.04, zz), (0.33, h(zz) + 0.04, zz), 0.05, 0.04, "Rubber", up=(0, 1, 0))
    for zz in (1.47, -1.47):                                                            # head and tail rollers
        t.cyl((0, h(zz) - 0.03, zz), 0.07, 0.07, 0.78, "SteelPlate", seg=8, axis='x')
    # discharge hood at the head: a steel cover over the exit with a lip to drop material straight down
    t.box((0, top1 + 0.12, -1.28), (0.9, 0.05, 0.42), "SteelGreen")
    for s in (-1, 1):
        t.box((s * 0.46, top1 + 0.06, -1.3), (0.05, 0.2, 0.46), "SteelGreen")
    t.box((0, top1 - 0.02, -1.55), (0.7, 0.1, 0.06), "Hazard")
    # side brace legs under the head
    for s in (-1, 1):
        t.bar((s * 0.42, 0.0, -1.0), (s * 0.42, top1 - 0.12, -1.45), 0.05, 0.05, "SteelPlate", up=(1, 0, 0))
    for zz in (1.45, -1.45):
        t.box((0, 0.02, zz), (1.0, 0.04, 0.08), "Hazard")
    t.finish()
    end_cap(root, 1.5, "EndCap_In")


def belt_corner(root, mirror):
    """A 90 degree corner: material enters at the back (+Z) and leaves through the side (+X, or -X when mirrored). Two half belts and the bend."""
    t = TM("Body", root, mirror=mirror, holder=True)
    # entry half: back edge (z=+1) to the centre; exit half: centre to the side (x=+1)
    t.box((0, BELT_Y, 0.5), (0.74, 0.03, 1.0), "Belt")
    t.box((0.5, BELT_Y, 0), (1.0, 0.03, 0.74), "Belt")
    t.box((0, BELT_Y, 0), (0.74, 0.03, 0.74), "Belt")
    t.box((-0.42, 0.2, 0.29), (0.06, 0.14, 1.42), "SteelGreen")              # outer rail, entry side
    t.box((0.29, 0.2, -0.42), (1.42, 0.14, 0.06), "SteelGreen")              # outer rail, exit side
    t.box((0.42, 0.2, 0.71), (0.06, 0.14, 0.58), "SteelGreen")               # inner rails stop short of the bend
    t.box((0.71, 0.2, 0.42), (0.58, 0.14, 0.06), "SteelGreen")
    for lx, lz in ((-0.42, 0.8), (0.42, 0.8), (0.8, -0.42), (0.8, 0.42), (-0.42, -0.42)):
        t.box((lx, 0.07, lz), (0.07, 0.14, 0.07), "SteelPlate")
    t.cyl((0, 0.22, 0.97), 0.07, 0.07, 0.78, "SteelPlate", seg=8, axis='x')
    t.cyl((0.97, 0.22, 0), 0.07, 0.07, 0.78, "SteelPlate", seg=8, axis='z')
    t.cyl((0, 0.31, 0), 0.1, 0.1, 0.06, "Hazard", seg=8)                      # the bend's hub plate
    t.box((0, 0.02, 0.95), (1.0, 0.04, 0.08), "Hazard")
    t.box((0.95, 0.02, 0), (0.08, 0.04, 1.0), "Hazard")
    t.box((0, 0.275, 0.55), (0.16, 0.012, 0.26), "Hazard")
    t.box((0.55, 0.275, 0), (0.26, 0.012, 0.16), "Hazard")
    t.finish()
    # end caps: the entry (+Z) and the exit (side); the exit cap is turned to face +X
    end_cap(root, 1.0, "EndCap_In")
    c = TM("EndCap_Out", root, loc=(1.0, 0.2, 0), holder=True, mirror=mirror)
    c.box((1.015, 0.2, 0), (0.03, 0.24, 0.96), "SteelPlate")
    c.box((1.045, 0.2, 0), (0.03, 0.06, 0.5), "Hazard")
    c.finish()


def belt_merger(root):
    """A 2 x 2 m junction: a main lane from the back (+Z) to the front (-Z) and a side lane from each side (+-X) joining it. Arrows point to the centre."""
    t = TM("Body", root, holder=True)
    t.box((0, BELT_Y, 0), (0.74, 0.03, 1.94), "Belt")
    for s in (-1, 1):
        t.box((s * 0.68, BELT_Y, 0), (0.64, 0.03, 0.74), "Belt")                              # side lane into the main lane
        t.box((s * 0.68, 0.2, 0.42), (0.64, 0.14, 0.06), "SteelGreen")
        t.box((s * 0.68, 0.2, -0.42), (0.64, 0.14, 0.06), "SteelGreen")
        t.box((s * 0.97, 0.22, 0), (0.14, 0.14, 0.78), "SteelPlate")                          # the side inlets' rollers
        t.box((s * 0.7, 0.275, 0), (0.3, 0.012, 0.16), "Hazard")                              # arrows pointing to the centre
        t.box((s * 0.55, 0.275, 0.0 + 0.0), (0.08, 0.012, 0.3), "Hazard")
        t.box((s * 0.97, 0.02, 0), (0.08, 0.04, 1.0), "Hazard")
    for x in (-0.42, 0.42):
        t.box((x, 0.2, 0.7), (0.06, 0.14, 0.6), "SteelGreen")                                # the main rails stop where the side lanes enter
        t.box((x, 0.2, -0.7), (0.06, 0.14, 0.6), "SteelGreen")
        for zz in (-0.9, 0.9):
            t.box((x, 0.07, zz), (0.07, 0.14, 0.07), "SteelPlate")
    for s in (-1, 1):
        for zz in (-0.4, 0.4):
            t.box((s * 0.9, 0.07, zz), (0.07, 0.14, 0.07), "SteelPlate")
    for zz in (-0.97, 0.97):
        t.cyl((0, 0.22, zz), 0.07, 0.07, 0.78, "SteelPlate", seg=8, axis='x')
        t.box((0, 0.02, zz), (1.0, 0.04, 0.08), "Hazard")
    t.box((0, 0.275, -0.7), (0.16, 0.012, 0.26), "Hazard")
    t.box((0, 0.1, 0.0), (1.0, 0.05, 0.05), "SteelPlate")
    t.box((0, 0.1, 0.0), (0.05, 0.05, 1.0), "SteelPlate")
    t.finish()
    end_cap(root, 1.0, "EndCap_In")
    end_cap(root, -1.0, "EndCap_Out")


def belt_splitter(root):
    """A T splitter, 2 x 2 m: one belt comes in at the back (+Z), a diverter at the centre sends material alternately to the belts leaving at BOTH sides (+-X).
    The front (-Z) is closed with a steel wall."""
    t = TM("Body", root, holder=True)
    t.box((0, BELT_Y, 0.5), (0.74, 0.03, 1.0), "Belt")                                         # the feed lane to the centre
    for s in (-1, 1):
        t.box((s * 0.68, BELT_Y, 0), (0.64, 0.03, 0.74), "Belt")                              # the two exit lanes
        t.box((s * 0.68, 0.2, 0.42), (0.64, 0.14, 0.06), "SteelGreen")
        t.box((s * 0.68, 0.2, -0.42), (0.64, 0.14, 0.06), "SteelGreen")
        t.box((s * 0.97, 0.22, 0), (0.14, 0.14, 0.78), "SteelPlate")
        t.box((s * 0.7, 0.275, 0), (0.3, 0.012, 0.16), "Hazard")                              # arrows pointing OUT
        t.box((s * 0.9, 0.275, 0.0), (0.08, 0.012, 0.3), "Hazard")
        t.box((s * 0.97, 0.02, 0), (0.08, 0.04, 1.0), "Hazard")
        for zz in (-0.4, 0.4):
            t.box((s * 0.9, 0.07, zz), (0.07, 0.14, 0.07), "SteelPlate")
    t.box((0, BELT_Y, 0), (0.74, 0.03, 0.74), "Belt")                                          # the centre square
    for x in (-0.42, 0.42):
        t.box((x, 0.2, 0.7), (0.06, 0.14, 0.6), "SteelGreen")                                # feed rails
        for zz in (0.9,):
            t.box((x, 0.07, zz), (0.07, 0.14, 0.07), "SteelPlate")
    t.box((0, 0.3, -0.45), (1.96, 0.3, 0.06), "SteelGreen")                                 # the closed front wall
    t.box((0, 0.1, -0.45), (1.9, 0.08, 0.1), "SteelPlate")
    # the diverter: a wedge (pointing at the feed) in yellow, two angled plates
    t.prism([(-0.28, 0.0), (0.18, 0.0), (0.18, 0.26), (-0.28, 0.26)], 0.06, (0, 0.27, 0), "PaintYellow", x=0.0)
    t.bar((0.0, 0.4, 0.2), (-0.34, 0.4, -0.3), 0.2, 0.04, "PaintYellow", up=(0, 1, 0))
    t.bar((0.0, 0.4, 0.2), (0.34, 0.4, -0.3), 0.2, 0.04, "PaintYellow", up=(0, 1, 0))
    t.cyl((0, 0.55, -0.1), 0.08, 0.08, 0.06, "Lamp", seg=8)
    t.cyl((0, 0.45, -0.1), 0.03, 0.03, 0.2, "SteelPlate", seg=6)
    t.cyl((0, 0.22, 0.97), 0.07, 0.07, 0.78, "SteelPlate", seg=8, axis='x')
    t.box((0, 0.02, 0.97), (1.0, 0.04, 0.08), "Hazard")
    t.box((0, 0.275, 0.6), (0.16, 0.012, 0.26), "Hazard")
    t.finish()
    end_cap(root, 1.0, "EndCap_In")


def support_set(root):
    """For the viewer: a leg pair with a cross brace, a taller incline leg, and the two end caps laid out side by side."""
    t = TM("Body", root, holder=True)
    for k, hgt in enumerate((0.14, 0.7, 1.2)):
        x0 = -0.9 + k * 0.9
        for s in (-1, 1):
            t.box((x0 + s * 0.42, hgt / 2, 0), (0.07, hgt, 0.07), "SteelPlate")
        t.box((x0, hgt, 0), (0.92, 0.05, 0.05), "SteelPlate")
        if hgt > 0.5:
            t.bar((x0 - 0.42, 0.05, 0), (x0 + 0.42, hgt - 0.05, 0), 0.03, 0.03, "SteelPlate", up=(0, 0, 1))
        t.box((x0, 0.02, 0), (0.95, 0.04, 0.14), "Hazard")
    t.finish()
    c = TM("EndCap_Out", root, loc=(0, 0.2, 0.9), holder=True)
    c.box((0, 0.2, 0.9), (0.96, 0.24, 0.03), "SteelPlate")
    c.box((0, 0.2, 0.93), (0.5, 0.06, 0.03), "Hazard")
    for x in (-0.36, 0.36):
        c.box((x, 0.12, 0.93), (0.1, 0.1, 0.04), "Rubber")
    c.finish()


# ------------------------------------------------------------------------------------------------------------------------------ crushers
def feed_trough(t, lip_z, top_z, top_y, half=0.55):
    """A sloped feed trough: a floor plate rising from the low lip (z=lip_z, y=0.34) to the hopper (z=top_z, y=top_y), two side walls, a painted rim."""
    t.bar((0, 0.34, lip_z), (0, top_y - 0.1, top_z), 0.06, 2 * half, "SteelPlate", up=(0, 1, 0))
    for s in (-1, 1):
        prof = [(lip_z, 0.30), (top_z, 0.30), (top_z, top_y + 0.05), (lip_z, 0.62)]            # (z, y)
        t.prism(prof, 0.07, (0, 0, 0), "PaintYellow", x=s * (half + 0.03))
    t.box((0, 0.36, lip_z + 0.02), (2 * half + 0.1, 0.05, 0.06), "Hazard")


def crusher(root):
    """The jaw crusher (tier 1): skid frame, green body, yellow jaw housing, a sloped feed trough at the back (+Z), a feed hopper over the jaw, a motor with a belt
    guard, two spoked flywheels, the swinging jaw and a discharge chute (-Z) that ends at z -1.05, 0.33 m up, right over the start of a belt."""
    t = TM("Body", root, holder=True)
    for x in (-0.68, 0.68):
        t.box((x, 0.08, 0.0), (0.16, 0.16, 1.8), "SteelPlate")                                # skids
    t.box((0, 0.5, 0), (1.3, 0.7, 1.25), "SteelGreen", taper=(0.94, 1.0))                     # lower body
    t.box((0, 1.0, -0.02), (1.2, 0.4, 1.1), "PaintYellow", taper=(0.92, 1.0))                  # jaw housing
    for s in (-1, 1):
        t.box((s * 0.62, 0.9, -0.05), (0.06, 0.8, 1.0), "SteelGreen")                         # bolted side plates
        for zz in (-0.4, 0.0, 0.4):
            t.cyl((s * 0.66, 0.98, zz), 0.04, 0.04, 0.03, "Bright", seg=6, axis='x')           # bolt heads
    # feed hopper over the jaw: four walls, open top and open to the trough
    for s in (-1, 1):
        t.box((s * 0.43, 1.55, 0.28), (0.06, 0.45, 0.62), "PaintYellow")
    t.box((0, 1.55, -0.03), (0.92, 0.45, 0.06), "PaintYellow")
    t.box((0, 1.79, 0.28), (0.96, 0.05, 0.05), "Hazard")
    feed_trough(t, 0.85, 0.35, 1.3)
    # motor with fins and a belt guard on the -X side, and a control box with a lamp on the +X side
    t.cyl((-0.33, 0.93, -0.42), 0.2, 0.2, 0.5, "SteelPlate", seg=8, axis='z')
    for k in range(4):
        t.cyl((-0.33, 0.93, -0.58 + k * 0.1), 0.23, 0.23, 0.03, "SteelPlate", seg=8, axis='z')
    t.box((-0.7, 0.9, -0.15), (0.05, 0.62, 0.7), "SteelGreen", taper=(1, 0.9))                 # belt guard
    t.box((0.78, 0.5, -0.45), (0.2, 0.4, 0.3), "SteelPlate")
    t.box((0.89, 0.55, -0.45), (0.03, 0.12, 0.12), "Lamp")
    t.cyl((0, 0.78, 0.05), 0.045, 0.045, 1.85, "SteelPlate", seg=8, axis='x')                   # shaft through the housing
    # discharge chute: sloped floor with two cheeks, ends over the belt
    t.bar((0, 0.5, -0.55), (0, 0.33, -1.05), 0.05, 0.84, "SteelPlate", up=(0, 1, 0))
    for s in (-1, 1):
        t.prism([(-0.55, 0.3), (-1.05, 0.28), (-1.05, 0.42), (-0.55, 0.65)], 0.05, (0, 0, 0), "SteelGreen", x=s * 0.44)
    t.box((0, 0.2, -1.0), (1.2, 0.12, 0.04), "Hazard")
    t.finish()
    for x in (-0.78, 0.78):
        f = TM("Flywheel_L" if x < 0 else "Flywheel_R", root, loc=(x, 0.78, 0.05), holder=True)
        f.cyl((x, 0.78, 0.05), 0.42, 0.42, 0.1, "SteelPlate", seg=10, axis='x')
        f.cyl((x, 0.78, 0.05), 0.46, 0.46, 0.05, "Hazard", seg=10, axis='x')
        f.box((x, 0.78, 0.05), (0.14, 0.08, 0.84), "SteelPlate")                                 # spokes
        f.box((x, 0.78, 0.05), (0.14, 0.84, 0.08), "SteelPlate")
        f.cyl((x + (0.07 if x > 0 else -0.07), 0.78, 0.05), 0.09, 0.09, 0.05, "Bright", seg=8, axis='x')
        f.finish()
    j = TM("Jaw", root, loc=(0, 1.26, -0.2), holder=True)
    j.box((0, 1.06, -0.2), (0.82, 0.4, 0.12), "SteelPlate", taper=(1.0, 0.9))
    for k in range(4):
        j.box((-0.3 + 0.2 * k, 1.06, -0.13), (0.05, 0.36, 0.04), "Bright")                        # wear teeth
    j.finish()


def crusher_adv(root):
    """The advanced (cone) crusher: a wider skid frame, an orange bowl with a feed ring, a gyrating mantle, motor with a belt guard, a trough lip at z +1.25 and a
    twin discharge chute ending at z -1.25."""
    t = TM("Body", root, holder=True)
    for x in (-0.82, 0.82):
        t.box((x, 0.1, 0.0), (0.2, 0.2, 2.3), "SteelPlate")
    t.box((0, 0.45, 0), (1.7, 0.5, 1.7), "SteelGreen", taper=(0.95, 1.0))
    t.cyl((0, 0.7, 0), 0.82, 0.7, 0.7, "PaintOrange", seg=10)                                   # the bowl
    t.cyl((0, 1.37, 0), 0.7, 0.86, 0.32, "PaintOrange", seg=10)                                  # the feed ring
    t.cyl((0, 1.55, 0), 0.9, 0.9, 0.06, "Hazard", seg=10)
    for k in range(6):
        a = k * math.pi / 3
        t.box((0.88 * math.cos(a) * 0.9, 0.95, 0.88 * math.sin(a) * 0.9), (0.08, 0.3, 0.08), "SteelPlate")      # rim ribs
    t.box((0.95, 0.75, 0.55), (0.45, 0.42, 0.6), "SteelPlate")                                  # motor
    for k in range(4):
        t.box((0.95, 0.75, 0.3 + k * 0.1), (0.5, 0.46, 0.03), "SteelPlate")
    t.box((0.95, 0.95, 0.1), (0.12, 0.5, 0.95), "SteelGreen")                                   # belt guard
    t.box((-1.0, 0.55, -0.4), (0.22, 0.5, 0.3), "SteelPlate")                                   # control cabinet
    t.box((-1.115, 0.62, -0.4), (0.03, 0.12, 0.12), "Lamp")
    feed_trough(t, 1.25, 0.65, 1.2, half=0.65)
    for s in (-1, 1):
        t.prism([(-0.7, 0.3), (-1.25, 0.26), (-1.25, 0.4), (-0.7, 0.68)], 0.05, (0, 0, 0), "SteelGreen", x=s * 0.5)
    t.bar((0, 0.5, -0.7), (0, 0.32, -1.25), 0.05, 0.96, "SteelPlate", up=(0, 1, 0))
    t.box((0, 0.24, -1.2), (1.5, 0.14, 0.04), "Hazard")
    t.finish()
    m = TM("Mantle", root, loc=(0, 1.3, 0), holder=True)
    m.cyl((0, 1.2, 0), 0.5, 0.12, 0.42, "SteelPlate", seg=8)
    m.box((0, 1.6, 0), (0.1, 0.12, 0.6), "Bright")
    m.finish()


# ------------------------------------------------------------------------------------------------------------------------------ bins, hopper, storage
def inlet(t, side, w, ybase=0.3):
    """An inlet spout in a bin wall: a lipped chute at belt height. side: (nx, nz) outward unit vector, w: the wall half-extent in that direction."""
    nx, nz = side
    px, pz = nx * w, nz * w
    # lip sticks out of the wall and slopes down inside
    cx, cz = px + nx * 0.06, pz + nz * 0.06
    sx, sz = (0.1, 0.62) if nx != 0 else (0.62, 0.1)
    t.box((cx, ybase + 0.02, cz), (sx, 0.05, sz), "SteelPlate")
    t.box((px + nx * 0.02, ybase + 0.34, pz + nz * 0.02), ((0.05 if nx else 0.7), 0.05, (0.7 if nx else 0.05)), "Hazard")       # frame over the opening
    for k in (-1, 1):
        if nx:
            t.box((cx, ybase + 0.15, cz + k * 0.33), (0.1, 0.3, 0.05), "SteelPlate")
        else:
            t.box((cx + k * 0.33, ybase + 0.15, cz), (0.05, 0.3, 0.1), "SteelPlate")


def wall_with_inlet(t, axis, pos, half_len, h0, h1, thick, mat, inlet_w=0.6, inlet_y0=0.3, inlet_y1=0.62):
    """A wall along `axis` ('x' = runs along X at z=pos, 'z' = runs along Z at x=pos), solid except for a rectangular inlet at its middle."""
    hl = half_len
    seg = (hl * 2 - inlet_w) / 2
    for s in (-1, 1):
        c = s * (inlet_w / 2 + seg / 2)
        sz = (seg, h1 - h0, thick) if axis == 'x' else (thick, h1 - h0, seg)
        t.box((c, (h0 + h1) / 2, pos) if axis == 'x' else (pos, (h0 + h1) / 2, c), sz, mat)
    szb = (inlet_w, inlet_y0 - h0, thick) if axis == 'x' else (thick, inlet_y0 - h0, inlet_w)
    t.box((0, (h0 + inlet_y0) / 2, pos) if axis == 'x' else (pos, (h0 + inlet_y0) / 2, 0), szb, mat)
    szt = (inlet_w, h1 - inlet_y1, thick) if axis == 'x' else (thick, h1 - inlet_y1, inlet_w)
    t.box((0, (inlet_y1 + h1) / 2, pos) if axis == 'x' else (pos, (inlet_y1 + h1) / 2, 0), szt, mat)


def out_bin(root):
    """The output storage bin: a low 1.4 m bin sitting on the ground, walls to 1.12, with an inlet spout on each of the four sides at belt height (belts butt up
    to them, nothing floats), corner posts, a hazard rim and a ladder on +X. Inside is open: the game heaps the stored stone in it."""
    t = TM("Body", root, holder=True)
    t.box((0, 0.05, 0), (1.46, 0.1, 1.46), "SteelPlate")                                        # floor plate / skid
    for s in (-1, 1):
        wall_with_inlet(t, 'x', s * 0.68, 0.7, 0.08, 1.12, 0.06, "SteelGreen")
        wall_with_inlet(t, 'z', s * 0.68, 0.7, 0.08, 1.12, 0.06, "SteelGreen")
        for q in (-1, 1):
            t.box((s * 0.7, 0.6, q * 0.7), (0.1, 1.1, 0.1), "SteelPlate")                      # corner posts
    for nx, nz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        inlet(t, (nx, nz), 0.68)
    t.box((0, 1.13, -0.7), (1.5, 0.06, 0.06), "Hazard")
    t.box((0, 1.13, 0.7), (1.5, 0.06, 0.06), "Hazard")
    t.box((-0.7, 1.13, 0), (0.06, 0.06, 1.4), "Hazard")
    t.box((0.7, 1.13, 0), (0.06, 0.06, 1.4), "Hazard")
    for z in (-0.19, 0.19):
        t.box((0.745, 0.62, z), (0.04, 1.05, 0.03), "SteelPlate")                                # ladder rails on the +X wall
    for y in range(5):
        t.box((0.755, 0.25 + y * 0.2, 0.0), (0.03, 0.03, 0.4), "SteelPlate")
    t.finish()


def hopper(root):
    """The small hopper: a funnel on a braced four-leg frame (rim at 1.17 m, spout at the bottom), a belt-port plate on each of the four sides and a level gauge.
    Belts can also drop material in from above (an incline's exit hood stands over the rim)."""
    t = TM("Body", root, holder=True)
    for x in (-0.55, 0.55):
        for z in (-0.55, 0.55):
            t.box((x, 0.45, z), (0.08, 0.9, 0.08), "SteelPlate")
            t.box((x, 0.03, z), (0.2, 0.06, 0.2), "SteelPlate")
    for y in (0.3, 0.9):
        t.box((0, y, -0.55), (1.1, 0.05, 0.05), "SteelPlate")
        t.box((0, y, 0.55), (1.1, 0.05, 0.05), "SteelPlate")
        t.box((-0.55, y, 0), (0.05, 0.05, 1.1), "SteelPlate")
        t.box((0.55, y, 0), (0.05, 0.05, 1.1), "SteelPlate")
    t.bar((-0.55, 0.3, -0.55), (0.55, 0.9, -0.55), 0.04, 0.04, "SteelPlate", up=(0, 0, 1))
    t.bar((0.55, 0.3, 0.55), (-0.55, 0.9, 0.55), 0.04, 0.04, "SteelPlate", up=(0, 0, 1))
    t.cyl((0, 0.84, 0), 0.16, 0.7, 0.68, "SteelGreen", seg=8)                                   # the funnel (wide at the top)
    t.cyl((0, 0.18, 0), 0.1, 0.16, 0.34, "SteelGreen", seg=8)                                   # the spout
    for sd in ((0, -0.72, 1.46, 0.07), (0, 0.72, 1.46, 0.07)):
        t.box((0, 1.17, sd[1]), (sd[2], 0.07, 0.07), "Hazard")
    for sx in (-0.72, 0.72):
        t.box((sx, 1.17, 0), (0.07, 0.07, 1.46), "Hazard")
    for nx, nz in ((1, 0), (-1, 0), (0, 1), (0, -1)):                                            # belt-port plates, one each side
        px, pz = nx * 0.6, nz * 0.6
        t.box((px, 0.3, pz), ((0.06 if nx else 0.36), 0.3, (0.36 if nx else 0.06)), "PaintYellow")
        t.box((px + nx * 0.04, 0.2, pz + nz * 0.04), ((0.06 if nx else 0.2), 0.06, (0.2 if nx else 0.06)), "SteelPlate")
    t.box((0.74, 0.9, 0.0), (0.04, 0.5, 0.1), "SteelPlate")
    t.box((0.77, 0.9, 0.0), (0.02, 0.4, 0.04), "Lamp")
    t.finish()


def storage(root):
    """The large storage container (the yard's main crate): 2.0 x 1.6 m, walls to 1.3 on a steel base, ribs, a hazard rim and four belt inlets (two on each long
    side would not fit: one spout per side, at belt height). Open inside for the stored material."""
    t = TM("Body", root, holder=True)
    t.box((0, 0.08, 0), (2.04, 0.16, 1.64), "SteelPlate")
    for s in (-1, 1):
        wall_with_inlet(t, 'x', s * 0.78, 1.0, 0.1, 1.3, 0.06, "SteelGreen")
        wall_with_inlet(t, 'z', s * 0.98, 0.8, 0.1, 1.3, 0.06, "SteelGreen")
        for q in (-1, 1):
            t.box((s * 1.0, 0.7, q * 0.8), (0.1, 1.2, 0.1), "SteelPlate")
    for x in (-0.6, -0.2, 0.2, 0.6):
        for z in (-0.82, 0.82):
            t.box((x, 0.72, z), (0.06, 1.1, 0.04), "SteelPlate")                                 # ribs
    for z in (-0.4, 0.4):
        for x in (-1.0, 1.0):
            t.box((x + (0.02 if x > 0 else -0.02), 0.72, z), (0.04, 1.1, 0.06), "SteelPlate")
    for nx, nz, w in ((1, 0, 1.0), (-1, 0, 1.0), (0, 1, 0.78), (0, -1, 0.78)):
        inlet(t, (nx, nz), w)
    for sd in ((0, -0.82, 2.06, 0.1), (0, 0.82, 2.06, 0.1)):
        t.box((0, 1.31, sd[1]), (sd[2], 0.08, 0.06), "Hazard")
    for sx in (-1.01, 1.01):
        t.box((sx, 1.31, 0), (0.06, 0.08, 1.64), "Hazard")
    t.finish()


MODELS = {
    "crusher": crusher, "crusher_adv": crusher_adv, "hopper": hopper, "bin": out_bin, "storage": storage,
    "belt": belt_straight, "belt_short": belt_short, "belt_incline": belt_incline,
    "belt_left": lambda r: belt_corner(r, True), "belt_right": lambda r: belt_corner(r, False),
    "belt_merger": belt_merger, "belt_splitter": belt_splitter, "support": support_set,
}


def build(name, fn):
    Q.reset()
    root = empty("QD_" + name, size=0.2)
    fn(root)
    os.makedirs(SRC, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, name + ".blend"))
    path = os.path.join(OUT, "EQP_QD_%s.glb" % name)
    Q.export_glb(path)
    faces = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
    print("EQUIPMENT", name, os.path.getsize(path), "bytes", faces, "faces")


if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    os.makedirs(OUT, exist_ok=True)
    for name, fn in MODELS.items():
        if not only or name in only:
            build(name, fn)
    print("BUILD_OK")
