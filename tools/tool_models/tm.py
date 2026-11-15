"""Quarry Days hand tools - a small modelling layer over qd_blender.Mesher that works in GODOT model space.

Coordinates passed to every method are the ones the game uses: metres, +Y up the handle from the grip, -Z forward (the working end of a
swung tool points to -Z), +X right. They are converted to Blender (x, -z, y) here, so glTF export (Y up) lands the numbers back exactly.
"""
import math
import bpy
from mathutils import Vector
import qd_blender as Q
from qd_blender import Mesher, empty

# materials the tools use. Godot swaps the project's own material in by NAME at load time (scripts/art/tool_models.gd).
Q.MATERIALS.update({
    "Wood":     (None, (0.55, 0.40, 0.25), 0.9, 0.0, {}),
    "OldWood":  (None, (0.37, 0.27, 0.18), 1.0, 0.0, {}),
    "Steel":    (None, (0.38, 0.40, 0.42), 0.65, 0.2, {}),
    "Bright":   (None, (0.70, 0.70, 0.72), 0.5, 0.5, {}),
    "Rust":     (None, (0.45, 0.25, 0.14), 0.9, 0.2, {}),
    "Rubber":   (None, (0.07, 0.07, 0.08), 1.0, 0.0, {}),
    "Rope":     (None, (0.62, 0.52, 0.34), 1.0, 0.0, {}),
    "Red":      (None, (0.62, 0.14, 0.10), 0.8, 0.0, {}),
    "Orange":   (None, (0.85, 0.45, 0.12), 0.8, 0.0, {}),
    "Yellow":   (None, (0.80, 0.66, 0.20), 0.8, 0.0, {}),
    "Blue":     (None, (0.24, 0.34, 0.46), 0.8, 0.0, {}),
    "Paper":    (None, (0.86, 0.82, 0.68), 1.0, 0.0, {}),
    "Glove":    (None, (0.17, 0.18, 0.21), 1.0, 0.0, {}),
    "Plaid":    (None, (0.62, 0.13, 0.10), 1.0, 0.0, {}),
    "PlaidDark": (None, (0.33, 0.06, 0.05), 1.0, 0.0, {}),
    "SkinDark": (None, (0.62, 0.46, 0.35), 1.0, 0.0, {}),
    "GloveDark": (None, (0.08, 0.08, 0.10), 1.0, 0.0, {}),
    "Skin":     (None, (0.80, 0.62, 0.48), 1.0, 0.0, {}),
    "Sleeve":   (None, (0.86, 0.46, 0.16), 1.0, 0.0, {}),
    "Band":     (None, (0.86, 0.86, 0.78), 1.0, 0.0, {}),
})


def B(p):
    """Godot model space -> Blender."""
    return (p[0], -p[2], p[1])


class TM:
    """One part of a tool. Geometry is split into one mesh object per material (so the game sees several parts). A part named "Body" lives directly
    under the root; any other name ("Spinner", "Lever") is an empty at `loc` (its hinge) that holds its meshes."""
    def __init__(self, name, parent=None, loc=(0, 0, 0), mirror=False, holder=False):
        """holder=True: an empty named `name` at `loc` (a hinge: a wheel, a tipping body) that holds the meshes, whose geometry is still given in MODEL
        space (the shift moves it into the holder's frame). Without it, "Body" is the flat part of a tool and any other name is a part described in its own frame."""
        self.mirror = mirror
        self.name = name
        lb = Vector(self._p(loc))
        if holder:
            self.holder = empty(name, parent, loc=lb, size=0.05)
            self.shift = (-lb.x, -lb.y, -lb.z)
            self.parent_loc = Vector((0, 0, 0))
        elif name == "Body":
            self.holder, self.shift = parent, (-lb.x, -lb.y, -lb.z)
            self.parent_loc = lb
        else:
            self.holder = empty(name, parent, loc=lb, size=0.03)
            self.shift = (0, 0, 0)                    # a moving part is described in its OWN frame (origin = its hinge)
            self.parent_loc = Vector((0, 0, 0))
        self.ms = {}

    def _mesher(self, mat):
        if mat not in self.ms:
            self.ms[mat] = Mesher("%s_%s" % (self.name, mat), self.holder, loc=self.parent_loc, shift=self.shift, dirt=0.0)
        return self.ms[mat]

    def _p(self, p):
        x, y, z = p
        return B((-x if self.mirror else x, y, z))

    def solid(self, verts, faces, mat):
        return self._mesher(mat).solid([self._p(v) for v in verts], faces, mat)

    # ---- primitives (godot space)
    def box(self, c, s, mat, taper=(1.0, 1.0), rot_y=0.0):
        cx, cy, cz = c
        hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        tx, tz = taper
        ring = [(-hx, -hz), (hx, -hz), (hx, hz), (-hx, hz)]
        ca, sa = math.cos(rot_y), math.sin(rot_y)

        def rot(px, pz):
            return (cx + px * ca - pz * sa, cz + px * sa + pz * ca)
        v = []
        for px, pz in ring:
            x, z = rot(px, pz)
            v.append((x, cy - hy, z))
        for px, pz in ring:
            x, z = rot(px * tx, pz * tz)
            v.append((x, cy + hy, z))
        return self.solid(v, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], mat)

    def hexa(self, v8, mat):
        return self.solid(v8, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], mat)

    def slab(self, y0, z0, w0, y1, z1, w1, t, mat, x=0.0):
        """A thin plate whose centre line runs from (y0, z0) to (y1, z1) (a blade section): width w0 -> w1, thickness t."""
        v = []
        for (y, z, w) in ((y0, z0, w0), (y1, z1, w1)):
            v += [(x - w / 2, y, z - t / 2), (x + w / 2, y, z - t / 2), (x + w / 2, y, z + t / 2), (x - w / 2, y, z + t / 2)]
        return self.solid(v, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], mat)

    def cyl(self, c, r0, r1, h, mat, seg=8, axis='y', phase=0.0, squash=1.0):
        """Frustum centred at c along `axis`; r0 at the -axis end, r1 at the +axis end. `squash` scales the second radial axis (oval handles)."""
        n = seg
        rings = []
        for k, (r, off) in enumerate(((r0, -h / 2), (r1, h / 2))):
            ring = []
            for i in range(n):
                a = phase + 2 * math.pi * i / n
                u, w = math.cos(a) * r, math.sin(a) * r * squash
                if axis == 'y':
                    ring.append((c[0] + u, c[1] + off, c[2] + w))
                elif axis == 'z':
                    ring.append((c[0] + u, c[1] + w, c[2] + off))
                else:
                    ring.append((c[0] + off, c[1] + u, c[2] + w))
            rings.append(ring)
        return self._skin(rings, mat)

    def _skin(self, rings, mat, caps=True):
        n = len(rings[0])
        v = [p for r in rings for p in r]
        f = []
        for k in range(len(rings) - 1):
            for i in range(n):
                a, b = k * n + i, k * n + (i + 1) % n
                f.append((a, b, b + n, a + n))
        if caps:
            f.append(tuple(range(n - 1, -1, -1)))
            f.append(tuple(range((len(rings) - 1) * n, len(rings) * n)))
        return self.solid(v, f, mat)

    def tube(self, pts, radii, mat, seg=6, squash=1.0, up=(0, 1, 0)):
        """A swept tube along a polyline (godot space) with a radius per point (or one radius). Round-ish cross-section, rings by parallel transport."""
        pts = [Vector(p) for p in pts]
        if not isinstance(radii, (list, tuple)):
            radii = [radii] * len(pts)
        rings = []
        prev_n = None
        for i, p in enumerate(pts):
            if i == 0:
                d = pts[1] - p
            elif i == len(pts) - 1:
                d = p - pts[i - 1]
            else:
                d = (pts[i + 1] - p).normalized() + (p - pts[i - 1]).normalized()
            d = d.normalized()
            if prev_n is None:
                ref = Vector(up)
                if abs(ref.dot(d)) > 0.95:
                    ref = Vector((1, 0, 0))
                nrm = (ref - d * ref.dot(d)).normalized()
            else:
                nrm = (prev_n - d * prev_n.dot(d))
                nrm = nrm.normalized() if nrm.length > 1e-6 else prev_n
            prev_n = nrm
            bn = d.cross(nrm)
            ring = []
            for k in range(seg):
                a = 2 * math.pi * k / seg
                ring.append(tuple(p + nrm * (math.cos(a) * radii[i]) + bn * (math.sin(a) * radii[i] * squash)))
            rings.append(ring)
        return self._skin(rings, mat)

    def prism(self, prof, width, at, mat, x=0.0):
        """Extrude a side profile given as (z, y) points (the convention of the old procedural heads) along X for `width`, placed at `at`=(0,y,0)."""
        n = len(prof)
        v = []
        for sx in (-width / 2, width / 2):
            for (pz, py) in prof:
                v.append((x + sx, at[1] + py, at[2] + pz))
        f = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
        for i in range(n):
            f.append((i, (i + 1) % n, n + (i + 1) % n, n + i))
        return self.solid(v, f, mat)

    def bar(self, a, b, w, h, mat, up=(0, 1, 0)):
        a, b = Vector(a), Vector(b)
        d = (b - a).normalized()
        s = Vector(up) - d * Vector(up).dot(d)
        if s.length < 1e-4:
            s = d.orthogonal()
        s.normalize()
        t = d.cross(s)
        o = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
        v = [tuple(a + s * p[0] + t * p[1]) for p in o] + [tuple(b + s * p[0] + t * p[1]) for p in o]
        return self.solid(v, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], mat)

    def finish(self):
        return [m.finish() for m in self.ms.values()]


def arc_head(t, yc, half, mat, r_mid, droop=0.03, seg=6, side="both", sx=0.0):
    """A pick head: two curved arms along Z from the eye at height yc, each tapering from r_mid to a point `half` away, drooping `droop` at the tip."""
    for sgn in (-1, 1):
        if side == "front" and sgn > 0:
            continue
        if side == "back" and sgn < 0:
            continue
        pts, rad = [], []
        steps = 6
        for i in range(steps + 1):
            u = i / steps
            z = sgn * (0.02 + (half - 0.02) * u)
            y = yc - droop * u * u
            pts.append((sx, y, z))
            rad.append(max(0.0035, r_mid * (1.0 - u * u * 0.97)))
        t.tube(pts, rad, mat, seg=seg, squash=1.15)


def finger_arc(t, y, R, a0, a1, r, mat, n=6, seg=5, sign=1.0):
    """A finger or thumb curled round the grip: points on a circle of radius R about the Y axis, angle measured from +Z toward +X."""
    pts = []
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        pts.append((math.sin(a) * R, y, math.cos(a) * R))
    rad = [r * (1.0 - 0.18 * i / n) for i in range(n + 1)]
    t.tube(pts, rad, mat, seg=seg)


def grip_band(t, y, width, R, a0, a1, thick, mat, steps=10, taper=0.35, chamfer=0.35):
    """A solid band wrapped round a grip (axis Y through the origin): the four fingers of a closed fist as one continuous glove surface.
    Centre radius R, angle measured from +Z toward +X from a0 to a1, `thick` radial thickness (thinning toward the fingertips by `taper`),
    `width` along Y, with chamfered corners."""
    rings = []
    for i in range(steps + 1):
        u = i / steps
        a = math.radians(a0 + (a1 - a0) * u)
        th = thick * (1.0 - taper * u * u)
        hw, ht = width / 2, th / 2
        ch = min(hw, ht) * chamfer
        sec = [(-hw + ch, -ht), (hw - ch, -ht), (hw, -ht + ch), (hw, ht - ch), (hw - ch, ht), (-hw + ch, ht), (-hw, ht - ch), (-hw, -ht + ch)]
        sa, ca = math.sin(a), math.cos(a)
        ring = []
        for (dy, dr) in sec:
            rr = R + dr
            ring.append((sa * rr, y + dy, ca * rr))
        rings.append(ring)
    return t._skin(rings, mat)
