# Quarry Days - HUD pixel-art asset handoff

What to generate, at what size, where each piece goes. Companion files: `CHATGPT_UI_IMAGE_PROMPTS.md` (copy-paste prompts) and `HUD_REDESIGN_IMPLEMENTATION.md` (how the PNGs are wired in).

## Ground rules

- **Canvas.** The game draws at 960x540 and the window scales it x2 at 1080p (`stretch/mode=canvas_items`, `aspect=expand`). All sizes below are in those **base pixels ("art px")**. One art pixel = one canvas pixel = 2x2 screen pixels at 1080p.
- **Sheets.** Each sheet is **1024x1024 px with 4x4 sheet pixels per art pixel**, i.e. a **256x256 art-px grid**. Positions below are art px from the sheet's top-left; multiply by 4 for sheet px. After generating, slice each piece, shrink it by 4 with **nearest-neighbour**, save it as its own PNG named as in the tables. (If a generated sheet is not pixel-aligned, regenerate it or re-draw it on the grid rather than resampling.)
- **Transparency.** Every piece has a transparent background (alpha PNG). No drop shadows baked in outside the frame (the game adds its own soft shadow). No anti-aliasing: hard 1-art-px outline, no gradients beyond 2-3 flat tones per material.
- **Palette (use only these families).** Dark brown `#211913` / `#2d2118` (panel body), warm wood `#6b4a2b` / `#8a6238`, aged brass `#b88f57` / `#e0b86a` / `#fac257` (accent), rust orange `#db7529`, olive green `#7fb04f` / `#9ee07a` (good/progress), warning red `#e0583f`, cream `#fcf2d6` (highlights/typography), outline near-black `#120d09`.
- **No text and no numbers in any art.** Labels, values, percentages and hints stay live text drawn by the game (Nunito Sans / Pixelify Sans / Silkscreen / VT323 via QuarryTheme). Leave the *safe text area* of each piece empty.
- **Nine-slice.** "Margins" are (left, top, right, bottom) in art px, for Godot `StyleBoxTexture` / `NinePatchRect`. The centre and the edge strips must be plain (tileable or flat) so the piece can stretch.
- **States.** Where listed, supply one PNG per state, same size, same margins.
- **Do not bake the HUD layout.** One reusable frame per kind of panel; the game places and sizes them.

## Sheet A - frames, panel borders, corners (256x256 art px)

| File (`assets/ui/hud/`) | Size | Sheet position | Nine-slice margins | States | Safe text area | Replaces / integration |
|---|---|---|---|---|---|---|
| `hud_panel_main.png` | 48x48 | (0,0) | 12,12,12,12 | normal | inner area inside margins (min 24x24) | `QuarryPlate` background (`ui_plate.gd`, used by `hud.gd _panel()`): time/money, minimap plate, objective, tool, bag, drive plate |
| `hud_panel_inset.png` | 48x48 | (48,0) | 10,10,10,10 | normal | inside margins | recessed rows inside panels (inventory slots, list rows): `station_ui.gd _box()`, `management_ui.gd _card()` |
| `hud_panel_title.png` | 64x24 | (96,0) | 12,8,12,8 | normal | centre 40x8 | header plate behind panel titles ("STAGE 1/12 ...", "PAUSED") |
| `hud_prompt_bar.png` | 64x24 | (160,0) | 12,8,12,8 | normal | centre | contextual action box above the tool/bag bar (`hud.gd prompt_panel`) |
| `hud_dialog_frame.png` | 64x48 | (0,48) | 16,16,16,16 | normal | inside margins; keep the left 40 px free for the portrait | Walter / hire dialogues (`walter_dialog.gd`, `intro_dialog.gd`) |
| `hud_portrait_frame.png` | 40x40 | (64,48) | 10,10,10,10 | normal | inner 20x20 (the portrait sits here) | dialogue portraits, hire list, staff cards |
| `hud_toast_frame.png` | 64x32 | (112,48) | 14,10,14,10 | normal | inside margins | notifications (`hud.gd toast()`) |
| `hud_banner_frame.png` | 96x32 | (160,48) | 24,12,24,12 | normal | centre | stage / milestone / achievement banners (`hud.gd show_card()`, unlock toasts) |
| `hud_vehicle_plate.png` | 48x48 | (0,96) | 12,12,12,12 | normal | inside margins | vehicle plate (`hud.gd DrivePlate`): name, speed, load, controls |
| `hud_repair_prompt.png` | 64x32 | (48,96) | 14,10,14,10 | normal | inside margins | repair prompts ("E: fit the battery", repair sequence captions) |
| `hud_strip_green.png`, `hud_strip_gold.png`, `hud_strip_red.png`, `hud_strip_blue.png` | 4x32 each | (120,96),(128,96),(136,96),(144,96) | 0,4,0,4 (stretch vertically) | one per colour | n/a | coloured left strip of a panel (`QuarryPlate.accent`): money = gold, objective = green, warnings = red, info = blue |
| `hud_corner_tl.png`, `hud_corner_tr.png`, `hud_corner_bl.png`, `hud_corner_br.png` | 16x16 each | (152,96),(168,96),(184,96),(200,96) | none | one per corner | n/a | optional ornaments drawn over panel corners (brass brackets / rivet plates) |
| `hud_divider.png` | 64x8 | (0,144) | 8,0,8,0 | normal | n/a | separator line between sections of a panel (replaces `HSeparator`) |
| `hud_rivet.png`, `hud_rivet_lit.png` | 8x8 each | (72,144),(80,144) | none | normal / lit | n/a | rivets on frames; lit = objective complete flash |

## Sheet B - progress bars, indicators, buttons, control hints (256x256 art px)

| File | Size | Sheet position | Margins | States | Safe area | Integration |
|---|---|---|---|---|---|---|
| `bar_bg.png` | 48x12 | (0,0) | 5,5,5,5 | normal | the groove (inner 38x2 minimum) | `TextureProgressBar` under-texture for every bar: stage, cleanup, area, tool durability, bag, power (`hud.gd _bar()`) |
| `bar_fill_green.png`, `bar_fill_gold.png`, `bar_fill_red.png`, `bar_fill_blue.png` | 48x8 each | (48,0),(96,0),(144,0),(192,0) | 3,0,3,0 | per colour | whole piece | bar fill (progress texture): green = good/area, gold = stage/objective, red = cleanup/danger, blue = info |
| `bar_cap_left.png`, `bar_cap_right.png` | 8x12 each | (0,16),(8,16) | none | normal | n/a | end caps drawn over the bar ends |
| `bar_complete.png` | 48x12 | (16,16) | 5,5,5,5 | one | n/a | overlay (shine/glow, alpha) shown when a bar reaches 100% (completion state) |
| `state_dot_off.png`, `state_dot_on.png`, `state_dot_warn.png`, `state_dot_done.png` | 12x12 each | (64,16),(76,16),(88,16),(100,16) | none | four states | n/a | indicator lights: machine running, objective open / done, blocked |
| `checkbox_empty.png`, `checkbox_done.png` | 16x16 each | (112,16),(128,16) | none | two | n/a | objective list items (replaces "[ ]" / "[x]" text) |
| `btn_primary_normal/hover/pressed/disabled.png` | 48x24 each | grid origin (0,32): column per state, x = 0,48,96,144 | 10,8,10,8 | 4 | text centre; pressed art sits 1 px lower | default action buttons (`station_ui.gd make_button`, kind "primary") |
| `btn_main_normal/hover/pressed/disabled.png` | 48x24 each | row y=56 | 10,8,10,8 | 4 | same | the one call to action (RESUME, SELL ALL): amber |
| `btn_danger_normal/hover/pressed/disabled.png` | 48x24 each | row y=80 | 10,8,10,8 | 4 | same | destructive actions (NEW GAME, Dismiss): muted red |
| `btn_toggle_normal/hover/pressed/disabled.png` | 48x24 each | row y=104 | 10,8,10,8 | 4 | same | small switches (MUTE, Clerk on/off) |
| `keycap_small_normal.png`, `keycap_small_pressed.png` | 24x24 each | (0,136),(24,136) | 8,8,8,8 | normal / pressed | centre 8x8 (one letter) | hint bar key caps (`key_hints.gd`): W, E, B, M |
| `keycap_wide_normal.png`, `keycap_wide_pressed.png` | 48x24 each | (48,136),(96,136) | 10,8,10,8 | normal / pressed | centre | SHIFT, ESC, LEFT CLICK |
| `keycap_pad_a.png`, `keycap_pad_b.png`, `keycap_pad_x.png`, `keycap_pad_y.png`, `keycap_pad_trigger.png` | 24x24 each | (0,160),(24,160),(48,160),(72,160),(96,160) | none | one | n/a | gamepad glyph backgrounds (`gamepad.gd pad_hints`); the letter is live text |
| `slider_track.png` | 48x8 | (0,192) | 4,3,4,3 | normal | n/a | music slider groove (`station_ui.gd slider_row`) |
| `slider_grabber.png` | 12x16 | (48,192) | none | normal / hover (second piece at (60,192) `slider_grabber_hover.png`) | n/a | slider handle |

## Sheet C - icons (256x256 art px, 24x24 cells, 10 columns; row r, column c -> position (c*24, r*24))

All icons: 24x24, transparent, centred, 1-px dark outline, flat shading. A 16x16 "small" version is derived by the game (nearest-neighbour is NOT acceptable for downscaling: ask for the small set separately in prompt C2).

| Row | Files (`assets/ui/hud/icons/`, `.png`) - in column order |
|---|---|
| 0 tools | `tool_hammer`, `tool_pickaxe`, `tool_pickaxe_steel`, `tool_chisel_pointed`, `tool_chisel_flat`, `tool_sledge`, `tool_splitter`, `tool_drill`, `tool_jackhammer`, `tool_pneumatic` |
| 1 resources | `res_limestone`, `res_coal`, `res_iron`, `res_copper`, `res_gold`, `res_gravel`, `res_topsoil`, `res_crushed`, `res_soil`, `res_mixed` |
| 2 economy / people | `money_coin`, `money_stack`, `bag`, `bag_full`, `worker`, `worker_miner`, `worker_operator`, `worker_hauler`, `worker_clerk`, `wage` |
| 3 machinery | `m_crusher`, `m_conveyor`, `m_hopper`, `m_sorter`, `m_output`, `m_excavator`, `m_truck`, `m_loader`, `m_drill_rig`, `m_breaker` |
| 4 objectives / status | `obj_flag`, `obj_star`, `obj_lock`, `obj_warning`, `obj_check`, `obj_clock`, `obj_sun`, `obj_moon`, `obj_map_pin`, `obj_stage` |
| 5 repairs / gear | `rep_wrench`, `rep_battery`, `rep_hose`, `rep_fuel`, `rep_key`, `gear_cart`, `gear_wheelbarrow`, `gear_compressor`, `gear_workbench`, `gear_blueprint` |
| 6 vehicle controls | `drv_throttle`, `drv_brake`, `drv_dump`, `drv_scoop`, `drv_boom`, `drv_stick`, `drv_bucket`, `drv_exit`, `drv_recover`, `drv_auto` |

Integration: icons are looked up by id in `ui_art.gd` (`UiArt.icon(name, small)`, existing `assets/ui/icons/*.png`); the new set replaces files of the same role by name mapping in the implementation guide.

## Sheet D - minimap frame, compass, map markers (256x256 art px)

| File (`assets/ui/hud/map/`) | Size | Sheet position | Margins | States | Safe area | Integration |
|---|---|---|---|---|---|---|
| `map_frame.png` | 48x48 | (0,0) | 12,12,12,12 | normal | the whole inside is the live map (never painted) | frame drawn over `QuarryMinimap` (`hud_minimap.gd`); the map content stays procedural |
| `map_compass.png` | 32x32 | (48,0) | none | normal | n/a | compass rose in the frame corner (north tag) |
| `map_north_tag.png` | 16x16 | (80,0) | none | normal | n/a | "N" plate (the letter is part of the art here only: it is a fixed symbol, not live text) |
| `mk_player.png` | 12x12 | (0,48) | none | 1 (rotated by the game to the facing) | n/a | player arrow |
| `mk_entrance.png`, `mk_office.png`, `mk_workshop.png`, `mk_garage.png`, `mk_storage.png`, `mk_home.png` | 12x12 each | (12,48) ... (72,48) step 12 | none | 1 each | n/a | buildings / gate |
| `mk_area_open.png`, `mk_area_locked.png`, `mk_area_done.png` | 12x12 each | (0,60),(12,60),(24,60) | none | 3 | n/a | excavation area markers (live position / state from the game) |
| `mk_road_dash.png` | 8x4 | (48,60) | none | 1, tileable horizontally | n/a | built roads |
| `mk_excavator.png`, `mk_truck.png`, `mk_loader.png`, `mk_crusher.png`, `mk_rig.png`, `mk_belt.png` | 12x12 each | (0,72) ... (60,72) step 12 | none | 1 each | n/a | machinery |
| `mk_worker.png`, `mk_debris.png` | 12x12 each | (72,72),(84,72) | none | 1 each | n/a | workers, loose weeds / rubble |
| `mk_objective_1.png`, `mk_objective_2.png` | 12x12 each | (0,84),(12,84) | none | 2 frames (pulse) | n/a | active objective pin (animated by alternating) |
| `mk_new_1.png`, `mk_new_2.png`, `mk_new_3.png` | 12x12 each | (24,84),(36,84),(48,84) | none | 3 frames | n/a | "newly unlocked section" sparkle |

The map keeps drawing terrain, levels, roads and live positions procedurally (`hud_minimap.gd`); only its frame, compass and marker sprites are artwork.

## Element checklist (the 14 requested HUD elements -> pieces)

| HUD element | Pieces used |
|---|---|
| 1 Day / time / money | `hud_panel_main`, `hud_strip_gold`, `money_coin`, `obj_sun`/`obj_moon` |
| 2 Minimap and compass | `map_frame`, `map_compass`, `map_north_tag`, all `mk_*` |
| 3 Stage progression | `hud_panel_main`, `hud_panel_title`, `hud_strip_green`, `bar_*` (gold), `obj_stage` |
| 4 Objective list | `checkbox_*`, `hud_divider`, `bar_*` per item |
| 5 Site cleanup bar | `bar_bg`, `bar_fill_red`, `bar_cap_*`, `bar_complete`, `mk_debris` |
| 6 Excavation bars | `bar_*` (green), `state_dot_*` |
| 7 Tool panel | `hud_panel_main`, `tool_*`, `bar_*` (durability) |
| 8 Inventory bag | `hud_panel_main`, `hud_panel_inset`, `bag`, `res_*`, `bar_*` |
| 9 Contextual action box | `hud_prompt_bar`, `keycap_*` |
| 10 Control hints | `keycap_small_*`, `keycap_wide_*`, `keycap_pad_*` |
| 11 Dialogue panels | `hud_dialog_frame`, `hud_portrait_frame`, `btn_primary_*`, `btn_toggle_*` |
| 12 Repair prompts | `hud_repair_prompt`, `rep_*`, `keycap_small_*` |
| 13 Vehicle controls | `hud_vehicle_plate`, `drv_*`, `bar_*`, `keycap_*` |
| 14 Notifications / banners | `hud_toast_frame`, `hud_banner_frame`, `obj_star`, `hud_rivet_lit` |
