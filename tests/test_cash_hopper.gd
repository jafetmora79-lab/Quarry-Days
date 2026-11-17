extends SceneTree
## The Cash Hopper (it replaces the sales clerk): Grandpa's old hopper stands in the yard from the start; whatever is put in it (bag, cart, crate, belts) is sold one unit
## at a time at the tier's speed, each unit paid once from the game's one price table; belts and mergers feed it with backpressure; saves keep it mid-sale; the clerk is
## gone without breaking progression; older saves gain the hopper.
##   godot --headless --fixed-fps 60 -s tests/test_cash_hopper.gd

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

func make():
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	game.cash_hopper_enabled = true
	root.add_child(game)
	return game

func settle(game) -> void:
	await process_frame
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await process_frame

func stones(biz, st) -> int:
	var n: int = biz.conveyor_total()
	for c in st.crushers:
		n += int(c["output"])
	for o in biz.outputs:
		n += int(o["items"].get("crushed_stone", 0))
	return n

func run() -> void:
	var game = make()
	await settle(game)
	var st = game.state
	var biz = game.business
	# --- 1. the old hopper is there from the start, near the office, with all its attachment points
	var hs: Array = biz.cash_hopper_indices()
	check(hs.size() == 1, "a new game owns exactly one Cash Hopper (Grandpa's old one)")
	var h: int = hs[0]
	var hpos: Vector3 = QuarryBusiness.v3(biz.outputs[h]["position"])
	check(hpos.distance_to(game.OFFICE_POS) > 4.5 and hpos.distance_to(game.OFFICE_POS) < 9.0, "it stands near the office, clear of its door (%.1f m away)" % hpos.distance_to(game.OFFICE_POS))
	var body: Node = game.output_nodes[h]
	var view: Node = body.get_node_or_null("CashHopperView")
	var pts_ok := view != null
	if view != null:
		for k in ["Attach_Body", "Attach_InputFunnel", "Attach_Processor", "Attach_ConveyorIn", "Attach_RockSpawn", "Attach_Audio", "Attach_FloatText", "Attach_Display", "Pivot_Flywheel", "Pivot_Flap"]:
			pts_ok = pts_ok and view.get_node_or_null(k) != null
	check(pts_ok and str(body.get_meta("variant")) == "cash_hopper", "the machine is a collider plus a swappable view with every attachment point")
	check(biz.cash_rate(h) == 24.0 and biz.cash_tiers().size() == 3 and float(biz.cash_tiers()[1]["rate"]) == 48.0 and float(biz.cash_tiers()[2]["rate"]) == 96.0, "speeds come from data: 24, 48 and 96 units per second (a full bag sells in about a second)")
	# --- 2. deposit 100 units once; the hopper sells them over time, never instantly
	st.storage["crushed_stone"] = 100
	var m0: int = st.money
	var e0: int = st.earned
	var sold0: int = int(st.lifetime["sold"].get("crushed_stone", 0))
	var n: int = game.cash_deposit(h, [], true)
	check(n == 100 and biz.cash_queue(h) == 100 and int(st.storage["crushed_stone"]) == 0, "one action moved all 100 stone into the hopper")
	check(st.money == m0, "depositing pays nothing yet: the hopper has to sell it")
	var conserved := true
	for i in 10:
		biz.tick(0.1)
		if (st.money - m0) + biz.cash_queue(h) * 7 != 700:
			conserved = false
	check(biz.cash_queue(h) == 76 and st.money - m0 == 168, "after one second at 24 units/s: 24 sold, 76 waiting, $168 in (%d waiting, +$%d)" % [biz.cash_queue(h), st.money - m0])
	check(conserved, "at every step cash plus the value still waiting stays $700: no unit is lost or paid twice")
	for i in 90:
		biz.tick(1.0)
	check(biz.cash_queue(h) == 0 and st.money - m0 == 700 and st.earned - e0 == 700, "all 100 stone sold for exactly 100 x $7 (money +$%d, earned +$%d)" % [st.money - m0, st.earned - e0])
	check(int(st.lifetime["sold"].get("crushed_stone", 0)) - sold0 == 100 and biz.cash_today(h) == 700, "the sales history counts 100 units and $700 for today")
	# --- 3. several materials, different prices, dearest first, exact total
	st.inventory["gold_ore"] = 5
	st.inventory["copper_ore"] = 5
	st.inventory["limestone"] = 8
	st.inventory["crushed_stone"] = 0
	game.cash_deposit(h, [])
	check(biz.cash_queue(h) == 18 and st.total(st.inventory) == 0, "the bag was emptied into the hopper in one action")
	m0 = st.money
	biz.tick(0.05)
	check(biz.cash_current(h) == "gold_ore" and st.money - m0 == 80, "the dearest material sells first (gold ore, $80)")
	for i in 40:
		biz.tick(1.0)
	check(biz.cash_queue(h) == 0 and st.money - m0 == 5 * 80 + 5 * 34 + 8 * 3, "mixed load paid each material its own price: $%d" % (st.money - m0))
	# deposit selected: only the picked material goes
	st.inventory["coal"] = 4
	st.inventory["iron_ore"] = 3
	game.cash_sel = {"coal": true, "iron_ore": false}
	game.cash_deposit(h, ["coal"])
	check(int(st.inventory["coal"]) == 0 and int(st.inventory["iron_ore"]) == 3 and biz.outputs[h]["items"]["coal"] == 4, "DEPOSIT SELECTED moves only the picked material")
	for i in 10:
		biz.tick(1.0)
	st.inventory["iron_ore"] = 0
	# --- 4. no truck, no clerk: selling needs neither
	check(game.fleet.driving_id < 0 and not "clerk" in biz.PROFESSIONS, "all of that happened without a truck or a clerk")
	check(biz.available_candidates().filter(func(c): return str(c.get("profession", "")) == "clerk").is_empty(), "no sales clerk can be hired")
	# --- 5. speed tiers and the upgrade, kept by a save
	st.money = 5000
	check(biz.cash_upgrade_cost(h) == 900 and biz.cash_upgrade(h) and biz.cash_rate(h) == 48.0 and st.money == 4100, "upgrade to the Motorized Hopper costs $900 and runs at 48 units/s")
	biz.outputs[h]["items"]["limestone"] = 40
	m0 = st.money
	for i in 2:
		biz.tick(0.25)
	check(m0 + 24 * 3 == st.money and biz.cash_queue(h) == 16, "at 48 units/s half a second sells 24 units")
	# --- 6. save and load in the middle of a sale: nothing doubled, nothing lost
	biz.outputs[h]["items"]["gold_ore"] = 400
	biz.tick(0.5)
	var queue_before: int = biz.cash_queue(h)
	var value_before: int = 0
	for k in biz.outputs[h]["items"]:
		value_before += st.payout(k, int(biz.outputs[h]["items"][k]))
	var money_save: int = st.money
	var tier_before: int = biz.cash_tier_index(h)
	var prog_before: float = float(biz.outputs[h]["progress"])
	game._save(true)
	biz.tick(3.0)                                         # keeps selling after the save: the load must roll all of it back
	game._load(true)
	await process_frame                                   # no physics tick: at 48 units/s two frames would already sell a unit
	var h2: int = biz.cash_hopper_indices()[0]
	check(biz.cash_hopper_indices().size() == 1, "after loading there is still exactly one Cash Hopper")
	# the load rolls back the 3 s that were sold after the save; a physics tick may land before the check, and at 48 units/s one tick is up to a unit: so the queue and money are within one unit
	check(absf(float(st.money - money_save)) <= 80.0 and absi(biz.cash_queue(h2) - queue_before) <= 1 and biz.cash_tier_index(h2) == tier_before and absf(float(biz.outputs[h2]["progress"]) - prog_before) < 1.0, "money, queue, tier and processing progress come back exactly (money %d/%d, waiting %d/%d, tier %d/%d, progress %.3f/%.3f)" % [st.money, money_save, biz.cash_queue(h2), queue_before, biz.cash_tier_index(h2), tier_before, float(biz.outputs[h2]["progress"]), prog_before])
	for i in 30:
		biz.tick(1.0)
	check(biz.cash_queue(h2) == 0 and st.money == money_save + value_before, "finishing after a load pays exactly the value that was waiting (+$%d)" % (st.money - money_save))
	check(biz.cash_today(h2) > 0 and game.output_nodes[h2].get_node_or_null("CashHopperView") != null, "today's earnings survive and the machine is rebuilt with its view")
	# --- 7. feedback: floating cash and the machine display
	biz.outputs[h2]["items"]["gold_ore"] = 3
	biz.tick(1.0)
	var v2: Node = game.output_nodes[h2].get_node("CashHopperView")
	await frames(40)
	check(v2._live_floats >= 0 and str(v2.display.text).contains("TODAY") and str(v2.display.text).contains("WAITING"), "the machine's display shows what is selling, what waits, today's earnings and speed")
	# --- 8. Grandpa's short introduction
	game.prog.story["hopper_intro"] = false
	game._hopper_intro(h2)
	await frames(3)
	check(game.hud.card_open(), "the first visit brings up Grandpa's card about the hopper")
	game.hud.close_card()
	game.queue_free()
	await process_frame
	# --- 9. belts and a merger feed it: two crushers, backpressure, conservation
	var g2 = make()
	await settle(g2)
	st = g2.state
	biz = g2.business
	var origin := Vector3(40.0, 0.0, 40.0)
	st.new_crusher(origin + Vector3(4.2, 0, 0), PI * 0.5, 1)
	g2._create_crusher(st.crushers.size() - 1)
	st.new_crusher(origin + Vector3(-4.2, 0, 0), -PI * 0.5, 1)
	g2._create_crusher(st.crushers.size() - 1)
	var hi: int = biz.add_output(origin + Vector3(0, 0, -4.0), 0.0, "cash_hopper")
	g2._create_output(hi)
	var mg: int = biz.add_conveyor(origin, 0.0, "merger")
	g2._create_conveyor(mg)
	var o1: int = biz.add_conveyor(origin + Vector3(0, 0, -2.0), 0.0)
	g2._create_conveyor(o1)
	var ba: int = biz.add_conveyor(origin + Vector3(2, 0, 0), PI * 0.5)
	g2._create_conveyor(ba)
	var bb: int = biz.add_conveyor(origin + Vector3(-2, 0, 0), -PI * 0.5)
	g2._create_conveyor(bb)
	biz.compute_links()
	check(str(biz.links[o1]["dst"].get("type", "")) == "output" and int(biz.links[o1]["dst"]["index"]) == hi, "the belt line ends in the Cash Hopper")
	check(str(biz.links[ba]["resource"]) == "crushed_stone" and str(biz.links[bb]["resource"]) == "crushed_stone", "both crushers' belts carry crushed stone to it")
	var c1: int = int(biz.links[ba]["src"]["index"])
	var c2: int = int(biz.links[bb]["src"]["index"])
	st.crushers[c1]["output"] = 12
	st.crushers[c2]["output"] = 12
	m0 = st.money
	var ok_cons := true
	var t := 0.0
	var sold_units := 0
	while t < 600.0 and (stones(biz, st) > 0):
		biz.tick(0.1)
		t += 0.1
		sold_units = int(st.lifetime["sold"].get("crushed_stone", 0))
		if stones(biz, st) + (st.money - m0) / 7 != 24:
			ok_cons = false
	check(ok_cons, "at every moment stone in the system plus stone sold is 24: nothing created, nothing lost")
	check(st.money - m0 == 24 * 7 and stones(biz, st) == 0, "both crushers' 24 stones arrived through the merger and were all sold for $%d (%.0f s)" % [st.money - m0, t])
	check(biz.auto_crushed_sold >= 24 and biz.chain["sold"], "the automated-business goal counts the Cash Hopper's crushed-stone sales")
	# a full queue blocks the line without losing anything
	biz.outputs[hi]["items"]["crushed_stone"] = biz.output_capacity_of(hi) - 3
	st.crushers[c1]["output"] = 10
	st.crushers[c2]["output"] = 10
	var total_before: int = stones(biz, st)
	var blocked := false
	for i in 1200:
		biz.tick_conveyors(0.1)                              # production only: the hopper is not selling in this stretch
		for k in range(biz.conveyors.size()):
			if biz.belt_status(k) == "blocked":
				blocked = true
	check(stones(biz, st) == total_before and biz.cash_queue(hi) == biz.output_capacity_of(hi), "a full hopper stops the belts: its queue stops at capacity and nothing is lost (%d stones)" % total_before)
	check(blocked and (int(st.crushers[c1]["output"]) + int(st.crushers[c2]["output"])) > 0, "the belts report blocked and the crushers keep their finished stone")
	m0 = st.money
	var tt := 0.0
	while tt < 2000.0 and stones(biz, st) > 0:
		biz.tick(0.1)
		tt += 0.1
	check(stones(biz, st) == 0 and st.money - m0 == total_before * 7, "once it sells again the line drains completely: $%d for %d stones" % [st.money - m0, total_before])
	# --- 10. a belt from the storage crate brings whatever is stored, to a hopper, only because the player built that route
	var sp: Vector3 = biz.storage_pos * Vector3(1, 0, 1)
	var sbelt: int = biz.add_conveyor(sp + Vector3(0, 0, -2.0), 0.0)
	g2._create_conveyor(sbelt)
	biz.compute_links()
	var link: Dictionary = biz.links[sbelt]
	check(str(link["src"].get("type", "")) == "storage", "a belt placed at the crate is fed from it")
	var hs2: int = biz.add_output(sp + Vector3(0, 0, -4.0), 0.0, "cash_hopper")
	g2._create_output(hs2)
	biz.compute_links()
	check(str(biz.links[sbelt]["dst"].get("type", "")) == "output" and str(biz.links[sbelt]["resource"]) == "auto", "a belt from the crate to a Cash Hopper carries whatever the crate holds")
	biz.starter_feed = false                      # this scenario is about the belt the player built: the starter box's own automatic feed is off here
	var crate_before := {"gold_ore": 6, "limestone": 9}
	st.storage["gold_ore"] = 6
	st.storage["limestone"] = 9
	m0 = st.money
	var tc := 0.0
	while tc < 800.0 and (int(st.storage["gold_ore"]) + int(st.storage["limestone"]) + biz.conveyors[sbelt]["items"] + biz.cash_queue(hs2)) > 0:
		biz.tick(0.1)
		tc += 0.1
	check(int(st.storage["gold_ore"]) == 0 and int(st.storage["limestone"]) == 0 and st.money - m0 == 6 * 80 + 9 * 3, "the crate's stock rode the belt into the hopper and sold for exactly $%d (the crate sells only because the player built that belt)" % (st.money - m0))
	# --- 11. old saves: a business with no hopper gains Grandpa's; clerks in an old save are let go; progression survives
	var snap: Dictionary = JSON.parse_string(JSON.stringify(biz.snapshot()))
	snap["outputs"] = []
	snap["employees"] = [{"id": 1, "profession": "clerk", "name": "Petra Lind", "skill": 1, "upgrade": 0, "candidate": "petra", "owed": 1.0, "assignment": {"station": "sell"}}, {"id": 2, "profession": "hauler", "name": "Hana", "skill": 1, "upgrade": 0, "candidate": "hana", "assignment": {"src": {"type": "storage"}, "dst": {"type": "crusher", "index": 0}}}]
	snap["milestones"] = {"first_employee": true, "mechanized": true, "automated": false}
	biz.restore(snap)
	check(biz.employees.size() == 1 and str(biz.employees[0]["profession"]) == "hauler", "an old save's sales clerk is retired on load; the other employees stay")
	check(biz.milestones["first_employee"] and biz.milestones["mechanized"], "milestones already reached are kept")
	g2.output_nodes.clear()
	g2._ensure_cash_hopper(false)
	check(biz.cash_hopper_indices().size() == 1, "an old save without a hopper gets Grandpa's old one")
	# a save that holds a hopper and has no tier fields still loads (Phase-0 style record)
	var rec := {"position": [1.0, 0.0, 2.0], "yaw": 0.0, "items": {"limestone": 5}, "variant": "cash_hopper"}
	biz.restore({"outputs": [rec]})
	check(biz.cash_hopper_indices().size() == 1 and biz.cash_tier_index(0) == 0 and biz.cash_queue(0) == 5, "a hopper record without extras loads at the first tier with its queue")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
