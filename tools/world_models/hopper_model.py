"""QUARRY DAYS - the Cash Hopper (Grandpa Walt's old hopper, rebuilt to the reference mockup). Built by build_world.py:
    blender -b --factory-startup -P tools/world_models/build_world.py -- cash_hopper
Separate named objects: Body (cabinet and plinth), Rim, Brackets, Panel (front access panel with the crossed-pickaxe emblem, hinges, vents), SaleDisplay, Lamp_Status / Lamp_Status2, Pivot_Funnel
(the receiving hopper), Pivot_Drawer + Cash_1..4 (the payout drawer and its reusable cash bundles), Pivot_GearA/B and Pivot_RollerA/B (behind the inspection window), Pivot_Flywheel, Pivot_Flap,
Pivot_Piston. Animation clips (NLA tracks -> GLB -> AnimationPlayer): Idle, SaleRegistered, Processing, Counting, DrawerOpen, DrawerClose, ReturnToIdle.
"""
import math
import random
import bpy
import qd_blender as Q
from qd_blender import empty
from tm import TM


def rnd(seed):
    return random.Random(seed)


def build(root):
    """Grandpa Walt's old Cash Hopper: a riveted, rusting steel hopper on a concrete plinth. Footprint 1.9 x 1.9 m, front (the display) faces -Z, a belt reaches it from any side. A wide
    octagonal funnel with a hazard rim on top of a riveted housing, a spoked cast flywheel on the +X side, a hinged flap on top, a piston ram, a status lamp, a blank sign board, a coin tray
    and a chute at the back. Named nodes for the game (scripts/cash_hopper_view.gd): Attach_Body, Attach_InputFunnel, Attach_Processor, Attach_ConveyorIn, Attach_RockSpawn, Attach_Audio,
    Attach_FloatText, Attach_Display, Pivot_Flywheel (spins about X), Pivot_Flap (hinge about X), Pivot_Piston (slides in Y), Pivot_Funnel (shakes while it works), Lamp_Status (its
    material is recoloured), Fill (the heap of rock waiting in the funnel: the game scales it)."""
    ST, SD, RU, RD, YE, IR, BR, CO, SN = "HopSteel", "HopSteelDk", "HopRust", "HopRustDk", "HopYellow", "HopIron", "HopBrass", "HopConcrete", "HopStain"
    r = rnd(23)
    t = TM("Body", root, holder=True)
    # ---- plinth, anchor bolts, oil stains
    t.box((0, 0.09, 0), (1.9, 0.18, 1.9), CO, taper=(0.97, 0.97))
    t.box((0, 0.19, 0), (1.76, 0.03, 1.76), CO)
    for sx in (-1, 1):
        for sz in (-1, 1):
            t.cyl((sx * 0.8, 0.22, sz * 0.8), 0.05, 0.05, 0.08, IR, seg=6)
            t.box((sx * 0.8, 0.185, sz * 0.8), (0.16, 0.012, 0.16), IR)
    for k in range(6):
        t.box((r.uniform(-0.8, 0.8), 0.195, r.uniform(-0.8, 0.8)), (r.uniform(0.15, 0.4), 0.004, r.uniform(0.1, 0.3)), SN, rot_y=r.uniform(0, 3))
    # ---- corner posts (steel angle), cross bracing
    for sx in (-1, 1):
        for sz in (-1, 1):
            t.box((sx * 0.78, 0.82, sz * 0.78), (0.14, 1.28, 0.14), SD)
            t.box((sx * 0.78, 0.22, sz * 0.78), (0.2, 0.06, 0.2), IR)
    for sz in (-1, 1):
        t.bar((-0.78, 0.3, sz * 0.84), (0.78, 1.1, sz * 0.84), 0.06, 0.05, SD, up=(0, 0, 1))
        t.bar((0.78, 0.3, sz * 0.84), (-0.78, 1.1, sz * 0.84), 0.06, 0.05, SD, up=(0, 0, 1))
    # ---- the housing: riveted panels with seams, vents, a service hatch at the back
    t.box((0, 0.86, 0), (1.62, 1.0, 1.62), ST, taper=(0.99, 0.99))
    for k in range(5):                                                                              # horizontal panel seams on all four faces
        y = 0.45 + k * 0.2
        t.box((0, y, -0.815), (1.64, 0.015, 0.01), SD)
        t.box((0, y, 0.815), (1.64, 0.015, 0.01), SD)
        t.box((-0.815, y, 0), (0.01, 0.015, 1.64), SD)
        t.box((0.815, y, 0), (0.01, 0.015, 1.64), SD)
    for k in range(9):                                                                              # rivet rows along the seams
        x = -0.7 + k * 0.175
        for y in (0.45, 0.85, 1.25):
            t.box((x, y + 0.02, -0.82), (0.03, 0.03, 0.02), IR)
            t.box((x, y + 0.02, 0.82), (0.03, 0.03, 0.02), IR)
    for k in range(6):                                                                              # rust blooms and scrapes
        sx = r.choice((-1, 1))
        t.box((sx * 0.815, r.uniform(0.5, 1.3), r.uniform(-0.6, 0.6)), (0.012, r.uniform(0.1, 0.3), r.uniform(0.15, 0.4)), RU if k % 2 else RD)
        t.box((r.uniform(-0.6, 0.6), r.uniform(0.5, 1.3), -0.82 if k % 2 else 0.82), (r.uniform(0.15, 0.4), r.uniform(0.1, 0.25), 0.012), RU if k % 3 else RD)
    for k in range(5):                                                                              # louvred vents on the -X side
        t.box((-0.83, 0.62 + k * 0.07, 0.0), (0.03, 0.03, 0.5), SD, taper=(1.0, 1.0))
    t.box((0, 0.75, 0.83), (0.8, 0.6, 0.03), SD)                                                    # the service hatch at the back, with hinges and a latch
    for sy in (0.55, 0.95):
        t.cyl((-0.4, sy, 0.855), 0.03, 0.03, 0.12, IR, seg=6, axis='z')
    t.box((0.3, 0.75, 0.86), (0.1, 0.05, 0.03), BR)
    # ---- the front of the cabinet: the payout slot with glowing lips, its chute and the shelf above the drawer
    t.box((0, 0.64, -0.835), (0.62, 0.1, 0.03), IR)
    t.box((0, 0.64, -0.852), (0.5, 0.045, 0.02), SN)
    t.box((0, 0.665, -0.866), (0.5, 0.012, 0.012), "HopGlow")                                       # the slot is lit from inside: glowing brass lips
    t.box((0, 0.617, -0.866), (0.5, 0.012, 0.012), "HopGlow")

    # ---- the front panel (its own object): a large central access panel with the crossed-pickaxe emblem, hinges and a handle; an inspection window on the left, the stats screen on the right
    pn = TM("Panel", root, loc=(0, 0, 0), holder=True)
    pn.box((0, 1.02, -0.84), (0.7, 0.54, 0.05), IR)
    for yy, hh in ((1.3, 0.05), (0.74, 0.05)):
        pn.box((0, yy, -0.87), (0.76, hh, 0.04), YE)                                                # the yellow frame
    for sx in (-1, 1):
        pn.box((sx * 0.365, 1.02, -0.87), (0.05, 0.6, 0.04), YE)
    pn.box((0, 1.02, -0.868), (0.62, 0.46, 0.03), SD)                                               # the panel face
    for sg in (-1, 1):                                                                              # the crossed pickaxes: a handle and a head each
        ax, ay, bx, by = -0.15 * sg, 0.93, 0.15 * sg, 1.17
        ln = math.hypot(bx - ax, by - ay)
        dx, dy = (bx - ax) / ln, (by - ay) / ln
        pn.bar((ax, ay, -0.89), (bx, by, -0.89), 0.034, 0.02, BR, up=(0, 0, -1))
        pn.bar((bx + dy * 0.11, by - dx * 0.11, -0.895), (bx - dy * 0.11, by + dx * 0.11, -0.895), 0.04, 0.025, BR, up=(0, 0, -1))
    pn.box((0, 0.86, -0.885), (0.5, 0.07, 0.012), IR)                                               # the name strip under the emblem (the game letters it)
    for yy in (0.8, 1.24):
        pn.cyl((-0.39, yy, -0.88), 0.025, 0.025, 0.07, BR, seg=6, axis='z')                         # hinges on the left edge
    pn.box((0.38, 1.02, -0.9), (0.03, 0.22, 0.04), BR)                                              # the handle and latch on the right
    pn.box((0.38, 1.16, -0.885), (0.06, 0.05, 0.03), IR)
    for sx in (-1, 1):
        for sy in (-1, 1):
            pn.cyl((sx * 0.33, 1.02 + sy * 0.22, -0.89), 0.016, 0.016, 0.014, BR, seg=6, axis='z')
    pn.box((-0.6, 1.02, -0.84), (0.26, 0.4, 0.05), IR)                                              # the inspection window (the gears and rollers turn behind its grille)
    pn.box((-0.6, 1.02, -0.87), (0.2, 0.32, 0.03), SN)
    pn.box((-0.6, 1.02, -0.884), (0.18, 0.3, 0.01), "HopGearGlow")
    for k in range(4):
        pn.bar((-0.67 + k * 0.047, 0.87, -0.925), (-0.67 + k * 0.047, 1.17, -0.925), 0.01, 0.012, IR, up=(1, 0, 0))
    pn.box((0.6, 1.02, -0.84), (0.26, 0.4, 0.05), IR)                                               # the stats screen
    pn.box((0.6, 1.02, -0.87), (0.2, 0.32, 0.03), "HopScreen")
    for sx in (-1, 1):
        for sy in (-1, 1):
            pn.cyl((0.6 + sx * 0.11, 1.02 + sy * 0.18, -0.87), 0.012, 0.012, 0.014, BR, seg=6, axis='z')
    pn.finish()

    # ---- the top plate the funnel stands on, the funnel's four brackets, the rim
    t.box((0, 1.4, 0), (1.75, 0.12, 1.75), SD, taper=(0.98, 0.98))
    t.box((0, 1.47, 0), (1.62, 0.03, 1.62), RD)
    sd = TM("SaleDisplay", root, loc=(0, 0, 0), holder=True)                                        # the sale display: a slanted green LED window on the top front (the game writes +$ on it)
    sd.box((0, 1.52, -0.77), (0.62, 0.1, 0.16), IR)
    sd.slab(1.55, -0.845, 0.58, 1.76, -0.78, 0.58, 0.05, IR, x=0.0)                      # (it rises toward the back, so it faces up and out to the front)
    sd.slab(1.565, -0.868, 0.5, 1.745, -0.806, 0.5, 0.012, "HopScreenG", x=0.0)
    sd.finish()
    br = TM("Brackets", root, loc=(0, 0, 0), holder=True)                                           # four heavy dark braces from the top plate up the corners of the hopper to its rim
    for sx in (-1, 1):
        for sz in (-1, 1):
            br.bar((sx * 0.42, 1.47, sz * 0.42), (sx * 0.76, 2.07, sz * 0.76), 0.15, 0.075, SD, up=(sx, 0, sz))
            br.box((sx * 0.42, 1.49, sz * 0.42), (0.2, 0.06, 0.2), IR, rot_y=math.pi / 4)
    br.finish()
    # ---- coin chute at the back (where belts meet it: the game links them by distance), and a drain pipe
    t.box((0, 0.55, 0.98), (0.7, 0.14, 0.3), IR)
    t.bar((0, 0.62, 0.84), (0, 0.5, 1.12), 0.64, 0.05, SD, up=(0, 1, 0))
    for sx in (-1, 1):
        t.box((sx * 0.35, 0.6, 1.05), (0.04, 0.2, 0.34), SD)
    t.cyl((-0.7, 0.5, 0.86), 0.05, 0.05, 1.0, IR, seg=6)
    # ---- the motor with its belt guard, next to the flywheel's axle
    t.box((0.9, 0.5, 0.4), (0.3, 0.3, 0.4), SD)
    t.cyl((0.9, 0.55, 0.4), 0.12, 0.12, 0.34, RU, seg=8, axis='x')
    t.box((0.9, 0.82, 0.22), (0.26, 0.16, 0.06), IR)
    t.bar((0.97, 0.6, 0.4), (0.97, 0.88, 0.05), 0.06, 0.05, IR, up=(1, 0, 0))                       # the drive belt from the motor up to the flywheel's axle
    t.finish()

    # ---- funnel: a wide octagonal frustum with ribs, a hazard rim, a dark throat
    fn = TM("Pivot_Funnel", root, loc=(0, 1.45, 0), holder=True)
    fn.cyl((0, 1.78, 0), 0.5, 0.98, 0.66, RU, seg=8)
    fn.cyl((0, 1.78, 0), 0.47, 0.94, 0.68, SN, seg=8)                                               # the inside, dark
    fn.cyl((0, 2.03, 0), 0.93, 0.93, 0.02, SN, seg=8)                                               # the dark throat, open under the rim
    for k in range(8):
        a = math.tau * (k + 0.5) / 8
        rim_k = a                                                                                   # (the rim is its own object, below)
    for k in range(6):
        a = k * 1.1
        fn.box((math.cos(a) * 0.8, 1.9 + 0.05 * (k % 3), math.sin(a) * 0.8), (0.18, 0.12, 0.012), RD, rot_y=-a)                                # rust patches
    fn.finish()
    rm = TM("Rim", root, loc=(0, 0, 0), holder=True)                                                # the thick yellow rim with black hazard stripes: 16 plates round the octagon
    for k in range(8):
        a = math.tau * (k + 0.5) / 8
        tx, tz = -math.sin(a), math.cos(a)
        for sgn in (-1, 1):
            rm.box((math.cos(a) * 0.93 + tx * sgn * 0.195, 2.14, math.sin(a) * 0.93 + tz * sgn * 0.195), (0.4, 0.1, 0.22), YE if (k * 2 + (1 if sgn > 0 else 0)) % 2 == 0 else IR, rot_y=a + math.pi / 2)
    rm.cyl((0, 2.07, 0), 0.99, 0.99, 0.05, SD, seg=8)
    rm.finish()
    fl = TM("Fill", root, loc=(0, 1.9, 0), holder=True)                                             # the heap of rock waiting in the funnel
    for k in range(14):
        a = k * 2.4
        rr = 0.32 * math.sqrt(k / 14.0)
        fl.box((math.cos(a) * rr, 1.95 + 0.07 * (k % 4), math.sin(a) * rr), (r.uniform(0.2, 0.34), r.uniform(0.14, 0.26), r.uniform(0.2, 0.34)), "HopRock", taper=(0.7, 0.7), rot_y=r.uniform(0, 3))
    fl.finish()

    # ---- flywheel (+X side): rim, spokes, hub, bolts, axle and bearing blocks
    fw = TM("Pivot_Flywheel", root, loc=(0.97, 0.85, 0.0), holder=True)
    fw.cyl((1.0, 0.85, 0), 0.43, 0.43, 0.13, IR, seg=14, axis='x')
    fw.cyl((1.0, 0.85, 0), 0.34, 0.34, 0.145, SD, seg=14, axis='x')
    fw.cyl((1.0, 0.85, 0), 0.12, 0.12, 0.2, YE, seg=8, axis='x')
    for k in range(6):
        a = k * math.tau / 6
        fw.bar((1.0, 0.85, 0), (1.0, 0.85 + math.sin(a) * 0.36, math.cos(a) * 0.36), 0.07, 0.06, IR, up=(1, 0, 0))
        fw.box((1.065, 0.85 + math.sin(a) * 0.4, math.cos(a) * 0.4), (0.02, 0.05, 0.05), BR)
    fw.box((1.09, 0.85, 0), (0.02, 0.2, 0.05), YE)                                                  # a painted mark so the spin reads
    fw.finish()
    ax = TM("Axle", root, holder=True)
    ax.cyl((0.9, 0.85, 0), 0.05, 0.05, 0.3, IR, seg=8, axis='x')
    for sz in (-1, 1):
        ax.box((0.86, 0.72, sz * 0.2), (0.12, 0.2, 0.1), SD)
    ax.finish()

    # ---- flap: a hinged steel lid over the chute side of the top plate (kicks on every sale)
    fp = TM("Pivot_Flap", root, loc=(0, 1.5, 0.8), holder=True)
    fp.box((0, 1.52, 0.55), (1.2, 0.05, 0.5), YE)
    fp.box((0, 1.555, 0.55), (1.1, 0.012, 0.4), IR, taper=(0.9, 0.9))
    for sx in (-1, 1):
        fp.cyl((sx * 0.5, 1.5, 0.8), 0.035, 0.035, 0.14, IR, seg=6, axis='x')
    fp.finish()

    # ---- the piston ram (slides in Y while it works) on the front-left corner
    ps = TM("Pivot_Piston", root, loc=(-0.92, 1.2, -0.68), holder=True)
    ps.cyl((-0.92, 1.2, -0.68), 0.045, 0.045, 0.42, BR, seg=8)
    ps.cyl((-0.92, 1.43, -0.68), 0.07, 0.07, 0.05, IR, seg=8)
    ps.finish()
    cyl = TM("Cylinder", root, holder=True)
    cyl.cyl((-0.92, 0.95, -0.68), 0.09, 0.09, 0.5, SD, seg=10)
    cyl.cyl((-0.92, 0.7, -0.68), 0.11, 0.11, 0.06, IR, seg=10)
    cyl.finish()

    # ---- two caged amber lamps on the front corners of the top plate (the game lights them, brighter while it works)
    for nm, lx in (("Lamp_Status", 0.62), ("Lamp_Status2", -0.62)):
        lm = TM(nm, root, loc=(lx, 1.5, -0.66), holder=True)
        lm.cyl((lx, 1.58, -0.66), 0.085, 0.075, 0.14, "HopAmber", seg=8)
        lm.finish()
    cg = TM("LampCage", root, holder=True)
    for lx in (0.62, -0.62):
        cg.cyl((lx, 1.5, -0.66), 0.12, 0.12, 0.05, IR, seg=8)
        cg.cyl((lx, 1.67, -0.66), 0.1, 0.1, 0.03, IR, seg=8)
        for k in range(6):
            a = k * math.tau / 6
            cg.bar((lx + math.cos(a) * 0.1, 1.52, -0.66 + math.sin(a) * 0.1), (lx + math.cos(a) * 0.085, 1.66, -0.66 + math.sin(a) * 0.085), 0.014, 0.014, IR, up=(0, 1, 0))
    cg.finish()

    # ---- the payout drawer: a yellow drawer under the central panel that slides out; the cash bundles are four separate reusable objects (hidden at scale 0 while it is shut)
    dr = TM("Pivot_Drawer", root, loc=(0, 0.43, -0.67), holder=True)                               # shut, its front panel is flush with the cabinet under the central panel; the body is inside
    dr.box((0, 0.43, -0.67), (0.84, 0.03, 0.32), YE)
    dr.box((0, 0.485, -0.83), (0.86, 0.12, 0.03), YE)
    dr.box((0, 0.485, -0.85), (0.3, 0.025, 0.02), BR)
    for sx in (-1, 1):
        dr.box((sx * 0.42, 0.47, -0.67), (0.03, 0.09, 0.32), YE)
    dr.box((0, 0.47, -0.52), (0.84, 0.09, 0.03), YE)
    dr.finish()
    cash = []
    for k in range(4):
        cx, cy, cz = -0.27 + 0.18 * k, 0.5, -0.7
        cb = TM("Cash_%d" % (k + 1), root, loc=(cx, cy, cz), holder=True)
        cb.box((cx, cy, cz), (0.14, 0.06, 0.1), "HopBill", rot_y=0.05 * (k - 1.5))
        cb.box((cx, cy + 0.002, cz), (0.04, 0.062, 0.104), "HopYellow", rot_y=0.05 * (k - 1.5))
        cb.box((cx, cy + 0.032, cz), (0.13, 0.004, 0.09), "HopCoin", rot_y=0.05 * (k - 1.5))
        cb.finish()
        cash.append(cb.holder)

    # ---- the gears and rollers behind the inspection window (they turn while it works)
    mech = {}
    for nm, gx, gy, gr, teeth in (("Pivot_GearA", -0.635, 1.1, 0.062, 10), ("Pivot_GearB", -0.565, 1.0, 0.046, 8)):
        gg = TM(nm, root, loc=(gx, gy, -0.9), holder=True)
        gg.cyl((gx, gy, -0.9), gr, gr, 0.03, BR, seg=teeth * 2, axis='z')
        gg.cyl((gx, gy, -0.9), gr * 1.22, gr * 1.22, 0.012, BR, seg=teeth, axis='z')
        gg.cyl((gx, gy, -0.9), gr * 0.35, gr * 0.35, 0.05, IR, seg=6, axis='z')
        gg.finish()
        mech[nm] = gg.holder
    for nm, ry in (("Pivot_RollerA", 0.93), ("Pivot_RollerB", 0.885)):
        rr = TM(nm, root, loc=(-0.6, ry, -0.9), holder=True)
        rr.cyl((-0.6, ry, -0.9), 0.022, 0.022, 0.17, "HopSteel", seg=8, axis='x')
        for k in range(3):
            rr.box((-0.6 - 0.06 + 0.06 * k, ry, -0.9 + 0.0), (0.01, 0.048, 0.012), IR)
        rr.finish()
        mech[nm] = rr.holder

    # ---- attachment points (empties) the game reads
    for nm, loc in (("Attach_Body", (0, 0, 0)), ("Attach_InputFunnel", (0, 1.45, 0)), ("Attach_Processor", (0, 0.55, 0)), ("Attach_ConveyorIn", (0, 0.55, 1.1)),
                    ("Attach_RockSpawn", (0, 2.35, 0)), ("Attach_Audio", (0, 1.2, 0)), ("Attach_FloatText", (0, 2.6, 0)), ("Attach_Display", (0.6, 1.02, -0.9)),
                    ("Attach_SaleDisplay", (0, 1.655, -0.81)), ("Attach_Sign", (0, 0.86, -0.9))):
        TM(nm, root, loc=loc, holder=True).finish()

    # ---- animation clips (NLA tracks -> one GLB animation each; the game's AnimationPlayer plays them): Idle, SaleRegistered, Processing, Counting, DrawerOpen, DrawerClose, ReturnToIdle
    O = {o.name: o for o in bpy.data.objects}
    clips = Q.Clips()
    clips.fps = 30
    drawer = O["Pivot_Drawer"]
    cashes = [O["Cash_%d" % (k + 1)] for k in range(4)]
    lamps = [O["Lamp_Status"], O["Lamp_Status2"]]
    gear_a, gear_b = O["Pivot_GearA"], O["Pivot_GearB"]
    roll_a, roll_b = O["Pivot_RollerA"], O["Pivot_RollerB"]
    funnel, piston, flywheel, flap = O["Pivot_Funnel"], O["Pivot_Piston"], O["Pivot_Flywheel"], O["Pivot_Flap"]
    movers = [drawer] + cashes + lamps + [gear_a, gear_b, roll_a, roll_b, funnel, piston, flywheel, flap]
    rest = {o.name: (o.location.copy(), o.rotation_euler.copy(), o.scale.copy()) for o in movers}
    for o in movers:
        clips.track(o, "location", "rotation_euler", "scale")

    def sm(x):
        x = max(0.0, min(1.0, x))
        return x * x * (3 - 2 * x)

    def reset():
        for o in movers:
            o.location, o.rotation_euler, o.scale = rest[o.name][0].copy(), rest[o.name][1].copy(), rest[o.name][2].copy()
        for c in cashes:
            c.scale = (0.001, 0.001, 0.001)

    def pose(t, drawer_out=0.0, cash_show=0.0, gear=0.0, roller=0.0, lamp=0.0, shiver=0.0, pump=0.0, flap_k=0.0, spin=0.0):
        """One pose of the machine. Godot axes: the drawer slides toward -Z (Blender +Y), the gears turn about Z (Blender -Y), the rollers and the flywheel about X."""
        reset()
        drawer.location.y = rest["Pivot_Drawer"][0].y + drawer_out
        for k, c in enumerate(cashes):
            c.location.y = rest[c.name][0].y + drawer_out
            c.location.z = rest[c.name][0].z + 0.035 * sm(cash_show * 3.0 - 0.4 * k)
            sc = max(0.001, sm(cash_show * 2.2 - 0.25 * k))
            c.scale = (sc, sc, sc)
        gear_a.rotation_euler.y = -gear
        gear_b.rotation_euler.y = gear * 1.4
        roll_a.rotation_euler.x = roller
        roll_b.rotation_euler.x = -roller * 1.2
        for lp in lamps:
            lp.scale = (1.0 + lamp, 1.0 + lamp, 1.0 + lamp)
        funnel.rotation_euler.y = -shiver
        piston.location.z = rest["Pivot_Piston"][0].z + pump
        flywheel.rotation_euler.x = spin
        flap.rotation_euler.x = -flap_k * 0.35

    N = lambda f: (f - 1) / 30.0
    clips.bake("Idle", [1, 16, 31], lambda f: pose(N(f), lamp=0.04 * math.sin(N(f) * math.pi)))          # (the lamps breathe a hair: a clip of identical frames would not export)
    clips.bake("SaleRegistered", list(range(1, 17)), lambda f: pose(N(f), lamp=0.35 * max(0.0, math.sin(N(f) / 0.5 * math.tau * 2.0)) ** 2, shiver=0.012 * math.sin(N(f) * 90.0), flap_k=sm(1.0 - N(f) / 0.4)))
    clips.bake("Processing", list(range(1, 32)), lambda f: pose(N(f), gear=math.tau * 1.5 * sm(N(f)), roller=math.tau * 2.0 * N(f), lamp=0.25 * (0.5 + 0.5 * math.sin(N(f) * math.tau * 3.0)), shiver=0.01 * math.sin(N(f) * 110.0), pump=0.05 * math.sin(N(f) * math.tau * 4.0), spin=math.tau * 2.0 * N(f)))
    clips.bake("Counting", list(range(1, 22)), lambda f: pose(N(f), gear=math.pi * sm(N(f) / 0.7), roller=math.pi * 0.8 * N(f), lamp=0.18))
    clips.bake("DrawerOpen", list(range(1, 14)), lambda f: pose(N(f), drawer_out=(0.315 * sm(N(f) / 0.3) - 0.015 * sm((N(f) - 0.3) / 0.1)), cash_show=sm(N(f) / 0.4), lamp=0.2))
    clips.bake("DrawerClose", list(range(1, 12)), lambda f: pose(N(f), drawer_out=0.3 * (1.0 - sm(N(f) / 0.3)), cash_show=1.0 - sm(N(f) / 0.2), lamp=0.1))
    clips.bake("ReturnToIdle", list(range(1, 16)), lambda f: pose(N(f), gear=math.pi * 0.5 * (1.0 - sm(N(f) / 0.45)), roller=math.pi * 0.4 * (1.0 - sm(N(f) / 0.45)), lamp=0.15 * (1.0 - sm(N(f) / 0.4))))
    reset()
    for o in bpy.data.objects:
        if o.animation_data:
            o.animation_data.action = None
