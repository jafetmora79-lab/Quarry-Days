# Continue work: world environment (branch `feature/world-environment`)

Built on `feature/blender-production-garage` (excavator fix + Blender equipment + garage). Nothing merged into main.

## Done
- `tools/world_models/build_world.py` -> `assets/world/WLD_QD_*.glb`: forest set, mountains (height-field), tunnel portal and lining, deer, rabbit. Loader: `scripts/art/world_models.gd`.
- Forest: `scripts/art/landscape.gd` `_plant` (MultiMesh per species, 64 m ground-cover chunks, sway shader, density by distance, `forest_blocked`).
- Mountains: `quarry_art._world_mountains`; tunnel: `delivery._build_gate_west` / `_build_tunnel` (colliders unchanged).
- Wildlife `scripts/wildlife.gd`, ambience `scripts/ambience.gd` (synthesised sounds). Tests: test_world_environment, test_wildlife_ambience.
- Viewer (docs/): first group is the world models.

## Known gaps
- Deer, rabbit, golden hour and night were not checked by eye in the running game (headless tests and Blender renders only).
- The tunnel is still the existing 20 m dead end the delivery trucks drive into; no through-exit was added.
- Sky/clouds/day-night are the existing system (only the haze changed).
- Trees have no collision (as before); animals wander inside an open patch rather than path-finding round trees.
