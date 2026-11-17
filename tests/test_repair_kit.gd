extends SceneTree
## Focused checks of the excavator's marker-driven repairs and the seat: the fuel cap opens/closes and the can pours only when aligned, the hose stays connected when the boom moves,
## the battery goes into its tray, the repairs persist through save/load, entering/leaving a machine is a camera move with a visible seated driver, and the machine drives after repairs.
##   Run through tools/run_tests.sh (each job gets its own save folder).
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

func frames(n: int, until: Callable = Callable()) -> int:
	for i in range(n):
		await physics_frame
		if until.is_valid() and until.call():
			return i
	return n

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	game.intro_shots_enabled = false
	root.add_child(game)
	await process_frame
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	game.safety.enabled = false
	await frames(30)
	var prog: QuarryProgression = game.prog
	var v: QuarryVehicle = game._starter_vehicle()
	var kit: RepairKit = v.repair_kit
	check(kit != null, "the starter excavator carries the repair kit")
	for mk in ["FuelFiller", "FuelCapRest", "FuelPourTarget", "BatteryTray", "BatteryPositive", "BatteryNegative", "HydraulicHoseStart", "HydraulicHoseEnd"]:
		check(kit.m(mk) != null, "marker %s exists on the model" % mk)
	# ---- the broken machine
	var seat_xf := kit.cap_seated_xf()
	check(kit.cap.global_position.distance_to(seat_xf.origin) < 0.005, "broken: the cap is screwed on the filler neck")
	check(absf(kit.cover.rotation.x) > 1.0, "broken: the battery tray is open and empty")
	check(not kit.hose_live, "broken: the hydraulic hose is not connected")
	# ---- fuel: the cap comes off, the can pours only when its spout is over the neck, the cap goes back on
	check(prog.pick_up_part("fuel"), "fuel can picked up")
	game._install_part(v)
	var st := {"open_seen": false, "pour_frames": 0, "pour_bad": 0, "max_lift": 0.0, "cap_on_during_pour": false}
	var f := await frames(60 * 12, func():
		var seq = game.repair_seq
		if seq == null:
			return true
		var lift: float = kit.cap.global_position.distance_to(seat_xf.origin)
		st["max_lift"] = maxf(float(st["max_lift"]), lift)
		if seq._stream != null and seq._stream.visible:
			st["pour_frames"] = int(st["pour_frames"]) + 1
			var tip: Vector3 = seq._can.to_global((seq._can.find_child("Marker_SpoutTip", true, false) as Node3D).position)
			var fil := kit.m("FuelFiller").global_position
			if Vector2(tip.x - fil.x, tip.z - fil.z).length() > 0.02 or tip.y < fil.y:
				st["pour_bad"] = int(st["pour_bad"]) + 1
			if lift < 0.05:
				st["cap_on_during_pour"] = true
		return false)
	check(float(st["max_lift"]) > 0.08, "the cap lifts off the neck and travels to its rest (%.2f m)" % float(st["max_lift"]))
	check(int(st["pour_frames"]) > 20 and int(st["pour_bad"]) == 0, "fuel flows only while the spout is aligned over the filler (%d frames, %d misaligned)" % [int(st["pour_frames"]), int(st["pour_bad"])])
	check(not bool(st["cap_on_during_pour"]), "the cap stays off for the whole pour")
	check(kit.cap.global_position.distance_to(seat_xf.origin) < 0.005 and prog.repair_done("fuel"), "the cap ends screwed back on and the fuel repair is recorded")
	check(float(f) / 60.0 < 8.5, "the fuel sequence is short (%.1f s)" % (float(f) / 60.0))
	# ---- hose: it connects between the ports and stays connected when the boom moves
	check(prog.pick_up_part("hose"), "hose picked up")
	game._install_part(v)
	await frames(60 * 10, func(): return game.repair_seq == null)
	check(prog.repair_done("hose") and kit.hose_live and kit.hose_mesh.visible, "the hose is fitted and live")
	var rig = v.rig
	for ang in [0.0, 0.35, -0.3]:
		rig.boom.rotation.x = ang
		rig.stick.rotation.x = -ang * 0.8
		await frames(3)
		var e: Vector3 = kit.m("HydraulicHoseEnd").global_position
		var d: float = kit.hose_b.global_position.distance_to(e)
		check(d < 0.2, "boom at %.2f: the hose end fitting still follows the boom's port (%.3f m from it)" % [ang, d])
		var mid: Vector3 = (kit.hose_a.global_position + kit.hose_b.global_position) * 0.5
		check(mid.is_finite() and kit.hose_a.global_position.distance_to(kit.hose_b.global_position) < 2.5, "boom at %.2f: the two ends stay a sane distance apart" % ang)
	rig.boom.rotation.x = 0.0
	rig.stick.rotation.x = 0.0
	# ---- battery
	check(prog.pick_up_part("battery"), "battery picked up")
	game._install_part(v)
	await frames(60 * 10, func(): return game.repair_seq == null)
	check(prog.repair_done("battery") and absf(kit.cover.rotation.x) < 0.05, "the battery is in its tray and the cover is shut")
	var bat: Node3D = kit.battery_node
	check(bat.visible and bat.global_position.distance_to(kit.m("BatteryTray").global_position) < 0.25, "the battery sits at the tray marker")
	check(prog.repairs_complete(), "all three repairs are done")
	# ---- persistence
	game._save(true)
	var vid := v.vehicle_id
	game._load(true)
	await frames(20)
	var v2: QuarryVehicle = game._starter_vehicle()
	var k2: RepairKit = v2.repair_kit
	check(k2 != null and k2.hose_live and absf(k2.cover.rotation.x) < 0.05 and k2.cap.global_position.distance_to(k2.cap_seated_xf().origin) < 0.005, "after save/load the repaired machine is still repaired (cap on, battery in, hose live)")
	check(game.prog.repairs_complete(), "the repair progress survives the save")
	# ---- entering and leaving: a camera move, a visible seated driver attached to the machine
	var locked0: bool = game.player.locked
	game.prog.excavator_state()["started"] = true
	game.enter_vehicle(v2)
	await frames(4)
	check(game.driving == v2, "E puts the player in the driver's seat")
	var drivers := v2.find_children("SeatedDriver", "Node3D", true, false)
	check(drivers.size() == 1, "exactly one seated driver model (%d)" % drivers.size())
	var d0: SeatedDriver = drivers[0]
	check(d0.visible and d0.rig != null and d0.rig.seated, "the driver is visible and sitting")
	var cab: Dictionary = QuarryBoarding.cab(v2)
	check(d0.get_parent() == cab["ref"], "it is attached to the cab, so it moves with the machine")
	var seat := SeatedDriver.marker(v2, "DriverSeat")
	check(seat != null and SeatedDriver.marker(v2, "DriverCamera") != null and SeatedDriver.marker(v2, "VehicleExitPoint") != null, "DriverSeat / DriverCamera / VehicleExitPoint markers exist")
	var hips: Vector3 = d0.skel.global_transform * d0.skel.get_bone_global_pose(d0.skel.find_bone("Hips")).origin
	check(hips.distance_to(seat.global_position) < 0.25, "the pelvis sits on the seat marker (%.2f m away)" % hips.distance_to(seat.global_position))
	var thigh := d0.skel.get_bone_global_pose(d0.skel.find_bone("LeftLowerLeg")).origin - d0.skel.get_bone_global_pose(d0.skel.find_bone("LeftUpperLeg")).origin
	check(absf(thigh.y) < 0.25 * thigh.length() + 0.05 and thigh.length() > 0.2, "the thighs are level: the legs are bent in a seated pose")
	d0.first_person = true
	check(d0.skel.get_bone_pose_scale(d0.skel.find_bone("Head")).x < 0.01, "in the first-person cab view only the head is hidden")
	d0.first_person = false
	check(d0.skel.get_bone_pose_scale(d0.skel.find_bone("Head")).x > 0.9, "and it is back in the chase view")
	# the machine works after the repairs
	game.scripted_input = true
	var p0 := v2.global_position
	var rel0 := d0.global_position - v2.global_position
	v2.input = {"throttle": -1.0, "steer": 0.0, "brake": false}
	await frames(90)
	check(v2.global_position.distance_to(p0) > 0.3, "the repaired excavator drives (%.1f m)" % v2.global_position.distance_to(p0))
	var rel1 := d0.global_position - v2.global_position
	check(rel1.distance_to(rel0) < 0.15, "the driver travels with the machine (offset changed %.3f m)" % rel1.distance_to(rel0))
	v2.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
	await frames(120)
	check(d0.global_position.distance_to((cab["ref"] as Node3D).global_position) < 3.0, "and stays in the cab")
	var out: bool = game.exit_vehicle()
	await frames(4)
	check(out and game.driving == null, "E again gets out beside the machine")
	check(not d0.visible and game.player.visible, "the seated driver is gone and the person stands on the ground")
	check(not game.repair_busy and game.player.locked == locked0, "controls are back as they were before getting in (busy %s, locked %s)" % [str(game.repair_busy), str(game.player.locked)])
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
