# Quarry Days — environment polish and playability repair

Branch: `codex/quarry-environment-polish`.

Base: `claude/quarry-exact-blueprint`, `ed9e39458f7fbf2be6a3b6feaa395c486408e2bc`. Repository branch heads were inspected before work; this was the newest integrated gameplay branch and contains the rebuilt blueprint world, all 12 progression stages, surface plus four excavation levels, current equipment, service deliveries and save migration. No unrelated branches were merged. No PR was opened. THE VEIL and the published galleries were not modified.

## Changes and actual defects

- **Missing machinery interaction:** the original `shop` menu, previews, offers, confirmation and economy functions remained, but no world body was assigned `kind=shop`. A single signed terminal now stands immediately east of the workshop, at world **(-13.875, 0, 2.35)** in the blueprint layout. Approach its front (north-facing screen), look at the screen, press **E**, select an item, inspect its preview and confirm BUY. The existing office machinery page remains available. Stage locks, prices, construction inventory, snapping and vehicle delivery routines are unchanged.
- **Overlapping road intersections:** four asphalt rectangles occupied the same plane at their crossings. The same road footprints are now tessellated as a union, with narrow graded gravel shoulders. No road or facility was relocated. Low-contrast aggregate and small cracks replace large repeated asphalt blobs.
- **Unrepresented mountain blockers:** two hidden 76 m-wide rectangular `Tunnel mountain` bodies blocked space regardless of the visible rocky silhouette. They are removed. A continuous sculpted hillside has collision generated directly from its visible mesh, while the original tunnel passage, portal, shutter and delivery route remain clear.
- **Boundary mismatch:** nine-metre property walls extended far above the approximately 2.2 m visible fence and sat up to a metre behind it. The edge colliders now follow the visible fence line and height. Quarry fence meshes were also being drawn by both QuarryArt and PitZone; PitZone now owns their visible rails and wire, while matching yard-bake collision is retained.
- **Fence-to-portal joins:** the west yard fence ended at x=-23.5 while the tunnel portal sits at x=-26.1. Visible solid connectors now join the two ends to the portal. The service opening remains open when its existing shutter opens. The east service opening is intentional; it has clear posts and a dirt track, not a new wall.
- **Garage clearance:** the original visual intermediate posts crossed dynamically selected parking footprints. The front now uses an overhead portal truss and matching solid end columns, leaving the existing parking search and bays clear. A real west-tunnel loader delivery, driver return, enter/drive-out/brake/exit sequence now passes in the blueprint world.
- **Home perimeter:** added a connected small garden fence, with a 2.8 m front opening aligned with the house entrance. Physical tests cover all fence sides and walking through the intended opening. The new porch posts stay outside the entry path.
- **Duplicate workshop presentation:** the old Tool shed placeholder meshes were not included in the art layer's hiding rules. They now stop competing with the dressed walls/roof; their working collision and upgrade interaction remain. The old solid bed box is likewise hidden under the existing modeled bed while its interaction remains.
- **Intermittent slow walking:** `_try_mantle()` could treat a walkable floor contact as a ledge, repeatedly reset velocity and start a step-up. It now ignores walkable floor normals; real low vertical ledges still use the existing mantle system. The regression reproduced 0.33 m/s during a nominal 4.2 m/s carry walk before the fix and reaches 4.2 m/s afterward.

## Environment assets

Original deterministic pixel tiles and materials are in `assets/environment/`: Asphalt, Gravel, Siding, Metal, Roof, Trim, Concrete, Soil and Grass. Each tile is 256x256, uses restrained colour variation, nearest filtering with generated mipmaps/anisotropy, opaque rough materials and consistent world UVs (128 px/m on ground; 256 px/m on building details). Source: `tools/build_environment_palette.py`. Provenance is recorded beside the assets. Existing THE VEIL source assets and worker/vehicle models are unchanged.

Building details are authored in `scripts/art/environment_polish.gd`, applied through the existing batched art system: corner boards, fascia/eaves, gutters/downpipes, porch canopy, open doorway trim, workshop canopy, garage structural bases and columns, clerestory windows and raised roof seams. Roof seams are children of the existing roof, so they hide with it when the driving camera needs an interior view. Garage footprints, bays, existing service door and facility locations are preserved. The garage remains the yard's large industrial metal building; no new warehouse facility was invented.

The close northern backdrop is now three continuous shoulder-and-crest ridge meshes instead of separate boulder/cone peaks. The western tunnel backdrop is a broad undulating hillside. Existing distant mountain layers and day/night lighting remain. Pines now have layered canopies and a separate instanced bark batch; placement/footprints are unchanged. Sky colours are softer and warmer. One 1024 px, two-split directional shadow map with a 70 m range and 2x MSAA improve local shape readability without expensive post effects. Real integrated-GPU frame time is not claimed.

## Movement

| Setting | Previous | New |
|---|---:|---:|
| Walk | 4.2 m/s | **5.25 m/s** (+25%) |
| Sprint | 6.0 m/s | **7.5 m/s** (+25%) |
| Moving acceleration | 18 m/s² | 20 m/s² |
| Release braking | 18 m/s² | 24 m/s² |
| Locked braking | 20 m/s² | 24 m/s² |

Walk, sprint, acceleration and braking are exported variables in `scripts/player.gd`. Sprint keeps its original relative advantage. The 0.8 cart multiplier is preserved. Directed movement no longer suppresses the sprint input. Tool-motion normalization uses the new walk speed, retaining the original normal-walk bob intensity. Vehicle driving physics is untouched.

## HUD and render resolution

The existing 960x540 canvas layout and `canvas_items` stretching are retained; there was no separate low-resolution 3D viewport to remove. The 3D scene renders at window resolution. No whole-scene pixelation shader was added.

The existing antialiased Atkinson typeface remains. Body/secondary text increases from 9 to 11 canvas pixels, headings from 12 to 13. This gives roughly 14.7/17.3 screen pixels at 1280x720 and 22/26 at 1920x1080. Small labels are clamped to the readable minimum. Two theme size roles remain. The minimap follows the top-left plate's actual height, so a wrapped delivery/status line cannot overlap it; the order terminal has a small fixed amber map marker. Money-count animation, layout, icons, controller focus and touch behaviour are retained.

## Validation

All tests ran sequentially when sharing isolated test saves. Real user save directories were not used. Engine: official **Godot 4.3-stable**, Compatibility project.

- **Baseline:** eight relevant existing suites passed before implementation (layout, site fixes, buildings, machinery, deliveries, saves, readability, loaded haul route).
- **Final:** **18 suites, 377 checks, zero test failures and zero GDScript errors**. See `docs/validation/environment-polish/test-summary.json`.
- The new 48-check physical suite covers home fence continuity and opening; real controller walks from home to office, workshop, service lane, open tunnel and Area 1; solid building walls; represented property boundaries; worker navigation to workshop/office/home; the actual E interaction ray; original shop preview; exactly-once charging and construction inventory delivery; walk/sprint/braking/cart speed; hillside collision presence and imported environment textures.
- Existing suites cover the fully loaded truck down and back through the actual nested quarry roads, vehicle/service delivery, wheel/track behaviour, excavating and reloading the reconstructed quarry, old-save migration, equipment persistence, safety recovery, title menu, purchase preview/confirmation, UI containment at 1280x720 and 1920x1080, and touch input (`-- --touch`).
- Readability's previous 16–18 px body-text upper bound was deliberately updated to 20–24 px to test the larger requested text. No assertion about economy, progression, saves or world layout was weakened. An initial touch invocation omitted its documented `--touch` argument; the corrected run passes all 11 checks.
- Resource checker: **857 files checked, zero errors/warnings**.
- Official Windows x86_64 release export produces a separate EXE and PCK. The final exported EXE boots for 180 frames under **Wine 10, headless**, with no script errors. This proves executable/PCK startup, not Windows graphics-driver behaviour or frame rate.

Known diagnostic limitation: Godot 4.3's dummy renderer emits repeated `mesh_get_surface_count: Parameter m is null` messages and shutdown resource/leak diagnostics in the baseline and final headless game runs, including Wine. These are not newly introduced script failures; the same existing baseline suites pass with those diagnostics. No GPU image was generated to judge art quality. Native Windows OpenGL rendering, shadows, subjective readability and integrated-GPU performance require the user's Windows visual QA.

## Delivery and scope

`deliverables/QuarryDays-Environment-Polish-Windows.zip` contains `QuarryDays.exe`, `QuarryDays.pck`, launch notes, Godot's license, font licenses, checksums and validation summary. Extract the ZIP and keep EXE/PCK together. Source and all changes are on the experimental branch; there is no merge or PR.

`data/`, progression, economy, worker models/logic, vehicle physics, mineral definitions, story and save implementation are unchanged. Existing facility coordinates and excavation/haul-road layout are unchanged. No screenshots, videos or renders were generated. The supplied GameDev references were development guidance only, and no skill or tool was installed globally.
