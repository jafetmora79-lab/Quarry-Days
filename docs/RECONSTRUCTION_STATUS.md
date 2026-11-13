# World reconstruction: what is built and what is not

Branch `claude/quarry-definitive-reconstruction` (from `claude/quarry-integration-menu`).

## Built in this pass (headless-tested, not seen on Windows)
- **Survey-guided construction** (`scripts/survey.gd`): thin dashed survey lines (0.02 m high, 0.14 m wide) and small stakes mark the starter excavation (Area 1) until its contract is done, the open quarry levels (bright) and the level that opens next (faint). Completed work removes its lines. No glowing slabs.
- **Quarry plan** card on the office computer: the four levels with depth, materials, status (OPEN / NEXT with the unlock share / LOCKED) and the starter contract.

## Not built (genuine limitations)
The drawing's main requirement, a **flat, filled quarry that the player excavates level by level**, is not built. Today the 144 x 120 m basin is already dug 3.6 m below the plateau, and levels 2-4 are nested rock benches inside it, offset to the west, not centred as in the drawing. Findings from reading the geometry:
- A filled start needs a removable level-1 volume above the basin floor (e.g. a `frame: "pit"` grid formation at y -3.6..0) plus open **trench roads** through it. The basin ramp (x 0, z -68..-48) enters from the north end of the ramp, while the level-2 road head is at (-54.5, -69), on the other side of the level-2 pit rectangle (x -59..-5, z -150..-69). Joining them needs the level pit rectangles re-centred or shifted north, which changes every haul route, the level roads and the loaded-haul tests.
- One formation has one resource, so a layered topsoil / gravel / limestone level 1 needs either per-tier resources or the soil-field system extended over the whole basin.
- The nested rectangles in the drawing are concentric; the current ones are not.
- Not changed: yard layout (office west, tool shed centre, storage east, garage and home south: this follows the written brief), the south tunnel, the fence/wall treatment of the quarry boundary, the economy and pacing targets.
