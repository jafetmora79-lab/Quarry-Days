# One connected quarry: layout and contracts

Status: Phase A (foundation) and Phase B (Area 1) are implemented and tested headless. Areas 2-6 are declared (stable ids, plan) but not built.

## Spaces
- **Operations yard** (`world.hub`, x -23.5..23.5, z -6..23.5): permanent, never excavated. It no longer holds any mandatory weeds or rubble.
- **Area 1 - Starter Cut** (`areas[0]`, rect x -23..23, z -29..-7.5): the shallow cut just north of the yard gate. It holds the cleanup (21 items), the soil field (about 780 units of removable soil with a spoil heap), the hillside face and the two ore outcrops.

## Contracts (data/progression.json `areas`, logic in `QuarryProgression`)
Area 1 measures only work done in the area: debris cleared (all), soil dug (48), soil hauled to the spoil heap (24), rock recovered from the area's formations (60). Overall % is the mean of the four. The $300 reward is paid once (`rewarded` flag); finishing does not remove any remaining rock. The Better Tools stage requires the `area_1_complete` milestone in addition to its old requirements. Old saves count Area 1 as done with no second reward.

## Planned mapping of Areas 2-6 onto the existing connected geometry (not built)
2 upper working face (north of Area 1, `pit_band_01`), 3 first terrace (level 2 bench, existing ramp), 4 industrial bench (level 3), 5 deep mineral bench (level 4), 6 final cut (to be cut beyond level 4). The existing separate permit pit is not counted as any of the six.

## Foundation fixes (Phase A)
Piece ids for columns 100+, pocket minerals never lost (typed loose pieces, saved), below-ground load positions, nav refresh after soil changes, same-level proximity for hauling, one extraction rule (`extraction_block`) for hand, crew, companion, rigs and excavators, usable-save validation with a protected backup, and the landing assertion that could not fail.
