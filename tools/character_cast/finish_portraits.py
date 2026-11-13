"""Finish the raw 64 px renders into UI portraits: limited palette, 1 px dark outline, hard alpha (Pillow).

    python tools/character_cast/finish_portraits.py <raw_dir>   -> assets/ui/portraits/named/<id>.png
"""
import os, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "ui", "portraits", "named")
RAW = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
for f in sorted(os.listdir(RAW)):
    if not f.endswith(".png"): continue
    im = Image.open(os.path.join(RAW, f)).convert("RGBA")
    a = im.getchannel("A").point(lambda v: 255 if v > 110 else 0)
    rgb = im.convert("RGB").quantize(colors=28, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    out = Image.new("RGBA", im.size, (0, 0, 0, 0)); out.paste(rgb, (0, 0), a)
    W, H = im.size; src = out.load(); res = out.copy(); dst = res.load()
    for y in range(H):
        for x in range(W):
            if src[x, y][3]: continue
            if any(0 <= x + dx < W and 0 <= y + dy < H and src[x + dx, y + dy][3] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                dst[x, y] = (26, 20, 22, 255)
    res.save(os.path.join(OUT, f))
print("FINISHED", len(os.listdir(OUT)), OUT)
