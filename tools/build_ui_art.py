#!/usr/bin/env python3
"""Slices the generated icon and portrait sheets (tools/ui_art_src/) into game-ready, palette-reduced pixel art.

  python3 tools/build_ui_art.py      ->  assets/ui/icons/<name>.png (32 px) and assets/ui/portraits/p<N>.png (64 px)

Icons are on magenta: the background is removed by flood fill from the cell border. Portraits are on near-white. Both are shrunk with a box
filter, reduced to a small adaptive palette with no dithering (so they stay chunky like the rest of the UI) and given a hard alpha edge.
"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "ui_art_src")
OUT = os.path.join(ROOT, "assets", "ui")

ICON_NAMES = ["workers", "hire", "payroll", "production", "equipment", "upgrades", "milestones", "stats",
              "miner", "operator", "hauler", "clerk", "money", "staff", "wages", "skill",
              "sun", "storage", "crusher", "conveyor", "drill_rig", "excavator", "loader", "truck",
              "pickaxe", "hammer", "chisel", "bag", "stone", "coal", "iron_ore", "gold"]


def flood_bg(a, is_bg):
    h, w = is_bg.shape
    seen = np.zeros_like(is_bg)
    stack = [(0, x) for x in range(w)] + [(h - 1, x) for x in range(w)] + [(y, 0) for y in range(h)] + [(y, w - 1) for y in range(h)]
    while stack:
        y, x = stack.pop()
        if y < 0 or x < 0 or y >= h or x >= w or seen[y, x] or not is_bg[y, x]:
            continue
        seen[y, x] = True
        stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    return seen


def cut(sheet, cols, rows, bg):
    im = sheet.convert("RGB")
    W, H = im.size
    cw, ch = W / cols, H / rows
    out = []
    for r in range(rows):
        for c in range(cols):
            cell = im.crop((int(c * cw), int(r * ch), int((c + 1) * cw), int((r + 1) * ch)))
            a = np.array(cell).astype(int)
            if bg == "magenta":
                is_bg = (a[:, :, 0] > 170) & (a[:, :, 2] > 170) & (a[:, :, 1] < 110)
            else:
                is_bg = (a.min(axis=2) > 228) & ((a.max(axis=2) - a.min(axis=2)) < 14)
            seen = flood_bg(a, is_bg)
            fg = ~seen
            # keep the artwork, drop slivers of the neighbouring cell that the grid slice cut through
            labels = np.zeros(fg.shape, dtype=np.int32)
            sizes = {}
            n = 0
            for y0 in range(fg.shape[0]):
                for x0 in range(fg.shape[1]):
                    if fg[y0, x0] and labels[y0, x0] == 0:
                        n += 1
                        st = [(y0, x0)]
                        labels[y0, x0] = n
                        cnt = 0
                        while st:
                            y, x = st.pop()
                            cnt += 1
                            for dy in (-1, 0, 1):
                                for dx in (-1, 0, 1):
                                    yy, xx = y + dy, x + dx
                                    if 0 <= yy < fg.shape[0] and 0 <= xx < fg.shape[1] and fg[yy, xx] and labels[yy, xx] == 0:
                                        labels[yy, xx] = n
                                        st.append((yy, xx))
                        sizes[n] = cnt
            big = max(sizes.values())
            keep = np.zeros(fg.shape, dtype=bool)
            for k, v in sizes.items():
                if v >= big * 0.12:
                    keep |= labels == k
            seen = ~keep
            rgba = np.dstack([a.astype(np.uint8), np.where(seen, 0, 255).astype(np.uint8)])
            p = Image.fromarray(rgba, "RGBA")
            bb = p.getbbox()
            p = p.crop(bb)
            s = max(p.size)
            sq = Image.new("RGBA", (s, s), (0, 0, 0, 0))
            sq.paste(p, ((s - p.width) // 2, (s - p.height) if bg != "magenta" else (s - p.height) // 2))
            out.append(sq)
    return out


def shrink(p, n, colors):
    q = p.resize((n, n), Image.BOX)
    alpha = q.getchannel("A").point(lambda v: 255 if v > 110 else 0)
    rgb = q.convert("RGB").quantize(colors, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")
    r = rgb.convert("RGBA")
    r.putalpha(alpha)
    return r


def main():
    os.makedirs(os.path.join(OUT, "icons"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "portraits"), exist_ok=True)
    icons = cut(Image.open(os.path.join(SRC, "icons_sheet.webp")), 8, 4, "magenta")
    for name, p in zip(ICON_NAMES, icons):
        shrink(p, 32, 20).save(os.path.join(OUT, "icons", name + ".png"))
    ports = cut(Image.open(os.path.join(SRC, "portraits_sheet.webp")), 6, 2, "white")
    for i, p in enumerate(ports):
        shrink(p, 64, 24).save(os.path.join(OUT, "portraits", "p%d.png" % i))
    print("icons:", len(icons), "portraits:", len(ports))


if __name__ == "__main__":
    main()
