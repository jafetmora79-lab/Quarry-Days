extends SceneTree
## Phase 2 tests. Run headless with a fixed frame rate so scene tests do not wait in real time:
##   godot --headless --fixed-fps 60 -s tests/test_phase2.gd

var checks := 0
var failures := []
var cfg: Dictionary
var bcfg: Dictionary

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)
	else:
		print("PASS: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func make(money := 1000) -> QuarryBusiness:
	var s := QuarryState.new(cfg)
	s.money = money
	return QuarryBusiness.new(s, bcfg)

## Advance in-game time by whole minutes, as the game loop does (0.5 game min per real second).
func advance(b: QuarryBusiness, minutes: float, step_seconds := 30.0) -> void:
	var seconds := minutes * 2.0
	while seconds > 0.0:
		var dt := minf(step_seconds, seconds)
		b.state.tick(dt)
		b.tick(dt)
		seconds -= dt

func run_tests() -> void:
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy.json"))
	bcfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/business.json"))
	# Phase 5 scales wages and hiring fees (data/business.json); these arithmetic checks use the base values.
	bcfg["wage_scale"] = 1.0
	bcfg["hire_fee_scale"] = 1.0
	test_hiring()
	test_specialties()
	test_shifts()
	test_payroll()
	test_insufficient_funds()
	test_conveyors()
	test_clerk_sales()
	test_upgrades()
	test_exploits()
	await scene_tests()
	await chain_test()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

# ------------------------------------------------------------------ logic tests

func test_hiring() -> void:
	var b := make(100)
	var e := b.hire("rosa")
	check(not e.is_empty() and b.state.money == 85, "1 hiring deducts the $15 fee exactly")
	check(b.milestones["first_employee"], "milestone 1 reached on first hire")
	check(b.hire("rosa").is_empty() and b.state.money == 85, "same candidate cannot be hired twice")
	b.state.money = 10
	check(b.hire("ines").is_empty() and b.state.money == 10, "hiring blocked without enough money, nothing deducted")
	b.state.money = 1000
	b.hire("tomas"); b.hire("bram"); b.hire("petra")
	check(b.employees.size() == 4 and b.hire("omar").is_empty(), "staff limit of four enforced")
	check(b.hire_block_reason("omar").begins_with("Staff limit"), "staff limit reported to UI")

func test_specialties() -> void:
	var b := make()
	b.state.new_crusher(Vector3(0, 0, 0), 0)
	var miner := b.hire("rosa")
	var op := b.hire("tomas")
	var clerk := b.hire("petra")
	check(not b.assign(int(miner["id"]), {"crusher": 0}), "2 miner cannot be assigned to a crusher")
	check(not b.assign(int(op["id"]), {"resource": "coal"}), "2 operator cannot be assigned to mining")
	check(not b.assign(int(clerk["id"]), {"src": {"type": "storage"}, "dst": {"type": "crusher", "index": 0}}), "2 clerk cannot be given a hauling route")
	check(b.assign(int(miner["id"]), {"resource": "iron_ore"}) and miner["assignment"]["resource"] == "iron_ore", "2 miner can be assigned to iron")
	b.state.clock_minutes = 600
	b.payroll_minute = 600
	b.authorized["limestone"] = true
	b.state.storage["limestone"] = 5
	var money := b.state.money
	check(int(b.clerk_sell(miner)["units"]) == 0 and b.state.money == money, "2 miner cannot sell")
	b.state.crushers[0]["input"] = 3
	check(not b.operator_start(miner, 0) and not b.state.crushers[0]["running"], "2 miner cannot run a crusher")
	check(b.operator_start(op, 0) and b.state.crushers[0]["running"], "2 operator can run its crusher")

func test_shifts() -> void:
	check(not QuarryBusiness.on_shift_at(360, 840, 359) and QuarryBusiness.on_shift_at(360, 840, 360), "3 day shift starts exactly at 06:00")
	check(QuarryBusiness.on_shift_at(360, 840, 839) and not QuarryBusiness.on_shift_at(360, 840, 840), "3 day shift ends exactly at 14:00")
	check(QuarryBusiness.on_shift_at(1320, 360, 1400) and QuarryBusiness.on_shift_at(1320, 360, 100), "3 overnight shift spans midnight")
	check(not QuarryBusiness.on_shift_at(1320, 360, 360) and not QuarryBusiness.on_shift_at(1320, 360, 800), "3 overnight shift off during the day")
	var b := make()
	b.state.clock_minutes = 0
	b.payroll_minute = 0
	var e := b.hire("rosa")
	b.set_shift(int(e["id"]), 1320, 360)
	advance(b, 1440)
	check(int(e["stats"]["minutes_total"]) == 480, "3 overnight shift works exactly 8 hours in a day (got %d)" % int(e["stats"]["minutes_total"]))
	check(not b.set_shift(int(e["id"]), 600, 600), "3 zero-length shift rejected")

func test_payroll() -> void:
	var b := make(1000)
	b.state.clock_minutes = 0
	b.payroll_minute = 0
	var e := b.hire("rosa") # $3/h, 06:00-14:00
	var start_money := b.state.money
	advance(b, 300)
	check(b.state.money == start_money and int(e["stats"]["minutes_total"]) == 0, "4 no wages before the shift starts")
	advance(b, 1140)
	check(start_money - b.state.money == 24 and int(e["stats"]["paid_total"]) == 24, "4 eight hours at $3/h deducts exactly $24 (got %d)" % (start_money - b.state.money))
	check(int(b.day_stats(0)["wages"]) == 24, "4 daily labour expense recorded")
	check(float(e["owed"]) < 0.01, "4 nothing left owed after a fully paid shift")
	advance(b, 1440)
	check(start_money - b.state.money == 48 and int(b.day_stats(1)["wages"]) == 24, "4 second day billed separately")

func test_insufficient_funds() -> void:
	var b := make(15)
	b.state.clock_minutes = 480
	b.payroll_minute = 480
	var e := b.hire("rosa")
	check(b.state.money == 0, "5 balance is empty after hiring")
	advance(b, 120)
	check(bool(e["suspended"]) and not b.can_work(e), "5 unpaid worker stops working")
	check(float(e["owed"]) >= 1.0 and b.state.money == 0, "5 unpaid wages stay tracked, money never negative")
	var minutes := int(e["stats"]["minutes_total"])
	advance(b, 60)
	check(int(e["stats"]["minutes_total"]) == minutes, "5 no paid time accrues while suspended")
	var owed := float(e["owed"])
	b.state.money = 50
	advance(b, 1)
	check(not bool(e["suspended"]) and b.state.money == 50 - int(floor(owed + 0.0001)), "5 wages paid and work resumes once funds are available")

func test_conveyors() -> void:
	var b := make()
	b.state.new_crusher(Vector3(10, 0, 5), 0)  # input port at (10,0,6.15), output port at (10,0,3.85)
	b.add_conveyor(Vector3(10, 0, 7.5), 0)      # storage crate -> crusher hopper
	b.add_conveyor(Vector3(10, 0, 2.85), 0)     # crusher output -> next belt
	b.add_conveyor(Vector3(10, 0, 0.85), 0)     # -> output storage
	b.add_output(Vector3(10, 0, -1.2), 0)
	check(b.links[0]["src"].get("type") == "storage" and b.links[0]["dst"].get("type") == "crusher" and b.links[0]["resource"] == "limestone", "9 conveyor links storage to crusher hopper")
	check(b.links[1]["dst"].get("type") == "conveyor" and b.links[2]["dst"].get("type") == "output" and b.links[1]["resource"] == "crushed_stone", "9 chained belts link crusher output to output storage")
	b.state.storage["limestone"] = 10
	b.state.storage["coal"] = 4
	b.state.crushers[0]["output"] = 5
	var conserved := true
	for i in range(600):
		b.tick(0.1)
		var lime := int(b.state.storage["limestone"]) + int(b.state.crushers[0]["hopper"]) + (int(b.conveyors[0]["items"]))
		var crushed := int(b.state.crushers[0]["output"]) + int(b.conveyors[1]["items"]) + int(b.conveyors[2]["items"]) + b.output_total(0)
		conserved = conserved and lime == 10 and crushed == 5
	check(conserved, "9 conveyor quantities conserved every step")
	check(int(b.state.crushers[0]["hopper"]) == 10 and int(b.state.storage["limestone"]) == 0, "9 all 10 limestone conveyed into the hopper")
	check(b.output_total(0) == 5 and int(b.state.crushers[0]["output"]) == 0, "9 all 5 crushed stone conveyed to output storage")
	check(int(b.state.storage["coal"]) == 4, "9 belts ignore incompatible materials")
	var b2 := make()
	b2.state.new_crusher(Vector3(10, 0, 5), 0)
	b2.add_conveyor(Vector3(10, 0, 7.5), 0)
	b2.state.storage["limestone"] = 10
	for i in range(100):
		b2.tick(0.1)  # 10 seconds at 0.5 units/s
	check(int(b2.state.crushers[0]["hopper"]) <= 5 and int(b2.state.crushers[0]["hopper"]) >= 3, "9 transfer respects the configured rate (got %d in 10 s)" % int(b2.state.crushers[0]["hopper"]))

func test_clerk_sales() -> void:
	var b := make(100)
	var clerk := b.hire("petra")
	b.state.clock_minutes = 600
	b.payroll_minute = 600
	b.add_output(Vector3(0, 0, 0), 0)
	b.outputs[0]["items"]["crushed_stone"] = 5
	b.state.storage["crushed_stone"] = 2
	b.state.storage["limestone"] = 9
	var money := b.state.money
	var sale := b.clerk_sell(clerk)
	check(int(sale["units"]) == 0 and b.state.money == money, "10 nothing sold without authorization")
	b.authorized["crushed_stone"] = true
	sale = b.clerk_sell(clerk)
	check(int(sale["units"]) == 3 and b.state.money == money + 33, "10 clerk sells 3 crushed stone for $33")
	check(int(b.state.storage["crushed_stone"]) == 0 and b.output_total(0) == 4, "10 sold stock removed from storage then output storage")
	check(int(b.state.storage["limestone"]) == 9, "10 unauthorized limestone untouched")
	check(b.chain["sold"], "10 automated crushed-stone sale counts toward the chain")
	b.state.clock_minutes = 1200
	b.tick(0.0)
	money = b.state.money
	check(int(b.clerk_sell(clerk)["units"]) == 0 and b.state.money == money, "10 clerk does not sell off shift")

func test_upgrades() -> void:
	var b := make(2000)
	var miner := b.hire("rosa")
	var before := b.stat(miner, "strike_interval")
	var money := b.state.money
	check(b.buy_upgrade(int(miner["id"])) and b.state.money == money - 60, "11 miner upgrade costs $60")
	check(b.stat(miner, "strike_interval") < before * 0.71, "11 faster mining shortens strikes by 30%")
	check(int(b.stat(miner, "hits")) == 4 and b.buy_upgrade(int(miner["id"])) and int(b.stat(miner, "hits")) == 3, "11 improved tool needs one hit fewer")
	check(int(b.stat(miner, "yield")) == 0 and b.buy_upgrade(int(miner["id"])) and int(b.stat(miner, "yield")) == 1, "11 higher yield adds a piece per break")
	money = b.state.money
	check(not b.buy_upgrade(int(miner["id"])) and b.state.money == money, "11 no fourth upgrade level, nothing charged")
	check(is_equal_approx(b.wage(miner), 4.5), "11 trained miner earns +$0.50/h per level")
	var hauler := b.hire("bram")
	b.buy_upgrade(int(hauler["id"]))
	check(int(b.stat(hauler, "carry")) == 9, "11 hauler carries 9 instead of 5")
	var op := b.hire("tomas")
	var dt := b.stat(op, "downtime")
	b.buy_upgrade(int(op["id"])); b.buy_upgrade(int(op["id"])); b.buy_upgrade(int(op["id"]))
	check(b.stat(op, "downtime") < dt * 0.4 and is_equal_approx(b.stat(op, "process_factor"), 0.8), "11 operator downtime and processing time reduced")
	b.state.new_crusher(Vector3(0, 0, 0), 0)
	b.state.crushers[0]["input"] = 2
	b.state.clock_minutes = 600
	b.payroll_minute = 600
	b.operator_start(op, 0)
	check(is_equal_approx(float(b.state.crushers[0]["remaining"]), 18.0 * 0.8), "11 trained operator crushes in 14.4 s instead of 18 s")
	var clerk := b.hire("petra")
	b.buy_upgrade(int(clerk["id"])); b.buy_upgrade(int(clerk["id"])); b.buy_upgrade(int(clerk["id"]))
	b.authorized["crushed_stone"] = true
	b.state.storage["crushed_stone"] = 6
	money = b.state.money
	var sale := b.clerk_sell(clerk)
	check(int(sale["units"]) == 6 and b.state.money - money == int(floor(66 * 1.06)), "11 trained clerk sells 6 per transaction with a 6% bonus")
	var copy := make()
	copy.restore(JSON.parse_string(JSON.stringify(b.snapshot())))
	check(int(copy.employee(int(miner["id"]))["upgrade"]) == 3 and int(copy.stat(copy.employee(int(hauler["id"])), "carry")) == 9, "11 upgrades persist through save data")

func test_exploits() -> void:
	var b := make(100)
	b.state.clock_minutes = 480
	b.payroll_minute = 480
	var e := b.hire("rosa")
	advance(b, 30)
	var money := b.state.money
	b.tick(0.0); b.tick(0.0); b.tick(0.0)
	check(b.state.money == money, "14 repeated zero-length ticks never pay wages twice")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(b.snapshot()))
	var b2 := make(money)
	b2.state.clock_minutes = b.state.clock_minutes
	b2.restore(saved)
	b2.tick(0.0)
	check(b2.state.money == money and is_equal_approx(float(b2.employees[0]["owed"]), float(e["owed"])), "14 loading does not re-run or duplicate payroll")
	b.state.money = 0
	advance(b, 15)
	var owed := float(e["owed"])
	b.fire(int(e["id"]))
	check(b.outstanding_debt >= owed - 0.001 and owed > 0.0, "14 dismissing an unpaid worker keeps the wages as debt")
	check(b.hire("dmitri").is_empty() and b.hire_block_reason("dmitri").begins_with("Pay outstanding"), "14 cannot hire while wages are still owed")
	b.state.money = 100
	advance(b, 1)
	check(b.outstanding_debt == 0.0 and b.state.money == 100 - int(ceil(owed - 0.0001)), "14 outstanding wages are paid once funds exist")
	check(not b.hire("dmitri").is_empty(), "14 hiring possible again after debts are paid")
	var b3 := make(1000)
	var clerk := b3.hire("petra")
	b3.state.clock_minutes = 600
	b3.payroll_minute = 600
	b3.authorized["coal"] = true
	b3.state.storage["coal"] = 2
	var m := b3.state.money
	var sale := b3.clerk_sell(clerk)
	check(int(sale["units"]) == 2 and b3.state.money == m + 24 and b3.stock("coal") == 0, "14 clerk cannot sell more than the stock")
	check(int(b3.clerk_sell(clerk)["units"]) == 0 and b3.state.money == m + 24, "14 empty stock earns nothing")
	var fee_before := b3.state.money
	b3.fire(int(clerk["id"]))
	b3.hire("petra")
	check(b3.state.money <= fee_before - 15, "14 rehiring charges the fee again")

# ------------------------------------------------------------------ scene tests

func frames(game, n: int, until: Callable = Callable()) -> int:
	for i in range(n):
		await physics_frame
		if until.is_valid() and until.call():
			return i
	return n

func scene_tests() -> void:
	var packed := load("res://Main.tscn")
	var game = packed.instantiate()
	root.add_child(game)
	game.prog.stage = game.prog.stage_index("large") # Phase 5 stage gates (tested in test_phase5)
	await process_frame
	await physics_frame
	await physics_frame
	game.tutorial_visible = false
	check(game.nav_region.navigation_mesh.get_polygon_count() > 10, "6 runtime navigation mesh baked from quarry geometry")
	check(game.nav_ready(), "6 navigation map ready")
	game.state.money = 2000
	Engine.time_scale = 4.0
	# --- 13: manual mining and selling still work with the Phase 2 systems running
	game.player_mine("coal_mountain", -1, 14.0)
	var m: int = game.state.money
	check(game.state.sell("coal", 1) == 1 and game.state.money == m + 12, "13 manual mining and selling still work")
	# --- clerk walks to the station and sells authorized stock
	game.state.clock_minutes = 600.0 # 10:00
	game.business.payroll_minute = 600
	game.ui_hire("petra")
	var clerk_node = game.worker_nodes.values()[0]
	var clerk: Dictionary = game.business.employees[0]
	var track := {"last": clerk_node.global_position, "max": 0.0, "walked": 0.0}
	var start_pos: Vector3 = clerk_node.global_position
	var arrived := await frames(game, 1500, func():
		var d: float = clerk_node.global_position.distance_to(track["last"])
		track["max"] = maxf(track["max"], d)
		track["walked"] += d
		track["last"] = clerk_node.global_position
		return clerk_node._flat(clerk_node.global_position, Vector3(-7, 0, 10)) < 2.6)
	check(arrived < 1500 and start_pos.distance_to(Vector3(-7, 0, 10)) > 5.0, "6 clerk walks from the break area to the selling station (%d frames)" % arrived)
	check(track["max"] < 0.6 and track["walked"] > 4.0, "6 worker moves smoothly without teleporting (max step %.2f m, walked %.1f m)" % [track["max"], track["walked"]])
	game.state.storage["crushed_stone"] = 4
	game.business.authorized["crushed_stone"] = true
	m = game.state.money
	var rev0 := int(game.business.day_stats(game.business.current_day())["revenue"])
	await frames(game, 1500, func(): return int(game.state.storage["crushed_stone"]) < 4)
	check(int(game.state.storage["crushed_stone"]) == 1, "10 clerk in the world sells stock at the counter")
	check(int(game.business.day_stats(game.business.current_day())["revenue"]) - rev0 == 33 and game.state.money > m, "10 automated sale awards exactly $33")
	# --- miner: walks, strikes the deposit, picks up the pieces, delivers them to storage
	game.state.clock_minutes = 480.0
	game.business.payroll_minute = 480
	for id in game.ground_pieces.keys():
		game.ground_pieces[id].queue_free()
		game.ground_pieces.erase(id)
	game.state.storage["limestone"] = 0
	game.ui_hire("rosa")
	var miner: Dictionary = game.business.employees[1]
	game.business.set_shift(int(miner["id"]), 0, 1439)
	game.business.set_shift(int(clerk["id"]), 0, 1439)
	var mined := await frames(game, 6000, func(): return int(game.state.storage["limestone"]) >= 4)
	check(mined < 6000, "6/8 miner mines limestone and carries it to storage (%s)" % miner["task"])
	check(game.business.chain["mined"] and int(miner["stats"]["units_total"]) >= 4, "miner production recorded")
	check(game.business.carry_total(miner) == 0 or int(game.state.storage["limestone"]) >= 4, "miner delivered what it carried")
	# --- operator: consumes real hopper input and produces output
	game.state.new_crusher(Vector3(4, 0, 4), 0)
	game._create_crusher(game.state.crushers.size() - 1)
	game.business.compute_links()
	game._rebake_nav()
	game.state.crushers[0]["hopper"] = 4
	game.ui_hire("tomas")
	var op: Dictionary = game.business.employees[2]
	game.business.set_shift(int(op["id"]), 0, 1439)
	check(game.business.milestones["mechanized"] and game.business.conveyors_unlocked(), "milestone 2 unlocks conveyors")
	var cons := {"ok": true, "loaded": false}
	var done := await frames(game, 6000, func():
		var c: Dictionary = game.state.crushers[0]
		cons["ok"] = cons["ok"] and int(c["hopper"]) + int(c["input"]) + int(c["output"]) == 4
		cons["loaded"] = cons["loaded"] or int(c["input"]) > 0
		return int(c["output"]) == 4)
	check(done < 6000 and cons["loaded"], "8 operator loads, runs and completes the crusher (%s)" % op["task"])
	check(cons["ok"] and int(game.state.crushers[0]["hopper"]) == 0, "8 crusher consumed exactly the 4 limestone it was fed")
	# --- 7: blocked route prevents production, recovers when cleared
	game.state.new_crusher(Vector3(-4, 0, 3), 0)
	game._create_crusher(1)
	var walls := []
	for spec in [[Vector3(-4, 1, 0.6), Vector3(5, 2, 0.4)], [Vector3(-4, 1, 5.4), Vector3(5, 2, 0.4)], [Vector3(-6.3, 1, 3), Vector3(0.4, 2, 5.2)], [Vector3(-1.7, 1, 3), Vector3(0.4, 2, 5.2)]]:
		walls.append(game._solid(game.world, "Test wall", spec[0], spec[1], Color.RED))
	game.business.compute_links()
	game._rebake_nav()
	game.state.crushers[1]["hopper"] = 3
	game.ui_hire("hana")
	var op2: Dictionary = game.business.employees[3]
	game.business.set_shift(int(op2["id"]), 0, 1439)
	game.ui_assign(int(op2["id"]), {"crusher": 1})
	await frames(game, 600)
	check(str(op2["warning"]).begins_with("Cannot reach"), "7 unreachable workplace shows a warning (%s)" % op2["warning"])
	check(int(game.state.crushers[1]["hopper"]) == 3 and int(game.state.crushers[1]["input"]) == 0 and not game.state.crushers[1]["running"], "7 blocked route produces nothing")
	for w in walls:
		w.free()
	game._rebake_nav()
	var recovered := await frames(game, 3000, func(): return int(game.state.crushers[1]["hopper"]) < 3)
	check(recovered < 3000 and str(op2["warning"]) == "", "6 worker recalculates its path after the layout changes")
	# --- 12/14: save and load preserve everything without duplication
	game.business.add_output(Vector3(4, 0, 0.5), 0)
	game._create_output(0)
	game.business.outputs[0]["items"]["crushed_stone"] = 7
	game.business.add_conveyor(Vector3(10, 0, 7.5), 0)
	game._create_conveyor(0)
	game.business.compute_links()
	game.business.buy_upgrade(int(miner["id"]))
	game.business.authorized["coal"] = true
	game._save()
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.business.snapshot()))
	var money_saved: int = game.state.money
	var clock_saved: float = game.state.clock_minutes
	var crushers_saved := JSON.stringify(game.state.crushers)
	game.state.money = 99999
	game.ui_fire(int(miner["id"]))
	game.business.outputs[0]["items"]["crushed_stone"] = 0
	game.state.clock_minutes += 500
	game._load()
	var after: Dictionary = JSON.parse_string(JSON.stringify(game.business.snapshot()))
	var money_loaded: int = game.state.money
	var clock_loaded: float = game.state.clock_minutes
	var crushers_loaded := JSON.stringify(game.state.crushers)
	await process_frame
	for e in snap["employees"] + after["employees"]:
		e.erase("task")
		e.erase("warning")
	check(JSON.stringify(snap["employees"]) == JSON.stringify(after["employees"]), "12 employees, assignments, schedules, wages and upgrades restored")
	check(JSON.stringify(snap["outputs"]) == JSON.stringify(after["outputs"]) and JSON.stringify(snap["conveyors"]) == JSON.stringify(after["conveyors"]), "12 output storage and conveyors restored")
	check(snap["milestones"] == after["milestones"] and snap["authorized"] == after["authorized"] and snap["payroll_minute"] == after["payroll_minute"], "12 milestones, sales authorizations and payroll clock restored")
	check(money_loaded == money_saved and is_equal_approx(clock_loaded, clock_saved) and crushers_loaded == crushers_saved, "12 money, game time and production queues restored")
	check(game.worker_nodes.size() == 4 and game.output_nodes.size() == 1 and game.conveyor_nodes.size() == 1 and game.crusher_nodes.size() == 2, "12 world objects rebuilt once")
	game._load()
	var money_again: int = game.state.money
	await process_frame
	await process_frame
	check(game.workers_root.get_child_count() == 4 and game.output_nodes.size() == 1 and money_again == money_saved, "14 repeated load does not duplicate workers, structures or money")
	# --- milestone 3 and expansion
	for step in QuarryBusiness.CHAIN_STEPS:
		game.business.chain[step] = true
	game.business.auto_crushed_sold = game.business.sales_goal() # Phase 3 pacing goal
	game.business.check_milestones()
	check(game.business.milestones["automated"] and game.business.expansion_unlocked and game.deposit_nodes.has("limestone_east"), "milestone 3 opens the expansion with new deposits")
	check(game.expansion_gate[1].collision_layer == 0 and game.deposit_nodes.size() == 9, "expansion barrier removed; only the three existing minerals (+ quarry face + hillside)")
	await frames(game, 3)
	var pth: PackedVector3Array = NavigationServer3D.map_get_path(game.nav_map, Vector3(0, 0, 0), Vector3(38, 0, 0), true)
	check(pth.size() > 0 and Vector2(pth[pth.size() - 1].x, pth[pth.size() - 1].z).distance_to(Vector2(38, 0)) < 1.0, "expansion area is walkable for workers")
	# --- 12: Phase 1 save migration
	var v1 := {"version": 1, "money": 321, "inventory": {"limestone": 1, "coal": 0, "iron_ore": 0, "crushed_stone": 0}, "storage": {"limestone": 2, "coal": 0, "iron_ore": 0, "crushed_stone": 0}, "upgrades": {}, "clock_minutes": 700.0, "player_position": [0, 1, 8], "player_yaw": 0.0, "deposits": {}, "crushers": [{"position": [4, 0, 9], "yaw": 0.0, "input": 2, "output": 1, "running": false, "remaining": 0.0}], "pieces": []}
	var f := FileAccess.open("user://quarry_save.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(v1))
	f.close()
	game._load()
	await process_frame
	check(game.state.money == 321 and game.business.employees.is_empty() and game.worker_nodes.is_empty(), "12 Phase 1 save loads with an empty Phase 2 business")
	check(int(game.state.crushers[0]["hopper"]) == 0 and int(game.state.crushers[0]["input"]) == 2 and not game.business.expansion_unlocked and not game.deposit_nodes.has("limestone_east"), "12 Phase 1 machines migrate with safe defaults")
	Engine.time_scale = 1.0
	game.queue_free()
	await process_frame

## Acceptance: Miner -> Storage -> Hauler -> Crusher -> Output storage -> Sales clerk with no player input.
func chain_test() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.prog.stage = game.prog.stage_index("large") # Phase 5 stage gates (tested in test_phase5)
	await process_frame
	await physics_frame
	await physics_frame
	game.state.money = 3000
	Engine.time_scale = 4.0
	game.state.new_crusher(Vector3(2, 0, 3), 0)
	game._create_crusher(0)
	game.business.add_output(Vector3(2, 0, 0), 0)
	game._create_output(0)
	game.business.compute_links()
	game._rebake_nav()
	check(game.business.crusher_outputs[0] == 0, "output storage attached to the crusher chute")
	for cid in ["rosa", "bram", "tomas", "petra"]:
		game.ui_hire(cid)
	for e in game.business.employees:
		game.business.set_shift(int(e["id"]), 0, 1439)
	var hauler: Dictionary = game.business.employees[1]
	check(game.ui_assign(int(hauler["id"]), {"src": {"type": "storage"}, "dst": {"type": "crusher", "index": 0}}) == "Assignment updated", "hauler assigned storage -> crusher hopper")
	game.business.authorized["crushed_stone"] = true
	# Phase 3 pacing: milestone 3 needs 20 crushed stone sold by the clerk. Seed hand-mined
	# limestone in the crate so the test does not wait for five deposit regrowth cycles.
	game.state.storage["limestone"] = 24
	var start_money: int = game.state.money
	var f := await frames(game, 15000, func(): return game.business.milestones["automated"])
	var tasks := []
	for e in game.business.employees:
		tasks.append("%s: %s %s" % [e["name"], e["task"], e["warning"]])
	check(f < 15000, "full automated chain completes and unlocks the expansion (%d frames) %s" % [f, str(game.business.chain)])
	check(int(hauler["stats"]["units_total"]) > 0 and int(game.business.day_stats(game.business.current_day())["hauled"]) > 0, "hauler physically delivered limestone to the crusher %s" % str(tasks))
	check(game.deposit_nodes.has("coal_east") and game.state.money >= 0, "expansion deposits revealed; balance never negative")
	var paid := 0
	for e in game.business.employees:
		paid += int(e["stats"]["paid_total"])
	check(paid > 0, "staff were paid wages while the chain ran ($%d)" % paid)
	check(game.conveyor_valid(Vector3(10, 0, 7.5), 0) and not game.conveyor_valid(Vector3(10, 0, 10), 0), "conveyor placement allowed beside the crate, blocked through it")
	var link: Dictionary = game.business.link_for(Vector3(2, 0, 5.85), 0)
	check(link["dst"].get("type") == "crusher", "conveyor preview detects the crusher hopper")
	game._open_menu("manage")
	var built := true
	var widest := 0.0
	var frame: Control = game.management.get_child(0)
	for t in ["staff", "hire", "payroll", "production", "milestones"]:
		game.management._set_tab(t)
		await process_frame
		built = built and game.management.content.get_child_count() > 0
		widest = maxf(widest, frame.get_combined_minimum_size().x)
	check(widest <= 880.0, "management panel fits the 960x540 base canvas (1280x720 / 1920x1080) - widest %.0f px" % widest)
	check(built and game.management.visible, "management interface builds every tab")
	game._close_menu()
	check(not game.management.visible and game.menu == "", "management interface closes")
	Engine.time_scale = 1.0
	game.queue_free()
	await process_frame
