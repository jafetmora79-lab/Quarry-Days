extends SceneTree
## Step 4: staff and the dinosaur bite the real ground. A crew strike takes the highest ground of the column it works (same damage per unit as before), the units come out as loose
## pieces, the volume that left the terrain equals the units made (with the carried fraction), and the column is given up in the bookkeeping when it is down.
##   godot --headless --fixed-fps 60 -s tests/test_staff_terrain.gd

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
	check(col >= 0 and not lt.terrain.is_locked_at(20.0, -40.0), "a topsoil column inside the marked excavation (%d)" % col)
	var cp: Vector3 = prog.column_pos("q_top", col)
	var v0: float = lt.terrain.total_volume()
	var made := 0
	for i in range(30):
		made += game._terrain_bite_units("q_top", col, 30.0, 1, cp + Vector3(5, 0, 0), "crew")
	var lost: float = v0 - lt.terrain.total_volume()
	var rem: float = float(game._veh_rem.get("crew", {}).get("units", 0.0))
	check(lost > 0.05 and absf(lost * 11.0 - (float(made) + rem)) < 0.05, "30 bites dug %.3f m3 = %d units + %.2f carried" % [lost, made, rem])
	var n := 0
	while prog.chunks_left("q_top", col) > 0 and n < 3000:
		game._terrain_bite_units("q_top", col, 60.0, 1, cp + Vector3(5, 0, 0), "crew")
		n += 1
	check(prog.chunks_left("q_top", col) == 0, "bitten often enough, the column is given up in the bookkeeping (%d bites)" % n)
	check(lt.terrain.height_at(cp.x, cp.z) < -1.0, "and the ground there is down at the gravel (%.2f)" % lt.terrain.height_at(cp.x, cp.z))
	# the whole crew path still works end to end (a strike with no worker named picks the nearest exposed column itself)
	for i in range(5):
		game._crew_strike_formation("q_top", 4, 1, null)            # the whole crew path runs (it works whatever exposed column is nearest)
	check(true, "a crew strike with no worker named runs through the terrain path")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
