# One connected quarry: layout and contracts

Status: Phases A-D are implemented and tested headless: all six contracts exist. Areas 4-6 reuse levels 3 and 4 of the existing pit; no deeper terrain than level 4 (floor -14.4) was added.

## Spaces
- **Operations yard** (`world.hub`, x -23.5..23.5, z -6..23.5): permanent, never excavated. It no longer holds any mandatory weeds or rubble.
- **Area 1 - Starter Cut** (`areas[0]`, rect x -23..23, z -29..-7.5): the shallow cut just north of the yard gate. It holds the cleanup (21 items), the soil field (about 780 units of removable soil with a spoil heap), the hillside face and the two ore outcrops.

## Contracts (data/progression.json `areas`, logic in `QuarryProgression`)
Area 1 measures only work done in the area: debris cleared (all), soil dug (48), soil hauled to the spoil heap (24), rock recovered from the area's formations (60). Overall % is the mean of the four. The $300 reward is paid once (`rewarded` flag); finishing does not remove any remaining rock. The Better Tools stage requires the `area_1_complete` milestone in addition to its old requirements. Old saves count Area 1 as done with no second reward.

## Planned mapping of Areas 2-6 onto the existing connected geometry (not built)
2 upper working face (north of Area 1, `pit_band_01`), 3 first terrace (level 2 bench, existing ramp), 4 industrial bench (level 3), 5 deep mineral bench (level 4), 6 final cut (to be cut beyond level 4). The existing separate permit pit is not counted as any of the six.

## Foundation fixes (Phase A)
Piece ids for columns 100+, pocket minerals never lost (typed loose pieces, saved), below-ground load positions, nav refresh after soil changes, same-level proximity for hauling, one extraction rule (`extraction_block`) for hand, crew, companion, rigs and excavators, usable-save validation with a protected backup, and the landing assertion that could not fail.

## Phase C: Areas 2 and 3 (they reuse the existing connected pit, no new terrain)
The yard gate at the north-east edge of Area 1 opens (once Area 1's cleanup is done) onto a corridor that leads to the basin plateau; the basin floor (y -3.6) and the level-2 pit (floor y -7.2, reached by a 20 m ramp) were already one continuous, collision-matched excavation (see `scripts/pit_zone.gd`, `tests/test_open_pit.gd`).
- **Area 2 - Upper Working Face**: the basin floor, rock = `pit_band_01`. Contract: cut 200, recover 150 into a bag, bucket or bin, and reach the basin. Reward $800. Required by the Breaking Ground stage.
- **Area 3 - First Terrace**: the level-2 pit, rock = `bench_l2_coal` + `bench_l2_iron`. Contract: cut 150, recover 100, reach the terrace floor. Reward $1,600. The terrace itself opens by the existing rule (60% of the level above excavated). Required by the Industrial Quarry stage.
- Both need Area 1 complete, in either order. Membership is by place (`Main.area_at`): the pit frame and floor height, so a machine on the wrong level does not count.
- "Recovered" counts units that reach a carrier (hand bag, bucket, rig bin, worker) at mining time or when a dropped piece is picked up; cutting alone does not.

## Phase D: Areas 4-6 (levels 3 and 4 of the same pit)
- **Area 4 - Industrial Bench** (level 3, iron + copper): cut 200, recover 150, load 80 into trucks, reach the floor. $6,000. Needs Area 3. Required by Mass Production.
- **Area 5 - Deep Mineral Bench** (level 4, copper side z -114..-96): cut 150, recover 100, load 60, reach it. $15,000. Needs Area 4. Required by Beneath the Mountain.
- **Area 6 - Final Industrial Cut** (level 4, gold side z -135..-114): cut 120 gold, recover 80, load 40, reach it. $40,000. Needs Area 5. Required by Quarry Empire.
- "Loaded into trucks" counts bucket-to-truck transfers by the player's digging machine, attributed to the area the machine stands in. Loads by staff and haulers are not counted yet.
- Limitation: Area 6 shares level 4's floor with Area 5 (it is the gold half of it). A deeper level 5 was not built: nesting another pit inside level 4's 12 m-wide rock band with its own ramp would need new pit-zone geometry that could not be checked visually here.
- `tests/test_full_progression.gd` walks a new game through all 12 stages, satisfying every requirement for real (including all six contracts and the quarry levels), and checks no stage opens early.

## Phase E: verification (headless)
- `tests/test_full_progression.gd` - a new game through all 12 stages with every requirement met for real, all six contracts, no stage early.
- `tests/test_loaded_haul.gd` - a FULLY LOADED truck drives down all four pit levels, climbs back out with its whole load, goes round the pit and up the 20 m basin ramp, along the corridor to the quarry gate, and the load is intact. Passes for the standard truck (2.2 m) and the heavy truck (2.5 m).
- `tests/test_old_save.gd` - a real save written by the Phase 10 build (before the contracts, mid-game) loads, keeps its money/soil/cleanup progress, enters the Area 1 contract with that work counted, and is played on to completion with the reward paid once.
- Earlier: the pit's own route tests (`test_open_pit.gd`), contracts (`test_area1_contract`, `test_area1_playthrough`, `test_areas23`, `test_areas456`).

### Finding: the basin ramp and the level-2 entrance are far apart
The 20 m ramp into the basin stands at x 0 (in line with the corridor), but the level-2 haul road leaves the pit at its south-west corner (x -54.5), and the pit lies between them with only a 1 m sliver at the ramp foot. The two are connected the long way round the pit (west edge corridor ~5 m wide, north end, east side), about 330 m. The standard and heavy trucks drive it loaded. **The industrial truck (3.0 m wide, 5.6 m long) cannot take the tight turn at the west corridor** (it can drive every pit level and the ramps). Recommended fix, which changes world geometry and needs a visual check: move the basin ramp to x -54.5 so it runs straight into the level-2 road (all the ramp code uses x 0 in about eight places in `pit_zone.gd`), or widen the west corridor. Not done here.

## Yard / quarry split (after Phase E)
The yard (grey gravel ground, everything permanent) is fenced along its north edge (z -6.35, `QuarryArt._yard_boundary`) with one 7.2 m gate in the middle, a lintel sign and a gravel haul road running north into Area 1. Outside the fence the ground is raw quarry dirt with the soil field, weeds, rubble and rock face. Debris was re-placed for the new layout (10 weeds + 5 rubble heaps, all beyond the fence and clear of the road); soil cells, boulders and debris keep off the road. Saves in the old (legacy) layout keep their old debris positions because their three starting piles stand there.
Repair parts for Grandpa's excavator lie at least 1.2 m clear of the old truck, the machines and Grandpa. The named character cast (Walter, Dr. Marsh, 12 workers) from `claude/quarry-character-cast` is merged in.
