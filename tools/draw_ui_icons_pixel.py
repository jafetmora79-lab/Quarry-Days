#!/usr/bin/env python3
"""Draws the UI icon set in code, as real pixel art (no generated imagery): 32 x 32 canvases, flat colours from the HUD's steel / hazard-yellow palette, then two automatic passes -
a light top edge and a dark underside on every shape, and a 1 px dark outline. Writes assets/ui/icons/<name>_s.png (32 px) and <name>.png (the same art at 2x, nearest-neighbour).

  python tools/draw_ui_icons_pixel.py
"""
import os
import math
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "ui", "icons")
N = 32
OUTLINE = (12, 14, 18, 255)


def C(r, g, b):
    return (r, g, b, 255)


STEEL, STEEL_L, STEEL_D = C(120, 134, 152), C(176, 190, 206), C(66, 76, 90)
YEL, ORG, RED, GRN, BLU = C(250, 196, 36), C(232, 128, 36), C(200, 60, 44), C(104, 172, 72), C(84, 146, 204)
STONE, COAL, IRON, GOLD = C(190, 186, 174), C(64, 68, 80), C(196, 100, 72), C(252, 208, 64)
WOOD, WOOD_D, SKIN, WHITE, DARK = C(172, 116, 66), C(112, 70, 40), C(240, 192, 152), C(244, 240, 228), C(38, 42, 50)


class Ic:
    def __init__(self):
        self.im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def rect(self, x0, y0, x1, y1, col):
        self.d.rectangle((x0, y0, x1, y1), fill=col)

    def circ(self, cx, cy, r, col):
        self.d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=col)

    def poly(self, pts, col):
        self.d.polygon(pts, fill=col)

    def line(self, x0, y0, x1, y1, col, w=1):
        self.d.line((x0, y0, x1, y1), fill=col, width=w)

    def px(self, x, y, col):
        self.d.point((x, y), fill=col)

    def finish(self):
        """Edge light, underside shade, outline."""
        src = self.im.copy()
        px = src.load()
        out = Image.new("RGBA", (N + 2, N + 2), (0, 0, 0, 0))
        po = out.load()
        for y in range(N):
            for x in range(N):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue
                up = px[x, y - 1] if y > 0 else (0, 0, 0, 0)
                dn = px[x, y + 1] if y < N - 1 else (0, 0, 0, 0)
                lf = px[x - 1, y] if x > 0 else (0, 0, 0, 0)
                col = (r, g, b)
                if up[3] == 0 or up[:3] != (r, g, b) and sum(up[:3]) < sum(col) * 0.8:
                    col = tuple(min(255, int(v * 1.0 + (255 - v) * 0.32)) for v in col)
                elif dn[3] == 0 or (dn[:3] != (r, g, b) and sum(dn[:3]) > sum(col) * 1.25):
                    col = tuple(int(v * 0.68) for v in col)
                elif lf[3] == 0:
                    col = tuple(min(255, int(v * 1.0 + (255 - v) * 0.14)) for v in col)
                po[x + 1, y + 1] = (col[0], col[1], col[2], 255)
        res = out.copy()
        pr = res.load()
        for y in range(N + 2):
            for x in range(N + 2):
                if po[x, y][3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        xx, yy = x + dx, y + dy
                        if 0 <= xx < N + 2 and 0 <= yy < N + 2 and po[xx, yy][3] > 0:
                            pr[x, y] = OUTLINE
                            break
        return res.crop((1, 1, N + 1, N + 1)) if False else res.resize((N + 2, N + 2)).crop((0, 0, N, N)) if False else res.crop((1, 1, N + 1, N + 1))


def person(ic, cx, y, hat=YEL, body=BLU, face=SKIN):
    ic.rect(cx - 5, y + 11, cx + 5, y + 19, body)                  # shoulders
    ic.circ(cx, y + 6, 5, face)
    ic.rect(cx - 5, y + 2, cx + 5, y + 4, hat)                    # hard hat
    ic.rect(cx - 6, y + 4, cx + 6, y + 5, hat)
    ic.px(cx - 2, y + 7, DARK)
    ic.px(cx + 2, y + 7, DARK)


def gear(ic, cx, cy, r, col, hole=True):
    for k in range(8):
        a = k * math.pi / 4
        ic.circ(round(cx + math.cos(a) * (r + 1)), round(cy + math.sin(a) * (r + 1)), 2, col)
    ic.circ(cx, cy, r, col)
    if hole:
        ic.circ(cx, cy, max(2, r // 3), DARK)


def chunk(ic, col, dark, pts=None):
    ic.poly(pts or [(5, 20), (9, 9), (17, 5), (25, 10), (28, 19), (22, 27), (11, 27)], col)
    ic.poly([(9, 9), (17, 5), (16, 14), (10, 17)], tuple(min(255, int(v * 1.2)) for v in col[:3]) + (255,))
    ic.poly([(16, 14), (25, 10), (28, 19), (20, 20)], col)
    ic.poly([(11, 27), (22, 27), (28, 19), (20, 20)], dark)


def build():
    ic = {}

    def new(name):
        i = Ic()
        ic[name] = i
        return i

    i = new("workers"); person(i, 10, 4, YEL, BLU); person(i, 21, 8, ORG, GRN)
    i = new("hire"); person(i, 12, 4, YEL, BLU); i.rect(19, 19, 30, 21, GRN); i.rect(23, 15, 25, 25, GRN)
    i = new("payroll"); i.rect(3, 9, 28, 22, GRN); i.rect(5, 11, 26, 20, C(150, 206, 110)); i.circ(15, 15, 4, GRN); i.rect(15, 12, 16, 18, DARK); i.rect(2, 22, 29, 24, C(70, 120, 50))
    i = new("production"); gear(i, 16, 15, 8, STEEL); i.rect(6, 25, 26, 28, YEL)
    i = new("equipment"); i.line(8, 24, 21, 11, STEEL, 4); i.circ(23, 9, 6, STEEL); i.rect(21, 3, 25, 8, DARK); i.circ(7, 25, 3, STEEL_D)
    i = new("upgrades"); i.rect(4, 4, 27, 27, STEEL_D); i.poly([(16, 6), (26, 17), (20, 17), (20, 26), (12, 26), (12, 17), (6, 17)], GRN)
    i = new("milestones"); i.rect(6, 3, 8, 29, STEEL_L); i.poly([(9, 4), (27, 4), (22, 11), (27, 18), (9, 18)], RED); i.rect(3, 28, 12, 29, STEEL)
    i = new("stats"); i.rect(4, 4, 6, 27, STEEL); i.rect(4, 26, 28, 28, STEEL); i.rect(9, 17, 13, 25, ORG); i.rect(15, 11, 19, 25, YEL); i.rect(21, 6, 25, 25, GRN)
    i = new("miner"); person(i, 14, 3, YEL, BLU); i.line(24, 8, 26, 27, WOOD, 3); i.poly([(18, 6), (30, 8), (30, 11), (18, 9)], STEEL)
    i = new("operator"); person(i, 13, 3, YEL, ORG); i.circ(25, 22, 5, STEEL_D); i.circ(25, 22, 2, DARK); i.line(20, 22, 30, 22, STEEL, 1)
    i = new("hauler"); person(i, 12, 3, C(120, 150, 90), BLU); i.rect(18, 16, 30, 27, WOOD); i.rect(18, 20, 30, 21, WOOD_D)
    i = new("clerk"); person(i, 12, 3, C(90, 98, 112), WHITE); i.rect(11, 14, 13, 22, RED); i.rect(20, 14, 30, 27, WHITE); i.line(22, 18, 28, 18, STEEL, 1); i.line(22, 21, 28, 21, STEEL, 1)
    i = new("money"); i.circ(16, 16, 12, GOLD); i.circ(16, 16, 9, C(236, 172, 36)); i.rect(15, 7, 16, 9, DARK); i.rect(15, 23, 16, 25, DARK); i.rect(12, 10, 20, 11, DARK); i.rect(12, 10, 13, 15, DARK); i.rect(12, 15, 20, 16, DARK); i.rect(19, 16, 20, 21, DARK); i.rect(12, 21, 20, 22, DARK)
    i = new("staff"); person(i, 8, 6, YEL, BLU); person(i, 16, 2, ORG, GRN); person(i, 24, 6, YEL, STEEL)
    i = new("wages"); i.circ(11, 20, 7, GOLD); i.circ(21, 15, 7, GOLD); i.rect(20, 11, 22, 19, DARK); i.rect(10, 16, 12, 24, DARK)
    i = new("skill"); i.poly([(16, 3), (20, 12), (30, 12), (22, 18), (25, 28), (16, 22), (7, 28), (10, 18), (2, 12), (12, 12)], YEL)
    i = new("sun"); i.circ(16, 16, 7, YEL)
    for k in range(8):
        a = k * math.pi / 4
        i.line(round(16 + math.cos(a) * 6), round(16 + math.sin(a) * 6), round(16 + math.cos(a) * 14), round(16 + math.sin(a) * 14), ORG, 2)
    i = new("storage"); i.rect(3, 8, 28, 27, WOOD); i.rect(3, 8, 28, 12, WOOD_D); i.rect(14, 8, 17, 27, STEEL_D); i.rect(3, 17, 28, 18, WOOD_D); i.circ(15, 17, 2, STEEL_L)
    i = new("crusher"); i.poly([(3, 4), (29, 4), (22, 14), (10, 14)], STEEL); i.rect(8, 14, 24, 25, STEEL_D); i.rect(4, 25, 28, 28, DARK); i.circ(16, 20, 3, YEL); i.circ(9, 3, 2, STONE); i.circ(18, 2, 2, STONE)
    i = new("conveyor"); i.rect(2, 16, 29, 22, STEEL_D); i.circ(5, 19, 4, STEEL); i.circ(26, 19, 4, STEEL); i.rect(8, 14, 23, 15, DARK); i.poly([(12, 14), (15, 9), (20, 10), (21, 14)], STONE); i.rect(4, 24, 6, 28, STEEL); i.rect(25, 24, 27, 28, STEEL)
    i = new("drill_rig"); i.rect(4, 26, 28, 29, DARK); i.rect(14, 4, 18, 25, STEEL); i.line(12, 24, 20, 6, STEEL_L, 1); i.poly([(13, 25), (19, 25), (16, 31)], YEL); i.rect(8, 4, 24, 7, ORG)
    i = new("excavator"); i.rect(3, 24, 20, 29, DARK); i.rect(4, 14, 19, 24, YEL); i.rect(5, 10, 12, 14, STEEL_L); i.line(14, 14, 23, 5, YEL, 3); i.line(23, 5, 28, 14, YEL, 3); i.poly([(26, 13), (31, 13), (30, 19), (24, 19)], STEEL)
    i = new("loader"); i.rect(8, 12, 24, 22, YEL); i.rect(10, 6, 18, 12, STEEL_L); i.circ(10, 25, 4, DARK); i.circ(22, 25, 4, DARK); i.poly([(24, 14), (31, 12), (31, 22), (24, 22)], STEEL)
    i = new("truck"); i.rect(2, 10, 20, 21, STEEL); i.poly([(20, 14), (28, 14), (30, 21), (20, 21)], YEL); i.rect(22, 15, 26, 18, STEEL_L); i.circ(8, 24, 4, DARK); i.circ(24, 24, 4, DARK)
    i = new("pickaxe"); i.line(7, 27, 23, 9, WOOD, 3); i.poly([(8, 8), (14, 4), (26, 5), (29, 9), (24, 8), (16, 8), (11, 12)], STEEL)
    i = new("hammer"); i.line(8, 28, 21, 11, WOOD, 3); i.rect(14, 4, 29, 11, STEEL); i.rect(14, 4, 29, 6, STEEL_L)
    i = new("chisel"); i.rect(12, 3, 18, 8, STEEL_D); i.rect(13, 8, 17, 22, STEEL); i.poly([(13, 22), (17, 22), (15, 29)], STEEL_L)
    i = new("bag"); i.poly([(5, 10), (27, 10), (29, 27), (3, 27)], WOOD); i.poly([(5, 10), (27, 10), (24, 17), (8, 17)], WOOD_D); i.rect(14, 14, 18, 20, YEL); i.rect(9, 4, 23, 7, WOOD_D)
    i = new("stone"); chunk(i, STONE, C(120, 116, 106))
    i = new("coal"); chunk(i, C(78, 82, 96), C(30, 32, 40))
    i = new("iron_ore"); chunk(i, IRON, C(120, 56, 40)); i.px(12, 16, STEEL_L); i.px(21, 14, STEEL_L); i.px(17, 22, STEEL_L)
    i = new("gold"); i.poly([(4, 26), (8, 14), (15, 10), (21, 15), (24, 26)], GOLD); i.poly([(14, 26), (18, 17), (25, 14), (30, 20), (28, 26)], C(236, 176, 40)); i.px(10, 17, WHITE); i.px(22, 17, WHITE)
    i = new("plan"); i.poly([(3, 26), (29, 26), (29, 14)], STEEL); i.poly([(3, 26), (29, 14), (22, 10), (3, 18)], YEL); i.line(8, 22, 24, 22, DARK, 1)
    return ic


def main():
    os.makedirs(OUT, exist_ok=True)
    icons = build()
    for name, ic in icons.items():
        im = ic.finish()
        im.save(os.path.join(OUT, name + "_s.png"))
        im.resize((N * 2, N * 2), Image.NEAREST).save(os.path.join(OUT, name + ".png"))
    print("wrote", len(icons), "icons")


if __name__ == "__main__":
    main()
