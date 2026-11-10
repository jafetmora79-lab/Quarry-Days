# Changelog

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
