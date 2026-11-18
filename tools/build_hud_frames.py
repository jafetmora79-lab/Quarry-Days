#!/usr/bin/env python3
"""Draws the HUD's nine-slice frames, plates, buttons, slots, keycaps and bars in code: hand-written pixel art, no generated imagery.

  python tools/build_hud_frames.py      ->  overwrites the matching files in assets/ui/hud/ (same sizes and nine-slice margins as before, see scripts/ui_skin.gd)

One style for all of it: a dark walnut plank face (a few tones of grain, nothing noisy), a bevelled brass trim lit from the top-left, notched corners with small riveted brackets, a
1 px near-black outline and a 1 px inner highlight / shadow. Every piece is drawn on a tiny canvas and the game scales it with nearest-neighbour filtering, so edges stay crisp.
Palette comes straight from scripts/ui_theme.gd (BG walnut, BORDER / BORDER_HI brass, ACCENT amber).
"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "ui", "hud")
BACKUP = os.path.join(ROOT, "tools", "ui_art_src", "ai_frames_backup")


def c(r, g, b, a=255):
    return np.array([r, g, b, a], dtype=np.float32)


# QUARRY SIGNAGE: cool charcoal-blue steel plates with a bevelled steel rim, a hazard-yellow pinstripe, bolted corners with hazard-striped brackets, painted yellow / orange buttons.
OUTLINE = c(8, 10, 13)
WOOD = c(36, 43, 52)                 # (the panel face: brushed steel; the name is kept from the first, wooden version)
WOOD_DK = c(26, 31, 38)
BRASS = c(86, 98, 112)               # (the rim: steel; BRASS_* names kept)
BRASS_HI = c(158, 172, 188)
BRASS_LO = c(48, 55, 64)
BRASS_DK = c(28, 33, 40)
AMBER = c(255, 200, 40)
YELLOW = c(250, 196, 36)
YELLOW_DK = c(168, 120, 16)


def h(x, y, s=0):
    n = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def mix(a, b, t):
    return a * (1 - t) + b * t


def wood(x, y, base, seed=1, grain=0.10):
    """A brushed-steel face: each COLUMN has its own tone (vertical brushing), a few lighter scratches, the odd dark pit."""
    col = h(x // 1, 0, seed) - 0.5
    tone = 1.0 + col * grain * 1.6
    if h(x, y // 5, seed + 3) < 0.07:
        tone += 0.09
    if h(x // 2, y // 2, seed + 9) < 0.02:
        tone -= 0.2
    out = base.copy()
    out[:3] = np.clip(base[:3] * tone, 0, 255)
    return out


def new(w, hgt):
    return np.zeros((hgt, w, 4), dtype=np.float32)


def put(img, x, y, col):
    if 0 <= y < img.shape[0] and 0 <= x < img.shape[1]:
        img[y, x] = col


def frame(w, hgt, trim=2, notch=2, bracket=0, face=WOOD, alpha=238, brass=(BRASS_HI, BRASS, BRASS_LO), seed=1, glow=None, grain=0.10, rivet=True, flat_face=False):
    """The shared panel: outline, bevelled brass trim of `trim` px, a dark gap, an inner highlight, a plank face. `bracket` = size of the corner brackets (0 = none)."""
    img = new(w, hgt)
    hi, mid, lo = brass
    for y in range(hgt):
        for x in range(w):
            d = min(x, y, w - 1 - x, hgt - 1 - y)
            # notched corners
            cx = min(x, w - 1 - x)
            cy = min(y, hgt - 1 - y)
            if cx + cy < notch:
                continue
            lit = (x <= y and x < w - 1 - x) or (y <= x and y < hgt - 1 - y)           # the top / left bevel faces the light
            top_left = min(x, y) <= min(w - 1 - x, hgt - 1 - y)
            if d == 0 or cx + cy == notch:
                col = OUTLINE
            elif d <= trim:
                if d == 1:
                    col = hi if top_left else mid
                elif d == trim:
                    col = lo if not top_left else mid
                else:
                    col = mid if top_left else lo
            elif d == trim + 1:
                col = BRASS_DK * 0.55 + OUTLINE * 0.45
                col = np.array([col[0], col[1], col[2], 255], dtype=np.float32)
            elif d == trim + 2:
                col = YELLOW if top_left else YELLOW_DK                  # the hazard-yellow pinstripe just inside the steel rim
                col = np.array([col[0], col[1], col[2], 255], dtype=np.float32)
            elif d == trim + 3:
                col = mix(wood(x, y, face, seed, grain), OUTLINE, 0.5)
                col[3] = 255
            else:
                col = wood(x, y, face, seed, 0.0 if flat_face else grain)
            img[y, x] = col
    img[..., 3] = np.where(img[..., 3] > 0, np.where(np.arange(0), 0, 255), 0)[..., 0] if False else img[..., 3]
    # corner brackets: a small brass plate with a rivet
    if bracket:
        for (ox, oy, sx, sy) in ((0, 0, 1, 1), (w - 1, 0, -1, 1), (0, hgt - 1, 1, -1), (w - 1, hgt - 1, -1, -1)):
            for ly in range(bracket):
                for lx in range(bracket):
                    if lx + ly < notch:
                        continue
                    x, y = ox + sx * lx, oy + sy * ly
                    edge = lx == 0 or ly == 0 or lx + ly == notch
                    inner = lx == bracket - 1 or ly == bracket - 1
                    if edge:
                        col = OUTLINE
                    elif inner:
                        col = lo
                    else:
                        stripe = ((lx + ly) // 2) % 2 == 0                         # hazard stripes: yellow and black, running diagonally
                        col = YELLOW if stripe else c(26, 28, 32)
                        if lx == 1 or ly == 1:
                            col = hi if stripe is False else YELLOW
                    put(img, x, y, col)
            if rivet and bracket >= 6:
                rx, ry = ox + sx * (bracket // 2 + 1), oy + sy * (bracket // 2 + 1)
                put(img, rx, ry, BRASS_HI)
                put(img, rx + 1, ry, BRASS_HI)
                put(img, rx + sx, ry + sy, OUTLINE)
    if glow is not None:                                                  # a lit amber edge just inside the trim (the selected slot)
        for y in range(hgt):
            for x in range(w):
                d = min(x, y, w - 1 - x, hgt - 1 - y)
                if d == trim + 2 and img[y, x, 3] > 0:
                    img[y, x] = glow
    return img


def save(name, img, alpha_face=238):
    a = img.copy()
    # the face is slightly see-through (the world shows faintly); outline and trim are solid
    ys, xs = np.nonzero(a[..., 3] > 0)
    for y, x in zip(ys, xs):
        w, hgt = a.shape[1], a.shape[0]
        d = min(x, y, w - 1 - x, hgt - 1 - y)
        a[y, x, 3] = 255 if d < 7 else alpha_face
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    im.save(path)


def inset_well(w, hgt, glow=None, tint=None, hatch=False, seed=5):
    """A recessed dark well (item slot): a brass frame, then a deep inset with the shadow on the top and left."""
    img = frame(w, hgt, trim=2, notch=2, bracket=0, face=c(18, 22, 28), seed=seed, grain=0.04)
    for y in range(hgt):
        for x in range(w):
            d = min(x, y, w - 1 - x, hgt - 1 - y)
            if img[y, x, 3] == 0:
                continue
            if d in (2, 3):
                top_left = min(x, y) <= min(w - 1 - x, hgt - 1 - y)
                img[y, x, :3] = np.clip(img[y, x, :3] * (0.55 if top_left else 1.25), 0, 255)
            if d > 3:
                img[y, x, :3] = np.clip(img[y, x, :3] * 0.8 + (np.array(tint[:3]) * 0.2 if tint is not None else 0), 0, 255)
                if hatch and (x + y) % 4 == 0:
                    img[y, x, :3] = np.clip(img[y, x, :3] * 1.5, 0, 255)
    if glow is not None:
        for y in range(hgt):
            for x in range(w):
                d = min(x, y, w - 1 - x, hgt - 1 - y)
                if img[y, x, 3] > 0 and d in (1, 2):
                    img[y, x] = glow if d == 1 else mix(glow, OUTLINE, 0.45)
                    img[y, x, 3] = 255
    return img


def button(w, hgt, face, state="normal", seed=11):
    img = frame(w, hgt, trim=1, notch=2, face=face, seed=seed, grain=0.05, brass=(BRASS_HI, BRASS, BRASS_LO), flat_face=True)
    for y in range(hgt):
        for x in range(w):
            d = min(x, y, w - 1 - x, hgt - 1 - y)
            if img[y, x, 3] == 0 or d < 2:
                continue
            top_left = min(x, y) <= min(w - 1 - x, hgt - 1 - y)
            if d == 2:
                k = (1.55 if top_left else 0.6) if state != "pressed" else (0.6 if top_left else 1.4)
                img[y, x, :3] = np.clip(img[y, x, :3] * k, 0, 255)
            elif d == 3 and state != "pressed":
                img[y, x, :3] = np.clip(img[y, x, :3] * (1.18 if top_left else 0.85), 0, 255)
    return img


def bar_fill(w, hgt, col):
    """A flat fill with a bright top line and a dark bottom line (lit from above), and a faint 2 px segment rhythm."""
    img = new(w, hgt)
    base = col
    for y in range(hgt):
        for x in range(w):
            t = y / max(1, hgt - 1)
            k = 1.35 if y == 0 else (0.62 if y == hgt - 1 else (1.12 if y < hgt * 0.4 else 0.92))
            if (x // 4) % 2 == 1 and 0 < y < hgt - 1:
                k *= 0.96
            img[y, x, :3] = np.clip(base[:3] * k, 0, 255)
            img[y, x, 3] = 255
    return img


def keycap(w, hgt, state="normal"):
    face = {"normal": c(70, 82, 96), "hover": c(96, 110, 126), "pressed": c(48, 56, 66), "off": c(36, 41, 48)}[state]
    return button(w, hgt, face, "pressed" if state == "pressed" else "normal", seed=21)


def rivet(w, hgt, lit=False):
    img = new(w, hgt)
    cx, cy = (w - 1) / 2.0, (hgt - 1) / 2.0
    r = min(w, hgt) / 2.0 - 1.0
    for y in range(hgt):
        for x in range(w):
            dd = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if dd <= r + 0.5:
                col = (AMBER if lit else BRASS_HI) if (x - cx) + (y - cy) < -1 else ((c(255, 150, 40) if lit else BRASS) if (x - cx) + (y - cy) < r * 0.6 else BRASS_LO)
                img[y, x] = col
                if dd > r - 0.6:
                    img[y, x] = OUTLINE
    return img


def dot(w, hgt, col):
    img = new(w, hgt)
    cx, cy = (w - 1) / 2.0, (hgt - 1) / 2.0
    r = min(w, hgt) / 2.0 - 1.0
    for y in range(hgt):
        for x in range(w):
            dd = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if dd <= r + 0.4:
                img[y, x] = OUTLINE if dd > r - 0.7 else (np.clip(col * 1.35, 0, 255) if (x - cx) + (y - cy) < -1 else col)
                img[y, x, 3] = 255
    return img


def divider(w, hgt):
    img = new(w, hgt)
    m = hgt // 2
    for x in range(2, w - 2):
        img[m - 1, x] = BRASS_LO
        img[m, x] = BRASS
        img[m + 1, x] = BRASS_DK
    for x in (0, 1, w - 2, w - 1):
        for dy in (-1, 0, 1):
            img[m + dy, x] = BRASS_HI if dy == -1 else (BRASS if dy == 0 else BRASS_LO)
    return img


def strip(w, hgt, col):
    """A vertical accent strip (the colored tab on a toast's left)."""
    img = new(w, hgt)
    for y in range(hgt):
        for x in range(w):
            if x in (0, w - 1) or y in (0, hgt - 1):
                img[y, x] = OUTLINE
            else:
                img[y, x, :3] = np.clip(col[:3] * (1.3 if x < w * 0.35 else (0.7 if x > w * 0.7 else 1.0)), 0, 255)
                img[y, x, 3] = 255
    return img


def groove(w, hgt):
    img = frame(w, hgt, trim=1, notch=2, face=c(20, 14, 10), seed=31, grain=0.03, flat_face=True)
    for y in range(hgt):
        for x in range(w):
            d = min(x, y, w - 1 - x, hgt - 1 - y)
            if img[y, x, 3] and d in (2, 3):
                top_left = min(x, y) <= min(w - 1 - x, hgt - 1 - y)
                img[y, x, :3] = np.clip(img[y, x, :3] * (0.5 if top_left else 1.4), 0, 255)
    return img


def main():
    os.makedirs(BACKUP, exist_ok=True)
    import shutil
    pieces = {}
    # --- panels and plates (sizes and margins are those the game was built around: scripts/ui_skin.gd)
    pieces["panel_main"] = frame(49, 47, trim=2, notch=3, bracket=9, seed=2)
    pieces["panel_inset"] = frame(44, 45, trim=1, notch=2, bracket=0, face=c(28, 34, 42), seed=3, grain=0.07)
    pieces["panel_vehicle"] = frame(49, 46, trim=2, notch=3, bracket=9, face=c(42, 38, 30), seed=4)
    pieces["plate_title"] = frame(82, 28, trim=2, notch=3, bracket=10, seed=5)
    pieces["plate_prompt"] = frame(83, 22, trim=1, notch=2, bracket=7, seed=6, rivet=False)
    pieces["plate_toast"] = frame(57, 32, trim=2, notch=3, bracket=8, seed=7)
    pieces["plate_banner"] = frame(90, 35, trim=2, notch=3, bracket=12, seed=8)
    pieces["plate_repair"] = frame(86, 35, trim=2, notch=3, bracket=9, seed=9)
    pieces["frame_dialog"] = frame(87, 50, trim=3, notch=4, bracket=14, seed=10)
    pieces["frame_portrait"] = frame(36, 37, trim=2, notch=3, bracket=0, face=c(20, 24, 30), seed=12, grain=0.04)
    pieces["plate_chat"] = frame(28, 22, trim=1, notch=2, seed=13)
    pieces["plate_check"] = frame(26, 22, trim=1, notch=2, seed=14)
    pieces["plate_list"] = frame(26, 22, trim=1, notch=2, seed=15)
    pieces["plate_pin"] = frame(26, 22, trim=1, notch=2, seed=16)
    pieces["plate_star"] = frame(26, 22, trim=1, notch=2, seed=17)
    pieces["plate_trophy"] = frame(28, 22, trim=1, notch=2, seed=18)
    # --- buttons and keycaps
    pieces["btn_main"] = button(48, 23, c(66, 78, 92))
    pieces["btn_primary"] = button(48, 23, c(196, 112, 22))
    pieces["btn_danger"] = button(48, 23, c(170, 46, 36))
    pieces["btn_disabled"] = button(48, 23, c(46, 50, 56))
    pieces["keycap_small"] = keycap(20, 20)
    pieces["keycap_small_hover"] = keycap(19, 20, "hover")
    pieces["keycap_small_off"] = keycap(19, 20, "off")
    pieces["keycap_small_pressed"] = keycap(19, 21, "pressed")
    pieces["keycap_wide"] = keycap(41, 21)
    # --- item slots
    pieces["slot_empty"] = inset_well(32, 31)
    pieces["slot_selected"] = inset_well(32, 33, glow=AMBER, tint=c(120, 80, 20))
    pieces["slot_ok"] = inset_well(30, 32, glow=c(120, 200, 90), tint=c(40, 90, 30))
    pieces["slot_bad"] = inset_well(32, 32, glow=c(220, 90, 70), tint=c(110, 30, 24))
    pieces["slot_locked"] = inset_well(30, 32, hatch=True, tint=c(60, 60, 60))
    pieces["slot_dashed"] = inset_well(30, 31, hatch=True)
    # --- bars, dots, rivets, dividers, tabs
    pieces["bar_groove"] = groove(78, 17)
    pieces["bar_fill_green"] = bar_fill(52, 14, c(110, 176, 74))
    pieces["bar_fill_gold"] = bar_fill(50, 13, c(240, 184, 64))
    pieces["bar_fill_red"] = bar_fill(50, 13, c(204, 72, 52))
    pieces["bar_fill_blue"] = bar_fill(49, 13, c(84, 146, 204))
    pieces["dot_on"] = dot(16, 17, c(240, 184, 64))
    pieces["dot_off"] = dot(17, 17, c(52, 60, 70))
    pieces["dot_warn"] = dot(16, 17, c(204, 72, 52))
    pieces["dot_done"] = dot(16, 17, c(110, 176, 74))
    pieces["rivet"] = rivet(14, 14)
    pieces["rivet_lit"] = rivet(14, 14, True)
    pieces["divider"] = divider(106, 11)
    pieces["strip_gold"] = strip(11, 42, c(240, 184, 64))
    pieces["strip_green"] = strip(11, 42, c(110, 176, 74))
    pieces["strip_red"] = strip(12, 42, c(204, 72, 52))
    pieces["strip_blue"] = strip(11, 42, c(84, 146, 204))
    for name, img in pieces.items():
        src = os.path.join(OUT, name + ".png")
        bk = os.path.join(BACKUP, name + ".png")
        if os.path.exists(src) and not os.path.exists(bk):
            shutil.copy(src, bk)                                             # keep the old generated art once, next to the sources
        save(name, img)
    print("wrote", len(pieces), "pieces to", OUT)


if __name__ == "__main__":
    main()
