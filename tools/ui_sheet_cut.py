#!/usr/bin/env python3
"""Cuts the generated HUD sprite sheets (assets/ui/hud/_source/*.png) into single sprites.
Background removal (flood fill from the border: transparent / black / near-white), connected components, reading order (rows, then columns).
Usage: tools/ui_sheet_cut.py preview <sheet>    -> /tmp/ui_cut/<sheet>_labels.png and a printed index
       tools/ui_sheet_cut.py cut              -> writes the named sprites into assets/ui/hud (see NAMES)"""
import sys, os, json
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

SRC = os.path.join(os.path.dirname(__file__), '..', 'assets', 'ui', 'hud', '_source')
SHEETS = {
    'sheet_a_frames': dict(bg='alpha', big=1500, attach=14),
    'sheet_b_controls': dict(bg='black', big=1200, attach=16),
    'sheet_c1_tools_resources': dict(bg='white', big=1800, attach=26),
    'sheet_c2_machinery': dict(bg='alpha', big=1800, attach=26),
}

def load(sheet):
    im = Image.open(os.path.join(SRC, sheet + '.png')).convert('RGBA')
    a = np.array(im)
    mode = SHEETS[sheet]['bg']
    if mode == 'alpha':
        bg = a[..., 3] < 20
    else:
        rgb = a[..., :3].astype(int)
        if mode == 'black':
            cand = rgb.max(2) < 22
        else:
            cand = (rgb.min(2) > 226) & ((rgb.max(2) - rgb.min(2)) < 24)
        # background = candidate pixels connected to the border
        lab, n = ndimage.label(cand)
        border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])))
        border.discard(0)
        bg = np.isin(lab, list(border))
        # a one-pixel fringe of the background colour is eaten too
        fringe = ndimage.binary_dilation(bg, iterations=1) & cand
        bg = bg | fringe
        a[..., 3] = np.where(bg, 0, 255)
    return a, ~bg

def components(sheet):
    """Sprites = the big connected shapes; small fragments (dashes, floating shards, drop-shadow crumbs) are attached to the nearest big shape or dropped.
    Plain dilation would glue touching neighbours together, so the shapes are found WITHOUT dilation and only fragments use a distance."""
    a, fg = load(sheet)
    cfg = SHEETS[sheet]
    lab, n = ndimage.label(fg)
    objs = ndimage.find_objects(lab)
    areas = ndimage.sum(fg, lab, index=np.arange(1, n + 1))
    big, small = [], []
    for i, sl in enumerate(objs):
        box = [sl[1].start, sl[0].start, sl[1].stop, sl[0].stop]       # x0, y0, x1, y1
        (big if areas[i] >= cfg['big'] else small).append([box, areas[i]])
    boxes = [b[0] for b in big]
    for box, area in small:
        if area < 40:
            continue
        best, bd = -1, 1e9
        for k, bb in enumerate(boxes):
            dx = max(bb[0] - box[2], box[0] - bb[2], 0)
            dy = max(bb[1] - box[3], box[1] - bb[3], 0)
            d = max(dx, dy)
            if d < bd:
                best, bd = k, d
        if best >= 0 and bd <= cfg['attach']:
            bb = boxes[best]
            boxes[best] = [min(bb[0], box[0]), min(bb[1], box[1]), max(bb[2], box[2]), max(bb[3], box[3])]
    out = [[b[0], b[1], b[2] - b[0], b[3] - b[1]] for b in boxes]
    out.sort(key=lambda b: b[1] + b[3] / 2)
    rows, cur = [], []
    for b in out:
        if cur and (b[1] + b[3] / 2) - np.mean([c[1] + c[3] / 2 for c in cur]) > 0.5 * np.median([c[3] for c in cur] + [b[3]]):
            rows.append(cur); cur = []
        cur.append(b)
    if cur:
        rows.append(cur)
    res = []
    for r in rows:
        res.extend(sorted(r, key=lambda b: b[0]))
    return a, res

def crop(a, box, pad=2):
    x, y, w, h = box
    x0, y0, x1, y1 = max(0, x - pad), max(0, y - pad), min(a.shape[1], x + w + pad), min(a.shape[0], y + h + pad)
    sub = a[y0:y1, x0:x1].copy()
    return Image.fromarray(sub, 'RGBA')

NAMES = {
    'sheet_a_frames': ['panel_main', 'panel_inset', 'plate_title', 'plate_prompt', 'frame_dialog', 'frame_portrait', 'plate_toast', 'plate_banner', 'corner_tl', 'corner_tr',
        'panel_vehicle', 'plate_repair', 'strip_green', 'strip_gold', 'strip_red', 'strip_blue', 'corner_bl', 'corner_br', 'divider', 'rivet', 'rivet_lit'],
    'sheet_b_controls': ['bar_groove', 'bar_fill_green', 'bar_fill_gold', 'bar_fill_red', 'bar_fill_blue', 'bar_cap_left', 'bar_cap_right', 'bar_complete',
        'dot_off', 'dot_on', 'dot_warn', 'dot_done', 'checkbox_empty', 'checkbox_done', 'btn_primary', 'btn_main', 'btn_danger', 'btn_disabled',
        'arrow_left', 'arrow_right', 'arrow_up', 'arrow_down', 'slider_track_gold', 'slider_grabber_gold', None, 'btn_play', 'btn_pause', 'btn_stop', 'btn_plus', 'btn_minus',
        'btn_gear', 'btn_tools', 'btn_trash', 'slider_track_dark', 'slider_grabber_dark', None, 'keycap_small', 'keycap_small_hover', 'keycap_small_pressed', 'keycap_small_off',
        'keycap_wide', 'pad_a', 'pad_b', 'pad_x', 'pad_y', 'pad_lb', 'pad_rb', 'pad_lt', 'pad_rt', 'slot_empty', 'slot_selected', 'slot_ok', 'slot_bad', 'slot_locked', 'slot_dashed',
        'icon_up_green', 'icon_star', 'icon_warning', 'icon_info', 'plate_chat', 'plate_pin', 'plate_list', 'plate_check', 'plate_star', 'plate_trophy', 'ribbon'],
    'sheet_c1_tools_resources': ['pickaxe', 'hammer', 'chisel', 'jackhammer', 'shovel', 'crowbar', 'wrench', 'wrench_adjustable', 'screwdriver', 'tape_measure',
        'toolbox', 'battery', 'hose', 'filter', 'jerrycan', 'oilcan', 'bolt', 'nut', 'gear', 'bearing',
        'limestone', 'coal', 'iron_ore', 'copper_ore', 'gold_ore', 'gravel_pile', 'sand_pile', 'topsoil_pile', 'crushed_pile', 'concrete_block',
        'gravel_fine', 'gravel_coarse', 'stone_blocks', 'slab', 'ingots_steel', 'ingot_copper', 'ingot_gold', 'crate_ore', 'sack', 'bulk_bag',
        'excavator', 'loader', 'truck', 'crusher', 'conveyor', 'hopper', 'sorting_table', 'drill_rig', 'breaker', 'compressor',
        'office', 'workshop', 'shed', 'warehouse', 'fuel_tank', 'silo', 'conveyor_long', 'tower', 'gate_barrier', 'tunnel',
        'portrait_grandpa', 'portrait_worker_a', 'portrait_worker_b', 'portrait_worker_c', 'portrait_worker_d', 'portrait_worker_e', 'clipboard', 'blueprint', 'calendar', 'coins_stack',
        'money_bag', 'card', 'arrow_up', 'gear_gold', 'hardhat', 'vest', 'gloves', 'boots', 'radio', 'lunchbox', 'mug'],
    'sheet_c2_machinery': ['engine', 'radiator', 'oil_filter', 'hose_curved', 'battery_big', 'jerrycan_oil', 'spark_plug', 'belt_pulley',
        'tools_cross', 'gear_wrench', 'power_on', 'power_off', 'play', 'pause', 'stop', 'refresh', 'fuel_pump', 'oil_drop',
        'gear_grey', 'gear_green', 'gear_gold', 'gear_alert', 'wrench_tools', 'ok', 'cancel', 'hourglass', 'signal', 'antenna',
        'excavator_idle', 'excavator_dig', 'excavator_loaded', 'excavator_lift', 'excavator_swing', 'excavator_dump', 'excavator_travel',
        'truck_idle', 'truck_loading', 'truck_haul', 'truck_fast', 'truck_dump', 'truck_return',
        'crusher_a', 'crusher_b', 'conveyor_a', 'conveyor_b', 'hopper_b', 'silo_b', 'gravel_b', 'pallet_blocks',
        'area_1', 'area_2', 'area_3', 'area_4', 'area_5', 'area_6',
        'ore_limestone', 'ore_coal', 'ore_iron', 'ore_gold', 'ore_quartz', 'ore_copper', 'fossil_ammonite', 'fossil_bone', 'fossil_egg'],
}
# output scale (sheet px -> game px, the game canvas is 960x540) and folder per sheet
SCALE = {'sheet_a_frames': 0.22, 'sheet_b_controls': 0.25, 'sheet_c1_tools_resources': 0.28, 'sheet_c2_machinery': 0.28}
FOLDER = {'sheet_a_frames': '', 'sheet_b_controls': '', 'sheet_c1_tools_resources': 'icons/', 'sheet_c2_machinery': 'icons/'}

def cut_all(out_root):
    made = []
    for sheet, names in NAMES.items():
        a, boxes = components(sheet)
        assert len(boxes) == len(names), '%s: %d pieces but %d names' % (sheet, len(boxes), len(names))
        os.makedirs(os.path.join(out_root, FOLDER[sheet]), exist_ok=True)
        for box, name in zip(boxes, names):
            if name is None:
                continue
            im = crop(a, box, pad=1)
            # premultiply before resizing so the transparent border does not leave a dark halo
            arr = np.array(im).astype(np.float32)
            al = arr[..., 3:4] / 255.0
            arr[..., :3] *= al
            pm = Image.fromarray(arr.astype(np.uint8), 'RGBA')
            w = max(2, int(round(im.width * SCALE[sheet])))
            h = max(2, int(round(im.height * SCALE[sheet])))
            r = np.array(pm.resize((w, h), Image.LANCZOS)).astype(np.float32)
            ra = np.clip(r[..., 3:4], 1, 255) / 255.0
            r[..., :3] = np.clip(r[..., :3] / ra, 0, 255)
            Image.fromarray(r.astype(np.uint8), 'RGBA').save(os.path.join(out_root, FOLDER[sheet], name + '.png'))
            made.append((FOLDER[sheet] + name, w, h))
    return made

if __name__ == '__main__' and len(sys.argv) > 1 and sys.argv[1] == 'cut':
    root = os.path.join(os.path.dirname(__file__), '..', 'assets', 'ui', 'hud')
    for n, w, h in cut_all(root):
        print('%-28s %3dx%3d' % (n, w, h))
    sys.exit(0)

if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == 'preview':
        sheet = sys.argv[2]
        a, boxes = components(sheet)
        im = Image.fromarray(a, 'RGBA')
        prev = Image.new('RGBA', im.size, (200, 60, 200, 255)); prev.alpha_composite(im)
        d = ImageDraw.Draw(prev)
        for i, (x, y, w, h) in enumerate(boxes):
            d.rectangle([x, y, x + w, y + h], outline=(0, 255, 255, 255), width=1)
            d.text((x + 2, y + 1), str(i), fill=(255, 255, 0, 255))
        os.makedirs('/tmp/ui_cut', exist_ok=True)
        prev.save('/tmp/ui_cut/%s_labels.png' % sheet)
        print(sheet, len(boxes), 'pieces')
        for i, b in enumerate(boxes):
            print(i, b)
