# Changelog

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
