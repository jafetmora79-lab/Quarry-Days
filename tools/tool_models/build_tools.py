"""QUARRY DAYS - every player tool, modelled in Blender (5.x, headless):

    blender -b --factory-startup -P tools/tool_models/build_tools.py [id ...]

Writes assets/tools/TOOL_QD_<id>.glb (+ assets/tools/src/<id>.blend) for the five ladder tools (rock hammer .. jackhammer) and the Phase 9
tools (chisels .. ramp plan), and the gloved hands HAND_QD_R / HAND_QD_L. Conventions are those of scripts/tool_view.gd: the handle runs
along +Y from the grip point, the working end of a swung tool points to -Z, the same tip points and hand positions as the old procedural
models. Moving parts are their own nodes with their hinge as the origin (Spinner = drill bit / hammer ram / chisel, Lever = the splitter).
Flat shaded, nearest-filter style, no textures (the game swaps in its own materials by name).
"""
import bpy, math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import qd_blender as Q
from qd_blender import empty
from tm import TM, B, arc_head, finger_arc

OUT = os.path.join(Q.REPO, "assets", "tools")
SRC = os.path.join(OUT, "src")


def ring_grips(t, y0, y1, r, mat, n=4, seg=8):
    """Raised rubber ridges along a grip."""
    for i in range(n):
        y = y0 + (y1 - y0) * (i + 0.5) / n
        t.cyl((0, y, 0), r * 1.12, r * 1.12, 0.008, mat, seg=seg)


def eye_block(t, y, mat="Steel", w=0.06, h=0.085, d=0.065):
    t.box((0, y, 0), (w, h, d), mat, taper=(0.92, 0.92))


# ------------------------------------------------------------------------------------------------ the five ladder tools
def rock_hammer(root):
    t = TM("Body", root)
    t.cyl((0, 0.15, 0), 0.016, 0.0185, 0.40, "Wood", seg=8, squash=0.86)                  # ash handle, a little oval, fuller at the head
    t.cyl((0, 0.04, 0), 0.024, 0.026, 0.19, "Rubber", seg=8)                                # taped grip
    ring_grips(t, -0.045, 0.135, 0.024, "Rubber", n=5)
    t.cyl((0, -0.036, 0), 0.026, 0.021, 0.026, "Rubber", seg=8)                             # flared pommel
    eye_block(t, 0.36)
    t.cyl((0, 0.36, -0.07), 0.032, 0.038, 0.07, "Steel", seg=8, axis='z')                   # the hammer face, a short barrel
    t.cyl((0, 0.36, -0.1), 0.030, 0.030, 0.012, "Bright", seg=8, axis='z')                  # its worn bright striking face
    t.prism([(0.03, -0.034), (0.11, -0.010), (0.11, 0.010), (0.03, 0.034)], 0.05, (0, 0.36, 0), "Steel")   # chisel peen behind
    t.box((0, 0.403, 0.0), (0.014, 0.012, 0.04), "Bright")                                  # the wedge locking the head on
    t.finish()


def pickaxe_worn(root):
    t = TM("Body", root)
    t.cyl((0, 0.22, 0), 0.0175, 0.0205, 0.62, "OldWood", seg=8, squash=1.1)
    t.box((0, 0.05, 0), (0.046, 0.12, 0.05), "Rubber", taper=(0.95, 0.95))                  # cracked old tape
    t.box((0, 0.38, 0), (0.046, 0.04, 0.05), "Rope")                                         # frayed binding
    t.cyl((0, 0.455, 0), 0.026, 0.022, 0.03, "Rust", seg=6)
    eye_block(t, 0.5, "Rust", 0.05, 0.075, 0.06)
    arc_head(t, 0.5, 0.27, "Rust", 0.024, droop=0.025)
    t.box((0, 0.46, 0.0), (0.014, 0.05, 0.03), "Steel")                                     # loose wedge
    t.finish()


def pickaxe_reinforced(root):
    t = TM("Body", root)
    t.cyl((0, 0.24, 0), 0.020, 0.022, 0.66, "Wood", seg=8, squash=1.05)
    for x in (-0.027, 0.027):
        t.box((x, 0.28, 0), (0.012, 0.5, 0.034), "Steel")                                   # steel braces down both sides
    for y in (0.06, 0.2, 0.38):
        t.cyl((0, y, 0), 0.034, 0.034, 0.03, "Steel", seg=8)                                # collars
        for sx in (-1, 1):
            t.box((sx * 0.033, y, 0), (0.008, 0.012, 0.012), "Bright")                      # rivet heads
    eye_block(t, 0.55, "Steel", 0.075, 0.1, 0.075)
    arc_head(t, 0.55, 0.325, "Red", 0.034, droop=0.03)
    for sgn in (-1, 1):
        t.cyl((0, 0.52, sgn * 0.322), 0.0, 0.022, 0.06, "Steel", seg=6, axis='z') if sgn > 0 else t.cyl((0, 0.52, sgn * 0.322), 0.022, 0.0, 0.06, "Steel", seg=6, axis='z')   # hardened tips
    t.finish()


def drill(root, battery=False):
    t = TM("Body", root)
    t.box((0, 0.12, -0.04), (0.10, 0.13, 0.30), "Yellow", taper=(0.9, 0.88))                  # motor housing, chamfered
    t.box((0, 0.12, 0.14), (0.085, 0.105, 0.06), "Rubber")                                   # rear motor cap
    for z in (-0.08, -0.04, 0.0):
        t.box((0.052, 0.13, z), (0.008, 0.07, 0.018), "Rubber")                              # vents
        t.box((-0.052, 0.13, z), (0.008, 0.07, 0.018), "Rubber")
    t.box((0, 0.0, 0.05), (0.07, 0.17, 0.08), "Rubber", taper=(0.9, 0.9))                    # pistol grip
    for y in (-0.03, 0.0, 0.03):
        t.box((0, y, 0.092), (0.06, 0.008, 0.008), "Rubber")                                 # finger ridges
    t.box((0, 0.075, 0.0), (0.016, 0.035, 0.026), "Steel")                                   # trigger
    t.cyl((0, 0.12, -0.2), 0.04, 0.032, 0.07, "Steel", seg=8, axis='z')                      # chuck
    t.cyl((0, 0.12, -0.235), 0.036, 0.036, 0.02, "Bright", seg=8, axis='z')
    t.cyl((-0.095, 0.07, -0.12), 0.012, 0.012, 0.09, "Rubber", seg=6, axis='x')              # side handle
    t.cyl((-0.145, 0.07, -0.12), 0.018, 0.025, 0.06, "Rubber", seg=6, axis='x')
    if battery:
        t.box((0, -0.1, 0.06), (0.11, 0.06, 0.14), "Yellow")
    else:
        t.tube([(0, -0.06, 0.07), (0, -0.1, 0.12), (0, -0.16, 0.2), (0, -0.22, 0.27), (0, -0.3, 0.36)], 0.011, "Rubber", seg=6)   # power cord
    t.finish()
    bit = TM("Spinner", root, loc=(0, 0.12, -0.25))
    bit.cyl((0, 0, -0.17), 0.014, 0.004, 0.34, "Steel", seg=6, axis='z')
    bit.box((0.0, 0.0, -0.1), (0.032, 0.007, 0.2), "Bright")                                 # flutes (show the rotation)
    bit.box((0.0, 0.0, -0.25), (0.007, 0.024, 0.1), "Bright")
    bit.finish()


def jackhammer(root):
    t = TM("Body", root)
    t.box((0, 0.0, 0), (0.12, 0.034, 0.034), "Steel")
    t.cyl((0, 0.0, 0), 0.018, 0.018, 0.22, "Steel", seg=8, axis='x')                         # T-handle bar
    for sx in (-1, 1):
        t.cyl((sx * 0.15, 0.0, 0), 0.034, 0.034, 0.1, "Rubber", seg=8, axis='x')              # rubber grips
        t.cyl((sx * 0.205, 0.0, 0), 0.04, 0.04, 0.014, "Rubber", seg=8, axis='x')             # end flanges
    t.cyl((0, -0.03, 0), 0.05, 0.05, 0.05, "Steel", seg=8)                                    # top cap
    t.cyl((0, -0.22, 0), 0.07, 0.062, 0.36, "Red", seg=8)                                      # body
    t.cyl((0, -0.1, 0), 0.078, 0.078, 0.03, "Steel", seg=8)                                    # ribs
    t.cyl((0, -0.34, 0), 0.078, 0.078, 0.03, "Steel", seg=8)
    t.box((0, -0.06, 0.08), (0.08, 0.1, 0.06), "Steel")                                        # valve block
    t.cyl((0, -0.06, 0.12), 0.02, 0.02, 0.04, "Bright", seg=6, axis='z')                       # air inlet
    t.tube([(0, -0.06, 0.14), (0, -0.04, 0.25), (0, -0.12, 0.33), (0, -0.28, 0.36)], 0.016, "Rubber", seg=6)   # hose
    t.cyl((0, -0.405, 0), 0.07, 0.07, 0.03, "Rubber", seg=8)                                   # spring retainer at the nose
    t.finish()
    ch = TM("Spinner", root, loc=(0, -0.42, 0))
    ch.cyl((0, 0.0, 0), 0.03, 0.03, 0.04, "Steel", seg=6)
    ch.cyl((0, -0.1, 0), 0.016, 0.016, 0.16, "Bright", seg=6)                                  # shank
    ch.cyl((0, -0.2, 0), 0.016, 0.004, 0.06, "Bright", seg=6)                                  # a pointed tip
    ch.finish()


# ------------------------------------------------------------------------------------------------ Phase 9 tools
def chisel_common(t, tipmat="Steel"):
    t.cyl((0, 0.05, 0), 0.0215, 0.0215, 0.15, "Rubber", seg=8)                               # taped grip
    ring_grips(t, -0.02, 0.12, 0.0215, "Rubber", n=4)
    t.cyl((0, -0.03, 0), 0.03, 0.016, 0.04, "Bright", seg=8)                                  # the mushroomed strike end
    t.cyl((0, 0.123, 0), 0.036, 0.036, 0.012, "Steel", seg=8)                                  # hand guard ring


def pointed_chisel(root):
    t = TM("Body", root)
    chisel_common(t)
    t.cyl((0, 0.25, 0), 0.013, 0.013, 0.26, "Steel", seg=8)                                   # shaft
    t.cyl((0, 0.40, 0), 0.0135, 0.0025, 0.1, "Bright", seg=8)                                 # the long point
    t.cyl((0, 0.35, 0), 0.0145, 0.0145, 0.014, "Bright", seg=8)
    t.finish()


def flat_chisel(root):
    t = TM("Body", root)
    chisel_common(t)
    t.cyl((0, 0.25, 0), 0.015, 0.015, 0.24, "Steel", seg=8)
    # the blade flares from the shaft to a wide bevelled edge
    t.hexa([(-0.014, 0.32, -0.013), (0.014, 0.32, -0.013), (0.014, 0.32, 0.013), (-0.014, 0.32, 0.013),
            (-0.043, 0.425, -0.004), (0.043, 0.425, -0.004), (0.043, 0.43, 0.004), (-0.043, 0.43, 0.004)], "Steel")
    t.box((0.0, 0.43, 0.0), (0.086, 0.008, 0.006), "Bright")                                  # the worn bright edge
    t.box((0.03, 0.385, 0.0), (0.028, 0.05, 0.016), "Rust")                                    # rust bloom on the blade
    t.box((0.0, 0.15, 0.0), (0.05, 0.02, 0.05), "Steel")
    t.box((0.034, 0.428, 0.0), (0.012, 0.016, 0.012), "Rubber")                                # a nick
    t.finish()


def pickaxe_repaired(root):
    t = TM("Body", root)
    t.cyl((0, 0.22, 0), 0.018, 0.0205, 0.6, "Wood", seg=8, squash=1.1)
    t.cyl((0, 0.07, 0), 0.027, 0.027, 0.14, "Rope", seg=8)                                    # rope-wound grip
    ring_grips(t, 0.0, 0.14, 0.027, "Rope", n=6)
    for y in (0.34, 0.43):
        t.cyl((0, y, 0), 0.032, 0.032, 0.03, "Steel", seg=8)                                  # bands
    t.box((0.027, 0.27, 0), (0.012, 0.2, 0.05), "Steel")                                      # splint plate
    for y in (0.19, 0.27, 0.35):
        t.box((0.035, y, 0), (0.01, 0.014, 0.02), "Bright")                                   # rivets
    eye_block(t, 0.5, "Steel", 0.058, 0.07, 0.06)
    arc_head(t, 0.5, 0.28, "Steel", 0.026, droop=0.025)
    t.box((0, 0.505, 0), (0.06, 0.05, 0.08), "Bright")                                        # welded patch plate over the eye
    t.finish()


def sledgehammer(root):
    t = TM("Body", root)
    t.cyl((0, 0.3, 0), 0.025, 0.029, 0.82, "Wood", seg=8, squash=1.15)                         # long oval ash handle
    t.cyl((0, 0.03, 0), 0.031, 0.031, 0.28, "Rubber", seg=8)                                   # grip wrap
    ring_grips(t, -0.1, 0.16, 0.031, "Rubber", n=6)
    t.cyl((0, -0.09, 0), 0.04, 0.032, 0.05, "Rubber", seg=8)                                   # flared knob so it can't slip
    t.cyl((0, 0.74, 0), 0.068, 0.068, 0.30, "Steel", seg=8, axis='z', phase=math.pi / 8)       # octagonal head
    for sgn in (-1, 1):
        t.cyl((0, 0.74, sgn * 0.15), 0.052, 0.052, 0.012, "Bright", seg=8, axis='z', phase=math.pi / 8)   # worn striking faces
        t.cyl((0, 0.74, sgn * 0.085), 0.071, 0.071, 0.022, "Red", seg=8, axis='z', phase=math.pi / 8)      # paint bands
    t.cyl((0, 0.66, 0), 0.036, 0.046, 0.06, "Steel", seg=8)                                    # collar under the head
    t.box((0, 0.805, 0), (0.016, 0.012, 0.05), "Bright")                                       # wedge
    t.finish()


def pickaxe_steel(root):
    t = TM("Body", root)
    t.cyl((0, 0.23, 0), 0.0175, 0.0205, 0.64, "Wood", seg=8, squash=1.1)
    t.cyl((0, 0.05, 0), 0.025, 0.031, 0.26, "Rubber", seg=8)                                   # swelling rubber grip
    ring_grips(t, -0.07, 0.17, 0.028, "Rubber", n=5)
    t.cyl((0, 0.46, 0), 0.034, 0.03, 0.06, "Steel", seg=8)                                     # ferrule
    eye_block(t, 0.55, "Steel", 0.06, 0.09, 0.075)
    arc_head(t, 0.55, 0.33, "Bright", 0.03, droop=0.035)
    t.finish()


def pickaxe_hardened(root):
    t = TM("Body", root)
    t.cyl((0, -0.03, 0), 0.024, 0.032, 0.2, "Rubber", seg=8)                                  # ergonomic grip
    ring_grips(t, -0.12, 0.07, 0.03, "Rubber", n=4)
    t.cyl((0, 0.34, 0), 0.019, 0.022, 0.46, "Blue", seg=8, squash=1.15)                        # composite handle
    t.cyl((0, 0.09, 0), 0.034, 0.034, 0.022, "Steel", seg=8)
    t.cyl((0, -0.07, 0), 0.038, 0.032, 0.03, "Steel", seg=8)
    eye_block(t, 0.56, "Steel", 0.07, 0.11, 0.09)
    arc_head(t, 0.56, 0.33, "Steel", 0.034, droop=0.03, side="front")                          # the pick side
    # the other side is a flat chisel blade with a rubber bumper
    t.hexa([(-0.025, 0.535, 0.04), (0.025, 0.535, 0.04), (0.025, 0.585, 0.04), (-0.025, 0.585, 0.04),
            (-0.045, 0.505, 0.28), (0.045, 0.505, 0.28), (0.045, 0.625, 0.28), (-0.045, 0.625, 0.28)], "Steel")
    t.box((0, 0.56, 0.05), (0.074, 0.03, 0.05), "Red")                                         # painted stripe
    t.box((0, 0.565, 0.285), (0.09, 0.12, 0.02), "Rubber")                                     # bumper on the blade
    t.cyl((0, 0.53, -0.325), 0.012, 0.0, 0.05, "Bright", seg=6, axis='z')                      # hardened tip
    t.finish()


def hand_splitter(root):
    t = TM("Body", root)
    t.cyl((0, -0.05, 0), 0.03, 0.034, 0.2, "Rubber", seg=8)                                    # rubber grip
    ring_grips(t, -0.14, 0.04, 0.032, "Rubber", n=5)
    t.cyl((0, 0.15, 0), 0.05, 0.05, 0.016, "Steel", seg=8)                                     # hand guard
    t.cyl((0, 0.29, 0), 0.032, 0.03, 0.28, "Steel", seg=8)                                     # column
    t.box((0, 0.46, 0), (0.07, 0.09, 0.15), "Steel")                                           # jaw block
    for z in (-0.083, 0.083):
        t.box((0, 0.47, z), (0.06, 0.12, 0.016), "Steel")                                      # jaw plates
    t.box((0, 0.575, 0), (0.035, 0.1, 0.12), "Bright", taper=(0.35, 1.0))                       # wedge
    t.cyl((0, 0.47, 0.105), 0.016, 0.016, 0.21, "Bright", seg=6, axis='z')                     # cross bolt
    t.cyl((0, 0.3, 0.0), 0.018, 0.018, 0.13, "Bright", seg=6, axis='x')                        # pivot bolt
    t.finish()
    lv = TM("Lever", root, loc=(0, 0.3, 0.0))
    lv.box((0, 0, 0), (0.1, 0.06, 0.08), "Orange")                                             # eye round the column
    lv.box((0, 0, 0.22), (0.036, 0.04, 0.4), "Orange")                                         # arm
    lv.cyl((0, 0, 0.39), 0.028, 0.028, 0.12, "Rubber", seg=8, axis='z')                        # hand grip on the end
    lv.finish()


def powered_hammer(root):
    t = TM("Body", root)
    t.box((0, 0.12, 0.0), (0.13, 0.16, 0.30), "Orange", taper=(0.92, 0.9))                     # housing
    t.box((0, 0.12, 0.165), (0.11, 0.13, 0.03), "Rubber")                                      # end cap
    for z in (-0.06, -0.02, 0.02, 0.06):
        t.box((0.067, 0.13, z), (0.012, 0.08, 0.016), "Rubber")                                # vent slats
        t.box((-0.067, 0.13, z), (0.012, 0.08, 0.016), "Rubber")
    t.box((0, 0.0, 0.07), (0.055, 0.19, 0.075), "Rubber", taper=(0.9, 0.9))                    # pistol grip
    t.box((0, 0.07, 0.02), (0.022, 0.05, 0.03), "Steel")                                       # trigger
    t.box((0, 0.215, 0.09), (0.1, 0.036, 0.1), "Rubber")                                       # top handle
    t.cyl((0, 0.12, -0.15), 0.045, 0.045, 0.14, "Steel", seg=8, axis='z')                      # barrel
    t.cyl((0, 0.12, -0.18), 0.054, 0.054, 0.035, "Steel", seg=8, axis='z')                     # clamp ring
    t.cyl((-0.095, 0.12, -0.17), 0.016, 0.016, 0.07, "Rubber", seg=6, axis='x')                # side grip
    t.cyl((-0.14, 0.12, -0.17), 0.02, 0.026, 0.04, "Rubber", seg=6, axis='x')
    t.tube([(0, 0.12, 0.17), (0, 0.09, 0.21), (0, 0.03, 0.235), (0, -0.04, 0.24)], 0.014, "Rubber", seg=6)   # cable
    t.finish()
    ram = TM("Spinner", root, loc=(0, 0.12, -0.32))
    ram.box((0, 0, 0.0), (0.07, 0.07, 0.05), "Bright")                                         # the hammer collar
    ram.box((0, 0, 0.06), (0.05, 0.05, 0.1), "Steel")
    ram.cyl((0, 0, -0.07), 0.015, 0.015, 0.12, "Bright", seg=6, axis='z')                      # bit
    ram.cyl((0, 0, -0.15), 0.014, 0.003, 0.04, "Bright", seg=6, axis='z')
    ram.finish()


def pneumatic_chisel(root):
    t = TM("Body", root)
    t.cyl((0, -0.4, 0), 0.054, 0.048, 0.37, "Steel", seg=8)                                    # body
    t.cyl((0, -0.27, 0), 0.058, 0.058, 0.05, "Blue", seg=8)                                    # colour band
    t.cyl((0, -0.04, 0), 0.062, 0.058, 0.05, "Steel", seg=8)                                   # top cap
    t.cyl((0, -0.435, 0), 0.058, 0.058, 0.035, "Rubber", seg=8)                                # spring retainer
    t.cyl((0, 0.01, 0), 0.034, 0.03, 0.04, "Bright", seg=6)                                    # post
    t.cyl((0, 0.04, 0), 0.02, 0.02, 0.34, "Steel", seg=8, axis='x')                            # T-handle bar
    for sx in (-1, 1):
        t.cyl((sx * 0.15, 0.04, 0), 0.032, 0.032, 0.1, "Rubber", seg=8, axis='x')
    t.box((0.0, -0.01, 0.06), (0.04, 0.04, 0.05), "Bright")                                    # air inlet
    t.tube([(0, -0.01, 0.085), (0, 0.0, 0.17), (0, -0.04, 0.26), (0, -0.14, 0.32), (0, -0.26, 0.34)], 0.017, "Rubber", seg=6)   # air hose
    t.finish()
    ch = TM("Spinner", root, loc=(0, -0.44, 0))
    ch.box((0, 0.0, 0), (0.05, 0.04, 0.05), "Steel")
    ch.cyl((0, -0.08, 0), 0.016, 0.016, 0.14, "Bright", seg=6)
    ch.box((0, -0.17, 0), (0.05, 0.05, 0.012), "Bright", taper=(0.3, 1.0))
    ch.finish()


def shovel(root):
    t = TM("Body", root)
    t.cyl((0, 0.34, 0), 0.0175, 0.0195, 0.72, "Wood", seg=8, squash=1.05)                      # ash shaft
    # D-grip: a closed loop of wood at the top end
    t.tube([(-0.075, -0.075, 0), (-0.075, -0.03, 0), (-0.045, 0.004, 0), (0, 0.016, 0), (0.045, 0.004, 0), (0.075, -0.03, 0), (0.075, -0.075, 0)], 0.016, "Wood", seg=6)
    t.cyl((0, 0.69, 0), 0.036, 0.026, 0.1, "Steel", seg=8)                                     # socket
    t.box((0.0, 0.74, 0.0), (0.05, 0.03, 0.05), "Steel")
    # the blade: a turned-over top, a flat body, a point bent forward into a scoop
    t.slab(0.72, -0.018, 0.17, 0.84, -0.024, 0.19, 0.01, "Steel")
    t.slab(0.84, -0.024, 0.19, 0.93, -0.05, 0.17, 0.01, "Steel")
    t.slab(0.93, -0.05, 0.17, 1.0, -0.078, 0.07, 0.01, "Steel")
    t.slab(0.97, -0.067, 0.07, 1.0, -0.078, 0.07, 0.012, "Bright")                              # a worn, bright cutting edge
    t.box((0.0, 0.76, 0.012), (0.03, 0.12, 0.016), "Steel")                                    # centre rib on the back
    for sx in (-1, 1):
        t.slab(0.74, -0.015, 0.012, 0.93, -0.046, 0.012, 0.03, "Steel", x=sx * 0.088)           # rolled side rims
    t.box((0.05, 0.84, -0.032), (0.05, 0.08, 0.004), "Rust")                                    # a patch of rust
    t.box((0.0, 0.72, -0.026), (0.17, 0.014, 0.016), "Steel")                                   # turned-over step on top of the blade
    t.finish()


def ramp_plan(root):
    t = TM("Body", root)
    t.cyl((0, 0.3, 0), 0.016, 0.014, 0.68, "Wood", seg=8)                                      # surveyor's staff
    t.cyl((0, -0.03, 0), 0.02, 0.006, 0.07, "Steel", seg=6)                                    # spike
    t.cyl((0, 0.01, 0), 0.025, 0.025, 0.04, "Rubber", seg=8)
    t.box((0.0, 0.58, -0.07), (0.012, 0.13, 0.15), "Orange")                                   # flag
    t.box((0.0, 0.58, -0.07), (0.014, 0.04, 0.15), "Yellow")                                   # stripe
    t.cyl((0, 0.16, 0), 0.04, 0.04, 0.2, "Paper", seg=8, axis='x')                             # rolled plan
    t.cyl((0, 0.16, 0), 0.043, 0.043, 0.02, "Rope", seg=8, axis='x')                           # its tie
    t.finish()


# ------------------------------------------------------------------------------------------------ hands
def hand(root, mirror):
    """A gloved hand closed round a grip whose axis is local Y (through the origin), forearm running out along +Z. Right hand; `mirror` makes the left.
    Dimensions are real size: the game scales it to undo the tool's own scale."""
    t = TM("Body", root, mirror=mirror)
    r = 0.021                                                                              # the typical handle
    R = r + 0.0085
    t.box((0, 0.0, r + 0.026), (0.078, 0.09, 0.034), "Glove", taper=(0.9, 0.95))           # palm pad against the handle
    t.box((0, 0.0, r + 0.052), (0.082, 0.094, 0.026), "Glove", taper=(0.95, 0.95))          # back of the hand
    for i, y in enumerate((-0.036, -0.012, 0.012, 0.036)):
        finger_arc(t, y, R + 0.002 * (i % 2), 14, -205, 0.0092 - (0.0007 if i == 3 else 0), "Glove", n=6, seg=5)   # the four fingers wrap round
        t.box((0.0, y, r + 0.075), (0.02, 0.019, 0.016), "Glove")        # knuckles
    finger_arc(t, 0.056, R + 0.004, 40, 175, 0.0105, "Glove", n=5, seg=5)                    # the thumb comes over the top of the grip
    t.cyl((0, 0.0, r + 0.098), 0.032, 0.034, 0.05, "Glove", seg=8, axis='z', squash=1.1)    # glove gauntlet
    t.cyl((0, 0.0, r + 0.138), 0.047, 0.047, 0.026, "Band", seg=10, axis='z')                 # reflective cuff band
    t.cyl((0, 0.0, r + 0.222), 0.05, 0.066, 0.26, "Sleeve", seg=10, axis='z')                   # the miners' orange jacket sleeve
    t.finish()


# ------------------------------------------------------------------------------------------------ build
TOOLS = {
    "rock_hammer": rock_hammer, "pickaxe_worn": pickaxe_worn, "pickaxe_reinforced": pickaxe_reinforced, "drill": drill, "jackhammer": jackhammer,
    "pointed_chisel": pointed_chisel, "flat_chisel": flat_chisel, "repaired_pickaxe": pickaxe_repaired, "sledgehammer": sledgehammer,
    "steel_pickaxe": pickaxe_steel, "hardened_pickaxe": pickaxe_hardened, "hand_splitter": hand_splitter, "powered_hammer": powered_hammer,
    "pneumatic_chisel": pneumatic_chisel, "shovel": shovel, "ramp_plan": ramp_plan,
}


def build_one(name, fn, glb_name, *args):
    Q.reset()
    root = empty("QD_" + name, size=0.05)
    fn(root, *args)
    os.makedirs(SRC, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, name + ".blend"))
    path = os.path.join(OUT, glb_name)
    Q.export_glb(path)
    tris = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
    print("TOOL", name, os.path.getsize(path), "bytes", tris, "faces")


if __name__ == "__main__":
    only = [a for a in sys.argv[sys.argv.index("--") + 1:]] if "--" in sys.argv else []
    for name, fn in TOOLS.items():
        if only and name not in only:
            continue
        build_one(name, fn, "TOOL_QD_%s.glb" % name)
    if not only or "hands" in only:
        build_one("hand_r", hand, "HAND_QD_R.glb", False)
        build_one("hand_l", hand, "HAND_QD_L.glb", True)
    print("BUILD_OK")
