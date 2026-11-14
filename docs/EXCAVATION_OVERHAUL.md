# Excavation overhaul

## Controls
| Key | Action |
|---|---|
| Space | jump (0.9 m); at a reachable ledge (up to 1.25 m, `QuarryPlayer.mantle_max`) it climbs instead; never in the air, never during a menu, dialogue, card, cinematic or the computer |
| 1-9 / mouse wheel | the hotbar: 1 shovel, 2 the ladder tool (hammer, pickaxes, drills), 3 ramp plan, then the tools you buy |
| Q | the handheld quarry plan (rings, outlines switch). Tool swapping moved off Q to the hotbar |

## Tools and materials
Loose ground (topsoil, gravel: `"loose": true` in data/progression.json) is dug with the shovel (gear class `digging`); rock is cut with the hammer, pickaxes, chisels and power tools.
`QuarryProgression.tool_suits()` returns the reason shown when the tool does not suit ("Requires a shovel...", "Requires a pickaxe or a hammer for rock."). Every game owns the
gear marked `"starter": true` (shovel, ramp plan); an older save gains them on load and keeps the tool it had in hand. Permanent tools never use bag space.
The pickaxe is still the first purchase ($150): giving it away at the start would remove the first rung of the economy.

## Digging under your feet
The "step off that rock" protection is gone. Mining the column you stand on shrinks its collider; gravity drops the player onto what is left (no teleport, the camera is untouched).
The rescue key (U) and the stuck-player safeguard remain for genuinely broken states.

## Ramps (scripts/ramps.gd)
The ramp plan tool previews a straight embankment from the aimed point, climbing the way you face, to the rim of the excavation. Valid (green) needs: level foot across the width, a grade
of at most 30% (16.7 degrees), 4.4 m width, 3.4 m head room, the surface above the ground all along, level ground across the full width at the top, no overlap. Too far or too high:
a 12 m staging ramp ends in a landing and the next ramp starts from it. Left click builds, right click removes (refused while someone is on it or another ramp rests on its landing).
A ramp is a solid convex wedge (collision layer 1, meta `ground`) saved in `state.ramps`. Workers and the auto crew do not yet path over player-built ramps (the navigation mesh is not
re-baked for them).

## Rings and the plan (scripts/plan_view.gd)
A "ring" is one of the six area contracts. Only work inside a ring's footprint counts toward its contract (`prog.area_for_point`); everything else still removes rock and pays out.
The plan shows done / active / next / later rings, contract progress, overall excavation, roads and ramps; its switch turns the 3D outlines (`QuarrySurvey`) on and off
(`state.plan_outlines`, saved). Survey stakes now stand on the real ground and finished levels lose their markers.

## Save format additions (all optional, defaults on load)
`ramps` (list), `plan_outlines` (bool, default true). `gear` gains "shovel" and "ramp_plan" on load. No version bump.
