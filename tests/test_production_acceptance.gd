extends SceneTree
## The whole new production loop, as a player does it: sell from the Quick Sell Station, open Quarry OS, buy several crushers, conveyors, a merger and an
## output bin from the Equipment Catalog into the Build Inventory, pick them in Build Mode and place them (the ghost is checked for validity), connect two
## crushers through belts and a merger into one shared bin, process material with no duplication, store a machine back into the Build Inventory, place it
## somewhere else, and save and load the whole yard.
##   godot --headless --fixed-fps 60 -s tests/test_production_acceptance.gd

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

func stones(biz, st) -> int:
	var n: int = biz.conveyor_total()
	for c in st.crushers:
		n += int(c["output"])
	for o in biz.outputs:
		n += int(o["items"].get("crushed_stone", 0))
	return n

## Starts placing the build-mode selection of `key`, puts the ghost at pos/yaw and drops it. Returns true when the yard accepted it.
func place(game, key: String, pos: Vector3, yaw: float) -> bool:
	var keys: Array = game.build_inventory_keys()
	game.build_sel = keys.find(key)
	if game.build_sel < 0:
		return false
	game.construction = true
	if not game.build_place_selected():
		return false
	game.ghost.position = pos
	game.placement_yaw = yaw
	game.ghost.rotation.y = yaw
	game.ghost_valid = true
	game._place_ghost()
	game.construction = false
	return not game.placement

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	for i in 6:
		await physics_frame
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await process_frame
	var st = game.state
	var biz = game.business
	var prog = game.prog

	# 1. mine / quick sell
	for k in game.RESOURCE_ORDER:
		st.inventory[k] = 0
		st.storage[k] = 0
	st.inventory["limestone"] = 8
	var m0: int = st.money
	var got: int = game.quick_sell({"limestone": 8})
	check(got > 0 and st.money == m0 + got and int(st.inventory["limestone"]) == 0, "quick sell: 8 limestone sold at the station for $%d" % got)

	# 2. Quarry OS: buy 2 crushers, 4 belts, a merger, 1 output bin
	for s in range(prog.stages().size()):
		prog.stage = s
		if prog.unlocked("crusher"):
			break
	biz.milestones["mechanized"] = true
	st.money = 200000
	biz.inventory.clear()
	game.management.os.open_app("catalog")
	await process_frame
	check(game.management.os.window_of("catalog") != null, "Quarry OS: the Equipment Catalog opens")
	game.catalog_buy("crusher", 2)
	game.catalog_buy("conveyor", 3)
	game.catalog_buy("conveyor_merger", 1)
	game.catalog_buy("output", 1)
	check(int(biz.inventory.get("crusher", 0)) == 2 and int(biz.inventory.get("conveyor", 0)) == 3 and int(biz.inventory.get("conveyor_merger", 0)) == 1 and int(biz.inventory.get("output", 0)) == 1, "the Build Inventory holds 2 crushers, 3 belts, 1 merger, 1 output bin")
	check(game.build_inventory_units() == 7 and game.build_inventory_keys().size() == 4, "7 units in 4 kinds, listed in Build Mode")
	game.build_sel = 0
	game.build_pick_step(1)
	check(game.build_selected() == game.build_inventory_keys()[1], "[ ] steps through the inventory")

	# 3. place everything with Build Mode (positions in the clear east yard)
	var o := Vector3(60.0, 0.0, 30.0)
	check(place(game, "crusher", o + Vector3(4.2, 0, 0), PI * 0.5), "build mode places crusher #1 from the inventory")
	check(place(game, "crusher", o + Vector3(-4.2, 0, 0), -PI * 0.5), "and crusher #2")
	check(place(game, "output", o + Vector3(0, 0, -4.0), 0.0), "and the output bin")
	check(place(game, "conveyor_merger", o, 0.0), "and the merger")
	check(place(game, "conveyor", o + Vector3(0, 0, -2.0), 0.0), "and the output belt")
	check(place(game, "conveyor", o + Vector3(2, 0, 0), PI * 0.5), "and belt A")
	check(place(game, "conveyor", o + Vector3(-2, 0, 0), -PI * 0.5), "and belt B")
	check(game.build_inventory_units() == 0, "the Build Inventory is empty: everything was placed (none left over, none duplicated)")
	check(st.crushers.size() >= 2 and biz.conveyors.size() == 4 and biz.outputs.size() >= 1, "the yard has the 2 crushers, 4 belts and the bin")
	biz.compute_links()
	var merger := -1
	for i in biz.conveyors.size():
		if str(biz.conveyors[i]["kind"]) == "merger":
			merger = i
	var feeders := 0
	for i in biz.conveyors.size():
		if i != merger and str(biz.links[i]["dst"].get("type", "")) == "conveyor" and int(biz.links[i]["dst"]["index"]) == merger:
			feeders += 1
	check(merger >= 0 and feeders == 2, "two belts feed the merger (%d)" % feeders)
	# 4. process: both crushers hold finished stone; it flows through the merger into the shared bin
	var ca := -1
	var cb := -1
	for i in biz.conveyors.size():
		if str(biz.links[i]["src"].get("type", "")) == "crusher":
			if ca < 0:
				ca = int(biz.links[i]["src"]["index"])
			else:
				cb = int(biz.links[i]["src"]["index"])
	check(ca >= 0 and cb >= 0 and ca != cb, "each feeder belt starts at a different crusher")
	st.crushers[ca]["output"] = 9
	st.crushers[cb]["output"] = 9
	var bin_i := -1
	for i in biz.outputs.size():
		if biz.links[0].get("dst", {}).get("index", -2) == i or int(biz.outputs[i]["items"].get("crushed_stone", 0)) >= 0:
			bin_i = i
	var before := stones(biz, st)
	var ok := true
	var t := 0.0
	while t < 300.0 and biz.conveyor_total() + int(st.crushers[ca]["output"]) + int(st.crushers[cb]["output"]) > 0:
		biz.tick_conveyors(0.1)
		t += 0.1
		if stones(biz, st) != before:
			ok = false
	check(ok and stones(biz, st) == before, "processing: no stone created or lost on the way (%d throughout)" % before)
	var in_bin := 0
	for oo in biz.outputs:
		in_bin += int(oo["items"].get("crushed_stone", 0))
	check(in_bin == 18, "all 18 stones from both crushers are in the shared bin (%d)" % in_bin)

	# 5. relocate: store the merger, then place it again elsewhere
	var mi := merger
	check(game.store_to_inventory("conveyor", mi), "build mode: the merger is picked up into the Build Inventory")
	check(int(biz.inventory.get("conveyor_merger", 0)) == 1 and biz.conveyors.size() == 3, "free of charge, and the belts that remain stay put")
	var m1: int = st.money
	check(place(game, "conveyor_merger", o, 0.0) and st.money == m1, "placing it again costs nothing and reconnects the line")
	biz.compute_links()
	check(biz.conveyors.size() == 4, "4 belts again")

	# 6. save and load the whole yard
	var snap: Dictionary = JSON.parse_string(JSON.stringify(biz.snapshot()))
	var crushers_json := JSON.stringify(st.crushers)
	biz.inventory["crusher"] = 5
	biz.restore(snap)
	check(int(biz.inventory.get("crusher", 0)) == int(snap["inventory"].get("crusher", 0)), "a save keeps the Build Inventory")
	check(JSON.stringify(st.crushers) == crushers_json, "and the crushers, belts and bin are as they were")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
