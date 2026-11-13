"""QUARRY DAYS - pixel textures for the named cast (Pillow only, deterministic).

    python tools/character_cast/paint_cast.py [Name ...]      -> tools/character_cast/textures/<Name>/T_QD_<Name>_*.png

Painted in THE VEIL manner: small palettes with hue-shifted shadows and highlights, structured pixel clusters,
no photo sources. Clothing tiles cover 0.5 m (64 px, 128 px/m) and are world-projected, so the painter
knows the canonical height of every band, pocket and placket (see build_cast.py box_uv).
"""
import colorsys, math, os, random, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from cast_specs import CAST, GEAR_KEYS, gear_cell, SHOE_LEN, SHOE_W, SHOE_H  # noqa: E402

TEX_ROOT = os.path.join(HERE, "textures")
HEAD_Z0, HEAD_Z1 = 1.470, 1.735          # canonical head map v range (matches build_cast.py)
TILE = 0.5                                # metres per 64 px clothing tile


# ================================================================ helpers
def ramp(base, n_dark=2, n_light=2, step=0.15, hue=0.025):
    r, g, b = [c / 255 for c in base]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    def toward(h0, target, amt):
        d = ((target - h0 + 0.5) % 1.0) - 0.5
        return (h0 + max(-abs(d), min(abs(d), amt if d > 0 else -amt))) % 1.0
    out = []
    for k in range(-n_dark, n_light + 1):
        hh = toward(h, 0.70, hue * -k) if k < 0 else toward(h, 0.12, hue * k)
        ss = min(1, max(0, s * (1 + 0.10 * (-k))))
        vv = min(1, max(0, v * (1 + step * k)))
        out.append(tuple(int(round(c * 255)) for c in colorsys.hsv_to_rgb(hh, ss, vv)))
    return out


def H(s): return sum((i + 1) * ord(ch) for i, ch in enumerate(s))       # stable across runs (hash() is salted)


def mix(a, b, t): return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


class Canvas:
    def __init__(s, w, h, col=(0, 0, 0)):
        s.w, s.h = w, h; s.p = [[tuple(col) for _ in range(w)] for _ in range(h)]
    def put(s, x, y, c, wrap=True):
        if wrap: s.p[y % s.h][x % s.w] = tuple(c)
        elif 0 <= x < s.w and 0 <= y < s.h: s.p[y][x] = tuple(c)
    def get(s, x, y): return s.p[y % s.h][x % s.w]
    def rect(s, x0, y0, w, h, c, wrap=True):
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w): s.put(x, y, c, wrap)
    def hline(s, x0, x1, y, c, wrap=True):
        for x in range(min(x0, x1), max(x0, x1) + 1): s.put(x, y, c, wrap)
    def vline(s, x, y0, y1, c, wrap=True):
        for y in range(min(y0, y1), max(y0, y1) + 1): s.put(x, y, c, wrap)
    def line(s, x0, y0, x1, y1, c, wrap=True):
        dx, dy = abs(x1 - x0), -abs(y1 - y0); sx = 1 if x0 < x1 else -1; sy = 1 if y0 < y1 else -1; e = dx + dy
        while True:
            s.put(x0, y0, c, wrap)
            if x0 == x1 and y0 == y1: break
            e2 = 2 * e
            if e2 >= dy: e += dy; x0 += sx
            if e2 <= dx: e += dx; y0 += sy
    def save(s, path):
        im = Image.new("RGB", (s.w, s.h)); im.putdata([c for row in s.p for c in row]); im.save(path)


def vnoise(w, h, cell, seed):
    rnd = random.Random(seed); gw, gh = max(1, w // cell), max(1, h // cell)
    g = [[rnd.random() for _ in range(gw)] for _ in range(gh)]
    sm = lambda t: t * t * (3 - 2 * t)
    f = [[0.0] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            fx, fy = x / cell, y / cell; ix, iy = int(fx), int(fy); tx, ty = sm(fx - ix), sm(fy - iy)
            a = g[iy % gh][ix % gw]; b = g[iy % gh][(ix + 1) % gw]; c = g[(iy + 1) % gh][ix % gw]; d = g[(iy + 1) % gh][(ix + 1) % gw]
            f[y][x] = (a + (b - a) * tx) + ((c + (d - c) * tx) - (a + (b - a) * tx)) * ty
    return f


FONT = {"A": "010101111101101", "B": "110101110101110", "C": "011100100100011", "D": "110101101101110",
        "E": "111100110100111", "F": "111100110100100", "G": "011100101101011", "H": "101101111101101",
        "I": "111010010010111", "K": "101101110101101", "L": "100100100100111", "M": "101111111101101",
        "N": "111101101101101", "O": "010101101101010", "P": "110101110100100", "Q": "010101101110011",
        "R": "110101110101101", "S": "011100010001110", "T": "111010010010010", "U": "101101101101111",
        "V": "101101101101010", "Y": "101101010010010", "W": "101101101111101", "Z": "111001010100111", " ": "0" * 15}
def text(cv, x, y, s, c):
    for ch in s:
        for i, bit in enumerate(FONT.get(ch, FONT[" "])):
            if bit == "1": cv.put(x + i % 3, y + i // 3, c, False)
        x += 4
def text_w(s): return len(s) * 4 - 1


def tile_px(x, z):
    """Canonical world (x, z) on a FRONT-facing surface -> pixel in a 64 px tile (box projection, n.y > 0)."""
    u = (x / TILE) % 1.0; v = (z / TILE) % 1.0
    return int(u * 64) % 64, int((1 - v) * 64) % 64
def tile_row(z): return int((1 - (z / TILE) % 1.0) * 64) % 64


# ================================================================ face
def paint_head(name, sp):
    W, H = 128, 64; f = sp["face"]; SK = ramp(sp["skin"], 3, 1, 0.11, 0.03)
    hair = sp["hair"]; HR = ramp(hair["color"], 2, 2, 0.20)
    cv = Canvas(W, H, SK[3]); c = W // 2
    def row(z): return int(round((HEAD_Z1 - z) / (HEAD_Z1 - HEAD_Z0) * (H - 1)))
    r_eye, r_brow, r_mouth, r_nose = row(1.612), row(1.640), row(1.537), row(1.566)
    r_chin = row(1.49)
    for y in range(H):                                            # broad form shading
        for x in range(W):
            d = abs(x - c); k = 3
            if d > 22: k = 2
            if y > row(1.505) and d < 30: k = 2
            if y > row(1.49): k = 1
            cv.put(x, y, SK[k])
    lip = f.get("lips") or mix(SK[1], (176, 80, 80), 0.35)
    # ---- age
    wr = f.get("wrinkles", 0)
    if wr >= 1:
        for s in (-1, 1):
            ox = c + s * 13
            cv.put(ox, r_eye - 1, SK[2]); cv.put(ox + s, r_eye + 1, SK[2]); cv.put(ox, r_eye + 2, SK[2])
    if wr >= 2:
        cv.hline(c - 7, c + 7, r_brow - 4, SK[2])
        for s in (-1, 1):
            for i in range(5): cv.put(c + s * (4 + i // 2), r_nose + 1 + i, SK[2])     # smile lines
            cv.hline(c + s * 3, c + s * 7, r_eye + 4, SK[2])                              # bags
    if wr >= 3:
        cv.hline(c - 9, c + 9, r_brow - 6, SK[2]); cv.hline(c - 5, c + 5, r_brow - 8, SK[2])
        for s in (-1, 1): cv.vline(c + s * 11, r_mouth, r_mouth + 4, SK[2])               # jowls
    if f.get("freckles"):
        for y in range(r_eye + 3, r_nose + 3):
            for x in range(c - 18, c + 19):
                if abs(x - c) > 2 and (x * 5 + y * 3) % 11 == 0: cv.put(x, y, mix(SK[3], (150, 80, 50), 0.45))
    bl = f.get("blush", 0)
    if bl:
        for s in (-1, 1):
            for y in range(r_eye + 4, r_eye + 7):
                for x in range(c + s * 11 - 2, c + s * 11 + 3):
                    if (x + y) % 2 == 0 or bl > 0.4: cv.put(x, y, mix(cv.get(x, y), (226, 120, 120), 0.35 * bl + 0.1))
    # ---- facial hair
    FH = ramp(f.get("fh_col") or hair["color"], 2, 1, 0.2)
    fh = f.get("facial_hair")
    def mouth_hole(x, y): return abs(x - c) < 5 and r_mouth - 1 <= y <= r_mouth + 1
    if fh in ("beard_full", "beard_short", "beard_trim"):
        top = {"beard_full": r_nose + 2, "beard_short": r_nose + 3, "beard_trim": r_mouth + 2}[fh]
        for y in range(top, r_chin + 3):
            span = 27 if y > r_mouth - 2 else 24
            for x in range(c - span, c + span + 1):
                if mouth_hole(x, y): continue
                d = abs(x - c)
                if fh == "beard_trim" and y < r_mouth + 3 and d < 22: continue
                if fh == "beard_short" and (x % 4 == 0) and y < r_mouth: continue
                k = 1 if (x % 3 == 0) else 2
                if y > r_chin: k = 0
                cv.put(x, y, FH[k])
        for x in range(c - 6, c + 7): cv.put(x, r_mouth - 2, FH[1]); cv.put(x, r_mouth - 3, FH[2] if abs(x - c) < 5 else SK[2])
    if fh == "stubble":
        for y in range(r_nose + 2, r_chin + 1):
            for x in range(c - 26, c + 27):
                if (x + y) % 2 == 0 and y % 2 == 0 and not mouth_hole(x, y): cv.put(x, y, mix(SK[3], (110, 100, 110), 0.3))
    # ---- eyes
    style = f.get("eyes", "relaxed"); IR = f.get("iris", (70, 50, 40))
    LID = (40, 26, 24); WH = (238, 232, 218); WH2 = (214, 206, 192)
    for side in (-1, 1):
        ex = c + side * 8 - 3; ey = r_eye - 2; outer = ex + 6 if side > 0 else ex
        if style in ("squint", "jolly"):                     # smiling crescents
            for i, dy in enumerate((2, 1, 0, 0, 0, 1, 2)): cv.put(ex + i, ey + 1 + dy, LID)
            if style == "jolly": cv.hline(ex + 2, ex + 4, ey + 2, mix(IR, LID, 0.4))
            cv.put(outer + side, ey + 3, SK[2]); cv.put(outer + side, ey + 1, SK[2])
            continue
        heavy = style in ("heavy", "tired")
        openr = {"bright": 3, "wide": 3, "kind": 2, "relaxed": 2, "sharp": 2, "focused": 2, "cat": 2, "heavy": 2, "tired": 2}.get(style, 2)
        if heavy: cv.hline(ex - 1, ex + 7, ey - 1, SK[1])
        cv.hline(ex, ex + 6, ey, LID)
        if f.get("lashes") or style == "cat":
            cv.put(outer + side, ey - (1 if style == "cat" else 0), LID); cv.put(outer, ey - 1, LID)
        if style == "kind": cv.put(outer + side, ey + 1, LID)
        if style in ("sharp", "focused", "cat"): cv.put(ex + 3, ey - 1, SK[1])
        y0 = ey + 1
        if heavy: cv.hline(ex + 1, ex + 5, y0, mix(SK[1], LID, 0.3)); y0 += 1
        for r in range(openr):
            for xx in range(ex + 1, ex + 6): cv.put(xx, y0 + r, WH if r < openr - 1 else WH2)
        ix = ex + 3 - (1 if style == "focused" and side > 0 else 0)
        for r in range(openr):
            cv.put(ix, y0 + r, IR); cv.put(ix + 1, y0 + r, mix(IR, LID, 0.35))
        pr = y0 + max(0, openr // 2)
        cv.put(ix, pr, (22, 18, 18)); cv.put(ix + 1, pr, (22, 18, 18))
        cv.put(ix + 1 if side < 0 else ix, y0, (252, 250, 240))
        cv.hline(ex + 1, ex + 5, y0 + openr, SK[1])
    # ---- brows
    bt = f.get("brows", "medium"); BC = ramp(f.get("brow_col", hair["color"]), 1, 1, 0.2)
    shape = f.get("brow_shape", "soft")
    prof = {"arch": (1, 0, -1, -1, -1, -1, 0, 1, 2), "flat": (0,) * 9, "angled": (2, 1, 1, 0, 0, -1, -1, -1, 0),
            "soft": (0, -1, -1, -1, -1, 0, 0, 1, 2)}[shape]
    rows = {"thin": 1, "medium": 2, "thick": 2, "bushy": 3}[bt]
    for side in (-1, 1):
        for i in range(9):
            dy = prof[i]; x = c + side * (4 + i)
            for r in range(rows):
                if bt == "medium" and r == 1 and i in (0, 7, 8): continue
                if bt == "bushy" and r == 0 and i % 2 == 0: continue
                cv.put(x, r_brow - 2 + dy + r - (1 if bt == "bushy" else 0), BC[0] if r == rows - 1 else BC[1])
        if bt == "bushy":
            cv.put(c + side * 13, r_brow - 1, BC[1]); cv.put(c + side * 3, r_brow - 2, BC[1])
    # ---- nose shading
    for y in range(r_eye + 1, r_nose + 1): cv.put(c - 3, y, SK[2]); cv.put(c + 3, y, SK[1])
    cv.put(c - 2, r_nose + 1, mix(SK[0], (100, 50, 40), 0.3)); cv.put(c + 2, r_nose + 1, mix(SK[0], (100, 50, 40), 0.3))
    # ---- mouth
    mo = f.get("mouth", "neutral"); M = mix(lip, (60, 20, 20), 0.55)
    if mo == "grin":
        cv.hline(c - 5, c + 5, r_mouth - 1, M); cv.hline(c - 4, c + 4, r_mouth, (240, 236, 224)); cv.hline(c - 3, c + 3, r_mouth + 1, M)
        cv.put(c - 6, r_mouth - 2, M); cv.put(c + 6, r_mouth - 2, M); cv.hline(c - 2, c + 2, r_mouth + 2, lip)
    elif mo == "smile":
        cv.hline(c - 4, c + 4, r_mouth, M); cv.put(c - 5, r_mouth - 1, M); cv.put(c + 5, r_mouth - 1, M)
        cv.hline(c - 3, c + 3, r_mouth + 1, lip); cv.put(c - 6, r_mouth - 1, SK[2]); cv.put(c + 6, r_mouth - 1, SK[2])
    elif mo == "smirk":
        cv.hline(c - 4, c + 2, r_mouth, M); cv.put(c + 3, r_mouth - 1, M); cv.put(c + 4, r_mouth - 1, M); cv.put(c + 5, r_mouth - 2, M)
        cv.hline(c - 3, c + 2, r_mouth + 1, lip)
    elif mo == "firm":
        cv.hline(c - 3, c + 3, r_mouth, M); cv.hline(c - 2, c + 2, r_mouth + 1, SK[1]); cv.put(c - 4, r_mouth + 1, SK[2]); cv.put(c + 4, r_mouth + 1, SK[2])
    elif mo == "frown":
        cv.hline(c - 3, c + 3, r_mouth, M); cv.put(c - 4, r_mouth + 1, M); cv.put(c + 4, r_mouth + 1, M)
    else:
        cv.hline(c - 4, c + 3, r_mouth, M); cv.hline(c - 3, c + 2, r_mouth + 1, lip)
    if f.get("lips"): cv.hline(c - 4, c + 4, r_mouth - 1, mix(lip, SK[2], 0.5)); cv.hline(c - 3, c + 3, r_mouth + 1, lip)
    if fh in ("walrus", "handlebar", "pencil"):
        if fh == "pencil":
            cv.hline(c - 4, c + 4, r_mouth - 2, FH[1])
        else:
            for y in range(r_nose + 2, r_mouth + (1 if fh == "walrus" else 0)):
                for x in range(c - 7, c + 8):
                    if abs(x - c) < 7 - max(0, y - r_mouth + 1): cv.put(x, y, FH[2] if (x + y) % 3 else FH[1])
            if fh == "handlebar":
                for s in (-1, 1): cv.put(c + s * 8, r_mouth - 1, FH[1]); cv.put(c + s * 9, r_mouth - 2, FH[1]); cv.put(c + s * 9, r_mouth - 3, FH[2])
    # ---- ears
    for side in (-1, 1):
        ex = c + side * 32
        for y in range(row(1.632), row(1.588) + 1): cv.put(ex, y, SK[1]); cv.put(ex + side, y, SK[2])
    # ---- hair coverage on the scalp (under the hair shell), sideburns
    hl = row(hair.get("hairline", 1.68)); st = hair["style"]
    for y in range(H):
        for x in range(W):
            d = abs(x - c)
            bald_top = st == "horseshoe" and y < hl + 4 and d < 40
            covered = (y < hl and d < 34) or (d > 44 and y < row(1.52)) or (34 <= d <= 44 and y < row(1.64))
            if st in ("bob", "bob_sleek", "curls", "braid", "ponytail_curly", "bun", "braids_back"): covered = covered or (d > 26 and y < row(1.58))
            if bald_top: covered = d > 30 and y > row(1.69)
            if covered: cv.put(x, y, HR[1] if (x + y) % 4 else HR[0])
            if bald_top and d < 30: cv.put(x, y, SK[3] if (x // 3 + y // 2) % 7 else SK[2])
    if sp["gender"] == "m" and st not in ("buzz",):
        for side in (-1, 1):
            for y in range(row(1.64), row(1.59) + 1):
                for dx in range(27, 31): cv.put(c + side * dx, y, HR[1])
    return cv


# ================================================================ hair strands
def paint_hair(name, sp):
    hair = sp["hair"]; HR = ramp(hair["color"], 2, 2, 0.20); st = hair["style"]
    cv = Canvas(64, 64); rnd = random.Random(H(name) & 0xffff)
    for x in range(64):
        k = rnd.choice((1, 2, 2, 3))
        for y in range(64):
            c = HR[k]
            if st in ("curls", "ponytail_curly", "puff"):
                c = HR[2] if ((x + (y // 3) * 2) % 6) < 3 else HR[1]
                if (x + y * 2) % 9 == 0: c = HR[3]
                if (x * 3 + y) % 13 == 0: c = HR[0]
            elif st in ("braid", "braids_back"):
                c = HR[2] if ((x + y) % 6) < 3 else HR[1]
                if (x - y) % 6 == 0: c = HR[0]
            elif st == "buzz":
                c = HR[2] if (x + y) % 2 else HR[1]
            else:
                if x % 6 == 0: c = HR[1] if k > 1 else HR[0]
                if x % 6 == 3 and (y // 6) % 2 == 0: c = HR[3]
                if y > 56 and x % 3 == 0: c = HR[0]
            cv.put(x, 63 - y, c)
    if hair.get("streak"):
        for x in range(10, 16):
            for y in range(64): cv.put(x, y, ramp(hair["streak"], 1, 1)[1 if x % 2 else 2])
    if hair.get("beads"):
        for y in range(0, 64, 8):
            for x in range(1, 64, 6): cv.put(x, y, hair["beads"]); cv.put(x, y + 1, mix(hair["beads"], (90, 60, 20), 0.4))
    return cv


# ================================================================ clothing tiles
def fabric(kind, base, accent, line, seed):
    P = ramp(base, 2, 2, 0.12); A = ramp(accent, 1, 1, 0.12); cv = Canvas(64, 64, P[2]); n = vnoise(64, 64, 8, seed)
    if kind == "flannel":
        for y in range(64):
            for x in range(64):
                hb, vb = (y % 16) < 5, (x % 16) < 5
                c = P[2] if (x + y) % 2 else P[1]
                if hb and vb: c = A[0]
                elif hb or vb: c = A[1] if (x + y) % 2 else A[2]
                if y % 16 == 8 or x % 16 == 8: c = mix(c, line, 0.6)
                cv.put(x, y, c)
    elif kind in ("tee", "tank", "henley", "jacket"):
        for y in range(64):
            for x in range(64):
                k = 3 if n[y][x] > 0.86 else 2
                if n[y][x] < 0.12: k = 1
                if x % 4 == 0 and k == 2 and kind == "henley": k = 1
                cv.put(x, y, P[k])
    elif kind in ("button", "blouse", "polo"):
        for y in range(64):
            for x in range(64):
                c = P[2] if (x // 2 + y // 2) % 2 else P[3 if kind == "polo" else 2]
                if kind == "button" and y % 8 == 0: c = mix(P[2], line, 0.25)
                if kind == "blouse" and (x % 16 == 3 and y % 16 == 5 or x % 16 == 11 and y % 16 == 13): c = line
                if n[y][x] < 0.18: c = P[1]
                cv.put(x, y, c)
    elif kind in ("coverall", "work", "cargo", "chinos", "slacks", "coverall_waist", "overalls"):
        for y in range(64):
            for x in range(64):
                k = 2 if (x + y) % 3 else 1
                if n[y][x] > 0.78: k = 3
                cv.put(x, y, P[k])
    elif kind == "jeans":
        for y in range(64):
            for x in range(64):
                k = 2 if (x + y) % 4 else 1
                if n[y][x] > 0.84 and (x + y) % 2: k = 3
                cv.put(x, y, P[k])
    rnd = random.Random(seed)
    bright = sum(base) / 3 > 150                           # pale and hi-vis cloth: folds would read as stains
    for _ in range(0 if bright else 2):                    # a couple of soft folds
        x, y = rnd.randrange(64), rnd.randrange(64); L = rnd.randrange(6, 11); d = rnd.choice((-1, 1))
        for i in range(L): cv.put(x + i, y + (i * d) // 3, mix(P[1], P[2], 0.5)); cv.put(x + i, y + (i * d) // 3 - 1, P[3])
    return cv, P


def bands(cv, zs, col, h=2):
    R = ramp(col, 1, 1, 0.1)
    for z in zs:
        r = tile_row(z)
        for x in range(64):
            for k in range(h): cv.put(x, r + k, R[1] if k else R[2])
            cv.put(x, r - 1, mix(cv.get(x, r - 1), (0, 0, 0), 0.25))


def paint_top(name, sp):
    t = sp["top"]; cv, P = fabric(t["kind"], t["base"], t.get("accent", t["base"]), t.get("line", t["base"]), H(name) & 0xfff)
    if t.get("stripes"): bands(cv, (1.205, 0.975), (214, 216, 206))
    front = Canvas(64, 64); front.p = [r[:] for r in cv.p]
    k = t["kind"]
    def put_w(x, z, c):
        px, py = tile_px(x, z); front.put(px, py, c)
    if k in ("button", "flannel", "blouse"):                           # placket + buttons
        for zz in range(88, 140):
            z = zz / 100; put_w(0.0, z, mix(P[1], (0, 0, 0), 0.2)); put_w(0.006, z, P[3])
            if zz % 6 == 0: put_w(0.003, z, t.get("line", (230, 226, 214)))
        for zz in range(122, 130):                                      # chest pocket (his left)
            for xx in range(-11, -3): put_w(xx / 100, zz / 100, P[1] if zz in (129, 122) or xx in (-11, -4) else P[2])
    if k in ("henley", "polo"):
        for zz in range(126, 141): put_w(0.0, zz / 100, P[1])
        for zz in (128, 132, 136): put_w(0.004, zz / 100, (230, 226, 214))
    if k == "polo" and t.get("logo"):                                   # "QD" chest logo
        lx, ly = tile_px(-0.10, 1.31)
        text(front, lx - 3, ly, "QD", t.get("line", (240, 230, 200)))
    if k in ("coverall", "jacket"):                                     # zip
        for zz in range(88, 146): put_w(0.0, zz / 100, (150, 150, 150) if zz % 2 else (90, 90, 96))
        if k == "coverall":
            for zz in range(118, 126):
                for xx in range(-12, -4): put_w(xx / 100, zz / 100, P[1] if zz in (118, 125) or xx in (-12, -5) else P[2])
    return cv, front


def paint_cuff(sp):
    t = sp["top"]; P = ramp(t["base"] if t.get("sleeves") != "rolled" else t.get("accent", t["base"]), 1, 1, 0.13)
    cv = Canvas(32, 32)
    for y in range(32):
        for x in range(32): cv.put(x, y, P[0] if (x % 3 == 0 and t.get("sleeves") != "rolled") or y % 8 == 0 else (P[2] if y % 8 == 1 else P[1]))
    return cv


def paint_pants(name, sp):
    p = sp["pants"]; k = p["kind"]
    cv, P = fabric(k, p["color"], p["color"], p["color"], (H(name) >> 4) & 0xfff)
    if sp["top"].get("stripes") and k in ("coverall",): bands(cv, (0.40,), (214, 216, 206))
    if k in ("cargo", "work", "coverall", "coverall_waist", "overalls"):    # thigh pockets / knee patches at canonical heights
        for xs in range(64):
            if xs % 2 == 0: cv.put(xs, tile_row(0.62), P[1])
        r0, r1 = tile_row(0.44), tile_row(0.36)
        for y in range(min(r0, r1), max(r0, r1)):
            for x in range(64):
                if k == "work": cv.put(x, y, P[1] if (x + y) % 2 else P[2])
    if k in ("jeans",):
        rnd = random.Random(H(name) & 0xff)
        for _ in range(3):
            x, y = rnd.randrange(64), rnd.randrange(64)
            for i in range(7): cv.put(x + i, y - i // 2, P[1]); cv.put(x + i, y - i // 2 + 1, P[4])
    hem = Canvas(32, 32)
    HM = ramp(p["color"], 1, 1, 0.12)
    for y in range(32):
        for x in range(32): hem.put(x, y, HM[0] if y % 8 == 0 else (HM[2] if y % 8 == 1 else HM[1]))
    return cv, hem


def paint_over(name, sp):
    o = sp.get("overlay")
    if not o: return None
    P = ramp(o["color"], 2, 2, 0.11); cv = Canvas(64, 64, P[2]); n = vnoise(64, 64, 8, H(name) & 0x3ff)
    for y in range(64):
        for x in range(64):
            k = 2
            if o["kind"] == "hivis" and (x + 2 * y) % 8 == 0: k = 3                   # mesh weave
            if o["kind"] != "hivis" and n[y][x] < 0.16: k = 1
            if o["kind"] == "cardigan": k = 2 if (x % 3) else 1
            cv.put(x, y, P[k])
    if o["kind"] == "hivis":
        bands(cv, (1.215, 1.005), (214, 216, 206), 3)
        if o.get("foreman"):
            for x in range(64):
                if x % 3 == 0: cv.put(x, tile_row(1.30), (40, 40, 44))
    if o["kind"] == "fieldvest":
        for zc, w in ((1.06, 9), (1.25, 7)):                         # bellows pockets with flaps
            for xc in (-0.09, 0.09):
                px, py = tile_px(xc, zc)
                for dy in range(-4, 5):
                    for dx in range(-w // 2, w // 2 + 1):
                        cv.put(px + dx, py + dy, P[1] if abs(dy) == 4 or abs(dx) == w // 2 else P[2])
                cv.hline(px - w // 2, px + w // 2, py - 3, P[3])
    return cv


def paint_skin(sp):
    SK = ramp(sp["skin"], 3, 1, 0.11, 0.03); cv = Canvas(32, 32)
    for y in range(32):
        for x in range(32): cv.put(x, y, SK[3] if (x // 4 + y // 8) % 6 else mix(SK[3], SK[2], 0.5))
    return cv


def paint_shoes(name, sp):
    s = sp["shoes"]; k = s["kind"]; U = ramp(s["color"], 2, 1, 0.14); WH = ramp((228, 224, 210), 2, 1, 0.07)
    sole = (60, 54, 50) if k in ("boots", "loafers", "flats") else (226, 220, 206)
    cv = Canvas(64, 64, U[2]); L0, L1 = SHOE_LEN
    for y in range(32, 64):
        for x in range(64):
            yl = L0 + x / 63 * (L1 - L0); z = SHOE_H * (1 - (y - 32) / 31); c = U[2]
            if k == "sneakers" and yl > 0.13 and z < 0.075: c = WH[2]
            if k == "boots" and yl > 0.14 and z < 0.08: c = U[1]                      # scuffed toe cap
            if k == "boots" and yl < -0.04 and z > 0.13: c = U[3]                     # padded collar
            if z < 0.035: c = sole if k != "sneakers" else WH[1]
            if z < 0.012: c = (40, 36, 34)
            cv.put(x, y, c)
    for x in range(64): cv.put(x, 32 + int((1 - 0.035 / SHOE_H) * 31), mix(sole, (0, 0, 0), 0.3))
    for y in range(32):
        for x in range(64):
            yl = L0 + x / 63 * (L1 - L0); xl = (y / 31 - 0.5) * 2 * SHOE_W
            c = U[2] if abs(xl) > 0.02 else U[1]
            if k == "sneakers" and yl > 0.13: c = WH[2]
            cv.put(x, y, c)
    if k in ("boots", "sneakers"):
        lace = (210, 196, 150) if k == "boots" else WH[3]
        for x in range(12, 42, 4):
            for y in range(12, 20): cv.put(x, y, lace if (y + x // 4) % 3 else mix(lace, (0, 0, 0), 0.3))
    if k == "loafers":
        for x in range(30, 44): cv.put(x, 15, U[0]); cv.put(x, 16, U[3])
    sole_cv = Canvas(32, 32)
    for y in range(32):
        for x in range(32): sole_cv.put(x, y, sole if y % 6 else mix(sole, (0, 0, 0), 0.3))
    return cv, sole_cv


# gear swatch atlas: 8x8 cells, each a tiny shaded swatch (UVs point into a cell)
def gear_swatches(sp):
    hat = sp.get("hat", (240, 196, 40))
    sw = {"hat": hat, "hat_dark": mix(hat, (0, 0, 0), 0.3), "metal": (150, 154, 156), "black": (34, 34, 38),
          "leather": (104, 70, 44), "lens": (92, 124, 138), "strap": (60, 56, 52), "white": (236, 232, 222),
          "gold": (226, 184, 72), "red": (190, 56, 50), "orange": (236, 120, 40), "glove": (180, 150, 96),
          "cap": sp.get("cap", hat), "radio": (52, 54, 58), "badge": (236, 226, 190), "fh": sp["face"].get("fh_col") or sp["hair"]["color"],
          "hair": sp["hair"]["color"], "skin": sp["skin"], "suspender": (46, 54, 84), "canvas": (126, 110, 80),
          "teal": (60, 140, 140), "pen": (40, 70, 160), "muff": (220, 60, 40)}
    return sw
def paint_gear(sp):
    sw = gear_swatches(sp); cv = Canvas(64, 64, (128, 0, 128))
    for key in GEAR_KEYS:
        cx, cy = gear_cell(key); R = ramp(sw[key], 1, 1, 0.14)
        for y in range(8):
            for x in range(8):
                k = 2 if y < 1 else (0 if y > 6 else 1)
                cv.put(cx * 8 + x, cy * 8 + y, R[k])
    return cv


def paint_badge(name, sp):
    cv = Canvas(32, 16, (236, 226, 190))
    cv.rect(0, 0, 32, 5, (226, 150, 40)); text(cv, 2, 0, "QD", (60, 40, 20))
    nm = name.upper()[:6]; text(cv, 16 - text_w(nm) // 2, 8, nm, (40, 36, 40))
    for x in range(32): cv.put(x, 15, (150, 140, 110)); cv.put(x, 5, (170, 100, 30))
    return cv


def paint(name):
    sp = CAST[name]; out = os.path.join(TEX_ROOT, name); os.makedirs(out, exist_ok=True)
    pre = os.path.join(out, "T_QD_%s_" % name)
    paint_head(name, sp).save(pre + "Head.png")
    paint_hair(name, sp).save(pre + "Hair.png")
    top, front = paint_top(name, sp); top.save(pre + "Top.png"); front.save(pre + "TopFront.png")
    paint_cuff(sp).save(pre + "TopCuff.png")
    pants, hem = paint_pants(name, sp); pants.save(pre + "Pants.png"); hem.save(pre + "PantsHem.png")
    ov = paint_over(name, sp)
    if ov: ov.save(pre + "Over.png")
    paint_skin(sp).save(pre + "Skin.png")
    sh, so = paint_shoes(name, sp); sh.save(pre + "Shoes.png"); so.save(pre + "Sole.png")
    paint_gear(sp).save(pre + "Gear.png")
    paint_badge(name, sp).save(pre + "Badge.png")


if __name__ == "__main__":
    names = sys.argv[1:] or list(CAST)
    for n in names: paint(n)
    print("PAINT_OK", len(names))
