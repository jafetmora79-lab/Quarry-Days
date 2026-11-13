# Dmitri Holt — separate character candidate

Approval pending. Original polygon-authored Blender design for the existing miner Dmitri Holt, age 44. Source baseline is Quarry Days `c9ffc326d68dde4861ee97b295920fe9a783afbb` (named cast, also the Pages source at inspection). This candidate is never loaded by the employee code. No production character, gameplay, progression, save or existing animation file was changed. No screenshots or videos were generated.

## Inspect in the existing viewer

Candidate: https://jafetmora79-lab.github.io/Quarry-Days/#models%2Fexperiments%2Fdmitri-redesign%2FDmitri_Candidate.glb

Original: https://jafetmora79-lab.github.io/Quarry-Days/#models%2Fcharacters%2FCHR_QD_Dmitri.glb

The existing gallery provides orbit, zoom, wireframe, flat/smooth inspection and clip selection. Compare by switching the two entries in **Quarry Days — Character redesign experiment**. It does not offer simultaneous side-by-side viewing. Default Excavator selection, gallery code and existing models are preserved. Only the candidate GLB and appended manifest category are published on the existing, unprotected Pages source branch; no Pages configuration change or merge to main.

## Observed baseline and redesign

The named-cast source already includes facial geometry, an actual humanoid rig and pixel textures; it is not accurate to describe it as only stacked cubes. Its limitations are the coarse Skin-modifier body contour, four-sided finger sections, few garment folds, abrupt body-to-cuff transitions, and a small, heavy-eyed expression. The broad flannel/vest silhouette and numerous material partitions can read as rigid at close range. Original Dmitri has 3,042 triangles, five mesh objects and twelve materials. Original animation is driven at runtime by VeilRig, not stored as clips in that GLB.

This new mesh uses explicit rounded cross-section loops: tapered sleeves, shoulder volume, elbow gussets and folds, trouser knee shaping and raised cuffs. The fitted amber work jacket has actual lapels, bellows pockets, flaps, placket, snaps and raised hi-vis tape. A teal undershirt, charcoal trousers, warm leather gloves and laced boots balance the cream hardhat. The face has a shaped jaw, cheeks, modeled nose, ears, brows, beard, upward mouth corners and layered eyes with irises and highlights. The cropped hair and reinforcing helmet rib are modeled. Four curved fingers and an opposing thumb surround a palm opening for future grips.

Borrowed from THE VEIL's established Eddie art direction: modest low-poly rounding, warm material groups, tiny nearest-filtered texture marks, humanoid naming and hand/back/head attachments. No horror clothing, frightened expression, source mesh or original texture was copied. The archive references were used as development guidance, not installed. Their Godot examples target 4.7, so new 4.4+ APIs (AgX, new tween helpers, AreaLight3D, etc.) were not used.

## Deliverables and budget

- `Dmitri_Candidate.blend`: editable mesh, weights, rig, packed atlas and preview actions.
- `Dmitri_Candidate.glb`: one mesh, one opaque nonmetallic rough material, **7,680 triangles**, 4,252 exported vertices, embedded 256×256 PNG, nearest sampling without mipmapping, no required extensions or external files.
- `Dmitri_Candidate.obj` + `Dmitri_Candidate.mtl` + `Dmitri_PixelAtlas.png`: editable static neutral mesh. OBJ has no rig or animations; the existing gallery supports GLB, not OBJ.
- `build_dmitri.py`: reproducible original Blender 4.3.2 modeling and export source; no render calls.
- `validate_glb.py`, `validation.json`: independent binary/mesh/texture/skin checks.
- `check_godot43.gd`, `godot43-validation.txt`: actual Godot 4.3 import and existing VeilRig numerical checks.

Metres, +Y up and -Z forward in exported GLB; feet at Y=0, total helmet-inclusive height 1.873 m. Width 0.910 m includes the relaxed A-pose arms. The 22 deform bones use the current humanoid names and zero Blender bone roll; four socket empties import as four extra helper bones in Godot 4.3 (26 total). Hand socket local +Y follows the hand toward the palm. VeilRig computes its palm 0.075 m along the hand; tool shaft uses its existing local +Z convention, grip (0,0,0.05), support (0,0,0.25). New limb lengths are measured by VeilRig.

The atlas occupies about 256 KiB uncompressed RGBA, compared with many small baseline textures. Triangle count intentionally rises for close inspection while material surfaces fall from twelve to one; integrated-GPU frame time has not been profiled. No transparent eyes, high-end shader or post-effect requirement.

## Validation and limits

Binary validation verifies embedded image decode, atlas variation, unit normals, positive signed volume on all 94 closed authored islands, no boundary/nonmanifold edges after welding export splits, no zero-area triangles, UV bounds, normalized skin weights, and contact-neighborhood connectivity. Separate closed garment/face islands intentionally intersect; this is not a single watertight skin. Proximity checks do not replace visual review.

Godot **4.3-stable official** imported the candidate under `gl_compatibility`. The harness checks 22 deform bones plus 4 sockets, one textured skinned surface, metre scale and both clips, then exercises the **unchanged** game VeilRig for idle, walk, turn, mining, pickup and unload. All transforms remain finite; maximum main-hand grip error is below 0.001 mm. A cleanup-frame ordering issue in the initial harness was fixed; the final log contains no errors. This is a headless structural/kinematic test, not a Godot GPU lighting or Windows performance test.

Idle and Walk are short independent preview clips. Running, speech/facial animation, greeting gestures and production-quality mining/carry clips are not authored here. The rig permits later work on them. Fingers are fixed to the hand rather than individually articulated. The support-hand IK is exercised but visual grip fit, extreme shoulder deformation, boot contact and close-up intersections still need approval in the viewer. No drop-in replacement or production-ready claim is made.

To rebuild: `blender -b --factory-startup -P experiments/dmitri-redesign/build_dmitri.py`, then `python experiments/dmitri-redesign/validate_glb.py` (NumPy/Pillow). For the Godot check, create a separate Compatibility project, copy in the candidate GLB, `check_godot43.gd` and the unchanged `scripts/art/veil_rig.gd`; import with Godot 4.3, then run `--headless --script res://check_godot43.gd`. Keep writable XDG data/cache/config directories. The `.gdignore` here deliberately excludes the experiment from ordinary game imports.

Published Chromium verification passed: live GLB loads with a 26-color embedded atlas, nearest sampling, both clips, working orbit/zoom and view controls, original/candidate selection, no page errors or failed requests, and the unchanged default Excavator. Published GLB SHA-256: `42e9ba9a63e71fbf0ce6c0073893f5c0b782133aac0b4d4ee3643ab94b5732d6`. See `browser-published-validation.json`.

## Provenance

All new geometry, palette, atlas pixels, rig and clips were authored procedurally in this experiment with AI assistance using Blender/Python. No purchased, downloaded or generative-image assets were used. Original source is provided for the repository owner to edit and use; no additional third-party art license is required by these new files. Keep the AI-assisted provenance record if the candidate is later shipped. Artistic approval remains with the project owner.
