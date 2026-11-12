# Phase 6.3 plan: the bigger world and curved benches

Status: plan only (nothing built). Builds on Phase 6.1 (hillside) and 6.2 (cleanup tutorial).
Decisions already made by the designer: curved benches, enlarged world, cleanup tutorial first (done).
Goal: a quarry that grows from a small yard into a terraced open pit like the reference photos (concentric curved
benches, one zig-zag haul road, trucks and machines on flat bench floors), in the existing low-poly, pixel-textured style.

## 1. Facts from the current code that shape the design

| Fact | Where | Consequence |
|---|---|---|
| World is a 58 x 58 m floor (+-29) inside a ring of cliff boxes at r=27 and low rim walls at r=19, soil embankment as scenery to r=52 | `main._build_quarry`, `quarry_art._ground`, `_cliffs` | A big pit needs a new zone; the yard keeps its coordinates so saves, tests and machine positions stay valid. |
| Mineable rock is a column grid (`QuarryFormation`): one `MeshInstance3D` per chunk, one `BoxShape3D` per column; adjacency drives exposure | `formation.gd`, `progression.gd` (`dims`, `column_pos`, `column_exposed`, `column_open_dir`) | Works for rectangles only. A curved bench needs an arc layout; per-chunk meshes will not scale to thousands of chunks. |
| Only one lower level exists: a fixed rectangle plus one ramp, `level_unlocked` clamped to 1..2 | `excavation.gd`, `progression.restore` | Needs generalising to a list of levels (data driven). |
| Navigation is rebuilt synchronously from every `BoxShape3D` in the world over a fixed box (-30,-6,-30)..(52,8,30), cell 0.25 | `main._rebake_nav` | Too slow and too small for a large pit. Needs regions, exposed-only sources and async baking. |
| `in_build_area`, the ghost Y (0 or lower level) and belts are two-level, flat | `main.in_build_area`, `_update_ghost`, `conveyor_snap` | Placement must take Y and zones from data and the ground ray. |
| Vehicles climb 40 degrees, nav agents 0.25 climb, the existing ramp is about 14.5 degrees | `vehicle.gd`, `_rebake_nav`, `excavation.gd` | A haul road at 10-12 degrees is safe for trucks and workers. |
| Saves keep columns as int arrays inside `state.deposits`; `init_formation` resets columns if the count changes | `progression.init_formation` | Never resize existing formations; add new ids. A bench with 1,000 columns is about 4 KB of JSON per level. |

## 2. Core idea: rock fills the pit, the shell is already there

Do not carve terrain. Pre-build the **empty shell** of the finished quarry (curved floors, ramps, outer walls) as
static meshes, then fill the shell with **rock columns** that the player, staff and rigs remove.

- Each level `k` has a floor at `y_k` (0, -3.6, -7.2, -10.8, -14.4; bench lift 3 tiers of 1.2 m).
- The rock volume of level `k` is a curved band (annular sector) of columns standing on floor `k`, with tops flush
  with floor `k-1`. At the start the plateau looks flat and solid; mining a band reveals floor `k` underneath.
- The haul road is also part of the shell: a sloped trimesh under its columns. Clearing the columns above the road
  strip reveals a drivable road.
- Result: curved benches, ramps and flat working floors with no runtime mesh editing; excavation progress is only the
  column int arrays (compact, save-safe).

A small starting basin (Grandpa's old workings, floor at -3.6) gives the first open face and the first flat bench.

## 3. Technical building blocks

1. **Arc layout for formations.** Data: `layout: "arc"`, `center`, `radius_inner`, `rows` (radial cells), `sectors`,
   `arc_start/arc_end`, `tier_h`, `tiers`. Columns keep the same index scheme (sector = x, row = y), so
   `column_exposed`, `column_open_dir`, `nearest_column`, saves and staff logic are reused. Only `column_pos`,
   collider orientation (boxes rotated tangentially) and chunk orientation change.
2. **MultiMesh chunk renderer.** Replace per-chunk `MeshInstance3D` with one `MultiMeshInstance3D` per formation
   (and material). Hidden or crumbling chunks are per-instance transforms. Target: one draw call per formation per
   material instead of thousands.
3. **Shell meshes.** New `MeshKit` builders: curved floor strip, curved stratified wall (`cliff_into` swept along an
   arc), berm ridge, ramp strip. Collision for shell pieces: `ConcavePolygonShape3D` (static) or tangent box
   segments. Strata texture `T_QD_CutLimestone` plus tint per level.
4. **Navigation.** One `NavigationRegion3D` per zone (yard, pit level groups), bake from the shell trimesh plus only
   the *exposed* standing columns (buried columns are not sources), async (`bake_from_source_geometry_data_async`),
   rate-limited (at most one rebake per region per 1-2 s). Extend the source collector to read
   `ConcavePolygonShape3D.get_faces()`.
5. **Generalised levels.** `data/progression.json` `levels: [...]` replaces the single `excavation` rectangle.
   Keep the Phase 5 pit and its permit working unchanged (see decisions).
6. **Placement zones from data.** `in_build_area` and the ghost Y read zones and level floors; the ghost uses the
   ground ray for Y.

## 4. World layout

- **Yard** (existing 58 x 58 m, unchanged): office, shed, sales, kiosk, parking, roads, the west hillside and the
  cleanup tutorial.
- **Pit zone**: a new area north of the yard, about 120 x 120 m, entered through a gate in the north cliff ring
  (the same pattern as the east expansion barrier). Rim, embankment and horizon are scenery.
- **Levels** 1 to 4 down to y = -14.4 in concentric curved bands, 11 to 12 m wide, with a single zig-zag haul road
  descending along the wall.
- East expansion stays as is.

## 5. Phases (each playable and testable)

### Phase 6.3a: world shell and gate  (Medium)
- Scope: enlarge the world northward, gate in the cliff ring, rim and horizon, nav regions, build-zone data. No
  mining yet. The starting basin and rim are walkable and drivable.
- Files: `main.gd` (`_build_quarry`, `in_build_area`, `_rebake_nav`), `art/quarry_art.gd`, `art/mesh_kit.gd`,
  `data/progression.json`.
- Depends on: nothing.
- Acceptance: player, workers and a loader reach the pit rim from the yard; no gaps in the cliff ring; old saves
  load unchanged; navigation rebuild under 30 ms per region on the test machine; all current suites pass.

### Phase 6.3b: arc formations and MultiMesh chunks  (High)
- Scope: arc layout, rotated column colliders, MultiMesh renderer for cut-stone chunks (also used by the
  hillside), exposed-only nav sources, async rebake with a rate limit.
- Files: `formation.gd`, `progression.gd`, `art/mesh_kit.gd`, `main.gd`, tests.
- Depends on: 6.3a.
- Acceptance: a 1,000-column band renders in few draw calls; cutting a section updates only that instance;
  exposure, staff pathing and saves behave as on the hillside; frame time within budget on the integrated GPU
  test profile (see section 6).

### Phase 6.3c: first bench and curved walls  (Medium)
- Scope: level 1 band, curved stratified outer wall, berms and light poles, bench-floor texture (drill-hole rows,
  kerfs), level tints. The player cuts the first bench back and sees the flat floor widen.
- Files: `art/mesh_kit.gd`, `quarry_art.gd`, `tools/qd_textures.py`, `formation.gd`, data.
- Depends on: 6.3b.
- Acceptance: a new bench band can be mined from the open edge, collision follows, the floor behind it is flat and
  walkable, save/load restores exactly the cut area.

### Phase 6.3d: haul road and level 2  (High)
- Scope: generalised levels list, road shell under flagged columns, drivable by loader and truck, staff can walk
  it, machines can be placed on bench floors (Y from the ground ray), second band.
- Files: `excavation.gd` (generalise), `progression.gd` (`level_unlocked` range), `main.gd` (placement, ghost
  Y), `fleet.gd`/`vehicle.gd` only if slope handling needs it.
- Depends on: 6.3c.
- Acceptance: a truck drives from level 2 to the yard; a crusher can be placed on level 2; a pre-6.3 save with
  `level_unlocked` 1 or 2 still loads.

### Phase 6.3e: stages, permits and polish  (Medium)
- Scope: stage gates unlock levels 3 and 4, permit generalised, rig pads on benches, haul-road traffic flavour,
  tuning of costs and money.
- Depends on: 6.3d.
- Acceptance: a full playthrough path from cleanup to level 4 is possible; performance targets met.

## 6. Performance budget (Windows, integrated graphics)

- Chunk meshes: at most about 30 draw calls for all pit formations together (MultiMesh).
- Colliders: up to about 2,000 static boxes in total is acceptable; create colliders only for columns that can be
  touched (exposed plus one layer) if profiling says so.
- Navigation rebake: async, max one per region per second, exposed sources only.
- Particles: unchanged.
- Measure: frame time with the full level 1 band visible and during crew mining, plus rebake counts.

## 7. Risks

- Arc geometry and rotated colliders leaving tiny gaps between adjacent columns (use a small overlap, as the
  chunk meshes already do).
- Players standing on column tops when a worker removes the column (falls to the floor below; acceptable).
- Trimesh floors plus vehicle `move_and_slide` jitter (mitigate with flat road strips and floor snap).
- Old saves: never resize existing formations or reuse their ids; `level_unlocked` clamp must be widened carefully.
- Test fixtures hard-code coordinates around the yard; the yard must not move.

## 8. Decisions

Settled by the designer:
- Pit entrance: a **gate in the north cliff ring** (same pattern as the east expansion barrier).
- Trucks: player-driven first; **NPC drivers come later** (keep the haul road, truck API and `fleet` data free of
  player-only assumptions so haulers can drive them in a later phase).
- The drill-and-saw block-cutting pipeline is its **own phase after the benches** are finished.

Defaults assumed unless the designer says otherwise:
- Keep the Phase 5 lower pit and permit unchanged for now; fold them into the level system in a later phase.
- Bench height 3.6 m (3 tiers of 1.2 m).

## 9. Original open questions (for reference)

1. Keep the Phase 5 lower pit and the permit as they are, or fold them into the new level system later?
2. Pit entrance: a gate in the north ring (recommended) or a ramp through the existing rim?
3. Bench height: 3.6 m (3 tiers) as planned, or taller faces for a more dramatic look?
4. Should trucks be player-driven only, or should haulers drive them automatically on the road later?
5. Is a drilled-hole-and-saw block cutting pipeline part of 6.3c, or its own phase after the benches?
