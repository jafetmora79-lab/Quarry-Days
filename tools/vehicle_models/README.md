# Vehicle models (Blender -> GLB)

```
python tools/vehicle_models/gen_textures.py                                   # pixel textures -> assets/vehicles/textures
blender -b --factory-startup -P tools/vehicle_models/build_excavator.py       # -> assets/vehicles/src/QD_Excavator.blend + VEH_QD_Excavator.glb
python tools/vehicle_models/export_kin_gd.py                                  # exc_kin.py -> scripts/art/excavator_kin.gd (run after changing pins)
godot --headless --path . --script res://tools/validate_excavator.gd         # pins/strokes/budget check (needs the GLB imported once: open the editor)
godot --path . res://assets/vehicles/test/ExcavatorTest.tscn                  # isolated viewer: 1-0 clips, E engine, L lights, M manual, T drive
```
- Conventions: metres, hinge at each part's origin, `Marker_*`/`Pin_*`/`ColHull_*` empties, material names = Quarry Days names (Godot swaps in the project's pixel materials).
- `exc_kin.py` is the single source for the linkage (boom/stick/bucket, cylinders, bucket 4-bar); Blender bakes clips from it and `ExcavatorRig` solves the same maths at runtime.
- Fallback: `QuarryVehicle.USE_RIG_EXCAVATOR := false` brings back the old procedural excavator.
- Headless imports do not write `.import` files on this setup; open the project once in the editor (or run `godot --editor --quit-after 600`).
