extends SceneTree
## Vehicle handling after the speed pass: trucks are the fast way across the quarry, excavators are slower but practical, and every number can be tuned in data.
##   godot --headless --fixed-fps 60 -s tests/test_vehicle_speed.gd
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
	await frames(20)
	var fl: QuarryFleet = game.fleet
	var tr: Dictionary = {"type": "truck", "cargo": {}}
	var ex: Dictionary = {"type": "compact_excavator", "cargo": {}}
	check(fl.max_speed(tr) >= 11.0 and fl.max_speed(tr) > fl.max_speed(ex) * 2.0, "the truck (%.1f m/s) is much faster than the excavator (%.1f m/s)" % [fl.max_speed(tr), fl.max_speed(ex)])
	check(fl.max_speed(ex) > 3.2 and fl.max_speed(ex) < fl.max_speed({"type": "compact_truck", "cargo": {}}), "the excavator got quicker but stays slower than any truck")
	for t in ["compact_truck", "truck", "heavy_truck", "industrial_truck", "compact_excavator", "heavy_excavator"]:
		check(fl.accel({"type": t, "cargo": {}}) > 2.0 or t in ["industrial_truck", "heavy_excavator"], "%s accelerates briskly" % t)
	# the quarry is ~250 m wide: crossing it by truck
	var secs: float = 250.0 / fl.max_speed(tr)
	check(secs < 26.0, "crossing the 250 m quarry takes a truck about %.0f s" % secs)
	# tuning multipliers apply
	var base: float = fl.max_speed(tr)
	fl.cfg["tuning"]["truck_speed_mult"] = 0.5
	check(absf(fl.max_speed(tr) - base * 0.5) < 0.01, "the data tuning multiplier scales truck speed")
	fl.cfg["tuning"]["truck_speed_mult"] = 1.0
	# a driven truck really reaches its speed and brakes
	var rec: Dictionary = fl.give("truck", Vector3(30, 0.2, 14), 0.0)
	game._sync_vehicles(true)
	await frames(10)
	var v: QuarryVehicle = game.vehicle_nodes[int(rec["id"])]
	v.global_position = Vector3(-110, 0.3, -20)      # open ground inside the quarry
	v.rotation.y = -PI * 0.5
	v.velocity = Vector3.ZERO
	await frames(20)
	game.enter_vehicle(v)
	game.scripted_input = true
	v.input = {"throttle": 1.0, "steer": 0.0, "brake": false}
	await frames(240)
	check(v.speed > 8.5, "driven flat out on the road the truck reaches %.1f m/s" % v.speed)
	v.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
	var t0 := 0
	while v.speed > 0.2 and t0 < 240:
		await physics_frame
		t0 += 1
	check(t0 < 120, "and stops in %.1f s" % (float(t0) / 60.0))
	game.exit_vehicle()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
