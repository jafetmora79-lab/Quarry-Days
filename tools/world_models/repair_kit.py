"""The excavator's repair kit (Blender): the fuel tank with its filler neck and threaded cap, the battery tray with its hinged cover and lead studs, and the two hydraulic hose ports,
plus the loose repair parts (jerry can with a pouring spout, battery with terminals, hose end fitting with a turning coupling nut).

Registered by build_world.py:
  excavator_kit   Kit_Turret (everything that sits on the turret, in TURRET-LOCAL Godot axes: y up, -z forward, the deck top at y 0.728) and Kit_Boom (the boom's hose port, in BOOM-LOCAL axes).
                  The game attaches Kit_Turret to the excavator's Turret node and Kit_Boom to its Boom node with identity transforms, so every position here is the real place on the machine.
                  Named parts: Fuel_Cap (holder, pivot at the filler mouth), Battery_Cover (holder, pivot at its hinge), and empties Marker_* (FuelFiller, FuelCapRest, FuelPourTarget, FuelTether,
                  BatteryTray, BatteryPositive, BatteryNegative, LeadStudPositive, LeadStudNegative, HoseStart (turret) and HoseEnd (boom)).
  repair_parts    fuel_can (Marker_SpoutTip, Marker_CanBase), battery (Marker_Positive, Marker_Negative), hose_fitting (holder Nut; axis +Y, the hose joins at -Y and the port at +Y)
"""
import math
import random

import qd_blender as Q
from qd_blender import empty
from tm import TM, B

DECK = 0.728                                                          # turret-local height of the excavator's rear deck (measured on the model)


def _mat(name, rgb, rough=1.0, emit=0.0):
    Q.MATERIALS[name] = (None, rgb, rough, 0.0, ({"emit": emit} if emit else {}))


_mat("RkPaint", (0.70, 0.58, 0.22), 0.85); _mat("RkSteel", (0.47, 0.49, 0.52), 0.6); _mat("RkDark", (0.08, 0.08, 0.09)); _mat("RkBrass", (0.80, 0.60, 0.22), 0.5)
_mat("RkRed", (0.72, 0.12, 0.10), 0.7); _mat("RkCream", (0.90, 0.85, 0.70)); _mat("RkRubber", (0.13, 0.14, 0.17)); _mat("RkRust", (0.42, 0.22, 0.12))
_mat("RkYellow", (0.92, 0.72, 0.14), 0.7); _mat("RkTerminal", (0.62, 0.64, 0.66), 0.4); _mat("RkPlus", (0.80, 0.14, 0.10)); _mat("RkMinus", (0.06, 0.06, 0.07))


def marker(parent, name, godot_loc):
    return empty(name, parent, loc=B(godot_loc), size=0.04)


def hex_ring(t, c, r, h, mat, axis='y'):
    t.cyl(c, r, r, h, mat, seg=6, axis=axis)


def excavator_kit(root):
    # ---------------------------------------------------------------- everything on the turret (turret-local Godot axes)
    kt = TM("Kit_Turret", root, loc=(0, 0, 0))
    h = kt.holder
    # ---- fuel tank: saddle plate, tank body, two straps, filler neck with a flange and a dark opening
    tx, tz = 0.56, 1.05
    kt.box((tx, DECK + 0.01, tz), (0.42, 0.02, 0.56), "RkSteel")
    kt.box((tx, DECK + 0.14, tz), (0.36, 0.24, 0.50), "RkPaint", taper=(0.97, 0.97))
    for dz in (-0.14, 0.14):
        kt.box((tx, DECK + 0.145, tz + dz), (0.375, 0.255, 0.035), "RkSteel")                      # the straps round the tank
        kt.box((tx, DECK + 0.268, tz + dz), (0.375, 0.012, 0.045), "RkDark")                        # and their buckles on top
    top = DECK + 0.26
    nz = tz - 0.13
    kt.cyl((tx, top + 0.005, nz), 0.075, 0.075, 0.012, "RkSteel", seg=10)                           # flange on the tank
    kt.cyl((tx, top + 0.045, nz), 0.052, 0.050, 0.08, "RkSteel", seg=10)                            # the filler neck (threaded: three rings)
    for k in range(3):
        kt.cyl((tx, top + 0.025 + 0.022 * k, nz), 0.057, 0.057, 0.008, "RkSteel", seg=10)
    mouth = top + 0.085
    kt.cyl((tx, mouth - 0.002, nz), 0.043, 0.043, 0.004, "RkDark", seg=10)                         # the dark opening (the neck's inside)
    kt.box((tx + 0.075, top + 0.045, nz), (0.02, 0.03, 0.02), "RkSteel")                           # the tether lug on the neck
    kt.box((tx - 0.13, top + 0.04, tz + 0.10), (0.012, 0.01, 0.012), "RkDark")                    # (a small drip stain) beside the neck
    # ---- battery tray: floor, four walls (high enough for a hinged cover to clear the terminals), studs for the two leads
    bx, bz = -0.35, 1.05
    kt.box((bx, DECK + 0.01, bz), (0.50, 0.02, 0.36), "RkSteel")
    wall_h = 0.27
    for sx in (-1, 1):
        kt.box((bx + sx * 0.225, DECK + wall_h / 2, bz), (0.03, wall_h, 0.34), "RkPaint")
    for sz in (-1, 1):
        kt.box((bx, DECK + wall_h / 2, bz + sz * 0.155), (0.42, wall_h, 0.03), "RkPaint")
    for sx in (-1, 1):
        kt.box((bx + sx * 0.225, DECK + wall_h + 0.005, bz), (0.035, 0.012, 0.36), "RkSteel")      # the rim
    kt.cyl((bx + 0.11, DECK + 0.13, bz + 0.112), 0.016, 0.016, 0.05, "RkBrass", seg=8, axis='z')    # stud for the positive lead (on the INSIDE of the rear wall: the leads stay in the tray)
    kt.cyl((bx - 0.11, DECK + 0.13, bz + 0.112), 0.016, 0.016, 0.05, "RkBrass", seg=8, axis='z')    # stud for the negative lead
    kt.box((bx + 0.11, DECK + 0.13, bz + 0.133), (0.05, 0.05, 0.012), "RkPlus")                    # colour tags on the wall
    kt.box((bx - 0.11, DECK + 0.13, bz + 0.133), (0.05, 0.05, 0.012), "RkMinus")
    # ---- hydraulic port on the turret's boom-foot housing (right face) and its mount
    px, py, pz = 0.84, 0.21, -0.62
    kt.box((px + 0.02, py, pz), (0.05, 0.14, 0.14), "RkSteel")                                      # mounting block bolted to the housing
    kt.cyl((px + 0.065, py, pz), 0.026, 0.026, 0.05, "RkBrass", seg=8, axis='x')                     # the port body
    hex_ring(kt, (px + 0.052, py, pz), 0.036, 0.016, "RkSteel", axis='x')
    kt.cyl((px + 0.105, py, pz), 0.017, 0.017, 0.04, "RkBrass", seg=8, axis='x')                     # the nipple the hose coupling seats on
    for k in range(3):
        kt.cyl((px + 0.095 + 0.012 * k, py, pz), 0.019, 0.019, 0.004, "RkBrass", seg=8, axis='x')    # its thread rings
    for k in range(4):
        a = math.pi / 2 * k
        kt.box((px + 0.0, py + math.cos(a) * 0.06, pz + math.sin(a) * 0.06), (0.012, 0.014, 0.014), "RkDark")     # four bolt heads
    # ---- markers (turret-local)
    marker(h, "Marker_FuelFiller", (tx, mouth, nz))
    marker(h, "Marker_FuelPourTarget", (tx, mouth - 0.02, nz))
    marker(h, "Marker_FuelCapRest", (tx - 0.13, top + 0.022, tz + 0.08))
    marker(h, "Marker_FuelTether", (tx + 0.075, top + 0.06, nz))
    marker(h, "Marker_BatteryTray", (bx, DECK + 0.02, bz))
    marker(h, "Marker_BatteryPositive", (bx + 0.11, DECK + 0.02 + 0.20 + 0.03, bz - 0.05))
    marker(h, "Marker_BatteryNegative", (bx - 0.11, DECK + 0.02 + 0.20 + 0.03, bz - 0.05))
    marker(h, "Marker_LeadStudPositive", (bx + 0.11, DECK + 0.13, bz + 0.085))
    marker(h, "Marker_LeadStudNegative", (bx - 0.11, DECK + 0.13, bz + 0.085))
    marker(h, "Marker_HydraulicHoseStart", (px + 0.125, py, pz))
    kt.finish()
    # ---- the threaded filler cap (its own object; origin = the middle of the filler mouth, +Y up)
    cap = TM("Fuel_Cap", h, loc=(tx, mouth, nz))
    cap.cyl((0, 0.022, 0), 0.066, 0.066, 0.044, "RkYellow", seg=12)
    for k in range(12):                                                                              # grip ribs round the rim
        a = math.tau * k / 12
        cap.box((math.cos(a) * 0.066, 0.022, math.sin(a) * 0.066), (0.014, 0.04, 0.014), "RkYellow", rot_y=-a)
    cap.cyl((0, 0.048, 0), 0.034, 0.034, 0.012, "RkDark", seg=8)                                     # the raised centre
    cap.box((0, 0.056, 0), (0.07, 0.01, 0.014), "RkDark")                                            # the slot / breather mark
    cap.box((0.0, 0.004, 0.0), (0.095, 0.008, 0.095), "RkDark", rot_y=0.4)                           # the seal under it
    cap.box((0.066, 0.015, 0), (0.016, 0.014, 0.016), "RkSteel")                                    # tether eye on the cap
    cap.finish()
    # ---- the battery cover (its own object; origin = the hinge on the rear wall's top edge)
    cov = TM("Battery_Cover", h, loc=(bx, DECK + wall_h + 0.012, bz + 0.17))
    cov.box((0, 0.01, -0.17), (0.50, 0.02, 0.36), "RkPaint")
    cov.box((0, 0.025, -0.30), (0.20, 0.02, 0.03), "RkSteel")                                        # the lift handle
    for sx in (-1, 1):
        cov.cyl((sx * 0.2, 0.0, 0.0), 0.012, 0.012, 0.07, "RkSteel", seg=8, axis='x')                # hinge barrels
    cov.finish()
    # ---------------------------------------------------------------- the boom's hose port (boom-local Godot axes)
    kb = TM("Kit_Boom", root, loc=(0, 0, 0))
    ex, ey, ez = 0.29, 0.18, -1.0
    kb.box((ex + 0.01, ey, ez), (0.04, 0.14, 0.14), "RkSteel")
    kb.cyl((ex + 0.055, ey, ez), 0.026, 0.026, 0.05, "RkBrass", seg=8, axis='x')
    hex_ring(kb, (ex + 0.042, ey, ez), 0.036, 0.016, "RkSteel", axis='x')
    kb.cyl((ex + 0.095, ey, ez), 0.017, 0.017, 0.04, "RkBrass", seg=8, axis='x')
    for k in range(3):
        kb.cyl((ex + 0.085 + 0.012 * k, ey, ez), 0.019, 0.019, 0.004, "RkBrass", seg=8, axis='x')
    marker(kb.holder, "Marker_HydraulicHoseEnd", (ex + 0.115, ey, ez))
    kb.finish()


def repair_parts(root):
    # ---- the jerry can: red body with embossed cross, a handle bar, a screw cap and a tapered pouring spout; the spout tip is the pivot the can tilts about
    can = TM("fuel_can", root, loc=(0, 0, 0))
    ch = can.holder
    can.box((0, 0.23, 0), (0.36, 0.46, 0.17), "RkRed", taper=(0.97, 0.97))
    can.box((0, 0.46, 0), (0.30, 0.03, 0.12), "RkRed")                                               # shoulder
    can.box((0.04, 0.495, 0), (0.15, 0.03, 0.04), "RkRed")                                          # handle top bar
    for sx in (-0.02, 0.10):
        can.box((sx, 0.48, 0), (0.025, 0.05, 0.04), "RkRed")                                         # handle legs
    can.box((0, 0.23, 0.087), (0.26, 0.012, 0.004), "RkDark")                                       # embossed cross
    can.box((0, 0.23, 0.087), (0.012, 0.30, 0.004), "RkDark")
    can.box((0, 0.23, 0.0), (0.37, 0.012, 0.18), "RkDark")                                          # seam band
    can.cyl((-0.11, 0.485, 0), 0.034, 0.034, 0.04, "RkYellow", seg=8)                                # the screw cap on the can's neck
    # the spout: a tube leaning out and up from the neck, wide at the base, narrow at the tip
    can.bar((-0.12, 0.49, 0), (-0.20, 0.585, 0), 0.036, 0.036, "RkSteel")
    can.bar((-0.20, 0.585, 0), (-0.235, 0.625, 0), 0.026, 0.026, "RkSteel")
    can.box((-0.235, 0.628, 0), (0.03, 0.012, 0.03), "RkDark")                                       # the spout's mouth
    marker(ch, "Marker_SpoutTip", (-0.235, 0.628, 0))
    marker(ch, "Marker_CanBase", (0, 0, 0))
    can.finish()
    # ---- the battery: case with a ribbed top, two terminal posts (red positive on +x, black negative on -x), a strap, a label
    bat = TM("battery", root, loc=(0, 0, 0))
    bh = bat.holder
    bat.box((0, 0.10, 0), (0.34, 0.20, 0.22), "RkDark", taper=(0.985, 0.985))
    bat.box((0, 0.201, 0), (0.30, 0.006, 0.18), "RkSteel")                                          # top plate
    bat.box((0, 0.10, 0.111), (0.22, 0.10, 0.004), "RkCream")                                        # the label
    bat.box((0, 0.10, -0.111), (0.34, 0.014, 0.004), "RkYellow")
    bat.bar((-0.13, 0.205, 0.0), (0.13, 0.205, 0.0), 0.07, 0.012, "RkYellow", up=(0, 0, 1))         # carrying strap across the top
    for sx, m in ((1, "RkPlus"), (-1, "RkMinus")):
        bat.cyl((sx * 0.11, 0.222, -0.05), 0.022, 0.018, 0.04, "RkTerminal", seg=8)                  # terminal posts
        bat.cyl((sx * 0.11, 0.246, -0.05), 0.026, 0.026, 0.012, m, seg=8)                            # colour cap
    marker(bh, "Marker_Positive", (0.11, 0.252, -0.05))
    marker(bh, "Marker_Negative", (-0.11, 0.252, -0.05))
    marker(bh, "Marker_BatteryBase", (0, 0, 0))
    bat.finish()
    # ---- the hose end fitting: ferrule crimped on the hose, a hex collar and a coupling nut that turns on the thread (axis +Y; the hose joins at -Y, the port at +Y)
    hf = TM("hose_fitting", root, loc=(0, 0, 0))
    hf.cyl((0, -0.05, 0), 0.030, 0.034, 0.10, "RkBrass", seg=10)
    for k in range(3):
        hf.cyl((0, -0.08 + 0.03 * k, 0), 0.037, 0.037, 0.008, "RkBrass", seg=10)                      # crimp rings
    hf.cyl((0, 0.01, 0), 0.040, 0.040, 0.02, "RkSteel", seg=6)                                       # hex collar
    hf.finish()
    nut = TM("Nut", hf.holder, loc=(0, 0.035, 0))
    nut.cyl((0, 0.012, 0), 0.036, 0.036, 0.04, "RkSteel", seg=6)
    nut.cyl((0, 0.034, 0), 0.026, 0.026, 0.008, "RkDark", seg=10)                                    # the opening the nipple goes into
    nut.finish()
    marker(hf.holder, "Marker_Mouth", (0, 0.07, 0))
    marker(hf.holder, "Marker_HoseJoin", (0, -0.10, 0))
