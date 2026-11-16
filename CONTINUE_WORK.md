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

## Overnight intro / world / UI polish (branch feature/intro-world-ui-polish)
- P1 opening: scripts/opening_scene.gd (QuarryOpeningScene) + scripts/art/pickup_model.gd. First-person drive in Walt's pickup (QuarryOpening road -> tunnel -> yard lanes), exit, deed handoff
  (readable PROPERTY DEED, once: prog.story["deed_received"]), Walt walks to the excavator (walter_mode "to_post"), Esc skips to the same final state. Lines/timing: data/progression.json walter.cinematic
  (scene = drive / yard / post; empty text = silent beat). Headless runs start at the yard (intro_shots_enabled=false). Tools: tools/shot_opening.gd, shot_doors.gd, shot_os.gd, shot_hud.gd.
- P2 tunnel mountain / forest road, P3 door panel/glass fix (scripts/door.gd), P4 OS wallpaper + catalog icon, P5 HUD plates (scripts/ui_plate.gd).
- Unverified by eye/ear: engine/road/tunnel audio (synthesised, never listened to), distant peaks from the north, the pickup's exterior from outside during a real run beyond the shots taken.
- Godot for tests: unzip Downloads/Godot_v4.3-stable_win64.exe.zip; run `--headless --path . --import` once after adding a class_name.
