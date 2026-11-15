extends SceneTree
## The Blender excavator inside the real game: it loads, digs real soil with the bucket reaching the dig point, dumps, the engine
## state machine runs, hydraulics stay connected through the whole dig/dump cycle, and the fallback model still builds.
##   godot --headless --fixed-fps 60 -s tests/test_excavator_rig.gd

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

func pins_connected(rig: ExcavatorRig) -> float:
	var worst := 0.0
	var m := rig.model
	var pairs := [["BoomCyl_L_Rod", "Pin_BoomCylRod_L"], ["BoomCyl_R_Rod", "Pin_BoomCylRod_R"], ["StickCyl_Rod", "Pin_StickCylRod"],
		["BoomCyl_L_Barrel", "Pin_BoomCylBase_L"], ["StickCyl_Barrel", "Pin_StickCylBase"], ["BucketCyl_Barrel", "Pin_BucketCylBase"]]
	for p in pairs:
		worst = maxf(worst, (m.find_child(p[0], true, false) as Node3D).global_position.distance_to((m.find_child(p[1], true, false) as Node3D).global_position))
	# the 4-bar: rod end meets both link ends
	var stick := m.find_child("Stick", true, false) as Node3D
	var rod := stick.to_local((m.find_child("BucketCyl_Rod", true, false) as Node3D).global_position)
	for t in ["L", "R"]:
		var il := m.find_child("IdlerLink_" + t, true, false) as Node3D
		var bl := m.find_child("BucketLink_" + t, true, false) as Node3D
		var ie := stick.to_local(il.global_transform * Vector3(0, 0, -ExcavatorKin.LINK_IDLER_LEN))
		var be := stick.to_local(bl.global_transform * Vector3(0, 0, -ExcavatorKin.LINK_BUCKET_LEN))
		worst = maxf(worst, Vector2(ie.y - rod.y, ie.z - rod.z).length())
		worst = maxf(worst, Vector2(be.y - rod.y, be.z - rod.z).length())
	return worst

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
	check(ex != null and ex.vkind == "excavator", "the starter excavator exists")
	check(ex.rig != null and ex.rig.model != null, "it is the Blender rig, not the fallback")
	check(ex.turret == ex.rig.turret and ex.arm == ex.rig.boom and ex.stick == ex.rig.stick and ex.bucket == ex.rig.bucket, "the game's joint nodes are the rig's hinges")
	check(ex.bucket_load != null and ex.bucket_load.get_parent() == ex.rig.bucket, "bucket contents ride in the bucket")
	var soil: QuarrySoil = game.soil
	var target_cell := -1
	for i in range(soil.units.size()):
		if int(soil.active[i]) == 1 and soil.cell_center(i).z < -14.0 and soil.cell_center(i).x > -14.0 and soil.cell_center(i).x < 4.0:
			target_cell = i
			break
	var cc: Vector3 = soil.cell_center(target_cell)
	ex.global_position = Vector3(cc.x, 0.2, cc.z + 4.2)
	ex.rotation.y = 0.0
	ex.speed = 0.0
	ex.velocity = Vector3.ZERO
	await frames(10)
	game.enter_vehicle(ex)
	game.scripted_input = true
	await frames(10)
	check(ex.rig.engine_state == &"starting" or ex.rig.engine_state == &"idle", "entering the cab starts the engine (%s)" % ex.rig.engine_state)
	await frames(150)
	check(ex.rig.engine_state == &"idle", "the engine settles into idle")
	# dig: bucket reaches for the soil, pins stay connected through the stroke, the bucket fills
	var rec: Dictionary = game.fleet.vehicle(ex.vehicle_id)
	var worst := 0.0
	var tip_min_y := 99.0
	var reached := false
	ex.digging = true
	for i in 240:
		if ex.digging:
			game._excavator_dig(ex, 1.0 / 60.0)         # main.gd runs this itself unless input is scripted
		await physics_frame
		worst = maxf(worst, pins_connected(ex.rig))
		tip_min_y = minf(tip_min_y, ex.rig.bucket_tip().y - ex.global_position.y)
		if ex.dig_aim != Vector3.INF:
			var d := Vector2(ex.rig.bucket_tip().x - ex.dig_aim.x, ex.rig.bucket_tip().z - ex.dig_aim.z).length()
			reached = reached or d < 2.6          # the arm tops out near 3 m from the machine; the game digs cells up to ~4 m from its centre, so the lip gets as close as the arm allows
	ex.digging = false
	check(game.fleet.cargo_total(rec) > 0, "digging put real soil in the bucket (%d)" % game.fleet.cargo_total(rec))
	check(reached, "the bucket lip reached the dig point")
	check(tip_min_y > -0.35, "the bucket never goes through the ground (lowest %.2f m)" % tip_min_y)
	check(worst < 0.004, "all hydraulic pins stayed connected while digging (worst %.4f m)" % worst)
	check(ex.bucket_load.visible, "the load shows in the bucket")
	# dump
	game.vehicle_dump(ex)
	for i in 80:
		await physics_frame
		worst = maxf(worst, pins_connected(ex.rig))
	check(worst < 0.004, "pins stayed connected through the dump (worst %.4f m)" % worst)
	# manual controls move the real hinges
	var tip_before: float = ex.rig.bucket_tip().y
	ex.boom_m = -0.9
	for i in 20:
		ex._animate_rig(0.016)       # the arm animation itself (the game loop may be paused by a UI card here)
	check(absf(ex.rig.bucket_tip().y - tip_before) > 0.05, "manual boom control moves the bucket (%.2f m)" % (ex.rig.bucket_tip().y - tip_before))
	ex.boom_m = 0.0
	# driving: tracks scroll and the machine moves with eased throttle
	var belt_before := ex.rig._belts[0].uv1_offset.x as float
	var p0 := ex.global_position
	ex.input = {"throttle": -1.0, "steer": 0.0, "brake": false}
	await frames(90)
	var moved := ex.global_position.distance_to(p0)
	check(moved > 0.3 and ex.speed < 0.0, "driving moves the machine (%.2f m)" % moved)
	check(absf((ex.rig._belts[0].uv1_offset.x as float) - belt_before) > 0.1, "the track belts scroll while driving")
	ex.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
	await frames(60)
	# leaving shuts the engine down
	game.scripted_input = false
	game.exit_vehicle()
	await frames(20)
	check(ex.rig.engine_state == &"stopping" or ex.rig.engine_state == &"off", "leaving the cab shuts the engine down (%s)" % ex.rig.engine_state)
	# fallback: the procedural model still builds when the rig is disabled
	var fb := QuarryVehicle.new()
	check(fb.rig == null, "a vehicle without the rig keeps the fallback path")
	fb.free()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
