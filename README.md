# Quarry Days — Phase 3: Heavy Machinery & Expansion

Quarry Days is a standalone Godot 4.3 (GL Compatibility) quarry game for Windows. It uses original generated low-poly geometry, 16×16 pixel materials and synthesized sound effects, and does not load THE VEIL or require any of its files.

## Start

Open `QuarrySimulator.exe` from the Windows ZIP. Keep `QuarrySimulator.pck` beside it. A new game starts at 08:00 with $100. Phase 1 and Phase 2 saves (`user://quarry_save.json`) load directly. Everything already earned is kept. Older saves start with no vehicles, full rubble piles and the storage crate in its original spot.

For the editable project, import `project.godot` in Godot 4.3 and run the main scene.

## Controls

- **WASD** move, **Shift** sprint, mouse look.
- **Hold left mouse** on a rock deposit to mine it. **E** collects broken pieces or uses the station under the crosshair.
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

## Tests

```
godot --headless -s tests/test_quarry.gd                     # Phase 1 (21 checks)
godot --headless --fixed-fps 60 -s tests/test_phase2.gd      # Phase 2 (100 checks, accelerated time)
godot --headless --fixed-fps 60 -s tests/test_phase3.gd      # Phase 3 (75 checks, accelerated time)
```

## Known limitations

- Vehicle handling is deliberately simple: a kinematic body with arcade steering and a single box collider. There is no suspension, tipping or slopes beyond gentle ones. The loader bucket and truck bed are animations; material is tracked as counts.
- While a vehicle is moving it is not part of the worker navigation mesh. Workers bump into it and repath; once it is parked and you get out, the mesh is rebuilt around it.
- Conveyors are crossable low belts. People and workers walk through the belt's collision, but vehicles do not.
- The main storage crate can be moved but not sold. Rubble piles, deposits and buildings cannot be moved.
- Machinery can be built in the main quarry and the east expansion, but not in the narrow cliff opening between them.
- Placing, moving or selling a structure, or parking a vehicle, rebuilds navigation synchronously. This causes a brief hitch of roughly 10–40 ms.
- Vehicle recovery (R) and the automatic fall-out-of-world rescue move the vehicle back to its last clear position. That is a jump, used only for abnormal situations.
- Saving is manual (F5). Saving while driving resumes you in the same vehicle on load.
- No visual or Windows play-testing has been done in this environment. All verification is headless with accelerated time. Look, feel, camera comfort and animation quality still need your visual QA.
