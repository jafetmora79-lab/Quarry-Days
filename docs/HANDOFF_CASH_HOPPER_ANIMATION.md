# Handoff: the Meshy Cash Hopper animation (branch `claude/cash-hopper-meshy`)

Written 2026-11-23 for whoever touches the Cash Hopper next. **This branch is based on `feature/player-character` (b256272).** It contains only the hopper animation work; nothing else in the game was changed. If another session broke the hopper in the game, compare against this branch before "fixing" anything (see *If it looks broken*).

Standing rules still apply: never merge to `main`, never open PRs, never modify `THE_VEIL_ASSETS_V2/`, never touch money logic from a view.

## What it is
The Cash Hopper (the machine that sells whatever is put into it) now has three Meshy models, one per upgrade tier, and a payout animation:

1. A sale is registered: the funnel thumps, the plate screen starts **counting the amount up** from $0 (coin tick per step).
2. The machine works (funnel shivers, lanterns flare). The plate says what is being sold.
3. The **roll-up shutter** over the payout slot rolls up, then the **tray slides out**. The **cash is already lying in the tray** as its real bills and coins (it was hidden inside while closed), so nothing ever comes out of the screen.
4. The amount locks, the screen flashes and a **PAID** stamp lands; the footer lists the exact bills and coins in the tray.
5. DONE, the tray goes back in, the shutter comes down, the screen returns to its idle page.

Idle = tray tucked fully in, shutter down. The hopper must always look **closed** at rest.

## Files (all on this branch)
| File | Role |
|---|---|
| `scripts/cash_hopper_rig.gd` (`MeshyHopperRig`) | Loads the three tier models, plays the clips on them, owns shutter / tray / funnel motion, lanterns + lights, the cash piles. **No game state, no money logic.** |
| `scripts/hopper_plate_screen.gd` (`HopperPlateScreen`) | The front plate: idle page, count-up, PAID stamp, DONE; skinned per tier (`SKINS`); tier 2 has a bar chart of the last 8 sales. |
| `scripts/hopper_top_screen.gd` (`HopperTopScreen`) | Status window on tiers 1 and 2: SPEED, running chevrons, queue bar, QUEUE q / cap (+ material on tier 2). |
| `scripts/cash_hopper_view.gd` | **Existing file, edited**: uses the rig when `WLD_QD_cash_hopper_meshy.glb` exists (the Blender hopper is the fallback). See *Hooks in CashHopperView*. |
| `assets/world/WLD_QD_cash_hopper_meshy.glb` | Tier 0 model (13-bone rig from Meshy; skin weights hardened, see tools). |
| `assets/world/WLD_QD_cash_hopper_t2.glb`, `..._t3.glb` | Tier 1 and tier 2 models (static meshes cut into `Body` / `Tray` / `Funnel` nodes). Each GLB has an extracted texture PNG and `.import` files next to it: commit them together. |
| `tools/reweight_meshy_hopper.py` | Makes the tier 0 skin rigid per part (Meshy smeared the cabinet across the tray bones; sliding the tray tore the plate). |
| `tools/split_meshy_hopper.py` | Stands a static Meshy hopper at the game's size (1.7 units tall, base at y = 0) and cuts it into `Body` / `Tray` / `Funnel`. |
| `tests/test_cash_hopper_rig.gd` | 59 checks on the rig and screens alone (no game): amounts, tiers, clips, tray/cash, count-up. |
| `CHANGELOG.md` | Entries for each step. |

## Tier mapping
`CashHopperView.TIER_LOOK` / `Business.cash_tier_index` decide the tier; the rig follows it through `rig.apply_tier(ti)`.

| Tier | Game name | Model | Look |
|---|---|---|---|
| 0 | Grandpa's Old Hopper | `..._meshy.glb` (skeleton) | tinted worn grey, one lantern, green terminal |
| 1 | Motorized Hopper | `..._t2.glb` | green steel + hazard stripes; lanterns + lit tube + tray light; amber screen, LV2 badge, segmented bar; status window on top |
| 2 | Industrial Hopper | `..._t3.glb` | dark steel; most light (lanterns, tube, four corner lamps, strong tray light); cyan/gold screen, LV3 badge, bar chart; status window |

Swapping which model is which tier = reorder `GLBS` and `CFG` in `cash_hopper_rig.gd`. The per-tier numbers in `CFG` (plate position, shutter, tray rest/slide, lamp positions) were measured from each model; they are **not** interchangeable between models.

Gameplay numbers (speed, capacity, upgrade cost) are in `data/business.json` (`cash_hopper.tiers`: 24/48/96 units per second, 300/800/2400 capacity, $0/$900/$3,500). **The animation changes none of them.** The upgrades are visually distinct and have more informative screens; there is no extra bonus.

## The contract: how it must work
- **The view only shows sales that were already booked.** `Business.cash_sold` has paid the money and moved the stock before `CashHopperView.on_sold` is called. No frame of any animation may pay, pay twice, or change stock. The rig and the screens never touch money.
- **One number everywhere.** The plate's count-up target, the PAID amount, the note above the machine and the cash in the tray all come from the same booked amount (`run_money` in `_run_sequence`).
- **The cash in the tray is exact.** `MeshyHopperRig.breakdown(money)` is greedy over $500 / $100 / $20 / $5 / $1, so the pieces always add up to the amount (tested). Piles are drawn up to `PILE_CAP` = 8 per denomination; the plate footer (`breakdown_text`) always has the exact counts. Colours: $500 purple, $100 blue, $20 green, $5 pale grey-green, $1 gold coins.
- **Material is exact.** The plate title is `SALE n x MATERIAL` for one material, `SALE n UNITS` with a `MATERIAL a   MATERIAL b` line when several were sold. `_flush` collects `{res: units}` for the batch; do not collapse it to the biggest material.
- **Sales that arrive while the drawer is open** are summed into the same open drawer: the number continues from where it is (`sale(total, ..., from = shown_amount())`) and the cash piles are rebuilt for the new running total (`pay_out(run_money)`).
- **Closed at rest.** The tray rests at `CFG[tier].closed` (pushed in behind the shutter); it is NOT left half out as the models were modelled. The shutter is the only thing hiding the open slot, so keep it.
- **Order of motion:** open = shutter up, then tray out; close = tray in, then shutter down. Cash is shown only once `tray_open > 0.3`.
- Clip names are the Blender hopper's (`Idle`, `SaleRegistered`, `Processing`, `Counting`, `DrawerOpen`, `DrawerClose`, `ReturnToIdle`); `CashHopperView._play` returns the clip length so the sequence waits the right time. The payout is held open about 1 s (`0.55` quick) so the cash and the stamp can be read.

## Hooks in `CashHopperView` (everything the view had to change)
Search the file for `rig`:
- `setup()`: build the rig first (`MeshyHopperRig.available()`), set `model = rig.model`, move the `Attach_*` markers to `MeshyHopperRig.MARKERS`, connect `rig.tick` to `_count_tick`. If the rig is built, the Blender branch is skipped and `display` / `sale_display` / the plaque are not created.
- `_build_extras()`: skips the Blender-only screens; `sparks.position = MeshyHopperRig.TRAY_POINT`.
- `_apply_tier()`: `rig.apply_tier(ti)` (switches model, lights, screens); the per-part steel recolouring is skipped when a rig exists. The view's own `scale` per tier (`TIER_LOOK`) still applies.
- `_set_lamp()` -> `rig.set_lamp(level)`; `_play()` -> `rig.play(clip, speed)`; `_process` skips the old flywheel spin when a rig exists.
- `_flush()` / `_run_sequence(money, units, res, mats)`: collect materials; at *registered*: `rig.screen.sale(run_money, run_units, _mat_names(run_mats), secs, from)`; at *payout*: `rig.pay_out(run_money)` before opening the drawer, `rig.screen.paid(breakdown_text(run_money))` after; at *complete*: `rig.screen.done()`; at the end `rig.screen.back_to_idle()`.
- `_refresh_display()`: feeds the idle page (`rig.screen.set_idle`) and the status window (`rig.top_screen.set_stats`).

Intake animations (rocks falling, the bucket pour, the heap in the funnel) were **not changed**; they use the same `Attach_InputFunnel` / `Attach_RockSpawn` markers, which `MeshyHopperRig.MARKERS` places for the new funnel. Those positions are estimates (see below).

## How to check it
```
godot --headless --path . --import          # after pulling: imports the new GLBs
godot --headless --fixed-fps 60 -s tests/test_cash_hopper_rig.gd     # 59 checks on the rig/screens alone
godot --headless --fixed-fps 60 -s tests/test_cash_hopper.gd         # the game-level hopper suite (not run against this branch yet)
```
By eye, in the game: sell a mixed load. You should see the plate count up, the shutter roll up, the tray slide out already holding piles that match the footer, PAID, then everything close. Upgrade the hopper: the model, light and screen change. A closed hopper must show only the shutter under the plate, no yellow lip, no empty gap.

## What was and was NOT verified
- Verified: the rig and the screens in an isolated project (their scripts + `CashHopperView` with a stub business), by rendered frames (GIFs were sent to the user) and by `tests/test_cash_hopper_rig.gd`.
- **NOT verified: the real game.** The full project did not finish importing in the container that built this (the headless `--import` sat idle with almost no CPU and imported nothing; the last lines of its log are errors loading the project theme `qd_theme.tres` -> `qd_body.tres` -> `VeilPixel.ttf`. The cause was not found, and I did not confirm that the theme is what blocks it). So `test_cash_hopper.gd`, `Main.tscn`, saves, belts feeding the hopper, the bucket pour and Windows were not run against this branch. Run them first.
- Known rough edges: 13 triangles in the tier 1 tray join stay on the body (a hairline gap may show while the tray moves); the tier 1/2 status window sits over the model's slanted recess rather than inside it; the funnel heap / falling rocks use estimated marker positions for the new funnel (a full hopper may clip its walls); `CashHopperView._sfx(..., secs)` logs "Lambda capture ... was freed" when a sound ends before its timer (this existed before; harmless).

## If it looks broken
1. `git diff b256272 claude/cash-hopper-meshy -- scripts/cash_hopper_view.gd` shows exactly the view changes; every one is behind `rig != null`, so the old hopper path is unchanged.
2. Run `tests/test_cash_hopper_rig.gd`. If it passes, the rig and screens are fine and the problem is in the view hooks above.
3. Common breakages: a model GLB not re-imported (`.import` / PNG missing); `class_name` cache stale (re-run `--import`); somebody re-introduced `display` / `sale_display` on top of the plate; a change that pays or counts money inside the rig; a change that moves the tray/shutter by hand instead of through `play()`.
4. The three models are meant to be replaced by editing `CFG` (positions) after re-running `tools/split_meshy_hopper.py` on a new static model; measure the plate face, the slot, the tray lip and the lanterns from an orthographic render (the numbers in `CFG` were taken that way).

## Possible next steps (not started)
- Real gameplay differences per upgrade (a sale bonus on tier 2, a bigger tray) if the user wants them; this changes balance, ask first.
- Replace the procedural shutter slats with a modelled shutter; add sounds for the shutter and the tray (only the coin tick per count step and the existing clunk / chink sounds exist).
