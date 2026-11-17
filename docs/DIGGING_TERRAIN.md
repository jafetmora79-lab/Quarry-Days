# Real digging for the quarry: status

Branch `claude/quarry-digging-integration` (started from `feature/intro-world-ui-polish`, NOT from the 274-commit-old prototype branch: the quarry has since become a filled
244 x 92 m plain with 4 m formation columns, excavator, crews, contracts and saves, so the prototype was ported forward instead). Nothing is merged into another branch.

## What exists now (measured by tests)

| Piece | Where | Tests |
|---|---|---|
| Heightfield terrain over any world rectangle, 0.5 m vertices, 16-cell mesh chunks (max 3 rebuilt a frame), **one HeightMapShape3D per 32 x 32-cell block** refreshed only when dirty (~15 Hz) | `scripts/terrain/quarry_terrain.gd` | `tests/test_terrain.gd` |
| Geology: deterministic `layers_at(x, z)` built from the quarry's own formations (so every resource stays where the quarry puts it), topsoil split into topsoil/clay, plus `default_strata` and all material data in `data/geology.json` | `scripts/terrain/geology.gd` | contiguity, all 8 materials present, surface = topsoil |
| Per-vertex storage is only `dug` and `loose[material]`; the natural ground is never stored | terrain | snapshot of a dug 64 x 64 field is ~1.7 k characters |
| **Hardness**: `dig(..., max_hardness, mode)`. Shovel (hardness 0) scoops loose and soft ground and stops at rock with `blocked_by`; pickaxe/hammer **break** hard ground into loose rubble in place (no volume change) which the shovel then scoops | terrain | shovel stops exactly at the limestone surface; pickaxe breaks, shovel scoops; pickaxe cannot break iron+ harder than itself, hammer can |
| **Volume is conserved**: dig returns exactly what it removed, `deposit` adds exactly what it is given, slumping only moves material, `flatten` (construction) reports its change | terrain | dig/deposit round trip, break+scoop, slump, arena accounting |
| Locks and footprints: `lock_rect`, `unlock_rect`, `lock_ring`, `flatten` | terrain | locked ground cannot be dug, unlock works |
| Collision follows the mesh, checked by ray on and beside the block seams | terrain | worst error 7 mm |
| Save/load: only changed vertices, compressed; old saves have no block and load as untouched ground; loading twice duplicates nothing | `snapshot()` / `restore()` | totals, every loose material, sampled heights |
| 8-material terrain shader (weights in COLOR/UV/UV2), flat projection on gentle ground, one side projection only on steep faces, materials sampled only where their weight is above a threshold | `assets/shaders/quarry_terrain.gdshader` | compiles (windowed run, no shader errors); **cost is not measured** |
| Synthesised digging sounds (no recordings): `chink` (blocked), `thud_soil`, `squelch_clay`, `crunch_gravel`, `crack_rock` x3 variants each, `pour_dirt`, `pour_rock`, `scrape_metal` (loop) | `tools/make_sfx.py` -> `audio/dig_*.wav` | all files exist |
| One audio entry point `DigAudio.play(event, material, pos, intensity)`: 8-player pool, pitch +-6 %, per-event cooldown, event log for tests | `scripts/terrain/dig_audio.gd` | each material plays its own set, blocked plays the chink, a held button is swallowed |
| On-foot arena over the real terrain (real tool models, hints, particles, volume HUD) | `TerrainArena.tscn`, `scripts/terrain/terrain_arena.gd`, `QuarryDays.exe -- --terrain-arena` | `tests/test_terrain_arena.gd` |

## What is NOT done (the live quarry still digs the old way)

The live game (formation columns, excavator, crews, workers, companion, contracts, saves) is untouched. Replacing it is the large remaining job, in the brief's order:

* A. terrain as the live ground (formations' visuals/collision off, placement/conveyor/nav read the terrain, structures stamped and locked);
* B. player digging in the live game (shovel/pickaxe/hammer through `dig`, converting volume to bag units at the boundary with a carried fractional remainder, `units_per_m3` in `data/geology.json`);
* D. loader, excavator and truck on `cut_box` / `deposit` with volumes; contracts, stage progress and the Production Overview reading terrain volume instead of columns;
* E. workers and crews digging real ground; navmesh fed from the terrain with a debounced rebake;
* F. saves wired into the game save (`phase5` block), performance pass on real hardware.

Each of these touches systems with their own test suites; they should land one at a time with the old suites green between steps.

## Needs your visual / hardware test (never measured here)

How it looks (strata colours in hole walls, the shader on integrated graphics), the feel of break-then-scoop, how loud and how stylised the sounds are, the slump speed on a
large pile, frame time at quarry scale (the full dig lot would be about 448 x 192 cells = 86 k vertices and 84 collision blocks), and the particle look.

## Defaults assumed for the owner's open questions

Yard and roads locked; piles stay scripted for now; workers keep using deposit stock; strata topsoil / clay / gravel / limestone with coal, iron, copper and gold from the formations;
tools shovel (0), pickaxe (up to iron), hammer (all), loader bucket (0), excavator bucket (1); sounds synthesised and retro.
