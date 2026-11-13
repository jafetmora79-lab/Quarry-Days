# The filled quarry (branch `claude/quarry-filled-reconstruction`)

Headless-tested; **not seen on Windows**. Pit-local coordinates (x east, z north is -z; basin x -72..72, z -168..-48; plateau and basin rim y 0).

## What a new game is now
- **Filled, flat start.** The basin floor stays at y -3.6 underneath, but a removable volume (`q_l1_top` topsoil 1.2 m, `q_l1_gravel` 1.2 m, `q_l1_rock` limestone 1.2 m, 4 m cells, ~1020 columns each) fills it flush with the plateau. Topsoil carries scrub, weeds and stones that go with the soil. Only the basin ramp (x 0) and a 12 m staging lane at its foot (x -52..12, z -80..-68) are open.
- **Layered, increasingly hard geology.** Layers are separate stacked formations (`cover` rule: a layer cannot be cut while any layer above it stands). New materials `topsoil` (hardness 0) and `gravel` (0) join limestone 1, coal 1, iron 2, copper 3, gold 4; veins of coal/iron/copper/gold sit inside the rock (`veins`). Miners can be assigned to dig topsoil and gravel.
- **Four centred, nested levels** under the surface, all on the same grid, each with an 8 m ramp strip (W / E / W alternating), terraces of at least 8 m, and walls and floors as before:
  L2 x -52..52, z -152..-80 (floor -7.2) / L3 x -36..44, z -140..-92 (-10.8) / L4 x -28..28, z -128..-100 (-14.4). Coal and iron, iron and copper, copper and gold sit in separate formations per level.
- **Haul network.** Lane -> L2 strip (north) -> road along the L2 north terrace -> L3 strip (south) -> road along the L3 south terrace -> L4 strip (north). When a level opens, `open_roads` cuts its strip and roads (plus turning bays) through its own rock **and the layers above**; that rock is gone and pays nothing. Everything else is dug by the player. Level 2 opens when 6 % of the limestone bed is cut, level 3 at 30 % of level 2, level 4 at 30 % of level 3.
- Verified by `tests/test_filled_haul.gd`: the standard, heavy and industrial trucks drive **fully loaded** from the plateau down all four levels, turn round on the lowest floor and climb back to the yard gate with their whole load. `tests/test_filled_quarry.gd`: flat start without holes, nothing pre-dug, centred/nested/terraced rectangles, hardness order, stacked layers, digging changes ground height and collision and survives save/load, navigation over the surface, a hired miner digs topsoil, old-save migration.

## Old saves
A save from the pre-dug pit is migrated once on load (`QuarryProgression.migrate_filled_world`): the surface over each opened level's rectangle is cleared, haul roads are open, and the old per-level cleared share is cut from the new level (from its road end outward). Nothing is paid, nothing is added to the inventory, contract counters do not move. Machines parked inside the old pit are moved to the garage row or apron. The legacy layout (old tests, legacy saves) keeps the old pit untouched.

## Limitations (accurate as of this build)
- Roads are cut instantly when a level opens (small, surveyed, pays nothing) instead of being dug.
- Level 1 is three layers of one resource each; there is no per-tier resource inside one formation.
- Drilling-rig pads exist for the level-2 coal, level-3 iron and level-4 copper formations only. Machines placed in the old pit by a migrated save are not relocated (only vehicles).
- Quarry rock walls around the basin are unchanged (no fence treatment); the economy and pacing were not retuned (dirt and gravel sell for $1 and $2).
- Level 4 is 56 x 28 m: small. Area 6 is its northern gold bench, not a fifth level.
- Visual quality of the skinned layers, the terraces and the ramps has not been looked at.
