"""Pixel textures for the Quarry Days machinery (64 px/m, nearest filtering, deterministic). Writes assets/vehicles/textures/.
    python tools/vehicle_models/gen_textures.py
ExcPaint = the project's PaintYellow with worn paint: scratches, chips down to bare steel, a little rust at the chips.
ExcDark  = dark undercarriage steel with scuffs.  ExcTrack = rubber crawler belt with steel grouser plates (16 px = 0.2 m of belt)."""
import os, random
from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(REPO, "assets", "vehicles", "textures")
os.makedirs(OUT, exist_ok=True)
rnd = random.Random(1987)


def clamp(v): return max(0, min(255, int(v)))
def shade(c, k): return tuple(clamp(x * k) for x in c)


def paint():
    im = Image.open(os.path.join(REPO, "assets", "textures", "T_QD_PaintYellow.png")).convert("RGB")
    px = im.load(); w, h = im.size
    # fine scratches: short light/dark diagonal-ish streaks
    for _ in range(9):
        x, y = rnd.randrange(w), rnd.randrange(h); dx = rnd.choice((1, 1, 0)); dy = rnd.choice((0, 1, 1))
        for i in range(rnd.randrange(4, 10)):
            xx, yy = (x + dx * i) % w, (y + dy * i) % h
            px[xx, yy] = shade(px[xx, yy], 1.14) if rnd.random() < 0.5 else shade(px[xx, yy], 0.78)
    # chips to bare steel with a rust rim
    for _ in range(5):
        x, y = rnd.randrange(2, w - 2), rnd.randrange(2, h - 2)
        px[x, y] = (96, 100, 106)
        if rnd.random() < 0.6: px[x + 1, y] = (84, 88, 94)
        for ox, oy in ((-1, 0), (0, 1), (0, -1)):
            if rnd.random() < 0.6: px[x + ox, y + oy] = (130, 78, 40)
    # a dirty streak
    x = rnd.randrange(w)
    for y in range(h):
        if rnd.random() < 0.7: px[x, y] = shade(px[x, y], 0.82)
    im.save(os.path.join(OUT, "T_QD_ExcPaint.png"))


def dark():
    im = Image.open(os.path.join(REPO, "assets", "textures", "T_QD_SteelPlate.png")).convert("RGB")
    im = im.point(lambda v: int(v * 0.52))
    px = im.load(); w, h = im.size
    for _ in range(14):
        x, y = rnd.randrange(w), rnd.randrange(h)
        for i in range(rnd.randrange(2, 7)):
            px[(x + i) % w, y] = shade(px[(x + i) % w, y], 1.35)
    for _ in range(6):
        px[rnd.randrange(w), rnd.randrange(h)] = (92, 60, 38)
    im.save(os.path.join(OUT, "T_QD_ExcDark.png"))


def track():
    w, h = 16, 24                                      # u along the belt (one grouser pitch), v across the 0.44 m width
    im = Image.new("RGB", (w, h)); px = im.load()
    for x in range(w):
        for y in range(h):
            edge = y < 2 or y >= h - 2
            if edge: c = (24, 24, 26)                 # rubber side walls
            elif x < 11: c = (98, 100, 106)            # steel grouser plate
            else: c = (22, 22, 25)                    # gap between plates
            if not edge and x < 11:
                if x == 0 or x == 10: c = shade(c, 0.55)
                if x in (1, 2): c = shade(c, 1.25)
                if y in (2, h - 3): c = shade(c, 0.8)
                if y in (6, 17) and x in (3, 7): c = (46, 47, 52)    # bolts
            if rnd.random() < 0.06: c = shade(c, 0.8)
            px[x, y] = c
    im.save(os.path.join(OUT, "T_QD_ExcTrack.png"))


def worn(name):
    """Worn variants of the project's red / orange paints for the trucks: scratches, chips to steel, rust bleeding from the chips."""
    r = random.Random(sum(map(ord, name)))
    im = Image.open(os.path.join(REPO, "assets", "textures", "T_QD_Paint%s.png" % name)).convert("RGB")
    px = im.load(); w, h = im.size
    for _ in range(10):
        x, y = r.randrange(w), r.randrange(h); dx = r.choice((1, 1, 0)); dy = r.choice((0, 1, 1))
        for i in range(r.randrange(4, 10)):
            xx, yy = (x + dx * i) % w, (y + dy * i) % h
            px[xx, yy] = shade(px[xx, yy], 1.14) if r.random() < 0.5 else shade(px[xx, yy], 0.78)
    for _ in range(6):
        x, y = r.randrange(2, w - 2), r.randrange(2, h - 2)
        px[x, y] = (96, 100, 106)
        for ox, oy in ((-1, 0), (0, 1), (0, -1), (1, 0)):
            if r.random() < 0.7: px[x + ox, y + oy] = (128, 74, 38)
    x = r.randrange(w)
    for y in range(h):
        if r.random() < 0.75: px[x, y] = shade(px[x, y], 0.8)
    im.save(os.path.join(OUT, "T_QD_Worn%s.png" % name))


if __name__ == "__main__":
    paint(); dark(); track(); worn("Red"); worn("Orange")
    print("textures written to", OUT)
