"""QUARRY DAYS - THE COLOSSUS, re-created from scratch in Blender and made scarier.   (An original model: nothing from THE_VEIL asset pack is used or modified.)

    blender -b --factory-startup -P tools/creatures/build_colossus.py

Writes assets/creatures/CRT_QD_Colossus.glb (+ src/CRT_QD_Colossus.blend, previews in docs/previews/colossus_*.png). Godot model space after export: metres, +Y up, it FACES +Z, origin on the ground
under the body. About 9.5 m to the top of the back, 12 m with the arching tentacle.

What makes it scarier than the first one: a face that is almost a face (six eyes of different sizes in the wrong places, glaring pale), a VERTICAL maw that splits sideways into two hinged jaws lined with
long uneven teeth and wet red throat, an open rib cage you can see a glowing core and a hanging sac through, long stilt forelegs that end in hooked claws, wet purple-grey tentacles with hooked barbs
(one arching over its back), thin sensory stalks that hang and twitch in front of the face, a spiked dorsal ridge and bone plates, and an asymmetric body (one heavy shoulder, a broken rib, uneven legs).

Rigid hierarchy of named empties (Root > Body > Chest > Head > Maw_L / Maw_R, legs, tentacle chains), animation clips baked as NLA tracks: Idle_Breathe, Walk_Heavy, Alert, Attack_Strike, Attack_Heavy.
"""
import bpy, bmesh, math, os, sys, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "tool_models"))
import qd_blender as Q

OUT = os.path.join(Q.REPO, "assets", "creatures")
SRC = os.path.join(OUT, "src")
PREV = os.path.join(Q.REPO, "docs", "previews")

Q.MATERIALS.update({
    "ColHide":   (None, (0.13, 0.12, 0.15), 0.95, 0.0, {}),
    "ColHideLt": (None, (0.22, 0.20, 0.24), 0.95, 0.0, {}),
    "ColBone":   (None, (0.72, 0.68, 0.58), 0.9, 0.0, {}),
    "ColBoneDk": (None, (0.45, 0.41, 0.34), 0.9, 0.0, {}),
    "ColFlesh":  (None, (0.36, 0.09, 0.12), 0.45, 0.0, {}),
    "ColSkin":   (None, (0.30, 0.22, 0.30), 0.6, 0.0, {}),
    "ColTeeth":  (None, (0.86, 0.82, 0.68), 0.7, 0.0, {}),
    "ColEye":    (None, (0.86, 0.98, 0.80), 0.3, 0.0, {"emit": 3.0}),
    "ColCore":   (None, (0.78, 1.0, 0.72), 0.3, 0.0, {"emit": 4.0}),
    "ColCrack":  (None, (0.5, 0.9, 0.5), 0.4, 0.0, {"emit": 1.6}),
})

rng = random.Random(1313)


# ------------------------------------------------------------------------------------------------ geometry helpers (Blender: Z up, the creature faces -Y, which exports as +Z)

def _obj(name, bm, mat, parent=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(Q.material(mat))
    return o


def lump(bm, amount):
    """Low-poly lumpiness: every vertex pushed along its normal by a random amount."""
    bm.verts.ensure_lookup_table()
    for v in bm.verts:
        v.co += v.normal * rng.uniform(-amount, amount)


def sphere(name, c, s, mat, sub=2, lumpy=0.0, parent=None):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * s[0], v.co.y * s[1], v.co.z * s[2]))
    bm.normal_update()
    if lumpy:
        lump(bm, lumpy)
    for v in bm.verts:
        v.co += Vector(c)
    o = _obj(name, bm, mat)
    return o


def tube(name, a, b, r0, r1, mat, seg=6, cap=True):
    """A tapered tube from a to b (r0 at a, r1 at b)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    L = d.length
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=seg, radius1=r0, radius2=r1, depth=L)
    q = d.to_track_quat('Z', 'Y')
    m = Matrix.Translation((a + b) * 0.5) @ q.to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return _obj(name, bm, mat)


def cone(name, base, tip, r, mat, seg=5):
    return tube(name, base, tip, r, 0.0, mat, seg=seg)


def box(name, c, s, mat, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * s[0], v.co.y * s[1], v.co.z * s[2]))
    m = Matrix.Translation(c) @ Matrix.Rotation(rot[2], 4, 'Z') @ Matrix.Rotation(rot[1], 4, 'Y') @ Matrix.Rotation(rot[0], 4, 'X')
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return _obj(name, bm, mat)


def empty(name, loc, parent=None):
    o = bpy.data.objects.new(name, None)
    o.empty_display_type = 'PLAIN_AXES'
    o.empty_display_size = 0.3
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    if parent is not None:
        o.parent = parent
        bpy.context.view_layer.update()
        o.matrix_parent_inverse = parent.matrix_world.inverted()
    return o


def attach(obj, parent):
    """Parent keeping the world placement (so the empty at the joint is the hinge)."""
    obj.parent = parent
    bpy.context.view_layer.update()
    obj.matrix_parent_inverse = parent.matrix_world.inverted()
    return obj


# ------------------------------------------------------------------------------------------------ the body

def build():
    Q.reset()
    root = empty("QD_Colossus", (0, 0, 0))
    O = {}
    body = empty("Body", (0, 0.2, 4.4), root)
    chest = empty("Chest", (0, -1.4, 4.7), body)
    head = empty("Head", (0, -2.9, 3.9), chest)
    rear = empty("Rear", (0.3, 1.8, 4.2), body)
    belly = empty("Belly", (0, -0.2, 3.3), body)
    maw_l = empty("Maw_L", (-0.5, -4.5, 3.8), head)
    maw_r = empty("Maw_R", (0.5, -4.5, 3.8), head)
    O.update(Root=root, Body=body, Chest=chest, Head=head, Rear=rear, Belly=belly, Maw_L=maw_l, Maw_R=maw_r)

    # ---- the hunched dorsal mass: highest over a heavier left shoulder, a hump on the right rear, a spiked ridge, overlapping bone plates, hood over the head
    attach(sphere("Back", (-0.25, 0.1, 5.1), (2.2, 3.2, 1.7), "ColHide", 2, 0.3), body)
    attach(sphere("LeftShoulder", (-1.9, -1.6, 5.2), (1.6, 1.7, 1.5), "ColHide", 2, 0.3), chest)
    attach(sphere("RearMass", (0.9, 2.0, 4.5), (1.7, 1.9, 1.5), "ColHideLt", 2, 0.28), rear)
    attach(sphere("RearHump", (1.8, 2.4, 5.3), (0.9, 1.0, 0.8), "ColHide", 1, 0.2), rear)
    for i in range(10):
        t = i / 9.0
        y = -1.8 + t * 5.0
        z = 6.55 - 0.25 * t - 0.4 * math.sin(t * math.pi) * -1
        h = 0.95 - 0.45 * t + rng.uniform(-0.15, 0.2)
        attach(cone("Spike%d" % i, (rng.uniform(-0.3, 0.2), y, z - 0.35), (rng.uniform(-0.4, 0.3), y - 0.25, z + h), 0.26 - 0.1 * t, "ColBone", 5), body)
        attach(sphere("Plate%d" % i, (rng.uniform(-0.7, 0.9), y + 0.3, z - 0.55 - rng.uniform(0, 0.5)), (0.8, 0.55, 0.2), "ColBoneDk", 1, 0.08), body)
    attach(sphere("Hood", (0, -2.4, 6.0), (1.6, 2.0, 1.0), "ColHide", 2, 0.25), chest)                 # the heavy hood, pushed back and up so it frames the face instead of hiding it
    attach(cone("HoodBrow", (0, -3.6, 5.6), (0, -4.9, 5.0), 0.7, "ColHideLt", 5), chest)
    for i in range(3):                                                                                  # gill-like slits and a faint luminous crack on the right flank
        attach(box("Gill%d" % i, (2.35, 0.4 + i * 0.55, 4.6), (0.12, 0.35, 0.05), "ColFlesh", (0, 0, 0.25)), body)
    for i in range(4):
        attach(box("Crack%d" % i, (rng.uniform(-1.5, 1.5), rng.uniform(-1.8, 2.5), 6.0 - rng.uniform(0, 0.8)), (0.05, rng.uniform(0.4, 0.9), 0.04), "ColCrack", (0, 0, rng.uniform(-0.8, 0.8))), body)

    # ---- the open rib cage: four ribs on the left, three and a broken stub on the right; wet tissue between them, a hanging sac and a pale core
    def rib(side, y, size, broken=False):
        pts = []
        steps = 4
        for k in range(steps + 1):
            u = k / steps
            x = side * (0.6 + 2.0 * math.sin(u * 1.5))
            z = 3.9 - 1.9 * u - 0.5 * u * u
            pts.append((x, y, z * 1.0))
        last = steps - 2 if broken else steps
        for k in range(last):
            attach(tube("Rib", pts[k], pts[k + 1], 0.17 * size * (1 - 0.15 * k), 0.17 * size * (1 - 0.15 * (k + 1)), "ColBone", 5), belly)
        attach(cone("RibSpur", pts[last], (pts[last][0] + side * 0.3, y - 0.2, pts[last][2] - 0.35), 0.1, "ColBone", 4), belly)
    for i, y in enumerate((-1.2, -0.45, 0.3, 1.05)):
        rib(-1, y, 1.0 + 0.12 * i)
    for i, y in enumerate((-1.0, -0.2, 0.55)):
        rib(1, y, 0.9 + 0.1 * i)
    rib(1, 1.3, 0.8, broken=True)
    attach(sphere("RibFlesh", (0, 0.0, 3.3), (1.5, 1.7, 0.9), "ColFlesh", 1, 0.1), belly)
    attach(tube("SacStalk", (0, -0.1, 3.5), (0, -0.2, 2.5), 0.12, 0.2, "ColSkin", 5), belly)
    attach(sphere("Sac", (0.0, -0.2, 1.9), (0.95, 1.2, 1.3), "ColFlesh", 2, 0.12), belly)
    for i in range(6):                                                                                  # veins
        a = rng.uniform(0, math.tau)
        attach(tube("Vein", (math.cos(a) * 0.4, -0.2 + math.sin(a) * 0.5, 2.3), (math.cos(a) * 0.9, -0.2 + math.sin(a) * 1.1, 1.6 + rng.uniform(-0.3, 0.4)), 0.04, 0.025, "ColSkin", 4), belly)
    attach(sphere("Core", (0.1, -0.4, 3.0), (0.3, 0.3, 0.3), "ColCore", 1), belly)

    # ---- the head under the hood: a lumpy sensory mass, six pale eyes of different sizes set wrong, two drooping stalks, a vertical maw
    attach(sphere("HeadMass", (0, -3.7, 3.9), (1.35, 1.45, 1.5), "ColSkin", 2, 0.18), head)
    eyes = [((-0.7, -5.0, 4.7), 0.42), ((0.35, -5.15, 5.0), 0.26), ((0.95, -4.9, 4.4), 0.34), ((-0.2, -5.3, 4.2), 0.18), ((-1.0, -4.75, 4.0), 0.24), ((0.15, -5.2, 4.55), 0.15)]
    for i, (c, r) in enumerate(eyes):
        attach(sphere("EyeSocket%d" % i, (c[0], c[1] + 0.12, c[2]), (r * 1.5, r * 1.1, r * 1.5), "ColHide", 1, 0.05), head)       # a dark ring round each eye
        attach(sphere("Eye%d" % i, (c[0], c[1] - 0.06, c[2]), (r, r * 0.85, r), "ColEye", 1), head)
        attach(sphere("EyeLid%d" % i, (c[0], c[1] - 0.02, c[2] + r * 0.62), (r * 1.2, r * 0.95, r * 0.45), "ColHide", 1, 0.03), head)
    attach(sphere("Throat", (0, -4.7, 3.5), (0.55, 0.6, 1.5), "ColFlesh", 1), head)
    attach(sphere("Tongue", (0, -4.8, 2.5), (0.25, 0.5, 0.18), "ColFlesh", 1, 0.04), head)                  # the wet red inside of the maw
    for side, mj in ((-1, maw_l), (1, maw_r)):
        attach(sphere("Jaw%s" % ("L" if side < 0 else "R"), (side * 0.85, -4.85, 3.6), (0.38, 0.5, 1.7), "ColBone", 1, 0.07), mj)
        for k in range(13):                                                                               # long, uneven, crowded teeth along the inner edge, some crossing
            z = 5.0 - k * 0.19
            ln = rng.uniform(0.3, 0.85) * (1.0 - 0.25 * abs(k - 6) / 6.0)
            attach(cone("Tooth", (side * 0.5, -5.2, z), (side * (0.5 - ln * rng.uniform(0.35, 0.85)), -5.35 - ln * 0.15, z - ln * rng.uniform(0.1, 0.5)), 0.06 + 0.04 * rng.random(), "ColTeeth", 4), mj)
    for side in (-1, 1):                                                                                  # two drooping sensory stalks in front of the face
        prev = (side * 1.1, -4.9, 5.2)
        for k in range(4):
            nxt = (prev[0] + side * 0.18, prev[1] - 0.35, prev[2] - 0.55)
            attach(tube("Stalk", prev, nxt, 0.07 - 0.012 * k, 0.07 - 0.012 * (k + 1), "ColSkin", 4), head)
            prev = nxt
        attach(sphere("StalkBulb", prev, (0.1, 0.1, 0.1), "ColEye", 1), head)

    # ---- the legs: four, all different. Long sprawling forelegs (shoulder, a high lateral elbow, a long stilt, a hooked three-digit foot), shorter hind legs (forward knee, backward hock, a split hoof)
    def leg(tag, parent, pts, radii, claws):
        joints = []
        prev_parent = parent
        for k in range(len(pts) - 1):
            j = empty("Leg_%s_%d" % (tag, k), pts[k], prev_parent)
            joints.append(j)
            attach(tube("LegSeg", pts[k], pts[k + 1], radii[k], radii[k + 1], "ColHide" if k % 2 == 0 else "ColHideLt", 6), j)
            attach(sphere("Joint", pts[k + 1], (radii[k + 1] * 1.25,) * 3, "ColBoneDk", 1, 0.05), j)
            if k < len(pts) - 2:
                attach(cone("Spur", pts[k + 1], (pts[k + 1][0] + (0.35 if pts[k + 1][0] > 0 else -0.35), pts[k + 1][1] - 0.15, pts[k + 1][2] + 0.45), 0.1, "ColBone", 4), j)
            prev_parent = j
        foot = empty("Foot_%s" % tag, pts[-1], prev_parent)
        for c in claws:
            base = (pts[-1][0] + c[0] * 0.15, pts[-1][1] + c[1] * 0.15, pts[-1][2] + 0.1)
            mid = (pts[-1][0] + c[0], pts[-1][1] + c[1], pts[-1][2] + 0.18)
            tip = (pts[-1][0] + c[0] * 1.5, pts[-1][1] + c[1] * 1.5, pts[-1][2] + 0.7)
            attach(tube("Claw", base, mid, 0.13, 0.08, "ColBone", 4), foot)
            attach(cone("ClawTip", mid, tip, 0.08, "ColBone", 4), foot)
        joints.append(foot)
        return joints
    claws_f = [(0.0, -0.9), (-0.45, -0.7), (0.45, -0.7)]
    leg("FL", chest, [(-1.8, -1.6, 4.3), (-3.5, -1.9, 5.4), (-4.7, -3.3, 0.0)], [0.68, 0.5, 0.2], claws_f)
    leg("FR", chest, [(1.8, -1.6, 4.2), (3.2, -1.7, 5.0), (4.2, -3.1, 0.0)], [0.56, 0.42, 0.17], claws_f)
    leg("HL", rear, [(-1.3, 2.1, 3.9), (-2.2, 0.8, 2.7), (-2.4, 3.2, 1.3), (-2.6, 2.7, 0.0)], [0.6, 0.42, 0.28, 0.14], [(-0.3, -0.7), (0.3, -0.7)])
    leg("HR", rear, [(1.5, 2.2, 3.7), (2.2, 1.2, 2.4), (2.3, 2.9, 1.2), (2.5, 2.5, 0.0)], [0.5, 0.36, 0.24, 0.12], [(-0.25, -0.6), (0.25, -0.6)])

    # ---- tentacles: wet purple-grey, ridged, hooked barbs, each leaving the body through a puckered orifice. Two dorsal (one arching over its back), two from the flanks, two hanging from the sac
    def tentacle(tag, parent, curve, r0, barbs=True):
        joints = []
        prev_parent = parent
        pts = curve
        radii = [r0 * (1.0 - 0.9 * (k / (len(pts) - 1))) for k in range(len(pts))]
        attach(sphere("Orifice_" + tag, pts[0], (r0 * 1.9, r0 * 1.9, r0 * 1.2), "ColFlesh", 1, 0.05), parent)
        for k in range(len(pts) - 1):
            j = empty("T_%s_%02d" % (tag, k + 1), pts[k], prev_parent)
            joints.append(j)
            attach(tube("TSeg", pts[k], pts[k + 1], radii[k], radii[k + 1], "ColSkin" if k % 2 == 0 else "ColHideLt", 6), j)
            if barbs and k % 2 == 1:
                a = Vector(pts[k]); b = Vector(pts[k + 1]); m = (a + b) * 0.5
                side = Vector((0.0, 0.0, 1.0)).cross(b - a)
                side = side.normalized() if side.length > 1e-4 else Vector((1, 0, 0))
                for sgn in (-1, 1):
                    attach(cone("Barb", m + side * sgn * radii[k] * 0.8, m + side * sgn * (radii[k] * 2.3) + Vector((0, 0, -0.25)), radii[k] * 0.45, "ColBone", 4), j)
            prev_parent = j
        tipj = empty("T_%s_tip" % tag, pts[-1], prev_parent)
        hook_end = Vector(pts[-1]) + (Vector(pts[-1]) - Vector(pts[-2])).normalized() * 0.7 + Vector((0, 0, -0.25))
        hook_end.z = max(hook_end.z, 0.06)                                                          # (a hook never digs into the ground)
        attach(cone("TipHook", pts[-1], hook_end, radii[-1] * 3.0 + 0.04, "ColBone", 4), tipj)
        joints.append(tipj)
        return joints

    def arc(p0, p1, p2, p3, n):
        out = []
        for k in range(n + 1):
            t = k / n
            u = 1 - t
            out.append(tuple(u * u * u * p0[i] + 3 * u * u * t * p1[i] + 3 * u * t * t * p2[i] + t * t * t * p3[i] for i in range(3)))
        return out
    tentacle("DorsalL", body, arc((0.0, 0.3, 6.1), (0.0, -1.8, 10.0), (0.0, -4.8, 9.0), (0.0, -5.5, 5.8), 8), 0.34)
    tentacle("DorsalR", body, arc((0.8, 1.0, 5.9), (3.5, 2.0, 8.0), (6.2, 0.8, 6.5), (7.0, -1.2, 3.6), 7), 0.3)
    tentacle("FlankL", belly, arc((-2.3, 0.2, 3.7), (-4.5, 0.6, 3.5), (-6.0, 1.6, 1.8), (-6.5, 0.5, 0.45), 6), 0.26)
    tentacle("FlankR", belly, arc((2.2, -0.3, 3.5), (4.2, -1.0, 3.2), (5.8, -0.2, 1.2), (6.6, -1.4, 0.45), 6), 0.24)
    tentacle("VentA", belly, arc((-0.5, -0.4, 1.7), (-0.9, -1.2, 1.0), (-1.4, -2.4, 0.5), (-1.2, -4.0, 0.4), 5), 0.2)
    tentacle("VentB", belly, arc((0.55, 0.1, 1.6), (1.0, 1.2, 1.0), (1.2, 2.8, 0.5), (0.7, 4.3, 0.4), 5), 0.19)

    bpy.context.view_layer.update()
    return O


# ------------------------------------------------------------------------------------------------ animation

def animate():
    clips = Q.Clips()
    clips.fps = 24
    objs = [o for o in bpy.data.objects if o.type == 'EMPTY' and o.name != "QD_Colossus"]
    rest = {o.name: (o.location.copy(), o.rotation_euler.copy()) for o in objs}
    for o in objs:
        clips.track(o, "location", "rotation_euler")
    by = {o.name: o for o in objs}
    chains = {}
    for o in objs:
        if o.name.startswith("T_") or o.name.startswith("Leg_") or o.name.startswith("Foot_"):
            tag = o.name.split("_")[1]
            chains.setdefault(o.name.split("_")[0] + "_" + tag, []).append(o)
    for k in chains:
        chains[k].sort(key=lambda o: o.name)

    def reset():
        for o in objs:
            o.location = rest[o.name][0].copy()
            o.rotation_euler = rest[o.name][1].copy()

    def sm(x):
        x = max(0.0, min(1.0, x))
        return x * x * (3 - 2 * x)

    def tent(t, amp, speed, curl=0.0, spread=0.0, strike=None):
        """Wave down every tentacle chain: each joint turns a little more than the one before, out of phase."""
        for key, js in chains.items():
            if not key.startswith("T_"):
                continue
            ph = (hash(key) % 100) / 100.0 * math.tau
            for i, j in enumerate(js):
                f = (i + 1) / len(js)
                j.rotation_euler.x += amp * math.sin(t * speed + ph - i * 0.7) * (0.5 + f) + curl * 0.12
                j.rotation_euler.z += amp * 0.7 * math.cos(t * speed * 0.8 + ph - i * 0.6) * (0.4 + f) + spread * (-0.1 if "L" in key[2:] else 0.1)
        if strike is not None:
            for i, j in enumerate(chains.get("T_DorsalL", [])):
                j.rotation_euler.x += strike * (0.18 if i else 0.0)

    def body_pose(t, bob=0.0, roll=0.0, pitch=0.0, jaw=0.0, lift=0.0):
        by["Body"].location.z += bob + lift
        by["Body"].rotation_euler.y += roll
        by["Body"].rotation_euler.x += pitch
        by["Chest"].rotation_euler.x += -0.05 * math.sin(t * 1.5) - pitch * 0.5 - lift * 0.15
        by["Head"].rotation_euler.z += 0.06 * math.sin(t * 0.9)
        by["Maw_L"].rotation_euler.z += -jaw                # the jaws hinge about the vertical axis and split sideways
        by["Maw_R"].rotation_euler.z += jaw
        by["Belly"].rotation_euler.x += 0.05 * math.sin(t * 1.8 + 1.0)

    def idle(f):
        t = (f - 1) / 24.0
        reset()
        body_pose(t, bob=0.06 * math.sin(t * math.tau / 4.0), jaw=0.08 + 0.05 * math.sin(t * math.tau / 4.0 + 1.0))
        tent(t, 0.05, 1.6)
    clips.bake("Idle_Breathe", list(range(1, 97, 2)), idle)

    def walk(f):
        t = (f - 1) / 24.0
        reset()
        cyc = t / 4.0
        order = {"FL": 0.0, "HR": 0.25, "FR": 0.5, "HL": 0.75}
        for tag, off in order.items():
            js = chains.get("Leg_" + tag, [])
            ph = (cyc + off) % 1.0
            swing = math.sin(ph * math.tau)
            lift = max(0.0, math.sin(ph * math.tau + 0.5))
            if js:
                js[0].rotation_euler.x += 0.28 * swing
            if len(js) > 1:
                js[1].rotation_euler.x += -0.2 * lift + 0.1 * swing
            if len(js) > 2:
                js[2].rotation_euler.x += 0.2 * lift
        body_pose(t, bob=0.12 * abs(math.sin(cyc * math.tau * 2)), roll=0.04 * math.sin(cyc * math.tau * 2), pitch=0.02 * math.sin(cyc * math.tau * 4), jaw=0.1)
        tent(t, 0.14, 2.6, curl=0.2)
    clips.bake("Walk_Heavy", list(range(1, 97, 2)), walk)

    def alert(f):
        t = (f - 1) / 24.0
        reset()
        k = sm(t / 1.3)
        body_pose(t, lift=0.7 * k, pitch=-0.12 * k, jaw=0.65 * k)
        by["Head"].rotation_euler.x += -0.25 * k
        by["Head"].rotation_euler.z += 0.35 * sm((t - 0.6) / 1.2)
        tent(t, 0.08 + 0.1 * k, 3.0, curl=-1.4 * k, spread=2.5 * k)
        for tag in ("FL", "FR", "HL", "HR"):
            js = chains.get("Leg_" + tag, [])
            if js:
                js[0].rotation_euler.x += -0.12 * k
    clips.bake("Alert", list(range(1, 59, 2)), alert)

    def strike(f):
        t = (f - 1) / 24.0
        reset()
        wind = sm(t / 0.9)
        whip = sm((t - 1.0) / 0.16) * (1.0 - sm((t - 1.3) / 0.8))
        body_pose(t, lift=0.3 * wind, pitch=0.05 * wind - 0.2 * whip, jaw=0.7 * wind)
        tent(t, 0.06, 2.0)
        for i, j in enumerate(chains.get("T_DorsalL", [])):
            j.rotation_euler.x += (-0.22 * wind + 0.55 * whip) * (1.0 if i else 0.2)
    clips.bake("Attack_Strike", list(range(1, 62, 2)), strike)

    def heavy(f):
        t = (f - 1) / 24.0
        reset()
        rear = sm(t / 1.5)
        slam = sm((t - 1.7) / 0.18) * (1.0 - sm((t - 2.0) / 1.2))
        body_pose(t, lift=1.1 * rear - 1.2 * slam, pitch=-0.45 * rear + 0.35 * slam, jaw=0.8 * rear)
        for tag in ("FL", "FR"):
            js = chains.get("Leg_" + tag, [])
            if js:
                js[0].rotation_euler.x += -1.0 * rear + 1.6 * slam
        tent(t, 0.1, 3.5, curl=-0.8 * rear)
    clips.bake("Attack_Heavy", list(range(1, 83, 2)), heavy)
    reset()
    for o in bpy.data.objects:
        if o.animation_data:
            o.animation_data.action = None


def previews():
    bpy.context.scene.frame_set(1)
    views = {"front": ((0.0, -17.0, 4.4), (0.0, 0.0, 4.3)), "three_quarter": ((-13.0, -13.0, 7.0), (0.0, 0.0, 4.2)), "head": ((-2.2, -10.5, 4.6), (0.0, -4.6, 4.2)),
             "side": ((17.0, 0.0, 5.0), (0.0, 0.0, 4.5))}
    Q.render_views(PREV, "colossus", views, res=(1000, 700))


if __name__ == "__main__":
    O = build()
    animate()
    os.makedirs(SRC, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, "CRT_QD_Colossus.blend"))
    path = os.path.join(OUT, "CRT_QD_Colossus.glb")
    Q.export_glb(path)
    tris = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
    print("COLOSSUS", os.path.getsize(path), "bytes", tris, "faces", len([o for o in bpy.data.objects if o.type == 'EMPTY']), "joints")
    if "--previews" in sys.argv:
        previews()
    print("BUILD_OK")
