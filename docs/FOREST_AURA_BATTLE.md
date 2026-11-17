# Forest aura battle

A silent, repeatable aura-farming pose battle just outside the quarry's west
(left) fence. Uses the shipped deer and rabbit GLBs; ordinary wandering wildlife
stays independent. This is a goofy gesture contest, not an energy-beam fight.

## Finding it

Walk near **(-124, 0, -61)** and look west between the trees toward
**(-148, 1.2, -58)** for two continuous seconds. The left-edge discovery region
is x -129..-106, z -102..-18, within 65 m of the clearing, near the camera centre.
See-through fence movement colliders are ignored; solid scenery blocks discovery.
There is no quest marker, reward, dialogue, sound or camera takeover.

## Choreography (24 seconds)

- 0–2 s: indifferent stare, then rear up onto the hind legs.
- 2–8 s: six-seven-inspired alternating forepaws/hooves at chest height, with sway.
- 8–15 s: stacked-paw Boat Kid-inspired rolls: eight right flicks, five left, hold.
- 15–20 s: crossed forelegs and a deadpan stare, punctuated by small ground rings.
- 20–23 s: paws tucked beside the hips, relaxed chin-up "hands in pockets" attitude.
- 23–24 s: settle back onto all fours.

The gestures are animal adaptations: no added fingers, clothes or literal pockets.
The deer uses its existing independent foreleg hinges. The rabbit GLB has both
front paws in one mesh/hinge: only this Easter egg's instance separates its mesh
triangles into left/right paw hinges. Its source asset and normal wildlife remain
unchanged. The Easter egg rabbit is shown at twice its normal scale so its small
paws read from the fence. Rest transforms are restored after every showing, with no accumulated
pose drift. No music from the supplied reference is included.

Looking away for three seconds ends it. An 18-second cooldown and a fresh stare
allow a repeat. Menus/sleep pause it; loading starts fresh. The script uses no
physics, lights, resource production or save fields. A 31 x 14 m planting gap
keeps a window through the forest without changing terrain or navigation.

Run `godot --headless --path . -s tests/test_forest_aura_battle.gd` for trigger,
pose, split-paw, reset, occlusion and real-world sightline checks. Ordinary wildlife
is covered by `tests/test_wildlife_ambience.gd`.
