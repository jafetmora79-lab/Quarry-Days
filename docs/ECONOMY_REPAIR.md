# Economy and progression repair

Baseline: audit of `claude/quarry-machinery-overhaul` @ `797d68a`. Branch: `claude/economy-repair`.

## Prices (old -> new)
| Item | Old | New |
|---|---|---|
| Stone / Coal / Iron / Gravel(crushed) / Copper / Gold | 5 / 12 / 28 / 11 / 60 / 140 (x0.10-0.40 until Stage 7) | 3 / 7 / 16 / 7 / 34 / 80 (constant) |
| Topsoil / Pit gravel | 1 / 2 | 1 / 2 |
| Worn Pickaxe / Reinforced / Drill / Jackhammer | 90 / 350 / 4,500 / 14,000 | 150 / 600 / 6,000 / 16,000 |
| Pointed / Flat chisel / Repaired pick | 35 / 110 / 180 | 40 / 180 / 300 |
| Sledgehammer / Steel / Hardened / Splitter | 450 / 700 / 1,200 / 1,600 | 700 / 1,100 / 1,800 / 2,300 |
| Powered hammer / Compressor / Pneumatic | 2,500 / 3,500 / 6,500 | 3,500 / 4,500 / 7,500 |
| Hand cart / Wheelbarrow / Reinforced | 120 / 280 / 750 | 160 / 400 / 1,000 |
| Backpack / Technique / Storage / Crusher tuning / Harness | 55 / 90 / 120 / 150 / 700 | 90 / 250 / 240 / 300 / 900 |
| Crusher | 2,200 | 3,000 |

## Rewards (old -> new)
Cleanup letter 600 -> 150. Contracts 300 / 800 / 1,600 / 6,000 / 15,000 / 40,000 -> 120 / 300 / 700 / 2,500 / 7,000 / 18,000.
Milestones 500 / 1,200 / 2,500 / 3,500 / 6,000 / 9,000 / 14,000 / 5,000 -> 250 / 600 / 1,200 / 1,750 / 3,000 / 4,500 / 7,000 / 2,500. Lockbox 400 -> 150.

## Stage earnings (sales only)
150 / 600 / 1,800 / 4,000 / 9,000 / 20,000 / 45,000 / 100,000 / 250,000 / 600,000 / 1,500,000 (stages 2-12) ->
500 / 1,700 / 4,800 / 12,000 / 28,000 / 45,000 / 85,000 / 150,000 / 230,000 / 330,000 / 450,000.

## Other changes
- Upgrade gates: backpack from the start, mining technique and expanded storage at the Workshop, crusher tuning (owns a crusher) and the harness (owns a hand cart) at Breaking Ground.
- Vehicles: the "mechanized"/"automated" milestones no longer gate purchases; the stage still does.
- Storage bin: 40 + 40 at Moving Mountains + 60 at Deeper Ground (+60 with Expanded Storage, was +40).
- Soil: not storable (no script error); spoil heap counts toward Area 1, pays nothing. Topsoil and gravel from the formations stay sellable.
- Area 2 holds 60 pockets (40 iron); the gold bench has two rig pads; permit hidden in the new quarry; objective and title text fixed.

## Simulation (tests/test_progression_sim.gd, real rules, modelled work; not a played run)
Run with `SIMLOG=manual godot --headless -s tests/test_progression_sim.gd`: Stage 2 at ~14 min, Stage 3 ~23, Stage 4 ~39, Stage 5 ~76, Stage 6 ~108 minutes of continuous work.
