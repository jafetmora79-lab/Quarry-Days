#!/usr/bin/env python3
"""Cleans the 32x32 UI icons: drops small disconnected fragments (stray bits left over from the generated sheets), recentres each icon on its canvas,
and draws the new 'plan' (blueprint) icon in the same palette. Idempotent."""
import glob, os
from PIL import Image, ImageDraw
D = 'assets/ui/icons/'
OUT = (41, 24, 44, 255)      # the dark plum outline the other icons use

def components(px, w, h):
    seen = set(); comps = []
    for y in range(h):
        for x in range(w):
            if (x, y) in seen or px[x, y][3] < 40:
                continue
            stack = [(x, y)]; seen.add((x, y)); cur = []
            while stack:
                cx, cy = stack.pop(); cur.append((cx, cy))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and px[nx, ny][3] >= 40:
                            seen.add((nx, ny)); stack.append((nx, ny))
            comps.append(cur)
    return comps

def clean(path):
    im = Image.open(path).convert('RGBA'); w, h = im.size; px = im.load()
    comps = components(px, w, h)
    if len(comps) <= 1:
        return 0
    comps.sort(key=len, reverse=True)
    keep = comps[0]; removed = 0
    keepset = set(keep)
    for c in comps[1:]:
        if len(c) < 0.45 * len(keep):          # a fragment, not part of the picture
            for (x, y) in c:
                px[x, y] = (0, 0, 0, 0)
            removed += len(c)
    xs = [x for (x, y) in keepset]; ys = [y for (x, y) in keepset]
    # recentre what is left
    bbox = im.getbbox()
    if bbox:
        cw, ch = bbox[2] - bbox[0], bbox[3] - bbox[1]
        crop = im.crop(bbox)
        out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        out.alpha_composite(crop, ((w - cw) // 2, (h - ch) // 2))
        im = out
    im.save(path)
    return removed

def plan_icon(path):
    im = Image.new('RGBA', (32, 32), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    BLUE = (63, 96, 140, 255); BLUE_HI = (104, 146, 196, 255); LINE = (196, 220, 244, 255); WARM = (242, 196, 84, 255); WARM_D = (214, 148, 52, 255); RED = (226, 76, 56, 255)
    d.rectangle([3, 5, 28, 26], fill=OUT)                       # outline
    d.rectangle([4, 6, 27, 25], fill=BLUE)                      # the sheet
    d.rectangle([4, 6, 27, 8], fill=BLUE_HI)                    # lit top edge
    for gx in range(8, 27, 6):                                  # faint grid
        d.line([gx, 9, gx, 24], fill=(79, 114, 160, 255))
    for gy in range(12, 25, 5):
        d.line([5, gy, 26, gy], fill=(79, 114, 160, 255))
    d.rectangle([7, 10, 24, 22], outline=LINE)                  # the nested quarry levels, outermost to deepest
    d.rectangle([10, 13, 21, 19], outline=LINE)
    d.rectangle([13, 15, 18, 17], fill=WARM, outline=WARM_D)
    d.rectangle([22, 3, 25, 5], fill=OUT)                       # a pin
    d.rectangle([23, 4, 24, 4], fill=RED)
    im.save(path)

removed = {}
for f in sorted(glob.glob(D + '*.png')):
    n = clean(f)
    if n:
        removed[os.path.basename(f)] = n
plan_icon(D + 'plan.png')
print('stray pixels removed:', removed)
