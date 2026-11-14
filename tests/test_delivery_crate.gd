extends SceneTree
## Crate delivery truck for stationary machinery (cosmetic) and the delivery skip: the order is paid once and in the inventory at once, the truck
## comes in, tips and leaves, skipping ends with the same state, and a skipped vehicle delivery leaves exactly one parked machine.
##   godot --headless --fixed-fps 60 -s tests/test_delivery_crate.gd
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
	root.add_child(game)
	await process_frame
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await process_frame
	game.prog.stage = game.prog.stage_index("large")
	game.business.milestones["mechanized"] = true
	game.state.money = 50000
	var d: QuarryDelivery = game.delivery
	var money0: float = game.state.money
	var inv0: int = int(game.business.inventory.get("output", 0))
	var price: int = game._placement_price("output")
	check(game.order_machine("output"), "ordering an output storage succeeds")
	check(int(game.business.inventory.get("output", 0)) == inv0 + 1, "it is in the construction inventory at once, exactly once")
	check(game.state.money == money0 - price, "payment was taken once ($%d)" % price)
	check(d.crate_jobs.size() == 1, "a crate truck was sent")
	var node: Node3D = d.crate_jobs[0]["node"]
	var start: Vector3 = node.global_position
	var saw := {}
	var moved_ok := false
	var wheel_turned := false
	var w0: float = (d.crate_jobs[0]["wheels"][0] as Node3D).rotation.x
	for f in range(60 * 70):
		await physics_frame
		if d.crate_jobs.is_empty():
			break
		saw[str(d.crate_jobs[0]["stage"])] = true
		if node.global_position.distance_to(start) > 4.0:
			moved_ok = true
		if absf((d.crate_jobs[0]["wheels"][0] as Node3D).rotation.x - w0) > 1.0:
			wheel_turned = true
	check(moved_ok and wheel_turned, "the truck drove in and its wheels turned")
	check(saw.has("in") and saw.has("tip") and saw.has("out"), "it went in, tipped the crate and reversed out (%s)" % str(saw.keys()))
	check(d.crate_jobs.is_empty() and not is_instance_valid(node) or (node != null and node.is_queued_for_deletion()), "it is gone afterwards")
	check(int(game.business.inventory.get("output", 0)) == inv0 + 1 and game.state.money == money0 - price, "the truck changed neither inventory nor money")
	# skipping: same end state, nothing duplicated
	game.order_machine("output")
	await frames(30)
	check(d.crate_jobs.size() == 1, "a second order sends a second truck")
	d.finish_all()
	check(d.crate_jobs.is_empty(), "skipping clears the crate truck")
	check(int(game.business.inventory.get("output", 0)) == inv0 + 2, "and the inventory is still exactly two units")
	# a vehicle delivery skipped part-way
	var n_before: int = game.fleet.vehicles.size()
	game.state.money = 90000
	game.prog.stage = game.prog.stage_index("deep")
	var vt: String = str(game.fleet.types()[0])
	var msg: String = game.ui_buy_vehicle(vt)
	print("buy msg: ", msg)
	await frames(40)
	if d.jobs.size() > 0:
		d.finish_all()
		await frames(5)
		check(d.jobs.is_empty() and game.fleet.vehicles.size() == n_before + 1, "a skipped vehicle delivery leaves exactly one new machine, parked")
		var v: QuarryVehicle = game.vehicle_nodes[int(game.fleet.vehicles[-1]["id"])]
		check(not v.has_meta("delivering") and v.visible and v.collision_layer == 8, "and it is a normal, solid parked vehicle")
	else:
		print("note: no vehicle delivery was running (purchase refused: %s)" % msg)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
