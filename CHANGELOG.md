# Changelog

### Ground gaps and the objective window
- **Holes round the quarry fixed:** the topsoil field's outer edge no longer wobbles (it pulled back from the grass and left a strip of void showing the background colour), and the grass now covers everything outside the field exactly - the old cut-out did not match the soil, which left a whole band bare along the south side. `tests/test_ground_cover.gd` samples the ring round the field.
- **Objective window:** the stage bar is the average of its requirements with a percentage, "Clear Grandpa's overgrown site" counts real weeds and rubble (14/40, not 0%), the cleanup and each open area contract get their own bar, and percentages round up so the first bit of work shows (never 100% before the end). `tests/test_objective_progress.gd` keeps them honest.

### Menus, HUD and walking polish
- **Conversations:** while Grandpa or a new hire talks (and during the opening shots) the HUD plates, objective, hint bar and prompt fade out, the dialog sits at the bottom edge, and nobody is outlined.
- **No outline on people:** workers and Grandpa are never highlighted (it spoiled the character art).
- **Cleanup markers:** weeds and rubble heaps pulse in a red outline with a thin red ring and a faint red beam instead of the yellow beam and disc.
- **Buttons:** one new set of raised keys (brown default, amber for the main action, muted red for dangerous ones) across every menu.
- **Pause menu:** rebuilt as a compact column (RESUME, SAVE / LOAD, MAIN MENU, music slider with mute, NEW GAME) - the old one ran off the window and cut its button row. Station panels are now clamped to the window.
- **Walking bump fixed:** the ledge-climb check treated a brush against the flat ground as a ledge, lifting the player 20 cm and freezing them for 0.2 s at random spots (this was the "bump" near the quarry entrance). It now reacts only to real walls; `tests/test_entrance_walk.gd` walks the entrance and fence lines to keep it that way. The blueprint quarry also no longer builds invisible ramp curbs.

### Machinery overhaul (branch claude/quarry-machinery-overhaul)
- **Auto crew (J / R3 / AUTO button):** a bought excavator or dump truck can run itself. The excavator digs, swings and loads a truck, crusher, output, storage or the spoil heap; the truck hauls on the nav route (round the soil field too), turns, backs up, tips and returns. It uses the normal dig / dump / transfer code, so nothing is created or lost. Running cost per bucket / trip is `auto_cost` in `data/vehicles.json` ($3-$9). The flag is saved with the vehicle.
- **Belts and crushers:** a lamp on each belt shows active / idle / blocked / disconnected; crushers vibrate and animate at their real processing speed.
- **Deliveries:** stationary machinery arrives on a flatbed with a crate (cosmetic; the order is paid and in inventory at once). K / L3 / SKIP skips any delivery with the same end state.
- **Workers:** idle fidgets (look round, wipe brow); a clerk can be assigned to a sorting table (sorting pose, starts batches).
- **Rigs and breakers:** stabiliser legs, chassis hum / kick per blow, heavy breaker slower and heavier.
- **Sorting table, carts, compressor:** rocks in their own colours and per-mineral trays; carts have turning wheels, lean, tip out and show the player's hands on the handles; the compressor runs, shakes and drives a visible air hose only while an air tool works.
- **First person:** chisels are held and struck with a hammer; every tool stays clear of the camera; each tool's hit sound follows its power and class.
- **Opening:** two establishing shots before the meeting with Grandpa (skippable, once only).
- **Tests:** `tools/run_tests.sh` runs every suite in parallel (about 3 minutes); `--changed` runs only the suites that touch changed files.

### The named cast
- **Every person has their own model:** Grandpa Walter, Dr. Evelyn Marsh and all twelve hireable workers (Rosa, Dmitri, Ines, Nia, Tomas, Hana, Sofia, Bram, Lucia, Felix, Petra, Omar). Each has a distinct face, nose, ears, build, height and posture, plus their own hair, outfit and gear: hard hats, hi-vis, coveralls, ear defenders, glasses, beards and moustaches, tool belts, radios, gloves, a satchel and a cardigan. Built in THE VEIL's pixel low-poly style by `tools/character_cast/` (see its README).
- **Same rig as before:** the existing 22-bone humanoid with the same sockets and bone frames, so every worker animation, tool grip and Walter's cutscenes work unchanged.
- **Workers:** a hire loads the model of their own candidate (`CHR_QD_<Candidate>.glb`). Old records without a candidate keep the profession model and its tint and hat variants.
- **Walter and Dr. Marsh:** they use their own models instead of the recoloured miner and clerk. `_dress_grandpa` and the hair recolouring are gone.
- **Portraits:** the HUD, hiring list and intro dialog show portraits rendered from the same models (`assets/ui/portraits/named/`), so the face in the UI is the person in the yard. Walter's dialog now also shows Dr. Marsh when she speaks.

### Phase 6.3: living business
- **Corner belts:** left and right 90 degree conveyor corners (`kind` on each belt; old saves load as straight). Belts, corners, crushers, outputs, the storage crate and rig bins all expose ports, and a new piece snaps end to end onto the nearest free port. Material moves round the bend (items follow the L) with no loss or duplication.
- **Storage visuals:** the heap in the storage crate and in output bins shows the dominant stored material (coal charcoal, iron rust, copper orange, gold, stone grey) with a label listing the contents.
- **Employees:** every hire gets a personality (friendly, quiet, enthusiastic, serious, humorous) and a look variant (hair, skin tone, height). They come in through the service gate, walk over to the player when the player is free, and a short skippable conversation lets you keep or change their name. A busy player is never interrupted. Name, personality, look and the introduction state are saved; older saves never replay it.
- **Deliveries:** vehicles queue out of sight if someone stands at the gate, stop for people on the way, and fall back to a spot on the apron when every garage bay is blocked. Stationary machinery (crusher, output, belts, corners) is ordered at the kiosk and delivered to a construction inventory, then placed with the blueprint system; the order screen shows real stats and "PLACE (n)" for delivered items.
- **Ground:** the pit zone floor no longer has hairline cracks between tiles (the pale lines), and the pit zone cliff walls are smoother and overlap at their corners.
- Tests: `tests/test_belts.gd`, `tests/test_living.gd`.


### Character animation overhaul, phase 1
- **Tool grips:** tools are attached through `VeilRig.add_tool()` with a per-tool config (`TOOL_CFG` in `worker.gd`). The grip is measured from the lowered arm pose that is actually animated, not the imported A-pose, which fixes the tilted, floating pickaxe. The rig is now built after the worker enters the scene tree, because a skeleton outside the tree gave stale bone numbers.
- **Pickaxe:** both hands are solved onto the shaft with a light two-bone arm IK. The swing has a recovery spring, an anticipation draw-back, a fast strike and an impact pose on the exact frame the hit lands (`worker._act` sets `anim_phase = 1.0` as the strike fires). Timing and damage callbacks are unchanged.
- **Walking:** a planted-foot leg cycle (near-linear stance, knee flexion, toe-off), a stride that grows with speed, hip and torso counter-rotation, head stabilisation, a lean into turns and a body-weight bounce. Walking only plays while the worker is actually moving.
- **Carrying:** the load is parented to the skeleton, rides in front of the chest and is held by both arms with IK. It is visible exactly while the worker owns it.
- **Stowing:** a miner slings the pickaxe on the back when carrying, resting, picking up or off shift, and takes it back with a smooth move (no teleport).
- **Other workers:** the hauler reaches to the ground for pickups, and the operator puts both hands on the control panel and pulls the lever on the start action.
- **First-person:** simple stylised hands and sleeves hold every tool (one hand on the hammer, two on the pickaxes, drill and jackhammer).
- New test: `tests/test_animation.gd`.


### Service gate and deliveries
- The garage has a big roll-up door in its back wall, opening onto a tunnel-mouth service gate in the south ring. The door rolls up by itself when anyone comes near.
- New machinery is driven in through the gate by a delivery driver, who parks it in its bay, steps out and walks away. The machine cannot be entered until it is parked.
- Newly hired workers step out of the service gate and walk in.
- New test: `tests/test_delivery.gd`.


## Quarry OS, office and building overhaul (claude/quarry-os-buildings)
- QUARRY OS: the office computer is a windowed 90s-style desktop (`scripts/quarry_os.gd`, `quarry_os_window.gd`): teal pattern wallpaper, 32 px shortcuts, taskbar with start button, window buttons and the in-game clock, drag / minimise / restore / close / raise, windows clamped to the desktop, pixel cursor (integer scaled). Eight applications host the existing management pages on real game state (new Sales page uses `business.sell_material`). Art in `assets/ui/os/` (generated by `tools/make_os_art.py`, replaceable, with drawn fallbacks).
- E at the desk glides the camera to a physical CRT monitor (0.7 s), then opens the desktop; leaving glides back (0.55 s). Movement and tools are suspended throughout; clicks on the desktop never swing the tool.
- Office furnished (desk, CRT, keyboard, lamp, bookcase, maps, rug); house gets kitchen, table, bathroom; storage shed and workshop get roof frames, louvres, crates, drums, bins; all buildings get rafter tails, gutters, ridge caps, barge boards, porch awnings with lanterns; doors get hinges, panels, creak/thunk sounds (synthesized), 0.5 s swing.
- Tests: `test_quarry_os` (desktop, windows, clock, camera, walkability flood-fill of every building, layouts at 4 window sizes); older card-grid assertions updated.

## Typography overhaul and spoil heap (claude/typography-spoil-pile)
- One typographic system, all fonts packaged (SIL OFL): Pixelify Sans (titles, signs, buttons, equipment/stage names), Silkscreen (HUD labels, day/time, minimap), Nunito Sans (dialogue, letters, descriptions), VT323 (machine readouts). Resources `assets/fonts/qd_*.tres`, set as the project default font; Atkinson removed.
- `QuarryTheme` gains `display()/hud()/mono()`, `hud_label()/mono_label()` and size tokens (TITLE, SECTION, DIALOG); `PixelLabel` uses Pixelify for signs and VT323 for readouts (`readout = true`); pegboard tool names rendered at 2x texture size; letters 20 px at 1080p; dialogue body 20 px.
- Spoil heap is a square highlighted amber pad whose pile grows with soil dumped (cube-root, full at 500). New `test_spoil_pile`.

## Quarry Days — world polish (home, sleep, intro, hangar view, walls, ground)

- **Walls that looked like flat grey slabs were never dressed:** the engine renames duplicate nodes, so the cliff-dressing code only matched the first piece of each name. Every ring cliff and low rim is now recognised by its box and gets the rough natural cliff mesh.
- **The mismatched yellow ground patches** came from the VEIL dirt-road and gravel materials laid over the yard. Roads and the yard now use the same calm ground texture as the floor (with a tiny tint change), so there is no patchwork.
- **Hillside rock:** blocks have no visible chamfer seams any more, and the rock uses the lighter cliff palette so it matches the ring.
- **Home and sleep:** a small house next to the garage (`HOME_POS`) with a bed. E on the bed (after 17:00, or in the small hours) fades out, jumps to 07:00, settles wages, **saves the game** and shows "Good morning". Money, bag, staff and every excavated section are untouched; machines simply rest. A gentle "it's getting late" hint appears each evening after 20:00.
- **Intro:** the letter now mentions the house, and a second card, "YOUR FIRST DAY", lists the first steps (hammer, selling, upgrade board, sleeping, the cleanup and Walt's gift).
- **Hangar view:** the roof lifts off while you drive a vehicle inside the hangar, and the chase camera is pulled in by a ray so it can never sit behind a wall (it was behind the hangar's back wall, which is why you could not see the vehicle until you left).
- **Tests:** `tests/test_world_polish.gd` (24 checks); the access and Phase 5 tests close the second intro card.

## Quarry Days — natural environment pass (not yet visually confirmed)

Priority: one continuous rock surface, then the simple background. No visual check was made (none was requested); the checks below are automated only.

- **Continuous rock:**
  - New `natural_strata` texture generator: wavy beds of different thickness, fine layer lines, hairline cracks, soft tone clusters. It has no block outlines and tiles seamlessly. It replaces the brick-like rock, coal, iron, copper, gold, deep and cliff textures.
  - Hillside, curved bench and the boulder piles map their rock in **world space** (triplanar), so strata run unbroken across block seams instead of restarting on every block.
  - Cut blocks are now nearly flat (tiny chamfer, no tilt or jitter), sit exactly on each other with no wobble or rotation, and every course has the same tone. Fresh cuts are only slightly brighter than weathered rock, so the cut reads without a striped grid.
  - The mining grid, collision, exposure, saves and formation sizes are untouched.
- **Rougher cliffs:** `MeshKit.cliff_into` (pit walls, hillside backdrop, ring cliffs) now has a swelling height along the wall, a ragged crest, and much stronger per-vertex roughness, so walls are uneven rather than regular barriers. Collision is unchanged.
- **Ground:** `T_QD_QuarryFloor` and `T_QD_ExcavatedDirt` are now one calm compacted-dirt tone with sparse speckle (no yellow patches), so floors and roads blend.
- **Background** (`scripts/art/landscape.gd`, no collision, no navigation, about 20 draw calls):
  - sky gradient and sun disc, recoloured with the time of day;
  - lighter horizon-tinted haze (fog density 0.006 down to 0.0016);
  - 14 slow cloud blobs;
  - three layers of distant mountains beyond 290 m;
  - about 360 low-poly conifers in one MultiMesh on the embankment ring (not in the access corridor or the east expansion).
- **Tests:** `tests/test_natural_env.gd` (15 checks) covers the landscape cost, collision-free nodes, distances, tree placement, world-space rock materials, missing resources, the cliff ring and the cliff mesh. The Phase 6.3a loader drive got a longer time allowance.

## Quarry Days — Phase 6.3b: curved benches (arc formations) and MultiMesh chunks

- **Arc layout** (`progression.gd`): a formation can have `layout: "arc"` and `frame: "pit"`. Columns are angular slices (x index) of concentric rings (y index, row 0 = inner ring) around a centre, in the pit zone's frame. `cell_pos`, `column_pos`, `column_yaw`, `column_size` and `column_open_dir` are generic, so exposure, staff standing spots, saves and the rest of the column logic are reused unchanged. Grid formations behave exactly as before.
- **New bench `pit_band_01`** ("Basin Bench"): 16 slices x 6 rings x 3 tiers of cut limestone inside the starting basin, with the tops flush with the plateau. Only the inner ring (the working face) is exposed, so mining pushes the face outward toward the basin wall. It follows the cleanup lock (nothing to cut before the site is clean).
- **MultiMesh chunks** (`scripts/arc_formation.gd`): the whole bench is drawn by 5 MultiMeshes (about 288 chunks) instead of one node per chunk.
  - Hidden or crumbling chunks are zero-scale instances. Hit, shake and crumble only rewrite the chunks involved.
  - Weathered vs. freshly cut tints and course shading are per-instance colours.
  - Crack decals come from a pool of 3 overlays shared by the most recently damaged columns.
  - Physics is still one tangentially rotated box per column.
- **Navigation:** the pit region bakes from exposed columns only (plus the shell), in the background and rate-limited. The yard's synchronous rebuild now also skips buried hillside columns (it was the slowest part).
- **Staff:** a miner walks out through the gate, along the corridor and down to the bench, and cuts real stone (tested end to end). Rigs have no pads there yet.
- **Tests:** `tests/test_phase6_3b.gd` (30 checks). Counts of formations in older tests were updated. Note that the headless renderer does not store MultiMesh instance data, so those tests check chunk state, not instance transforms.

## Quarry Days — Phase 6.3a: the pit zone behind the north-east gate

- **The gate:** at 306 degrees on the cliff ring, the cliff filler and two low rim walls in its mouth are retired. A rockfall barrier closes it until the site cleanup tutorial is done (old saves are already open). The ring has no gaps while it is closed, and the gate is the only opening once it is open (both tested).
- **New area** (`scripts/pit_zone.gd`, data in `progression.json` → `pit_zone`; the yard keeps its coordinates):
  - an 8 m wide, 30 m long corridor with walls;
  - a 90 x 90 m plateau with walls;
  - a 36 x 36 m starting basin 3.6 m down, with a 20 m, 10-degree ramp (solid fill under it, curbs, rim barriers and railings);
  - pale limestone basin walls and brown strata outer walls;
  - the yard's soil embankment is cut where the corridor passes through.
- **Navigation:**
  - The yard keeps its own region.
  - The pit zone has a separate region baked in the background, with at most one bake per second of game time. Collecting its sources takes under 1 ms on the main thread.
  - A `NavigationLink3D` joins the two regions across the gate while it is open, so staff can reach the plateau and the basin floor.
  - Anything that is not the pit region is untouched.
- **Build zones:** `in_build_area` also allows the plateau and the basin floor once the gate is open (not the rim, ramp, corridor or wall margins). Yard and east-expansion rules are unchanged.
- **Vehicles:** a loader drives out of the yard through the gate, up the corridor onto the plateau, and down the basin ramp (tested).
- **Tests:** `tests/test_phase6_3a.gd` (22 checks). No mining or benches yet: those are 6.3b onward.

## Quarry Days — Phase 6.2: clean up Grandpa's site (tutorial)

- **New first step:** the old quarry is overgrown. 18 weed clumps and 8 rubble heaps are scattered over the open ground (`data/progression.json` → `cleanup`; positions are fixed, chosen so none touches a building, formation, the pit or the hillside).
  - **Weeds** fall to two hammer swings (`weed_hp` 6). They pay nothing but count toward the site.
  - **Rubble heaps** give 5 stone each into the bag, 1 per 10 damage. A full bag takes nothing and loses nothing, and the heap shrinks as it empties.
  - **Tools:** drills and jackhammers work on both.
  - **Movement:** people and vehicles walk and drive through them. Only the mining ray and the look-at prompt see them. Machinery placement is still blocked by them.
- **HUD:** "Site cleanup x/26" in the status panel, prompts for each item, and the stage 1 goal text and Grandpa's intro letter now describe the cleanup.
- **Gate:** the hillside, its staff mining and rig installs stay locked ("Clear the weeds and rubble first (n left)") until the site is clean. Its label says so too.
- **Walt's letter:** clearing the last item opens a letter from Grandpa Walt with `gift` ($600) paid once, and unlocks the hillside. It is earmarked for the first drill, which comes in a later phase.
- **Saves:** the cleanup state (cleared items and the stone left in each heap) is stored in the `phase5` block. Saves from before this phase have no cleanup block, so they load as already clean (no debris, hillside open, no gift).
- **Tests:** `tests/test_phase6_2.gd` (25 checks). The Phase 3 and 6.1 tests now start from a cleaned site.

## Quarry Days — Phase 6.1: The First Real Quarry (hillside)

- **New formation `hillside_face_01`** (`data/progression.json`): a 6-deep x 12-wide grid of 1.9 m columns, 1-4 tiers high (1.2 m each), cut into the west rim at x -28..-16.6, z -22..0.8. It is built on the existing `QuarryFormation` column system: shared meshes, one box collider per column, cracks, crumble and dust.
  - Only the east face is open. The other three sides are solid hill (`closed` in the data), so the player and staff cut in from the front and expose the next columns behind as they go.
  - `strict` formations never let a buried column be mined, even by targeting it directly.
- **Cut-stone look:** `MeshKit.cut_block_into` makes blocks with flat sides, chamfered corners, a slightly tilted top and 32 triangles. Blocks are laid in flush courses on the cliff strata material. Five shared meshes cover the whole hill.
- **Permanent:** columns never regrow (`regrow_at` is -1). They are saved as a compact int array, like the other formations. Loading twice or letting days pass never refills the cut.
- **Compatibility:**
  - The old formations are untouched: same ids, dimensions and column counts. Stage progress still counts only them.
  - Old saves load with a full hillside and nothing else changes.
  - The hand-mining quarry face and the original piles remain as starting resources, so there is no economy softlock.
- **World:** the low rim walls and the one cliff block in the hill's working area are retired (hidden, no collision, ignored by navigation). The cliffs behind it stay as the taller hill above. The tree, retaining wall and scenery props that stood there are skipped.
- **Staff and rigs:** workers use the existing exposure and standing logic and go to the nearest exposed face. Two rig pads were added on the front.
- **Measured:** navigation rebuilds once per emptied column at most. No throttling was needed.
- **Tests:** `tests/test_phase6_1.gd` (45 checks). Older tests updated where they hard-coded three formations.

## Quarry Days — tool, worker and belt fixes (from your screenshots)

- **First-person tools:** checked with real software renders this time. The pick and hammer now rest leaning forward and are smaller, so they no longer fill the screen. The drill and the jackhammer were far too large and mispositioned; both are rescaled and held at the lower right, and the jackhammer's chisel points forward-down. Power tools only nudge toward the crosshair instead of flying to it.
- **Workers:** the pickaxe, wrench and clipboard attach with a defined hold pose (`Worker.TOOL_POSE`) instead of pointing backwards. The pick shaft rises up and back on the wind-up with the head on top and comes down forward on the strike. The pick head now spans across the shaft, in the swing plane.
- **Pause menu:** the panel is now small, and its text and buttons are centred.
- **Belt placement:** with grid snap on (G toggles it), a belt ghost within 2.6 m of a crusher feed side, a crusher discharge chute, an output bin or another belt's end snaps flush and faces along the flow, so it links with no fiddling. Free placement is still available with G.
- **Tests:** snapping checks added to `tests/test_phase5_1.gd` (101 checks).

## Quarry Days — HUD readability fix

- **Fonts:** all body text, prices, descriptions, dialogue and button labels use Atkinson Hyperlegible (SIL OFL 1.1; licence in `assets/fonts/`), antialiased with light hinting. Bold is used for item names, prices and buttons. Silkscreen remains only for headings and decorative labels. Pixelify Sans is removed.
- **Sizes** (960x540 canvas scaled to the window): body 9 (12 px at 720p, 18 px at 1080p), secondary 8 (16 px at 1080p), headings 12 (24 px at 1080p), cash 16. Line spacing is 2. Text is re-rasterised at the window scale, so it stays sharp on any resolution or DPI.
- **Selling table:** a header row aligned with the data, alternating row shades, bold gold values and a bold material name. A green SELL button and a quieter "Clerk: on/off" toggle are visually distinct. Shop and upgrade cards use bold names and prices and green action buttons.
- **Also fixed:** the "Tool n/5" HUD readout no longer relies on glyphs missing from the new font. Long toasts and story text wrap.
- **Viewport:** the `expand` stretch aspect from the previous phase is verified at 16:9, 16:10 and ultrawide windows: no bands, and the 3D view is not stretched. The 3D textures stay nearest-neighbour; only interface text is smooth.
- **Tests:** `tests/test_ui_readability.gd` (24 checks).

## Quarry Days — Phase 5.1: Visual, Tool & Interface Polish

- **Readable pixel UI:**
  - Pixelify Sans is the body font and Silkscreen is for headings only. Body text is now one size (15) and headings use 12 or 24, because those sizes land on whole screen pixels at 1280x720 and 1920x1080. The old 11-14 sizes smeared the glyphs.
  - Larger text, +3 px line spacing, more opaque panels and brighter ink.
  - The HUD was re-laid out so nothing overlaps (the bottom bar no longer sits on the key hint). Long toasts and story letters wrap inside their panels.
- **Rock geometry:**
  - The faceted chunks had no underside: the flat base was an open ring, so chunks looked hollow from below. The base is now capped, so every chunk is a closed solid.
  - Neighbouring chunks overlap with no gaps (tighter radial jitter).
  - Formation rock is double-sided as a safety net. Textures and overall shapes are unchanged.
- **Mining dust:**
  - The square quad cloud is gone. A strike throws a small burst of tiny irregular specks from the actual hit point, along the surface normal.
  - Sizes and speeds vary, drag slows them, and they shrink and fade.
  - They take the mined rock's colour. 5-14 particles per strike.
- **First-person tools:**
  - Cause: pickaxe heads were extruded in the (z, y) plane and then rotated 90° about Y, so the points ran left and right. The jackhammer also leaned the wrong way.
  - Fixed for all five tools. Each now has a grip, rest pose and working-end point.
  - Swing tools rest with the head forward, wind up, strike and settle.
  - Power tools aim at the crosshair.
  - At impact (and while a power tool runs) the working end is eased onto the point on the crosshair ray, so the visible contact matches the hit.
  - Mining reach is 2.6 m. Camera near plane is 0.03.
- **Clickable menus:**
  - Shop, upgrades, selling, storage, crusher, output storage, rig and pause are button panels. Item cards show name, description, price, ownership or level, and a Buy/Order/Upgrade button.
  - Unaffordable and locked cards are visibly disabled.
  - The sales booth is an aligned table (material, quantity, per unit, total, Sell, clerk ON/OFF) plus Sell All.
  - The management desk was already clickable; its buttons now use the same click path.
  - Number keys still work as optional shortcuts, shown in each footer.
- **Money feedback:**
  - Floating red `-$20` on purchases and gold `+$45` on earnings rise about 46 px and fade over ~1.6 s. They start at the clicked button.
  - Amounts come from the real change in cash. Failed purchases show nothing.
  - Rapid amounts merge into one total instead of stacking. Repeat clicks within 150 ms are ignored.
- **Viewport:** stretch aspect is now `expand`, so any window shape fills with no black bands. 16:9 windows give exactly the 960x540 canvas; taller windows add canvas height; the 3D view is not stretched.
- **Tests:** `tests/test_phase5_1.gd` (97 checks) covers menus, clicks, money pop-ups, duplicates, tool poses and impact alignment, rock mesh validity, dust, viewport fill and save/load.

## Quarry Days — Phase 5: The Big Progression Overhaul

- **Progression:** six stages (Manual Labor → Deep Excavation) gate hiring, machinery and vehicles. They are driven by lifetime earnings and real milestones, all set in `data/progression.json`.
- **Three enormous finite formations** (stone 1,110 / coal 525 / iron 480 units):
  - Chunked low-poly columns that crack, crumble and visibly lose height.
  - Per-column colliders and navigation updates.
  - One shared stock for the player, staff and rigs.
- **Tools:** a five-tier line (Rock Hammer → Heavy Jackhammer).
  - Each has its own model, animation, sound, speed and hardness limit.
  - Damage lands on the impact frame; power tools run continuously.
- **Mining feedback:** cracks, fragments, dust, camera kick, "+N STONE" pop-ups, durability bar, bag overflow to capped loose pieces.
- **Worker animation:** task-driven states (work swing synced to extraction, pickup, unload, operator interact/monitor, clerk paperwork/hand-over, turn, rest).
  - Smooth acceleration; workers face the target before working; feet stay grounded.
- **Machinery motion:**
  - Crushers spin up and down, the jaw works only while crushing, and contents are visible.
  - Belts scroll only while loaded.
  - Loader arm and bucket curl ease; the truck bed eases and the load slides out at the right moment.
- **New machines:** Drilling Rig, Industrial Rock Breaker (aimed joints, crawl, running cost, bins, upgrades) and Advanced Crusher.
- **Deep excavation:** a permit opens a 3.5 m lower level with a ramp for the player, staff and vehicles, plus Copper Vein and Gold Seam formations. New materials: copper ($45) and gold ($90).
- **Cozy pixel HUD:**
  - Pixelify Sans / Silkscreen (OFL).
  - Panels: money count-up and income rate, objective with progress, tool and bag bar.
  - Toasts, sale confirmations, story cards.
- **Office:** restyled, with new UPGRADES and STATS tabs; MILESTONES now lists stages and discoveries.
- **Story:** Grandpa's intro letter; a lockbox discovery when the first formation is cleared.
- **Economy:** new-game $10, wage ×6 and hire-fee ×5, new upgrade prices; pacing checks are computed from the data.
- **Saves:**
  - A `phase5` block (stage, lower level, rigs, story, stats); formation columns and tool tier are stored in the state.
  - Phase 1–4 saves migrate without losing anything.
- **Tests:** new `tests/test_phase5.gd` (113 checks). Older tests were updated where deposits, stages, wage scales or tabs changed.

## Quarry Days — Phase 4: THE VEIL Art Style & Sustainable Resources

- **Resources fixed:**
  - Deposits now hold a visible, regrowing stock (limestone 24 / coal 15 / iron 8, +1 unit every 3 / 6 / 12 in-game minutes) instead of vanishing for 100 minutes after one break.
  - A never-empty quarry face is reserved for hand mining, so a broke player can always recover.
  - Pieces you break are reserved from staff for 15 in-game minutes.
  - Older saves migrate.
- **Reused THE VEIL assets:** props, materials and pixel textures are copied with their full dependency closure.
- **Quarry textures:** new ones painted to THE VEIL's rules (Greyhaven palette, 64 px/m, top-left light).
- **Environment:**
  - Zoned ground: pit floor, gravel yard, haul roads and concrete pads.
  - Stratified cliffs and excavation benches; gap-filling cliff walls; soil embankments.
  - Site props, dust fog and night practical lights.
- **Buildings:**
  - Modelled site office with windows, door, roof, sign, desk and computer, notice board, cabinets and lighting.
  - Storage shed.
  - New open-front equipment garage with steel frame, corrugated roof and a workshop.
  - Sales booth and order kiosk.
- **Machinery:** jaw crusher with spinning flywheels, aggregate bin, belt conveyor, ribbed storage bin, faceted rock deposits, loose-rock chunks and rubble mounds.
- **Vehicles:** front loader and dump truck rebuilt with shaped bodies, cabs and glass, tread tyres, hydraulic rams, a curved bucket and a tipping body.
- **Workers:** miner, hauler, operator and clerk generated with THE VEIL's character pipeline (from the hand-made Eddie reference), wearing hard hats, gloves and hi-vis. They are animated by a rig controller adapted from THE VEIL's NPC animator.
- **Gameplay unchanged:** all existing gameplay colliders, interactions, navigation, construction zones and vehicle access are preserved.
- **Tests:** new `tests/test_phase4.gd` (43 checks). Earlier tests were updated only where deposits now keep their stock instead of vanishing.

## Quarry Days — Phase 3: Heavy Machinery & Expansion

- Drivable front loader ($2,500, after Mechanized Quarry) and dump truck ($5,000, after Automated Business), bought in the office EQUIPMENT tab and delivered to a free parking bay.
- Lightweight kinematic driving: momentum, braking, load-dependent acceleration, collisions with terrain, structures, workers, vehicles and conveyors, a chase camera with mouse look, safe exits and stuck/fall recovery.
- Loader: contextual bucket (lower, then scoop and lift) and dumping. Scoops from four regrowing rubble piles (two in the main pit, two in the expansion) and from loose rock. Dumps into the storage crate, crusher hoppers, output storage or the truck. Truck: animated tipping bed for unloading.
- Equipment upgrades: Loader Bucket (6 → 10), Truck Cargo (20 → 32), Vehicle Engine (+40% acceleration, +20% top speed, half the load penalty).
- Construction mode (B): move and rotate crushers, conveyors, output storage and the storage crate, with live preview and cancel. Sell structures for 50% of their price; contents are returned with confirmation, and worker assignments are repaired.
- Conveyors are now low, crossable belts with marked supports. People and workers step over them; vehicles do not drive through them.
- Building in the unlocked east expansion with ground detection, an access road and a parking apron. Placement previews show green or red.
- Pacing: Milestone 3 now needs 20 clerk crushed-stone sales instead of a single unit. Player vehicle deliveries do not count toward automation.
- Save data adds a `phase3` block (vehicles, cargo, upgrades, piles, driving state) and the crate position. Phase 1 and Phase 2 saves load with safe defaults.
- New `tests/test_phase3.gd` (75 checks). The Phase 2 chain test was adapted to the new milestone goal.

## Quarry Days — Phase 2: Employees, Wages & Automation

- Four specialized professions (Miner, Machine Operator, Hauler, Sales Clerk), data-driven in `data/business.json`. Nine candidates, up to four employees (configurable).
- One shared low-poly character rig with procedural idle, walk and work animations. Each profession has its own colours, headgear and tool. Distant workers animate at a reduced rate.
- Workers physically do the work. Miners strike deposits using the same hit and regrowth rules as the player, then pick up and deliver the pieces. Haulers carry limited loads along real routes. Operators load, start, monitor and empty crushers. Clerks sell at the counter.
- Runtime navigation mesh built from the quarry's collision geometry and rebuilt after every placement or expansion. Workers avoid each other, detect stuck movement and repath. If they cannot reach a workplace, they stop and show a warning.
- Shift scheduling (including overnight), per-minute wage accrual and automatic hourly payroll from the business balance. Unpaid workers stop and keep their owed wages. Dismissal never erases wages. Daily labour, revenue and production history is kept for 7 days.
- Three training levels per profession with measurable effects.
- New placeable structures: output storage (limited capacity, manual access) and modular conveyor sections (free or grid-snapped placement, endpoint auto-linking, configurable rate, visible items, quantity-based simulation). Crushers gain an automation hopper.
- Machinery kiosk order menu. Clerk sales authorizations at the selling station.
- Milestones: First Employee (remote management, +5% productivity), Mechanized Quarry (conveyors), Automated Business (east quarry expansion with four new deposits of the existing minerals).
- Management office with Staff, Hire, Payroll, Production and Milestones tabs, in a retro pixel style sized for 1280×720 and 1920×1080. Compact milestone and alert readout on the HUD.
- Save version 2 stores all Phase 2 data next to the Phase 1 snapshot. Phase 1 saves migrate with safe defaults.
- New headless test suite (`tests/test_phase2.gd`, 100 checks) using accelerated time, including an unattended end-to-end production chain.

## Quarry Days — Phase 1 prototype

- Standalone first-person Godot 4.3 project with low-resolution generated material patterns, small quarry pit, walk-in office and shed, cliffs and trees.
- Three respawning mineral deposits, visible strike damage, collectible pieces, backpack and storage.
- Selling station, four editable prices, money HUD, five persistent upgrades.
- Buyable freely placed crusher with collision-aware placement, input/output bins and real processing timer.
- Continuous 48-minute day/night cycle, save/load of machine state and individual uncollected pieces, pause menu and synthesized effects.
- Headless test suite covering the economy, mining, crusher, upgrades, placement, clock and save/load.

## HUD art integration
- Generated HUD sheets cut by `tools/ui_sheet_cut.py` into `assets/ui/hud/`; `UiSkin` nine-slices them with flat fallbacks.
- Skinned: panels, buttons, key caps, bars, dialog frames, prompt plate, toasts/banners, sliders.
- Portraits are snips of the real 3D models only; no generated faces.
- Not yet skinned: objective checklist markers, minimap frame, icon mapping, main-menu buttons.

## Economy and progression repair (branch claude/economy-repair)
- Prices no longer change with the stage (all multipliers 1.0). Sales never round down to $0.
- The sales booth sells from the bag, the storage bin and the output storages in one sale, and lists only what you own.
- Loose soil can no longer be tipped into storage (it was a script error); the spoil heap counts it toward Area 1 and pays nothing. Truck prompts say what a load earns.
- Rebalanced prices, rewards and stage earnings (see docs/ECONOMY_REPAIR.md). Player upgrades are gated by stage.
- Vehicles need only money and the stage: no automation milestone. The storage bin grows with the stage (80 / 140 base at Moving Mountains / Deeper Ground).
- Fixed unreachable rewards (lockbox, first gold), the gold bench now has rig pads, the permit is gone from the new quarry, more iron pockets in Area 2.
- Office computer is now a fake desktop (shortcut icons, sticky note with the next goal, taskbar); the storage bin shows a capacity bar and material icons, only for what you own, with Store/Take everything.

## Machine cabs, boarding and repair camera (branch claude/machine-cabs, on top of claude/economy-repair)
- Loader, dump truck and excavators have real cabs: seat, steering wheel or joysticks, dashboard with lamps, pedals, ignition key, floor mat, hinged door, foot steps and grab rail.
- Climbing in and out is a first-person sequence (door, step, doorway, seat); Tab toggles cab view while driving. Grandpa's first start climbs in, turns the key (dash lamps flicker with the stall) and climbs out.
- Repairs: the camera moves to a vantage for each part; the hose now runs along the boom (it used to float in front of the cab) and is attached to it.

## Terrain excavation and Grandpa's letter (branch claude/terrain-letter, on top of claude/machine-cabs)
- Root cause of the holes and floating platforms: the loose-soil field (0.9 m of soil drawn and collided as its own layer) stood on top of the topsoil layer without being linked to it. An emptied soil cell drew a made-up limestone patch instead of the layer beneath, and digging topsoil left the soil above it floating over the hole. Soil now follows the topsoil columns (also repairs old saves), and an emptied cell shows the real layer.
- Grandpa's letter is a compact sheet of aged paper (unfolds in 0.55 s, folds, curled corner, hand-drawn signature), paginated when long; E or a click turns the page, Esc puts it away, no mining or swings while it is open.

## UI, windows and world bounds (branch claude/ui-windows-bounds, on top of claude/terrain-letter)
- The coloured strips at the left of every HUD box and of every table row are gone.
- Every story card (Your First Day, the fossil, the egg, discoveries) is a sheet of paper like Grandpa's letter; the old beige box is no longer shown. Table rows in the shops and storage use the bevelled panel art with material icons.
- Windows are real: the walls of the office, home and tool shed are cut around each opening, each window has a reveal, frame, two sashes of clear glass, casing, sill and curtains, and you can see into the room. Glass on all machines is clear, so their cabs show.
- The highlight outline no longer draws round glass or cab interiors (it produced stray yellow slivers).
- The yard's east gap, which led out to empty woodland, is closed with a locked service gate.

## Battery pocket, office back window, tool plate, workbench (branch claude/battery-tools-ui)
- The excavator's hood has a real pocket for the battery; the repair lowers the battery into it and clips the cables on top (bought excavators come with one).
- The office's back-wall window (which ran past the corner) is gone.
- The tool plate has no progress bar.
- The workbench and its pegboard no longer offer tools or carts you own or have outgrown (a tool is outgrown when nothing about it beats what you have).
