extends SceneTree
## Step 3a: the excavator's bucket bites the live terrain: it takes the highest ground of the column it works, the volume becomes cargo units with a carried remainder (nothing
## created or lost), a bucket never takes more than it has room for, rock beyond its hardness stops it with a chink, and the column is given up in the bookkeeping when it is down.
##   godot --headless --fixed-fps 60 -s tests/test_excavator_terrain.gd

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
	prog.excavator_state().merge({"battery": true, "hose": true, "fuel": true, "started": true}, true)
	game._ensure_opening()
	var rec: Dictionary = game.fleet.give("compact_excavator", Vector3(0, 0.2, 20), 0.0)
	game._sync_vehicles(true)
	await frames(4)
	var ex: QuarryVehicle = game.vehicle_nodes.get(int(rec["id"]))
	check(ex != null and ex.vkind == "excavator", "an excavator exists")
	var lt: LiveTerrain = game.live_terrain
	var col: int = prog.cell_index_at("q_top", Vector3(30.0, 0.0, -50.0))
	var cp: Vector3 = prog.column_pos("q_top", col)
	var t := {"kind": "q_top", "col": col, "res": "topsoil", "node": game.formation_nodes["q_top"]}
	var vol0: float = lt.terrain.total_volume()
	var hp := lt.highest_point("q_top", col, cp + Vector3(4, 0, 0))
	check(absf(hp.y) < 0.01 and absf(hp.x - cp.x) <= 1.8 and absf(hp.z - cp.z) <= 1.8, "it aims at the highest ground inside the column (%s)" % str(hp))
	var cargo0: int = game.fleet.cargo_total(rec)
	for i in range(40):
		game._excavator_dig_terrain(ex, t, 0.25)
	var cargo: int = game.fleet.cargo_total(rec)
	var lost: float = vol0 - lt.terrain.total_volume()
	var rem := 0.0
	for r in game._veh_rem.get(ex.vehicle_id, {}):
		rem += float(game._veh_rem[ex.vehicle_id][r])
	check(cargo > cargo0 and lost > 0.1 and absf(lost * 11.0 - (float(cargo - cargo0) + rem)) < 0.05, "40 ticks of digging moved %.3f m3 from the ground into %d units in the bucket (+%.2f carried)" % [lost, cargo - cargo0, rem])
	check(cargo <= game.fleet.capacity(rec), "the bucket never holds more than its capacity (%d / %d)" % [cargo, game.fleet.capacity(rec)])
	# keep going: the column is taken down evenly and then given up
	var n := 0
	while prog.chunks_left("q_top", col) > 0 and n < 6000:
		game.fleet.vehicle(ex.vehicle_id)["cargo"] = {}                       # (a truck takes the bucket away)
		game._excavator_dig_terrain(ex, t, 0.5)
		n += 1
	check(prog.chunks_left("q_top", col) == 0, "dug down tick by tick, the column is given up in the bookkeeping (%d ticks)" % n)
	var worst := 0.0
	var best := -1e9
	for dx in [-1.5, 0.0, 1.5]:
		for dz in [-1.5, 0.0, 1.5]:
			var h: float = lt.terrain.height_at(cp.x + dx, cp.z + dz)
			worst = minf(worst, h)
			best = maxf(best, h)
	check(best - worst < 1.6, "and the floor of the cut is level, not a well (spread %.2f m)" % (best - worst))
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
