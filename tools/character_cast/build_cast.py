"""QUARRY DAYS - builds the named cast as rigged, pixel-textured low-poly characters (Blender 5.x, headless).

    python tools/character_cast/paint_cast.py
    blender -b --factory-startup -P tools/character_cast/build_cast.py -- [--names Walter,Rosa] [--render <dir>]

Same construction as THE VEIL's Eddie (approval pack A): one cohesive skin-modifier body, a modelled head with nose,
brow, chin and ears, a chunky hair shell, sneakers/boots lofts, two-joint fingers, and the identical 22-bone humanoid
rig with Socket_* nodes, so scripts/art/veil_rig.gd animates every person without changes.
Each person is modelled in a canonical 1.75 m frame (Eddie's landmarks), skinned there, then warped to their own
height, leg length, widths and posture. Output: assets/characters/CHR_QD_<Name>.glb (Y up, facing -Z, feet at 0).
"""
import bpy, bmesh, math, os, sys, json
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
from cast_specs import CAST, gear_cell, SHOE_LEN, SHOE_W, SHOE_H   # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
NAMES = argv[argv.index("--names") + 1].split(",") if "--names" in argv else list(CAST)
PREV = argv[argv.index("--render") + 1] if "--render" in argv else None
OUT = os.path.join(REPO, "assets", "characters")
TEX = os.path.join(HERE, "textures")
HEAD_Z0, HEAD_Z1 = 1.470, 1.735
T_CLOTH = 0.5                     # 64 px clothing tiles -> 128 px/m


# ================================================================ generic helpers
class Part:
    def __init__(s): s.polys = []
    def add(s, pts, mat, uvs=None): s.polys.append(([Vector(p) for p in pts], mat, uvs))
    def extend(s, o): s.polys.extend(o.polys)


def pnormal(pts):
    n = Vector((0, 0, 0))
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        n.x += (a.y - b.y) * (a.z + b.z); n.y += (a.z - b.z) * (a.x + b.x); n.z += (a.x - b.x) * (a.y + b.y)
    return n.normalized() if n.length > 1e-12 else n


def box_uv(p, n, tile):
    ax = max(range(3), key=lambda k: abs(n[k]))
    if ax == 2: u, v = p.x * (1 if n.z > 0 else -1), p.y
    elif ax == 0: u, v = p.y * (1 if n.x < 0 else -1), p.z
    else: u, v = p.x * (1 if n.y > 0 else -1), p.z
    return (u / tile, v / tile)


def outward(pts, center):
    return pts if pnormal(pts).dot(sum(pts, Vector()) / len(pts) - Vector(center)) >= 0 else pts[::-1]


def tbox(part, p0, p1, w0, w1, h0, h1, side, mat, caps=True):
    p0, p1 = Vector(p0), Vector(p1); a = (p1 - p0).normalized()
    s = Vector(side) - a * a.dot(Vector(side))
    if s.length < 1e-6: s = a.orthogonal()
    s.normalize(); u = a.cross(s)
    def ring(c, w, h): return [c + s * (w / 2) * i + u * (h / 2) * j for i, j in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    r0, r1 = ring(p0, w0, h0), ring(p1, w1, h1)
    for i in range(4): part.add([r0[i], r0[(i + 1) % 4], r1[(i + 1) % 4], r1[i]], mat)
    if caps: part.add(r0[::-1], mat); part.add(r1, mat)


def ellipsoid(part, c, rx, ry, rz, mat, nu=10, nv=5, zmin=-1.0, zmax=1.0, close_bottom=True):
    """Lat-long ellipsoid slice between normalised heights zmin..zmax (dome when zmin=0)."""
    c = Vector(c); rows = []
    for i in range(nv + 1):
        t = zmin + (zmax - zmin) * i / nv; r = math.sqrt(max(0.0, 1 - t * t))
        rows.append([c + Vector((rx * r * math.cos(2 * math.pi * j / nu), ry * r * math.sin(2 * math.pi * j / nu), rz * t)) for j in range(nu)])
    for i in range(nv):
        for j in range(nu):
            q = [rows[i][j], rows[i][(j + 1) % nu], rows[i + 1][(j + 1) % nu], rows[i + 1][j]]
            if (q[0] - q[3]).length < 1e-7 and (q[1] - q[2]).length < 1e-7: continue
            part.add(outward(q, c), mat)
    if close_bottom and zmin > -1.0: part.add(outward(rows[0][::-1], c + Vector((0, 0, 1))), mat)
    return rows


def build_object(name, part, uv_fn=None, smooth=False, merge=0.0001, mats=None):
    me = bpy.data.meshes.new(name); bm = bmesh.new(); uvl = bm.loops.layers.uv.new("UVMap")
    order = []
    for _, m, _ in part.polys:
        if m not in order: order.append(m)
    for m in order: me.materials.append(mats[m])
    for pts, m, uvs in part.polys:
        try: f = bm.faces.new([bm.verts.new(p) for p in pts])
        except ValueError: continue
        f.material_index = order.index(m); f.smooth = smooth
        if uvs is None and uv_fn is not None: uvs = uv_fn(pts, pnormal(pts), m)
        if uvs is not None:
            for lp, uv in zip(f.loops, uvs): lp[uvl].uv = uv
    if merge: bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=merge)
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    return ob


def fix_seam(uv):
    us = [u for u, _ in uv]
    return [(u + 1.0 if u < 0.5 else u, v) for u, v in uv] if max(us) - min(us) > 0.5 else uv


def seg_dist(p, a, b):
    ab = b - a; t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared)); return (p - (a + ab * t)).length


# ================================================================ materials
def material(name, png, extend=False, rough=0.92):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs["Roughness"].default_value = rough
    for key in ("Specular IOR Level", "Specular"):
        if key in bsdf.inputs: bsdf.inputs[key].default_value = 0.15; break
    img = bpy.data.images.load(png, check_existing=True)
    tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = img; tn.interpolation = 'Closest'
    tn.extension = 'EXTEND' if extend else 'REPEAT'
    nt.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
    return m


# ================================================================ one character
def build(name):
    sp = CAST[name]; b = sp["body"]; f = sp["face"]; hs = sp["hair"]; gear = set(sp.get("gear", []))
    Q = "QD_" + name; tdir = os.path.join(TEX, name)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MATS = {}
    for key, ext in (("Top", False), ("TopFront", False), ("TopCuff", False), ("Pants", False), ("PantsHem", False),
                     ("Skin", False), ("Head", False), ("Hair", False), ("Shoes", True), ("Sole", False), ("Gear", True),
                     ("Badge", True), ("Over", False)):
        png = os.path.join(tdir, "T_%s_%s.png" % (Q, key))
        if os.path.exists(png): MATS[key] = material("%s_%s" % (Q, key), png, ext)

    # ------------------------------------------------------------ canonical landmarks (Eddie's)
    sh = 0.175 * b["shoulder"]; hipx = 0.095 * b["hips"]
    J = {"hips": Vector((0, -0.005, 0.93)), "spine": Vector((0, 0.0, 1.05)), "chest": Vector((0, 0.012, 1.20)),
         "neck": Vector((0, 0.0, 1.40)), "head": Vector((0, 0.012, 1.495)), "crown": Vector((0, 0.0, 1.76))}
    for s, sx in (("R", 1), ("L", -1)):
        J["shoulder" + s] = Vector((sx * sh, -0.005, 1.375)); J["clav" + s] = Vector((sx * 0.04, 0.0, 1.39))
        J["elbow" + s] = Vector((sx * (sh + 0.18), 0.0, 1.165)); J["wrist" + s] = Vector((sx * (sh + 0.33), 0.035, 0.99))
        J["hip" + s] = Vector((sx * hipx, 0.0, 0.89)); J["knee" + s] = Vector((sx * (hipx + 0.01), 0.02, 0.49))
        J["ankle" + s] = Vector((sx * (hipx + 0.015), -0.01, 0.10)); J["ball" + s] = Vector((sx * (hipx + 0.025), 0.13, 0.03))
        J["toe" + s] = Vector((sx * (hipx + 0.03), 0.22, 0.03))

    # ------------------------------------------------------------ body (skin modifier, cohesive)
    sv = [J["hips"], J["spine"], J["chest"], J["neck"], J["head"] + Vector((0, 0, 0.02)),
          J["shoulderR"], J["elbowR"], J["wristR"], J["shoulderL"], J["elbowL"], J["wristL"],
          J["hipR"], J["kneeR"], J["ankleR"] + Vector((0, 0, -0.02)), J["hipL"], J["kneeL"], J["ankleL"] + Vector((0, 0, -0.02))]
    se = [(0, 1), (1, 2), (2, 3), (3, 4), (3, 5), (5, 6), (6, 7), (3, 8), (8, 9), (9, 10), (0, 11), (11, 12), (12, 13),
          (0, 14), (14, 15), (15, 16)]
    A, L_ = b["arm"] * 1.08, (b["hips"] + b["waist"]) / 2
    rad = [0.150 * b["hips"], 0.150 * b["waist"], 0.170 * b["chest"], 0.075 * b["neck"], 0.048 * b["neck"],
           0.072 * A, 0.060 * A, 0.054 * A, 0.072 * A, 0.060 * A, 0.054 * A,
           0.088 * L_, 0.068 * L_, 0.066 * L_, 0.088 * L_, 0.068 * L_, 0.066 * L_]
    me = bpy.data.meshes.new("skel"); me.from_pydata([tuple(v) for v in sv], se, []); sk = bpy.data.objects.new("skel", me)
    bpy.context.scene.collection.objects.link(sk)
    m = sk.modifiers.new("Skin", 'SKIN'); m.branch_smoothing = 0.6
    for i, d in enumerate(me.skin_vertices[0].data): d.radius = (rad[i], rad[i])
    me.skin_vertices[0].data[0].use_root = True
    s1 = sk.modifiers.new("Sub", 'SUBSURF'); s1.levels = 1; s1.render_levels = 1
    body_me = bpy.data.meshes.new_from_object(sk.evaluated_get(bpy.context.evaluated_depsgraph_get())); bpy.data.objects.remove(sk)
    bm = bmesh.new(); bm.from_mesh(body_me)
    for v in bm.verts:
        p = v.co
        if abs(p.x) < sh + 0.06 and 0.84 < p.z < 1.47:
            cy = 0.012 if p.z > 1.1 else 0.0
            p.y = cy + (p.y - cy) * (0.66 if p.z < 1.38 else 0.80)
            if p.y > 0 and 1.10 < p.z < 1.32: p.y += 0.012
            if p.y < 0 and 0.86 < p.z < 0.98: p.y -= 0.010 + 0.012 * (b["hips"] - 1)
            if p.y > 0 and b.get("belly"):
                p.y += b["belly"] * math.exp(-((p.z - 1.03) / 0.09) ** 2) * max(0.0, 1 - abs(p.x) / 0.16)
            if p.y > 0 and b.get("bust"):
                for cx in (-0.068, 0.068):
                    p.y += b["bust"] * math.exp(-((p.x - cx) / 0.05) ** 2 - ((p.z - 1.25) / 0.05) ** 2)
            if p.z > 1.30 and abs(p.x) > 0.10: p.z -= 0.012 * (abs(p.x) - 0.10) / 0.1
        if p.z < 0.24 and sp["pants"]["kind"] in ("jeans", "work", "cargo", "coverall", "overalls"):
            for s in ("R", "L"):
                a = J["ankle" + s]
                if abs(p.x - a.x) < 0.12:
                    k = (0.24 - p.z) / 0.24 * 0.25; p.x += (p.x - a.x) * k; p.y += (p.y - a.y) * k
    bm.to_mesh(body_me); bm.free()

    # region labels per face (nearest skeleton segment)
    SEGS = {"torso": [(J["hips"], J["neck"])], "neck": [(J["neck"], J["head"])],
            "arm": [(J["shoulderR"], J["wristR"]), (J["shoulderL"], J["wristL"])],
            "leg": [(J["hipR"], J["ankleR"]), (J["hipL"], J["ankleL"])]}
    def region(c):
        if c.z < 0.905: return "leg"
        best = min(((seg_dist(c, a, bb) / (1.6 if k == "torso" else 1.0), k) for k, ss in SEGS.items() for a, bb in ss))
        return "neck" if c.z > 1.445 else best[1]
    def arm_t(c):
        s = "R" if c.x > 0 else "L"; a, bb = J["shoulder" + s], J["wrist" + s]
        return max(0.0, min(1.0, (c - a).dot(bb - a) / (bb - a).length_squared))
    t = sp["top"]; tk = t["kind"]; pk = sp["pants"]["kind"]; sleeves = t.get("sleeves", "long")
    if tk in ("tee", "polo"): sleeves = "short"
    if tk == "tank": sleeves = "none"
    def body_mat(c, n):
        r = region(c)
        if r == "leg":
            return "PantsHem" if c.z < 0.19 and pk not in ("slacks", "chinos") else "Pants"
        if r == "neck": return "Skin"
        if r == "arm":
            at = arm_t(c)
            if sleeves == "none" and at > 0.06: return "Skin"
            if sleeves == "short" and at > 0.36: return "Skin"
            if sleeves == "short" and at > 0.30: return "TopCuff"
            if sleeves == "rolled" and at > 0.62: return "Skin"
            if sleeves == "rolled" and at > 0.50: return "TopCuff"
            if at > 0.90: return "TopCuff"
            return "Top"
        if pk == "overalls" and n.y > 0.2 and abs(c.x) < 0.095 and c.z < 1.27: return "Pants"
        if pk == "coverall_waist" and c.z < 0.99: return "Pants"
        if tk == "tank" and c.z > 1.33 and (abs(c.x) > 0.075 or n.y > 0.5 and c.z > 1.37): return "Skin"
        if n.y > 0.35 and abs(c.x) < 0.14: return "TopFront"
        if tk in ("jacket",) and c.z < 0.95: return "TopCuff"
        return "Top"
    order = ["Top", "TopFront", "TopCuff", "Pants", "PantsHem", "Skin"]
    body_me.name = Q + "_Body"
    bm = bmesh.new(); bm.from_mesh(body_me); uvl = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")   # same name as the parts joined in
    for fc in bm.faces:
        c = fc.calc_center_median(); mn = body_mat(c, fc.normal); fc.material_index = order.index(mn); fc.smooth = True
        tile = 0.25 if mn in ("TopCuff", "PantsHem", "Skin") else T_CLOTH
        for lp in fc.loops: lp[uvl].uv = box_uv(lp.vert.co, fc.normal, tile)
    bm.to_mesh(body_me); bm.free()
    for k in order: body_me.materials.append(MATS[k])
    body = bpy.data.objects.new(Q + "_Body", body_me); bpy.context.scene.collection.objects.link(body)
    bvh = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())
    def surface(x, z, front=True):
        hit = bvh.ray_cast(Vector((x, 0.6 if front else -0.6, z)), Vector((0, -1 if front else 1, 0)))
        return hit[0], hit[1]

    det = Part()            # extra cloth geometry merged into the body (collars, overlays, cuffs)
    # ---- collar
    def collar(mat, open_deg, r_minor, lift):
        NA, NT = 14, 5; rings = []
        for i in range(NA + 1):
            a = math.radians(open_deg + (360 - 2 * open_deg) * i / NA)
            cc = Vector((0.085 * b["neck"] * math.sin(a), -0.012 + 0.075 * b["neck"] * math.cos(a), 1.425 + lift * math.sin(a / 2) ** 2))
            nrm = Vector((math.sin(a), math.cos(a), 0))
            rings.append([cc + (nrm * math.cos(2 * math.pi * k / NT) * 1.2 + Vector((0, 0, 1)) * math.sin(2 * math.pi * k / NT)) * r_minor for k in range(NT)])
        for i in range(NA):
            for k in range(NT):
                det.add([rings[i][k], rings[i + 1][k], rings[i + 1][(k + 1) % NT], rings[i][(k + 1) % NT]], mat)
    if tk in ("button", "flannel", "polo", "blouse", "coverall", "jacket"):
        collar("TopFront" if tk != "jacket" else "TopCuff", 26 if tk != "polo" else 34, 0.016, 0.02)
    elif tk in ("tee", "henley"):
        collar("TopCuff", 0, 0.008, 0.0)
    # ---- overlay shell (hi-vis vest, field vest, cardigan): offset copy of the torso faces
    ov = sp.get("overlay")
    if ov:
        ok = ov["kind"]; zlo = {"cardigan": 0.86, "hivis": 0.90, "fieldvest": 0.90}[ok]; gap = {"cardigan": 0.06, "hivis": 0.0, "fieldvest": 0.035}[ok]
        sleeves_ov = ok == "cardigan"
        bm = bmesh.new(); bm.from_mesh(body_me); bm.verts.ensure_lookup_table()
        nrm = {v.index: v.normal.copy() for v in bm.verts}
        for fc in bm.faces:
            c = fc.calc_center_median(); r = region(c)
            if r == "leg" and c.z < zlo: continue
            if r == "neck": continue
            if r == "arm" and not (sleeves_ov and arm_t(c) < 0.80): continue
            if r == "arm" and not sleeves_ov: continue
            if c.z < zlo or c.z > 1.43: continue
            if fc.normal.y > 0.3 and abs(c.x) < gap: continue
            off = 0.016 if r != "arm" else 0.010
            pts = [v.co + nrm[v.index] * off for v in fc.verts]
            det.add(pts, "Over")
        bm.free()
        if ok == "cardigan":
            for s in ("R", "L"):                                      # knit cuffs
                a, w = J["elbow" + s], J["wrist" + s]; p0 = a + (w - a) * 0.80
                tbox(det, p0, p0 + (w - a) * 0.08, 0.13 * A, 0.12 * A, 0.13 * A, 0.12 * A, (0, 0, 1), "TopCuff")
    # ---- hands (stylised, thumb + four two-joint fingers); gloves swap the material
    glove = "gloves" in gear
    hands = Part()
    HS = b["hands"] * 1.12                      # chunky, readable hands
    for s in ("R", "L"):
        sx = 1 if s == "R" else -1
        a = (J["wrist" + s] - J["elbow" + s]).normalized()
        inward = Vector((-sx, 0, 0)); inward = (inward - a * a.dot(inward)).normalized()
        fwd = a.cross(inward).normalized()
        if fwd.y < 0: fwd = -fwd
        w0 = J["wrist" + s] + a * 0.008; hm = "Gear" if glove else "Skin"
        tbox(hands, w0, w0 + a * 0.088 * HS, 0.080 * HS, 0.088 * HS, 0.036 * HS, 0.032 * HS, fwd, hm)
        if glove: tbox(hands, w0 - a * 0.02, w0 + a * 0.03, 0.10 * HS, 0.095 * HS, 0.06 * HS, 0.055 * HS, fwd, hm)
        for i, off in enumerate((0.031, 0.011, -0.009, -0.028)):
            L1, L2 = (0.044, 0.040, 0.042, 0.036)[i] * HS, (0.034, 0.033, 0.032, 0.026)[i] * HS
            p0 = w0 + a * 0.082 * HS + fwd * off * HS
            d1 = (a * math.cos(0.38) + inward * math.sin(0.38)).normalized(); p1 = p0 + d1 * L1
            d2 = (a * math.cos(0.95) + inward * math.sin(0.95)).normalized(); p2 = p1 + d2 * L2
            tbox(hands, p0, p1, 0.019 * HS, 0.018 * HS, 0.021 * HS, 0.019 * HS, fwd, hm)
            tbox(hands, p1 - d1 * 0.004, p2, 0.018 * HS, 0.015 * HS, 0.019 * HS, 0.016 * HS, fwd, hm)
        t0 = w0 + a * 0.02 * HS + fwd * 0.036 * HS + inward * 0.006
        dt = (a * 0.55 + fwd * 0.62 + inward * 0.45).normalized(); t1 = t0 + dt * 0.042 * HS
        dt2 = (a * 0.9 + inward * 0.45).normalized(); t2 = t1 + dt2 * 0.034 * HS
        tbox(hands, t0, t1, 0.025 * HS, 0.022 * HS, 0.026 * HS, 0.022 * HS, inward, hm)
        tbox(hands, t1 - dt * 0.004, t2, 0.021 * HS, 0.017 * HS, 0.021 * HS, 0.017 * HS, inward, hm)

    G = Part()     # rigid gear, bone chosen per vertex later by position; UVs into the gear swatch atlas
    def gu(key):
        cx, cy = gear_cell(key); return [((cx * 8 + 2 + 4 * (i in (1, 2))) / 64, 1 - (cy * 8 + 2 + 4 * (i in (2, 3))) / 64) for i in range(4)]
    def gpart(part, key):
        for pts, _, _ in part.polys:
            n = len(pts); base = gu(key)
            G.add(pts, "Gear", [base[i % 4] for i in range(n)])

    # ---- straps that follow the torso surface (suspenders, overall straps, satchel strap)
    def strap(points_front, points_back, key, w=0.03):
        pr = Part()
        for pts, front in ((points_front, True), (points_back, False)):
            prev = None
            for x, z in pts:
                loc, nr = surface(x, z, front)
                if loc is None: continue
                side = Vector((1, 0, 0)); cur = [loc + nr * 0.017 - side * w / 2, loc + nr * 0.017 + side * w / 2,
                                                 loc + nr * 0.026 + side * w / 2, loc + nr * 0.026 - side * w / 2]
                if prev:
                    for i in range(4):
                        q = [prev[i], prev[(i + 1) % 4], cur[(i + 1) % 4], cur[i]]
                        pr.add(q if front else q[::-1], "Gear")
                prev = cur
        gpart(pr, key)
    if "suspenders" in gear:
        for sx in (1, -1):
            strap([(sx * 0.07, z / 100) for z in range(94, 140, 4)], [(sx * (0.07 - 0.04 * (1 - (z - 94) / 46)), z / 100) for z in range(94, 140, 4)], "suspender", 0.028)
    if pk == "overalls":
        for sx in (1, -1):
            strap([(sx * 0.065, z / 100) for z in range(124, 142, 3)], [(sx * 0.05, z / 100) for z in range(100, 142, 4)], "strap", 0.03)
    if "satchel" in gear:
        pr = Part()
        for i in range(12):
            tt = i / 11; x = 0.13 - 0.25 * tt; z = 1.40 - 0.42 * tt
            loc, nr = surface(x, z, True)
            if loc is None: continue
            tbox(pr, loc + nr * 0.02, loc + nr * 0.02 + Vector((-0.025, 0, -0.04)), 0.03, 0.03, 0.008, 0.008, (0, 1, 0), "Gear")
        gpart(pr, "leather")
        bag = Part(); tbox(bag, Vector((-0.18, 0.02, 0.94)), Vector((-0.18, 0.02, 1.10)), 0.10, 0.10, 0.22, 0.22, (0, 1, 0), "Gear"); gpart(bag, "canvas")
    if "toolbelt" in gear:
        pr = Part()
        for i in range(16):
            a0, a1 = 2 * math.pi * i / 16, 2 * math.pi * (i + 1) / 16
            rx, ry = 0.165 * b["hips"], 0.115 * b["hips"]
            p0 = Vector((rx * math.sin(a0), ry * math.cos(a0), 0.95)); p1 = Vector((rx * math.sin(a1), ry * math.cos(a1), 0.95))
            tbox(pr, p0, p1, 0.012, 0.012, 0.05, 0.05, (0, 0, 1), "Gear", caps=False)
        gpart(pr, "leather")
        pp = Part()
        for sx in (1, -1): tbox(pp, Vector((sx * 0.17, 0.03, 0.86)), Vector((sx * 0.17, 0.03, 0.95)), 0.09, 0.10, 0.06, 0.06, (0, 1, 0), "Gear")
        gpart(pp, "canvas")
        hm = Part(); tbox(hm, Vector((0.19, -0.04, 0.80)), Vector((0.19, -0.04, 0.98)), 0.022, 0.022, 0.022, 0.022, (1, 0, 0), "Gear"); gpart(hm, "leather")
        hh = Part(); tbox(hh, Vector((0.17, -0.04, 0.80)), Vector((0.22, -0.04, 0.80)), 0.03, 0.03, 0.05, 0.05, (0, 1, 0), "Gear"); gpart(hh, "metal")
    if "radio" in gear:
        loc, nr = surface(-0.085, 1.28)
        if loc is not None:
            r = Part(); tbox(r, loc + nr * 0.02 + Vector((0, 0, -0.05)), loc + nr * 0.02 + Vector((0, 0, 0.05)), 0.05, 0.05, 0.03, 0.03, (1, 0, 0), "Gear"); gpart(r, "radio")
            an = Part(); tbox(an, loc + nr * 0.02 + Vector((0.015, 0, 0.05)), loc + nr * 0.02 + Vector((0.015, 0, 0.13)), 0.008, 0.006, 0.008, 0.006, (1, 0, 0), "Gear"); gpart(an, "black")
    if "gloves_tucked" in gear:
        for sx in (1, -1):
            loc, nr = surface(sx * 0.07, 0.86, False)
            if loc is not None:
                gt = Part(); tbox(gt, loc + nr * 0.01, loc + nr * 0.01 + Vector((0, -0.01, 0.10)), 0.07, 0.06, 0.02, 0.02, (1, 0, 0), "Gear"); gpart(gt, "glove")
    if "watch" in gear:
        w = J["wristL"]; a = (J["wristL"] - J["elbowL"]).normalized(); wt = Part()
        tbox(wt, w - a * 0.045, w - a * 0.02, 0.105 * A, 0.105 * A, 0.105 * A, 0.105 * A, (0, 0, 1), "Gear"); gpart(wt, "gold")
    if "pen" in gear:
        loc, nr = surface(-0.07, 1.27)
        if loc is not None: pn = Part(); tbox(pn, loc + nr * 0.015, loc + nr * 0.015 + Vector((0, 0, 0.06)), 0.01, 0.01, 0.01, 0.01, (1, 0, 0), "Gear"); gpart(pn, "pen")
    badge = Part()
    if "badge" in gear:
        bl, bn = surface(-0.10, 1.30)
        if bl is not None:
            bn = Vector((0, 0.97, -0.24)).normalized(); sd = Vector((0, 0, 1)).cross(bn).normalized(); up = bn.cross(sd).normalized()
            hw, hh2, th = 0.030, 0.015, 0.005; c0 = bl + bn * (0.022 if ov else 0.010)
            cs = [c0 - sd * hw - up * hh2, c0 + sd * hw - up * hh2, c0 + sd * hw + up * hh2, c0 - sd * hw + up * hh2]
            fr = [p + bn * th for p in cs]
            badge.add(fr, "Badge", [(0, 0), (1, 0), (1, 1), (0, 1)])
            for i in range(4): badge.add([cs[i], cs[(i + 1) % 4], fr[(i + 1) % 4], fr[i]], "Badge", [(0.5, 0.9)] * 4)

    extra = build_object("tmp_det", det, lambda pts, n, m: [box_uv(q, n, 0.25 if m == "TopCuff" else T_CLOTH) for q in pts], mats=MATS) if det.polys else None
    extra2 = build_object("tmp_hands", hands, (lambda pts, n, m: gu("glove")) if glove else (lambda pts, n, m: [box_uv(q, n, 0.25) for q in pts]), smooth=True, mats=MATS)
    extra3 = build_object("tmp_badge", badge, mats=MATS) if badge.polys else None
    for o in (extra, extra2):
        if o is None: continue
        for p in o.data.polygons: p.use_smooth = o is extra2
    bpy.ops.object.select_all(action='DESELECT')
    for o in (body, extra, extra2, extra3):
        if o: o.select_set(True)
    bpy.context.view_layer.objects.active = body; bpy.ops.object.join()

    # ------------------------------------------------------------ head
    jaw, ck = f.get("jaw", 1.0), f.get("cheek", 1.0)
    RINGS = [(1.470, 0.050, 0.045, 0.052, -0.012, 1.0), (1.492, 0.062 * jaw, 0.078, 0.058, 0.0, 0.85),
             (1.515, 0.073 * jaw, 0.098, 0.072, 0.0, 0.75), (1.545, 0.081 * (jaw + ck) / 2, 0.103, 0.086, 0.0, 0.80),
             (1.580, 0.088 * ck, 0.101, 0.096, 0.0, 0.85), (1.613, 0.090, 0.097, 0.103, 0.0, 0.88),
             (1.643, 0.091, 0.103, 0.105, 0.0, 0.85), (1.675, 0.087, 0.093, 0.103, -0.004, 0.90),
             (1.705, 0.073, 0.073, 0.090, -0.008, 0.95), (1.727, 0.045, 0.040, 0.055, -0.010, 1.0)]
    def ring_params(z):
        if z <= RINGS[0][0]: return RINGS[0]
        for a_, b_ in zip(RINGS, RINGS[1:]):
            if a_[0] <= z <= b_[0]:
                tt = (z - a_[0]) / (b_[0] - a_[0]); return tuple(a_[i] + (b_[i] - a_[i]) * tt for i in range(6))
        return RINGS[-1]
    def head_pt(z, phi, rp=None):
        _, W, Df, Db, cy, pw = rp or ring_params(z)
        s_, c_ = math.sin(phi), math.cos(phi)
        return Vector((W * math.copysign(abs(s_) ** pw, s_), cy + (Df if c_ > 0 else Db) * math.copysign(abs(c_) ** pw, c_), z))
    NSEG = 16; hv = []
    for k, rp in enumerate(RINGS):
        row = []
        for j in range(NSEG):
            phi = 2 * math.pi * j / NSEG; jj = j if j <= NSEG // 2 else j - NSEG; p = head_pt(rp[0], phi, rp)
            if k == 2 and jj == 0: p.y += 0.004 + 0.008 * f.get("chin", 0.8); p.z -= 0.004
            if k == 2 and abs(jj) == 1: p.y += 0.004
            if k == 6 and abs(jj) <= 1: p.y += 0.007
            if k == 5 and abs(jj) == 1: p.y -= 0.006
            if k == 4 and abs(jj) == 2: p.x += math.copysign(0.004, p.x)
            if k in (1, 2) and abs(jj) in (3, 4): p.x += math.copysign(0.004 * jaw, p.x)
            row.append(p)
        hv.append(row)
    headp = Part()
    def head_uv(pts): return fix_seam([((0.5 - math.atan2(p.x, p.y) / (2 * math.pi)) % 1.0, (p.z - HEAD_Z0) / (HEAD_Z1 - HEAD_Z0)) for p in pts])
    for k in range(len(hv) - 1):
        for j in range(NSEG):
            q = [hv[k][j], hv[k][(j + 1) % NSEG], hv[k + 1][(j + 1) % NSEG], hv[k + 1][j]]
            q = q[::-1] if pnormal(q).dot(q[0] - Vector((0, 0, q[0].z))) < 0 else q
            headp.add(q, "Head", head_uv(q))
    top = Vector((0, -0.010, 1.736))
    for j in range(NSEG):
        tq = [hv[-1][j], hv[-1][(j + 1) % NSEG], top]
        if pnormal(tq).z < 0: tq = tq[::-1]
        headp.add(tq, "Head", head_uv(tq))
    # nose by type
    ns = f.get("nose_size", 1.0); nt = f.get("nose", "straight")
    zf = lambda z: ring_params(z)[2]
    tip_y, tip_z, wing, tipw, bridge, skew = 0.138, 1.572, 0.020, 0.012, 0.0, 0.0
    if nt == "button": tip_y, tip_z, tipw = 0.128, 1.576, 0.014
    if nt == "long": tip_y, tip_z, wing, tipw = 0.142, 1.561, 0.017, 0.010
    if nt == "hooked": tip_y, tip_z, bridge = 0.138, 1.564, 0.010
    if nt == "broad": tip_y, wing, tipw = 0.132, 0.027, 0.016
    if nt == "bulb": tip_y, tip_z, wing, tipw = 0.142, 1.568, 0.023, 0.019
    if nt == "broken": skew = 0.006
    base_y = zf(1.57)
    tip_y = base_y + (tip_y - 0.101) * ns
    T = Vector((0, zf(1.622) - 0.004, 1.622)); P = Vector((skew, tip_y, tip_z)); B = Vector((skew * 0.6, base_y + (tip_y - base_y) * 0.55, tip_z - 0.013))
    M = Vector((skew * 0.5, (T.y + tip_y) / 2 + bridge * ns, (T.z + tip_z) / 2))
    for sx in (-1, 1):
        nl = Vector((sx * wing * ns, zf(1.562) + 0.001, 1.561)); ntp = Vector((sx * 0.011, zf(1.615) - 0.006, 1.613))
        tp = Vector((skew + sx * tipw * ns, tip_y - 0.008, tip_z - 0.006)); mm = Vector((M.x + sx * 0.009 * ns, M.y - 0.006, M.z))
        for fc in ([ntp, T, M, mm], [mm, M, P, tp], [ntp, mm, tp, nl], [tp, P, B], [nl, tp, B]):
            fc = list(fc)
            if pnormal(fc).x * sx < 0: fc = fc[::-1]
            headp.add(fc, "Head", head_uv(fc))
    EAR = [(0.014, 0.024), (-0.006, 0.030), (-0.020, 0.014), (-0.018, -0.010), (-0.004, -0.024), (0.012, -0.012)]
    es = f.get("ears", 1.0)
    for sx in (1, -1):
        zc, yc = 1.607, -0.008; W = ring_params(zc)[1]
        inner = [Vector((sx * (W - 0.006), yc + a * es, zc + bb * es)) for a, bb in EAR]
        outer = [Vector((sx * (W + 0.017 * es), yc + a * 1.08 * es - 0.006, zc + bb * 1.05 * es)) for a, bb in EAR]
        cap = outer if pnormal(outer).x * sx > 0 else outer[::-1]
        headp.add(cap, "Head", head_uv(cap))
        for i in range(len(EAR)):
            q = [inner[i], inner[(i + 1) % len(EAR)], outer[(i + 1) % len(EAR)], outer[i]]
            if pnormal(q).dot(sum(q, Vector()) / 4 - Vector((sx * W, yc, zc))) < 0: q = q[::-1]
            headp.add(q, "Head", head_uv(q))
    head = build_object(Q + "_Head", headp, smooth=True, mats=MATS)

    # ------------------------------------------------------------ hair
    st = hs["style"]; HC = Vector((0, -0.005, 1.60))
    hat = next((g for g in ("hardhat", "hardhat_back", "flatcap", "beanie", "cap_back") if g in gear), None)
    hairp = Part()
    def shell(zb_fn, th_fn, arc=None, crown=True, NH=24, NS=7, flare=0.0, top_z=1.728):
        phis = [2 * math.pi * j / NH for j in range(NH)] if arc is None else [math.radians(arc[0] + (arc[1] - arc[0]) * j / (NH - 1)) for j in range(NH)]
        closed = arc is None; rows = []
        for k in range(NS):
            s_ = k / (NS - 1); row = []
            for j, phi in enumerate(phis):
                pd = math.degrees(phi); pd = pd - 360 if pd > 180 else pd
                z0 = zb_fn(pd, j)
                z = z0 + (top_z - z0) * (s_ ** 0.85)
                if not crown: z = z0 + (zt_fn(pd) - z0) * s_
                spt = head_pt(max(1.48, min(z, 1.727)), phi)
                if z < 1.48:                                         # long hair below the jaw: hang straight down
                    spt = head_pt(1.50, phi); spt.z = z
                d = (spt - HC); d.z *= 0.3 if z < 1.5 else 1.0; d.normalize()
                p = spt + d * th_fn(pd, s_, k, j)
                if k == 0 and flare: p += Vector((d.x, d.y, 0)).normalized() * flare
                row.append(p)
            rows.append(row)
        cols = NH if closed else NH - 1
        for k in range(NS - 1):
            for j in range(cols):
                j2 = (j + 1) % NH
                q = [rows[k][j], rows[k][j2], rows[k + 1][j2], rows[k + 1][j]]
                uv = [(j / NH, 0.03 + 0.94 * k / (NS - 1)), ((j + 1) / NH, 0.03 + 0.94 * k / (NS - 1)), ((j + 1) / NH, 0.03 + 0.94 * (k + 1) / (NS - 1)), (j / NH, 0.03 + 0.94 * (k + 1) / (NS - 1))]
                if pnormal(q).dot(sum(q, Vector()) / 4 - HC) < 0: q, uv = q[::-1], uv[::-1]
                hairp.add(q, "Hair", uv)
        if crown:
            cr = Vector((0.0, -0.016, max(p.z for p in rows[-1]) + 0.012))
            for j in range(cols):
                tq = [rows[-1][j], rows[-1][(j + 1) % NH], cr]; uv = [(j / NH, 0.97), ((j + 1) / NH, 0.97), ((j + 0.5) / NH, 1.0)]
                if pnormal(tq).z < 0: tq, uv = tq[::-1], uv[::-1]
                hairp.add(tq, "Hair", uv)
        for j in range(cols):                                        # underside lip (reads as thickness)
            a_, b_ = rows[0][j], rows[0][(j + 1) % NH]
            ia = head_pt(max(1.48, min(a_.z + 0.004, 1.72)), phis[j]); ib = head_pt(max(1.48, min(b_.z + 0.004, 1.72)), phis[(j + 1) % NH])
            q = [a_, ia, ib, b_]
            if pnormal(q).z > 0: q = q[::-1]
            hairp.add(q, "Hair", [(j / NH, 0.0)] * 4)
        if not closed:                                               # caps at the open ends of an arc
            for j in (0, NH - 1):
                strip = [rows[k][j] for k in range(NS)]
                inner_ = [head_pt(max(1.48, min(p.z, 1.72)), phis[j]) for p in strip]
                for k in range(NS - 1):
                    hairp.add([strip[k], strip[k + 1], inner_[k + 1], inner_[k]], "Hair", [(j / NH, 0.5)] * 4)
        return rows
    def band(a, levels):              # piecewise-linear by |phi|: levels = [(deg, z), ...] ascending deg
        a = abs(a)
        for (d0, z0), (d1, z1) in zip(levels, levels[1:]):
            if d0 <= a <= d1: return z0 + (z1 - z0) * (a - d0) / (d1 - d0)
        return levels[-1][1]
    hl = hs.get("hairline", 1.68)
    def jag(j, k, amt): return -amt if j % 2 else 0.0
    zt_fn = None
    if st == "horseshoe":
        def zt_fn(pd): return band(pd, [(60, 1.640), (100, 1.665), (180, 1.685)])
        shell(lambda pd, j: band(pd, [(60, 1.600), (90, 1.585), (130, 1.540), (180, 1.525)]) - (0.006 if j % 2 else 0),
              lambda pd, s_, k, j: 0.012 + 0.010 * math.sin(math.pi * s_) + 0.006 * (j % 3 == 0), arc=(62, 298), crown=False, NS=4)
    elif st in ("crop", "buzz", "sidepart", "undercut"):
        lv = [(0, hl), (45, hl - 0.012), (82, 1.645), (125, 1.565), (180, 1.545)]
        if st == "sidepart": lv = [(0, hl), (45, hl - 0.008), (82, 1.646), (125, 1.57), (180, 1.55)]
        def th(pd, s_, k, j):
            if st == "buzz": return 0.005
            if st == "undercut":
                base = 0.004 if s_ < 0.42 else 0.018 + 0.06 * (s_ - 0.42) * (1.7 if abs(pd) < 70 else 0.8)
                return base + (0.022 * math.sin(math.pi * (s_ - 0.42) / 0.58) if abs(pd) < 45 and s_ > 0.42 else 0) + (0.008 if (j % 3 == 0 and s_ > 0.42) else 0)
            t_ = 0.008 + 0.016 * s_
            if st == "crop": t_ += 0.006 * max(0.0, math.sin(7 * math.radians(pd) + 2 * s_)) ** 2
            if st == "sidepart": t_ += 0.010 * s_ * (1 if pd < 20 else 0.5)
            return t_
        shell(lambda pd, j: band(pd, lv) - (0.006 if (j % 2 and st == "crop") else 0), th)
    else:                                                       # longer cuts on a closed shell
        if st in ("bob", "bob_sleek"):
            lv = [(0, 1.645 if hs.get("fringe") else hl), (30, 1.655 if hs.get("fringe") else hl - 0.01), (60, 1.60), (90, 1.535), (180, 1.51)]
            asym = 0.02 if st == "bob_sleek" else 0.0
            shell(lambda pd, j: band(pd, lv) - (asym if pd < -40 else 0) - (0.008 if (j % 2 and st == "bob") else 0),
                  lambda pd, s_, k, j: 0.012 + 0.018 * s_ + (0.004 if st == "bob" and j % 3 == 0 else 0), flare=0.022 if st == "bob" else 0.012)
        elif st == "curls":
            shell(lambda pd, j: band(pd, [(0, hl), (50, hl - 0.015), (90, 1.585), (180, 1.535)]) - (0.008 if j % 2 else 0),
                  lambda pd, s_, k, j: 0.022 + 0.014 * s_ + 0.014 * (1 if (j + k) % 2 else 0), flare=0.012)
        else:                                                   # pulled-back styles: snug shell + a feature at the back
            shell(lambda pd, j: band(pd, [(0, hl), (50, hl - 0.014), (85, 1.62), (130, 1.55), (180, 1.535)]),
                  lambda pd, s_, k, j: 0.008 + 0.010 * s_ + (0.004 if st in ("braids_back",) and j % 2 else 0))
        ext = Part()
        if st == "ponytail_curly":
            pts = [Vector((0, -0.112, 1.665)), Vector((0, -0.150, 1.62)), Vector((0, -0.165, 1.55)), Vector((0, -0.155, 1.47)), Vector((0, -0.140, 1.42))]
            rads = [0.030, 0.050, 0.058, 0.050, 0.030]
            for i in range(len(pts) - 1): tbox(ext, pts[i], pts[i + 1], rads[i] * 2, rads[i + 1] * 2, rads[i] * 1.8, rads[i + 1] * 1.8, (1, 0, 0), "Hair")
            ellipsoid(ext, (0, -0.12, 1.672), 0.03, 0.022, 0.02, "Gear", 6, 3)       # scrunchie
        if st == "bun":
            ellipsoid(ext, (0, -0.122, 1.665), 0.048, 0.040, 0.042, "Hair", 10, 6)
        if st == "puff":
            ellipsoid(ext, (0, -0.118, 1.575), 0.068, 0.058, 0.060, "Hair", 12, 7)
            ellipsoid(ext, (0.03, -0.09, 1.545), 0.032, 0.028, 0.03, "Hair", 8, 4)
        if st == "braid":
            p = Vector((0, -0.110, 1.56)); prev = p
            for i in range(8):
                q = Vector((0.006 * (1 if i % 2 else -1), -0.122 - 0.006 * i, 1.53 - 0.045 * (i + 1)))
                w = 0.050 - 0.003 * i; tbox(ext, prev, q, w, w * 0.9, w * 0.8, w * 0.75, (1, 0, 0), "Hair"); prev = q
            ellipsoid(ext, (0, -0.118, 1.535), 0.026, 0.02, 0.016, "Gear", 6, 3)
        if st == "braids_back":
            for bx in (-0.03, 0.0, 0.03):
                prev = Vector((bx, -0.108, 1.60))
                for i in range(7):
                    q = Vector((bx * (1 - i / 9), -0.126 - 0.005 * i, 1.57 - 0.04 * (i + 1)))
                    tbox(ext, prev, q, 0.024, 0.022, 0.022, 0.02, (1, 0, 0), "Hair"); prev = q
        for pts_, m_, _ in ext.polys:
            hairp.add(pts_, m_, [((0.2 + 0.6 * (i in (1, 2))), 0.1 + 0.8 * (i in (2, 3))) for i in range(len(pts_))] if m_ == "Hair" else gu("red" if st != "bun" else "hair"))
    hair = build_object(Q + "_Hair", hairp, smooth=True, mats=MATS)

    # ------------------------------------------------------------ head gear + face gear
    HG = Part()
    if hat in ("hardhat", "hardhat_back"):
        bmh = bmesh.new(); bmh.from_mesh(hair.data)                  # squash hair under the dome
        for v in bmh.verts:
            if v.co.z > 1.655:
                d = v.co - Vector((0, -0.01, 1.655)); k = min(1.0, 0.118 / max(0.001, Vector((d.x, d.y * 0.92, d.z * 1.25)).length))
                v.co = Vector((0, -0.01, 1.655)) + d * min(1.0, k)
        bmh.to_mesh(hair.data); bmh.free()
        tilt = -0.25 if hat == "hardhat_back" else 0.0
        dome = Part(); ellipsoid(dome, (0, -0.012, 1.655), 0.128, 0.142, 0.118, "Gear", 12, 5, 0.0, 1.0)
        brim = Part(); ellipsoid(brim, (0, 0.0, 1.655), 0.150, 0.170, 0.010, "Gear", 12, 2, -1.0, 1.0)
        ridge = Part(); tbox(ridge, Vector((0, 0.12, 1.70)), Vector((0, -0.13, 1.72)), 0.03, 0.03, 0.06, 0.06, (1, 0, 0), "Gear")
        R = Matrix.Rotation(tilt, 4, 'X')
        for prt, key in ((dome, "hat"), (brim, "hat_dark"), (ridge, "hat")):
            for pts_, _, _ in prt.polys:
                pp = [Vector((0, 0, 1.655)) + (R @ (p - Vector((0, 0, 1.655)))) for p in pts_]
                base = gu(key); HG.add(pp, "Gear", [base[i % 4] for i in range(len(pp))])
    if hat == "flatcap":
        c = Part(); ellipsoid(c, (0, -0.008, 1.655), 0.118, 0.134, 0.092, "Gear", 12, 4, 0.0, 1.0)
        tbox(c, Vector((0, 0.09, 1.668)), Vector((0, 0.172, 1.652)), 0.19, 0.16, 0.024, 0.012, (1, 0, 0), "Gear")
        gpart_into = c
        for pts_, _, _ in c.polys: HG.add(pts_, "Gear", gu("cap")[:len(pts_)] if len(pts_) <= 4 else (gu("cap") * 3)[:len(pts_)])
    if hat == "beanie":
        c = Part(); ellipsoid(c, (0, -0.008, 1.645), 0.112, 0.124, 0.115, "Gear", 12, 5, 0.0, 1.0)
        ellipsoid(c, (0, -0.008, 1.66), 0.118, 0.130, 0.03, "Gear", 12, 2, -1.0, 1.0)
        for pts_, _, _ in c.polys: HG.add(pts_, "Gear", (gu("hat") * 3)[:len(pts_)])
    if hat == "cap_back":
        c = Part(); ellipsoid(c, (0, -0.006, 1.660), 0.110, 0.122, 0.085, "Gear", 12, 4, 0.0, 1.0)
        tbox(c, Vector((0, -0.10, 1.672)), Vector((0, -0.20, 1.665)), 0.15, 0.13, 0.014, 0.010, (1, 0, 0), "Gear")
        for pts_, _, _ in c.polys: HG.add(pts_, "Gear", (gu("cap") * 3)[:len(pts_)])
    if hat in ("flatcap", "beanie", "cap_back"):
        bmh = bmesh.new(); bmh.from_mesh(hair.data)
        for v in bmh.verts:
            if v.co.z > 1.65:
                d = v.co - Vector((0, -0.006, 1.65)); lim = 0.105
                if Vector((d.x, d.y * 0.9, d.z * 1.3)).length > lim: v.co = Vector((0, -0.006, 1.65)) + d * (lim / Vector((d.x, d.y * 0.9, d.z * 1.3)).length)
        bmh.to_mesh(hair.data); bmh.free()
    if "bandana" in gear:
        c = Part()
        for i in range(16):
            a0, a1 = 2 * math.pi * i / 16, 2 * math.pi * (i + 1) / 16
            p0 = head_pt(1.672, a0); p1 = head_pt(1.672, a1)
            d0 = (p0 - Vector((0, 0, 1.672))).normalized() * 0.022; d1 = (p1 - Vector((0, 0, 1.672))).normalized() * 0.022
            c.add(outward([p0 + d0 + Vector((0, 0, -0.016)), p1 + d1 + Vector((0, 0, -0.016)), p1 + d1 + Vector((0, 0, 0.016)), p0 + d0 + Vector((0, 0, 0.016))], (0, 0, 1.672)), "Gear")
        tbox(c, Vector((0, -0.12, 1.67)), Vector((0.02, -0.15, 1.62)), 0.03, 0.02, 0.012, 0.01, (1, 0, 0), "Gear")
        for pts_, _, _ in c.polys: HG.add(pts_, "Gear", (gu("red") * 2)[:len(pts_)])
    # glasses
    gl = next((g for g in ("glasses_round", "glasses_rect", "glasses_half") if g in gear), None)
    eye_z = 1.612 if gl != "glasses_half" else 1.600
    if gl or "safety_glasses" in gear or "aviators_head" in gear:
        c = Part()
        def frame(cx, cz, rx, rz, yf, n=8):
            pts = [Vector((cx + rx * math.cos(2 * math.pi * i / n), yf, cz + rz * math.sin(2 * math.pi * i / n))) for i in range(n)]
            if gl == "glasses_half": pts = [p for p in pts if p.z <= cz + 0.002] + [Vector((cx - rx, yf, cz)), Vector((cx + rx, yf, cz))]
            for i in range(len(pts) - 1 if gl == "glasses_half" else len(pts)):
                tbox(c, pts[i], pts[(i + 1) % len(pts)], 0.006, 0.006, 0.006, 0.006, (0, 1, 0), "Gear", caps=False)
        if gl:
            yf = ring_params(eye_z)[2] + 0.018; rx, rz = (0.019, 0.017) if gl == "glasses_round" else (0.022, 0.014)
            for sx in (-1, 1):
                frame(sx * 0.040, eye_z, rx, rz, yf)
                W = ring_params(eye_z)[1]
                tbox(c, Vector((sx * (0.040 + rx), yf, eye_z)), Vector((sx * (W + 0.006), -0.004, 1.615)), 0.006, 0.006, 0.006, 0.006, (0, 0, 1), "Gear")
            tbox(c, Vector((-0.021, yf, eye_z + 0.004)), Vector((0.021, yf, eye_z + 0.004)), 0.006, 0.006, 0.006, 0.006, (0, 0, 1), "Gear")
            if "glasses_chain" in gear:
                for sx in (-1, 1):
                    W = ring_params(eye_z)[1]; prev = Vector((sx * (W + 0.006), -0.004, 1.612))
                    for i in range(1, 7):
                        tt = i / 6; q = Vector((sx * (W + 0.02 - 0.06 * tt), 0.02 + 0.06 * tt * tt, 1.612 - 0.20 * math.sin(tt * math.pi / 2)))
                        tbox(c, prev, q, 0.004, 0.004, 0.004, 0.004, (0, 0, 1), "Gear", caps=False); prev = q
        for pts_, _, _ in c.polys: HG.add(pts_, "Gear", (gu("gold" if gl == "glasses_round" and name == "Walter" else "black") * 3)[:len(pts_)])
        c2 = Part()
        if "safety_glasses" in gear:
            yf = ring_params(1.612)[2] + 0.02
            tbox(c2, Vector((-0.07, yf - 0.012, 1.612)), Vector((0.07, yf - 0.012, 1.612)), 0.03, 0.03, 0.012, 0.012, (0, 0, 1), "Gear")
        if "aviators_head" in gear:
            for sx in (-1, 1): ellipsoid(c2, (sx * 0.038, 0.03, 1.758), 0.024, 0.02, 0.006, "Gear", 8, 2, -1, 1)
            tbox(c2, Vector((-0.012, 0.03, 1.762)), Vector((0.012, 0.03, 1.762)), 0.004, 0.004, 0.004, 0.004, (0, 0, 1), "Gear")
        for pts_, _, _ in c2.polys: HG.add(pts_, "Gear", (gu("lens") * 3)[:len(pts_)])
    if "earmuffs_head" in gear or "earmuffs_neck" in gear:
        c = Part(); onhead = "earmuffs_head" in gear
        for sx in (-1, 1):
            if onhead: cc = Vector((sx * (ring_params(1.607)[1] + 0.03), -0.008, 1.607))
            else: cc = Vector((sx * 0.095, 0.03, 1.40))
            ax_ = Vector((sx, 0, 0)) if onhead else Vector((sx, 0.6, 0.6)).normalized()
            tbox(c, cc - ax_ * 0.02, cc + ax_ * 0.02, 0.07, 0.07, 0.08, 0.08, (0, 1, 0), "Gear")
        for pts_, _, _ in c.polys: HG.add(pts_, "Gear", (gu("muff") * 3)[:len(pts_)])
        c = Part(); prev = None
        for i in range(9):
            a = math.pi * i / 8
            q = Vector((-math.cos(a) * (ring_params(1.607)[1] + 0.036), -0.008, 1.607 + math.sin(a) * 0.15)) if onhead else Vector((-math.cos(a) * 0.105, -0.02 - math.sin(a) * 0.10, 1.38))
            if prev: tbox(c, prev, q, 0.02, 0.02, 0.012, 0.012, (0, 1, 0) if onhead else (0, 0, 1), "Gear", caps=False)
            prev = q
        for pts_, _, _ in c.polys: HG.add(pts_, "Gear", (gu("black") * 3)[:len(pts_)])
    if "earrings_studs" in gear or "earrings_hoops" in gear:
        c = Part()
        for sx in (-1, 1):
            W = ring_params(1.585)[1] + 0.012 * f.get("ears", 1.0)
            if "earrings_hoops" in gear:
                for i in range(8):
                    a0, a1 = 2 * math.pi * i / 8, 2 * math.pi * (i + 1) / 8
                    tbox(c, Vector((sx * W, -0.008 + 0.012 * math.cos(a0), 1.570 + 0.012 * math.sin(a0))), Vector((sx * W, -0.008 + 0.012 * math.cos(a1), 1.570 + 0.012 * math.sin(a1))), 0.004, 0.004, 0.004, 0.004, (1, 0, 0), "Gear", caps=False)
            else:
                tbox(c, Vector((sx * W, -0.012, 1.582)), Vector((sx * (W + 0.006), -0.012, 1.582)), 0.008, 0.008, 0.008, 0.008, (0, 1, 0), "Gear")
        for pts_, _, _ in c.polys: HG.add(pts_, "Gear", (gu("gold") * 3)[:len(pts_)])
    fh = f.get("facial_hair")
    if fh in ("walrus", "handlebar"):                        # chunky moustache block under the nose
        c = Part(); yy = ring_params(1.553)[2] + 0.012
        tbox(c, Vector((-0.030, yy, 1.552)), Vector((0.030, yy, 1.552)), 0.024, 0.024, 0.016, 0.016, (0, 0, 1), "Gear")
        for sx in (-1, 1):
            end = Vector((sx * (0.055 if fh == "handlebar" else 0.040), yy - 0.012, 1.548 if fh == "handlebar" else 1.536))
            tbox(c, Vector((sx * 0.028, yy, 1.552)), end, 0.020, 0.010, 0.014, 0.008, (0, 0, 1), "Gear")
            if fh == "handlebar": tbox(c, end, end + Vector((sx * 0.008, -0.004, 0.016)), 0.009, 0.005, 0.008, 0.004, (0, 0, 1), "Gear")
        for pts_, _, _ in c.polys: HG.add(pts_, "Gear", (gu("fh") * 3)[:len(pts_)])
    head_gear = HG

    # ------------------------------------------------------------ shoes
    kind = sp["shoes"]["kind"]
    SECT = [(-0.085, 0.044, 0.165), (-0.050, 0.054, 0.170), (0.010, 0.058, 0.140), (0.075, 0.062, 0.105),
            (0.140, 0.063, 0.088), (0.200, 0.057, 0.074), (0.235, 0.042, 0.058), (0.245, 0.024, 0.040)]
    if kind in ("flats", "loafers"):
        SECT = [(-0.075, 0.040, 0.075), (-0.040, 0.046, 0.080), (0.020, 0.050, 0.070), (0.090, 0.052, 0.062),
                (0.150, 0.050, 0.055), (0.200, 0.044, 0.048), (0.228, 0.032, 0.040), (0.236, 0.018, 0.030)]
    if kind == "boots":
        SECT = [(y, w * 1.06, h * 1.04 if y < 0.05 else h * 1.08) for y, w, h in SECT]
    def shoe_ring(w, h):
        c_ = 0.016
        return [(-w + c_, 0.0), (w - c_, 0.0), (w, c_), (w, h * 0.6), (w * 0.72, h), (-w * 0.72, h), (-w, h * 0.6), (-w, c_)]
    shoes = Part()
    for s in ("R", "L"):
        a = J["ankle" + s]; rot = Matrix.Rotation(math.radians(-7 if s == "R" else 7), 3, 'Z'); org = Vector((a.x, a.y, 0.0))
        rings = [[org + rot @ Vector((x, y, z)) for x, z in shoe_ring(w, h)] for y, w, h in SECT]
        loc = [[(x, y, z) for x, z in shoe_ring(w, h)] for y, w, h in SECT]
        def suv(lpts, mat, nl):
            out = []
            for (x, y, z) in lpts:
                if mat == "Sole": out.append((y / 0.25, z / 0.25 + x / 0.25)); continue
                u = ((y - SHOE_LEN[0]) / (SHOE_LEN[1] - SHOE_LEN[0]) * 63 + 0.5) / 64
                v = 1 - ((((x / (2 * SHOE_W)) + 0.5) * 31 + 0.5) / 64) if nl.z > 0.55 else 1 - ((32 + (1 - min(z, SHOE_H) / SHOE_H) * 31) + 0.5) / 64
                out.append((u, v))
            return out
        for i in range(len(rings) - 1):
            for k in range(8):
                q = [rings[i][k], rings[i][(k + 1) % 8], rings[i + 1][(k + 1) % 8], rings[i + 1][k]]
                ql = [loc[i][k], loc[i][(k + 1) % 8], loc[i + 1][(k + 1) % 8], loc[i + 1][k]]
                nl = pnormal([Vector(p) for p in ql]); cz = sum(p[2] for p in ql) / 4
                if nl.dot(Vector((sum(p[0] for p in ql) / 4, 0, cz - 0.06))) < 0: q, ql = q[::-1], ql[::-1]; nl = -nl
                mat = "Sole" if cz < 0.03 else "Shoes"; shoes.add(q, mat, suv(ql, mat, nl))
        for idx, flip in ((0, True), (len(rings) - 1, False)):
            q, ql = rings[idx], loc[idx]; nl = pnormal([Vector(p) for p in ql])
            if (nl.y > 0) == flip: q, ql = q[::-1], ql[::-1]; nl = -nl
            shoes.add(q, "Shoes", suv(ql, "Shoes", nl))
    shoe_ob = build_object(Q + "_Shoes", shoes, mats=MATS)

    gear_all = Part(); gear_all.extend(G); gear_all.extend(head_gear)
    gear_ob = build_object(Q + "_GearExtras", gear_all, mats=MATS, merge=0.0) if gear_all.polys else None

    # ------------------------------------------------------------ head scale (appeal) about the neck pivot
    HP = Vector((0, 0.0, 1.465)); HSC = 1.10 * b.get("head", 1.0)          # slightly oversized heads for appeal
    head_objs = [head, hair]
    for ob in head_objs:
        for v in ob.data.vertices: v.co = HP + (v.co - HP) * HSC
    if gear_ob:
        for v in gear_ob.data.vertices:
            if v.co.z > 1.47 and abs(v.co.x) < 0.2 and not (v.co.z < 1.43): v.co = HP + (v.co - HP) * HSC
    crown_z = HP.z + (1.76 - HP.z) * HSC

    # ------------------------------------------------------------ skin weights (canonical frame)
    BONES = {}
    def B(n, h, t_): BONES[n] = (Vector(h), Vector(t_))
    B("Hips", J["hips"], J["spine"]); B("Spine", J["spine"], J["chest"]); B("Chest", J["chest"], Vector((0, 0.005, 1.31)))
    B("UpperChest", Vector((0, 0.005, 1.31)), J["neck"]); B("Neck", J["neck"], J["head"]); B("Head", J["head"], Vector((0, 0, crown_z)))
    for s, side in (("R", "Right"), ("L", "Left")):
        a = (J["wrist" + s] - J["elbow" + s]).normalized()
        B(side + "Shoulder", J["clav" + s], J["shoulder" + s]); B(side + "UpperArm", J["shoulder" + s], J["elbow" + s])
        B(side + "LowerArm", J["elbow" + s], J["wrist" + s]); B(side + "Hand", J["wrist" + s], J["wrist" + s] + a * 0.10)
        B(side + "UpperLeg", J["hip" + s], J["knee" + s]); B(side + "LowerLeg", J["knee" + s], J["ankle" + s])
        B(side + "Foot", J["ankle" + s], J["ball" + s]); B(side + "Toes", J["ball" + s], J["toe" + s])
    def cand(p):
        out = ["Hips", "Spine", "Chest", "UpperChest", "Neck"]
        for side, sx in (("Right", 1), ("Left", -1)):
            if p.x * sx > 0.02 or abs(p.x) < 0.02:
                out += [side + n for n in ("Shoulder", "UpperArm", "LowerArm", "Hand")]
                if p.z < 1.0: out += [side + "UpperLeg", side + "LowerLeg", side + "Foot"]
        if p.z > 1.0: out = [o for o in out if "Leg" not in o and "Foot" not in o]
        return out
    def skin(ob, fn):
        for nmb in BONES: ob.vertex_groups.new(name=nmb)
        for v in ob.data.vertices:
            for nmb, w in fn(v.co): ob.vertex_groups[nmb].add([v.index], w, 'REPLACE')
    def body_w(p):
        ds = sorted((seg_dist(p, *BONES[n_]), n_) for n_ in cand(p))[:3]
        ws = [(1.0 / (d + 0.004) ** 5, n_) for d, n_ in ds]; tot = sum(w for w, _ in ws)
        return [(n_, w / tot) for w, n_ in ws if w / tot > 0.02]
    def head_w(p):
        if p.z < 1.45: return [("UpperChest", 0.6), ("Head", 0.4)]
        if p.z < 1.49: return [("Neck", 0.5), ("Head", 0.5)]
        return [("Head", 1.0)]
    skin(body, body_w); skin(head, head_w); skin(hair, head_w)
    def shoe_w(p):
        side = "Right" if p.x > 0 else "Left"; tt = max(0.0, min(1.0, (p.y - 0.09) / 0.06))
        return [(n_, w) for n_, w in ((side + "Foot", 1 - tt), (side + "Toes", tt)) if w > 0]
    skin(shoe_ob, shoe_w)
    if gear_ob:
        def gear_w(p):
            if p.z > 1.47 and abs(p.x) < 0.2: return [("Head", 1.0)]
            if 1.33 < p.z <= 1.47 and abs(p.x) < 0.14 and p.y > -0.02 and ("earmuffs_neck" in gear) and p.z > 1.36: return [("Neck", 1.0)]
            return body_w(p)
        skin(gear_ob, gear_w)
    PARTS = [o for o in (body, head, hair, shoe_ob, gear_ob) if o]

    # ------------------------------------------------------------ warp canonical -> this person (height, legs, posture)
    legk = 0.94 * b.get("leg", 1.0); top_c = crown_z + 0.03          # stylised: a touch shorter in the leg
    s_tot = sp["height"] / (0.93 * legk + (top_c - 0.93))
    sw = 1 + (s_tot - 1) * 0.55
    slouch = b.get("slouch", 0.0)
    def warp(p):
        z = p.z * legk if p.z < 0.93 else 0.93 * legk + (p.z - 0.93)
        z *= s_tot; y = p.y * sw; x = p.x * sw
        zc = 0.98 * s_tot * legk
        if z > zc: y += slouch * ((z - zc) / max(0.01, sp["height"] - zc)) ** 1.6
        return Vector((x, y, z))
    for ob in PARTS:
        for v in ob.data.vertices: v.co = warp(v.co)
    WB = {k: (warp(h), warp(t_)) for k, (h, t_) in BONES.items()}

    # ------------------------------------------------------------ armature (identical names/hierarchy to the existing cast)
    arm_data = bpy.data.armatures.new(Q + "_Rig"); rig = bpy.data.objects.new(Q + "_Rig", arm_data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    PARENT = {"Spine": "Hips", "Chest": "Spine", "UpperChest": "Chest", "Neck": "UpperChest", "Head": "Neck"}
    for side in ("Right", "Left"):
        PARENT.update({side + "Shoulder": "UpperChest", side + "UpperArm": side + "Shoulder", side + "LowerArm": side + "UpperArm",
                       side + "Hand": side + "LowerArm", side + "UpperLeg": "Hips", side + "LowerLeg": side + "UpperLeg",
                       side + "Foot": side + "LowerLeg", side + "Toes": side + "Foot"})
    CONNECT = {"Spine", "Chest", "UpperChest", "Neck", "Head"} | {sd + k for sd in ("Right", "Left") for k in ("UpperArm", "LowerArm", "Hand", "LowerLeg", "Foot", "Toes")}
    order_b = ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head"] + [sd + k for sd in ("Right", "Left") for k in
               ("Shoulder", "UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot", "Toes")]
    for nmb in order_b:
        eb = arm_data.edit_bones.new(nmb); eb.head, eb.tail = WB[nmb]
        if nmb in PARENT: eb.parent = arm_data.edit_bones[PARENT[nmb]]; eb.use_connect = nmb in CONNECT
        eb.roll = 0.0
    bpy.ops.object.mode_set(mode='OBJECT')
    for ob in PARTS:
        ob.parent = rig; md = ob.modifiers.new("Armature", 'ARMATURE'); md.object = rig
    def socket(nm, bone_name, loc):
        e = bpy.data.objects.new(nm, None); bpy.context.scene.collection.objects.link(e); e.empty_display_size = 0.04
        e.parent = rig; e.parent_type = 'BONE'; e.parent_bone = bone_name
        e.matrix_world = Matrix.Translation(loc); return e          # identity rotation, as Eddie's sockets
    def along(bn, d):
        h, t_ = WB[bn]; return t_ + (t_ - h).normalized() * d
    SOCK = [socket("Socket_RightHand", "RightHand", along("RightHand", -0.03)), socket("Socket_LeftHand", "LeftHand", along("LeftHand", -0.03)),
            socket("Socket_Head", "Head", WB["Head"][1] + Vector((0, 0, 0.04))), socket("Socket_Back", "UpperChest", warp(Vector((0, -0.17, 1.25))))]
    rig["character"] = sp["title"]; rig["age"] = sp["age"]; rig["bone_naming"] = "Godot SkeletonProfileHumanoid"
    rig["built_by"] = "tools/character_cast/build_cast.py"

    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "CHR_QD_%s.glb" % name)
    bpy.ops.object.select_all(action='DESELECT')
    for o in [rig] + PARTS + SOCK: o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_yup=True, export_apply=False,
                              export_extras=True, export_skins=True, export_animations=False, export_image_format='AUTO')
    tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in PARTS}
    height = max((o.matrix_world @ v.co).z for o in PARTS for v in o.data.vertices)
    rep = {"name": name, "title": sp["title"], "glb": "assets/characters/CHR_QD_%s.glb" % name, "triangles": sum(tris.values()),
           "parts": tris, "materials": len({m.name for o in PARTS for m in o.data.materials if m}), "height_m": round(height, 3),
           "empty_material_slots": sum(1 for o in PARTS for m in o.data.materials if m is None)}
    print("CAST_OK", json.dumps(rep))
    if PREV: preview(name, rig, PARTS)
    return rep


# ================================================================ previews
def preview(name, rig, parts):
    os.makedirs(PREV, exist_ok=True); sc = bpy.context.scene
    for eng in ('BLENDER_EEVEE', 'BLENDER_EEVEE_NEXT'):
        try: sc.render.engine = eng; break
        except TypeError: continue
    sc.view_settings.view_transform = 'Standard'; sc.render.resolution_x, sc.render.resolution_y = 720, 900
    w = bpy.data.worlds.new("W"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.40, 0.36, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    for nm, rot, en, col in (("Key", (50, 0, 30), 3.0, (1.0, 0.92, 0.80)), ("Rim", (60, 0, 200), 1.6, (0.7, 0.8, 1.0)), ("Fill", (75, 0, -70), 0.7, (0.9, 0.9, 1.0))):
        l = bpy.data.lights.new(nm, 'SUN'); l.energy = en; l.color = col; o = bpy.data.objects.new(nm, l); sc.collection.objects.link(o)
        o.rotation_euler = [math.radians(a) for a in rot]
    me = bpy.data.meshes.new("g"); me.from_pydata([(-3, -3, 0), (3, -3, 0), (3, 3, 0), (-3, 3, 0)], [], [(0, 1, 2, 3)])
    g = bpy.data.objects.new("g", me); sc.collection.objects.link(g)
    gm = bpy.data.materials.new("gm"); gm.use_nodes = True; gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.36, 0.33, 0.28, 1); me.materials.append(gm)
    def cam(nm, loc, tgt, lens):
        c = bpy.data.cameras.new(nm); c.lens = lens; o = bpy.data.objects.new(nm, c); sc.collection.objects.link(o); o.location = loc
        o.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler(); return o
    h = CAST[name]["height"]
    for tag, loc, tgt, lens, res in (("34", (2.3, 3.4, h * 0.62), (0, 0, h * 0.52), 50, (720, 900)),
                                     ("face", (0.35, 1.05, h - 0.13), (0, 0, h - 0.16), 60, (720, 720))):
        sc.render.resolution_x, sc.render.resolution_y = res
        sc.camera = cam(tag, loc, tgt, lens); sc.render.filepath = os.path.join(PREV, "%s_%s.png" % (name, tag))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    reports = [build(n) for n in NAMES]
    rp = os.path.join(OUT, "CAST_REPORT.json")
    old = json.load(open(rp)) if os.path.exists(rp) else {}
    old.update({r["name"]: r for r in reports}); json.dump(old, open(rp, "w"), indent=1)
    print("ALL_OK", len(reports))
