# The protagonist - CHR_QD_Player

Built with the cast pipeline (`tools/character_cast`): `cast_specs.py` ("Player"), `paint_cast.py` (pixel textures, Pillow), `build_cast.py` (Blender 5: modelled head, body, clothing geometry, gloves, satchel, rig, GLB).

    python tools/character_cast/paint_cast.py Player
    blender -b --factory-startup -P tools/character_cast/build_cast.py -- --names Player --render <dir>

Outputs: `assets/characters/CHR_QD_Player.glb` (the game's file, all four satchel meshes), `assets/characters/viewer/CHR_QD_Player.glb` (gallery copy, one satchel state), `assets/characters/src/CHR_QD_Player.blend`, textures `tools/character_cast/textures/Player/T_QD_Player_*.png` (Head 128x64, Hair, Top, TopFront, TopCuff, Over = the jacket, Pants, PantsHem, Skin, Shoes, Sole, Gear swatches, Bag 128x128 atlas).

* **Look:** 27, ~1.76 m, sturdy, messy brown hair with tufts, stubble, thick arched brows, a small smile; faded forest-green work jacket (rolled sleeves, chest pockets with flaps, dark buttons, collar) over a cream tee, dark-brown cargo trousers (pockets, reinforced knees, leather belt with a bronze buckle), tan boots, charcoal gloves with four fingers and a thumb each.
* **Rig:** the cast's 22-bone humanoid (Godot names + Socket_* nodes), so `VeilRig` plays idle / walk / run / turn / carry / interact / seated on it unchanged; `tests/test_player_character.gd` checks that the bones move, not just that the names match.
* **Satchel:** olive canvas, brown leather strap across the chest (always shown), bronze buckles, reinforced bottom, open mouth, hangs behind the right hip. Four separate meshes (`QD_Player_Bag0..3`); `PlayerBody.set_bag(used, capacity)` shows exactly one: EMPTY 0-25 %, PARTIAL 26-60 %, MOSTLY FULL 61-90 % (a few stones), FULL 91-100 % (more stones, wide bottom). Driven by the real BAG (`state.total(inventory) / state.capacity()`); no inventory data is touched. The bucket is a separate item.
* **In the game:** `scripts/art/player_body.gd` (model, rig, satchel); `main._make_player_body / _player_body_tick` (on foot: a shadow-only body so nothing obstructs the camera - the hands in view remain the shared tool rig, no second hand system); `SeatedDriver` now seats this character in the excavator, trucks, loaders and the dozer (satchel off the seat, head hidden only in the cab view).
* **Gallery:** the 3D asset viewer lists it under Quarry Days / Characters (`python tools/build_asset_preview.py`).
* Evidence: `docs/previews/player_four_view.png`, `player_face.png`, `player_satchel_states.png`, `player_in_game_poses.png`, `player_seated.png`.

Known limits: the body is not drawn in first person (shadow only), so the on-foot walk/mine poses can only be seen in the shadow or by a debug camera (`tools/shot_player.gd`); the "Bag Full" posture tweak was not done; no Cole Harlan reference image was available to me (the brief's attachment did not come through), so the proportions follow the existing cast (Eddie-derived frame) rather than a side-by-side with Cole; the full regression suite has not been run for this branch.
