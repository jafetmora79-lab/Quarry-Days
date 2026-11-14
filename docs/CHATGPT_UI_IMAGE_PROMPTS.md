# ChatGPT image prompts - Quarry Days HUD sheets

Use one conversation per sheet. Paste the **Style block** first, then the sheet's prompt. All sheets are **1024x1024 PNG, transparent background**, on a **256x256 art-pixel grid where every art pixel is a crisp 4x4 block** (so the final art is made by shrinking x4 with nearest-neighbour). Positions refer to `UI_ART_ASSET_HANDOFF.md`; keep the filenames in the tables as the piece names when you slice.

If a result is off-grid, blurry, or contains text: say "Redo, pixel-perfect on the 4x4 grid, no text, transparent background" and re-send the layout. Generate a sheet in two halves if the model drops pieces (top half / bottom half of the same layout).

## READ FIRST - what these sheets are for (add this to every prompt)

The first generated sheet ("Sheet C3") came back as an attractive **mock-up board**: nice art, but with a painted map inside the map frame, an emblem baked into each panel, letters baked into key caps and the compass, bars drawn half-full, everything at different sizes with no grid. A game cannot use that as-is: the panels must be EMPTY so live text and live values can sit inside them, bars must be an EMPTY groove plus a SEPARATE fill (the game stretches the fill to the real percentage), and key caps must have no letter (the game draws the key name). Say so explicitly. Paste this paragraph at the top of every request:

```
PURPOSE: these are PRODUCTION GAME ASSETS that a programmer will cut out and plug into a game engine, NOT a UI mock-up, poster or concept art. The game draws all text, numbers, maps, portraits and bar fill amounts itself, so every piece must be EMPTY and reusable:
- Frames and panels: the inside is EMPTY flat dark brown. No icons, emblems, stripes, portraits, text or maps inside or on the edges other than the repeating border. Decoration only in the four corners (they stay fixed); the edges between the corners are plain and repeat.
- Progress bars: draw the EMPTY groove (with end caps) as one sprite and the FILL as a separate sprite (a plain strip I can stretch). NEVER draw a half-full bar.
- Key caps and buttons: NO letters, symbols or icons on them; blank faces only.
- Minimap frame: the centre is fully TRANSPARENT (no painted map).
- Compass and markers: no letters; (only the dedicated north tag may contain an N).
- One sprite per grid cell at the exact size and position I list. Do not add extra sprites, decorations, labels, or a presentation layout. Same outline thickness and palette across every sprite.
```

## Style block (paste first, every time)

```
You are drawing UI sprite sheets for a cozy retro industrial quarry-management video game called "Quarry Days".
Art direction: crisp pixel art, hard 1-pixel dark outlines (#120d09), NO anti-aliasing, NO blur, NO gradients except 2-3 flat tones per material, NO glossy or modern mobile-game look, NO text, NO letters, NO numbers (except where a prompt says a symbol is part of the art).
Palette ONLY: dark brown #211913 and #2d2118 (panel bodies), warm wood #6b4a2b and #8a6238, aged brass #b88f57 / #e0b86a / #fac257, rust orange #db7529, olive green #7fb04f / #9ee07a, warning red #e0583f, cream #fcf2d6, near-black outline #120d09.
Mood: warm, worn, hand-made - riveted dark-brown wooden and iron plates with brass trim, like an old quarry office.
Technical: the output image is exactly 1024x1024 pixels with a fully TRANSPARENT background. The picture is a 256x256 grid of "art pixels"; each art pixel is exactly a 4x4 block of image pixels, with perfectly square, hard edges. Every sprite sits exactly on that grid at the position and size I give (positions and sizes are in art pixels, measured from the top-left corner; multiply by 4 for image pixels). Leave at least 1 empty art pixel between sprites. Do not add anything that is not listed.
Nine-slice pieces: corners hold the decoration; the edges and the centre must be PLAIN (flat colour or a repeating 2-pixel pattern) so the piece can be stretched. The inside (safe text area) must be empty flat dark brown, no pattern.
```

## Sheet A - HUD frames, panel borders and corners

```
SHEET A. Draw these sprites on the transparent 1024x1024 sheet (art pixels):
1. hud_panel_main - 48x48 at (0,0): dark-brown (#2d2118) panel, 3-px brass-and-wood border (#b88f57 top/left edge, #6b4a2b bottom/right edge), a tiny rivet in each corner, 12-px corners, plain flat centre.
2. hud_panel_inset - 48x48 at (48,0): a recessed slot: darker (#211913) centre with a 2-px inner shadow on top/left and a faint brass line on bottom/right, 10-px corners, plain centre.
3. hud_panel_title - 64x24 at (96,0): a header plate, slightly lighter wood (#6b4a2b) with brass end-caps, 12-px left/right ends, plain centre.
4. hud_prompt_bar - 64x24 at (160,0): a long flat dark plate with a thin brass top line, rounded 12-px ends, plain centre.
5. hud_dialog_frame - 64x48 at (0,48): a speech panel: dark-brown with a thicker brass frame, four brass corner brackets, 16-px corners, plain centre.
6. hud_portrait_frame - 40x40 at (64,48): a square picture frame of wood with brass inner lip, 10-px border, EMPTY dark centre.
7. hud_toast_frame - 64x32 at (112,48): a small notice plate, brown with brass edge, 14-px ends, plain centre.
8. hud_banner_frame - 96x32 at (160,48): a wide ceremonial banner plate: brass border, rivets, small scroll ends (24 px each side), plain centre.
9. hud_vehicle_plate - 48x48 at (0,96): like hud_panel_main but with a hazard-stripe (yellow/black, 2-px) detail along the TOP border only.
10. hud_repair_prompt - 64x32 at (48,96): a workshop-tag plate: brown with an orange (#db7529) left edge and a bolt in each corner, 14-px ends, plain centre.
11. Four vertical strips, 4x32 each: hud_strip_green at (120,96) olive #9ee07a, hud_strip_gold at (128,96) #fac257, hud_strip_red at (136,96) #e0583f, hud_strip_blue at (144,96) a muted blue #6fa0c8; each is a flat colour with a 1-px darker left edge.
12. Four corner ornaments 16x16: hud_corner_tl at (152,96), hud_corner_tr at (168,96), hud_corner_bl at (184,96), hud_corner_br at (200,96): small brass corner brackets with one rivet; each one drawn to fit its own corner.
13. hud_divider - 64x8 at (0,144): a thin line made of a dark line over a brass line, with a small diamond rivet at each end, plain middle.
14. hud_rivet - 8x8 at (72,144) a brass rivet, and hud_rivet_lit - 8x8 at (80,144) the same rivet glowing bright gold (#fac257 centre).
```

## Sheet B - progress bars, indicators, buttons and control hints

```
SHEET B. Draw these sprites on the transparent 1024x1024 sheet (art pixels):
1. bar_bg - 48x12 at (0,0): a progress-bar groove: near-black (#120d09) inner trough, 1-px brass outer lip, 5-px ends, plain centre.
2. Four bar fills, 48x8 each: bar_fill_green at (48,0) #7fb04f with a lighter top row #9ee07a; bar_fill_gold at (96,0) #e0b86a with top row #fac257; bar_fill_red at (144,0) #c8452f with top row #e0583f; bar_fill_blue at (192,0) #5b87ad with top row #7fb0d8. Flat, 3-px plain ends, with a repeating 4-px diagonal tick pattern in the middle.
3. bar_cap_left - 8x12 at (0,16) and bar_cap_right - 8x12 at (8,16): brass end-caps with a rivet, matching bar_bg.
4. bar_complete - 48x12 at (16,16): a semi-transparent gold shine overlay (alpha) that sits over a full bar.
5. Four indicator lights 12x12: state_dot_off at (64,16) dark glass, state_dot_on at (76,16) green lit, state_dot_warn at (88,16) amber/red lit, state_dot_done at (100,16) gold with a tiny check mark shape (shape only, no text).
6. checkbox_empty - 16x16 at (112,16): an empty wooden checkbox; checkbox_done - 16x16 at (128,16): the same box with a bold brass check mark.
7. Buttons, each 48x24, 10-px ends, plain centre, raised look (lighter top edge, darker 3-px bottom edge). Four STATES each (normal, hover = lighter, pressed = 1 px lower with a 1-px bottom edge, disabled = desaturated dark). Arranged in a grid, one column per state at x = 0, 48, 96, 144 (normal, hover, pressed, disabled), and one row per kind: btn_primary at y=32 (brown wood #6b4a2b), btn_main at y=56 (amber #e0b86a with darker amber edge), btn_danger at y=80 (muted red #8c3a2c), btn_toggle at y=104 (flat dark #2d2118 with a thin brass edge).
8. Key caps: keycap_small_normal 24x24 at (0,136) and keycap_small_pressed 24x24 at (24,136): a square cream-and-brown key with a 3-px darker bottom edge (pressed is 1 px lower); keycap_wide_normal 48x24 at (48,136) and keycap_wide_pressed 48x24 at (96,136): the same key, wide.
9. Gamepad key backs, 24x24 round-ish: keycap_pad_a at (0,160) green-tinted, keycap_pad_b at (24,160) red-tinted, keycap_pad_x at (48,160) blue-tinted, keycap_pad_y at (72,160) amber-tinted, keycap_pad_trigger at (96,160) a grey trigger shape. NO letters.
10. slider_track - 48x8 at (0,192): a groove like bar_bg but thinner; slider_grabber - 12x16 at (48,192): a brass knob; slider_grabber_hover - 12x16 at (60,192): the same, brighter.
```

## Sheet C - icons (two prompts: C1 24x24, C2 16x16 small set)

```
SHEET C1. Draw 24x24 pixel icons on the transparent 1024x1024 sheet, one per 24x24 cell, 10 columns, 7 rows; cell (column c, row r) starts at (c*24, r*24) in art pixels. Each icon is centred, uses a 1-px #120d09 outline, flat colours from the palette, a clear silhouette readable at small size, NO text.
Row 0 (tools): rock hammer, pickaxe, steel pickaxe, pointed chisel, flat chisel, sledgehammer, hand splitter, power drill, jackhammer, pneumatic chisel with a short air hose.
Row 1 (resources): limestone block (pale), coal lumps (charcoal), iron ore (rusty brown/grey), copper ore (warm red-brown), gold ore (muted gold), gravel pile (mixed small stones), topsoil pile (dark brown), crushed stone, loose soil, mixed rocks.
Row 2 (economy and people): gold coin with a dollar symbol (the symbol is part of this icon), stack of coins, canvas bag, full bag, worker with a yellow hard hat, miner with a pickaxe, machine operator with ear defenders, hauler with a crate, clerk with a clipboard, wage envelope.
Row 3 (machinery): jaw crusher, conveyor belt piece, hopper, sorting table, output bin, excavator, dump truck, front loader, drilling rig, rock breaker.
Row 4 (objectives and status): flag, star, padlock, warning triangle, check mark, clock, sun, moon, map pin, stage badge.
Row 5 (repairs and gear): wrench, battery, hydraulic hose coil, red fuel can, key, hand cart, wheelbarrow, air compressor, workbench, blueprint roll.
Row 6 (vehicle controls): throttle pedal, brake pedal, dump bed, scoop bucket, boom arm, stick arm, bucket curl, exit door arrow, recover/refresh arrows, auto-crew gear.
```

```
SHEET C2. The SAME icons as C1, redrawn (not shrunk) as clean 16x16 pixel icons, one per 16x16 cell, 16 columns, 7 rows (cell (c,r) starts at (c*16, r*16)), same order as C1 (10 icons per row, columns 0-9). Simplify the shapes: fewer details, 1-px outline, readable at 16x16.
```

## Sheet D - minimap frame, compass and markers

```
SHEET D. Draw these sprites on the transparent 1024x1024 sheet (art pixels):
1. map_frame - 48x48 at (0,0): a nine-slice map frame: brass and dark-wood border, 12-px corners with rivets, a thin inner shadow line, and a COMPLETELY TRANSPARENT centre (the live map shows through). Plain edges.
2. map_compass - 32x32 at (48,0): a small brass compass rose with a clear north point, no letters.
3. map_north_tag - 16x16 at (80,0): a small brown plate with a bold pixel letter N (the only letter allowed on this sheet).
4. mk_player - 12x12 at (0,48): a cream arrow/chevron pointing UP (north).
5. Buildings, 12x12 each in a row from (12,48), step 12: mk_entrance (gate arch), mk_office (small office building), mk_workshop (building with a wrench), mk_garage (building with a roll door), mk_storage (crate stack), mk_home (small house).
6. Area markers 12x12: mk_area_open at (0,60) green pickaxe-on-square, mk_area_locked at (12,60) grey padlock-on-square, mk_area_done at (24,60) gold check-on-square.
7. mk_road_dash - 8x4 at (48,60): a gold dashed road segment that tiles horizontally.
8. Machinery 12x12 in a row from (0,72), step 12: mk_excavator, mk_truck, mk_loader, mk_crusher, mk_rig, mk_belt; then mk_worker at (72,72) a small person dot, mk_debris at (84,72) a small rock-and-weed dot in red.
9. Objective pin, 2 frames 12x12: mk_objective_1 at (0,84) a red-orange map pin, mk_objective_2 at (12,84) the same pin slightly larger/brighter (for a pulse).
10. New-section sparkle, 3 frames 12x12: mk_new_1 at (24,84), mk_new_2 at (36,84), mk_new_3 at (48,84): a gold four-point star growing then fading.
```

## After generating (you, not ChatGPT)

1. Slice each sprite by its position/size, shrink x4 with nearest-neighbour, save under the filename into `assets/ui/hud/` (icons into `assets/ui/hud/icons/`, map pieces into `assets/ui/hud/map/`).
2. Check each nine-slice piece against its margins in `UI_ART_ASSET_HANDOFF.md` (the centre and edges must be plain).
3. Follow `HUD_REDESIGN_IMPLEMENTATION.md` to switch the game over; until a file exists the game keeps its current look for that piece.
