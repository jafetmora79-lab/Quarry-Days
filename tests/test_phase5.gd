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
	await scene_mining()
	await scene_more()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

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
	s.money = 59
	check(not p.buy_next_tool() and s.tool_tier == 0 and s.money == 59, "2 cannot buy the pickaxe without $60; nothing charged")
	s.money = 60
	check(p.buy_next_tool() and s.tool_tier == 1 and s.money == 0 and p.can_mine("iron_ore"), "2 pickaxe bought for $60 and cracks iron")
	s.money = 100000
	while p.buy_next_tool():
		pass
	check(s.tool_tier == 4 and p.is_continuous() and p.can_mine("gold_ore") and p.next_tool().is_empty(), "2 tool line ends at the jackhammer, which works gold")
	check(not p.is_continuous(2) and p.is_continuous(3), "2 hand tools swing; the drill and jackhammer run continuously")
	s.upgrades["faster_mining"] = true
	check(is_equal_approx(p.tool_dps(4), float(p.tools()[4]["dps"]) * 1.25), "2 Mining Technique upgrade adds 25% speed to any tool")
	var st := QuarryState.new(cfg)
	check(st.restore({"version": 2, "money": 5, "inventory": {}, "storage": {}, "upgrades": {"reinforced_pickaxe": true}, "crushers": [], "deposits": {}, "player_position": [0, 1, 8], "clock_minutes": 480, "player_yaw": 0}) and st.tool_tier == 2, "2 older saves keep the reinforced pickaxe they bought")

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
	check(game.prog.story["intro_seen"] and not game.hud.card_open(), "11 the letter closes and is remembered")
	check(game.formation_nodes.size() == 3 and not game.formation_nodes.has("copper_vein"), "1 three starting formations are built; deep ones wait for the lower level")
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
	aim_at(game, Vector3(-10.0, 0.05, -3.6), Vector3(-10.0, 1.0, -7.2))
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
	game.state.money = 60
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
	check(game.ground_pieces.size() == pieces_saved and game.formation_nodes.size() == 3, "14 loose pieces and formation nodes rebuilt once")
	visible = 0
	for mi in node.chunks[col]:
		visible += 1 if mi.visible else 0
	check(visible == 0 and node.shapes[col].disabled, "14 an emptied column stays gone after loading")
	game._load()
	await process_frame
	check(game.ground_pieces.size() == pieces_saved and game.world.find_children("stone_mountain*", "", false, false).size() == 1, "14 repeated loads do not duplicate pieces or formations")
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
	# off shift -> resting at the break area
	game.business.set_shift(int(miner["id"]), 0, 30)
	game.state.clock_minutes = 600.0
	var rested := await frames(4000, func(): return w.anim == "rest")
	check(rested < 4000 and w._flat(w.global_position, game.break_spot(0)) < 1.0, "8 off shift, the worker walks to the break area and rests")
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
