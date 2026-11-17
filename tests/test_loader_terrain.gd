extends SceneTree
## Step 3b: the loader scoops heaps and soft ground off the live terrain into its bucket, the bulldozer pushes loose material into its blade, and a load can be tipped on the ground
## as a heap. Every cubic metre is accounted (terrain + cargo/rate + carried remainders).   godot --headless --fixed-fps 60 -s tests/test_loader_terrain.gd

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

func cargo_volume(game, rec: Dictionary, vid: int) -> float:
	var v := 0.0
	for r in rec["cargo"]:
		var res := "topsoil" if str(r) == "soil" else str(r)
		var mid: String = game.live_terrain.geo.material_of_resource(res)
		v += float(rec["cargo"][r]) / float(game.live_terrain.geo.props(mid)["units_per_m3"])
	for r in game._veh_rem.get(vid, {}):
		var mid2: String = game.live_terrain.geo.material_of_resource("topsoil" if str(r) == "soil" else str(r))
		v += float(game._veh_rem[vid][r]) / float(game.live_terrain.geo.props(mid2)["units_per_m3"])
	return v

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(10)
	game.prog.cleanup["done"] = true
	game.safety.enabled = false
	var lt: LiveTerrain = game.live_terrain
	var t: QuarryTerrain = lt.terrain
	var rl: Dictionary = game.fleet.give("loader", Vector3(40.0, 0.3, -30.0), 0.0)
	var rd: Dictionary = game.fleet.give("bulldozer", Vector3(60.0, 0.3, -30.0), 0.0)
	game._sync_vehicles(true)
	await frames(6)
	var ld: QuarryVehicle = game.vehicle_nodes.get(int(rl["id"]))
	var dz: QuarryVehicle = game.vehicle_nodes.get(int(rd["id"]))
	check(ld != null and ld.vkind == "loader" and dz != null and dz.vkind == "bulldozer", "a loader and a bulldozer exist")
	if ld == null or dz == null:
		quit(1)
		return
	# a heap of loose topsoil in front of the loader
	ld.global_position = Vector3(40.0, 0.3, -30.0)
	ld.rotation.y = 0.0
	ld.velocity = Vector3.ZERO
	var wp: Vector3 = ld.work_point()
	t.add_pile(wp.x, wp.z, 2.2, 1.0, "topsoil", 0.0)
	t.flush(true)
	await frames(10)
	var total0: float = t.total_volume() + cargo_volume(game, rl, ld.vehicle_id)
	ld.bucket_target = 0.0
	await frames(2)
	var got: int = game.loader_primary(ld)
	check(got > 0 and game.fleet.cargo_total(rl) == got, "the loader scoops %d units off the heap into its bucket" % got)
	var total1: float = t.total_volume() + cargo_volume(game, rl, ld.vehicle_id)
	check(absf(total1 - total0) < 0.02, "terrain + bucket is unchanged by the scoop (%.5f m3 apart)" % absf(total1 - total0))
	# tip it on the ground somewhere else
	ld.global_position = Vector3(48.0, 0.3, -36.0)
	await frames(8)
	var cargo_before: int = game.fleet.cargo_total(rl)
	var moved: int = game.vehicle_dump(ld, true)
	check(moved == cargo_before and game.fleet.cargo_total(rl) == 0, "tipped on the ground: the whole load (%d units) leaves the bucket" % moved)
	t.flush(true)
	var total2: float = t.total_volume() + cargo_volume(game, rl, ld.vehicle_id)
	check(absf(total2 - total0) < 0.02, "and arrives as a heap: nothing created or lost (%.5f m3 apart)" % absf(total2 - total0))
	# the bulldozer pushes loose material into its blade
	dz.global_position = Vector3(60.0, 0.3, -30.0)
	dz.rotation.y = 0.0
	dz.velocity = Vector3.ZERO
	var wpd: Vector3 = dz.work_point()
	t.add_pile(wpd.x, wpd.z, 2.0, 0.8, "gravel", 0.0)
	t.flush(true)
	await frames(10)
	var tot_d0: float = t.total_volume() + cargo_volume(game, rd, dz.vehicle_id)
	dz.blade_goal = -0.08
	dz._dozer_alpha = -0.08
	dz.speed = 2.0
	dz.input = {"throttle": 1.0, "steer": 0.0, "brake": false}
	var pushed := 0
	for i in range(30):
		pushed += game._dozer_push(dz, 0.1)
	var tot_d1: float = t.total_volume() + cargo_volume(game, rd, dz.vehicle_id)
	check(pushed > 0 and int(rd["cargo"].get("soil", 0)) > 0, "driving with the blade down pushes %d units of loose gravel into the blade as soil" % pushed)
	check(absf(tot_d1 - tot_d0) < 0.02, "and the blade holds exactly what left the ground (%.5f m3 apart)" % absf(tot_d1 - tot_d0))
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
