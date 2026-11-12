extends SceneTree
## Phase 9.7: the Phase 9.6 equipment (carts, hopper, sorting table) inside the reconstructed open-pit quarry, and saves from both branches.
##   godot --headless --fixed-fps 60 -s tests/test_integration97.gd

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

func load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.natural_start_enabled = false      # Phase 10: these suites test the older systems on the old starting layout
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
	var st: QuarryState = game.state
	var biz: QuarryBusiness = game.business
	var pz: QuarryPitZone = game.pit_zone
	prog.cleanup["done"] = true
	game._sync_pit_gate()
	game.safety.enabled = false
	prog.stage = prog.stage_index("deep")
	st.money = 200000
	# ---- A: the merged data
	var cfg := prog.cfg
	check(cfg["feature_gates"].has("hopper") and cfg["feature_gates"].has("sorter") and cfg["formations"].has("bench_l4_gold") and cfg["gear"].has("hand_cart") and cfg["stages"].size() == 12,
		"A the merged configuration has the pit formations, the 12 stages, the gear and the hopper and table gates")
	check(game.cart_nodes.size() == 0 and game.output_nodes.size() >= 0 and pz.level_pits.size() == 3, "A a new game has the four-level pit and no carts yet")
	# ---- B: a loaded wheelbarrow goes down the pit's entry ramp with the player
	prog.buy_gear("hand_cart")
	prog.buy_gear("wheelbarrow")
	game._refresh_workbench()
	await frames(3)
	var wb: QuarryCart = game.cart_nodes["wheelbarrow"]
	st.inventory["limestone"] = 15
	st.inventory["coal"] = 10
	game.cart_move("load", "wheelbarrow", "limestone")
	game.cart_move("load", "wheelbarrow", "coal")
	var carried: int = st.cart_total("wheelbarrow")
	var all0: int = st.all_units()
	game.player.locked = false
	game.player.global_position = pz.to_world(Vector3(0, 0.3, -24.0))
	game.player.rotation.y = pz.global_rotation.y
	await frames(3)
	wb.global_position = pz.to_world(Vector3(0, 0.05, -24.0 - 1.8))
	wb.rotation.y = game.player.rotation.y
	await frames(2)
	game.hold_cart("wheelbarrow")
	var fwd: Vector3 = -game.player.global_transform.basis.z
	for i in range(1500):
		game.player.drive_wish = fwd
		await physics_frame
		if pz.to_loc(game.player.global_position).z < -75.0:
			break
	game.player.drive_wish = Vector3.ZERO
	await frames(10)
	var lp: Vector3 = pz.to_loc(wb.global_position)
	check(game.held_cart == wb and lp.y < -3.0 and lp.z < -60.0, "B the wheelbarrow is pushed down the basin ramp onto the pit floor (cart at %s)" % str(lp.snapped(Vector3(0.1, 0.1, 0.1))))
	check(st.cart_total("wheelbarrow") == carried and st.all_units() == all0, "B and its load is exactly what it carried (%d units)" % carried)
	var floor_y: float = pz.to_loc(game.player.global_position).y
	check(floor_y > -4.0 and floor_y < -3.0, "B the player stands on the pit floor, not under it (y %.2f)" % floor_y)
	game.release_cart()
	# ---- C: hopper and sorting table on the pit floor
	var hpos: Vector3 = pz.to_world(Vector3(20, -3.6, -58))
	check(game.in_build_area(hpos), "C the pit floor is a build area for the new machines")
	var h: int = biz.add_output(hpos, 0.0, "hopper")
	game._create_output(h)
	var spos: Vector3 = pz.to_world(Vector3(30, -3.6, -58))
	var so: int = biz.add_output(spos, 0.0, "sorter")
	game._create_output(so)
	await frames(3)
	biz.ep_put({"type": "output", "index": h}, "coal", 25, false)
	st.inventory["limestone"] = 12
	game.output_deposit(so, "limestone")
	biz.sorter_start(so)
	biz.tick_sorters(7.0)
	check(biz.output_total(h) == 25 and biz.sorter_sorted(so, "limestone") == 10, "C the hopper holds coal and the table sorts a batch down in the pit")
	# ---- D: a real save file with carts, hopper and table, loaded repeatedly
	var units0: int = st.all_units() + biz.output_total(h) + biz.output_total(so)
	var money0: int = st.money
	var carts0: Array = st.carts.duplicate()
	var outs0: int = biz.outputs.size()
	var gear0: Array = st.gear.duplicate()
	game._save(true)
	for r in range(3):
		game._load(true)
		await frames(3)
	var units1: int = st.all_units() + biz.output_total(h) + biz.output_total(so)
	check(units1 == units0 and st.money == money0 and st.carts == carts0 and biz.outputs.size() == outs0 and st.gear == gear0, "D three save/load rounds change no unit, coin, cart, tool or machine")
	check(biz.variant_of(h) == "hopper" and biz.variant_of(so) == "sorter" and biz.sorter_sorted(so, "limestone") == 10 and game.cart_nodes.size() == 2 and game.output_nodes.size() == outs0, "D the hopper, the table (with its sorted rock) and both carts are back, once each")
	# ---- E: saves from the source branches
	var s9 := QuarryState.new(load_json("res://data/economy.json"))
	var snap9: Dictionary = {"version": 2, "tool_tier": 2, "earned": 5000, "money": 321, "inventory": {}, "storage": {}, "upgrades": {}, "crushers": [], "deposits": {}, "player_position": [0, 1, 8], "clock_minutes": 480, "player_yaw": 0,
		"lifetime": {"mined": {"iron_ore": 5}, "sold": {}}, "gear": ["pointed_chisel"], "equipped": "pointed_chisel", "carts": ["hand_cart"]}        # a Phase 9 state: gear and carts, no cart contents
	check(s9.restore(snap9) and s9.gear == ["pointed_chisel"] and s9.carts == ["hand_cart"] and s9.cart_total("hand_cart") == 0 and s9.money == 321 and s9.tool_tier == 2, "E a Phase 9 save loads: gear and carts kept, the cart simply starts empty")
	var b9 := QuarryBusiness.new(s9, load_json("res://data/business.json"))
	b9.restore({"outputs": [{"position": [5, 0, 5], "yaw": 0.0, "items": {"crushed_stone": 7}}], "employees": []})
	check(b9.outputs.size() == 1 and b9.variant_of(0) == "output" and b9.output_total(0) == 7 and b9.output_capacity_of(0) == 30, "E an older output bin (no variant) stays a plain 30-unit bin with its gravel")
	var s87 := QuarryState.new(load_json("res://data/economy.json"))
	var snap87: Dictionary = snap9.duplicate(true)
	for k in ["lifetime", "gear", "equipped", "carts"]:
		snap87.erase(k)
	check(s87.restore(snap87) and s87.gear.is_empty() and s87.carts.is_empty() and s87.cart_load.is_empty() and s87.money == 321, "E an 8.7 save (no Phase 9 fields) loads with safe empty defaults and the same money")
	var again: Dictionary = s87.snapshot()
	var s87b := QuarryState.new(load_json("res://data/economy.json"))
	check(s87b.restore(again) and s87b.snapshot() == again, "E what is saved loads back to the same state (no drift, no duplication)")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
