# Continue work: Blender redesign (branch `feature/blender-production-garage`, from cba72a5)

Nothing here is merged into main.

## Integrated in the game (Blender GLB -> actually used)
- Production equipment, `tools/equipment_models/build_equipment.py` -> `assets/equipment/EQP_QD_*.glb`, loaded by `scripts/art/equipment_models.gd`, wired in `scripts/art/quarry_art.gd`
  (`_equip_crusher`, `_equip_belt`): crusher, advanced crusher, hopper, output bin, storage container, straight / short / incline / left / right belts, merger, splitter,
  end caps (shown while a belt end is unconnected) and supports (built into every belt; `support` is also a viewer model).
- Belt kinds short / incline / splitter run on the existing transfer system (`business.gd`: `belt_half`, `conveyor_outputs`, `dst2`, splitter alternation `sr`).
- Garage: `tools/building_models/build_garage.py` -> `BLD_QD_Garage.glb`, `quarry_art._garage_blender`; colliders, parking and delivery untouched.
- Earlier branch: office, house + living wing, workshop, shed, Quick Sell kiosk.
- Viewer (docs/, three.js): the first group lists the Blender buildings and the equipment, the same files the game loads. Rebuild: `python tools/build_asset_preview.py`.

## Not done / known limits
- The sorting table is still the generated model (not in the request).
- Support legs are part of each belt model, not separately placeable pieces. An incline's exit has no matching "lift" level: it only drops into bins, hoppers and crusher troughs.
- Garage front stays open for the whole width (machines are parked by a physics-fit search, so solid piers/doors there would change capacity); door hoods are visual.
- Interiors checked in-engine (tools/shot_buildings.gd): no floating furniture found; the office pin boards and the workshop pendant lamp overlap the sign slightly.

## Tips
- Full suite: `GODOT=".../Godot_v4.3-stable_win64.exe" bash tools/run_tests.sh -j 4`.
- New GLBs / class_names need one editor scan (`godot --path . --editor --quit-after 700`, isolated APPDATA), then `git checkout project.godot`; do not stage rewritten `.import` files.
- In-engine pictures: `godot --path . --resolution 900x520 -s tools/shot_equipment.gd -- out.png` and `tools/shot_buildings.gd`.
