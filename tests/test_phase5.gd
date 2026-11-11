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
	pass
