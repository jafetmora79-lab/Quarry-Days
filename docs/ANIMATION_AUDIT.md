# Quarry Days: animation audit (animation overhaul, Phase A)

Nothing here has been verified by eye: the numbers come from `tools/animation_audit.gd` (run it with `godot --headless -s tools/animation_audit.gd`;
`tests/test_animation_audit.gd` runs the same checks as a regression test). A gap is the surface-to-surface distance between a moving part and
what it is hinged to; interpenetrating pins count as attached when within 4.5 cm.

## What exists already (found by reading the code, from the earlier animation work)

| Spec area | State in the code | Evidence |
|---|---|---|
| First-person tools: swing, impact on contact, power-tool spin, ease in/out, walking bob, equip lower/raise | exists | `scripts/tool_view.gd` (`swing()` fires `impact` at the strike moment; `op_blend` eases power tools) |
| Hands on the tools | exists; hands now measured against the real tool geometry (all 9 new tools pass) | `QuarryToolView._add_hands`, `GearModels.POSE` |
| Camera feedback | exists, small damped shake | `scripts/player.gd` `impact_feedback()` |
| Chips and dust, per material, pooled | exists (`CPUParticles3D` pools, material-coloured fragments) | `scripts/fx.gd` |
| Rock cracks and crumbling chunks | exists | `scripts/formation.gd` (`_update_cracks`, `_crumble`) |
| Worker walk cycle, turn, carry, work loops, introductions | exists | `scripts/art/veil_rig.gd`, `scripts/worker.gd` |
| Jaw crusher flywheels + swing jaw, cone crusher mantle, spin up/down | exists | `scripts/main.gd` crusher animation (~line 5743) |
| Drilling rig / breaker turret + boom + tool animation | exists | `scripts/rig.gd` |
| Excavator: automatic dig animation, manual cab/boom/stick/bucket (Phase 10.3) | exists | `scripts/vehicle.gd` |
| Loader scoop/curl, truck bed tilt with ram | exists | `scripts/vehicle.gd` |
| Service gate and garage door, deliveries | exists (Phase 9.7 / 10 fixes) | `scripts/delivery.gd` |
| Clouds | exists | `scripts/art/landscape.gd` |

## Gaps against the brief (not done yet)

| Spec area | Gap |
|---|---|
| Wheelbarrow workers (approach, grip the handles, lift, push, wheel turns with distance, lower, release) | missing: workers carry on the chest, they never push a wheelbarrow |
| Conveyor belts carrying visible material that follows corners | not audited in the game yet (belt scroll exists; items on the belt unconfirmed) |
| Trees: wind sway | missing |
| Wheel rotation matched to travel distance, steering wheels turning, suspension | wheel spin exists for vehicles; steering and suspension not implemented |
| Worker personality variation in idle/walk/work speed | personalities exist as data; animation variation unconfirmed |
| Sorting-table worker routine | unconfirmed |
| Save/load restoring animation state | not tested for animations specifically |

## Attachment repairs made in Phase A

- **Excavator:** the boom's foot was not attached to anything, so raising the boom pulled it up to 19 cm off the body. Added a boom pedestal and foot pin on the body and a matching hub on the boom, plus a stick elbow pin, a bucket pin at the stick tip and bucket ears. The bucket and stick now stay joined through the whole range (8 test poses).
- **Truck:** the cab guard stood inside the cab at rest. Moved onto the headboard clear of the cab roof, so the bed clears the cab at every tilt.
- **Hand splitter:** the left hand gripped 7 cm below the lever; it now grips the lever.
- **Crusher flywheels / jaw:** attached (the shaft passes through the housing).

## Checks (all pass)

| Group | Check | Gap (m) | OK |
|---|---|---|---|
| crusher tier 1 | moving part 1 -> housing | 0.04 | yes |
| crusher tier 1 | moving part 2 -> housing | 0.04 | yes |
| crusher tier 1 | moving part 3 -> housing | 0.014 | yes |
| crusher tier 2 | moving part 1 -> housing | 0.03 | yes |
| crusher tier 2 | moving part 2 -> housing | 0.03 | yes |
| excavator | boom -> cab/body [rest] | 0.006 | yes |
| excavator | stick -> boom [rest] | 0 | yes |
| excavator | bucket -> stick [rest] | 0 | yes |
| excavator | boom -> cab/body [boom raised] | 0.014 | yes |
| excavator | stick -> boom [boom raised] | 0 | yes |
| excavator | bucket -> stick [boom raised] | 0 | yes |
| excavator | boom -> cab/body [boom lowered] | 0.004 | yes |
| excavator | stick -> boom [boom lowered] | 0 | yes |
| excavator | bucket -> stick [boom lowered] | 0 | yes |
| excavator | boom -> cab/body [stick out] | 0.015 | yes |
| excavator | stick -> boom [stick out] | 0 | yes |
| excavator | bucket -> stick [stick out] | 0 | yes |
| excavator | boom -> cab/body [stick in] | 0.015 | yes |
| excavator | stick -> boom [stick in] | 0 | yes |
| excavator | bucket -> stick [stick in] | 0 | yes |
| excavator | boom -> cab/body [bucket curled] | 0.015 | yes |
| excavator | stick -> boom [bucket curled] | 0 | yes |
| excavator | bucket -> stick [bucket curled] | 0 | yes |
| excavator | boom -> cab/body [bucket dumped] | 0.015 | yes |
| excavator | stick -> boom [bucket dumped] | 0 | yes |
| excavator | bucket -> stick [bucket dumped] | 0 | yes |
| excavator | boom -> cab/body [cab swung] | 0.015 | yes |
| excavator | stick -> boom [cab swung] | 0 | yes |
| excavator | bucket -> stick [cab swung] | 0 | yes |
| loader | lift arm -> chassis [lift 0.0] | 0 | yes |
| loader | bucket -> lift arm [lift 0.0] | 0.015 | yes |
| loader | lift arm -> chassis [lift 0.5] | 0 | yes |
| loader | bucket -> lift arm [lift 0.5] | 0.006 | yes |
| loader | lift arm -> chassis [lift 1.0] | 0 | yes |
| loader | bucket -> lift arm [lift 1.0] | 0.009 | yes |
| tool grip | pointed_chisel R hand | 0.021 | yes |
| tool grip | flat_chisel R hand | 0.018 | yes |
| tool grip | repaired_pickaxe R hand | 0.01 | yes |
| tool grip | repaired_pickaxe L hand | 0.004 | yes |
| tool grip | sledgehammer R hand | 0.022 | yes |
| tool grip | sledgehammer L hand | 0.022 | yes |
| tool grip | steel_pickaxe R hand | 0.017 | yes |
| tool grip | steel_pickaxe L hand | 0.017 | yes |
| tool grip | hardened_pickaxe R hand | 0.018 | yes |
| tool grip | hardened_pickaxe L hand | 0.018 | yes |
| tool grip | hand_splitter R hand | 0.03 | yes |
| tool grip | hand_splitter L hand | 0.018 | yes |
| tool grip | powered_hammer R hand | 0.026 | yes |
| tool grip | powered_hammer L hand | 0.008 | yes |
| tool grip | pneumatic_chisel R hand | 0.01 | yes |
| tool grip | pneumatic_chisel L hand | 0.01 | yes |
| tool tip | pointed_chisel working tip on the model | 0.008 | yes |
| tool tip | flat_chisel working tip on the model | 0.004 | yes |
| tool tip | repaired_pickaxe working tip on the model | 0.02 | yes |
| tool tip | sledgehammer working tip on the model | 0 | yes |
| tool tip | steel_pickaxe working tip on the model | 0.007 | yes |
| tool tip | hardened_pickaxe working tip on the model | 0.034 | yes |
| tool tip | hand_splitter working tip on the model | 0.004 | yes |
| tool tip | powered_hammer working tip on the model | 0.012 | yes |
| tool tip | pneumatic_chisel working tip on the model | 0.006 | yes |
| truck | bed hinge -> chassis [tilt 0.00] | 0.001 | yes |
| truck | bed clears the cab [tilt 0.00] |  | yes |
| truck | bed hinge -> chassis [tilt 0.50] | 0 | yes |
| truck | bed clears the cab [tilt 0.50] |  | yes |
| truck | bed hinge -> chassis [tilt 0.95] | 0.007 | yes |
| truck | bed clears the cab [tilt 0.95] |  | yes |
