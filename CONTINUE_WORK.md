# Continue work: buildings, quick sales, modular production

Branch: `feature/buildings-sales-production` (built on `feature/office-menus-os-polish`, commit 7f64a12). Nothing here is merged into main.

## Already in the game (do not redo)
- Blender office (tools/building_models/build_buildings.py -> assets/buildings/BLD_QD_Office.glb, loaded by scripts/art/building_models.gd).
- Vehicles stand on the visible ground (scripts/vehicle.gd `_update_ground_lift`), hands/arms, HUD, pause/settings/main menu, Quarry OS polish.
- The production system already exists: crushers, hoppers, sorting tables, output bins (variants), straight / left / right conveyors, a persistent construction inventory
  (`business.inventory`, saved by `Business.snapshot()`), placement from inventory (`main.gd` `_start_placement`), moving and selling structures.
  Links are computed in `business.gd` (`compute_links`, `_endpoint_near`, `tick_conveyors`).

## Order of work (commit + push after each)
1. Quick Sell Station (in-world kiosk + compact panel; reuse `business.sell_material` / `menu_act("sell")`).
2. Build inventory + EQUIPMENT CATALOG app in Quarry OS (multi-quantity purchases into `business.inventory`).
3. Merger / junction conveyor (+ short conveyor, incline if budget allows): extend `conveyor_ends`, `_endpoint_near`, `compute_links`, models in tools/.
4. Snap preview (green / red, direction arrows) in build mode.
5. Production overview (Quarry OS "production" page): running / idle / blocked + reason.
6. Buildings: house interior, workshop, storage shed, machinery garage (reuse build_buildings.py helpers).
7. Save/load regression, full suite, ZIP, mobile 3D viewer (three.js + GLB on GitHub Pages).

## Tips
- Run the full suite: `GODOT=".../Godot_v4.3-stable_win64.exe" bash tools/run_tests.sh -j 4`.
- New `class_name` scripts need one editor scan: `godot --path . --editor --quit-after 700`, then `git checkout project.godot` and any tracked `.import` it rewrote.
- Export: `godot --headless --path . --export-pack "Windows Desktop" build/QuarryDays.pck`, pair with `Downloads/QuarryDays.exe`.
