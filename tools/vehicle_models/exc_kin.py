"""Quarry Days excavator kinematics - pure 2D (y forward, z up) planar linkage maths, no Blender needed.

The Blender builder (build_excavator.py) and the Godot runtime rig (scripts/art/excavator_rig.gd) share these definitions, so the
cylinders and the bucket 4-bar linkage are solved the same way in the animation clips and in the game.
All lengths are metres, angles radians (positive = raise / swing out, like Godot rotation.x on a -Z-forward node).
"""
import math, random

ARM_S = 1.0                    # arm scale: keeps the reach in proportion to the 3.4 m machine
P0 = (0.62, 1.15)              # boom foot pin, model space (y, z)
BOOM_E = (2.35 * ARM_S, 0.0)           # elbow pin, boom-local
STICK_W = (0.28 * ARM_S, -1.10 * ARM_S)        # bucket pin, stick-local
REST = {"swing": 0.0, "boom": 0.35, "stick": -0.50, "bucket": -0.45}
LIMITS = {"boom": (-0.15, 0.95), "stick": (-0.80, 0.85), "bucket": (-1.15, 0.85)}

# cylinder pins: (base pin in parent-frame local, rod pin in target-frame local)
BOOM_CYL = {"base": (0.595, 0.867), "rod": (0.84 * ARM_S, -0.445 * ARM_S)}     # base: turret-plane (world y,z); rod: boom-local
STICK_CYL = {"base": (0.892 * ARM_S, 0.729 * ARM_S), "rod": (0.149 * ARM_S, 0.549 * ARM_S)}   # base: boom-local; rod: stick-local
BUCKET_CYL = {"base": (-0.159 * ARM_S, 0.544 * ARM_S)}                        # base: stick-local; rod end = J (solved)
LINK_K = (0.321 * ARM_S, -0.944 * ARM_S)         # idler-link pivot on the stick, stick-local
LINK_L = (-0.021 * ARM_S, 0.320 * ARM_S)         # bucket-link pivot on the bucket, bucket-local
TIP = (-0.58 * ARM_S, -0.50 * ARM_S)   # hoe bucket: teeth at the rear-bottom, mouth faces the cab            # bucket lip (tooth tips), bucket-local


def rot(p, a):
    c, s = math.cos(a), math.sin(a)
    return (p[0] * c - p[1] * s, p[0] * s + p[1] * c)


def add(a, b): return (a[0] + b[0], a[1] + b[1])
def sub(a, b): return (a[0] - b[0], a[1] - b[1])
def dist(a, b): return math.hypot(a[0] - b[0], a[1] - b[1])


def circle_hit(p0, r0, p1, r1, side):
    d = dist(p0, p1)
    a = (r0 * r0 - r1 * r1 + d * d) / (2 * d)
    h2 = r0 * r0 - a * a
    if h2 < 0:
        return None
    h = math.sqrt(h2)
    ex, ey = (p1[0] - p0[0]) / d, (p1[1] - p0[1]) / d
    mx, my = p0[0] + a * ex, p0[1] + a * ey
    return (mx - side * h * ey, my + side * h * ex)


class Pose:
    """Forward kinematics for a (boom, stick, bucket) angle triple. Frames: boom@P0, stick@boom elbow, bucket@stick pin."""
    def __init__(self, boom, stick, bucket):
        self.b, self.s, self.k = boom, stick, bucket
        self.E = add(P0, rot(BOOM_E, boom))                        # elbow, world
        self.ab = boom                                             # boom frame angle
        self.as_ = boom + stick                                    # stick frame angle
        self.W = add(self.E, rot(STICK_W, self.as_))               # bucket pin, world
        self.ak = self.as_ + bucket                                # bucket frame angle
    def boom_pt(self, p): return add(P0, rot(p, self.ab))
    def stick_pt(self, p): return add(self.E, rot(p, self.as_))
    def bucket_pt(self, p): return add(self.W, rot(p, self.ak))


_R0 = {}
def rest_link():
    """Link lengths and the J side, taken from the rest pose (a fixed property of the machine)."""
    if _R0:
        return _R0
    # idler link (K->J) and bucket link (L->J) lengths: chosen so J sits ahead of the stick at rest
    _R0["lk"] = 0.4468 * ARM_S
    _R0["ll"] = 0.4296 * ARM_S
    return _R0


def solve_j(pose):
    """J (world) = intersection of the circle about K (idler link) and the circle about L (bucket link)."""
    r = rest_link()
    K = pose.stick_pt(LINK_K)
    L = pose.bucket_pt(LINK_L)
    # J sits on the side away from the pin line, towards the front/up of the stick
    for side in (1, -1):
        j = circle_hit(K, r["lk"], L, r["ll"], side)
        if j is not None:
            yield j


def bucket_j(pose, side=-1):
    r = rest_link()
    K = pose.stick_pt(LINK_K)
    L = pose.bucket_pt(LINK_L)
    return circle_hit(K, r["lk"], L, r["ll"], side)


def stroke(fn, rng, n=24):
    ds = [fn(rng[0] + (rng[1] - rng[0]) * i / (n - 1)) for i in range(n)]
    return min(ds), max(ds)


def report():
    def bc(b): return dist(BOOM_CYL["base"], Pose(b, 0, 0).boom_pt(BOOM_CYL["rod"]))
    def sc(s):
        p = Pose(REST["boom"], s, 0)
        return dist(p.boom_pt(STICK_CYL["base"]), p.stick_pt(STICK_CYL["rod"]))
    def kc(k, side):
        p = Pose(REST["boom"], 0.0, k)
        j = bucket_j(p, side)
        return None if j is None else dist(p.stick_pt(BUCKET_CYL["base"]), j)
    print("boom cyl", stroke(bc, LIMITS["boom"]))
    print("stick cyl", stroke(sc, LIMITS["stick"]))
    for side in (1, -1):
        vals = [kc(LIMITS["bucket"][0] + (LIMITS["bucket"][1] - LIMITS["bucket"][0]) * i / 23, side) for i in range(24)]
        ok = [v for v in vals if v is not None]
        print("bucket cyl side", side, "valid", len(ok), "/24", (min(ok), max(ok)) if ok else None)


if __name__ == "__main__":
    report()


def tip_world(pose): return pose.bucket_pt(TIP)

def ik_tip(target, bucket_abs, boom_rng=None, stick_rng=None):
    """Brute-force planar IK: boom+stick angles that put the bucket lip nearest `target` (y,z) with the bucket at the given
    absolute angle (rad; 0 = rest orientation of the bucket mesh). Returns (boom, stick, bucket_rel, error)."""
    br = boom_rng or LIMITS["boom"]; sr = stick_rng or LIMITS["stick"]
    best = None
    for i in range(61):
        b = br[0] + (br[1] - br[0]) * i / 60
        for j in range(81):
            s = sr[0] + (sr[1] - sr[0]) * j / 80
            k = bucket_abs - (b + s)
            k = max(LIMITS["bucket"][0], min(LIMITS["bucket"][1], k))
            e = dist(tip_world(Pose(b, s, k)), target)
            if best is None or e < best[3]:
                best = (b, s, k, e)
    return best

def tip_rest():
    return tip_world(Pose(REST["boom"], REST["stick"], REST["bucket"]))


def cyl_ranges(margin=0.02):
    """(min, max) pin distance of each hydraulic cylinder over the joint limits, padded by `margin`."""
    def bc(b): return dist(BOOM_CYL["base"], Pose(b, 0, 0).boom_pt(BOOM_CYL["rod"]))
    def sc(s):
        p = Pose(REST["boom"], s, 0)
        return dist(p.boom_pt(STICK_CYL["base"]), p.stick_pt(STICK_CYL["rod"]))
    def kc(k):
        p = Pose(REST["boom"], 0.0, k)
        return dist(p.stick_pt(BUCKET_CYL["base"]), bucket_j(p, -1))
    out = {}
    for name, fn, lim in (("BoomCyl", bc, LIMITS["boom"]), ("StickCyl", sc, LIMITS["stick"]), ("BucketCyl", kc, LIMITS["bucket"])):
        lo, hi = stroke(fn, lim, 40)
        out[name] = (lo - margin, hi + margin)
    return out
