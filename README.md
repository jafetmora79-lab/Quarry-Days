# Quarry Days — Phase 1

Quarry Days is a standalone Godot 4.3 quarry prototype for Windows. Uses original generated geometry, 16×16 pixel materials and synthesized sound effects. It does not load THE VEIL or require any of its files.

## Start

Open `QuarrySimulator.exe` in the Windows ZIP. Keep `QuarrySimulator.pck` beside it. First launch starts at 08:00 with $100. For the editable project, import `project.godot` in Godot 4.3 and run the scene.

## Controls

- **WASD** move; **Shift** sprint; mouse look.
- **Hold left mouse** when looking at a rock deposit to strike it. Pickaxe swings while mining.
- **E** collect broken rock pieces or use the station under the crosshair.
- **Selling station**: press **1–4** to sell all of each resource.
- **Blue order kiosk**: **E** buys a crusher for $85; look at clear ground to preview, **R/right mouse** to rotate, **left mouse** to place, **Esc** to cancel and refund. Aim downward so the placement preview intersects ground.
- **Crusher**: **E** to open; **1** loads carried limestone, **2** starts timed processing, **3** collects finished crushed stone. Sell the finished stone at the selling station.
- **Upgrade board** by the office: **E**, then **1–5** to buy an upgrade.
- **Storage crate** by the shed: **E**, then **1–4** deposits each carried material, or **Shift+1–4** withdraws it.
- **F5** save, **F9** load, **Esc** pause/resume. Closing the game does not progress the clock.

## Loop

Three deposits provide limestone, coal and iron ore. They take four hits initially and regenerate after 100 in-game minutes (about 200 real seconds). A reinforced pickaxe needs two hits. One in-game day lasts 48 real minutes. Sell ores, buy upgrades, place crushers, process limestone, sell crushed stone. Prices, durations, capacities and upgrade costs can be edited in `data/economy.json` in the source project. Saved progress is in Godot's `user://quarry_save.json` location for this game.

## Notes

This is a compact mechanical prototype. There are no employees, vehicles or automation yet. Geometry and sounds were made for this project; the Windows binary includes Godot Engine under the accompanying `GODOT_LICENSE.txt`. Visual gameplay has not been manually tested on Windows in this environment.
