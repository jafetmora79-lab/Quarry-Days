extends SceneTree
## The Blender bulldozer inside the real game (it is a proposed machine: not in the shop, handed over with fleet.give for the test):
## it loads, the engine runs, the blade goes down and its three cylinders stay pinned, driving with the blade down pushes real soil into
## the blade pile, nothing is created or destroyed (ground + spoil heap + pile stay constant), right click spreads or tips it, tracks
## differ when steering, and the machine is not for sale.
##   godot --headless --fixed-fps 60 -s tests/test_dozer_rig.gd

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

func hyd_error(rig: DozerRig) -> float:
	var m := rig.model
	var e := 0.0
	for tag in ["L", "R"]:
		e = maxf(e, (m.find_child("LiftCyl_%s_Barrel" % tag, true, false) as Node3D).global_position.distance_to((m.find_child("Pin_LiftBase_" + tag, true, false) as Node3D).global_position))
		e = maxf(e, (m.find_child("LiftCyl_%s_Rod" % tag, true, false) as Node3D).global_position.distance_to((m.find_child("Pin_LiftRod_" + tag, true, false) as Node3D).global_position))
	e = maxf(e, (m.find_child("TiltCyl_Barrel", true, false) as Node3D).global_position.distance_to((m.find_child("Pin_TiltBase", true, false) as Node3D).global_position))
	e = maxf(e, (m.find_child("TiltCyl_Rod", true, false) as Node3D).global_position.distance_to((m.find_child("Pin_TiltRod", true, false) as Node3D).global_position))
	return e

func total(game, rec: Dictionary) -> int:
	var n: int = game.soil.total() + game.state.soil_dumped
	for r in game.fleet.vehicles:
		n += int(r["cargo"].get("soil", 0))
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
	var soil: QuarrySoil = game.soil
	check(not game.fleet.types().has("bulldozer") and game.fleet.buy_block_reason("bulldozer") == "Not available yet", "the bulldozer is proposed only: not in the shop, cannot be bought")
	# find soil to push
	var target_cell := -1
	for i in range(soil.units.size()):
		if int(soil.active[i]) == 1 and soil.cell_center(i).z < -14.0 and soil.cell_center(i).x > -14.0 and soil.cell_center(i).x < 4.0:
			target_cell = i
			break
	var cc: Vector3 = soil.cell_center(target_cell)
	var rec_new: Dictionary = game.fleet.give("bulldozer", Vector3(cc.x, 0.2, cc.z + 7.0), 0.0)
	check(not rec_new.is_empty(), "the test hands over a bulldozer")
	game._sync_vehicles()
	var dz: QuarryVehicle = game.vehicle_nodes[int(rec_new["id"])]
	check(dz.vkind == "bulldozer" and dz.drig != null and dz.drig.model != null, "it is the Blender bulldozer")
	var rec: Dictionary = game.fleet.vehicle(dz.vehicle_id)
	dz.global_position = Vector3(cc.x, 0.2, cc.z + 7.0)
	dz.rotation.y = 0.0
	dz.speed = 0.0
	await frames(30)
	game.enter_vehicle(dz)
	game.scripted_input = true
	await frames(10)
	check(dz.drig.engine_state == &"starting" or dz.drig.engine_state == &"idle", "entering the cab starts the engine (%s)" % dz.drig.engine_state)
	var all0: int = total(game, rec)
	# blade down: the cutting edge reaches the ground and the cylinders follow
	game.dozer_toggle_blade(dz)
	var worst := 0.0
	for i in 120:
		await physics_frame
		worst = maxf(worst, hyd_error(dz.drig))
	check(game.dozer_blade_low(dz), "the blade is down (edge %.2f m above the ground)" % DozerRig.edge_height(dz._dozer_alpha))
	check(worst < 0.004, "all three cylinders stayed pinned while the blade lowered (%.4f m)" % worst)
	# push: drive forward over the soil
	dz.input = {"throttle": 1.0, "steer": 0.0, "brake": false}
	var pushed := 0
	for i in 420:
		pushed += game._dozer_push(dz, 1.0 / 60.0)
		await physics_frame
		worst = maxf(worst, hyd_error(dz.drig))
	var carried := int(rec["cargo"].get("soil", 0))
	check(carried > 0 and pushed == carried, "driving with the blade down pushed soil into the blade pile (%d units)" % carried)
	check(total(game, rec) == all0, "nothing created or destroyed: ground + spoil + pile unchanged (%d)" % all0)
	check(carried <= game.fleet.capacity(rec), "the pile never exceeds the blade capacity (%d)" % game.fleet.capacity(rec))
	check(dz.drig._pile.visible, "the pushed pile shows in front of the blade")
	# steering: the outer track runs faster
	dz.input = {"throttle": 1.0, "steer": 1.0, "brake": false}
	await frames(60)
	var bl: float = dz.drig._belts["L"].uv1_offset.x
	var br: float = dz.drig._belts["R"].uv1_offset.x
	await frames(30)
	var dl: float = absf(float(dz.drig._belts["L"].uv1_offset.x) - bl)
	var dr: float = absf(float(dz.drig._belts["R"].uv1_offset.x) - br)
	check(dl > dr * 1.05, "turning right drives the left track faster (%.2f vs %.2f)" % [dl, dr])
	dz.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
	await frames(90)
	# spread what is carried (no storage or spoil in reach here)
	# the machine has driven on (the soil is climbable now): back it up to where the ground was cut, so there is room to spread into
	dz.global_position = Vector3(cc.x, 0.2, cc.z + 7.0)
	dz.rotation.y = 0.0
	dz.speed = 0.0
	await frames(20)
	var before_ground: int = soil.total()
	var spread: int = game.vehicle_dump(dz)
	check(spread > 0 and int(rec["cargo"].get("soil", 0)) == carried - spread and soil.total() == before_ground + spread, "right click spreads the soil back onto the ground (%d)" % spread)
	check(total(game, rec) == all0, "still conserved after spreading")
	# tip the rest onto the spoil heap
	var left: int = int(rec["cargo"].get("soil", 0))
	if left == 0:
		rec["cargo"]["soil"] = 2
		all0 += 2
		left = 2
	dz.global_position = game.spoil_node.global_position + Vector3(0, 0.2, 3.0)
	dz.rotation.y = 0.0
	dz.speed = 0.0
	await frames(20)
	var dumped_before: int = game.state.soil_dumped
	var t: Dictionary = game.dump_target(dz.work_point(), 3.0, dz)
	check(t.has("spoil"), "the blade pile can be emptied at the spoil heap")
	game.vehicle_dump(dz)
	check(game.state.soil_dumped == dumped_before + left and int(rec["cargo"].get("soil", 0)) == 0 and total(game, rec) == all0, "the soil is counted on the heap exactly once")
	# raise the blade, leave, save record round trip
	game.dozer_toggle_blade(dz)
	await frames(120)
	check(not game.dozer_blade_low(dz), "the blade is raised again")
	game.scripted_input = false
	game.exit_vehicle()
	await frames(10)
	check(dz.drig.engine_state == &"stopping" or dz.drig.engine_state == &"off", "leaving the cab stops the engine (%s)" % dz.drig.engine_state)
	check(game.fleet.vehicle(dz.vehicle_id).has("cargo") and str(game.fleet.vehicle(dz.vehicle_id)["type"]) == "bulldozer", "the machine's record (type, cargo) is the normal fleet record, so saves keep working")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
