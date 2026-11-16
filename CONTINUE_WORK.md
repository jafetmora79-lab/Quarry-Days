# Continue work: buildings, quick sales, modular production

Branch: `feature/buildings-sales-production` (built on `feature/office-menus-os-polish`, commit 7f64a12). Nothing here is merged into main.

## Done on this branch (do not redo)
1. **Quick Sell Station**: Blender kiosk (`build_buildings.py sellkiosk`), `main._build_quicksell_station`, `_draw_quicksell`, `quick_sell`, `quick_sell_all`. Test: `tests/test_quick_sell.gd`.
2. **Equipment Catalog** (Quarry OS app "catalog"): `main.CATALOG`, `catalog_buy` (atomic, quantity 1-99), `machine_lock_reason`, page `management_ui._catalog`. Test: `test_equipment_catalog.gd`.
3. **Merger (3-way junction)**: `business.conveyor_side_inputs`, round-robin `_merge_turn_ok`, model `quarry_art.conveyor_merger_model`, catalog key `conveyor_merger`. Test: `test_merger_production.gd`.
4. **Build Mode inventory**: `[` `]` pick, `P` place, `I` store a placed machine back into the Build Inventory (`business.store_structure`). Test: `test_production_acceptance.gd`.
5. **Production Overview** (Quarry OS Production page): `business.machine_status` / `production_overview`. Test: `test_production_overview.gd`.
6. **Buildings**: Blender Home (cabin + living-room wing), Workshop, Shed (`build_buildings.py house workshop shed`); wing colliders in `main._home_wing`. Test: `test_yard_buildings.gd`.
7. **Asset viewer** (`docs/`, three.js): new first group with the buildings and the production machinery. Rebuild with
   `godot --headless --path . -s tools/export_procedural_models.gd -- docs/models/procedural machinery` then `python tools/build_asset_preview.py`.

## Known gaps / next steps
- Production equipment (crushers, hoppers, bins, belts, merger) is still drawn by the game's MeshKit builders, not Blender. Blender versions would go in a new
  `tools/building_models/build_equipment.py` and be loaded like the buildings (`BuildingModels.load_model`).
- Not built: short conveyor, incline conveyor, splitter, support legs as separate pieces. A splitter needs a second `dst` per belt link (`links[i]` has one).
- The machinery garage keeps its existing procedural steel-frame model (delivery door and parking logic depend on it).
- Snap preview already tints the ghost green/red and prints IN/OUT; direction arrows are on the belt models, not on the ghost.
- Pages: the repo's GitHub Pages site is served from another branch; this branch's viewer is reachable through raw.githack.com (see the final report).

## Tips
- Run the full suite: `GODOT=".../Godot_v4.3-stable_win64.exe" bash tools/run_tests.sh -j 4`.
- New `class_name` scripts need one editor scan: `godot --path . --editor --quit-after 700` (with an isolated APPDATA), then `git checkout project.godot`; do not stage
  the `.import` files it rewrites (line-ending noise already present in the working tree).
- Export: `godot --headless --path . --export-pack "Windows Desktop" build/QuarryDays.pck`, pair with `Downloads/QuarryDays.exe`; `.blend` folders need `.gdignore`.
