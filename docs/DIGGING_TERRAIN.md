# Real digging for the quarry: status

Branch `claude/quarry-digging-integration` (started from `feature/intro-world-ui-polish`, NOT from the 274-commit-old prototype branch: the quarry has since become a filled
244 x 92 m plain with 4 m formation columns, excavator, crews, contracts and saves, so the prototype was ported forward instead). Nothing is merged into another branch.

## The engine (measured by tests)

| Piece | Where | Tests |
|---|---|---|
| Heightfield terrain over any world rectangle, 0.5 m vertices, 16-cell mesh chunks (max 3 rebuilt a frame), **one HeightMapShape3D per 32 x 32-cell block** refreshed only when dirty (~15 Hz) | `scripts/terrain/quarry_terrain.gd` | `tests/test_terrain.gd` (40 checks) |
| Geology: deterministic `layers_at(x, z)` built from the quarry's own formations, topsoil split into topsoil/clay, plus `default_strata` and all material data in `data/geology.json` (hardness, repose, `units_per_m3`, sound set) | `scripts/terrain/geology.gd` | contiguity, all 8 materials present |
| Per-vertex storage is only `dug` and `loose[material]`; natural ground is never stored | terrain | a dug 64 x 64 field snapshots to ~1.7 k characters |
| **Hardness**: shovel scoops loose and soft ground and is stopped by rock (`blocked_by`, chink); pickaxe/hammer **break** hard ground into loose rubble in place (no volume change) which a shovel scoops | terrain | `test_terrain.gd` |
| **Volume is conserved** (dig returns exactly what it removed, deposit adds exactly what it is given, slumping only moves material) | terrain | `test_terrain.gd`, `test_terrain_strike.gd` |
| Locks and footprints: `lock_rect`, `unlock_rect`, `lock_ring`, `flatten` | terrain | `test_terrain.gd` |
| 8-material shader (weights in COLOR/UV/UV2), flat projection on gentle ground and one side projection only on steep faces | `assets/shaders/quarry_terrain.gdshader` | compiles; **cost not measured** |
| Synthesised digging sounds (`tools/make_sfx.py`) and one audio entry point `DigAudio.play(event, material, pos, intensity)` | `scripts/terrain/dig_audio.gd` | each material plays its own set, blocked plays the chink |
| On-foot arena (`TerrainArena.bat`) | `scripts/terrain/terrain_arena.gd` | `test_terrain_arena.gd` |

## Integration into the live quarry

1. **Terrain as the live ground** (`scripts/terrain/live_terrain.gd`, `tests/test_live_terrain.gd`). The filled quarry's ground is the terrain: people, vehicles and workers walk on it,
   the topsoil formation's colliders sit on the rays-only layer 32 and their skins are hidden. Only the marked excavation (`dig` rect) is unlocked. The formation columns remain
   the **bookkeeping**: a cut column lowers the ground under it (border vertices follow the lower column so lanes keep their width; pit-level floors and haul ramps are matched), and
   a hand-dug column is given up in the bookkeeping when its footprint is a whole tier down (`settle_columns`). Verified by the loaded-truck haul test.
2. **Player digging** (`main._terrain_strike`, `tests/test_terrain_strike.gd`). Swings dig the terrain: shovel scoops, ground harder than the tool chinks, pickaxe/hammer break rock into
   rubble (the pick also pulls loose rubble), volume -> units with a carried remainder (`terrain_rem`; nothing created or lost), the dig sound follows the material.
3. **Buckets instead of a bag** (`scripts/bucket_view.gd`, Blender `bucket`): you start with the pail, carry any number of buckets (18 each; the backpack upgrades make each bucket bigger), the
   pail in view shows its load, every full bucket slows the walk a little, E at the starter box dumps one bucket (hold E for all), the box holds 100 and shows its contents when aimed at, and
   it empties its loose dirt into the Cash Hopper by itself (`business.starter_feed`; stone, coal and ore stay for the crusher chain). `tests/test_buckets.gd`.
4. **Excavator** (`main._excavator_dig_terrain`, `tests/test_excavator_terrain.gd`): the bucket bites the highest ground of the column it works (so a column is taken down evenly), volume -> cargo
   units with a per-vehicle remainder, and the bookkeeping follows. Crews, trucks, the companion and rigs still use the column bookkeeping, which lowers the terrain through the same hook.
5. **Saves** (`tests/test_terrain_save.gd`): the save holds `terrain` (only changed vertices, compressed), `terrain_rem` and `veh_rem`; an old save loads as the columns say.

6. **Loader and bulldozer** (`tests/test_loader_terrain.gd`): the loader scoops heaps and soft ground off the terrain into its bucket and can tip a load on the ground as a heap; the
   bulldozer pushes loose material into its blade (as "soil", loose material only). Volume is conserved through every step. The older soil field (the tutorial's cells) still exists beside it.
7. **Navigation** (`tests/test_terrain_nav.gd`): the pit's navmesh is baked from the terrain (a cached triangle list per chunk, only changed chunks rebuilt, so collecting costs milliseconds),
   not from the column boxes.
8. **Staff and the dinosaur** (`tests/test_staff_terrain.gd`): crew strikes and the dinosaur's club bite the highest ground of their column with the same damage per unit as before; units fall as loose
   pieces; the bookkeeping follows. Mineral pockets are handed out when a dig gives a tier up.
9. **The bucket is a hotbar item** (slot 4): the pail in hand shows its load, the slot shows how many buckets you carry, left click pours a bucket onto the ground or into the box.
10. **Performance on this PC** (Radeon RX550, 1280x720, `tools/perf_probe.gd`): 57 fps with the terrain against 58 without while digging (vsync bound); draw calls 568 vs 357; the 31 ms 95th-percentile
    frames are in the base game with the terrain off too. Far chunks are culled beyond 190 m.

## Not done

* The scripted rubble piles (legacy yard only) and the tutorial's older soil field are still separate from the terrain.
* Contracts and stage progress still count column units; the terrain feeds them through the bookkeeping (a tier is given up when its footprint is a whole tier down).
* Workers still choose what to mine from the column bookkeeping (they dig the real ground, but the target choice is the old one).
* Structures are locked (not flattened) where they stand.
* A frame-time report with a larger quarry dug out, and on a slower machine, is still to be measured.

## Needs your visual / hardware test

How it looks (strata colours in hole walls, the terrain shader on integrated graphics), the feel of break-then-scoop, how loud the sounds are, slump speed, frame time at quarry scale (99 k
vertices, 96 collision blocks; building the terrain at start costs about 2 s on this machine), particle look, the bucket in view.

## Heaps by material (PileModels)
* Soil lies as a smooth rounded **cone** (the spoil heap, `PileModels.dirt_mesh`); rock lies as a **rocky mound of blocky chunks** with loose pieces at the foot (`rock_mesh`, used by the rubble piles); ore is the same mound with bright mineral chunks (`ore_mesh`).
* In the terrain, the angle of repose already differs per material (soil 36 degrees, rock 45-49). Loose rock and ore are now also *drawn* rough (coarse 1 m chunk jitter that grows with the rubble's depth, `QuarryTerrain.vheight_vis`); collision stays smooth. Soil, clay and gravel stay smooth.
* Still the old look: the tutorial's soil field (flat stepped cells with vertical faces) and the column formations' block faces.
