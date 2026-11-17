# Handoff: bring real digging to the whole quarry (layers, tools, sounds)

For the Claude that builds the Quarry Days quarry. Read this fully before touching code.

## 0. Where things stand

- The owner played the digging prototype and **likes it a lot**. Keep its feel and controls. This is not a redesign: it is scaling the prototype up into the real quarry and adding material logic.
- Branch with the prototype: **`claude/quarry-dig-prototype`** (commit `b4cf87b`). It is based on `claude/quarry-phase-4-visual-overhaul` (Phase 4: THE VEIL art + sustainable deposits). Start your branch from the prototype branch, e.g. `claude/quarry-digging-integration`. Do not merge anything into another branch and do not open a pull request; the owner decides.
- The owner's rules (they apply to you):
  - Godot 4.3, GL Compatibility renderer, Windows only, integrated graphics.
  - Preserve the retro low-poly pixelated THE VEIL look (nearest filtering, Greyhaven palette).
  - **Never generate screenshots, renders or videos.** The owner does all visual testing. Anything visual you cannot measure must be reported as "needs your visual test", never as "fixed".
  - Do not break saves from Phases 1-4. Commit each finished feature separately. Run short headless tests with accelerated time.
  - THE VEIL's repository is read-only reference.
- What is **proven** (headless, 32 checks in `tests/test_dig.gd`) and what is **not**:
  - Proven: collision follows the deformed ground; volume moves exactly (nothing created or lost); bucket/shovel/box capacities; pile slumping; rock digs as rock; enter/exit loader; chunk rebuild cost (about 0.9 ms per chunk, about 1 ms collision refresh for 81x81 vertices on this container's CPU); terrain shader compiles under software OpenGL.
  - **Not verified by anyone:** how it looks, loader pitch on slopes, particle look, shovel model, real frame rate on integrated graphics, how it feels at quarry scale.

## 1. What the prototype contains (read these files first)

| File | What it is |
|---|---|
| `scripts/proto/dig_terrain.gd` (`DigTerrain`) | The deformable ground. Heightfield, layers, `cut_box`, `cut_disc`, `deposit`, `relax`, chunk meshes, collision. **The core to extend.** |
| `assets/shaders/dig_terrain.gdshader` | Triplanar pixel shader, dirt/rock blended by vertex colour R. |
| `scripts/proto/dig_loader.gd` (`DigLoader`) | Front loader that cuts as you drive into material and pours out of the tipped bucket. Reuses `VehicleModels.loader` (Phase 4 model). |
| `scripts/proto/dig_test.gd` | Test arena: player shovel, collection box, particles (visual only), HUD, input. Shows how everything is wired. |
| `tests/test_dig.gd` | Headless tests. Copy its patterns (conservation checks, collision ray checks, autopilot driving). |
| `DigTest.tscn`, `main.gd` `--dig-test` hook | How the arena is launched (`DigTest_Prototype.bat`). |

### Key design facts (keep these invariants)

1. **Heightfield, not voxels.** Vertices every `CELL = 0.5` m. Each vertex stores layer thicknesses above a fixed `BEDROCK = -2.0`. Height = `BEDROCK + base + dirt + rock`.
2. **Volume is conserved.** Digging calls `_take(k, t)` which removes thickness and returns what it removed; the digger holds exactly that volume (m3). Dumping calls `deposit(...)` which adds exactly that volume. `total_volume()` + everything carried must stay constant. **This is the main correctness property; every new feature gets a conservation test.**
3. **Loose material first.** `_take` removes loose (piles, dumped loads) before natural `base` ground. That is what makes a rock pile dig as rock.
4. **Slumping moves material, never makes it.** `relax()` shifts material to lower neighbours when a slope exceeds the repose angle (dirt about 36 degrees, rock about 49 degrees). Budgeted per frame (700 vertices) via an `active` set.
5. **Collision follows the mesh.** One `HeightMapShape3D` on a `StaticBody3D` scaled `(0.5, 1, 0.5)`. Verified headless that a ray hit equals `height_at()`. Collision refresh is throttled to about 15 Hz when dirty.
6. **Particles are cosmetic.** Quantities are numbers; chunks and dust are `CPUParticles3D` bursts, capped at 14 emitters, and never carry material.
7. Bucket/shovel contents are tracked as **volume per material**, not as individual bodies. Do not simulate individual grains (no compute shaders in the Compatibility renderer; it would be unplayable on integrated graphics).

## 2. The job

Make the **real quarry** ground diggable, with **layers** and **material logic**, without breaking Phases 1-4. In order:

### 2.1 Scale the terrain to the quarry

- Real footprint: the pit/yard is about 58 x 58 m (`Quarry floor`, centred at origin), plus the east expansion at x 29..49, z -13..13 (`Expansion floor`). At 0.5 m that is roughly 160 x 120 vertices. The prototype has 81 x 81.
- **Split collision into per-chunk `HeightMapShape3D`s** (e.g. 32 x 32 cells), and refresh only dirty chunks. One big shape that is rebuilt whole will cost 3+ ms per refresh at quarry size. Meshes are already chunked (16 x 16 cells).
- Add a world-space chunk grid (not one array of `N x N`), or pad the arrays. Decide and keep `to_grid`/`vertex_pos` consistent.
- Keep the expansion locked (not diggable, not slumping) until the Automated Business milestone opens it, the same way `main.gd` gates it today (`expansion_gate`, `_set_expansion`).
- The old `Quarry floor` / `Expansion floor` static boxes become the invisible fallback or are removed. Their uses to fix: `main.gd` `_on_ground()`, `placement_valid()`, `conveyor_valid()` all test `body.name == "Quarry floor" or body.has_meta("ground")`. Give the terrain body `set_meta("ground", true)`.
- Terrain meshes must exclude the old textured floor art (`QuarryArt._ground()` in `scripts/art/quarry_art.gd`). The shader replaces `QuarryFloor`/`ExcavatedDirt` material use for the ground.
- Initial heights should encode the existing look: the pit floor lower than the yard, the haul roads, the entrance ramp. Do **not** change playable boundaries, resource locations, construction zones or vehicle access.

### 2.2 Protect structures and roads

Digging under a crusher, the office or the garage must not happen.

- Keep a `locked` mask (it exists: `locked[k]`). Lock vertices under buildings, the equipment garage, parking bays, the storage crate, machines and conveyors, plus a margin.
- On placing or moving a structure (`_place_ghost`, `_finish_relocation`), stamp the footprint flat and lock it; on selling, unlock.
- Roads and the processing yard: either lock them, or let them be dug but have workers/vehicles cope (decide with the owner; default to locked yard + roads, diggable pit and spoil areas).
- Placement validity must reject steep or uneven ground (slope check) and ground that is not flat enough. Do not let machines float or sink.

### 2.3 Layers (geology)

The prototype has three layers (`base`, loose `dirt`, loose `rock`). Generalise it.

- Proposed strata from the top down: topsoil, clay, sand/gravel, weathered limestone, solid limestone (bedrock-hard), with coal and iron seams as veins in the limestone. Make the table data-driven in a JSON file (`data/geology.json`) so the owner can tune it.
- **Do not store every layer thickness for every vertex.** Better: a deterministic `geology(x, z, depth) -> material` function (layer depths plus noise, seeded) for the natural ground, and store only the **dug depth** and the **loose layers** per vertex. That keeps saves small and makes layers appear naturally as you dig down.
- Per material, define: `hardness`, `dig_rate`, `repose_slope`, `unit_value` (see 2.6), `colour`/texture, `sound_set`, `particle_colour`, `required_tool_tier`.
- Shader: extend `dig_terrain.gdshader` to blend more than two textures (vertex colour RGBA = weights for up to four materials; add a second vertex attribute if more are needed). Textures come from `tools/qd_textures.py` in THE VEIL manner (Greyhaven palette, 64 px/m, nearest filter). Add new ones there (e.g. clay, gravel, topsoil); keep palette discipline. The cliff walls already show layered rock, so match the order and colours.
- Digging down reveals the next layer visibly. Hole walls should show the layers (triplanar on steep faces already helps).

### 2.4 Tools, hardness and sound logic (the owner specifically asked for this)

The rule: **what you hit decides what happens and what you hear.** Implement as one table plus one event function, not scattered `if`s.

Tool tiers (propose, confirm with the owner): hand shovel (tier 1), pickaxe (tier 2, already exists in the player), loader bucket (tier 2), excavator bucket if one is added later (tier 3), rock breaker/hammer (tier 4).

Digging result by material vs tool:

| Situation | Result | Sound | Visual |
|---|---|---|---|
| Shovel into soil/clay/sand | scoops volume | soft "shff"/thud (clay: wet squelch) | dirt chunks + dust |
| Shovel into gravel | scoops, slower | crunch | grey chunks |
| **Shovel hits rock** (hardness above tool) | **digs nothing**, tool bounces, swing is cancelled | **bright metallic "chink"** (high, short, with a faint ring) | spark flecks + a puff of dust; hint text "Too hard - use a pickaxe" |
| **Shovel digs soil down to rock** | the cut stops at the rock layer | **one "chink"** the moment the blade reaches it | same as above |
| Pickaxe into rock | breaks it into **loose rock volume** (rock layer becomes loose rock) | heavy "clack"/crack, louder with each hit | rock chips |
| Loader bucket into soil | cuts and fills (as now) | low scrape/rumble that rises while loaded | dirt spray |
| Loader bucket into rock | **cannot cut**; the loader shudders and slows | grinding scrape + **clang** | sparks |
| Pouring | stream of material | pitch by material, hiss for dirt, clatter for rock | falling chunks |
| Dropping a load into the box/truck | thump scaled by volume | rocks = clatter, dirt = thud | dust |

Implementation guidance:

- Add `material_at(x, z, y)` and a hardness check inside `cut_disc`/`cut_box`: if the top material's hardness is greater than the tool tier, return an empty result **plus a flag** (`"blocked_by": material`). The caller decides the sound.
- One audio entry point, e.g. `DigAudio.play(event, material, pos, intensity)`, with events like `dig`, `blocked`, `pour`, `drop`, `scrape`. Use a pool of `AudioStreamPlayer3D` (about 8), random pitch +-6%, a per-event cooldown (about 120 ms) so held buttons do not machine-gun, and volume scaled by `intensity`.
- **There are no recordings.** The project's four existing sounds (`audio/*.wav`) are synthesized, and the generator is not in the repo. Add a small deterministic script `tools/make_sfx.py` (numpy, writes 16-bit mono WAV, 22.05 kHz) and commit the WAVs and `.import` files. Recipes to start from:
  - `chink`: 8 ms noise burst, plus two decaying sines about 2.2 kHz and 3.4 kHz (decay about 80 ms), slight pitch drop.
  - `thud_soil`: low sine about 90 Hz decaying in about 120 ms, plus filtered noise.
  - `squelch_clay`: noise through a low-pass whose cutoff sweeps down, with a short wet click.
  - `crunch_gravel`: 4-6 short noise grains over about 150 ms.
  - `crack_rock`: noise burst, a 600 Hz body decaying in about 160 ms, plus a high click.
  - `scrape_metal`: band-passed noise, looped, modulated by speed.
  - Make 3 variants of each so repeated hits do not sound identical.
- Keep the existing `pick_hit.wav` for the pickaxe if the new sounds are not ready.

### 2.5 Hook up the vehicles and the loader

- `DigLoader` (prototype) maps onto the real `QuarryVehicle` loader (`scripts/vehicle.gd`) and the Phase 3 `QuarryFleet`. Bring over: `cut_box` while the bucket is lowered, volume in the bucket, pour spot, tilting the body model to the slope (`_follow_ground`).
- **Replace the scripted "rubble piles"** (`data/vehicles.json` `piles`, `pile_nodes`, `QuarryFleet.scoop_pile`) with real terrain piles, or keep piles only as a pre-built spoil heap that is generated into the terrain at start. Decide with the owner; keep the loader useful on day one.
- The dump truck: loads from the loader's pour, unloads at a storage crate/crusher hopper/output storage. It currently counts units; give it volume with a conversion (2.6).
- Vehicles must not tip or get stuck in holes forever: add a recovery rule (they already have R recovery and a fall rescue in `vehicle.gd`; make recovery pick a safe flat spot now that the ground can change).
- Hole safety for the player: repose caps slopes at 36-49 degrees, `QuarryPlayer` climbs about 45 degrees. Test climbing out of a 2 m hole. If it fails, widen hole walls or add a "climb out" assist.

### 2.6 Reconcile with the existing economy (important)

Everything in the game today counts integer units: `limestone`, `coal`, `iron_ore`, `crushed_stone` in the backpack, storage crate, crusher hopper, output storage, workers and sales. Terrain deals in m3.

- Define a conversion in `data/economy.json`, e.g. `units_per_m3` per material, and convert **only at the boundary** (when volume enters/leaves a unit-based container). Keep a fractional remainder inside the carrier so rounding can never create or destroy units.
- A piece/cube world: the existing `ground_pieces` (loose rock pickups) and deposit stock/regrowth (Phase 4, `QuarryState.ensure_deposit`, `mine_yield`, `regrow_deposits`) stay valid until you replace them. **Phase it** (below): do not delete them in step one.
- The player's backpack/bag (`state.inventory`, capacity 18) and the shovel: decide whether a shovelful converts to units immediately (backpack feel) or stays as volume until dumped. Default: shovel volume stays on the shovel until thrown into a container, as in the prototype.
- Sales, prices, upgrades, milestones, wages must keep working unchanged. The owner's balance: manual mining must still let a broke player recover (Phase 4 "quarry face" rule). With real digging that is natural: topsoil is always diggable by shovel and is sellable; keep that guarantee and test it ($0, nothing loose, still able to earn).
- Employees (miners, haulers, operators, clerks) are built on units and walk with `VeilRig` animation. First pass: leave their logic alone, with miners still using deposit stock. Second pass: let miners/haulers dig real terrain (a worker "dig" action using `cut_disc`) only after the player-side system is stable and tested.

### 2.7 Navigation and workers

- The navmesh is baked from collision boxes (`main.gd` `_rebake_nav`, `cell_size 0.25`, `agent_max_climb 0.25`, synchronous, about 10-40 ms). A heightfield must be fed into the bake (`NavigationMeshSourceGeometryData3D.add_faces` from chunk meshes) or workers will not path over it.
- **Debounce rebakes**: do not rebake per scoop. Rebake once after digging stops for about 1.5 s, only when a changed region crosses a size threshold, and keep workers safe if the ground they stand on disappears (they have stuck recovery; test that a worker beside a new hole recovers).
- Agent slope limit: set `agent_max_slope` so workers do not try to climb the steepest piles.
- Keep the placement/nav tests: workers must still reach the sales booth, deposits, storage, crushers, expansion.

### 2.8 Save/load

- Save only what changed: for each modified vertex, its index and values (dug depth and loose layers), compressed (e.g. `PackedFloat32Array` -> `compress` -> base64) inside a new `phase5` block next to `phase2`/`phase3`. Old saves must load with default terrain.
- Save must include: the terrain deltas, shovel/bucket/truck volumes per material, and fractional remainders.
- Required test: dig, pour, save, reload, assert `total_volume()` and every container equal before/after, collision rays match, and loading twice does not duplicate anything.

### 2.9 Performance

- Target: smooth on Windows integrated graphics. Budgets from the prototype: at most 3 chunk rebuilds per frame; collision refresh at about 15 Hz for dirty chunks only; slump budget 700 vertices per frame; particle cap 14 emitters.
- Triplanar shader samples each texture three times (six fetches for two textures). With four materials that is twelve. Consider biplanar, or triplanar only on steep faces and flat UV on gentle ground. **Measure on real hardware; ask the owner for a frame-time report** because it cannot be measured here.
- Far chunks do not need collision (workers/vehicles only touch near ground) but keep it simple first.
- Do not run `relax` over the whole map; keep the `active` set.

## 3. Suggested order (commit each step separately, all tests green between steps)

1. **A. Terrain replaces the floor**, no digging allowed yet (everything locked). Keep Phase 1-4 suites green. Per-chunk collision. Placement/nav use the terrain. This is the riskiest step; prove it before anything else.
2. **B. Player shovel + pickaxe digging** on unlocked pit/spoil areas, single layer pair first, **with the material table and the chink logic and the sound script**. Hand tool to hole to backpack/box.
3. **C. Layers**: geology function, 4-5 materials, shader, data file.
4. **D. Loader and truck on real terrain**, piles, conversion to units at containers.
5. **E. Workers on terrain**, deposits as veins (optional), conveyors and structures interplay, locked footprints.
6. **F. Save/load**, performance pass, README/CHANGELOG, Windows ZIP.

## 4. Tests you must write (extend `tests/test_dig.gd` style)

- Volume conservation through: shovel, pickaxe, loader, truck, box, crusher hopper, storage; including after save/load and after slump.
- Hardness: shovel on rock yields 0 volume and reports `blocked_by = rock`; pickaxe on the same rock yields loose rock; shovel soil-to-rock stops exactly at the rock surface.
- Sound events fire for each case (assert the event, not the audio).
- Collision ray == `height_at` after deformation, on every chunk edge (seams).
- Structures: footprints locked and flat; placement rejected on slopes; selling/relocating unlocks and re-locks correctly.
- Navigation: after a dig and a debounced rebake, workers still reach their targets; a worker next to a fresh hole recovers.
- Broke-player recovery, still true with real digging.
- All earlier suites (`test_quarry`, `test_phase2`, `test_phase3`, `test_phase4`, `test_dig`). Several earlier tests assume a flat floor at y = 0 (placement, loader, vehicle, nav, east expansion); update them only where flat-ground is the assumption, and say so in the commit.

## 5. Known prototype shortcuts and risks (do not trust blindly)

- The prototype terrain is one 81 x 81 array with a single collision shape. Not enough for the quarry (2.1).
- Layers are only `base`/`dirt`/`rock` and the shader blends only two textures.
- Relaxation uses 8 neighbours and a fixed `0.25` transfer factor; very large excavations may slump slowly or look stepped. Tune on the real map, with the owner watching.
- Slumped natural ground becomes loose material (that is intended, but it changes what a later dig yields).
- Resolution is 0.5 m, so holes are slightly blocky. Do not drop below 0.5 m without measuring cost.
- Collision is `HeightMapShape3D` under GodotPhysics3D (the project does not enable Jolt). If the owner switches to Jolt, re-verify the scaled heightmap.
- Hand-shovel reach is 5 m and aiming at the box wall throws into the box; both are prototype conveniences.
- The prototype player/loader are not connected to the economy, saves or workers.

## 6. Open questions to ask the owner before building the parts that depend on them

1. Which tools exist at launch (shovel, pickaxe, loader bucket, a future excavator, a rock breaker)?
2. Should the yard and roads be diggable, or locked (recommended: locked)?
3. Do rubble piles become real terrain piles, or stay as scripted piles for now?
4. Do workers dig real terrain, or keep using deposit stock for now?
5. Is the strata list in 2.3 right (topsoil, clay, gravel, weathered limestone, solid limestone, coal/iron seams), and should digging be able to reveal coal and iron by depth instead of scripted deposits?
6. How loud and how stylised should the sounds be? (Keep them synthesized and retro unless told otherwise.)

## 7. Helpful commands

```
godot --headless --import
godot --headless --fixed-fps 60 -s tests/test_dig.gd
godot --headless --fixed-fps 60 -s tests/test_phase4.gd        # and test_quarry, test_phase2, test_phase3
xvfb-run -a godot --rendering-driver opengl3 --path . res://DigTest.tscn --quit-after 240   # shader/GL compile check only, no screenshots
godot --headless --export-release "Windows Desktop" build/QuarrySimulator.exe              # needs export templates 4.3.stable
```

Report honestly: list what is measured by tests and what needs the owner's visual or hardware testing.
