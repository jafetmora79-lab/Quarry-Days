#!/usr/bin/env python3
"""Adds the FILLED quarry to data/progression.json (idempotent): a level-1 volume of three stacked layers that fills the whole 144 x 120 m
basin flush with the plateau, and levels 2-4 as centred, nested, 4 m-cell benches under it, with the strips, roads and vertical shafts that
connect them. Old (legacy) pit data stays and is used only by the legacy layout. Everything is in the pit frame (x east, z north is -z)."""
import json, sys
P = 'data/progression.json'
d = json.load(open(P))
CELL = 4.0
TH = 1.2

# ---------------------------------------------------------------- geometry (all multiples of 4 m)
BASIN = (-72, -168, 72, -48)
RAMP = (-4, -68, 4, -48)                       # the basin ramp slot (x 0, 8 m wide)
LANE = (-52, -80, 12, -68)                     # trench lane at the ramp foot: staging and turning space, joins the level-2 road head
L2 = dict(rect=(-52, -152, 52, -80), strip='W', top='south', y_top=-3.6, floor=-7.2)
L3 = dict(rect=(-36, -140, 44, -92), strip='E', top='north', y_top=-7.2, floor=-10.8)
L4 = dict(rect=(-28, -128, 28, -100), strip='W', top='south', y_top=-10.8, floor=-14.4)
RW = 8.0
def strip(L):
    x0, z0, x1, z1 = L['rect']
    return (x0, z0, x0 + RW, z1) if L['strip'] == 'W' else (x1 - RW, z0, x1, z1)
def cols(L):
    x0, z0, x1, z1 = L['rect']
    return (x0 + RW, z0, x1, z1) if L['strip'] == 'W' else (x0, z0, x1 - RW, z1)
ROAD_A = (-44, -152, 44, -144)                 # level-2 floor road along the north terrace
ROAD_B = (36, -144, 44, -140)                  # ... to the head of the level-3 ramp
ROAD_C = (-28, -100, 44, -92)                  # level-3 floor road along the south terrace to the level-4 ramp head
BAY_A = (16, -152, 44, -140)                   # turning bay at the level-3 ramp head (a 3 m, 5.6 m truck swings wide there)
BAY_C1 = (20, -104, 44, -92)                   # turning bay where the level-3 ramp meets its south road
BAY_C2 = (-36, -104, -28, -92)                 # turning bay west of the level-4 ramp head
strips = {2: strip(L2), 3: strip(L3), 4: strip(L4)}
# What is cut away automatically when a level opens (progression.open_roads, in the formations of that level AND every shallower one): the
# level's haul-road strip and its floor roads. Rock cut this way is simply gone and pays nothing; the bulk of every level is dug by the player.
roads = {2: [strips[2], ROAD_A, ROAD_B, BAY_A], 3: [strips[3], ROAD_C, BAY_C1, BAY_C2], 4: [strips[4]]}
# Only the entrance (the basin ramp and the staging lane at its foot) is open from the start; everything else starts as solid, layered rock.
def shafts(k):
    return [RAMP, LANE] if k <= 1 else []

def overlap_frac(cell, r):
    ax0, az0, ax1, az1 = cell
    ox = max(0.0, min(ax1, r[2]) - max(ax0, r[0]))
    oz = max(0.0, min(az1, r[3]) - max(az0, r[1]))
    return (ox * oz) / ((ax1 - ax0) * (az1 - az0))

def grid(rect, tiers, ex):
    x0, z0, x1, z1 = rect
    nx = int(round((x1 - x0) / CELL)); nz = int(round((z1 - z0) / CELL))
    rows = []
    for j in range(nz):
        row = []
        for i in range(nx):
            c = (x0 + i * CELL, z0 + j * CELL, x0 + (i + 1) * CELL, z0 + (j + 1) * CELL)
            row.append(0 if any(overlap_frac(c, r) >= 0.5 for r in ex) else tiers)
        rows.append(row)
    return rows

def formation(title, res, rect, base_y, tiers, units, qlevel, ex, cover=None, extra=None):
    f = dict(title=title, resource=res, frame='pit', layout='grid',
             center=[(rect[0] + rect[2]) / 2, base_y, (rect[1] + rect[3]) / 2], cell=CELL, tier_h=TH, chunk_units=units,
             level=1, quarry_level=qlevel, style='cut', skin=True, strict=False, requires_cleanup=True, world='filled', closed=[],
             tiers=grid(rect, tiers, ex))
    if cover:
        f['cover'] = cover
    if extra:
        f.update(extra)
    return f

F = {}
# ---- level 1: three stacked layers, 1.2 m each, flush with the plateau (top 0). Bottom layer first.
L1R = BASIN
ex1 = shafts(1)
F['q_l1_rock'] = formation('Limestone Bed', 'limestone', L1R, -3.6, 1, 14, 1, ex1,
                           extra=dict(no_label=True, veins=dict(seed=21, count=18, mix=['coal', 'coal', 'iron_ore'])))
F['q_l1_gravel'] = formation('Gravel and Compacted Soil', 'gravel', L1R, -2.4, 1, 8, 1, ex1, extra=dict(no_label=True))
F['q_l1_top'] = formation('Topsoil and Overburden', 'topsoil', L1R, -1.2, 1, 5, 1, ex1, extra=dict(no_label=True, decor=dict(seed=7, density=0.22)))
# the layers are stacked in the same place: a lower layer is covered by the ones above it
F['q_l1_gravel']['cover'] = ['q_l1_top']
F['q_l1_rock']['cover'] = ['q_l1_top', 'q_l1_gravel']
L1_COVER = ['q_l1_top', 'q_l1_gravel', 'q_l1_rock']

# ---- level 2: coal (south half, next to the lane) and iron (north half); level 3: iron north, copper south; level 4: gold north, copper south
def split(L, z_split):
    x0, z0, x1, z1 = cols(L)
    return (x0, z0, x1, z_split), (x0, z_split, x1, z1)
c2n, c2s = split(L2, -116)
F['q_l2_iron'] = formation('Iron Bench', 'iron_ore', c2n, -7.2, 3, 9, 2, shafts(2), cover=L1_COVER,
                           extra=dict(veins=dict(seed=31, count=14, mix=['iron_ore', 'coal'])))
F['q_l2_coal'] = formation('Coal Bench', 'coal', c2s, -7.2, 3, 13, 2, shafts(2), cover=L1_COVER,
                           extra=dict(veins=dict(seed=32, count=14, mix=['coal', 'iron_ore']),
                                      pads=[[-36.0, -3.6, -76.5, 0.0], [-28.0, -3.6, -76.5, 0.0], [-20.0, -3.6, -76.5, 0.0]]))
c3n, c3s = split(L3, -116)
F['q_l3_iron'] = formation('Deep Iron Bench', 'iron_ore', c3n, -10.8, 3, 13, 3, shafts(3), cover=['q_l2_iron', 'q_l2_coal'] + L1_COVER,
                           extra=dict(veins=dict(seed=41, count=12, mix=['iron_ore', 'copper_ore']),
                                      pads=[[-12.0, -7.2, -147.5, 3.1416], [-4.0, -7.2, -147.5, 3.1416], [4.0, -7.2, -147.5, 3.1416]]))
F['q_l3_copper'] = formation('Deep Copper Bench', 'copper_ore', c3s, -10.8, 3, 16, 3, shafts(3), cover=['q_l2_iron', 'q_l2_coal'] + L1_COVER)
c4n, c4s = split(L4, -116)
F['q_l4_gold'] = formation('Gold Bench', 'gold_ore', c4n, -14.4, 3, 13, 4, shafts(4), cover=['q_l3_iron', 'q_l3_copper', 'q_l2_iron', 'q_l2_coal'] + L1_COVER)
F['q_l4_copper'] = formation('Deep Copper Seam', 'copper_ore', c4s, -14.4, 3, 20, 4, shafts(4), cover=['q_l3_iron', 'q_l3_copper', 'q_l2_iron', 'q_l2_coal'] + L1_COVER,
                             extra=dict(veins=dict(seed=51, count=8, mix=['copper_ore', 'gold_ore']),
                                        pads=[[0.0, -10.8, -96.5, 0.0], [8.0, -10.8, -96.5, 0.0], [16.0, -10.8, -96.5, 0.0]]))

# ---------------------------------------------------------------- levels
def level(n, id_, title, floor_y, mats, forms, unlock, L=None, rds=None, gate=None):
    lv = dict(id=id_, title=title, floor_y=floor_y, materials=mats, formations=forms, built=True, unlock=unlock)
    if gate:
        lv['gate'] = gate
    if L:
        x0, z0, x1, z1 = L['rect']
        lv['pit'] = dict(rect=[x0, z0, x1, z1], ramp_w=RW, side=L['strip'], ramp_top=L['top'], ramp_run=21, y_top=L['y_top'])
        lv['roads'] = [list(r) for r in (rds or [])]
    return lv
LV = [
    level(1, 'surface', 'Surface Quarry', -3.6, ['topsoil', 'gravel', 'limestone'], ['q_l1_top', 'q_l1_gravel', 'q_l1_rock', 'hillside_face_01'], 0.0, gate=['q_l1_rock']),
    level(2, 'bench', 'First Excavation Bench', -7.2, ['coal', 'iron_ore'], ['q_l2_coal', 'q_l2_iron'], 0.06, L2, roads[2]),
    level(3, 'deep', 'Deep Quarry', -10.8, ['iron_ore', 'copper_ore'], ['q_l3_iron', 'q_l3_copper'], 0.3, L3, roads[3]),
    level(4, 'lower', 'Lower Quarry', -14.4, ['copper_ore', 'gold_ore'], ['q_l4_copper', 'q_l4_gold'], 0.3, L4, roads[4]),
]
# the surface level's gate (what "level 1 is cut" means for opening level 2): the limestone bed, i.e. columns dug all the way down
d['quarry_levels_filled'] = LV
# legacy data keeps working unchanged for the legacy layout
for k in ('bench_l2_coal', 'bench_l2_iron', 'bench_l3_iron', 'bench_l3_copper', 'bench_l4_copper', 'bench_l4_gold', 'pit_band_01'):
    d['formations'][k]['world'] = 'legacy'
for k, v in F.items():
    d['formations'][k] = v
# materials
d['materials']['topsoil'] = dict(hp=10, hardness=0)
d['materials']['gravel'] = dict(hp=16, hardness=0)
d['display_names']['topsoil'] = 'Topsoil'
d['display_names']['gravel'] = 'Pit Gravel'
# areas (new ids join the old ones; Main.area_at and area_of_formation read these)
for a in d['areas']:
    if a['id'] == 'area_2': a['formations'] = ['pit_band_01', 'q_l1_top', 'q_l1_gravel', 'q_l1_rock']
    if a['id'] == 'area_3': a['formations'] = ['bench_l2_coal', 'bench_l2_iron', 'q_l2_coal', 'q_l2_iron']
    if a['id'] == 'area_4': a['formations'] = ['bench_l3_iron', 'bench_l3_copper', 'q_l3_iron', 'q_l3_copper']
    if a['id'] == 'area_5': a['formations'] = ['bench_l4_copper', 'q_l4_copper']; a['z_range_filled'] = [-116.0, -100.0]
    if a['id'] == 'area_6': a['formations'] = ['bench_l4_gold', 'q_l4_gold']; a['z_range_filled'] = [-128.0, -116.0]
# fossil: the gold bench's far corner
fz = dict(d['fossil']); fz['formation'] = 'q_l4_gold'; fz['columns'] = [4, 5]
d['fossil_filled'] = fz
json.dump(d, open(P, 'w'), indent=1)
tot = {k: sum(sum(1 for t in row if t) for row in f['tiers']) for k, f in F.items()}
print('columns:', tot)
print('dims L1', len(F['q_l1_top']['tiers'][0]), 'x', len(F['q_l1_top']['tiers']))
