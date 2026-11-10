# Changelog

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
