# Excavator repairs and vehicle seat

## What changed
* **Repair kit (Blender)** - `tools/world_models/repair_kit.py` builds `WLD_QD_excavator_kit.glb` (fuel tank with a real filler neck and cap on a tether, battery tray with a hinged cover and lead studs, hydraulic ports on the turret and the boom) and `WLD_QD_repair_parts.glb` (fuel can with spout, battery, hose fitting with a coupling nut). Sources: `assets/world/src/excavator_kit.blend`, `repair_parts.blend`.
* **Markers** - everything is placed from named empties (`Marker_FuelFiller`, `FuelCapRest`, `FuelPourTarget`, `BatteryTray`, `BatteryPositive`, `BatteryNegative`, `HydraulicHoseStart`, `HydraulicHoseEnd`, and on every cab `DriverSeat`, `DriverCamera`, `VehicleExitPoint`), always through the node's own transform, so it works rotated and on a slope. `scripts/repair_kit.gd` (state, hose/lead/tether geometry) and `scripts/repair_sequence.gd` (the three sequences).
* **No hands** - the parts move on their own. Fuel (~7 s with the camera): cap unscrews counter-clockwise, rises and travels to its rest on the tether, the can comes in from below the frame, aligns the spout with the neck, tilts about the spout tip, the stream runs only while aligned, stops before the can rights itself, the can leaves, the cap returns and screws on. Hose (~4 s): fittings lift, the hose curves, aligns, seats, the coupling nut tightens, settles, click; the hose is rebuilt every frame between the two ports, so it stays connected when the boom, stick and bucket move. Battery: the cover opens, the battery lowers into the tray and seats, the positive and negative leads connect, the cover closes.
* **Repair camera** - a gentle camera moves to a vantage computed from the markers and returns; Esc/E before the part is fitted puts it down, after it skips what is left of the animation (the state is already updated).
* **Entering and leaving** - the climb animations are gone: E gives a ~0.6 s eased camera move to the driver's eye (`DriverCamera`), leaving moves to the standing spot beside the machine; controls are unlocked as before.
* **Seated driver** - `scripts/seated_driver.gd` puts the operator model (VeilRig `seated` pose: level thighs, shins down, hands on the wheel or console) on the cab node, so it moves with the machine; one per machine, shown only while it is driven; in the first-person cab view only the head is hidden.

## Validation
`tests/test_repair_kit.gd` (47 checks: markers, cap open/close, pour only when aligned, hose follows the boom at three boom angles, battery tray, persistence through save/load, entry/exit, one visible seated driver attached to the cab, the machine drives after repairs) plus the updated `test_repair_hands`, `test_repair_sequences`, `test_battery_tools`, `test_cab_interiors`. GIF previews: `docs/previews/repair_fuel.gif`, `repair_hose.gif`, `repair_battery.gif` (frames from the real game).

## Known gaps
* The fuel can is a plain box with a spout (it reads boxy next to the machine).
* Other drivable machines get the seated driver through the same cab data; only the starter excavator and truck were looked at on screen.
* The seated pose is checked numerically and on screen for the excavator; hand placement on trucks/loaders uses the wheel hands and was not tuned per cab.
* Climb-free entry applies to every machine with a cab; machines without a cab still cut straight to the chase camera.
