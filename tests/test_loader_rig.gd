extends SceneTree
## The Blender wheel loader inside the real game: loads, engine runs, scoops a real rubble pile into the bucket (conserved), the arms lift
## with the bucket level and all three cylinders stay pinned, the dump rolls the bucket forward, the frame articulates and the wheels roll.
##   godot --headless --fixed-fps 60 -s tests/test_loader_rig.gd

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

func hyd_error(rig: LoaderRig) -> float:
	var m := rig.model
	var e := 0.0
	for tag in ["L", "R"]:
		e = maxf(e, (m.find_child("LiftCyl_%s_Barrel" % tag, true, false) as Node3D).global_position.distance_to((m.find_child("Pin_LiftBase_" + tag, true, false) as Node3D).global_position))
		e = maxf(e, (m.find_child("LiftCyl_%s_Rod" % tag, true, false) as Node3D).global_position.distance_to((m.find_child("Pin_LiftRod_" + tag, true, false) as Node3D).global_position))
	e = maxf(e, (m.find_child("TiltCyl_Barrel", true, false) as Node3D).global_position.distance_to((m.find_child("Pin_TiltBase", true, false) as Node3D).global_position))
	e = maxf(e, (m.find_child("TiltCyl_Rod", true, false) as Node3D).global_position.distance_to((m.find_child("Pin_TiltRod", true, false) as Node3D).global_position))
	return e

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
	var pile_pos: Array = game.fleet.cfg["piles"]["limestone_rubble"]["pos"]
	var rec_new: Dictionary = game.fleet.give("loader", Vector3(pile_pos[0], 0.2, pile_pos[2] + 2.6), 0.0)
	check(not rec_new.is_empty(), "the test hands over a loader")
	game._sync_vehicles()
	var v: QuarryVehicle = game.vehicle_nodes[int(rec_new["id"])]
	check(v.vkind == "loader" and v.lrig != null and v.lrig.model != null, "it is the Blender wheel loader, not the fallback")
	check(v.bucket == v.lrig.bucket and v.bucket_load != null and v.bucket_load.get_parent() == v.lrig.bucket, "the bucket and its load ride on the rig")
	var rec: Dictionary = game.fleet.vehicle(v.vehicle_id)
	v.global_position = Vector3(pile_pos[0], 0.2, pile_pos[2] + 2.6)
	v.rotation.y = 0.0
	v.speed = 0.0
	await frames(30)
	game.enter_vehicle(v)
	game.scripted_input = true
	await frames(10)
	check(v.lrig.engine_state == &"starting" or v.lrig.engine_state == &"idle", "entering the cab starts the engine (%s)" % v.lrig.engine_state)
	var pile_before: int = int(game.fleet.piles["limestone_rubble"]["amount"])
	var got: int = game.loader_primary(v)
	check(got > 0 and game.fleet.cargo_total(rec) == got, "left click scoops the rubble pile into the bucket (%d)" % got)
	check(int(game.fleet.piles["limestone_rubble"]["amount"]) == pile_before - got, "nothing created or destroyed: the pile lost exactly what the bucket gained")
	var worst := 0.0
	var peak := 0.0
	for i in 150:
		await physics_frame
		worst = maxf(worst, hyd_error(v.lrig))
		peak = maxf(peak, v.lrig.arm_angle)
	check(peak > LoaderKin.LIFT_MAX * 0.8, "the arms lift the load (%.2f of %.2f rad)" % [peak, LoaderKin.LIFT_MAX])
	check(worst < 0.004, "all three cylinders stayed pinned through scoop and lift (%.4f m)" % worst)
	check(v.bucket_load.visible, "the load shows in the bucket")
	# dump: the bucket rolls forward
	v.dump_timer = 1.0
	var tip := -9.0
	for i in 70:
		await physics_frame
		tip = maxf(tip, v.lrig.bucket_angle)
		worst = maxf(worst, hyd_error(v.lrig))
	check(tip > 0.0, "the dump rolls the bucket forward (%.2f rad)" % tip)
	check(worst < 0.004, "pins stayed connected through the dump (%.4f m)" % worst)
	# drive and steer: wheels roll, the frame articulates
	var wheel := v.lrig._wheels[0] as Node3D
	v.input = {"throttle": 1.0, "steer": 1.0, "brake": false}
	var p0 := v.global_position
	await frames(100)
	check(v.global_position.distance_to(p0) > 0.15, "driving moves the loader (%.2f m)" % v.global_position.distance_to(p0))
	check(wheel.transform.basis != Basis.IDENTITY, "the wheels roll")
	check(absf(v.lrig.front.rotation.y) > 0.1, "the frame articulates into the turn (%.2f rad)" % v.lrig.front.rotation.y)
	v.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
	await frames(60)
	game.scripted_input = false
	game.exit_vehicle()
	await frames(10)
	check(v.lrig.engine_state == &"stopping" or v.lrig.engine_state == &"off", "leaving the cab stops the engine (%s)" % v.lrig.engine_state)
	var fb := QuarryVehicle.new()
	check(fb.lrig == null, "a vehicle without the rig keeps the fallback path")
	fb.free()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
