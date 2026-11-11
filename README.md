# Quarry Days — Phase 5: The Big Progression Overhaul

Quarry Days is a standalone Godot 4.3 (GL Compatibility) incremental mining game for Windows. It keeps THE VEIL's pixelated low-poly look, with a warmer, cozier feel.

You inherit Grandpa Walt's nearly bankrupt quarry. Start with his old rock hammer and break into three enormous formations. Sell what you dig, buy better tools, hire a helper, add crushers, rigs and trucks, and finally dig a lower level for copper and gold.

## Start

Open `QuarrySimulator.exe` from the Windows ZIP and keep `QuarrySimulator.pck` beside it.

- **New game:** starts at 08:00 with $10, the rock hammer and a short letter from Grandpa.
- **Older saves** (`user://quarry_save.json`, Phases 1–4) load directly and keep everything already bought. See *Old saves* below.

For the editable project, import `project.godot` in Godot 4.3 and run the main scene. The window opens at 1280×720 and scales to 1920×1080. The UI is laid out on a 960×540 canvas.

## Phase 5 at a glance

### The core loop

Mine → collect → transport → process → sell → upgrade → mine faster.

Stages unlock in order. The objective panel (top right) shows the next stage's requirements and progress. All thresholds are in `data/progression.json`.

| Stage | Unlocked when | Opens |
|---|---|---|
| 1 Manual Labor | start | hammer, sales booth, upgrade board |
| 2 Better Tools | $30 earned | goal: buy a pickaxe |
| 3 First Employee | $350 earned + pickaxe | hiring at the office desk |
| 4 Early Industrialization | $1,400 earned + 1 employee | crusher, output storage, front loader (conveyors still need Mechanized Quarry) |
| 5 Large-Scale Mining | $6,000 earned + 1 crusher | drilling rig, advanced crusher, dump truck (truck also still needs Automated Business) |
| 6 Deep Excavation | $14,000 earned + 55% of the first three formations dug | excavation permit ($5,000), rock breaker |

### Three enormous formations

- **The formations:** a Stone Formation (1,110 units), a Coal Seam (525) and an Iron Ridge (480) dominate the pit.
- **How they shrink:** each is a grid of columns made of stacked low-poly chunks. Damage first cracks the top chunk. When a chunk's units are gone, it crumbles away with dust and fragments. The column collider gets shorter, and emptied columns expose the rock behind them.
- **Finite and visible:** formations never regrow. A label shows how much is left, and the STATS tab shows how much of each is excavated.
- **One shared stock:** you, your staff and your rigs all take units out of the same columns. A full bag drops extra rock beside the formation as loose pieces. This stops at a cap (36 per formation); after that nothing more is extracted. Nothing is lost or duplicated.
- **Recovery path:** the never-empty quarry face (north-west) is still there.

### Tools

Buy tools at the upgrade board (key **1**) or in the office UPGRADES tab.

| Tool | Price | Use | Works |
|---|---|---|---|
| Rock Hammer | start | swing | stone, coal |
| Basic Pickaxe | $90 | swing | + iron |
| Reinforced Pickaxe | $320 | swing | + iron |
| Power Drill | $1,600 | hold LMB | + copper |
| Heavy Jackhammer | $4,500 | hold LMB | + gold |

- Each tool has its own model, animation, sound and speed. Every tier is at least 25% faster than the last; the first upgrade more than doubles your speed.
- Swing damage lands at the visible impact frame.
- Rock that is too hard makes the tool bounce off, and a message names the tool you need.
- **Mining Technique** (+25% speed) and the bag upgrades (Larger Backpack +16, Hauling Harness +30) are on the same board.

### Mining feedback

- On every hit: crack overlays, chunk shake, rock chips, short dust puffs and a small camera kick.
- Floating "+3 STONE" pop-ups (merged when they come quickly) and a durability bar under the crosshair while you mine.
- Selling shows a sale toast with a coin sound; the money counter counts up smoothly.
- Upgrades show their effect, for example "MINING POWER +134%". Stages and milestones get a short unlock notification.

### Workers

Workers keep their schedules, wages, training and assignments. Their animation now follows the real task:

- **Miner:** picks an exposed column and walks to it. Turns to face it before working, swings, and the rock is removed exactly when the pick lands. Then crouches to pick up the pieces and carries them to the crate.
- **Hauler:** crouches to load, carries the load, and lowers it into the destination.
- **Operator:** works the controls to load and start the crusher (lever pull), and stands watching while it runs.
- **Clerk:** does paperwork between customers and hands over at the moment a sale completes.
- **All workers:** idle, walk, turn in place, and rest at the break area when off shift.

Movement accelerates and slows smoothly (at most 9 m/s²). The stride matches the walking speed, and crouches keep the feet planted.

**Staff costs (Phase 5 balance):** wages ×6 and hiring fees ×5 (`wage_scale`, `hire_fee_scale` in `data/business.json`). For example, Rosa costs $75 to hire and $18 per hour.

### Machinery

- **Crushers:**
  - The flywheels spin up and down smoothly, and the jaw only cycles while really crushing.
  - The hopper and output pile show the real contents, a label shows run progress, and a dust puff marks each completed run.
  - The **Advanced Crusher** ($2,600, cone crusher with a gyrating mantle) takes double batches at about twice the speed.
- **Conveyors:** the belt texture scrolls only while it carries material.
- **Front loader:** the arm eases up and down and the bucket curls when it scoops. The load pours out over the dump.
- **Dump truck:** the bed rises smoothly, the load slides toward the tailgate, and the cargo leaves near the top of the lift.
- **Drilling Rig** ($3,200, Large-Scale Mining) and **Industrial Rock Breaker** ($8,500, Deep Excavation):
  - **Ordering:** at the blue kiosk (**5**/**6**), then choose a formation. Each is installed on that formation's drilling pad.
  - **Motion:** the turret slews and the mast (rig) or two-link hydraulic arm (breaker) aims at the real target column. The rod spins and feeds, or the hammer strikes, only while extracting. The crawler creeps forward as the face recedes.
  - **Running:** each has a running cost per in-game minute, an output bin (40) and upgrades. Its label shows the production rate.
  - **Collecting the bin:** press **E** at the rig, or use a hauler route, a conveyor or the loader.

### Deep excavation

- **Opening it:** buy the excavation permit at the kiosk (**7**) or in the office UPGRADES tab. The flat pit cap disappears and reveals a lower level 3.5 m down.
- **Access:** a 3 m access ramp works for the player, staff and vehicles, with railings and work lights.
- **Lower-level rock:** the **Copper Vein** needs the drill and the **Gold Seam** needs the jackhammer or a rock breaker. Copper sells for $45, gold for $90.
- **Building:** you can build machinery on the lower floor.
- **Further levels:** add more pit rectangles in the data.

### Story

- **Start:** a short letter from Grandpa opens a new game.
- **Grandpa's lockbox:** clearing the first starting formation reveals it where the rock stood. Press **E** for his notes, a 1971 crew photo, a core-sample record hinting at copper and gold below, and a $400 savings bond (paid once).

### The office (M or the desk)

The tabs are WORKERS, HIRE, PAYROLL, PRODUCTION, EQUIPMENT, UPGRADES (tools, personal upgrades, rigs, permit), MILESTONES (stages, discoveries, Phase 2 milestones) and STATS (lifetime sales, units mined by hand/staff/rigs, chunks broken, per-formation excavation).

### Old saves

Nothing is confiscated:
- The three small Phase 1–4 deposits are replaced by the full formations. Their loose pieces go to the storage crate (or your bag, or beside the new formation).
- You keep your pickaxe (or the reinforced one).
- Your stage starts at least where your equipment puts it: staff → First Employee; machines or vehicles → Early Industrialization; truck, automation or rigs → Large-Scale Mining.
- Past revenue counts toward earnings, and the intro letter is skipped.

### Data files

- `data/progression.json`: tools, material hardness and hit points, formations (layout, chunk units, drilling pads), stages, machines, excavation, story text.
- `data/economy.json`: prices (copper and gold added), upgrade prices, crusher settings.
- `data/business.json`: staff, wages and the Phase 5 wage and fee scales.
- `data/vehicles.json`: vehicles.

## Controls

- **WASD** move, **Shift** sprint, mouse look.
- **Left mouse** swings the hammer or pickaxe; hold it with the drill or jackhammer. Mined rock goes straight into your bag. **E** collects loose pieces or uses the station under the crosshair.
- **Selling station**: **1–6** sell all of a material from your bag, **7** sells everything. **Shift+1–6** toggles whether the sales clerk may sell that material.
- **Storage crate**: **1–4** deposit, **Shift+1–4** withdraw.
- **Upgrade board**: **1** buys the next tool, **2–6** buy personal upgrades.
- **Blue machinery kiosk**: **E** opens orders. **1** Stone crusher ($85), **2** Output storage ($60), **3** Conveyor section ($20, unlocked by milestone 2), **4** Advanced crusher, **5** Drilling rig, **6** Rock breaker, **7** Excavation permit. Locked items show which stage opens them.
- **Rigs**: **E** opens the rig panel. **1** collects the bin into your bag, **2** switches the rig on or off, **3** upgrades it.
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

## Resources (Phase 4, superseded in the main pit by the Phase 5 formations)

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

Run the test files one at a time: they share the `user://` save file.

```
godot --headless -s tests/test_quarry.gd                     # Phase 1 (22 checks)
godot --headless --fixed-fps 60 -s tests/test_phase2.gd      # Phase 2 (100 checks, accelerated time)
godot --headless --fixed-fps 60 -s tests/test_phase3.gd      # Phase 3 (75 checks, accelerated time)
godot --headless --fixed-fps 60 -s tests/test_phase4.gd      # Phase 4 (42 checks)
godot --headless --fixed-fps 60 -s tests/test_access.gd      # building entrances, worker facing
godot --headless --fixed-fps 60 -s tests/test_phase5.gd      # Phase 5 (113 checks)
godot --headless --fixed-fps 60 -s tests/test_phase5_1.gd    # Phase 5.1 polish (101 checks)
godot --headless --fixed-fps 60 -s tests/test_phase6_1.gd    # Phase 6.1 hillside (45 checks)
godot --headless --fixed-fps 60 -s tests/test_ui_readability.gd  # fonts, sizes, sales table, viewport (24 checks)
```

`test_phase5.gd` covers mining and rock depletion, tool progression, staff and machine extraction, processing, selling, the excavation unlock (player, staff and vehicle access), schedules (resting off shift), story, HUD layout, pacing estimated from the data, and save/load idempotence.

## Android / touch (temporary support)

Open the project in the Godot Android editor (or run it on any touchscreen with `godot --path . -- --touch`). Touch mode turns on automatically on mobile builds: left thumb stick to move, drag the right side to look, MINE (hold), USE (E), RUN (toggle), MENU, MGR (M), BUILD (B), plus PLACE / ROT while placing and ALT while driving. Menus and shops work with ordinary taps. Landscape orientation is set in `project.godot`. No export preset or keystore is included; `tests/test_touch.gd` (11 checks) covers the controls.

## Known limitations

- **Visual quality is unverified.** No screenshots or renders were made, as requested. Headless tests check behaviour, not looks. How the formations, chunk crumbling, tool viewmodels, worker poses, rig joints and the HUD actually look all need your visual pass.
- **Animation is procedural.** Worker states are bone-rotation poses blended in code, not keyframed clips. Tool grips, swing arcs and crouch depth are tuned numerically and unverified by eye. Workers stand rather than sit while resting.
- **Navigation rebuilds cost about 20 ms.** The navigation mesh is rebuilt when a formation column empties, a rig creeps forward, or something is built. Expect a brief hitch then (measured here; slower PCs may hitch longer).
- **Rigs only work from fixed drilling pads** (two per starting formation, one per deep formation). They creep forward on their tracks but are not freely placeable. Rigs cannot be sold or moved.
- **The rest of the pit floor stays flat.** The lower level is the only depth change, and its navigation mesh sits about 0.5 m above the physical floor (voxel rounding). This does not affect movement.
- **Old-phase quirks remain:**
  - The east expansion still has the Phase 4 regrowing deposits.
  - Vehicles are arcade-simple.
  - Saving is manual (F5).
  - Phase 5.1 visuals, tool poses and dust are tuned numerically and verified only by headless checks.
- **Not built:** the excavator (priority D) and further depth levels; the data structure allows more pit levels.

## Credits

- Fonts: Atkinson Hyperlegible (UI body text) and Silkscreen (large headings only), both under the SIL Open Font License 1.1 (`assets/fonts/*-OFL.txt`).
- Sounds: synthesized by `tools/qd_sounds.py`. Rock textures: painted by `tools/qd_textures.py` from THE VEIL palette.
