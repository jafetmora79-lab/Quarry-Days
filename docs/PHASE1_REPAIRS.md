# Phase 1: critical quarry foundation repairs

Branch `claude/quarry-phase1-foundation-repairs` (from `claude/quarry-wheels-tunnel`, which holds the audited `f3597bf`). Targeted repairs only: no new levels, no redesign. Everything below was verified headless; **none of it has been looked at on Windows**.

## 1. Industrial truck access
Reproduced with `HAUL_TRUCK=industrial_truck godot --headless -s tests/test_loaded_haul.gd`: the loaded 3.0 m truck stopped at pit-local (-60.98, -3.65, -61.36) against "Plateau west". Cause: the west corridor between the level-2 pit wall (x -59) and the plateau wall (x -64) was 5 m wide, too narrow to turn into from the pit road's exit. Fix: `pit_zone.basin_width` 128 -> 144 m, so that corridor is about 13 m (the east side widens the same way). Pit rectangles, ramps, road positions and all saved positions (pit-local) are unchanged. `test_loaded_haul.gd` now defaults to the industrial truck; truck, heavy_truck and industrial_truck all pass (28 checks each).

## 2. Contract progression
- Loading a truck is no longer a shipment. Rock carries its excavation area (`rec["origin"]`, `{area: units}`, set where an excavator, rig or loose piece is loaded, moved with the rock by `Fleet.transfer`, saved and restored).
- `Fleet.dump_to` (delivery to storage, crusher, output) spends the origin record and `Main._credit_delivery` awards `shipped` only for what the destination accepted, for the area it was cut in. Cannot count twice (the record is consumed). Units with no origin record (old saves) earn nothing extra; existing counters are untouched.
- Work done in an area before its contract opens is banked (`area_add` no longer drops it); when the prerequisite completes, dependants are re-checked, so mining ahead can never leave a contract short. Rewards stay once-only.

## 3. Mining accounting
Crew, companion and rig extraction ignored the pocket minerals (`ex["veins"]`) the extraction opened, so they vanished. They now lie on the ground as pieces of their own mineral (`_vein_bonus(..., "ground")`). Rig output also counts toward the contract's "recovered" total.

## 4. Navigation and placement
- A stuck worker is no longer hopped to the next path point unless the hop is short (<= 3 m) and a ray finds nothing solid between (no more passing through walls).
- Belts link to a machine or belt only on the same level (`LEVEL_TOL` 0.75 m): `Business._endpoint_near`.
- `Main.footprint_ok`: a placed machine's rotated footprint (2.2 x 1.6 m) needs level supporting ground under nine sample points (within 0.2 m of its height, gentle slope) and nothing solid in its volume.
- Terrain changes already rebuild navigation (`nav_dirty` -> `_rebake_nav`; the pit's own region via `request_bake`); existing tests cover this.

## Also fixed in this branch (found by the user while testing)
- Dump truck bed tipped DOWN; it now tips up about the rear hinge and the load slides to the tailgate (the animation audit had the same wrong sign).
- The Hillside Face rock reached into the yard (blocked Grandpa's utility truck) -> moved north into Area 1; a weed that was inside the rock was moved; the old retaining wall that boxed the truck in was removed and the dumpster moved clear.
- Wheels/tracks rotate with distance travelled for every vehicle; open arched service tunnel behind the garage (previous branch).

## Tests
`tests/test_phase1_repairs.gd` (new): nothing buried in rock (both layouts), the truck leaves its spot, no level-1 rock in the yard, bank-before-activation, shipments on delivery only and once, crew pockets, footprint/support, belt levels, truck origin save/load, old-format save. Plus `test_loaded_haul` (3 trucks), `test_areas456` (updated), full regression.

## Not verified / remaining
Visuals on Windows (wider basin, tunnel, truck bed, wheels). Basin-ramp relocation and a real level 5 remain undone. Worker anti-wall hop has no dedicated test (covered only by existing worker suites not failing).
