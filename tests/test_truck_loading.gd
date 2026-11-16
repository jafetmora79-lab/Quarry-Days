extends SceneTree
## The Blender excavator and the truck bed: the excavator rests on the ground (tracks touching it, nothing buried), it tips into a truck only when
## its arm points at the REAL bed and can reach it (bed position, height and angle come from the truck model, not a fixed spot), the bucket really goes
## to a point above the bed before it tips, no material is created or lost (a full or nearly full bed keeps the rest in the bucket), and a truck out
## of reach or in the wrong direction takes nothing.
##   godot --headless --fixed-fps 60 -s tests/test_truck_loading.gd

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

func lowest(n: Node3D) -> float:
	var lo := 1e9
	for node in n.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or not str(mi.name).begins_with("Track_"):
			continue                                      # the tracks are what stands on the ground (the bucket may be digging below it)
		var b: AABB = mi.global_transform * mi.get_aabb()
		lo = minf(lo, b.position.y)
	return lo

func ground_y(at: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 6, 0), at + Vector3(0, -6, 0), 1)
	var h := root.get_world_3d().direct_space_state.intersect_ray(q)
	return float(h["position"].y) if not h.is_empty() else NAN

func total(game) -> int:
	var n := 0
	for v in game.fleet.vehicles:
		n += game.fleet.cargo_total(v)
	return n

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await process_frame
	game.safety.enabled = false
	game.prog.excavator_state().merge({"battery": true, "hose": true, "fuel": true, "started": true}, true)
	game._ensure_opening()
	var ex: QuarryVehicle = game._starter_vehicle()
	var truck: QuarryVehicle
	for v in game.vehicle_nodes.values():
		if v.vtype == "starter_truck":
			truck = v
	check(ex != null and truck != null, "an excavator and a truck to work with")
	check(ex.rig != null and truck.trig != null, "both are the Blender machines")
	var rec: Dictionary = game.fleet.vehicle(ex.vehicle_id)
	var trec: Dictionary = game.fleet.vehicle(truck.vehicle_id)
	# ---- the excavator rests on the ground
	var spot := Vector3(-6.0, 0.3, -16.0)
	# A parked machine now follows the ground under it (it used to hang where the test put it). The truck must therefore stand on the same level ground as the
	# excavator, so the loose soil around the work spot is cleared first (as a bulldozer would).
	if game.soil != null:
		for i in game.soil.units.size():
			if game.soil.cell_center(i).distance_to(spot) < 16.0:
				game.soil.remove(i, int(game.soil.units[i]))
		game.soil.refresh()
	ex.global_position = spot
	ex.rotation.y = 0.0
	ex.velocity = Vector3.ZERO
	ex.speed = 0.0
	await frames(40)
	var gy := ground_y(ex.global_position)
	var low := lowest(ex.rig.model)
	check(not is_nan(gy) and absf(low - gy) < 0.06, "the tracks touch the ground: lowest point of the model %.3f m vs the ground %.3f m" % [low, gy])
	check(low > gy - 0.03, "and nothing of the model is buried (%.3f m below)" % maxf(0.0, gy - low))
	# ---- the bed is measured from the model
	var bb := truck.bed_box()
	check(truck._bed_box.size != Vector3.ZERO, "the truck's bed box is measured from its model, not the rough fallback")
	check(bb.size.x > 1.2 and bb.size.z > 2.0 and bb.size.y > 0.4, "and it is a bed-sized box (%s)" % str(bb.size.snapped(Vector3(0.01, 0.01, 0.01))))
	# ---- loading with both on level ground: find where the truck must stand for the arm to reach the bed
	ex.swing = 0.0
	ex.turret_yaw = 0.0
	var reach_ok := false
	var good_dist := 0.0
	var cz := bb.get_center().z
	var d := 2.0
	while d < 9.0:
		truck.global_position = ex.global_position + Vector3(0, 0.0, -d - cz)
		truck.rotation.y = 0.0
		truck.velocity = Vector3.ZERO
		await frames(4)
		var r: Dictionary = ex.truck_dump_aim(truck)
		if r.has("aim"):
			reach_ok = true
			good_dist = d
			break
		d += 0.25
	check(reach_ok, "there is a truck position the excavator can load from (bed centre %.2f m ahead)" % good_dist)
	truck.global_position = ex.global_position + Vector3(0, 0.0, -good_dist - cz)
	await frames(6)
	var aim_level: Vector3 = ex.truck_dump_aim(truck)["aim"]
	var chk := truck.bed_check(aim_level, 0.0)
	check(bool(chk["over"]) and aim_level.y >= float(chk["rim"]) + 0.5, "the bucket aim is over the bed and above its rim (%.2f over a rim at %.2f)" % [aim_level.y, float(chk["rim"])])
	# conservation: 3 units in the bucket go into the truck, exactly once
	trec["cargo"] = {}
	rec["cargo"] = {"soil": 3}
	var all0 := total(game)
	var t: Dictionary = game.dump_target(ex.work_point(), 3.0, ex)
	check(t.has("truck") and t.has("aim"), "the dump target is the truck with its aim point")
	var moved: int = game.vehicle_dump(ex, true)
	check(moved == 3 and int(trec["cargo"].get("soil", 0)) == 3 and int(rec["cargo"].get("soil", 0)) == 0 and total(game) == all0, "3 units moved into the truck, none created or lost")
	# the bucket really goes over the bed and clears the rim before it ends
	var best := 1e9
	var best_h := -1e9
	for i in range(70):
		await physics_frame
		var tip := ex.rig.bucket_tip()
		var dd := Vector2(tip.x - aim_level.x, tip.z - aim_level.z).length()
		if dd < 0.9:
			best_h = maxf(best_h, tip.y)
		best = minf(best, dd)
	check(best < 0.9 and best_h > float(chk["rim"]) - 0.15, "during the tip the bucket lip comes within %.2f m of the aim, %.2f m above the rim line" % [best, best_h - float(chk["rim"])])
	# ---- the truck higher / lower / angled: the aim follows its real position
	var heights := {}
	for dy in [0.0, 0.3, 1.8, -0.5]:
		truck.global_position = ex.global_position + Vector3(0, 0.1 + dy, -good_dist - cz)
		truck.rotation.y = 0.0
		truck.velocity = Vector3.ZERO
		truck.set_physics_process(false)
		truck.global_position.y = ex.global_position.y + 0.1 + dy
		var r2: Dictionary = ex.truck_dump_aim(truck)
		var rim := float(truck.bed_check(truck.global_position)["rim"])
		heights[dy] = {"aim": r2.get("aim", Vector3.INF), "rim": rim}
		truck.set_physics_process(true)
	for dy in [0.0, 0.3, -0.5]:
		var hh: Dictionary = heights[dy]
		check(hh["aim"] != Vector3.INF and (hh["aim"] as Vector3).y >= float(hh["rim"]) + 0.19, "a truck %+.1f m from level: the aim follows its bed (%.2f m over a rim at %.2f)" % [dy, ((hh["aim"] as Vector3).y if hh["aim"] != Vector3.INF else NAN), float(hh["rim"])])
	check(absf((float(heights[0.3]["rim"]) - float(heights[0.0]["rim"])) - 0.3) < 0.05, "and the rim really is 0.3 m higher for the raised truck")
	check(heights[1.8]["aim"] == Vector3.INF, "a truck 1.8 m higher is beyond the arm's reach: no aim, nothing is loaded")
	truck.global_position = ex.global_position + Vector3(0, 0.0, -good_dist - cz)
	truck.rotation.y = deg_to_rad(14.0)
	await frames(6)
	var ang: Dictionary = ex.truck_dump_aim(truck)
	check(ang.has("aim") and bool(truck.bed_check(ang["aim"], 0.0)["over"]), "a truck parked at a slight angle still gets an aim over its bed")
	truck.rotation.y = 0.0
	await frames(4)
	# ---- bed nearly full / full: the rest stays in the bucket
	trec["cargo"] = {"soil": 8}
	rec["cargo"] = {"soil": 3}
	var all1 := total(game)
	var m1: int = game.vehicle_dump(ex, true)
	check(m1 == 2 and int(trec["cargo"]["soil"]) == 10 and int(rec["cargo"]["soil"]) == 1 and total(game) == all1, "a nearly full bed takes only what fits (2), 1 stays in the bucket")
	ex.dump_timer = 0.0
	var m2: int = game.vehicle_dump(ex, true)
	check(m2 == 0 and int(trec["cargo"]["soil"]) == 10 and int(rec["cargo"]["soil"]) == 1 and total(game) == all1, "a full bed takes nothing and nothing is lost")
	# ---- wrong direction / out of reach: nothing is transferred
	trec["cargo"] = {}
	rec["cargo"] = {"soil": 3}
	ex.dump_timer = 0.0
	ex.swing = PI
	var t2: Dictionary = game.dump_target(ex.work_point(), 3.0, ex)
	check(not t2.has("truck"), "with the cab pointing away from the truck it is not a target")
	check(game.vehicle_dump(ex, true) == 0 and int(trec["cargo"].get("soil", 0)) == 0 and int(rec["cargo"]["soil"]) == 3, "and nothing is transferred")
	check(str(ex.truck_dump_aim(truck).get("why", "")) == "swing", "the reason given is the swing")
	ex.swing = 0.0
	truck.global_position = ex.global_position + Vector3(0, 0.1, -14.0)
	await frames(6)
	check(str(ex.truck_dump_aim(truck).get("why", "")) in ["swing", "reach"] and not ex.truck_dump_aim(truck).has("aim"), "a truck far away is out of reach")
	var all2 := total(game)
	check(game.vehicle_dump(ex, true) == 0 and int(rec["cargo"]["soil"]) == 3 and total(game) == all2, "nothing is transferred to it either")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
