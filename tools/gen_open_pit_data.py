#!/usr/bin/env python3
"""Phase 8.7: writes the open-pit layout (pit zone, four quarry levels, stratified formations) into data/progression.json.
All numbers are metres in the pit frame (x across, -z = away from the gate)."""
import json, math
P = 'data/progression.json'
d = json.load(open(P))
CELL = 3.0

pz = d['pit_zone']
pz.update({"plateau_width": 160.0, "plateau_depth": 156.0, "basin_width": 128.0, "basin_depth": 120.0, "basin_floor": -3.6,
           "ramp_width": 8.0, "ramp_run": 20.0, "wall_height": 4.0})
pz["_comment"] = "Phase 8.7: a 160 x 156 m plateau (rim at 0) with the 128 x 120 m starting basin (floor -3.6). Four working levels are cut into the basin floor as nested terraced pits (see quarry_levels)."

def tiers(cols, rows, n=3):
    return [[n] * cols for _ in range(rows)]

def grid(x0, x1, z0, z1):
    cols = round((x1 - x0) / CELL)
    rows = round((z1 - z0) / CELL)
    assert abs(cols * CELL - (x1 - x0)) < 1e-6 and abs(rows * CELL - (z1 - z0)) < 1e-6, (x0, x1, z0, z1)
    return cols, rows, [(x0 + x1) / 2, (z0 + z1) / 2]

F = d['formations']
legacy = {"bench_l2_coal": {"columns": 35, "dims": [7, 5], "units": 7350}, "bench_l2_iron": {"columns": 28, "dims": [7, 4], "units": 5880},
          "bench_l3_iron": {"columns": 12, "dims": [3, 4], "units": 2520}, "bench_l3_copper": {"columns": 9, "dims": [3, 3], "units": 1890},
          "bench_l4_copper": {"columns": 8, "dims": [2, 4], "units": 1440}, "bench_l4_gold": {"columns": 6, "dims": [2, 3], "units": 1080}}  # the Phase 8.6 layouts
def put(fid, title, res, level, x0, x1, z0, z1, y, cu, cover=None, closed=None, pads=None, hard=None):
    cols, rows, c = grid(x0, x1, z0, z1)
    f = {"title": title, "resource": res, "frame": "pit", "layout": "grid", "center": [c[0], y, c[1]], "cell": CELL, "tier_h": 1.2,
         "chunk_units": cu, "level": 1, "quarry_level": level, "style": "cut", "skin": True, "strict": True, "requires_cleanup": True,
         "tiers": tiers(cols, rows)}
    if cover: f["cover"] = cover
    if closed: f["closed"] = closed
    if pads: f["pads"] = pads
    F[fid] = f

# level 2 rock: 15 x 27 cells; coal in the south, iron in the north
put('bench_l2_coal', 'Coal Bench', 'coal', 2, -50, -5, -108, -69, -7.2, 13, closed=["N"],
    pads=[[-2.0, -3.6, -75.0, 1.5708], [-2.0, -3.6, -81.0, 1.5708], [-2.0, -3.6, -87.0, 1.5708]])
put('bench_l2_iron', 'Iron Bench', 'iron_ore', 2, -50, -5, -150, -108, -7.2, 9, closed=["S"],
    pads=[[-2.0, -3.6, -114.0, 1.5708], [-2.0, -3.6, -120.0, 1.5708], [-2.0, -3.6, -126.0, 1.5708]])
l2 = ["bench_l2_coal", "bench_l2_iron"]
put('bench_l3_iron', 'Deep Iron Bench', 'iron_ore', 3, -44, -20, -111, -87, -10.8, 13, cover=l2, closed=["N"])
put('bench_l3_copper', 'Copper Bench', 'copper_ore', 3, -44, -20, -135, -111, -10.8, 10, cover=l2, closed=["S"])
l3 = ["bench_l3_iron", "bench_l3_copper"]
put('bench_l4_copper', 'Deep Copper Bench', 'copper_ore', 4, -32, -20, -114, -96, -14.4, 20, cover=l3, closed=["N"])
put('bench_l4_gold', 'Gold Bench', 'gold_ore', 4, -32, -20, -135, -114, -14.4, 13, cover=l3, closed=["S"])

# the L1 basin band moves to the east half of the big basin (same 16 x 6 columns: saves keep them as they are)
F['pit_band_01']['center'] = [34.0, -3.6, -122.0]

d['legacy_formations'] = legacy
d['legacy_formations_comment'] = "Phase 8.7 save migration: the old column layout of each re-laid formation (column count and total units). Saves written with that layout are converted by cleared fraction, never reset."

# fossil: two columns in the middle row of the gold bench (4 x 7 cells)
d['fossil']['columns'] = [13, 14]

ql = d['quarry_levels']
def lvl(n, rect, rw, side, top, run, yt, roads, note=""):
    L = ql[n - 1]
    L['pit'] = {"rect": rect, "ramp_w": rw, "side": side, "ramp_top": top, "ramp_run": run, "y_top": yt}
    L['roads'] = roads
lvl(2, [-59, -150, -5, -69], 9, "W", "south", 21, -3.6, [[-50, -150, -5, -135], [-20, -135, -11, -87]])
lvl(3, [-44, -135, -11, -87], 9, "E", "north", 21, -7.2, [[-44, -102, -20, -87], [-41, -135, -32, -96]])
lvl(4, [-41, -135, -20, -96], 9, "W", "south", 21, -10.8, [])
ql[0]['_comment'] = ql[0].get('_comment', '') + " Phase 8.7: pit = rect [x0,z0,x1,z1] with a haul-road strip of ramp_w on `side` (W/E): the ramp starts at the `ramp_top` end (south/north) and falls ramp_run metres to the level floor, the rest of the strip is flat road. `roads` = rects of this level's own rock that are cut away the moment the level opens, so the haul road is never blocked."
json.dump(d, open(P, 'w'), indent=1)
print(json.dumps(legacy))
