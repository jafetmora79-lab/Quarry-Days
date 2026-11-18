# Cash Hopper

- Model: `tools/world_models/hopper_model.py` (Blender 5.x, built by `build_world.py -- cash_hopper`) -> `assets/world/WLD_QD_cash_hopper.glb` (+ `src/cash_hopper.blend`). Separate named objects: Body (cabinet), Rim, Brackets, Panel
  (access panel, emblem, hinges, inspection window, stats screen), SaleDisplay, Lamp_Status/2, Pivot_Funnel (hopper), Pivot_Drawer + Cash_1..4 (drawer and four reusable cash bundles), Pivot_GearA/B, Pivot_RollerA/B, Pivot_Flywheel/Flap/Piston.
- Clips in the GLB (AnimationPlayer): Idle, SaleRegistered, Processing, Counting, DrawerOpen, DrawerClose, ReturnToIdle.
- Gameplay: `scripts/cash_hopper_view.gd` only SHOWS a sale; `Business` books the money and stock first (`cash_sold`). Six phases (~3.2 s; a sale within 4 s of the last plays the short version, sales that arrive during
  a payout are summed and paid out in the same open drawer): idle -> sale registered -> processing -> counting -> payout -> complete.
- Test: `tests/test_hopper_sequence.gd`. Comparison picture: `docs/previews/cash_hopper_comparison.png`.
