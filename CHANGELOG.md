# Changelog

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
