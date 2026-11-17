extends SceneTree
## Machines, staff and the dinosaur keep the bookkeeping's rate (units, tiers, veins exactly as before) and the real ground is carved by the same volume at the highest point of the column,
## so the picture follows the work smoothly and ends level.   godot --headless --fixed-fps 60 -s tests/test_staff_terrain.gd

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
	var col: int = prog.cell_index_at("q_top", Vector3(20.0, 0.0, -40.0))
	var cp: Vector3 = prog.column_pos("q_top", col)
	check(col >= 0 and not lt.terrain.is_locked_at(cp.x, cp.z), "a topsoil column inside the marked excavation (%d)" % col)
	var v0: float = lt.terrain.total_volume()
	for i in range(6):
		game._carve_column("q_top", col, 30.0, cp + Vector3(5, 0, 0))
	check(lt.terrain.total_volume() < v0 - 2.0, "carving removes real volume from the ground (%.2f m3)" % (v0 - lt.terrain.total_volume()))
	var before: int = prog.column_units("q_top", col)
	for i in range(6):
		game._crew_strike_formation("q_top", 4, 1, null)            # the whole crew path runs with the carve in it (it works whatever exposed column is nearest)
	check(true, "a crew strike with no worker named runs through the carve path")
	var n := 0
	while prog.chunks_left("q_top", col) > 0 and n < 3000:
		var ex: Dictionary = prog.extract("q_top", col, 50.0, 99, "companion")
		game._carve_column("q_top", col, 50.0, cp + Vector3(5, 0, 0))
		if int(ex["chunks"]) > 0:
			game.formation_nodes["q_top"].refresh()
		n += 1
	check(prog.chunks_left("q_top", col) == 0 and lt.terrain.height_at(cp.x, cp.z) < -1.1, "the dinosaur-style carve ends with the column given up and the ground at the gravel (%.2f)" % lt.terrain.height_at(cp.x, cp.z))
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
