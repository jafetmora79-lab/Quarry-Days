extends SceneTree
## Phase 5 tests: formations, tools, mining feedback, staff/machine extraction, processing, selling,
## stages, deep excavation, save/load. Accelerated, headless; no visual checks.
##   godot --headless --fixed-fps 60 -s tests/test_phase5.gd

var checks := 0
var failures := []
var cfg: Dictionary
var bcfg: Dictionary
var pcfg: Dictionary

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)
	else:
		print("PASS: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func frames(n: int, until: Callable = Callable()) -> int:
	for i in range(n):
		await physics_frame
		if until.is_valid() and until.call():
			return i
	return n

func run_tests() -> void:
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy.json"))
	bcfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/business.json"))
	pcfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
	test_formation_logic()
	test_tools()
	test_stages()
	test_balance()
	await scene_mining()
	await scene_more()
	await scene_deep()
	await scene_story_hud()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

## Live (not queued-for-deletion) world nodes of a script class.
func live(game, cls: String) -> int:
	var n := 0
	for c in game.world.get_children():
		if c.get_script() and c.get_script().get_global_name() == cls and not c.is_queued_for_deletion():
			n += 1
	return n

func fresh() -> QuarryProgression:
	var s := QuarryState.new(cfg)
	var b := QuarryBusiness.new(s, bcfg)
	var p := QuarryProgression.new(s, b, pcfg)
	for id in p.formation_ids():
		p.init_formation(id)
	return p

# ------------------------------------------------------------------ 1 mining and rock depletion (pure)

func test_formation_logic() -> void:
	var p := fresh()
	var stone := p.max_units("stone_mountain")
	check(stone >= 1000 and p.max_units("coal_mountain") >= 500 and p.max_units("iron_mountain") >= 400, "1 three enormous starting formations (stone %d, coal %d, iron %d units)" % [stone, p.max_units("coal_mountain"), p.max_units("iron_mountain")])
	check(p.units_left("stone_mountain") == stone and not p.state.deposits["stone_mountain"]["broken"], "1 formation starts full")
	var col := p.nearest_column("stone_mountain", Vector3(-10, 0, 0))
	check(col >= 0 and p.column_exposed("stone_mountain", col), "1 an exposed column faces the yard")
	var interior := 5 # centre of the 4x3 grid
	check(not p.column_exposed("stone_mountain", interior), "1 interior columns are covered until a neighbour is mined away")
	var ex := p.extract("stone_mountain", col, 25.0)
	check(int(ex["units"]) == 2 and p.units_left("stone_mountain") == stone - 2, "1 25 damage on 10-hp stone yields 2 units; the remainder carries over")
	ex = p.extract("stone_mountain", col, 5.0)
	check(int(ex["units"]) == 1, "1 damage carry-over completes the next unit")
	ex = p.extract("stone_mountain", col, 100.0, 0)
	check(int(ex["units"]) == 0 and float(p.state.deposits["stone_mountain"]["progress"]) < 10.0 and p.units_left("stone_mountain") == stone - 3, "1 no room: nothing is extracted and no damage is banked")
	var before_chunks := p.chunks_left("stone_mountain", col)
	ex = p.extract("stone_mountain", col, 10000.0)
	check(p.column_units("stone_mountain", col) == 0 and bool(ex["column_emptied"]) and int(ex["chunks"]) == before_chunks, "1 a column empties chunk by chunk and stops at zero")
	var neighbours_exposed := false
	for i in range(p.column_count("stone_mountain")):
		if p.column_units("stone_mountain", i) > 0 and p.column_exposed("stone_mountain", i):
			neighbours_exposed = true
	check(neighbours_exposed, "1 removing a column exposes new rock")
	var total := 0
	for i in range(p.column_count("coal_mountain")):
		total += int(p.extract("coal_mountain", i, 1e6)["units"])
	check(total == p.max_units("coal_mountain") and p.units_left("coal_mountain") == 0 and p.state.deposits["coal_mountain"]["cleared"], "1 a formation yields exactly its units, then is cleared")
	p.state.clock_minutes += 5000
	p.state.regrow_deposits()
	check(p.units_left("coal_mountain") == 0, "1 formations never regrow")
	check(p.cleared_fraction() > 0.2, "1 cleared fraction tracks the starting formations (%.2f)" % p.cleared_fraction())

# ------------------------------------------------------------------ 2 tool progression

func test_tools() -> void:
	var p := fresh()
	var s := p.state
	check(s.tool_tier == 0 and str(p.tool()["title"]) == "Rock Hammer", "2 new players start with grandpa's rock hammer")
	check(p.can_mine("limestone") and p.can_mine("coal") and not p.can_mine("iron_ore"), "2 the hammer works stone and coal but not iron")
	var last := 0.0
	var ok := true
	for t in range(p.tools().size()):
		ok = ok and p.tool_dps(t) > last * 1.25
		last = p.tool_dps(t)
	check(ok, "2 every tool tier mines at least 25% faster than the one before")
	check(p.tool_gain_percent(0, 1) >= 100, "2 the first upgrade feels meaningful (+%d%%)" % p.tool_gain_percent(0, 1))
	var pick := int(p.tools()[1]["cost"])
	s.money = pick - 1
	check(not p.buy_next_tool() and s.tool_tier == 0 and s.money == pick - 1, "2 cannot buy the pickaxe without $%d; nothing charged" % pick)
	s.money = pick
	check(p.buy_next_tool() and s.tool_tier == 1 and s.money == 0 and p.can_mine("iron_ore"), "2 pickaxe bought for $%d and cracks iron" % pick)
	s.money = 100000
	while p.buy_next_tool():
		pass
	check(s.tool_tier == 4 and p.is_continuous() and p.can_mine("gold_ore") and p.next_tool().is_empty(), "2 tool line ends at the jackhammer, which works gold")
	check(not p.is_continuous(2) and p.is_continuous(3), "2 hand tools swing; the drill and jackhammer run continuously")
	s.upgrades["faster_mining"] = true
	check(is_equal_approx(p.tool_dps(4), float(p.tools()[4]["dps"]) * 1.25), "2 Mining Technique upgrade adds 25% speed to any tool")
	var st := QuarryState.new(cfg)
	check(st.restore({"version": 2, "money": 5, "inventory": {}, "storage": {}, "upgrades": {"reinforced_pickaxe": true}, "crushers": [], "deposits": {}, "player_position": [0, 1, 8], "clock_minutes": 480, "player_yaw": 0}) and st.tool_tier == 2, "2 older saves keep the reinforced pickaxe they bought")

## 12 pacing estimates from the data (no real-time playthrough): mining rate, bag trips, walking.
func test_balance() -> void:
	var p := fresh()
	var hp := float(p.material("limestone")["hp"])
	var price := float(p.state.config["prices"]["limestone"])
	var trip := 12.0 # seconds: formation -> sales booth -> back
	var bag := float(p.state.capacity())
	var per_s := func(tier: int) -> float:
		var mine_t: float = bag / (p.tool_dps(tier) / hp)
		return bag * price / (mine_t + trip)
	var first: float = (float(p.tools()[1]["cost"]) - float(pcfg["new_game_money"])) / float(per_s.call(0))
	check(first > 20.0 and first < 180.0, "12 first pickaxe after about %.0f s of hand mining (meaningful, not a grind)" % first)
	var steps := []
	for t in range(1, p.tools().size() - 1):
		steps.append(float(p.tools()[t + 1]["cost"]) / float(per_s.call(t)))
	var ok := true
	for v in steps:
		ok = ok and v < 900.0
	check(ok, "12 each later tool is a few minutes of mining with the previous one (%s s)" % str(steps.map(func(v): return int(v))))
	var stone := float(p.max_units("stone_mountain"))
	var manual := stone / (p.tool_dps(1) / hp) / 60.0
	var jack := stone / (p.tool_dps(4) / hp) / 60.0
	check(manual > 8.0 and jack < manual / 5.0, "12 the stone formation is ~%.0f min of pickaxe work but ~%.1f min with the jackhammer" % [manual, jack])
	var value := 0.0
	for id in p.cfg["starting_formations"]:
		value += float(p.max_units(id)) * float(p.state.config["prices"][str(p.fdef(id)["resource"])])
	var deep_req := float(p.stage_info(p.stage_index("deep"))["req"]["earned"])
	check(value > deep_req + p.permit_cost(), "12 the starting formations ($%d raw) fund the deep stage and permit" % int(value))
	var rig := p.machine("drill_rig")
	var rig_income := float(rig["dps"]) / hp * price * 120.0 # per in-game hour (120 s)
	var rig_cost := float(rig["cost_per_min"]) * 60.0
	check(rig_income > rig_cost * 3.0, "12 a drilling rig earns well above its running cost ($%d vs $%d per in-game hour)" % [int(rig_income), int(rig_cost)])
	var wage := float(bcfg["candidates"][0]["wage"]) * float(bcfg["wage_scale"])
	check(wage >= 12.0, "12 wages stay meaningful ($%.0f/h for a junior miner)" % wage)

func test_stages() -> void:
	var p := fresh()
	check(p.stage == 0 and not p.unlocked("hire") and not p.unlocked("crusher"), "12 a new quarry starts at Manual Labor: no staff, no machinery")
	p.state.add_income(30, "sale")
	p.check_stages()
	check(p.stage == 1, "12 first sales open the Better Tools stage")
	p.state.add_income(400, "sale")
	p.check_stages()
	check(p.stage == 1, "12 the first employee needs a pickaxe as well as $350 earned")
	p.state.tool_tier = 1
	p.check_stages()
	check(p.stage == 2 and p.unlocked("hire") and not p.unlocked("crusher"), "12 First Employee stage unlocks hiring only")
	p.state.money = 1000
	p.business.hire("rosa")
	p.state.add_income(1000, "sale")
	p.check_stages()
	check(p.stage == 3 and p.unlocked("crusher") and p.unlocked("loader") and not p.unlocked("drill_rig"), "12 Early Industrialization unlocks crusher, storage and loader")
	check(p.business.hire_fee(p.business.candidate("rosa")) == 75 and is_equal_approx(p.business.wage(p.business.employees[0]), 18.0), "12 staff costs scale with the quarry (fee $75, wage $18/h)")
	var old := fresh()
	old.business.milestones["first_employee"] = true
	old.state.crushers.append({})
	old.restore({}, ["loader"])
	check(old.stage >= 3, "12 older saves start at the stage their equipment implies (never lower)")

# ------------------------------------------------------------------ in-game mining, feedback, selling, saving

func aim_at(game, pos: Vector3, look: Vector3) -> void:
	game.player.global_position = pos
	var d := look - (pos + Vector3(0, 1.58, 0))
	game.player.rotation.y = atan2(-d.x, -d.z)
	game.player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	game.player.camera.rotation.x = game.player.pitch

func scene_mining() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame
	game.tutorial_visible = false
	check(game.state.money == 10 and game.state.tool_tier == 0, "1 new game: $10 and the rock hammer")
	check(game.hud.card_open() and game.hud.card_title.text.contains("GRANDPA"), "11 a short introduction letter opens a new game")
	game.hud.close_card()
	await process_frame
	game.hud.close_card() # Phase 6.x: a second card ("your first day") follows the letter
	check(game.prog.story["intro_seen"] and not game.hud.card_open(), "11 the letter closes and is remembered")
	check(game.formation_nodes.size() == 5 and game.formation_nodes.has("hillside_face_01") and not game.formation_nodes.has("copper_vein"), "1 three starting formations plus the hillside are built; deep ones wait for the lower level")
	var node = game.formation_nodes["stone_mountain"]
	var stone0: int = game.prog.units_left("stone_mountain")
	# swing timing: damage only lands at the visible impact
	var tv = game.player.tool_view
	var hits := {"n": 0, "t": 0.0}
	var clock := {"t": 0.0}
	tv.swing(0.6, func(): hits["n"] += 1; hits["t"] = clock["t"])
	for i in range(12):
		clock["t"] += 0.05
		tv._process(0.05)
	check(hits["n"] == 1 and hits["t"] > 0.3 and hits["t"] < 0.4, "5 a swing calls its impact exactly once, at the strike moment (%.2fs of 0.6s)" % hits["t"])
	check(not tv.is_busy(), "5 the swing finishes and the tool returns to rest")
	# aim at the stone formation and swing for real
	aim_at(game, Vector3(-10.0, 0.05, -5.0), Vector3(-10.0, 1.0, -7.2))
	await frames(2)
	var ray: Dictionary = game._mining_ray()
	check(not ray.is_empty() and ray["node"] == node and int(ray["column"]) >= 0, "1 the crosshair ray resolves the formation column it hits")
	for i in range(3):
		game._on_swing_impact()
	check(int(game.state.inventory["limestone"]) == 1 and game.prog.units_left("stone_mountain") == stone0 - 1, "1 three hammer hits (4 dmg each) knock 1 stone out of 10 hp")
	check(game.hud.popups.get_child_count() >= 1 and game.hud.popups.get_child(0).text.contains("STONE"), "5 a '+1 STONE' pop-up appears")
	check(game.hud.dura_timer > 0.0, "9 the durability bar shows while mining")
	# hardness gate
	var iron0: int = game.prog.units_left("iron_mountain")
	check(game.player_mine("iron_mountain", -1, 100.0) == 0 and game.prog.units_left("iron_mountain") == iron0 and game.message.contains("Too hard"), "2 the hammer bounces off iron and says which tool is needed")
	# chunk depletion: a column loses chunks, then its collider
	var col := int(ray["column"])
	var chunks_before: int = game.prog.chunks_left("stone_mountain", col)
	game.state.tool_tier = 2
	game.state.upgrades["hauling_harness"] = true
	game.state.upgrades["larger_backpack"] = true
	var guard := 0
	while game.prog.column_units("stone_mountain", col) > 0 and guard < 50:
		for k in game.state.inventory:
			game.state.inventory[k] = 0
		game.player_mine("stone_mountain", col, 160.0)
		guard += 1
	await frames(40)
	var visible := 0
	for mi in node.chunks[col]:
		visible += 1 if mi.visible else 0
	check(chunks_before >= 2 and visible == 0 and node.shapes[col].disabled, "1 a mined-out column crumbles away chunk by chunk and its collider is removed")
	check(game.nav_dirty or game.nav_version > 1, "8 navigation is rebuilt when a column disappears")
	check(str(node.label.text).contains(str(game.prog.units_left("stone_mountain"))), "1 the formation label shows how much rock is left")
	# bag overflow drops loose pieces, capped, never lost
	for k in game.state.inventory:
		game.state.inventory[k] = 0
	game.state.inventory["coal"] = game.state.capacity()
	var loose0: int = game.loose_count("coal_mountain")
	var coal0: int = game.prog.units_left("coal_mountain")
	var got: int = game.player_mine("coal_mountain", -1, 14.0 * 5)
	check(got == 5 and game.loose_count("coal_mountain") == loose0 + 5 and game.prog.units_left("coal_mountain") == coal0 - 5, "1 with a full bag, mined coal drops beside the seam (5 pieces)")
	for i in range(30):
		game.player_mine("coal_mountain", -1, 14.0 * 5)
	var cap := int(game.prog.cfg["loose_piece_cap"])
	check(game.loose_count("coal_mountain") == cap and game.prog.units_left("coal_mountain") == coal0 - cap, "1 loose pieces stop at the cap and nothing more is extracted (no loss, no duplication)")
	# selling: confirmation, money, lifetime earnings
	for k in game.state.inventory:
		game.state.inventory[k] = 0
	game.state.inventory["limestone"] = 10
	game.state.inventory["coal"] = 2
	var m0: int = game.state.money
	var e0: int = game.state.earned
	var earned: int = game.sell_from_bag(game.RESOURCE_ORDER)
	check(earned == 10 * 5 + 2 * 12 and game.state.money == m0 + earned and game.state.earned == e0 + earned, "6 selling the bag pays $74 and counts toward lifetime earnings")
	check(game.hud.toast_queue.size() >= 1 and str(game.hud.toast_queue.back()[0]).contains("10 STONE"), "6 an animated sale confirmation is queued")
	for i in range(30):
		game.hud._process(0.1)
	check(int(round(game.hud.shown_money)) == game.state.money, "9 the money counter counts up to the real balance")
	# tool purchase through the upgrade board
	game.state.tool_tier = 0
	game.state.money = int(game.prog.tools()[1]["cost"])
	check(game.buy_next_tool() and game.state.tool_tier == 1 and game.state.money == 0, "2 the upgrade board sells the pickaxe")
	check(str(game.hud.toast_queue.back()[1]).begins_with("MINING POWER +"), "9 the upgrade shows its improvement (MINING POWER +%%)")
	# save / load: formations, tools, stage and pieces restored exactly once
	game.state.tool_tier = 2
	game.prog.stage = 2
	var cols_saved := JSON.stringify(game.state.deposits["stone_mountain"]["columns"])
	var pieces_saved: int = game.ground_pieces.size()
	game._save()
	game.player_mine("stone_mountain", -1, 500.0)
	game.state.tool_tier = 0
	game.prog.stage = 0
	game._load()
	await process_frame
	check(JSON.stringify(game.state.deposits["stone_mountain"]["columns"]) == cols_saved and game.state.tool_tier == 2 and game.prog.stage == 2, "14 excavation progress, tool and stage restored")
	check(game.ground_pieces.size() == pieces_saved and game.formation_nodes.size() == 5, "14 loose pieces and formation nodes rebuilt once")
	visible = 0
	for mi in node.chunks[col]:
		visible += 1 if mi.visible else 0
	check(visible == 0 and node.shapes[col].disabled, "14 an emptied column stays gone after loading")
	game._load()
	await process_frame
	check(game.ground_pieces.size() == pieces_saved and live(game, "QuarryFormation") == 4 and live(game, "QuarryArcFormation") == 1, "14 repeated loads do not duplicate pieces or formations")
	game.queue_free()
	await process_frame

func scene_more() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame
	game.hud.close_card()
	game.tutorial_visible = false
	game.prog.stage = game.prog.stage_index("large")
	game.state.money = 50000
	game.state.clock_minutes = 480.0
	game.business.payroll_minute = 480
	# ---- 3/8 a miner really works the formation, with matching animation
	game.ui_hire("rosa")
	var miner: Dictionary = game.business.employees[0]
	game.business.set_shift(int(miner["id"]), 0, 1439)
	var w = game.worker_nodes[int(miner["id"])]
	var seen := {}
	var stats := {"bad_face": 0, "empty": 0, "far": 0, "max_dv": 0.0, "float": 0.0, "strikes": 0, "strike_anim_ok": 0, "prev_anim": "", "prev_phase": 0.0}
	var d: Dictionary = game.state.deposits["stone_mountain"]
	var mined := {"v": int(d.get("mined", 0))}
	var last_v := {"v": Vector3.ZERO}
	Engine.time_scale = 4.0
	await frames(5000, func():
		seen[w.anim] = true
		if w.anim == "work":
			if absf(angle_difference(w.rotation.y, w.facing)) > 0.35:
				stats["bad_face"] += 1
			if w.mine_col >= 0 and game.prog.column_units(w.mine_dep, w.mine_col) <= 0:
				stats["empty"] += 1
			if w.mine_col >= 0 and w._flat(w.global_position, game.prog.column_pos(w.mine_dep, w.mine_col)) > float(game.prog.fdef(w.mine_dep)["cell"]) * 0.5 + 1.6:
				stats["far"] += 1
		var dv: float = Vector2(w.velocity.x - last_v["v"].x, w.velocity.z - last_v["v"].z).length() / (Engine.time_scale / 60.0)
		stats["max_dv"] = maxf(stats["max_dv"], dv)
		last_v["v"] = w.velocity
		if w.rig:
			stats["float"] = maxf(stats["float"], w.rig.skel.position.y)
		var now := int(d.get("mined", 0))
		if now > mined["v"]:
			stats["strikes"] += 1
			if stats["prev_anim"] == "work" and float(stats["prev_phase"]) > 0.85:
				stats["strike_anim_ok"] += 1
			mined["v"] = now
		stats["prev_anim"] = w.anim
		stats["prev_phase"] = w.anim_phase
		return int(game.state.storage["limestone"]) >= 8)
	check(int(game.state.storage["limestone"]) >= 8, "3 the first helper mines stone and delivers it to storage (%s)" % miner["task"])
	check(seen.has("walk") and seen.has("work") and seen.has("pickup") and seen.has("unload"), "8 miner animation states follow the job: %s" % str(seen.keys()))
	check(stats["strikes"] > 0 and stats["strike_anim_ok"] == stats["strikes"], "8 every rock extraction lands at the end of a visible swing (%d/%d)" % [stats["strike_anim_ok"], stats["strikes"]])
	check(stats["bad_face"] == 0 and stats["far"] == 0, "8 the miner faces the rock and stands at it while swinging")
	check(stats["empty"] == 0, "8 no swinging at an empty column")
	check(stats["max_dv"] < 12.0, "8 smooth acceleration: no velocity snaps (max %.1f m/s^2)" % stats["max_dv"])
	check(stats["float"] < 0.04, "8 feet stay on the ground (max hip lift %.3f m)" % stats["float"])
	# off shift -> walks out through the service gate and goes home
	game.business.set_shift(int(miner["id"]), 0, 30)
	game.state.clock_minutes = 600.0
	var rested := await frames(5000, func(): return bool(w.e.get("away", false)))
	check(rested < 5000 and not w.visible and w.collision_layer == 0, "8 off shift, the worker walks out through the gate and goes home (out of sight)")
	game.business.set_shift(int(miner["id"]), 0, 1439)
	var back := await frames(600, func(): return w.visible)
	check(back < 600 and not bool(w.e.get("away", true)) and w.collision_layer == 4, "8 and walks in through the gate again when the shift starts")
	Engine.time_scale = 1.0
	# ---- 4/7 crusher: real processing drives the animation
	game.state.new_crusher(Vector3(4, 0, 4), 0)
	game._create_crusher(game.state.crushers.size() - 1)
	var body = game.crusher_nodes[0]
	game.state.crushers[0]["input"] = 4
	await frames(30)
	check(float(body.get_meta("spin")) == 0.0 and not game.state.crushers[0]["running"], "7 an idle crusher does not animate")
	game.state.start_crusher(0)
	await frames(20)
	var spin1: float = float(body.get_meta("spin"))
	await frames(40)
	check(spin1 > 0.0 and spin1 < float(body.get_meta("spin")), "7 the crusher spins up smoothly when it starts (%.2f -> %.2f)" % [spin1, float(body.get_meta("spin"))])
	check(str(body.get_meta("label").text).begins_with("CRUSHING"), "7 the crusher label shows real run progress")
	game.state.crushers[0]["remaining"] = 0.01
	await frames(3)
	check(int(game.state.crushers[0]["output"]) == 4 and body.get_meta("output_pile").visible, "7 output appears in the chute pile when the run completes")
	await frames(20)
	check(float(body.get_meta("spin")) < 1.0 and float(body.get_meta("spin")) > 0.0, "7 the crusher spins down instead of stopping dead")
	# ---- conveyor belt only scrolls while carrying
	game.business.add_conveyor(Vector3(10, 0, 4), 0)
	game._create_conveyor(0)
	await frames(2)
	var belt = game.conveyor_nodes[0].get_meta("belt")
	check(belt.material_override != game.belt_mat_moving, "7 an empty belt stands still")
	game.business.conveyors[0]["items"] = 1
	game.business.conveyors[0]["resource"] = "limestone"
	await frames(2)
	check(belt.material_override == game.belt_mat_moving, "7 a loaded belt visibly moves")
	# ---- truck: bed lifts smoothly; cargo changes near the top of the lift
	game.business.milestones["mechanized"] = true
	game.business.milestones["automated"] = true
	check(game.ui_buy_vehicle("truck").ends_with("parking area."), "5 dump truck bought")
	game.delivery.finish_all()
	var truck = game.vehicle_nodes.values()[0]
	var rec: Dictionary = game.fleet.vehicle(truck.vehicle_id)
	game.fleet.add_cargo(rec, "limestone", 10)
	truck.global_position = game.business.storage_pos + Vector3(0, 0.05, -3.6)
	truck.rotation.y = 0.0
	await frames(5)
	var s0 := int(game.state.storage["limestone"])
	game.enter_vehicle(truck)
	game.vehicle_dump(truck)
	var tilt_at_transfer := {"v": -1.0}
	var steps := {"max": 0.0, "last": 0.0}
	await frames(200, func():
		steps["max"] = maxf(steps["max"], absf(truck.bed_tilt - steps["last"]))
		steps["last"] = truck.bed_tilt
		if tilt_at_transfer["v"] < 0.0 and int(game.state.storage["limestone"]) > s0:
			tilt_at_transfer["v"] = truck.bed_tilt
		return false)
	check(tilt_at_transfer["v"] > 0.8, "7 cargo leaves the truck once the bed is up (tilt %.2f)" % tilt_at_transfer["v"])
	check(steps["max"] < 0.03, "7 the bed lifts and lowers smoothly")
	game.exit_vehicle()
	game.queue_free()
	await process_frame

# ------------------------------------------------------------------ 4/7/9 machinery, deep excavation, saves

func scene_deep() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame
	game.hud.close_card()
	game.tutorial_visible = false
	var prog: QuarryProgression = game.prog
	game.state.money = 100000
	check(prog.rig_block_reason("drill_rig", "stone_mountain").begins_with("Unlocks"), "4 the drilling rig is locked before Large-Scale Mining")
	prog.stage = prog.stage_index("large")
	check(prog.rig_block_reason("drill_rig", "gold_seam") != "" and prog.permit_block_reason() != "", "6 deep formations and the permit wait for the Deep Excavation stage")
	# ---- 4 drilling rig extracts from the same formation units
	var stone0: int = prog.units_left("stone_mountain")
	var money0: int = game.state.money
	check(game.install_rig("drill_rig", "stone_mountain") and game.rig_nodes.size() == 1, "4 a drilling rig is installed on the stone formation's pad")
	check(game.state.money == money0 - int(prog.machine("drill_rig")["price"]), "4 the rig costs exactly its price")
	var r: Dictionary = prog.rigs[0]
	var rig = game.rig_nodes[0]
	game.state.money = 5000
	var m1: int = game.state.money
	await frames(900, func(): return prog.rig_bin_total(r) >= 10)
	var mined: int = stone0 - prog.units_left("stone_mountain")
	check(bool(r["working"]) and prog.rig_bin_total(r) >= 10 and mined == prog.rig_bin_total(r), "4 the rig drills real units into its bin (%d mined = %d in bin)" % [mined, prog.rig_bin_total(r)])
	check(game.state.money < m1, "4 the rig charges its operating cost while running ($%d)" % (m1 - game.state.money))
	check(rig.work > 0.5 and rig.audio.playing, "7 the rig visibly and audibly works while extracting")
	r["on"] = false
	await frames(120)
	check(not r["working"] and rig.work < 0.5, "7 a switched-off rig winds down and stops animating")
	r["on"] = true
	# collect into the bag through the rig panel
	for k in game.state.inventory:
		game.state.inventory[k] = 0
	game._open_menu("rig", 0)
	var inbin: int = prog.rig_bin_total(r)
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_1
	ev.keycode = KEY_1
	game._menu_key(ev)
	check(int(game.state.inventory["limestone"]) == mini(inbin, game.state.capacity()) and prog.rig_bin_total(r) == inbin - int(game.state.inventory["limestone"]), "4 collecting the rig bin moves units into the bag without loss")
	game._close_menu()
	# a full bin stops extraction (no overflow, no duplication)
	r["bin"] = {"limestone": prog.rig_bin_cap(r)}
	var before: int = prog.units_left("stone_mountain")
	await frames(60)
	check(prog.units_left("stone_mountain") == before and not r["working"] and str(r["status"]).contains("full"), "4 a full output bin pauses the rig")
	# hauler / conveyor endpoint
	var b: QuarryBusiness = game.business
	check(b.route_resource({"type": "rig", "index": 0}, {"type": "storage"}) == "limestone" and b.route_resource({"type": "rig", "index": 0}, {"type": "crusher", "index": 0}) == "limestone", "4 haulers can route rig output to storage or a crusher")
	var s0 := int(game.state.storage["limestone"])
	var took := b.ep_take({"type": "rig", "index": 0}, "limestone", 5)
	b.ep_put({"type": "storage"}, "limestone", took)
	check(took == 5 and int(game.state.storage["limestone"]) == s0 + 5 and prog.rig_bin_total(r) == prog.rig_bin_cap(r) - 5, "4 rig output moves through the shared endpoint system exactly")
	# ---- 5 advanced crusher processes faster with a bigger batch
	game.state.new_crusher(Vector3(4, 0, 4), 0)
	game.state.new_crusher(Vector3(-4, 0, 4), 0, 2)
	game._create_crusher(0)
	game._create_crusher(1)
	check(game.state.process_seconds(1) < game.state.process_seconds(0) * 0.5 and game.state.input_limit(1) == 2 * game.state.input_limit(0), "5 the advanced crusher runs twice as fast with twice the batch")
	game.state.inventory["limestone"] = 24
	check(game.state.load_crusher(1, 99) == 24 and game.state.start_crusher(1), "5 the advanced crusher takes a 24-stone batch")
	var t := 0.0
	while game.state.crushers[1]["running"] and t < 100.0:
		game.state.tick(0.5)
		t += 0.5
	check(int(game.state.crushers[1]["output"]) == 24 and t <= game.state.process_seconds(1) + 0.5, "5 it turns 24 stone into 24 gravel in %.1fs" % t)
	# ---- 6 deep excavation
	prog.stage = prog.stage_index("deep")
	game.state.money = 100000
	check(prog.permit_block_reason() == "" and game.buy_permit() and prog.level_unlocked == 2, "6 the excavation permit opens the lower level")
	check(game.formation_nodes.has("copper_vein") and game.formation_nodes.has("gold_seam") and game.excavation.is_open, "6 copper and gold formations appear on the lower level")
	check(game.excavation.cap.collision_layer == 0 and game.excavation.lower.collision_layer == 1 and game.excavation.ramp.collision_layer == 1, "6 the pit cap is removed; lower floor and ramp are solid")
	await frames(4)
	var pth: PackedVector3Array = NavigationServer3D.map_get_path(game.nav_map, Vector3(0, 0, 4), Vector3(2.5, -3.5, -11.5), true)
	check(pth.size() > 0 and pth[pth.size() - 1].y < -2.5 and Vector2(pth[pth.size() - 1].x, pth[pth.size() - 1].z).distance_to(Vector2(2.5, -11.5)) < 1.0, "8 staff can path down the ramp to the lower level")
	# the player walks down the ramp
	game.player.global_position = Vector3(-3.5, 0.1, -6.0)
	game.player.rotation.y = 0.0
	game.player.velocity = Vector3.ZERO
	Input.action_press("move_forward")
	await frames(240, func(): return game.player.global_position.z < -16.0)
	Input.action_release("move_forward")
	check(game.player.global_position.y < -3.0 and game.player.global_position.z < -15.0, "6 the player walks down the access ramp (%s)" % str(game.player.global_position))
	check(game.player_mine("copper_vein", -1, 1000.0) == 0, "2 copper is too hard for the reinforced pickaxe")
	game.state.tool_tier = 3
	for k in game.state.inventory:
		game.state.inventory[k] = 0
	check(game.player_mine("copper_vein", -1, 34.0 * 2) == 2 and int(game.state.inventory["copper_ore"]) == 2, "6 the power drill mines copper on the lower level")
	# a vehicle drives down the ramp
	game.business.milestones["mechanized"] = true
	game.ui_buy_vehicle("loader")
	game.delivery.finish_all()
	var loader = game.vehicle_nodes.values()[0]
	loader.global_position = Vector3(-3.5, 0.1, -4.0)
	loader.rotation.y = 0.0
	loader.speed = 0.0
	game.enter_vehicle(loader)
	game.scripted_input = true
	loader.input = {"throttle": 1.0, "steer": 0.0, "brake": false}
	await frames(400, func(): return loader.global_position.z < -15.0)
	loader.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
	check(loader.global_position.y < -2.5 and loader.global_position.z < -14.0, "6 the front loader drives down the ramp (%s)" % str(loader.global_position))
	await frames(20)
	game.exit_vehicle()
	# rock breaker on gold
	check(game.install_rig("rock_breaker", "gold_seam") and game.rig_nodes.size() == 2, "4 a rock breaker is installed against the gold seam")
	var gold0: int = prog.units_left("gold_seam")
	game.state.money = 5000
	await frames(900, func(): return prog.rig_bin_total(prog.rigs[1]) >= 2)
	check(prog.rig_bin_total(prog.rigs[1]) >= 2 and gold0 - prog.units_left("gold_seam") == prog.rig_bin_total(prog.rigs[1]), "4 the rock breaker hammers gold out of the seam")
	# ---- 14 save/load with the lower level, rigs and deep stock
	game._save()
	var snap := JSON.stringify(prog.snapshot()["rigs"])
	var gold_saved: int = prog.units_left("gold_seam")
	game.state.money = 1
	game._load()
	await process_frame
	await process_frame
	check(prog.level_unlocked == 2 and game.excavation.is_open and game.formation_nodes.has("gold_seam") and prog.units_left("gold_seam") == gold_saved, "14 the lower level, deep formations and their stock survive a load")
	check(prog.rigs.size() == 2 and game.rig_nodes.size() == 2 and live(game, "QuarryRig") == 2, "14 rigs reload once, with their bins (%d nodes)" % live(game, "QuarryRig"))
	var reloaded = JSON.parse_string(JSON.stringify(prog.snapshot()["rigs"]))
	var saved_r = JSON.parse_string(snap)
	check(int(reloaded[0]["bin"].get("limestone", 0)) == int(saved_r[0]["bin"].get("limestone", 0)), "14 rig bins restored exactly")
	game._load()
	await process_frame
	check(live(game, "QuarryRig") == 2 and live(game, "QuarryFormation") == 6 and live(game, "QuarryArcFormation") == 1, "14 repeated loads do not duplicate machines or formations")
	game.queue_free()
	await process_frame

# ------------------------------------------------------------------ 11 story discovery, 9 HUD layout

func scene_story_hud() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.hud.close_card()
	var prog: QuarryProgression = game.prog
	game.state.tool_tier = 4
	for i in range(prog.column_count("coal_mountain")):
		prog.extract("coal_mountain", i, 1e7)
	check(prog.units_left("coal_mountain") == 0 and prog.story["found"].get("first_clear", false) and game.discovery_nodes.has("first_clear"), "11 clearing the first formation reveals grandpa's lockbox")
	var box = game.discovery_nodes["first_clear"]
	game._close_menu()
	var m0: int = game.state.money
	game._interact(box)
	var reward := int(prog.discovery("first_clear")["reward"])
	check(game.hud.card_open() and game.hud.card_title.text == "GRANDPA'S LOCKBOX" and game.hud.card_body.text.contains("copper"), "11 the discovery card tells of the deeper minerals")
	check(game.state.money == m0 + reward and prog.story["read"]["first_clear"], "11 the old savings bond pays $%d once" % reward)
	game.hud.close_card()
	game._save()
	game._load()
	await process_frame
	check(not game.discovery_nodes.has("first_clear") and game.state.money == m0 + reward and prog.read_discovery("first_clear") == 0, "14 a read discovery stays read after loading (no second reward)")
	# HUD layout: panels inside the 960x540 canvas and not overlapping
	game.hud.set_prompt("LMB: mine Stone  -  Stone Formation  1110 / 1110 left")
	game.hud.set_message("Bag full! Sell at the booth or store at the crate. Extra rock drops beside the formation.")
	root.size = Vector2i(1280, 720) # headless windows start tiny; a 16:9 window gives the 960x540 canvas
	game.hud.refresh_panels()
	for i in range(10):
		await process_frame
	var rects := []
	for n in [game.hud.time_label.get_parent().get_parent(), game.hud.stage_label.get_parent().get_parent(), game.hud.tool_label.get_parent().get_parent().get_parent(), game.hud.prompt_panel]:
		rects.append(Rect2(n.get_global_rect()))
	var inside := true
	for r in rects:
		inside = inside and Rect2(0, 0, 960, 540).encloses(r)
	var overlap := false
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			overlap = overlap or rects[i].intersects(rects[j])
	check(inside and not overlap, "9 HUD panels fit the 960x540 base canvas without overlapping: %s" % str(rects))
	check(game.hud.money_label.get_theme_font("font") is FontFile and (game.hud.money_label.get_theme_font("font") as FontFile).antialiasing == TextServer.FONT_ANTIALIASING_GRAY, "9 the HUD body text uses the smooth UI font")
	game.queue_free()
	await process_frame
