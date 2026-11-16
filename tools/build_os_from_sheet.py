#!/usr/bin/env python3
"""Cuts the ChatGPT-made Quarry OS art sheet (docs/ref/quarry_os_sheet.webp: window, icons with selected plates, panels, buttons) into the game's assets/ui/os files:

    python tools/build_os_from_sheet.py [sheet.webp]

Writes icon_<app>.png and icon_<app>_sel.png (64 px, transparent), wallpaper.png (the sheet's window interior), the 9-patch bevels (raised / pressed / sunken), the title bars and glyphs,
all in the sheet's palette. Everything here is replaceable; the game falls back to drawn graphics when a file is missing. No text is baked into any image.
"""
import os, sys
from PIL import Image, ImageChops, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
OUT = os.path.join(REPO, "assets", "ui", "os")
SHEET = sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, "docs", "ref", "quarry_os_sheet.webp")
im = Image.open(SHEET).convert("RGB")

# (app, plain box, selected box) in sheet pixels: generous boxes, the real bounds are found from the non-background pixels
ICONS = [
    ("employees", (965, 45, 1095, 170), (1092, 45, 1222, 170)),
    ("machinery", (1235, 45, 1380, 170), (1380, 45, 1525, 170)),
    ("catalog", (965, 180, 1095, 310), (1092, 180, 1222, 310)),
    ("production", (1235, 180, 1380, 310), (1380, 180, 1525, 310)),
    ("upgrades", (965, 320, 1095, 450), (1092, 320, 1222, 450)),
    ("sales", (1235, 320, 1380, 450), (1380, 320, 1525, 450)),
    ("plan", (958, 480, 1068, 585), (1068, 480, 1168, 585)),
    ("milestones", (1170, 480, 1258, 585), (1258, 480, 1346, 585)),
    ("stats", (1342, 480, 1436, 585), (1434, 480, 1528, 585)),
]


def background_mask(img):
    """255 where the pixel is the sheet's light checker background (bright, nearly grey)."""
    hsv = img.convert("HSV")
    h, s, v = hsv.split()
    bright = v.point(lambda x: 255 if x > 200 else 0)
    grey = s.point(lambda x: 255 if x < 34 else 0)
    return ImageChops.multiply(bright, grey)


def cut(box):
    crop = im.crop(box)
    bg = background_mask(crop)
    fg = bg.point(lambda x: 0 if x else 255)
    bb = fg.getbbox()
    crop = crop.crop(bb)
    rgba = crop.convert("RGBA")
    w, h = rgba.size
    for seed in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        ImageDraw.floodfill(rgba, seed, (0, 0, 0, 0), thresh=60)
    side = max(w, h)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(rgba, ((side - w) // 2, (side - h) // 2), rgba)
    return sq.resize((64, 64), Image.LANCZOS)


os.makedirs(OUT, exist_ok=True)
for app, plain, sel in ICONS:
    cut(plain).save(os.path.join(OUT, "icon_%s.png" % app))
    cut(sel).save(os.path.join(OUT, "icon_%s_sel.png" % app))

# the wallpaper: the sheet's window interior (dark green brick, faded mountains, pines, an excavator, hazard corners), 16:9
im.crop((38, 92, 928, 586)).save(os.path.join(OUT, "wallpaper.png"))

# ---- 9-patch bevels (8x8, 3 px edges) in the sheet's sandstone metal: light top-left, dark bottom-right, a dark outline
BEIGE, LIGHT, SHADE, EDGE = (189, 158, 123), (230, 206, 175), (130, 104, 76), (46, 34, 24)


def bevel(name, face, hi, lo, edge=EDGE):
    t = Image.new("RGBA", (8, 8), face + (255,))
    d = ImageDraw.Draw(t)
    d.rectangle((0, 0, 7, 7), outline=edge + (255,))
    d.line((1, 1, 6, 1), fill=hi + (255,))
    d.line((1, 1, 1, 6), fill=hi + (255,))
    d.line((1, 6, 6, 6), fill=lo + (255,))
    d.line((6, 1, 6, 6), fill=lo + (255,))
    t.save(os.path.join(OUT, name))


bevel("raised.png", BEIGE, LIGHT, SHADE)
bevel("pressed.png", (170, 140, 108), SHADE, (214, 190, 160))
bevel("sunken.png", (24, 38, 33), (10, 18, 15), (58, 74, 64), edge=(8, 12, 10))
bevel("title_active.png", (212, 182, 144), (240, 220, 190), (150, 120, 88))
bevel("title_inactive.png", (170, 150, 122), (206, 190, 164), (118, 100, 78))

# ---- glyphs (8x8): a dark minimise dash and close cross
g = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
ImageDraw.Draw(g).line((1, 6, 6, 6), fill=(46, 34, 24, 255))
ImageDraw.Draw(g).line((1, 5, 6, 5), fill=(46, 34, 24, 255))
g.save(os.path.join(OUT, "glyph_min.png"))
g = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
d = ImageDraw.Draw(g)
d.line((1, 1, 6, 6), fill=(46, 34, 24, 255))
d.line((6, 1, 1, 6), fill=(46, 34, 24, 255))
d.line((2, 1, 6, 5), fill=(46, 34, 24, 255))
d.line((5, 1, 1, 5), fill=(46, 34, 24, 255))
g.save(os.path.join(OUT, "glyph_close.png"))
print("OS_SHEET_OK")
