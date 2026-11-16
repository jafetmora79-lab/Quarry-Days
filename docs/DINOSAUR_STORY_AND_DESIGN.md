# The Stonetail Seam: the dinosaur story, mechanics and design

*(Quarry Days: story bible and logic review for the dinosaur companion. Models live in `tools/world_models/build_world.py`, `tools/character_cast/`. See the 3D viewer's "The dinosaur story" group.)*

## 1. The history (what really happened under the quarry)

- **68 million years ago** a mother ankylosaur, **"Old Mother Stonetail"** (the name Grandpa Walt's father gave her), laid five eggs in a hollow beside a **warm mineral spring** at the edge of a shallow lake, and curled round them to guard the nest.
- A flood buried her in silt. Over millions of years the silt became the **limestone and gold-bearing benches** of the mountain. Four eggs fossilised. The fifth was sealed by the spring's **calcite**, like a jar, and the spring's heat never left it: it is **still alive and warm**.
- **1952:** Walt's father, Gideon, noticed that the east wall of the deepest cut *sweats and stays warm in winter*. He dug no further ("leave her for someone who deserves her") and told his son. Walt never sold the mountain for exactly that reason (his lines at the fossil visit: *"there's a reason I never sold this mountain"*).
- **Today:** the player cuts down level by level (Walt's journal pages appear as levels open: records, geological notes "ask Evelyn", then the sketch of the mother). At the bottom, in the gold bench of Area 5, the player mines out the last two columns (16 and 17) and **the nest is exposed**.

## 2. The people

| Who | Role | Design |
|---|---|---|
| **Grandpa Walter**, 78 | Handed over the quarry, knows the legend, watches the dinosaur break rock ("Fifty years buying machinery. All I needed was a dinosaur.") | flat cap, round gold glasses, walrus moustache, flannel, suspenders (unchanged) |
| **Dr. Evelyn Marsh**, 54 *(redesigned)* | Walt's old friend, a field palaeontologist. Weathered, quick and kind. She chooses the live egg over a lab, and rigs the incubator. | **tan, freckled face with laugh lines; copper-and-silver bun held up by a red field bandana; round gold glasses on a chain; teal work shirt under a khaki field vest; tool belt with trowel and brush; satchel of specimen bags; watch; cargo trousers, boots.** `CHR_QD_Marsh.glb` + a new portrait. |
| **Mr. Aldric Vane** | The collector: pays $75,000 for the whole nest and calls the warm egg "a rock". | (voice only: a pitch card) |
| **Stonetail** (the player names it: Pebble, Rocky, Dusty, Flint) | The companion | see section 4 |

## 3. The choice and the flow (logic review)

1. **Exposure.** `prog.check_fossil()` fires when the fossil's columns are really mined out and the player is on level 4+. Toast, a camera swing to the nest, then **E** on it opens the card and the choice (final, with a confirm step).
2. **Collector** ($75,000): the nest is crated; no dinosaur, ever. **Scientist** ($2,000): `story["fossil_egg"]`, companion state `pending`.
3. **Next day:** Dr. Marsh visits in person (`marsh_due()`), explains the egg (the hot spring, the calcite, why she brings it here and not to a lab) and promises the incubator.
4. **The egg waits on the porch** in its straw nest (`egg_porch_pos()`), prompt "E: pick up the egg and put it in the incubator".
5. **Pick-up -> the egg goes into the incubator** in Grandpa's living-room corner (`incubator_pos()`), under the brooder lamp, with the thermometer and water tray. State `egg`; hatches after `egg_days` = 2 in-game days. The prompt shows the days left. **The incubator stays** in the house for good.
6. **Hatching:** the egg rocks, the cracks show, the shell splits and the top half pops off; the hatchling climbs out of the incubator into the living room; the player names it; a "what is this for?" card explains it.
7. **Growth** (days since birth): hatchling 3 days -> juvenile 4 days -> adult. Sleeps on its straw bed (22:00 to 06:00).

**Problems found in the old logic and what was changed**

| Old | Now |
|---|---|
| Egg appeared at fixed *old-yard* coordinates (-1, 9.5), nothing to do with the house. | Porch nest and incubator are placed from the real house position (`HOME_POS`), correct in the new quarry layout. |
| "Keep it warm and dry" but nothing was warm: just a sphere on the ground for 2 days. | A real incubator with lamp, thermometer, water tray; the egg lies in it; days-left prompt. |
| Egg magic was unexplained ("it should not be viable. It is."). | Backstory: a calcite-sealed egg beside a hot spring; Walt's father's clues across the journal pages. |
| The fossil was a pile of boxes and the egg was "found inside the rock" only in Marsh's words. | The fossil is the mother curled round her nest with four stone eggs and one **warm** one, so the choice is informed. |
| Cards/tutorial: nothing told the player the dinosaur breaks rock. | Cards at hatch, juvenile and adult: look at rock, press **T**. |

## 4. The dinosaur: design and how it helps destroy rock

**Stonetail** is a **cozy ankylosaur**: a round, low barrel body in olive-brown with a cream belly, three rows of armour studs down the back (the middle row tallest), flank spikes, a wedge head with a beak, rosy cheeks, cheek horns and **big, sparkly eyes**, four stubby legs with three cream claws, and a thick tail ending in a **bone-coloured club**. Hatchlings have bigger heads and eyes, smaller plates and club.

- **Rig:** the same 24 joints the animation already drives (neck, head, 4 hips/shins/feet, 3 tail joints, club, eyes, plates), so walking, resting, the tail wind-up and strike all work unchanged.
- **Mechanic (key T):** look at **exposed rock** or a **rubble/weed heap** and press T. It walks up, turns its flank, winds the tail back and **swings the club so it really meets the rock**; damage and dust land at the moment of contact. T again calls it off.

| Stage | Size | Smash | Damage per hit | Hardest rock |
|---|---|---|---|---|
| Hatchling | 0.35 | no | - | - |
| Juvenile | 0.75 | yes | 14 | hardness 2 (soft stone) |
| Adult | 1.25 | yes | 34 | hardness 3 |

Six hits per command, reach 14 m, 1.1 s between hits. It follows the **same rules as every tool**: hardness, exposure, locked levels. Pieces fall as loose rock the player or machines collect. The first time it breaks rock Walt cheers.

## 5. Where everything is

- **Models (Blender):** `dino`, `egg` (Shell, Cracks, ShellTop, ShellBottom, Nest), `incubator` (Body, Glass, Lamp, Gauge), `fossil_nest` (Body, Glow), and the redesigned `CHR_QD_Marsh`. Built by `python tools/character_cast/paint_cast.py Marsh`, `blender -b -P tools/character_cast/build_cast.py -- --names Marsh`, `blender -b -P tools/world_models/build_world.py -- dino egg incubator fossil_nest`.
- **Code:** `scripts/companion.gd` (`_build_from_model`), `scripts/main.gd` (`_ensure_incubator`, `_spawn_egg`, `_take_egg`, `_hatch_egg`, `_spawn_fossil`), `scripts/item_tips.gd` (companion cards), data in `data/progression.json` (`fossil`, `companion`, Walter's journal and visits).
- **Tests:** `tests/test_incubator.gd` (new), `tests/test_dinosaur_story.gd`, `tests/test_companion.gd`, `tests/test_fossil.gd`.
- **Screenshot tool:** `tools/shot_dino.gd`.
