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
