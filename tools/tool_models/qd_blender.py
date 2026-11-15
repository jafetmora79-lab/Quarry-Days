"""Quarry Days machinery - shared Blender (bpy) helpers: materials, low-poly mesh builder, animation registry, GLB export.

Conventions (see tools/vehicle_models/README.md)
  * metres, Z up, +Y forward in Blender  ->  glTF/Godot -Z forward, Y up.  Origin at the ground between the tracks.
  * every movable part is its own object whose ORIGIN is its mechanical hinge, parented in the real mechanical hierarchy.
  * flat shaded, meter-UVs (1 UV unit = 1 m = 64 px) so the pixel textures keep the project's texel density.
  * material names are Quarry Days names ("PaintYellow", "SteelPlate"...). Godot swaps in res://assets/materials/M_QD_<name>.tres
    (or assets/vehicles/materials/) at load time, so the machines always use the project's material set.
"""
import bpy, bmesh, math, os, sys, hashlib
from mathutils import Vector, Matrix, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TEXDIR = os.path.join(REPO, "assets", "textures")
VTEXDIR = os.path.join(REPO, "assets", "vehicles", "textures")
VEIL_BRUSHED = os.path.join(REPO, "THE_VEIL_ASSETS_V2", "01_Textures", "Furniture", "T_Furn_MetalBrushed.png")

# name -> (image path or None, base colour, roughness, metallic, extras)
MATERIALS = {
    "ExcPaint":    (os.path.join(VTEXDIR, "T_QD_ExcPaint.png"), (0.67, 0.58, 0.33), 0.8, 0.0, {}),
    "PaintYellow": (os.path.join(TEXDIR, "T_QD_PaintYellow.png"), (0.67, 0.58, 0.33), 0.8, 0.0, {}),
    "CabPaint":    (os.path.join(VTEXDIR, "T_QD_ExcPaint.png"), (0.67, 0.58, 0.33), 0.8, 0.0, {}),
    "BedPaint":    (os.path.join(VTEXDIR, "T_QD_ExcPaint.png"), (0.67, 0.58, 0.33), 0.8, 0.0, {}),
    "ExcDark":     (os.path.join(VTEXDIR, "T_QD_ExcDark.png"), (0.3, 0.3, 0.32), 0.7, 0.2, {}),
    "SteelPlate":  (os.path.join(TEXDIR, "T_QD_SteelPlate.png"), (0.38, 0.4, 0.42), 0.65, 0.2, {}),
    "Hazard":      (os.path.join(TEXDIR, "T_QD_Hazard.png"), (0.45, 0.38, 0.2), 0.8, 0.0, {}),
    "MetalBrushed": (VEIL_BRUSHED, (0.7, 0.7, 0.72), 0.5, 0.5, {}),
    "ExcTrack":    (os.path.join(VTEXDIR, "T_QD_ExcTrack.png"), (0.2, 0.2, 0.22), 0.9, 0.0, {}),
    "Tire":        (os.path.join(TEXDIR, "T_QD_Tire.png"), (0.11, 0.11, 0.12), 1.0, 0.0, {}),
    "Glass":       (None, (0.2, 0.28, 0.32), 0.25, 0.0, {"alpha": 0.38}),
    "LampLens":    (None, (1.0, 0.92, 0.7), 0.4, 0.0, {"emit": 2.5}),
    "LampRed":     (None, (0.9, 0.12, 0.08), 0.4, 0.0, {"emit": 1.2}),
    "Screen":      (None, (0.25, 0.9, 0.55), 0.4, 0.0, {"emit": 1.6}),
    "Seat":        (None, (0.16, 0.18, 0.22), 1.0, 0.0, {}),
    "Rubber":      (None, (0.07, 0.07, 0.08), 1.0, 0.0, {}),
    "CabFloor":    (None, (0.22, 0.2, 0.18), 1.0, 0.0, {}),
}
_mat_cache = {}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mat_cache.clear()
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.render.fps = 30


def material(name):
    if name in _mat_cache:
        return _mat_cache[name]
    img_path, col, rough, metal, extra = MATERIALS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    vcol = nt.nodes.new("ShaderNodeVertexColor")
    vcol.layer_name = "Col"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = 'RGBA'
    mix.blend_type = 'MULTIPLY'
    mix.inputs["Factor"].default_value = 1.0
    nt.links.new(vcol.outputs["Color"], mix.inputs["B"])
    if img_path and os.path.exists(img_path):
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(img_path, check_existing=True)
        tex.interpolation = 'Closest'
        nt.links.new(tex.outputs["Color"], mix.inputs["A"])
    else:
        mix.inputs["A"].default_value = (*col, 1.0)
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    if "alpha" in extra:
        bsdf.inputs["Alpha"].default_value = extra["alpha"]
        try: m.surface_render_method = 'BLENDED'
        except Exception: pass
        try: m.blend_method = 'BLEND'
        except Exception: pass
    if "emit" in extra:
        bsdf.inputs["Emission Color"].default_value = (*col, 1.0)
        bsdf.inputs["Emission Strength"].default_value = extra["emit"]
    m.diffuse_color = (*col, 1.0)
    _mat_cache[name] = m
    return m


# ------------------------------------------------------------------------------------------------ dirt / wear (vertex colours)

def _hash01(x, y, z):
    h = hashlib.md5(("%.2f,%.2f,%.2f" % (round(x * 8) / 8, round(y * 8) / 8, round(z * 8) / 8)).encode()).digest()
    return h[0] / 255.0


def dirt_colour(p, zbase, dirt):
    """Vertex-colour grime: browner and darker towards the ground, plus a little per-vertex mottling."""
    z = p.z + zbase
    low = max(0.0, min(1.0, (0.95 - z) / 0.95)) ** 1.3
    k = dirt * (low * 0.62 + _hash01(p.x, p.y, p.z) * 0.12)
    k = max(0.0, min(0.8, k))
    return (1.0 - k * 0.30, 1.0 - k * 0.42, 1.0 - k * 0.60, 1.0)


# ------------------------------------------------------------------------------------------------ mesh builder

def _uv_for(p, n):
    ax = max(range(3), key=lambda i: abs(n[i]))
    if ax == 2: return (p.x * (1 if n.z > 0 else -1), p.y)
    if ax == 0: return (p.y * (1 if n.x < 0 else -1), p.z)
    return (p.x * (1 if n.y > 0 else -1), p.z)


class Mesher:
    """Accumulates flat-shaded low-poly geometry (several materials) for ONE object.
    Coordinates passed in are in 'model space' and shifted by `shift` into the object's local frame (so a part whose origin is a
    hinge can still be described with ground-relative numbers). `zbase` is the approximate world height of the origin (dirt)."""
    def __init__(self, name, parent=None, loc=(0, 0, 0), rot=(0, 0, 0), shift=(0, 0, 0), zbase=0.0, dirt=1.0):
        self.name, self.parent = name, parent
        self.loc, self.rot = Vector(loc), rot
        self.shift = Vector(shift)
        self.zbase, self.dirt = zbase, dirt
        self.bm = bmesh.new()
        self.mats = []
        self.uvl = self.bm.loops.layers.uv.new("UVMap")
        self.coll = self.bm.loops.layers.color.new("Col")

    def v(self, p): return Vector(p) + self.shift
    def _mi(self, mat):
        if mat not in self.mats: self.mats.append(mat)
        return self.mats.index(mat)

    def solid(self, verts, faces, mat, uv_scale=1.0):
        vs = [self.bm.verts.new(self.v(p)) for p in verts]
        fs = []
        for f in faces:
            try:
                face = self.bm.faces.new([vs[i] for i in f])
            except ValueError:
                continue
            face.material_index = self._mi(mat)
            face.smooth = False
            fs.append(face)
        bmesh.ops.recalc_face_normals(self.bm, faces=fs)
        for face in fs:
            n = face.normal
            for loop in face.loops:
                loop[self.uvl].uv = [c * uv_scale for c in _uv_for(loop.vert.co, n)]
        return fs

    def quad(self, pts, mat):
        """A single (open) face, normal from the winding. Used for glass panes and decals."""
        vs = [self.bm.verts.new(self.v(p)) for p in pts]
        face = self.bm.faces.new(vs)
        face.material_index = self._mi(mat)
        face.smooth = False
        for loop in face.loops:
            loop[self.uvl].uv = _uv_for(loop.vert.co, face.normal)
        return face

    def raw_quad(self, pts, uvs, mat, outward=None, inward=None):
        """One face with explicit UVs (belt strips). `outward` = a point the normal should face away from."""
        vs = [self.bm.verts.new(self.v(p)) for p in pts]
        face = self.bm.faces.new(vs)
        face.material_index = self._mi(mat)
        face.smooth = False
        if outward is not None and face.normal.dot(face.calc_center_median() - self.v(outward)) < 0:
            face.normal_flip()
        if inward is not None and face.normal.dot(face.calc_center_median() - self.v(inward)) > 0:
            face.normal_flip()
        uvmap = {v: uvs[i] for i, v in enumerate(vs)}
        for loop in face.loops:
            loop[self.uvl].uv = uvmap[loop.vert]
        return face

    # ---- primitives
    def hexa(self, v8, mat):
        return self.solid(v8, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], mat)

    def box(self, c, s, mat, top=1.0, topy=1.0):
        """Axis-aligned box; `top`/`topy` taper the top face in x / y (hoods, tapered covers)."""
        cx, cy, cz = c; hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        v = [(cx - hx, cy - hy, cz - hz), (cx + hx, cy - hy, cz - hz), (cx + hx, cy + hy, cz - hz), (cx - hx, cy + hy, cz - hz),
             (cx - hx * top, cy - hy * topy, cz + hz), (cx + hx * top, cy - hy * topy, cz + hz),
             (cx + hx * top, cy + hy * topy, cz + hz), (cx - hx * top, cy + hy * topy, cz + hz)]
        return self.hexa(v, mat)

    def prism_yz(self, pts, x0, x1, mat):
        """Extrude a (y, z) side profile between x0 and x1 (convex or mildly concave)."""
        n = len(pts)
        v = [(x0, p[0], p[1]) for p in pts] + [(x1, p[0], p[1]) for p in pts]
        f = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        return self.solid(v, f, mat)

    def prism_xy(self, pts, z0, z1, mat, top_k=1.0):
        """Extrude a plan polygon (x, y) from z0 to z1; `top_k` insets the top outline about its centroid (chamfer / taper)."""
        n = len(pts)
        cx = sum(p[0] for p in pts) / n; cy = sum(p[1] for p in pts) / n
        v = [(p[0], p[1], z0) for p in pts] + [(cx + (p[0] - cx) * top_k, cy + (p[1] - cy) * top_k, z1) for p in pts]
        f = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        return self.solid(v, f, mat)

    def cyl(self, c, r, length, axis, mat, seg=8, r2=None, phase=0.0):
        """Cylinder / frustum centred at c along `axis` ('x','y','z'); r2 = radius at the +axis end."""
        r2 = r if r2 is None else r2
        ring0, ring1 = [], []
        for i in range(seg):
            a = phase + 2 * math.pi * i / seg
            ca, sa = math.cos(a), math.sin(a)
            if axis == 'x': ring0.append((-length / 2, ca * r, sa * r)); ring1.append((length / 2, ca * r2, sa * r2))
            elif axis == 'y': ring0.append((ca * r, -length / 2, sa * r)); ring1.append((ca * r2, length / 2, sa * r2))
            else: ring0.append((ca * r, sa * r, -length / 2)); ring1.append((ca * r2, sa * r2, length / 2))
        v = [(c[0] + p[0], c[1] + p[1], c[2] + p[2]) for p in ring0 + ring1]
        n = seg
        f = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        return self.solid(v, f, mat)

    def bar(self, a, b, w, h, mat, up=(0, 0, 1)):
        """Rectangular bar from a to b with cross-section w x h (struts, hoses, rails)."""
        a, b = Vector(a), Vector(b)
        d = (b - a).normalized()
        s = Vector(up) - d * Vector(up).dot(d)
        if s.length < 1e-4: s = d.orthogonal()
        s.normalize(); t = d.cross(s)
        o = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
        v = [tuple(a + s * p[0] + t * p[1]) for p in o] + [tuple(b + s * p[0] + t * p[1]) for p in o]
        return self.solid(v, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], mat)

    def finish(self):
        # dirt in vertex colours
        for f in self.bm.faces:
            for loop in f.loops:
                loop[self.coll] = dirt_colour(loop.vert.co, self.zbase, self.dirt)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(material(m))
        if len(me.color_attributes) > 0:
            me.color_attributes.active_color = me.color_attributes[0]          # the glTF exporter only writes the active colour layer
            me.color_attributes.render_color_index = 0
        obj = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = self.parent
        obj.location = self.loc
        obj.rotation_euler = self.rot
        return obj


def empty(name, parent=None, loc=(0, 0, 0), rot=(0, 0, 0), size=0.08, display='PLAIN_AXES'):
    o = bpy.data.objects.new(name, None)
    o.empty_display_type = display
    o.empty_display_size = size
    bpy.context.scene.collection.objects.link(o)
    o.parent = parent
    o.location = loc
    o.rotation_euler = rot
    return o


# ------------------------------------------------------------------------------------------------ animation clips (NLA tracks -> GLB animations)

class Clips:
    """Registers animated objects; each clip is sampled frame by frame and baked into one NLA track per object.
    The glTF exporter merges same-named tracks across objects into a single AnimationPlayer clip in Godot."""
    def __init__(self):
        self.objs = []          # (obj, channels tuple)
        self.fps = 30

    def track(self, obj, *channels):
        self.objs.append((obj, channels or ("rotation_euler",)))

    def bake(self, name, frames, apply_fn, loop=False):
        """frames: iterable of frame numbers (1-based). apply_fn(frame) must pose every tracked object."""
        actions = {}
        for o, _ in self.objs:
            ad = o.animation_data_create()
            ad.action = None
            actions[o.name] = bpy.data.actions.new(f"{name}__{o.name}")
        for f in frames:
            apply_fn(f)
            for o, chans in self.objs:
                o.animation_data.action = actions[o.name]
                for ch in chans:
                    o.keyframe_insert(ch, frame=f)
        for o, chans in self.objs:
            ad = o.animation_data
            act = actions[o.name]
            ad.action = None
            tr = ad.nla_tracks.new()
            tr.name = name
            tr.strips.new(name, 1, act)
        # linear interpolation between the dense samples keeps the baked mechanics exact
        for act in actions.values():
            for fc in self._fcurves(act):
                for kp in fc.keyframe_points:
                    kp.interpolation = 'LINEAR'

    @staticmethod
    def _fcurves(act):
        try:
            return list(act.fcurves)
        except Exception:
            out = []
            for layer in act.layers:
                for strip in layer.strips:
                    for bag in strip.channelbags:
                        out.extend(bag.fcurves)
            return out


def export_glb(path, **extra):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    kw = dict(filepath=path, export_format='GLB', export_apply=False, export_yup=True, export_animation_mode='NLA_TRACKS',
              export_optimize_animation_size=False, use_selection=False, export_extras=True, export_cameras=False, export_image_format='NONE',
              export_lights=False)
    kw.update(extra)
    bpy.ops.export_scene.gltf(**kw)


def render_views(out_dir, tag, views, res=(960, 640), frame=1):
    """Workbench/EEVEE-free preview renders (flat studio light) so the model can be inspected by eye."""
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = False
    sh = sc.display.shading
    sh.light = 'STUDIO'; sh.color_type = 'TEXTURE'; sh.show_shadows = True; sh.show_cavity = False
    sh.background_type = 'WORLD' if False else 'VIEWPORT'
    sh.background_color = (0.55, 0.68, 0.8)
    sc.frame_set(frame)
    cam_d = bpy.data.cameras.new("PrevCam"); cam = bpy.data.objects.new("PrevCam", cam_d)
    bpy.context.scene.collection.objects.link(cam); sc.camera = cam
    cam_d.lens = 38
    paths = []
    for vname, (loc, target) in views.items():
        cam.location = loc
        d = Vector(target) - Vector(loc)
        cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = os.path.join(out_dir, f"{tag}_{vname}.png")
        bpy.ops.render.render(write_still=True)
        paths.append(sc.render.filepath)
    bpy.data.objects.remove(cam)
    return paths
