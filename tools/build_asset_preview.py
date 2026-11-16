#!/usr/bin/env python3
"""Builds the 3D asset preview site in docs/ (GitHub Pages: branch + /docs folder).

  1. godot --headless -s tools/export_procedural_models.gd -- docs/models/procedural   (the game's generated models)
  2. python3 tools/build_asset_preview.py                                           (copies the Veil + character GLBs, writes the manifest)
"""
import json, os, shutil, glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
OUT = os.path.join(DOCS, "models")

import re

def pretty(s):
    s = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", s)
    s = s.replace("_", " ").replace("-", " ").strip()
    return " ".join(w if w.isupper() else w.capitalize() for w in s.split())

def main():
    groups = {}
    def add(group, sub, path, name):
        groups.setdefault(group, {}).setdefault(sub, []).append({"name": name, "file": path})

    # NEW: the Blender yard buildings (assets/buildings) and the production line, first in the list so a phone opens straight on them
    NEWG = "NEW: buildings, sell station, production line"
    bdir = os.path.join(ROOT, "assets", "buildings")
    os.makedirs(os.path.join(OUT, "blender"), exist_ok=True)
    nice = {"Home": "Grandpa's house (cabin + living room)", "Workshop": "Workshop", "Shed": "Storage shed", "Office": "Office", "SellKiosk": "Quick Sell Station", "Garage": "Machinery garage"}
    for key in ["Garage", "Home", "Workshop", "Shed", "Office", "SellKiosk"]:
        src = os.path.join(bdir, "BLD_QD_%s.glb" % key)
        if os.path.exists(src):
            shutil.copy2(src, os.path.join(OUT, "blender", "BLD_QD_%s.glb" % key))
            add(NEWG, "1. Buildings (modelled in Blender)", "models/blender/BLD_QD_%s.glb" % key, nice[key])
    eq = os.path.join(ROOT, "assets", "equipment")
    os.makedirs(os.path.join(OUT, "equipment"), exist_ok=True)
    prod = [("crusher", "Jaw crusher"), ("crusher_adv", "Advanced (cone) crusher"), ("hopper", "Input hopper"), ("bin", "Output storage bin"), ("storage", "Large storage container"),
            ("belt", "Conveyor, straight (2 m)"), ("belt_short", "Conveyor, short (1 m)"), ("belt_incline", "Conveyor, inclined (3 m)"),
            ("belt_left", "Conveyor, left corner"), ("belt_right", "Conveyor, right corner"), ("belt_merger", "Conveyor merger"), ("belt_splitter", "Conveyor splitter"),
            ("support", "Conveyor supports and end cap")]
    for key, nm in prod:
        src = os.path.join(eq, "EQP_QD_%s.glb" % key)
        if os.path.exists(src):
            shutil.copy2(src, os.path.join(OUT, "equipment", "EQP_QD_%s.glb" % key))
            add(NEWG, "2. Production machinery (modelled in Blender, the models the game uses)", "models/equipment/EQP_QD_%s.glb" % key, nm)

    # Veil asset pack
    veil_root = os.path.join(ROOT, "assets", "veil_qd")           # the repaired Quarry Days copies (tools/repair_glb.py)
    if not os.path.isdir(veil_root):
        veil_root = os.path.join(ROOT, "THE_VEIL_ASSETS_V2")
    for f in sorted(glob.glob(os.path.join(veil_root, "**", "*.glb"), recursive=True)):
        rel = os.path.relpath(f, veil_root).replace(os.sep, "/")
        dst = os.path.join(OUT, "veil", rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(f, dst)
        parts = rel.split("/")
        sub = pretty(parts[1] if len(parts) > 2 else parts[0].split("_", 1)[-1])
        add("The Veil pack", pretty(parts[0].split("_", 1)[-1]) + " / " + sub if len(parts) > 2 else pretty(parts[0]),
            "models/veil/" + rel, pretty(os.path.splitext(parts[-1])[0].split("_", 1)[-1]))
    # textures the Veil models reference by relative path
    for f in glob.glob(os.path.join(veil_root, "**", "*.png"), recursive=True):
        rel = os.path.relpath(f, veil_root)
        dst = os.path.join(OUT, "veil", rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(f, dst)
    # characters
    legacy = {"Clerk", "Hauler", "Miner", "Operator"}   # generic fallbacks for very old saves: not shown in the gallery
    for f in sorted(glob.glob(os.path.join(ROOT, "assets", "characters", "*.glb"))):
        if os.path.splitext(os.path.basename(f))[0].replace("CHR_QD_", "") in legacy:
            continue
        dst = os.path.join(OUT, "characters", os.path.basename(f))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(f, dst)
        add("Quarry Days", "Characters", "models/characters/" + os.path.basename(f), pretty(os.path.splitext(os.path.basename(f))[0].replace("CHR_QD_", "")))
    # procedural (exported from Godot)
    for f in sorted(glob.glob(os.path.join(OUT, "procedural", "*.glb"))):
        base = os.path.splitext(os.path.basename(f))[0]
        cat, name = base.split("__", 1)
        if cat == "machinery" and name in ("jaw_crusher", "cone_crusher", "small_hopper", "output_storage", "storage_crate", "conveyor", "conveyor_corner_left", "conveyor_corner_right", "conveyor_merger"):
            continue                                  # replaced by the Blender models above
        add("Quarry Days", pretty(cat), "models/procedural/" + os.path.basename(f), pretty(name))

    manifest = []
    for g in groups:
        manifest.append({"group": g, "sections": [{"title": t, "items": groups[g][t]} for t in sorted(groups[g])]})
    with open(os.path.join(DOCS, "models", "manifest.json"), "w") as fh:
        json.dump(manifest, fh, indent=1)
    open(os.path.join(DOCS, ".nojekyll"), "w").close()
    n = sum(len(s["items"]) for g in manifest for s in g["sections"])
    print("manifest: %d models" % n)

if __name__ == "__main__":
    main()
