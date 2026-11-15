"""Shared machinery parts for the Quarry Days vehicle generators (crawler tracks, track wheels, window panes).
Used by build_bulldozer.py (build_excavator.py keeps its own copy: that asset is finished and is not regenerated)."""
import math
from qd_blender import Mesher


def track_belt(parent, name, x, y_rear, y_front, z, ro, ri, w, pitch=0.2, dirt=0.8):
    """Continuous low-poly crawler belt: a stadium loop around the wheels. UV u runs along the belt (one grouser pitch per unit)
    so the game scrolls the texture to animate it. Returns the object (origin at the track centre line x)."""
    mm = Mesher(name, parent, loc=(x, 0, 0), dirt=dirt)
    path = []
    seg = 9
    def add(y, zz, ny, nz): path.append((y, zz, ny, nz))
    add(y_rear, z - ro, 0, -1)
    add(y_front, z - ro, 0, -1)
    for i in range(1, seg):
        a = -math.pi / 2 + math.pi * i / seg
        add(y_front + math.cos(a) * ro, z + math.sin(a) * ro, math.cos(a), math.sin(a))
    add(y_front, z + ro, 0, 1)
    add(y_rear, z + ro, 0, 1)
    for i in range(1, seg):
        a = math.pi / 2 + math.pi * i / seg
        add(y_rear + math.cos(a) * ro, z + math.sin(a) * ro, math.cos(a), math.sin(a))
    n = len(path)
    cum = [0.0]
    for i in range(1, n + 1):
        a, b = path[i - 1], path[i % n]
        cum.append(cum[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    total = cum[-1]
    reps = round(total / pitch)
    hw = w / 2
    ctr = (0, (y_rear + y_front) / 2, z)
    def P(p, xx, r):
        cy, cz = p[0] - p[2] * ro, p[1] - p[3] * ro
        return (xx, cy + p[2] * r, cz + p[3] * r)
    for i in range(n):
        a, b = path[i], path[(i + 1) % n]
        u0, u1 = cum[i] / total * reps, cum[i + 1] / total * reps
        mm.raw_quad([P(a, -hw, ro), P(b, -hw, ro), P(b, hw, ro), P(a, hw, ro)], [(u0, 0), (u1, 0), (u1, 1), (u0, 1)], "ExcTrack", outward=ctr)
        mm.raw_quad([P(a, -hw, ri), P(b, -hw, ri), P(b, hw, ri), P(a, hw, ri)], [(u0, 0.1), (u1, 0.1), (u1, 0.9), (u0, 0.9)], "ExcTrack", inward=ctr)
        for xx, dirn in ((-hw, -1), (hw, 1)):
            mm.raw_quad([P(a, xx, ri), P(b, xx, ri), P(b, xx, ro), P(a, xx, ro)], [(u0, 0), (u1, 0), (u1, 0.05), (u0, 0.05)], "ExcTrack",
                        outward=(xx - dirn * 5, 0, z))
    return mm.finish()


def sprocket(mm, r, width, teeth=10):
    mm.cyl((0, 0, 0), r * 0.80, width, 'x', "ExcDark", seg=10)
    mm.cyl((0, 0, 0), r * 0.28, width + 0.06, 'x', "SteelPlate", seg=6)
    for i in range(teeth):
        a = 2 * math.pi * i / teeth
        c, s = math.cos(a), math.sin(a)
        mm.bar((0, c * r * 0.72, s * r * 0.72), (0, c * r * 1.0, s * r * 1.0), width * 0.9, r * 0.28, "SteelPlate", up=(1, 0, 0))


def idler(mm, r, width):
    mm.cyl((0, 0, 0), r * 0.94, width * 0.7, 'x', "ExcDark", seg=12)
    for x in (-width * 0.4, width * 0.4):
        mm.cyl((x, 0, 0), r, 0.05, 'x', "SteelPlate", seg=12)
    mm.cyl((0, 0, 0), r * 0.28, width + 0.06, 'x', "SteelPlate", seg=6)


def roller(mm, r, width):
    mm.cyl((0, 0, 0), r, width * 0.8, 'x', "ExcDark", seg=8)
    for x in (-width * 0.4, width * 0.4):
        mm.cyl((x, 0, 0), r * 1.1, 0.05, 'x', "SteelPlate", seg=8)


def pane_x(mm, x, y0, y1, zb, zt, t=0.012):
    return mm.hexa([(x - t / 2, y0, zb), (x - t / 2, y1, zb), (x - t / 2, y1, zt), (x - t / 2, y0, zt),
                    (x + t / 2, y0, zb), (x + t / 2, y1, zb), (x + t / 2, y1, zt), (x + t / 2, y0, zt)], "Glass")
