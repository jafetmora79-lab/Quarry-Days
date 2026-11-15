extends SceneTree
## The Blender dump truck inside the real game: it loads, drives (wheels roll, front wheels + steering wheel steer, body leans), the
## engine runs, the bed tips on its hinge with the ram pinned and the tailgate swinging, the load is counted exactly once, and the
## fallback path survives.
##   godot --headless --fixed-fps 60 -s tests/test_truck_rig.gd

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

func ram_error(rig: TruckRig) -> float:
	var m := rig.model
	var e := (m.find_child("BedCyl_Barrel", true, false) as Node3D).global_position.distance_to((m.find_child("Pin_RamBase", true, false) as Node3D).global_position)
	return maxf(e, (m.find_child("BedCyl_Rod", true, false) as Node3D).global_position.distance_to((m.find_child("Pin_RamRod", true, false) as Node3D).global_position))

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
	var truck: QuarryVehicle
	for v in game.vehicle_nodes.values():
		if v.vtype == "starter_truck":
			truck = v
	check(truck != null and truck.vkind == "truck", "the starter truck exists")
	check(truck.trig != null and truck.trig.model != null, "it is the Blender truck, not the fallback")
	check(truck.bed == truck.trig.bed and truck.bed_load != null and truck.bed_load.get_parent() == truck.trig.bed, "the game's bed node is the rig's hinged bed and the load rides in it")
	var rec: Dictionary = game.fleet.vehicle(truck.vehicle_id)
	var spoil_pos: Vector3 = game.spoil_node.global_position
	# ---- driving
	truck.global_position = spoil_pos + Vector3(8, 0.3, 14)
	truck.rotation.y = 0.0
	await frames(30)
	game.enter_vehicle(truck)
	game.scripted_input = true
	await frames(10)
	check(truck.trig.engine_state == &"starting" or truck.trig.engine_state == &"idle", "entering the cab starts the engine (%s)" % truck.trig.engine_state)
	var wheel := truck.trig._wheels[0] as Node3D
	var p0 := truck.global_position
	truck.input = {"throttle": 1.0, "steer": 0.8, "brake": false}
	await frames(100)
	check(truck.global_position.distance_to(p0) > 0.5 and truck.speed > 0.2, "driving moves the truck (%.2f m)" % truck.global_position.distance_to(p0))
	check(wheel.transform.basis != Basis.IDENTITY and (truck.trig._wheels[2] as Node3D).transform.basis != Basis.IDENTITY, "the wheels roll")
	var front := truck.trig._steer[0] as Node3D
	check(absf(front.rotation.y) > 0.1, "the front wheels steer (%.2f rad)" % front.rotation.y)
	check(absf(truck.trig._steering_wheel.rotation.y) > 0.3, "the steering wheel turns with them")
	check(absf(truck._susp_roll) > 0.0005 or absf(truck._susp_pitch) > 0.0005, "the body leans on its suspension")
	truck.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
	await frames(120)
	check(absf(truck.speed) < 0.3, "the brakes stop it")
	game.scripted_input = false
	game.exit_vehicle()
	await frames(10)
	check(truck.trig.engine_state == &"stopping" or truck.trig.engine_state == &"off", "leaving the cab stops the engine (%s)" % truck.trig.engine_state)
	# ---- tipping at the spoil heap with 3 units of soil
	rec["cargo"]["soil"] = 3
	var all_soil: int = game.soil.total() + game.state.soil_dumped + 3
	truck.global_position = spoil_pos + Vector3(0, 0.2, -2.5)
	truck.rotation.y = 0.0
	truck.speed = 0.0
	await frames(30)
	var dumped_before: int = game.state.soil_dumped
	game.vehicle_dump(truck)
	var peak := 0.0
	var gate_open := 0.0
	var worst := 0.0
	var load_seen := false
	for i in 200:
		await physics_frame
		peak = maxf(peak, truck.trig.bed_angle)
		gate_open = minf(gate_open, truck.trig.tailgate.rotation.x)
		worst = maxf(worst, ram_error(truck.trig))
		load_seen = load_seen or truck.bed_load.visible
	check(peak > TruckKin.BED_MAX * 0.9, "the bed tips on its hinge (%.2f of %.2f rad)" % [peak, TruckKin.BED_MAX])
	check(gate_open < TruckKin.GATE_OPEN * 0.9, "the tailgate swings open (%.2f rad)" % gate_open)
	check(worst < 0.004, "the ram stays pinned at both ends through the tip (%.4f m)" % worst)
	check(load_seen, "the load is visible in the bed")
	check(game.state.soil_dumped == dumped_before + 3 and int(rec["cargo"].get("soil", 0)) == 0 and game.soil.total() + game.state.soil_dumped == all_soil, "the soil is counted exactly once (%d dumped)" % game.state.soil_dumped)
	check(truck.trig.bed_angle < 0.05 and absf(truck.trig.tailgate.rotation.x) < 0.05, "the bed lowers and the tailgate latches again")
	# ---- the fallback path
	var fb := QuarryVehicle.new()
	check(fb.trig == null, "a vehicle without the rig keeps the fallback path")
	fb.free()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
