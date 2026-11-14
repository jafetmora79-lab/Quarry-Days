#!/usr/bin/env python3
"""Generates the original Quarry OS pixel art into assets/ui/os (run: python3 tools/make_os_art.py).
Everything here is replaceable: QuarryOS loads these paths and falls back to drawn graphics if a file is missing.
Icons are drawn on a 16x16 grid and doubled to 32x32 native pixels. No text or numbers are baked into any image."""
from PIL import Image
import os
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "os")
os.makedirs(OUT, exist_ok=True)
P = {'.': None, 'k': (28, 24, 34), 'w': (250, 250, 244), 'g': (192, 192, 192), 'G': (120, 120, 128), 'y': (250, 214, 80), 'o': (232, 140, 48),
     'r': (206, 70, 60), 'b': (52, 92, 190), 'B': (28, 48, 130), 'c': (110, 200, 220), 'n': (140, 92, 54), 'N': (92, 58, 34), 'l': (88, 168, 70),
     'L': (46, 110, 52), 't': (226, 200, 150), 's': (230, 170, 130), 'p': (240, 120, 150)}
ICONS = {
"employees": [
"................",
".....kkkk.......",
"....kssssk..kkk.",
"....kssssk.kssk.",
"....ksksk..kssk.",
".....kkkk...kk..",
"...kkbbbbkk.kbbk",
"..kbbbbbbbbkkbbk",
"..kbbbbbbbbkbbbk",
"..kbbbbbbbbkbbbk",
"..kbbbbbbbbkkkkk",
"..kkkkkkkkkk....",
"................",
"................",
"................",
"................"],
"machinery": [
"................",
"................",
"................",
"....kkkkkkkk....",
"...kyyyyyyyyk...",
"..kyyyyyyyyyyk..",
"..kyyyyyyyyykkk.",
".kyyyyyyyyyykwwk",
".kyyyyyyyyyykwwk",
".kkkkkkkkkkkkkkk",
"..kGGkk..kkGGk..",
"..kGkGk..kGkGk..",
"..kGGGk..kGGGk..",
"...kkk....kkk...",
"................",
"................"],
"sales": [
"................",
"....kkkkkkkk....",
"...kyyyyyyyyk...",
"..kyyoooooyyyk..",
"..kyoyyyyyoyyk..",
".kyyoyyyyyyyyyk.",
".kyyoooooyyyyyk.",
".kyyyyyyyoyyyyk.",
".kyyyyyyyyoyyyk.",
".kyyoooooooyyyk.",
"..kyyyyoyyyyyk..",
"..kyyyyoyyyyyk..",
"...kyyyyyyyyk...",
"....kkkkkkkk....",
"................",
"................"],
"plan": [
"................",
"..kkkkkkkkkkkk..",
".kttttttttttttk.",
".kttttkkkkttttk.",
".ktttkNNNNktttk.",
".kttkNnnnnNkttk.",
".kttkNnddnNkttk.",
".kttkNnnnnNkttk.",
".ktttkNNNNktttk.",
".kttttkkkkttttk.",
".ktrttttttttttk.",
".ktrrttttkkkttk.",
".kttttttttttttk.",
"..kkkkkkkkkkkk..",
"................",
"................"],
"production": [
"................",
"................",
"......kk........",
".....kGGk.......",
".kkkkkkGGkkkkk..",
".kGGGGGGGGGGGk..",
".kGyyGGGGyyGGk..",
".kGyyGGGGyyGGk..",
".kGGGGGGGGGGGk..",
".kkkkkkkkkkkkk..",
"kkggkggkggkggkk.",
"kGGGkGGGkGGGkGk.",
".kkk.kkk.kkk.kk.",
"................",
"................",
"................"],
"upgrades": [
"................",
".......kk.......",
"......kyyk......",
".....kyyyyk.....",
"....kyyyyyyk....",
"...kyyyyyyyyk...",
"..kkkkyyyykkkk..",
".....kyyyyk.....",
".....kyyyyk.....",
".....kyyyyk.....",
".....kkkkkk.....",
"...kkGGGGGGkk...",
"...kGGGGGGGGk...",
"...kkkkkkkkkk...",
"................",
"................"],
"milestones": [
"................",
"...kkkkkkkkkk...",
"...kyyyyyyyyk...",
"..kkyyyyyyyykk..",
".kyk.kyyyyk.kyk.",
".kyk.kyyyyk.kyk.",
"..kkkkyyyykkkk..",
"....kkyyyykk....",
".....kyyyyk.....",
"......kyyk......",
".......kk.......",
"......kyyk......",
".....kyyyyk.....",
"....kkkkkkkk....",
"................",
"................"],
"stats": [
"................",
"................",
"................",
".............kk.",
"............kllk",
"...kk.......kllk",
"..kbbk..kk..kllk",
"..kbbk.kccck.kllk",
"..kbbk.kccck.kllk",
"..kbbk.kccck.kllk",
"kkkkkkkkkkkkkkkk",
"................",
"................",
"................",
"................",
"................"],
}
for name, rows in ICONS.items():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        row = (row + "." * 16)[:16]
        for x, ch in enumerate(row):
            col = P.get(ch)
            if ch == 'd':
                col = (40, 28, 20)
            if col:
                img.putpixel((x, y), col + (255,))
    img.resize((32, 32), Image.NEAREST).save(os.path.join(OUT, "icon_%s.png" % name))

# wallpaper: a 16x16 repeating stone-course pattern in teal
W = Image.new("RGB", (16, 16), (0, 128, 128))
for y in range(16):
    for x in range(16):
        row = y // 8
        off = 8 if row else 0
        edge = (y % 8 == 0) or ((x + off) % 16 == 0)
        W.putpixel((x, y), (0, 112, 116) if edge else ((0, 132, 132) if (x + y) % 7 else (0, 138, 136)))
W.save(os.path.join(OUT, "wallpaper_tile.png"))

# bevelled 9-patch pieces (8x8, 2 px edge): raised, sunken, title bar
def bevel(name, tl, br, face, outer=(0, 0, 0)):
    im = Image.new("RGB", (8, 8), face)
    for i in range(8):
        for j in range(8):
            if i == 0 or j == 0:
                im.putpixel((i, j), tl[0] if (i == 0 or j == 0) else face)
    for i in range(8):
        im.putpixel((i, 0), tl[0]); im.putpixel((0, i), tl[0])
        im.putpixel((i, 7), outer); im.putpixel((7, i), outer)
    for i in range(1, 7):
        im.putpixel((i, 6), br[1]); im.putpixel((6, i), br[1])
        im.putpixel((i, 1), tl[1]); im.putpixel((1, i), tl[1])
    im.save(os.path.join(OUT, name))
GRAY = (192, 192, 192)
bevel("raised.png", [(223, 223, 223), (255, 255, 255)], [None, (128, 128, 128)], GRAY)
bevel("sunken.png", [(128, 128, 128), (64, 64, 64)], [None, (223, 223, 223)], (24, 36, 44), outer=(255, 255, 255))
bevel("pressed.png", [(64, 64, 64), (128, 128, 128)], [None, (223, 223, 223)], (176, 176, 176), outer=(255, 255, 255))
T = Image.new("RGB", (8, 8), (0, 0, 128))
for x in range(8):
    T.putpixel((x, 7), (0, 0, 96))
T.save(os.path.join(OUT, "title_active.png"))
T2 = Image.new("RGB", (8, 8), (128, 128, 128))
T2.save(os.path.join(OUT, "title_inactive.png"))

# mouse cursor 16x16 (hot spot 0,0)
C = ["k...............", "kk..............", "kwk.............", "kwwk............", "kwwwk...........", "kwwwwk..........", "kwwwwwk.........", "kwwwwwwk........",
     "kwwwwwwwk.......", "kwwwwwkkkk......", "kwwkwwk.........", "kwk.kwwk........", "kk..kwwk........", "k....kwwk.......", ".....kwwk.......", "......kk........"]
c = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
for y, row in enumerate(C):
    for x, ch in enumerate(row):
        if ch == 'k': c.putpixel((x, y), (0, 0, 0, 255))
        elif ch == 'w': c.putpixel((x, y), (255, 255, 255, 255))
c.save(os.path.join(OUT, "cursor.png"))
# a small window-control glyph set (close x, minimise _), 8x8 black on transparent
for nm, rows in {"glyph_close": ["........", ".kk..kk.", "..kkkk..", "...kk...", "..kkkk..", ".kk..kk.", "........", "........"],
                 "glyph_min": ["........", "........", "........", "........", "........", ".kkkkkk.", ".kkkkkk.", "........"]}.items():
    g = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == 'k': g.putpixel((x, y), (0, 0, 0, 255))
    g.save(os.path.join(OUT, nm + ".png"))
print("ok")
