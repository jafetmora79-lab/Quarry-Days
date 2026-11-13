# Quarry Days — the named cast

Grandpa Walter, Dr. Evelyn Marsh and the twelve hireable workers, each with their own model. They're built the same way as
THE VEIL's Eddie: low-poly forms with chunky hands, a modelled face, and hand-painted pixel textures with nearest filtering.

| Model | Who | Look |
|---|---|---|
| `CHR_QD_Walter` | Grandpa Walter, 78 | flat cap, gold round glasses, walrus moustache, bushy white brows, white horseshoe hair, flannel, navy suspenders, stoop |
| `CHR_QD_Marsh` | Dr. Evelyn Marsh, 54 | silver bob with fringe, round glasses, field vest with bellows pockets, teal shirt, satchel |
| `CHR_QD_Rosa` | miner, 24 | curly high ponytail, freckles, grin, orange hi-vis, yellow hard hat, gloves in back pocket |
| `CHR_QD_Dmitri` | miner, 44 | big frame, full dark beard, broken nose, plaid flannel, white hard hat, tool belt with hammer |
| `CHR_QD_Ines` | miner, 52 (foreman) | grey bun with a silver streak, hooked nose, safety glasses, radio, white hard hat |
| `CHR_QD_Nia` | miner, 31 | low afro puff, hoop earrings, purple tee, bib overalls, hard hat |
| `CHR_QD_Tomas` | operator, 23 | undercut with volume on top, pencil moustache, navy coveralls with reflective stripes, ear defenders round the neck |
| `CHR_QD_Hana` | operator, 34 | beaded braids, ear defenders on, green coveralls, radio |
| `CHR_QD_Sofia` | operator, 42 | sleek black bob, red lipstick, tank top, coveralls tied at the waist, aviators on her head, gold watch |
| `CHR_QD_Bram` | hauler, 56 | big and jolly, handlebar moustache, rosy cheeks, red beanie, hi-vis jacket, gloves |
| `CHR_QD_Lucia` | hauler, 27 | long braid, red bandana, hi-vis tee, cargo trousers, gloves |
| `CHR_QD_Felix` | hauler, 33 | tall, ginger beard and freckles, backwards cap, flannel under a yellow vest |
| `CHR_QD_Petra` | clerk, 63 | blonde-grey curls, half-moon glasses on a chain, mustard cardigan, name badge |
| `CHR_QD_Omar` | clerk, 36 | neat side part, trimmed beard, glasses, teal "QD" polo, pen, name badge |

## Rebuild
```
python tools/character_cast/paint_cast.py                     # pixel textures -> tools/character_cast/textures/<Name>/
blender -b --factory-startup -P tools/character_cast/build_cast.py -- [--names Rosa,Walter] [--render <dir>]
blender -b --factory-startup -P tools/character_cast/render_portraits.py -- <raw_dir>
python tools/character_cast/finish_portraits.py <raw_dir>     # -> assets/ui/portraits/named/<id>.png
python tools/build_asset_preview.py                           # 3D gallery in docs/
```
Edit a person in `cast_specs.py` (body, face, hair, outfit, gear), then repaint and rebuild just that name.

## How the models fit the game
- **Rig.** The rig is the existing cast's 22-bone humanoid (Godot `SkeletonProfileHumanoid` names), with `Socket_RightHand`,
  `Socket_LeftHand`, `Socket_Head` and `Socket_Back`. Bone frames match `CHR_QD_Miner` exactly, so `scripts/art/veil_rig.gd`,
  the tool grips and every worker animation work unchanged.
- **Build pipeline.** Each person is modelled and skinned in a canonical 1.75 m frame (Eddie's landmarks), then warped to their
  own height, leg length, widths and posture. That's why the bones differ per person; `VeilRig` reads limb lengths from the
  skeleton.
- **Workers.** `scripts/worker.gd` loads `CHR_QD_<Candidate>.glb` for a record's `candidate`. Very old records without a
  candidate keep the profession model and its tint and hat variants.
- **Walter and Dr. Marsh.** `scripts/main.gd` loads `CHR_QD_Walter` and `CHR_QD_Marsh`. Their looks are modelled in, with no
  runtime recolouring.
- **Portraits.** The HUD, hiring list and intro dialogs use `assets/ui/portraits/named/`, rendered from these same models.
  Anyone without a named portrait falls back to the generated portrait sheet.
- **Budget.** Each person is about 2.4k–3.3k triangles with 11–12 materials. Textures are 128×64 for the face and 64×64 or
  32×32 for tiles, with clothing at 128 px/m.
