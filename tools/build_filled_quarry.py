#!/usr/bin/env python3
"""Builds the BLUEPRINT quarry into data/progression.json (idempotent). Pit-local frame: origin at the yard's central fence gate (world 0, -8),
local -z is north (into the quarry), x east, y up; surface 0.
 quarry fence    x -126..126, z -100..0      (252 x 100 m, 2.5 : 1)
 Area 1 (blue)   x -122..122, z  -96..-4     topsoil surface (the tutorial and the overburden); the pit zone's "basin" (floor -1.2)
 Area 2          x -110..110, z  -92..-28    level 2: gravel + limestone, floor -4.8
 Area 3          x  -98.. 98, z  -84..-36    level 3: coal + iron, floor -8.4
 Area 4          x  -86.. 86, z  -76..-44    level 4: iron + copper, floor -12.0
 Area 5          x  -74.. 74, z  -68..-52    level 5: copper + gold, floor -14.4 (2 tiers)
Everything is on a 4 m cell grid. Rock stays flush and covered until the player digs it; access ramps and roads are built (and paid for)
from the office (progression.buy_road)."""
import json
P = 'data/progression.json'
d = json.load(open(P))
CELL = 4.0
TH = 1.2
RW = 8.0
A1 = (-122, -96, 122, -4)
LV = {
    2: dict(rect=(-110, -92, 110, -28), strip='W', top='south', y_top=-1.2, floor=-4.8, run=21),
    3: dict(rect=(-98, -84, 98, -36), strip='E', top='north', y_top=-4.8, floor=-8.4, run=21),
    4: dict(rect=(-86, -76, 86, -44), strip='W', top='south', y_top=-8.4, floor=-12.0, run=21),
    5: dict(rect=(-74, -68, 74, -52), strip='E', top='north', y_top=-12.0, floor=-14.4, run=12),
}
def strip(L):
    x0, z0, x1, z1 = L['rect']
    return (x0, z0, x0 + RW, z1) if L['strip'] == 'W' else (x1 - RW, z0, x1, z1)
def cols(L):
    x0, z0, x1, z1 = L['rect']
    return (x0 + RW, z0, x1, z1) if L['strip'] == 'W' else (x0, z0, x1 - RW, z1)
# access that is cut (and paid for) when a level's road is built; rock cut this way is simply gone
ROADS = {
    2: [(-4, -12, 4, -4), (-106, -28, 12, -12), strip(LV[2]), (-102, -92, 98, -84), (74, -92, 98, -80)],
    3: [strip(LV[3]), (-86, -44, 98, -36), (74, -48, 98, -36), (-90, -48, -74, -36)],
    4: [strip(LV[4]), (-78, -76, 74, -68), (-86, -76, -62, -64), (50, -76, 74, -64)],
    5: [strip(LV[5])],
}
ROAD_COST = {2: 400, 3: 1500, 4: 5000, 5: 14000}

def grid(rect, tiers):
    x0, z0, x1, z1 = rect
    nx = int(round((x1 - x0) / CELL)); nz = int(round((z1 - z0) / CELL))
    return [[tiers for _ in range(nx)] for _ in range(nz)]

def formation(title, res, rect, base_y, tiers, units, qlevel, cover=None, extra=None):
    f = dict(title=title, resource=res, frame='pit', layout='grid',
             center=[(rect[0] + rect[2]) / 2, base_y, (rect[1] + rect[3]) / 2], cell=CELL, tier_h=TH, chunk_units=units,
             level=1, quarry_level=qlevel, style='cut', skin=True, strict=False, requires_cleanup=True, world='filled', closed=[],
             tiers=grid(rect, tiers))
    if cover: f['cover'] = cover
    if extra: f.update(extra)
    return f

def split_z(L, z):
    x0, z0, x1, z1 = cols(L); return (x0, z0, x1, z), (x0, z, x1, z1)
def split_x(L, x):
    x0, z0, x1, z1 = cols(L); return (x0, z0, x, z1), (x, z0, x1, z1)

F = {}
F['q_top'] = formation('Topsoil and Overburden', 'topsoil', A1, -1.2, 1, 5, 1, extra=dict(no_label=True, decor=dict(seed=7, density=0.2)))
L2c = cols(LV[2])
F['q_a2_gravel'] = formation('Gravel and Compacted Soil', 'gravel', L2c, -2.4, 1, 8, 2, cover=['q_top'], extra=dict(no_label=True))
F['q_a2_rock'] = formation('Limestone Bench', 'limestone', L2c, -4.8, 2, 14, 2, cover=['q_a2_gravel', 'q_top'],
                           extra=dict(veins=dict(seed=21, count=24, mix=['coal', 'coal', 'iron_ore']),
                                      pads=[[-30.0, -1.2, -24.5, 0.0], [-18.0, -1.2, -24.5, 0.0], [-6.0, -1.2, -24.5, 0.0]]))
C2 = ['q_a2_rock', 'q_a2_gravel', 'q_top']
n3, s3 = split_z(LV[3], -60)
F['q_a3_iron'] = formation('Iron Bench', 'iron_ore', n3, -8.4, 3, 9, 3, cover=C2, extra=dict(veins=dict(seed=31, count=14, mix=['iron_ore', 'coal']),
                           pads=[[-20.0, -4.8, -88.5, 3.1416], [-10.0, -4.8, -88.5, 3.1416], [0.0, -4.8, -88.5, 3.1416]]))
F['q_a3_coal'] = formation('Coal Bench', 'coal', s3, -8.4, 3, 13, 3, cover=C2, extra=dict(veins=dict(seed=32, count=14, mix=['coal', 'iron_ore'])))
C3 = ['q_a3_iron', 'q_a3_coal'] + C2
n4, s4 = split_z(LV[4], -60)
F['q_a4_iron'] = formation('Deep Iron Bench', 'iron_ore', n4, -12.0, 3, 13, 4, cover=C3, extra=dict(veins=dict(seed=41, count=10, mix=['iron_ore', 'copper_ore'])))
F['q_a4_copper'] = formation('Deep Copper Bench', 'copper_ore', s4, -12.0, 3, 16, 4, cover=C3,
                             extra=dict(pads=[[-30.0, -8.4, -40.5, 0.0], [-20.0, -8.4, -40.5, 0.0], [-10.0, -8.4, -40.5, 0.0]]))
C4 = ['q_a4_iron', 'q_a4_copper'] + C3
w5, e5 = split_x(LV[5], -6)
F['q_a5_copper'] = formation('Deep Copper Seam', 'copper_ore', w5, -14.4, 2, 20, 5, cover=C4, extra=dict(veins=dict(seed=51, count=8, mix=['copper_ore', 'gold_ore']),
                             pads=[[-40.0, -12.0, -72.5, 3.1416], [-30.0, -12.0, -72.5, 3.1416]]))
F['q_a5_gold'] = formation('Gold Bench', 'gold_ore', e5, -14.4, 2, 13, 5, cover=C4)

def level(n, id_, title, floor_y, mats, forms, unlock, gate=None):
    lv = dict(id=id_, title=title, floor_y=floor_y, materials=mats, formations=forms, built=True, unlock=unlock)
    if gate: lv['gate'] = gate
    if n >= 2:
        L = LV[n]; x0, z0, x1, z1 = L['rect']
        lv['pit'] = dict(rect=[x0, z0, x1, z1], ramp_w=RW, side=L['strip'], ramp_top=L['top'], ramp_run=L['run'], y_top=L['y_top'])
        lv['roads'] = [list(r) for r in ROADS[n]]
        lv['road_cost'] = ROAD_COST[n]
    return lv
LEVELS = [
    level(1, 'surface', 'Surface Preparation', -1.2, ['topsoil'], ['q_top'], 0.0, gate=['q_top']),
    level(2, 'bench', 'First Limestone Bench', -4.8, ['gravel', 'limestone'], ['q_a2_gravel', 'q_a2_rock'], 0.06, gate=['q_a2_rock']),
    level(3, 'deep', 'Coal and Iron', -8.4, ['coal', 'iron_ore'], ['q_a3_coal', 'q_a3_iron'], 0.30, gate=['q_a3_coal', 'q_a3_iron']),
    level(4, 'lower', 'Industrial Bench', -12.0, ['iron_ore', 'copper_ore'], ['q_a4_iron', 'q_a4_copper'], 0.30, gate=['q_a4_iron', 'q_a4_copper']),
    level(5, 'final', 'Deep Excavation', -14.4, ['copper_ore', 'gold_ore'], ['q_a5_copper', 'q_a5_gold'], 0.30),
]
d['quarry_levels_filled'] = LEVELS
for k in list(d['formations'].keys()):
    if k.startswith('q_l'):
        del d['formations'][k]
for k, v in F.items():
    d['formations'][k] = v
for k in ('bench_l2_coal', 'bench_l2_iron', 'bench_l3_iron', 'bench_l3_copper', 'bench_l4_copper', 'bench_l4_gold', 'pit_band_01', 'hillside_face_01'):
    d['formations'][k]['world'] = 'legacy'
d['materials']['topsoil'] = dict(hp=10, hardness=0)
d['materials']['gravel'] = dict(hp=16, hardness=0)
d['display_names']['topsoil'] = 'Topsoil'
d['display_names']['gravel'] = 'Pit Gravel'
d['pit_zone_filled'] = {"_comment": "The blueprint quarry: frame at the yard's central gate (world 0, -8) facing north; 252 x 100 m fenced rectangle directly attached to the yard.",
    "angle_deg": 270.0, "gate_radius": 8.0, "corridor_length": 0.0, "corridor_width": 8.0, "plateau_width": 400.0, "plateau_depth": 100.0,
    "basin_width": 244.0, "basin_depth": 92.0, "basin_floor": -1.2, "ramp_width": 8.0, "ramp_run": 8.0, "wall_height": 4.0, "build_margin": 3.0,
    "fence": [-126.0, -100.0, 126.0, 0.0]}
# contracts for the blueprint's five areas (area 5 = the deepest zone, split into its copper and gold halves for contracts 5 and 6)
old = {a['id']: a for a in d['areas']}
def area(id_, title, forms, req, contract, reward, **kw):
    a = dict(id=id_, title=title, formations=forms, status='active', requires=req, contract=contract, reward=reward)
    a.update(kw); return a
d['areas_filled'] = [
    area('area_1', 'AREA 1 - SURFACE PREPARATION', ['q_top'], [], {"rock": 60, "soil_removed": 48, "soil_hauled": 24, "debris": "all"}, 300, rect=[-122.0, -104.0, 122.0, -12.0], entrance=[0.0, 0.0, -12.0]),
    area('area_2', 'AREA 2 - FIRST LIMESTONE BENCH', ['q_a2_gravel', 'q_a2_rock'], ['area_1'], {"rock": 200, "recovered": 150, "visit": 1}, 800, frame='pit', level=2),
    area('area_3', 'AREA 3 - COAL AND IRON', ['q_a3_coal', 'q_a3_iron'], ['area_2'], {"rock": 150, "recovered": 100, "visit": 1}, 1600, frame='pit', level=3),
    area('area_4', 'AREA 4 - INDUSTRIAL BENCH', ['q_a4_iron', 'q_a4_copper'], ['area_3'], {"rock": 200, "recovered": 150, "shipped": 80, "visit": 1}, 6000, frame='pit', level=4),
    area('area_5', 'AREA 5 - DEEP COPPER', ['q_a5_copper'], ['area_4'], {"rock": 150, "recovered": 100, "shipped": 60, "visit": 1}, 15000, frame='pit', level=5, x_range=[-74.0, -6.0]),
    area('area_6', 'AREA 5 - FINAL GOLD CUT', ['q_a5_gold'], ['area_5'], {"rock": 120, "recovered": 80, "shipped": 40, "visit": 1}, 40000, frame='pit', level=5, x_range=[-6.0, 74.0]),
]
fz = dict(d['fossil']); fz['formation'] = 'q_a5_gold'; fz['columns'] = [16, 17]
d['fossil_filled'] = fz
json.dump(d, open(P, 'w'), indent=1)
print({k: sum(sum(1 for t in row if t) for row in f['tiers']) for k, f in F.items()})
