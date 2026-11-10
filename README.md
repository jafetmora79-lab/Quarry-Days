# Quarry Days — Phase 4: THE VEIL Art Style & Sustainable Resources

Quarry Days is a standalone Godot 4.3 (GL Compatibility) quarry game for Windows. It shares THE VEIL's visual identity: PSX-era low-poly geometry, nearest-filtered pixel textures from THE VEIL's Greyhaven palette, and characters built with THE VEIL's own character pipeline. It is still its own industrial game. The THE VEIL assets it reuses are copied into this project; it does not need THE VEIL installed.

## Start

Open `QuarrySimulator.exe` from the Windows ZIP. Keep `QuarrySimulator.pck` beside it. A new game starts at 08:00 with $100. Saves from Phases 1–3 (`user://quarry_save.json`) load directly and keep everything already earned:
- Older saves start with no vehicles, full rubble piles and the storage crate in its original spot.
- Deposits that were broken when you saved come back empty and regrow; intact ones come back full.

For the editable project, import `project.godot` in Godot 4.3 and run the main scene.

## Controls

- **WASD** move, **Shift** sprint, mouse look.
- **Hold left mouse** on a rock deposit to mine it. **E** collects broken pieces or uses the station under the crosshair. Each deposit shows how much is left (see *Resources* below).
- **Selling station**: **1–4** sell all of a material from your bag. **Shift+1–4** toggles whether the sales clerk may sell that material.
- **Storage crate**: **1–4** deposit, **Shift+1–4** withdraw.
- **Upgrade board**: **1–5** buy personal upgrades.
- **Blue machinery kiosk**: **E** opens orders. **1** Stone crusher ($85), **2** Output storage ($60), **3** Conveyor section ($20, unlocked by milestone 2).
- **Placement**: aim at the ground. **R** or right mouse rotates (crushers and storage 90°; conveyors 45° with grid snap, 15° without). **G** toggles grid snap. **Left mouse** places. **Esc** cancels and refunds.
- **Crusher**: **1** load bag limestone, **2** start, **3** collect output, **4** move hopper contents into the machine.
- **Output storage**: **1–4** withdraw into your bag, **Shift+4** deposit crushed stone.
- **Management desk**: inside the office. **M** opens management from anywhere after your first hire. Vehicles and vehicle upgrades are bought in its **EQUIPMENT** tab.
- **B** toggles **construction mode**. Aim at a crusher, conveyor, output storage or the storage crate:
  - **LMB** moves it. You get a green/red preview; **R** rotates, **LMB** confirms, **Esc** cancels and leaves it where it was.
  - **X** sells it for 50% of its price. Anything stored in it goes to the storage crate, then other output storage, then your bag. If it holds material, press X twice to confirm. If there is no room for its contents, it cannot be sold. The main storage crate can be moved but not sold.

### Driving heavy machinery

- **E** enters a vehicle you are looking at. **E** again exits on a clear side, once the vehicle has stopped.
- **WASD** drives and steers. **Space** brakes. **Mouse** looks around; the camera drifts back behind you while moving.
- **Front loader**:
  - **LMB** is contextual. With the bucket down, it scoops from the rubble pile or loose rock in front of the bucket and lifts. With the bucket up, it lowers the bucket.
  - **RMB** dumps the bucket into the nearest storage crate, crusher hopper, output storage (crushed stone only) or dump truck.
- **Dump truck**: back the rear up to a storage crate, crusher hopper or output storage. **RMB** raises the bed and unloads.
- Material that a target cannot take (it is full, or a crusher is offered coal) stays in the vehicle; nothing is lost or created.
- **R** recovers a stuck vehicle to its last clear driving position.
- A small hint at the bottom shows speed, load and what LMB/RMB will do at your position.
- **F5** save, **F9** load, **Esc** pause or close panels. Closing the game pauses the clock. There are no offline earnings.

## Resources (Phase 4)

You can no longer run out of things to mine. The old system made a deposit disappear for 100 in-game minutes after a single break, and staff miners grabbed the pieces you had just broken. That left nothing to mine and no way to recover with $0. The new rules:

- **Visible stock.** Every deposit holds units: limestone 24, coal 15, iron 8. Each break takes its pieces from that stock. The rock shrinks as it is mined, and a label above it shows `LIMESTONE 18/24`, or `DEPLETED - regrows in N min`. Aiming at a deposit shows the same in the prompt.
- **Predictable regrowth.** One unit comes back every 3 (limestone), 6 (coal) or 12 (iron) in-game minutes, up to the cap. A depleted deposit stays in place as a small, solid stub and is minable again as soon as one unit has regrown.
- **Quarry face.** A wide limestone face on the north-west pit wall never runs out. It is slow (5 hits, 2 pieces) and reserved for hand mining; staff never use it. A player with no money and nothing loose can always mine it, sell the limestone and recover.
- **Shared, honest quantities.** You, miners and the loader all draw from the same stock. Pieces you break are yours for 15 in-game minutes; staff leave them alone. Nothing is created beyond what a stock gives up.
- **Rarer minerals.** Coal and iron regrow more slowly. More of every mineral is in the east expansion and the rubble piles.

## Running the business

1. **Hire.** At the management desk, open **HIRE**. Each candidate has a profession, skill level (1–3), hourly wage and a one-time hiring fee. You can employ up to four people (`max_employees` in `data/business.json`).
2. **Assign.** In **STAFF**:
   - **Miner**: choose limestone, coal or iron. The miner walks to a matching deposit, strikes it with the normal mining rules, picks up the pieces and carries them to the storage crate.
   - **Machine Operator**: choose a crusher. The operator loads limestone from the hopper into the machine, starts and watches each run, and moves the output into an output storage placed at the crusher's chute (the side with the dark chute).
   - **Hauler**: choose **From** and **To**. Sources are the storage crate, loose pieces at deposits, crusher output or output storage. Destinations are the storage crate, a crusher hopper or output storage. Carry capacity is limited. The UI shows which material the route carries; impossible routes are rejected.
   - **Sales Clerk**: stands at the selling station and sells authorized materials from the storage crate and output storages. Choose materials in **PRODUCTION** or with Shift+1–4 at the station.
3. **Schedule.** Use the **−/+** buttons to set start and end times in 30-minute steps. Overnight shifts such as 22:00–06:00 work. Workers walk to work when their shift starts and return to the break bench when it ends.
4. **Pay.** Wages accrue for each in-game minute on shift and are deducted from your balance automatically. If you cannot pay, that worker stops, the unpaid amount stays owed, and work resumes once the money is available. Dismissing someone settles their wages or keeps them as debt. You cannot hire while you still owe former staff. **PAYROLL** shows today's labour cost and the last 7 days.
5. **Train.** Each profession has three training levels with real effects. Each level adds $0.50/h to that worker's wage.
   - **Miner**: faster mining (−30% strike time), improved tool (one fewer hit), higher yield (+1 piece per break).
   - **Operator**: faster loading (−50%), reduced downtime (−65% restart delay), processing efficiency (−20% crush time).
   - **Hauler**: +4 carrying capacity, +30% walking speed, −60% loading/unloading time.
   - **Clerk**: faster selling (−40% per transaction), +3 units per transaction, +6% selling price.
6. **Automate.** One possible line: miner → storage crate → hauler (storage → crusher hopper) or a conveyor → crusher with operator → output storage at the chute → clerk. Conveyors carry material from their input end to their output end (yellow arrow). Place the input end beside a source (storage crate, crusher chute, output storage, another belt end) and the output end beside a target (crusher hopper side, output storage, crate, next belt). The placement prompt previews `IN -> OUT`.

Workers path around machines, walls, parked vehicles and each other, and step over conveyor belts. A worker who cannot reach its workplace stops, shows a red warning in STAFF and on the HUD, and retries automatically. Paths are recalculated when you place something.

### Heavy machinery and rubble piles

- **Front Loader**: $2,500; requires Mechanized Quarry. Bucket holds 6.
- **Dump Truck**: $5,000; requires Automated Business. Bed holds 20.
- **Delivery**: vehicles arrive in the first free bay of the equipment parking area south of the yard (yellow lines, sign). A bay with anything standing in it is skipped.
- **Rubble piles**: limestone and coal piles sit inside the main pit. The east expansion adds limestone and iron piles. Each holds up to 30 units and regrows one unit every 8 in-game minutes. Only the loader can work them.
- **Upgrades** (EQUIPMENT tab):
  - **Loader Bucket**, $900: bucket 6 → 10.
  - **Truck Cargo**, $1,400: bed 20 → 32.
  - **Vehicle Engine**, $1,200: +40% acceleration, +20% top speed, and half the slowdown from a full load.
- **Handling**: a loaded vehicle accelerates up to 45% slower (about 22% with the engine upgrade).

### Milestones (shown top-right; full details under MILESTONES)

1. **First Employee**: hire anyone. Unlocks remote management (M) and +5% staff productivity.
2. **Mechanized Quarry**: own a crusher and employ an operator. Unlocks conveyor belts and the front loader.
3. **Automated Business**: run an automated chain until the clerk has sold 20 crushed stone. The chain is: staff mine → limestone fed by hauler or conveyor → operator finishes a run → crushed stone reaches output storage automatically → clerk sells crushed stone. Deliveries made with your own vehicles do not count toward this. Unlocks the east quarry expansion (deposits, rubble piles, building space, access road) and the dump truck.

**Pacing note (Phase 3).** The Phase 2 test that unlocked the expansion in about 74 in-game seconds was mostly an artifact: it started with $3,000, hired four staff at once and ran 24-hour shifts. The goal itself was also too small, because a single crushed stone passing through the chain was enough. Milestone 3 now needs 20 clerk sales of crushed stone. That is about five limestone deposit cycles of mining, or less if you hand-feed the crate, so it takes a working day or more. Existing saves keep milestones they have already reached.

**Rough progression:**
- **Hand mining and selling:** a few hundred dollars per in-game day.
- **Staffed quarry with a crusher:** roughly $1,000–2,000 per in-game day before wages of about $100–150.
- **Front loader:** about 1.5–2.5 in-game days of savings. With the two main-pit piles, it adds up to about 180 units per pile per day.
- **Dump truck:** expect a few more days of savings after the loader.

## Data

- `data/economy.json`: Phase 1 prices, crusher and storage settings.
- `data/business.json`: candidates, professions, wages, upgrade paths, shift defaults, conveyor rate and capacity, output storage size and prices, and the Milestone 3 sales goal.
- `data/vehicles.json`: vehicle prices, unlock milestones, capacities, handling, upgrades, parking bays and rubble piles.
- `data/economy.json`: also deposit stock (`deposit_stock`), regrowth (`deposit_regrow_minutes`) and the quarry face (`quarry_face`).

## Art pipeline (THE VEIL style)

- `THE_VEIL_ASSETS_V2/`: props, Godot materials and pixel textures reused from THE VEIL at their original paths. `tools/import_veil_assets.py` copies them with their full dependency closure (148 files, under 1 MB) and only ever reads THE VEIL. Reused props include the office desk and computer, chair, notice board, filing cabinet, windows, door, wall lamp, workbench, shelving, toolbox, pallets, electrical cabinet, barriers, cones, dumpster, light poles, bench, retaining walls, railings, pines, rocks and dirt mounds.
- `tools/qd_textures.py`: paints the quarry-specific textures by THE VEIL's rules. Every pixel comes from the Greyhaven palette, at 64 px/m with top-left light and pixel clusters rather than noise. The set covers bedded limestone, coal and iron rock, drilled cliff strata, quarry gravel, dirt, corrugated metal, painted machine panels, tyre tread, belt, hazard stripes and pixel-font signs. Output goes to `assets/`, imported lossless with nearest filtering.
- `tools/veil_pipeline/qd_style_cast.py`: builds the four workers with THE VEIL's character pipeline, derived from its `chr_style_cast.py` and the hand-made Eddie reference. It reads a local THE VEIL checkout and writes `assets/characters/`. The workers keep THE VEIL's rig, sockets and texture manner, and add hard hats, gloves and hi-vis fabric.
- `scripts/art/`:
  - `mesh_kit.gd`: low-poly builders with meter-UVs.
  - `quarry_art.gd`: dresses the terrain, buildings, machinery and props. Gameplay colliders are unchanged.
  - `vehicle_models.gd`: the loader and truck models.
  - `veil_rig.gd`: worker animation, adapted from THE VEIL's `npc_animator.gd`.

## Tests

```
godot --headless -s tests/test_quarry.gd                     # Phase 1 (21 checks)
godot --headless --fixed-fps 60 -s tests/test_phase2.gd      # Phase 2 (100 checks, accelerated time)
godot --headless --fixed-fps 60 -s tests/test_phase3.gd      # Phase 3 (75 checks, accelerated time)
godot --headless --fixed-fps 60 -s tests/test_phase4.gd      # Phase 4 (43 checks: resources, art integrity, navigation, driving, saves)
```

## Known limitations

- **Visual quality is unverified.** No screenshots, renders or visual comparisons were made, as you asked. All checks are headless.
  - What is tested: the geometry and textures exist, everything loads, colliders and interactions still work, workers path, vehicles drive, the textures stay on the palette, and characters are skinned and pose.
  - What is not tested: how the quarry, buildings, machinery, vehicles and workers actually look, including prop orientation, tool grip in the hands, animation quality and the lighting mood. These need your visual pass.
- **Prop orientation.** Reused THE VEIL props are placed by position and rotation without having been seen; a few may face the wrong way or sit slightly off a wall.
- **Decorative prop collision.** Reused props are decorative: their own colliders are switched off, and explicit boxes block only where it matters (garage shelving and workbench, shed shelving, office cabinets, dumpster, light poles, retaining wall, filler cliffs). You can walk through small decor such as cones, rocks and weeds.
- **Flat physics ground.** The ground is visually uneven but physically flat, so walking, navigation and vehicles behave exactly as before. Cliffs, benches and embankments are visual meshes over the existing collision boxes. New filler cliffs close the old gaps in the cliff ring.
- **Workers.** They are procedurally animated (walk, idle, carry and one work loop per job), not motion-captured. Tools sit in the hand sockets; how naturally they are gripped is unverified.
- **Earlier limits still apply.** Vehicles are arcade-simple, the main storage crate can be moved but not sold, there is a brief hitch when navigation rebuilds, and saving is manual (F5).
