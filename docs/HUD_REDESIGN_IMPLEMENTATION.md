# HUD redesign - how the generated PNGs replace the current styling

Status: **not started in code, by design.** The artwork does not exist yet; nothing here may be claimed done until the PNGs are in `assets/ui/hud/`, wired in, and the checks at the end pass. Until a given file exists, the game keeps its current look for that piece (the fallback rule below), so the work can land piece by piece.

## 1. Where the look is defined today (what gets replaced)

| Look | Code today | Replaced by |
|---|---|---|
| Panel frames (time/money, minimap plate, objective, tool, bag, drive plate) | `QuarryPlate` (`scripts/ui_plate.gd`): a `StyleBoxFlat` plus procedural `_draw` (top light, rivets, strip). Created by `hud.gd _panel()` | `StyleBoxTexture` from `hud_panel_main.png` (nine-slice 12,12,12,12) + `hud_strip_*.png` as a child `TextureRect`; rivets are baked into the art |
| Generic panels / theme | `QuarryTheme.panel_box()` (`scripts/ui_theme.gd`), also the theme's `PanelContainer`, `Button` styleboxes | `UiSkin.box(name)` (new, below) returning a texture box or the old flat box |
| Station panels, rows, cards | `station_ui.gd` `_box()`, `_style(kind, state)`, `make_button()`, `vbutton()`, `slider_row()` | `hud_panel_inset`, `btn_<kind>_<state>`, `slider_track/grabber` |
| Progress bars | `hud.gd _bar()` (`ProgressBar` + flat fill), the new progress blocks (`_progress_block`) | `TextureProgressBar` (below) |
| Key hints | `key_hints.gd` (a `StyleBoxFlat` key cap + label) | `keycap_small/wide_*` as the cap `StyleBoxTexture` |
| Dialogues | `walter_dialog.gd`, `intro_dialog.gd` (`panel_box`) | `hud_dialog_frame` + `hud_portrait_frame` |
| Prompt / toasts / banners | `hud.gd prompt_panel`, `toast()`, `show_card()` | `hud_prompt_bar`, `hud_toast_frame`, `hud_banner_frame` |
| Vehicle plate | `hud.gd` DrivePlate | `hud_vehicle_plate` |
| Icons | `ui_art.gd` (`UiArt.icon(name, small)`, files `assets/ui/icons/*.png`), `hud_icon.gd` (drawn icons) | the Sheet C set, mapped by name (table in section 4) |
| Minimap | `hud_minimap.gd` (`QuarryMinimap`, procedural `_draw`) | procedural content kept; `map_frame` drawn over it; markers as sprites instead of drawn shapes |

Fonts stay as they are (Atkinson Hyperlegible, `QuarryTheme.body()/bold()`): **no text is baked into any art**.

## 2. Import and loading rules

- Put sliced PNGs in `assets/ui/hud/` (icons `assets/ui/hud/icons/`, map `assets/ui/hud/map/`). Godot import: **Filter off (Nearest), Mipmaps off, Compression Lossless, Fix Alpha Border on**. Project default texture filter is already linear for UI text; set `texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST` on every control that draws these sprites (set in `UiSkin`, not per scene).
- Scaling: the art is authored in base canvas pixels; the existing canvas-items stretch (x2 at 1080p, x1.33 at 720p, x1 at 540p) scales it. At 720p x1.33 is a non-integer scale: nearest-neighbour then gives uneven pixels. Mitigation: keep UI at integer scale by setting the window's minimum UI scale to 1/2 steps (`Window.content_scale_factor` snapped to 1, 2, 3) for the HUD layer only, or accept slight unevenness at 720p. Decide at integration time by looking at the 720p result.

## 3. Code plan (small, in this order)

1. **`scripts/ui_skin.gd` (new, `class_name UiSkin`).** One loader with a cache:
   - `static func box(name: String, fallback: StyleBox) -> StyleBox` - if `res://assets/ui/hud/<name>.png` exists returns a `StyleBoxTexture` with `texture_margin_*` taken from a **margin table** (the table in `UI_ART_ASSET_HANDOFF.md`, kept as a const dictionary `MARGINS` in this file), `axis_stretch_*` = tile for plain edges, `modulate_color` = white; otherwise returns `fallback`.
   - `static func tex(name) -> Texture2D` (cached, null if missing), `static func has(name) -> bool`.
   - A test (`tests/test_ui_skin.gd`) checks every file named in `MARGINS` loads, is non-empty, and that margins are smaller than half the size.
2. **Panels.** In `QuarryPlate._init`, replace the `StyleBoxFlat` by `UiSkin.box("hud_panel_main", <the current flat box>)`; when the texture box is used, skip the procedural `_draw` light/rivets and add the coloured strip as a `TextureRect` child (`hud_strip_<colour>`, stretched to the plate height, left edge). `QuarryTheme.panel_box()` takes an optional `skin_name`; `station_ui._box()`/cards pass `hud_panel_inset`.
3. **Buttons.** `station_ui._style(kind, state)` returns `UiSkin.box("btn_%s_%s" % [kind, state], <flat box>)`. Label colour/offset rules stay in code (main = dark text; pressed label sinks 1 px via content margins already used).
4. **Progress bars.** Replace `hud._bar()`'s `ProgressBar` with a small `QuarryBar` (`extends TextureProgressBar`): `texture_under = bar_bg` (nine-patch: `nine_patch_stretch = true`, margins 5/5/5/5), `texture_progress = bar_fill_<colour>` (margins 3/0/3/0), end caps as two `TextureRect`s, `bar_complete` overlay shown when `value >= max_value` (fade in 0.3 s). **Values stay live**: the same `value` / `_obj_target` easing code drives it; fill colour = which fill texture is assigned. Fallback: if the textures are missing the old `ProgressBar` look is used (a `QuarryBar` that draws the flat style).
5. **Hints.** `key_hints.gd` builds each cap with `UiSkin.box("keycap_small_normal")` / `keycap_wide_normal` chosen by label length (<=2 chars small); gamepad mode uses `keycap_pad_*` by button name. A key currently held (`Input.is_key_pressed`) switches to the `_pressed` box.
6. **Dialogues, prompt, toasts, banners, vehicle plate, repair prompt.** Each calls `UiSkin.box(...)` where it now calls `QuarryTheme.panel_box(...)`; no layout changes. The repair sequence captions use `hud_repair_prompt` (the prompt line `hud.set_prompt` gets a `kind` argument: "action" or "repair").
7. **Icons.** `UiArt.icon(name, small)` first looks for `assets/ui/hud/icons/<mapped>.png` (24 px, or the C2 16 px set when `small`), then the existing `assets/ui/icons/<name>.png`. No draw-code changes.
8. **Minimap.** `QuarryMinimap._draw` keeps drawing terrain, levels (open filled / locked faint), roads, positions. Changes: (a) frame: a `NinePatchRect` with `map_frame` over the map control; (b) compass + north tag as `TextureRect`s in the frame corner; (c) markers: replace the drawn shapes for player (rotated by `-player.rotation.y`), entrance, office/workshop/garage/storage/home, area markers (open/locked/done from `prog.area_available/area_complete`), machinery (from `vehicle_nodes`, rigs, crushers), workers, debris, objective pin (alternate `mk_objective_1/2` every 0.5 s), and "new section" sparkle (3 frames, shown for 20 s after `quarry_level` increases or an access road is built) with `draw_texture_rect`. All positions come from `to_map()` exactly as now. **The map must show:** player position and facing, quarry entrance, office/workshop, excavation areas, roads, important machinery, the active objective, newly unlocked sections - each is a data row in `snapshot()` (a test already reads it; extend it with `entrance`, `buildings`, `machines`, `new_sections` so the checks do not depend on pixels).
9. **Completion states.** Objective checkbox rows use `checkbox_empty/done`; a finished bar plays `bar_complete` and lights `hud_rivet_lit` on its panel for 1.5 s (the existing `hud.toast` "unlock" kind also uses `hud_banner_frame`).

## 4. Icon name mapping (existing id -> new file)

`hammer`->`tool_hammer`, `pickaxe`->`tool_pickaxe`, `chisel`->`tool_chisel_pointed`, `drill`->`tool_drill`, `jackhammer`->`tool_jackhammer`, `bag`->`bag`, `money`->`money_coin`, `stone`/`limestone`->`res_limestone`, `coal`->`res_coal`, `iron_ore`->`res_iron`, `gold`->`res_gold`, `crusher`->`m_crusher`, `conveyor`->`m_conveyor`, `excavator`->`m_excavator`, `truck`->`m_truck`, `loader`->`m_loader`, `drill_rig`->`m_drill_rig`, `miner/operator/hauler/clerk`->`worker_*`, `staff/workers`->`worker`, `wages/payroll`->`wage`, `milestones`->`obj_flag`, `stats`->`obj_stage`. Anything without a mapping keeps its current icon.

## 5. Rules that keep the HUD working

- **No layout code changes** in the first pass: art changes frames and fills only. Minimum sizes of panels may grow by the border thickness difference; check each plate at 960x540 and 1920x1080.
- **Live values** (money, time, percentages, counts, names, key names, prompts) are always `Label`s over the art. Art never contains values.
- **Fallback is mandatory**: every `UiSkin` call has a flat fallback, so a missing or misnamed PNG shows the old look instead of an empty or white box. A debug line lists missing files once at startup.
- **Touch and gamepad** keep their current layouts (`touch_controls.gd` buttons stay procedural circles unless a `touch_btn` sheet is added later).
- **Performance:** one `StyleBoxTexture` per name (cached); no per-frame texture creation; the minimap redraw rate (a few times a second) is unchanged. Keep draw calls in check with `tests/test_graphics_budget.gd`.

## 6. Order of work and acceptance

1. `UiSkin` + margins table + `test_ui_skin` (no art needed: runs on whatever files exist).
2. Panels and theme (Sheet A) -> check every plate and station menu.
3. Buttons, sliders, hints (Sheet B).
4. Bars with completion state (Sheet B).
5. Icons (Sheet C) by mapping.
6. Minimap frame and markers (Sheet D) and the extended `snapshot()` tests.

Done means **all of**: every file in the asset table is present and loaded (no fallback lines logged); `tools/run_tests.sh` passes (HUD, readability, menu, minimap, graphics-budget suites included); the 14 HUD elements in the handoff checklist use the new art at 960x540, 1280x720 and 1920x1080 with nothing clipped or overlapping; values remain live and correct (objective test `tests/test_objective_progress.gd`); and a person has looked at the result on screen. None of that is claimed yet.
