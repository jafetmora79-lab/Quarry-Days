# The Cash Hopper and automated selling (Phase 1: gameplay foundation)

Branch `feature/cash-hopper-foundation`, built on `feature/intro-world-ui-polish`. Not merged into `main`.

## What changed in one paragraph

The sales clerk and the Quick Sell kiosk are retired. Grandpa Walt's **old Cash Hopper** stands east of the office from the first minute. Put material in once (bag, cart, storage
crate, or a belt) and it sells it **one unit at a time**, wherever you are: every unit leaves the queue and is paid in the same step, at the price in `data/economy.json`
(the only price table). Selling needs no truck, no clerk and no repeated clicking.

## How it works

* **One structure, many reused systems.** A Cash Hopper is an `output` structure with `variant = "cash_hopper"` (`scripts/business.gd`). It therefore inherits placement,
  belt links, merger feeding with round-robin turns, backpressure (`ep_space`), saving and loading, and the Production Overview. Nothing about belts or crushers was redesigned.
* **Selling loop:** `Business.tick_cash_hoppers(seconds)` runs from `Business.tick` every frame, wherever the player is. Progress accumulates at the tier's rate; each whole
  unit picks the next material (the one in progress, otherwise the dearest first), removes one unit from the queue, pays `state.payout(res, 1)` through
  `state.add_income(pay, "hopper")`, and updates lifetime sales, the daily log, the hopper's own counters and the automated-business goal. One `cash_sold` signal per material
  per tick drives the feedback, so a fast hopper groups its show while every unit is still booked.
* **Tiers (data, `data/business.json` -> `cash_hopper.tiers`):** Grandpa's Old Hopper 24 units/s (queue 300: a full bag sells in about a second), Motorized 48/s (800, upgrade $900), Industrial 96/s (2400, upgrade $3500).
  The upgrade button is on the hopper's panel. The tier is saved.
* **Ways in:** the panel (E on the hopper): `DEPOSIT ALL` and `DEPOSIT SELECTED` (bag), `FROM CRATE` (an explicit choice), `CLOSE`, `UPGRADE`; the Carts panel (`TO HOPPER` /
  `ALL TO HOPPER` when the cart is beside it); belts. A belt out of the storage crate to a hopper carries whatever the crate holds (`"auto"` resource, dearest first) but only
  because the player built that route: storage never sells by itself. Crushers, mining rigs and mergers feed it like any bin.
* **Transactions:** deposits are move operations clamped to the room left (nothing created or lost); a sale removes the unit and credits it in one step. Saving in the middle of
  a sale keeps the queue, the processing progress, the tier, today's and lifetime revenue (`snapshot` / `restore` already carried the `outputs` records).
* **Clerk retired:** `"clerk"` is no longer a profession; no clerk candidates; an old save's clerks are let go on load (their unpaid wages are forgiven; everything else is
  kept). The milestone "Automated business" now counts crushed stone sold through a Cash Hopper (`auto_crushed_sold`). A sorting table is worked by hand now (the clerk was
  the only worker that operated it).
* **Quarry OS Sales app:** statistics only: total revenue, today's revenue, materials sold, the hopper's status (speed, queue, what it is selling, today / all time), revenue by
  material (units sold x price table) and earnings by day.
* **Old saves:** a save with no hopper gets Grandpa's at the same spot on load; a hopper record without the new fields loads at the first tier.
* **Grandpa's introduction:** the first time you press E at the hopper, a short card from Walt explains it, then the panel opens (flag `story.hopper_intro`).
* **Tests:** `tests/test_cash_hopper.gd` (39 checks): the 10 acceptance scenarios (see the delivery notes).

## Feedback

Per burst: rocks falling into the funnel (a few, never one per unit), a mechanical clunk (3 samples, random pitch), a short coin sound (random pitch), floating green (amber when
big) `+$n` over the machine, the flywheel spinning while it works, a flap kicking, and the machine's display (tier, material, waiting / capacity, today's earnings, speed). The HUD
cash counter already counts up smoothly (its own pop-ups are suppressed for hopper income so the machine carries the show).

## Visual replacement contract (Phase 2, Blender)

`scripts/cash_hopper_view.gd` owns every visual and no gameplay. To replace the placeholder, export a model to **`res://assets/world/WLD_QD_cash_hopper.glb`**; if it exists it is
shown instead of the primitives. Conventions: 1 unit = 1 m, +Y up, the machine's front (display) faces -Z, origin on the ground at the footprint centre, footprint about
1.9 m x 1.9 m x 1.5 m (the game's collision box; the funnel may rise above it). Name empty nodes / parts in the model with these names and the matching attachment moves to them:

| Name | Purpose |
|---|---|
| `Attach_Body` | the hopper frame |
| `Attach_InputFunnel` | the wide mouth the rocks fall into (also where the queue heap is drawn) |
| `Attach_Processor` | the processing section |
| `Attach_ConveyorIn` | where a belt meets it (informational; the game links belts by distance, 1.7 m) |
| `Attach_RockSpawn` | where a falling rock starts |
| `Attach_Audio` | the 3D audio source (clunk and coin) |
| `Attach_FloatText` | where the floating `+$n` starts |
| `Attach_Display` | the status screen (a Label3D reading from -Z) |
| `Pivot_Flywheel` | spins about its local X while it works |
| `Pivot_Flap` | hinge about its local X that kicks on every sale |

## Visual assets to replace in Phase 2 (everything still a placeholder)

1. **The Cash Hopper itself** (`CashHopperView` primitives: plinth, processing box, funnel cone, flywheel, flap, chute, display panel). Biggest priority; a rusty old
   hopper that looks like Grandpa's. Optionally three variants for the Motorized and Industrial tiers (the tier name is shown on the display; the model is shared today).
2. **Rock chunks** that fall into the funnel (small boxes today).
3. **Storage bin** (`main._place_storage_body` and `QuarryArt` dress functions): still the old procedural crate; a Blender bin with an open top and a belt port.
4. **Output bin / small hopper / sorting table** (`art.dress_output`, `dress_hopper`, `dress_sorter`): procedural.
5. **Conveyor pieces** (straight, corners, merger, splitter, short, incline, support legs): procedural `MeshKit` models; not redesigned in this phase.
6. **Crushers** (jaw and advanced) stay procedural until Phase 2.
7. A **sign / plaque** for the hopper, and a **coin burst** particle sprite (the coin is only a sound today).

## Known limits / not done

* The old truck delivery sale to the office (`delivery.gd`) still exists as an *optional* way to cash in a load; nothing requires a truck any more.
* Loose rock pieces on the ground are picked up into the bag first (E), then deposited; they are not thrown into the funnel directly.
* The Blender-asset viewer (`docs/`) was not updated with the temporary hopper.
* The panel refreshes twice a second while open (so you can watch the queue shrink); a rebuild resets button hover for an instant.
