extends SceneTree
## Machines, staff and the dinosaur keep the bookkeeping's rate (units, tiers, veins exactly as before) and the real ground is carved by the same volume at the highest point of the column,
## so the picture follows the work smoothly and ends level.   godot --headless --fixed-fps 60 -s tests/test_excavator_terrain.gd

var checks := 0
var failures := []

func check(c: bool, label: String) -> void:
	checks += 1
	if not c:
		failures.append(label)
		printerr("FAIL: " + label)
	else:
		print("PASS: " + label)

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in range(n):
		await physics_frame

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(10)
	var prog: QuarryProgression = game.prog
	prog.cleanup["done"] = true
	var lt: LiveTerrain = game.live_terrain
	var col: int = prog.cell_index_at("q_top", Vector3(30.0, 0.0, -50.0))
	var cp: Vector3 = prog.column_pos("q_top", col)
	check(col >= 0 and not lt.terrain.is_locked_at(cp.x, cp.z), "a topsoil column inside the marked excavation (%d)" % col)
	var s: Dictionary = game.fleet.spec("compact_excavator")
	var dps := float(s.get("dig_dps", 10.0))
	var mid_h := 0.0
	var n := 0
	var units := 0
	while prog.chunks_left("q_top", col) > 0 and n < 4000:
		var ex: Dictionary = prog.extract("q_top", col, dps * 0.1, 99, "excavator")
		units += int(ex["units"])
		game._carve_column("q_top", col, dps * 0.1, cp + Vector3(5, 0, 0))
		if prog.column_units("q_top", col) <= 3 and mid_h == 0.0:
			mid_h = 0.0
			for dx2 in [-1.5, 0.0, 1.5]:
				for dz2 in [-1.5, 0.0, 1.5]:
					mid_h = minf(mid_h, lt.terrain.height_at(cp.x + dx2, cp.z + dz2))
		n += 1
		if int(ex["chunks"]) > 0:
			game.formation_nodes["q_top"].refresh()
	check(units == 5 and prog.chunks_left("q_top", col) == 0, "the bookkeeping is untouched: the column gives its 5 units in %d ticks" % n)
	var worst := 0.0
	var best := -1e9
	for dx in [-1.5, 0.0, 1.5]:
		for dz in [-1.5, 0.0, 1.5]:
			var h: float = lt.terrain.height_at(cp.x + dx, cp.z + dz)
			worst = minf(worst, h)
			best = maxf(best, h)
	check(worst < -1.1 and best - worst < 1.5, "and the carved ground ends level at the floor of the cut (%.2f to %.2f)" % [worst, best])
	check(mid_h < 0.0 and mid_h > -1.19, "partway through, the ground was already part-way down (lowest point %.2f m)" % mid_h)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
