extends SceneTree
## Service gate: a delivery driver brings new machinery in through the garage door, parks it and walks out;
## hired workers walk in through the gate.
##   godot --headless --fixed-fps 60 -s tests/test_delivery.gd

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
	root.add_child(game)
	await process_frame
	for i in range(4):
		await physics_frame
	game.hud.close_card()
	await process_frame
	game.hud.close_card()
	await process_frame
	var d: QuarryDelivery = game.delivery
	check(d != null, "A the world has a delivery service")
	check(game.get_node_or_null("Delivery") != null, "A built into the scene")
	game.prog.cleanup["done"] = true
	game.business.milestones["mechanized"] = true
	game.prog.stage = game.prog.stage_index("large")
	game.state.money = 50000
	var msg: String = game.ui_buy_vehicle("loader")
	check(msg.ends_with("parking area."), "B buying a loader is accepted: " + msg)
	check(d.jobs.size() == 1, "B a delivery job started")
	var v = d.jobs[0]["vehicle"]
	var slot: Vector3 = d.jobs[0]["slot"]
	check(v.global_position.z > 25.0, "B the machine starts at the tunnel mouth in the south")
	check(v.has_meta("delivering") and v.collision_layer == 0, "B it is not drivable while being delivered")
	check(d.jobs[0]["driver"].get_parent() == v, "B a driver sits in the cab")
	game.enter_vehicle(v)
	check(game.driving == null, "B the player cannot get in while it is being delivered")
	check(game.free_parking_slot() != slot, "B the bay is reserved")
	var passed_door := false
	var opened := false
	for i in range(900):
		await physics_frame
		if d.jobs.is_empty():
			break
		if absf(v.global_position.z - d.DOOR_Z) < 0.5:
			passed_door = true
			opened = opened or d.is_open()
	check(passed_door and opened, "C the door rolls up before the machine goes through")
	await frames(240, func(): return d.delivered > 0)
	check(d.delivered == 1 and d.jobs.is_empty(), "C the driver finished: machine parked, driver gone")
	check(v.global_position.distance_to(slot) < 0.3 and not v.has_meta("delivering") and v.collision_layer == 8, "C it ended on its bay and is a normal machine again")
	check(not d.reserved.has(slot), "C the bay is released")
	await frames(120)
	check(d.open_amount < 0.2, "C the door closes behind them")
	check(v.global_position.distance_to(slot) < 0.6 and v.global_position.y < 1.0, "C the machine stays parked (does not fall or drift)")
	game.enter_vehicle(v)
	check(game.driving == v, "D the player can now drive it")
	game.exit_vehicle()
	await frames(5)
	# hires step out of the gate and walk in
	game.state.money = 50000
	game.state.clock_minutes = 480.0
	game.ui_hire("rosa")
	var w = game.worker_nodes.values()[0]
	check(Vector2(w.global_position.x, w.global_position.z).distance_to(Vector2(d.GATE.x, d.GATE.z)) < 2.0, "E a new hire appears at the service gate")
	game.business.set_shift(int(game.business.employees[0]["id"]), 0, 1439)
	await frames(900, func(): return w.global_position.z < 21.5)
	check(w.global_position.z < 21.5, "E the hire walks in through the garage door (z %.1f)" % w.global_position.z)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
