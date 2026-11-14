extends SceneTree
## Phase 1 economy and progression repair: selling from every store, the soil economy, constant prices, sale rounding, stage gates for
## upgrades, vehicle purchases without factory milestones, storage sized for the trucks, rewards that can be reached, save/load.
##   godot --headless --fixed-fps 60 -s tests/test_economy_repair.gd
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

func boot():
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	return game

func run() -> void:
	for path in ["user://quarry_save.json", "user://quarry_save.bak", "user://quarry_save.json.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var game = await boot()
	var st = game.state
	var prog = game.prog
	var biz = game.business

	# ---- prices are the same at every stage
	var same := true
	for i in range(prog.stages().size()):
		prog.stage = i
		prog.apply_stage_effects()
		same = same and is_equal_approx(st.unit_price("limestone"), 3.0) and is_equal_approx(st.unit_price("gold_ore"), 80.0)
	prog.stage = 0
	prog.apply_stage_effects()
	check(same, "1 a material pays the same at every stage (stage multipliers are gone)")

	# ---- rounding: a real sale is never worth $0
	check(st.payout("topsoil", 1) == 1 and st.payout("limestone", 1) == 3 and st.payout("topsoil", 0) == 0, "2 a lot of 1 topsoil pays $1, an empty lot pays nothing")
	check(st.payout("limestone", 3, 1.06) == 10, "2 the clerk's bonus is applied before one rounding")

	# ---- selling from every store, as one sale, with the units conserved
	biz.add_output(Vector3(0, 0, 0), 0.0)                 # a crusher output storage
	st.inventory["crushed_stone"] = 2
	st.storage["crushed_stone"] = 3
	biz.outputs[0]["items"]["crushed_stone"] = 4
	st.inventory["limestone"] = 5
	var total_before: int = biz.sellable_units("crushed_stone") + biz.sellable_units("limestone")
	var money0: int = st.money
	var r: Dictionary = biz.sell_material("crushed_stone")
	check(int(r["units"]) == 9 and int(r["bag"]) == 2 and int(r["storage"]) == 3 and int(r["output"]) == 4, "3 one sale takes the bag, the storage bin and the output storage")
	check(st.money - money0 == 63 and int(r["money"]) == 63 and biz.sellable_units("crushed_stone") == 0, "3 nine crushed stone at $7 pay $63 and leave nothing behind")
	check(int(biz.outputs[0]["items"]["crushed_stone"]) == 0 and int(st.storage["crushed_stone"]) == 0 and int(st.inventory["crushed_stone"]) == 0, "3 no unit is counted twice and none is left in any store")
	check(biz.sellable_units("limestone") == 5 and total_before - 9 == 5, "3 other materials are untouched (quantities conserved)")
	check(int(biz.sell_material("crushed_stone")["units"]) == 0 and st.money - money0 == 63, "3 selling again pays nothing")
	# through the booth
	st.storage["coal"] = 2
	biz.outputs[0]["items"]["coal"] = 1
	var m1: int = st.money
	game.sell_from_bag(["coal"])
	check(st.money - m1 == st.payout("coal", 3) and biz.sellable_units("coal") == 0, "3 the sales booth sells storage and output storage without moving anything to the bag")

	# ---- the booth lists only what you own
	st.inventory["limestone"] = 3
	for k in ["coal", "iron_ore", "copper_ore", "gold_ore", "topsoil", "gravel", "crushed_stone"]:
		st.inventory[k] = 0
		st.storage[k] = 0
		biz.outputs[0]["items"][k] = 0
	biz.outputs[0]["items"]["crushed_stone"] = 2
	game._open_menu("sell", -1)
	await frames(3)
	check(game.panel.buttons.has("sell_limestone") and game.panel.buttons.has("sell_crushed_stone"), "4 rows exist for what you own, wherever it is stored")
	check(not game.panel.buttons.has("sell_iron_ore") and not game.panel.buttons.has("sell_gold_ore"), "4 no empty rows for materials you do not have")
	game._close_menu()

	# ---- soil: never a script error, never stored, never paid
	var rec: Dictionary = game.fleet.give("starter_truck", Vector3(0, 0, 0), 0.0)
	game.fleet.add_cargo(rec, "soil", 5)
	game.fleet.add_cargo(rec, "topsoil", 4)
	var moved: int = game.fleet.dump_to(rec, {"type": "storage"})
	check(moved == 4 and int(rec["cargo"].get("soil", 0)) == 5 and int(st.storage["topsoil"]) == 4, "5 tipping into the storage bin moves the topsoil and keeps the loose soil on the truck")
	check(biz.ep_space({"type": "storage"}, "soil") == 0, "5 loose soil is not a storable material")
	var dumped0: int = st.soil_dumped
	var hauled0: int = int(prog.area_state("area_1")["soil_hauled"])
	var money2: int = st.money
	var n: int = game._dump_soil(rec)
	check(n == 5 and st.soil_dumped == dumped0 + 5 and int(prog.area_state("area_1")["soil_hauled"]) == hauled0 + 5 and st.money == money2, "5 the spoil heap takes the soil, counts it toward Area 1 and pays nothing")
	check(int(rec["cargo"].get("soil", 0)) == 0, "5 the truck is empty afterwards")

	# ---- upgrades are gated by stage
	st.money = 100000
	prog.stage = 0
	check(not game.buy_player_upgrade("faster_mining") and not game.buy_player_upgrade("expanded_storage") and not st.upgrades["faster_mining"], "6 mining technique and expanded storage are locked at Grandpa's Legacy")
	check(game.buy_player_upgrade("larger_backpack"), "6 the backpack is the one upgrade open from the start")
	prog.stage = 1
	check(not game.buy_player_upgrade("faster_mining"), "6 mining technique still waits for the Workshop at Better Tools")
	prog.stage = 2
	check(game.buy_player_upgrade("faster_mining") and game.buy_player_upgrade("expanded_storage"), "6 the Workshop opens mining technique and expanded storage")
	check(not game.buy_player_upgrade("efficient_crusher") and not game.buy_player_upgrade("hauling_harness"), "6 crusher tuning and the harness need Breaking Ground (and a crusher / hand cart)")

	# ---- vehicles: stage and money only
	var gate := QuarryFleet.new(QuarryBusiness.new(QuarryState.new(st.config), biz.cfg), game.fleet.cfg)
	gate.state.money = 99999
	check(not gate.buy("truck", Vector3.ZERO).is_empty() and not gate.buy("compact_excavator", Vector3.ZERO).is_empty(), "7 trucks and excavators need no factory milestone")
	prog.stage = 0
	check(not prog.unlocked("truck") and not prog.unlocked("heavy_excavator"), "7 they are still gated by stage")

	# ---- storage can take the trucks of each stage
	prog.stage = prog.stage_index("moving_mountains")
	prog.apply_stage_effects()
	var heavy: int = int(game.fleet.spec("heavy_truck")["capacity"])
	check(st.storage_capacity() >= heavy, "8 at Moving Mountains the bin (%d) takes a heavy truck (%d)" % [st.storage_capacity(), heavy])
	prog.stage = prog.stage_index("deeper_ground")
	prog.apply_stage_effects()
	var ind: int = int(game.fleet.spec("industrial_truck")["capacity"])
	check(st.storage_capacity() >= ind, "8 at Deeper Ground the bin (%d) takes an industrial truck (%d)" % [st.storage_capacity(), ind])
	prog.stage = 0
	prog.apply_stage_effects()

	# ---- the reachable rewards
	check([int(prog.area_def("area_1")["reward"]), int(prog.area_def("area_2")["reward"]), int(prog.area_def("area_3")["reward"]), int(prog.area_def("area_4")["reward"]), int(prog.area_def("area_5")["reward"]), int(prog.area_def("area_6")["reward"])] == [120, 300, 700, 2500, 7000, 18000], "9 the six contracts pay the new rewards")
	check(str(prog.area_def("area_6")["title"]).begins_with("AREA 6"), "9 Area 6 is called Area 6")
	prog.ensure_formation("q_a5_gold")
	st.deposits["q_a5_gold"]["mined"] = 1
	var gold_ok := false
	for m in prog.milestone_defs():
		if str(m["id"]) == "first_gold":
			gold_ok = prog.milestone_met(m)
	check(gold_ok, "9 the first-gold bonus is reached by mining the new quarry's gold bench")
	check(prog.fdef("q_a5_gold").get("pads", []).size() >= 2 and int(prog.material("gold_ore")["hardness"]) <= int(prog.machine("improved_rig")["max_hardness"]), "9 gold can be drilled by rigs: the gold bench has pads and the improved rig is hard enough")
	var iron_pockets := 0
	for v in prog.veins("q_a2_rock"):
		if str(v["res"]) == "iron_ore":
			iron_pockets += 1
	check(iron_pockets >= 30, "9 Area 2 holds plenty of iron pockets for the Stage 5 discovery (%d)" % iron_pockets)
	check(prog.permit_block_reason().begins_with("Not needed"), "9 the excavation permit is not sold in the new quarry")
	check(int(prog.stage_info(11)["req"]["earned"]) <= 450000, "9 Stage 12 asks for $450,000 of sales, well within the quarry's value")
	# lockbox
	prog.story["found"].erase("first_clear")
	prog.area_check("area_1")
	prog.area_state("area_1").merge({"rock": 60, "soil_removed": 48, "soil_hauled": 24}, true)
	for cid in prog.cleanup_ids():
		prog.clear_cleanup_item(cid)
	prog.area_check("area_1")
	await frames(3)
	check(bool(prog.story["found"].get("first_clear", false)), "9 the lockbox is found when the first contract is done")
	check(prog.milestone_title("soil_hauled").contains("units of soil"), "9 the soil objective says units, not loads")

	# ---- save and load
	st.earned = 12345
	st.money = 777
	prog.stage = 2
	prog.apply_stage_effects()
	st.storage["limestone"] = 6
	biz.outputs[0]["items"]["coal"] = 3
	game._save()
	var g2 = await boot()
	g2._load()
	await frames(3)
	check(g2.state.earned == 12345 and g2.state.money == 777 and g2.state.upgrades["larger_backpack"] and int(g2.state.storage["limestone"]) == 6, "10 earned, money, upgrades and storage survive a save")
	check(g2.business.outputs.size() >= 1 and int(g2.business.outputs[0]["items"]["coal"]) == 3, "10 output storage contents survive a save")
	check(g2.prog.area_complete("area_1") and g2.state.unit_price("limestone") == 3.0, "10 contracts and prices survive a save")
	for path in ["user://quarry_save.json", "user://quarry_save.bak", "user://quarry_save.json.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
