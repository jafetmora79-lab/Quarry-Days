# Forest aura battle

A silent, repeatable Easter egg in the forest just outside the quarry's west
(left) fence. Uses the shipped `WLD_QD_deer.glb` and `WLD_QD_rabbit.glb` and their
named animation hinges; ordinary wandering wildlife stays independent.

## Finding it

Walk close to the left quarry fence, roughly around world **(-121, 0, -58)**.
Look west between the trees toward **(-148, 1.2, -58)** for two continuous seconds.
A broader section of the left edge can discover it (x -129..-106, z -102..-18),
provided the clearing is within 65 m, near the centre of the camera and not hidden
by solid scenery. There is no quest marker, message, reward or camera takeover.

The 24-second sequence has a stare-down, cyan deer / golden rabbit auras, an
energy clash and the rabbit's oversized final surge. Both settle afterward.
Looking away for three seconds ends it; another showing needs an 18-second
cooldown and a fresh stare. Menus and sleep pause it. Reloading resets it.

## Implementation

`scripts/forest_aura_battle.gd` owns the trigger, pose animation and small fixed
set of emissive meshes. `wildlife.gd` creates it only in the blueprint world.
`landscape.gd` reserves a 31 x 14 m planting gap between the trees so the view is
not dependent on a lucky random tree layout. The clearing does not change ground,
navigation or construction boundaries. The effect uses no glow requirement,
dynamic lights, physics bodies, audio, material production or save fields.

Run `godot --headless --path . -s tests/test_forest_aura_battle.gd` for the focused
trigger, animation, real-model, occlusion and cooldown checks. The existing
`tests/test_wildlife_ambience.gd` covers ordinary wildlife integration.
