# One connected quarry: layout and contracts

Status: Phase A (foundation), B (Area 1) and C (Areas 2 and 3) are implemented and tested headless. Areas 4-6 are declared (stable ids, plan) but not built.

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
