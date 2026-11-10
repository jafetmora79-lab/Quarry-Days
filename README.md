# Quarry Days — Phase 2: Employees, Wages & Automation

Quarry Days is a standalone Godot 4.3 (GL Compatibility) quarry game for Windows. It uses original generated low-poly geometry, 16×16 pixel materials and synthesized sound effects, and does not load THE VEIL or require any of its files.

## Start

Open `QuarrySimulator.exe` from the Windows ZIP. Keep `QuarrySimulator.pck` beside it. A new game starts at 08:00 with $100. Phase 1 saves (`user://quarry_save.json`) load directly: money, materials, upgrades, crushers and loose pieces are kept, and the business starts empty.

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
- **Management desk**: inside the office. **M** opens management from anywhere after your first hire.
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

Workers path around machines, walls, conveyors and each other. A worker who cannot reach its workplace stops, shows a red warning in STAFF and on the HUD, and retries automatically. Paths are recalculated when you place something.

### Milestones (shown top-right; full details under MILESTONES)

1. **First Employee**: hire anyone. Unlocks remote management (M) and +5% staff productivity.
2. **Mechanized Quarry**: own a crusher and employ an operator. Unlocks conveyor belts.
3. **Automated Business**: complete one automated chain (staff mine → limestone fed by hauler or conveyor → operator finishes a run → crushed stone reaches output storage automatically → clerk sells crushed stone). Opens the east quarry expansion with new limestone, coal and iron deposits.

## Data

- `data/economy.json`: Phase 1 prices, crusher and storage settings.
- `data/business.json`: candidates, professions, wages, upgrade paths, shift defaults, conveyor rate and capacity, output storage size and prices.

## Tests

```
godot --headless -s tests/test_quarry.gd                     # Phase 1 (21 checks)
godot --headless --fixed-fps 60 -s tests/test_phase2.gd      # Phase 2 (100 checks, accelerated time)
```

## Known limitations

- Placed machines, storage and conveyors cannot be moved, sold or removed (same as Phase 1). Machinery can only be placed in the original quarry area, not in the expansion.
- The sales clerk sells stock held in the storage crate and output storages from the counter. Nobody carries goods to the counter.
- Conveyors block movement at knee height. The player cannot step over them, so leave walkways.
- Navigation is rebuilt synchronously on placement, causing a brief (~10–40 ms) hitch.
- As a last resort, a worker stuck for several seconds is moved to its next path point, and only while you are not looking.
- Saving is manual (F5), as in Phase 1. Unsaved progress is lost when the game closes.
- Visual appearance and real-time play on Windows hardware have not been tested in this environment. Testing was headless with accelerated time.
