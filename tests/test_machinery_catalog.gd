extends SceneTree
## Every finished machine can be bought through the intended progression: it is in the shop with a real price and a stage gate (nothing late-game is open at the
## start), the price is affordable at the stage it unlocks (checked against the stage's earnings requirement), buying takes exactly the price, the machine spawns as
## the Blender model for its kind, and it persists through a save and load. Machines without a finished model are not for sale.
##   godot --headless --fixed-fps 60 -s tests/test_machinery_catalog.gd

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
	var prog: QuarryProgression = game.prog
	var fleet = game.fleet
	var blender_kinds := ["loader", "truck", "excavator", "bulldozer"]
	var types: Array = fleet.types()
	check(types.size() == 8, "the shop lists 8 machines (%s)" % str(types))
	# the audit: every machine kind that has a finished Blender model has at least one buyable entry
	var kinds_for_sale := {}
	for t in types:
		kinds_for_sale[fleet.kind(str(t))] = true
	for k in blender_kinds:
		check(kinds_for_sale.has(k), "a %s is for sale" % k)
	var start_stage := prog.stage
	for t in types:
		var t_s: String = str(t)
		var sp: Dictionary = fleet.spec(t_s)
		var gate: String = prog.gate_stage(t_s)
		check(int(sp["price"]) > 0 and gate != "", "%s: has a price ($%d) and a stage gate (%s)" % [t_s, int(sp["price"]), gate])
		var gi := prog.stage_index(gate)
		check(gi > start_stage and not prog.unlocked(t_s), "%s: locked at the start (opens at stage %d)" % [t_s, gi])
		var earned_need := float(prog.stages()[gi].get("req", {}).get("earned", 0))
		check(earned_need <= 0.0 or float(sp["price"]) <= earned_need * 0.35, "%s: affordable when it unlocks ($%d against $%d earned by then)" % [t_s, int(sp["price"]), int(earned_need)])
		# locked: refused, nothing taken
		game.state.money = int(sp["price"]) + 100
		var before: int = fleet.vehicles.size()
		var msg: String = game.ui_buy_vehicle(t_s)
		check(msg.contains("unlocks") and fleet.vehicles.size() == before and game.state.money == int(sp["price"]) + 100, "%s: refused while locked, nothing is taken (%s)" % [t_s, msg])
		# unlocked: bought for exactly its price, spawns as the Blender machine, survives a save
		prog.stage = gi
		game.state.money = int(sp["price"])
		while fleet.vehicles.size() >= int(fleet.cfg.get("max_vehicles", 4)):
			fleet.vehicles.pop_back()
		var m2: String = game.ui_buy_vehicle(t_s)
		check(game.state.money == 0 and fleet.owns_type(t_s), "%s: bought for exactly $%d (%s)" % [t_s, int(sp["price"]), m2])
		game._sync_vehicles()
		await frames(4)
		var node: QuarryVehicle = null
		for v in game.vehicle_nodes.values():
			if v.vtype == t_s:
				node = v
		var k: String = fleet.kind(t_s)
		var rigged: bool = node != null and ((k == "excavator" and node.rig != null) or (k == "truck" and node.trig != null) or (k == "loader" and node.lrig != null) or (k == "bulldozer" and node.drig != null))
		check(node != null and node.vkind == k and rigged, "%s: spawns as the Blender %s" % [t_s, k])
		var snap: Dictionary = JSON.parse_string(JSON.stringify(fleet.snapshot()))
		var owned_before: int = fleet.vehicles.size()
		fleet.restore(snap)
		check(fleet.owns_type(t_s) and fleet.vehicles.size() == owned_before, "%s: still owned after a save and load" % t_s)
		# back to the start for the next machine
		for i in range(fleet.vehicles.size() - 1, -1, -1):
			if str(fleet.vehicles[i]["type"]) == t_s:
				fleet.vehicles.remove_at(i)
		game._sync_vehicles()
		prog.stage = start_stage
		await frames(2)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
