#!/usr/bin/env python3
"""Draws the UI icon set from scratch: 64x64 art, rendered at 4x and filtered down, flat shapes with a soft top-light gradient, a bold dark-plum outline and a
small drop shadow, in the game's warm palette. Writes name.png (64 px, the card size) and name_s.png (32 px, small lists / the HUD)."""
import math, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops

SS = 4
N = 64 * SS
OUT_DIR = sys.argv[1] if len(sys.argv) > 1 else 'assets/ui/icons'
PLUM = (44, 26, 40)

def C(r, g, b): return (r, g, b, 255)
GOLD = (C(255, 226, 112), C(222, 156, 36)); GOLD_D = (C(240, 196, 70), C(190, 126, 28))
WOOD = (C(196, 136, 78), C(130, 82, 44)); WOOD_L = (C(222, 168, 104), C(166, 108, 60))
STEEL = (C(226, 232, 240), C(138, 150, 170)); STEEL_D = (C(150, 160, 178), C(86, 96, 116))
RED = (C(246, 104, 76), C(176, 52, 44)); GREEN = (C(146, 214, 98), C(72, 142, 54)); BLUE = (C(120, 168, 224), C(56, 96, 160))
STONE = (C(224, 216, 200), C(146, 138, 124)); COAL = (C(98, 100, 118), C(34, 36, 48)); IRON = (C(226, 120, 88), C(148, 62, 46))
COPPER = (C(244, 168, 104), C(184, 100, 54)); SKIN = (C(250, 206, 164), C(216, 156, 114)); SAND = (C(246, 226, 178), C(192, 160, 108))
ORANGE = (C(255, 168, 64), C(210, 104, 28)); YELLOW = (C(255, 214, 70), C(226, 152, 28)); WHITE = (C(255, 252, 244), C(214, 206, 190)); DARK = (C(70, 72, 86), C(36, 38, 50))
BROWN = (C(150, 100, 64), C(96, 60, 38))

class Icon:
    def __init__(self):
        self.img = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    def _mask(self, draw_fn):
        m = Image.new('L', (N, N), 0)
        draw_fn(ImageDraw.Draw(m))
        return m
    def _paint(self, mask, colors, angle_light=True):
        top, bot = colors
        grad = Image.new('RGBA', (N, N))
        ys = Image.linear_gradient('L').resize((N, N))           # 0 at top .. 255 at bottom
        t = Image.new('RGBA', (N, N), top); b = Image.new('RGBA', (N, N), bot)
        grad = Image.composite(b, t, ys)
        layer = Image.new('RGBA', (N, N), (0, 0, 0, 0))
        layer.paste(grad, (0, 0), mask)
        self.img.alpha_composite(layer)
    def poly(self, pts, colors):
        self._paint(self._mask(lambda d: d.polygon([(x * SS, y * SS) for x, y in pts], fill=255)), colors)
    def rect(self, x0, y0, x1, y1, colors, r=0):
        self._paint(self._mask(lambda d: d.rounded_rectangle([x0 * SS, y0 * SS, x1 * SS, y1 * SS], radius=r * SS, fill=255)), colors)
    def ell(self, x0, y0, x1, y1, colors):
        self._paint(self._mask(lambda d: d.ellipse([x0 * SS, y0 * SS, x1 * SS, y1 * SS], fill=255)), colors)
    def line(self, pts, w, colors):
        self._paint(self._mask(lambda d: d.line([(x * SS, y * SS) for x, y in pts], fill=255, width=int(w * SS), joint='curve')), colors)
    def flat(self, fn, color):
        m = self._mask(fn); layer = Image.new('RGBA', (N, N), color); out = Image.new('RGBA', (N, N), (0, 0, 0, 0)); out.paste(layer, (0, 0), m); self.img.alpha_composite(out)
    def hl(self, pts, w=1.2, a=150):          # a soft highlight stroke
        self.flat(lambda d: d.line([(x * SS, y * SS) for x, y in pts], fill=255, width=int(w * SS), joint='curve'), (255, 255, 255, a))
    def text(self, t, cx, cy, size, color):
        from PIL import ImageFont
        font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', int(size * SS))
        def fn(d):
            bb = d.textbbox((0, 0), t, font=font)
            d.text((cx * SS - (bb[0] + bb[2]) / 2, cy * SS - (bb[1] + bb[3]) / 2), t, font=font, fill=255)
        self.flat(fn, color)
    def dot(self, x, y, r, color):
        self.flat(lambda d: d.ellipse([(x - r) * SS, (y - r) * SS, (x + r) * SS, (y + r) * SS], fill=255), color)
    def blob(self, cx, cy, rx, ry, colors, seed=1, n=7, jit=0.18):
        import random
        rnd = random.Random(seed); pts = []
        for i in range(n):
            a = i / n * math.tau + rnd.uniform(-0.2, 0.2); k = 1.0 + rnd.uniform(-jit, jit)
            pts.append((cx + math.cos(a) * rx * k, cy + math.sin(a) * ry * k))
        self.poly(pts, colors)
        self.hl([(cx - rx * 0.5, cy - ry * 0.35), (cx - rx * 0.1, cy - ry * 0.65)], 1.3, 120)
    def finish(self, outline=1.6):
        a = self.img.split()[3]
        grow = int(outline * SS)
        big = a.filter(ImageFilter.MaxFilter(grow * 2 + 1))
        shadow = ImageChops.offset(big, 0, 2 * SS).filter(ImageFilter.GaussianBlur(1.5 * SS))
        out = Image.new('RGBA', (N, N), (0, 0, 0, 0))
        sh = Image.new('RGBA', (N, N), (0, 0, 0, 90)); out.paste(sh, (0, 0), shadow)
        ol = Image.new('RGBA', (N, N), PLUM + (255,)); out.paste(ol, (0, 0), big)
        out.alpha_composite(self.img)
        return out.resize((64, 64), Image.LANCZOS)

ICONS = {}
def icon(fn):
    ICONS[fn.__name__] = fn
    return fn

@icon
def bag(i):
    i.ell(8, 20, 56, 62, SAND)
    i.poly([(22, 12), (42, 12), (46, 26), (18, 26)], SAND)
    i.poly([(16, 6), (26, 14), (22, 20), (14, 12)], SAND); i.poly([(48, 6), (38, 14), (42, 20), (50, 12)], SAND)
    i.line([(18, 24), (46, 24)], 4.2, BROWN)
    i.ell(23, 36, 41, 52, (C(214, 184, 130), C(184, 150, 96)))
    i.hl([(14, 36), (13, 48)], 1.8, 150); i.hl([(22, 16), (30, 14)], 1.4, 150)
    i.line([(27, 44), (37, 44)], 1.4, BROWN)

@icon
def chisel(i):
    i.line([(20, 46), (44, 16)], 9, ORANGE)
    i.poly([(40, 8), (52, 6), (54, 12), (44, 20)], STEEL)
    i.poly([(44, 18), (54, 12), (56, 24), (46, 28)], STEEL_D)
    i.hl([(24, 40), (38, 22)], 1.6, 140)

@icon
def clerk(i):
    i.rect(14, 10, 50, 58, BROWN, 4)
    i.rect(18, 16, 46, 54, WHITE, 2)
    i.rect(24, 6, 40, 16, STEEL, 3)
    for k, y in enumerate((26, 36, 46)):
        i.rect(21, y - 3, 26, y + 2, GREEN, 1)
        i.line([(29, y), (42, y)], 1.8, (C(170, 160, 146), C(150, 140, 126)))

@icon
def coal(i):
    i.blob(20, 42, 14, 12, COAL, 3); i.blob(42, 42, 16, 13, COAL, 5); i.blob(31, 26, 15, 13, COAL, 8)
    i.hl([(24, 20), (30, 17)], 1.6, 160); i.hl([(40, 38), (46, 36)], 1.4, 140)

@icon
def conveyor(i):
    i.poly([(4, 36), (52, 18), (60, 30), (12, 50)], DARK)
    i.poly([(8, 36), (52, 21), (56, 28), (12, 45)], (C(120, 122, 140), C(70, 72, 90)))
    for k in range(6):
        x = 14 + k * 7.5
        i.line([(x, 41 - k * 3.0), (x + 4, 38 - k * 3.0 - 1)], 1.8, YELLOW)
    i.ell(0, 34, 16, 54, DARK); i.ell(44, 14, 62, 34, DARK); i.ell(4, 38, 12, 50, STEEL); i.ell(49, 18, 57, 30, STEEL)

@icon
def crusher(i):
    i.poly([(10, 10), (54, 10), (44, 34), (20, 34)], STEEL)
    i.rect(14, 34, 50, 56, STEEL_D, 2)
    i.rect(14, 44, 50, 49, YELLOW, 1)
    i.rect(8, 54, 56, 60, DARK, 2)
    i.hl([(14, 14), (48, 14)], 1.6, 150)

@icon
def drill_rig(i):
    i.poly([(32, 4), (46, 50), (18, 50)], ORANGE)
    i.poly([(32, 14), (40, 46), (24, 46)], (C(40, 28, 36), C(40, 28, 36)))
    for y in (22, 32, 42):
        i.line([(22 + (y - 14) * 0.2, y), (42 - (y - 14) * 0.2, y)], 2, ORANGE)
    i.rect(8, 50, 56, 58, YELLOW, 2); i.rect(36, 36, 56, 52, YELLOW, 3)
    i.ell(40, 52, 50, 62, DARK)

@icon
def equipment(i):
    i.line([(16, 48), (38, 26)], 10, STEEL)
    i.ell(32, 4, 58, 30, STEEL)
    i.poly([(46, 4), (62, 4), (62, 18), (53, 16), (50, 12)], (C(44, 26, 40), C(44, 26, 40)))
    i.ell(40, 12, 50, 22, (C(44, 26, 40), C(44, 26, 40)))
    i.ell(6, 40, 26, 60, STEEL_D); i.ell(12, 46, 20, 54, (C(60, 66, 84), C(60, 66, 84)))
    i.hl([(20, 44), (36, 28)], 1.8, 160)

@icon
def excavator(i):
    i.rect(4, 44, 40, 58, DARK, 6)
    for x in (10, 22, 34): i.ell(x - 3, 47, x + 3, 53, STEEL)
    i.rect(10, 28, 30, 46, YELLOW, 3)
    i.rect(12, 20, 24, 34, (C(150, 214, 240), C(70, 134, 190)), 2)
    i.line([(26, 32), (44, 14), (56, 30)], 5, YELLOW)
    i.poly([(52, 28), (62, 28), (60, 40), (50, 38)], STEEL)
    i.hl([(12, 30), (28, 30)], 1.4, 150)

@icon
def gold(i):
    i.blob(18, 44, 14, 11, GOLD, 2); i.blob(44, 44, 15, 12, GOLD, 4); i.blob(31, 27, 15, 12, GOLD, 6)
    i.hl([(24, 22), (32, 20)], 1.8, 210); i.hl([(11, 40), (17, 38)], 1.6, 190); i.hl([(38, 40), (46, 38)], 1.6, 190)

@icon
def hammer(i):
    i.line([(18, 54), (42, 22)], 8, WOOD)
    i.poly([(28, 6), (56, 14), (52, 28), (24, 20)], STEEL)
    i.poly([(24, 20), (52, 28), (50, 33), (21, 25)], STEEL_D)
    i.hl([(30, 11), (50, 17)], 1.6, 160)

@icon
def hauler(i):
    i.poly([(8, 22), (54, 22), (46, 44), (18, 44)], (C(246, 120, 72), C(184, 64, 40)))
    i.blob(24, 20, 9, 6, STONE, 1); i.blob(40, 18, 10, 7, STONE, 4)
    i.ell(26, 40, 42, 58, DARK); i.ell(30, 44, 38, 54, STEEL)
    i.line([(50, 24), (60, 36)], 4, WOOD); i.line([(14, 44), (8, 58)], 3.6, WOOD); i.line([(44, 44), (50, 58)], 3.6, WOOD)

@icon
def hire(i):
    i.poly([(0, 28), (14, 22), (30, 44), (14, 52)], BLUE)
    i.poly([(64, 28), (50, 22), (34, 44), (50, 52)], ORANGE)
    i.ell(12, 22, 52, 54, SKIN)
    for k in range(4):
        i.line([(24 + k * 5, 24 + k * 2), (28 + k * 5, 34 + k * 2)], 2.2, (C(214, 152, 112), C(186, 120, 86)))
    i.ell(18, 34, 40, 50, SKIN); i.line([(22, 44), (36, 40)], 2, (C(214, 152, 112), C(186, 120, 86)))
    i.hl([(18, 28), (34, 24)], 1.8, 160)

@icon
def iron_ore(i):
    i.blob(18, 44, 14, 11, IRON, 7); i.blob(44, 44, 15, 12, IRON, 9); i.blob(31, 27, 15, 12, IRON, 11)
    for x, y in ((26, 30), (40, 46), (14, 44)): i.dot(x, y, 1.6, (255, 190, 150, 200))

@icon
def loader(i):
    i.rect(14, 26, 46, 48, YELLOW, 4)
    i.rect(30, 14, 44, 30, (C(150, 214, 240), C(70, 134, 190)), 3)
    i.poly([(2, 38), (20, 38), (20, 56), (2, 50)], STEEL)
    i.line([(18, 40), (32, 30)], 3.4, STEEL_D)
    i.ell(12, 42, 28, 58, DARK); i.ell(36, 42, 52, 58, DARK); i.ell(17, 47, 23, 53, STEEL); i.ell(41, 47, 47, 53, STEEL)

@icon
def milestones(i):
    i.rect(12, 4, 17, 60, STEEL, 2)
    i.poly([(17, 8), (54, 14), (44, 24), (54, 34), (17, 30)], RED)
    i.hl([(20, 11), (48, 16)], 1.6, 150)
    i.ell(9, 2, 20, 10, GOLD)

def face(i, hat, extra=None):
    i.ell(14, 22, 50, 58, SKIN)
    i.ell(22, 36, 27, 41, (C(40, 30, 40), C(40, 30, 40))); i.ell(37, 36, 42, 41, (C(40, 30, 40), C(40, 30, 40)))
    i.line([(26, 48), (38, 48)], 1.8, (C(170, 90, 80), C(170, 90, 80)))
    i.ell(14, 38, 22, 46, (C(255, 160, 140), C(255, 160, 140))) if False else None
    i.poly([(10, 28), (54, 28), (50, 14), (32, 8), (14, 14)], hat)
    i.rect(8, 26, 56, 32, hat, 2)

@icon
def miner(i):
    face(i, YELLOW); i.ell(26, 10, 38, 22, WHITE); i.dot(32, 16, 2.4, (255, 236, 150, 255))
    i.hl([(18, 18), (30, 12)], 1.6, 150)

@icon
def operator(i):
    face(i, ORANGE)
    i.rect(20, 33, 44, 43, (C(150, 214, 240), C(70, 134, 190)), 3); i.line([(32, 33), (32, 43)], 1.6, DARK)
    i.ell(6, 36, 16, 52, STEEL_D); i.ell(48, 36, 58, 52, STEEL_D)

@icon
def clerk_face(i):
    pass

@icon
def money(i):
    i.ell(4, 4, 60, 60, GOLD); i.ell(11, 11, 53, 53, GOLD_D)
    i.text('$', 32, 33, 34, (255, 247, 200, 255))
    i.hl([(12, 22), (22, 12)], 2.2, 210)

@icon
def payroll(i):
    for j in range(4):
        i.ell(6, 40 - j * 6, 34, 54 - j * 6, GOLD if j % 2 == 0 else GOLD_D)
    for j in range(3):
        i.ell(30, 46 - j * 6, 58, 60 - j * 6, GOLD if j % 2 == 0 else GOLD_D)
    i.ell(16, 8, 44, 22, GOLD); i.text('$', 30, 15, 13, (255, 244, 190, 255))
    i.hl([(10, 38), (18, 36)], 1.6, 200)

@icon
def pickaxe(i):
    i.line([(16, 56), (42, 20)], 7, WOOD)
    i.poly([(14, 22), (28, 8), (52, 10), (58, 22), (50, 20), (30, 18), (20, 28)], STEEL)
    i.poly([(30, 18), (50, 20), (58, 22), (52, 10)], STEEL_D)
    i.hl([(24, 14), (46, 14)], 1.6, 160)

@icon
def plan(i):
    i.rect(6, 10, 58, 54, BLUE, 3)
    for gx in range(14, 58, 10): i.line([(gx, 12), (gx, 52)], 0.9, (C(150, 190, 236), C(120, 160, 210)))
    for gy in range(20, 52, 9): i.line([(8, gy), (56, gy)], 0.9, (C(150, 190, 236), C(120, 160, 210)))
    for (x0, y0, x1, y1) in ((12, 16, 52, 48), (18, 22, 46, 42), (24, 28, 40, 36)):
        i.flat(lambda d, x0=x0, y0=y0, x1=x1, y1=y1: d.rectangle([x0 * SS, y0 * SS, x1 * SS, y1 * SS], outline=255, width=int(1.8 * SS)), (236, 246, 255, 255))
    i.rect(28, 30, 36, 34, YELLOW, 1)
    i.ell(46, 4, 56, 14, RED); i.dot(51, 9, 1.8, (255, 255, 255, 230))

@icon
def production(i):
    i.poly([(4, 40), (52, 24), (60, 34), (12, 54)], DARK)
    i.line([(8, 42), (54, 27)], 3.6, YELLOW)
    for k in range(5): i.ell(12 + k * 9, 40 - k * 3.4, 17 + k * 9, 46 - k * 3.4, STEEL)
    i.blob(30, 24, 10, 8, STONE, 2); i.blob(44, 20, 9, 8, STONE, 6); i.blob(20, 28, 8, 6, STONE, 9)

@icon
def skill(i):
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5; r = 28 if k % 2 == 0 else 12
        pts.append((32 + math.cos(a) * r, 34 + math.sin(a) * r))
    i.poly(pts, GOLD)
    i.hl([(26, 22), (32, 12)], 1.8, 210)

@icon
def staff(i):
    i.ell(18, 6, 46, 34, SAND); i.poly([(8, 60), (10, 42), (22, 36), (42, 36), (54, 42), (56, 60)], SAND)
    i.hl([(24, 12), (32, 9)], 1.6, 170)

@icon
def stats(i):
    i.rect(4, 52, 60, 58, WOOD, 2)
    i.rect(8, 34, 20, 52, BLUE, 2); i.rect(24, 22, 36, 52, BLUE, 2); i.rect(40, 8, 52, 52, BLUE, 2)
    i.hl([(10, 36), (10, 50)], 1.6, 150); i.hl([(26, 24), (26, 50)], 1.6, 150); i.hl([(42, 10), (42, 50)], 1.6, 150)

@icon
def stone(i):
    i.blob(18, 44, 14, 11, STONE, 12); i.blob(44, 44, 15, 12, STONE, 14); i.blob(31, 27, 15, 12, STONE, 16)

@icon
def storage(i):
    i.rect(6, 14, 58, 58, WOOD, 3)
    i.rect(6, 14, 58, 24, WOOD_L, 2)
    i.line([(10, 36), (54, 36)], 3, (C(110, 70, 40), C(110, 70, 40))); i.line([(10, 48), (54, 48)], 3, (C(110, 70, 40), C(110, 70, 40)))
    i.line([(8, 16), (56, 56)], 2.4, (C(120, 76, 42), C(120, 76, 42))); i.line([(56, 16), (8, 56)], 2.4, (C(120, 76, 42), C(120, 76, 42)))
    for x, y in ((11, 19), (53, 19), (11, 53), (53, 53)): i.dot(x, y, 1.8, (C(222, 200, 150)))

@icon
def sun(i):
    for k in range(12):
        a = k * math.tau / 12
        i.line([(32 + math.cos(a) * 20, 32 + math.sin(a) * 20), (32 + math.cos(a) * 29, 32 + math.sin(a) * 29)], 4.4, YELLOW)
    i.ell(14, 14, 50, 50, GOLD); i.hl([(22, 24), (28, 18)], 2, 220)

@icon
def truck(i):
    i.poly([(4, 20), (36, 20), (38, 44), (4, 44)], YELLOW)
    i.poly([(4, 20), (36, 20), (44, 12), (12, 12)], (C(255, 232, 130), C(238, 176, 52)))
    i.rect(38, 26, 60, 46, YELLOW, 3)
    i.rect(42, 29, 56, 38, (C(150, 214, 240), C(70, 134, 190)), 2)
    i.rect(2, 44, 60, 50, DARK, 2)
    for x in (14, 30, 50): i.ell(x - 7, 44, x + 7, 58, DARK); i.ell(x - 3, 48, x + 3, 54, STEEL)

@icon
def upgrades(i):
    i.poly([(32, 4), (58, 32), (42, 32), (42, 58), (22, 58), (22, 32), (6, 32)], GREEN)
    i.hl([(14, 30), (30, 10)], 1.8, 190)

@icon
def wages(i):
    i.ell(4, 4, 46, 46, WHITE); i.ell(8, 8, 42, 42, (C(255, 252, 244), C(240, 230, 210)))
    i.line([(25, 12), (25, 26), (34, 32)], 2.8, DARK)
    for k in range(12):
        a = k * math.tau / 12; i.dot(25 + math.cos(a) * 15, 25 + math.sin(a) * 15, 1.1, (C(120, 110, 100)))
    i.ell(30, 34, 60, 62, GOLD); i.ell(34, 38, 56, 58, GOLD_D); i.line([(45, 41), (45, 55)], 2.2, (C(255, 244, 190), C(255, 244, 190)))

@icon
def workers(i):
    i.ell(30, 18, 58, 48, SKIN); i.poly([(30, 22), (58, 22), (54, 10), (44, 6), (34, 10)], (C(196, 170, 120), C(150, 126, 84)))
    i.poly([(6, 60), (8, 46), (20, 40), (40, 40), (52, 46), (54, 60)], BLUE)
    i.ell(10, 20, 44, 52, SKIN); i.poly([(8, 30), (46, 30), (42, 16), (27, 10), (12, 16)], YELLOW)
    i.ell(18, 34, 22, 38, DARK) if False else None
    i.dot(20, 38, 2, (C(40, 30, 40))); i.dot(34, 38, 2, (C(40, 30, 40)))
    i.line([(22, 46), (32, 46)], 1.6, (C(170, 90, 80), C(170, 90, 80)))

# clerk is the clipboard (kept); the face-style 'clerk' was a clipboard in the old set too
if __name__ == '__main__':
    os.makedirs(OUT_DIR, exist_ok=True)
    only = set(sys.argv[2:])
    for name, fn in ICONS.items():
        if name == 'clerk_face':
            continue
        if only and name not in only:
            continue
        ic = Icon(); fn(ic)
        im = ic.finish()
        im.save(os.path.join(OUT_DIR, name + '.png'))
        im.resize((32, 32), Image.LANCZOS).save(os.path.join(OUT_DIR, name + '_s.png'))
    print('drew', len(ICONS) - 1, 'icons into', OUT_DIR)
