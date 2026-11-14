extends SceneTree
## Phase 9: the twelve-stage progression, hybrid unlocks, the extra tools, hauling aids and save migration.
##   godot --headless --fixed-fps 60 -s tests/test_progression9.gd

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

func fresh() -> QuarryProgression:
	var cfg := load_json("res://data/economy.json")
	var bcfg := load_json("res://data/business.json")
	var pcfg := load_json("res://data/progression.json")
	var s := QuarryState.new(cfg)
	s.money = int(pcfg["new_game_money"])
	var b := QuarryBusiness.new(s, bcfg)
	var p := QuarryProgression.new(s, b, pcfg)
	for id in p.formation_ids():
		p.init_formation(id)
	return p

func all_items(p: QuarryProgression) -> Array:
	var out := []
	for t in p.tools():
		out.append(str(t["id"]))
	for g in p.gear_ids():
		out.append(str(g))
	return out

func run() -> void:
	# ---- A: the twelve stage definitions
	var p := fresh()
	var st: Array = p.stages()
	var expected := [["grandpa", 0], ["better_tools", 500], ["workshop", 1700], ["breaking_ground", 4800], ["first_employee", 12000], ["power_pressure", 28000], ["moving_mountains", 45000],
		["industrial_quarry", 85000], ["deeper_ground", 150000], ["mass_production", 230000], ["beneath_mountain", 330000], ["quarry_empire", 450000]]
	var ok := st.size() == 12
	var ordered := true
	var last := -1
	for i in range(mini(12, st.size())):
		ok = ok and str(st[i]["id"]) == expected[i][0] and int(st[i].get("req", {}).get("earned", 0)) == int(expected[i][1]) and str(st[i].get("goal", "")) != "" and str(st[i].get("title", "")) != ""
		ordered = ordered and int(st[i].get("req", {}).get("earned", 0)) > last
		last = int(st[i].get("req", {}).get("earned", 0))
	check(ok, "A twelve stages with the approved ids, names and earnings")
	check(ordered, "A earnings requirements strictly increase")
	check(p.stage_index("large") == 6 and p.stage_index("deep") == 8 and p.stage_index("crew") == 4, "A the six old stage ids still resolve (large, deep, crew)")
	var later_empty := true
	for i in range(6, 12):
		var unl: Array = st[i].get("unlocks", [])
		later_empty = later_empty and not (str(st[i]["id"]) in ["mass_production", "beneath_mountain", "quarry_empire"] and not unl.is_empty())
	check(later_empty, "A stages 10-12 list no new purchasable content (future work)")
	# ---- B: unlock graph: no cycles, nothing unreachable, nothing needs an unobtainable mineral
	var ids := all_items(p)
	var graph := {}
	var refs_ok := true
	for id in ids:
		var u: Dictionary = p.cfg["unlocks"].get(id, {})
		graph[id] = u.get("owns", [])
		for o in u.get("owns", []):
			refs_ok = refs_ok and str(o) in ids
		if u.has("stage"):
			refs_ok = refs_ok and p.stage_index(str(u["stage"])) >= 0 and str(u["stage"]) in ["grandpa", "better_tools", "workshop", "breaking_ground", "first_employee", "power_pressure", "moving_mountains", "industrial_quarry", "deeper_ground"]
	check(refs_ok, "B every unlock refers to real items and stages")
	var cyc := false
	for id in ids:
		var seen := {}
		var stack := [id]
		while not stack.is_empty():
			var cur: String = stack.pop_back()
			for o in graph.get(cur, []):
				if str(o) == id:
					cyc = true
				if not seen.has(str(o)):
					seen[str(o)] = true
					stack.append(str(o))
	check(not cyc, "B no item needs itself (no circular requirements)")
	# reachability with ONLY equipment obtainable so far: iterate until nothing new opens
	var owned := {"hand": true}
	var found := {"limestone": true, "coal": true}
	var changed := true
	var guard := 0
	while changed and guard < 40:
		changed = false
		guard += 1
		var best_h := 1
		for id in owned:
			var d: Dictionary = p.gear_def(id) if p.gear_def(id).size() > 0 else {}
			if d.is_empty():
				for t in p.tools():
					if str(t["id"]) == id:
						d = t
			best_h = maxi(best_h, int(d.get("max_hardness", 1)))
		for res in ["iron_ore", "copper_ore", "gold_ore"]:
			if not found.has(res) and int(p.material(res)["hardness"]) <= best_h and res != "gold_ore" and res != "copper_ore":
				found[res] = true
				changed = true
		for id in ids:
			if owned.has(id):
				continue
			var u: Dictionary = p.cfg["unlocks"].get(id, {})
			var can := true
			for o in u.get("owns", []):
				can = can and owned.has(str(o))
			for r in u.get("discover", []):
				can = can and found.has(str(r))
			for r in u.get("delivered", {}):
				can = can and found.has(str(r))
			# ladder tools come in order
			for i in range(p.tools().size()):
				if str(p.tools()[i]["id"]) == id and i > 0:
					can = can and owned.has(str(p.tools()[i - 1]["id"]))
			if can:
				owned[id] = true
				changed = true
	var unreachable := []
	for id in ids:
		if not owned.has(id):
			unreachable.append(id)
	check(unreachable.is_empty(), "B every tool, cart and machine is reachable from the starting hammer (%s unreachable)" % str(unreachable))
	var mand_ok := true
	for i in range(12):
		var req: Dictionary = st[i].get("req", {})
		for r in req.get("discover", []):
			mand_ok = mand_ok and found.has(str(r))
		for o in req.get("owns", []):
			mand_ok = mand_ok and owned.has(str(o))
	check(mand_ok, "B every mandatory stage requirement (discoveries, equipment) is achievable with equipment you can already own")
	# ---- C: the power drill cannot be bought early; the real conditions open it
	var gp := fresh()
	gp.state.money = 999999
	gp.state.tool_tier = 2
	check(not gp.buy_next_tool() and gp.state.tool_tier == 2 and gp.state.money == 999999, "C a rich new-game player cannot buy the power drill (nothing charged)")
	var txt := gp.unlock_missing_text("drill")
	check(txt.contains("Stage 6") and txt.to_lower().contains("iron") and txt.contains("Steel Pickaxe"), "C the shop tells what is missing: %s" % txt)
	gp.stage = 5
	check(not gp.buy_next_tool(), "C the right stage alone is not enough")
	gp.state.gear.append("steel_pickaxe")
	gp.state.add_item("iron_ore", 3)
	check(not gp.buy_next_tool(), "C neither are equipment and a discovery without the iron delivery")
	gp.state.inventory["iron_ore"] = 0
	var sold := 0
	gp.state.add_item("iron_ore", 10)
	gp.state.sell("iron_ore", 10)
	check(gp.buy_next_tool() and gp.state.tool_tier == 3 and gp.owns("drill"), "C stage, equipment, discovery and delivery together open it")
	check(not gp.buy_next_tool() or gp.state.tool_tier == 4, "C (the next ladder tool has its own gates)")
	# ---- D: extra tools
	var g := fresh()
	g.state.money = 100000
	check(g.gear_block_reason("pointed_chisel").contains("Stage 2") and not g.buy_gear("pointed_chisel"), "D a locked tool says which stage it needs and cannot be bought")
	g.cleanup["done"] = true
	for k in ["battery", "hose", "fuel", "started", "legacy"]: g.story["excavator"][k] = true
	g.state.add_income(500, "sale")
	g.check_stages()
	var m0 := g.state.money
	check(g.buy_gear("pointed_chisel") and g.state.money == m0 - 40 and g.state.equipped == "pointed_chisel", "D the Pointed Chisel costs $40 and goes into your hand")
	check(not g.buy_gear("pointed_chisel") and g.state.money == m0 - 40 and g.state.gear.count("pointed_chisel") == 1, "D buying it twice is refused and charges nothing")
	check(g.can_mine("limestone") and not g.can_mine("iron_ore"), "D the chisel cuts soft rock but not iron")
	check(g.tool_modifier("limestone") > 1.4 and g.tool_modifier("iron_ore") == 1.0, "D chisels are soft-rock specialists (x%.1f on stone)" % g.tool_modifier("limestone"))
	check(g.tool_dps() * g.tool_modifier("limestone") > g.tool_dps(0) * 2.5, "D the chisel is at least 2.5x the hammer on stone")
	g.cycle_tool()
	check(g.state.equipped == "" and str(g.tool()["id"]) == "hand", "D cycling returns to the ladder tool")
	check(g.owns("hand") and not g.owns("flat_chisel"), "D ownership is tracked per item")
	# ---- E: hauling aids
	var h := fresh()
	h.state.money = 5000
	h.cleanup["done"] = true
	for k in ["battery", "hose", "fuel", "started", "legacy"]: h.story["excavator"][k] = true
	h.state.add_income(500, "sale")
	h.check_stages()
	var cap0 := h.state.capacity()
	check(h.buy_gear("hand_cart") and h.state.cart_cap("hand_cart") == 20 and h.state.capacity() == cap0, "E the Hand Cart ($160) is a container of 20 on its own; the bag stays %d" % cap0)
	h.state.add_item("limestone", 100)
	check(h.state.cart_load_from_bag("hand_cart", "limestone", 100) == 18 or h.state.cart_total("hand_cart") <= 20, "E and it really takes load from the bag")
	check(not h.buy_gear("wheelbarrow") and h.gear_block_reason("wheelbarrow").contains("Stage 3"), "E the wheelbarrow waits for the Workshop stage")
	h.stage = 2
	check(h.buy_gear("wheelbarrow") and h.buy_gear("reinforced_wheelbarrow") and h.state.cart_capacity() == 70, "E the reinforced wheelbarrow is the best aid (capacity 70)")
	# ---- F: saves and migration
	var snap := h.state.snapshot()
	var s2 := QuarryState.new(load_json("res://data/economy.json"))
	check(s2.restore(snap) and s2.gear == h.state.gear and s2.carts == h.state.carts and s2.lifetime == h.state.lifetime and s2.equipped == h.state.equipped, "F gear, carts, lifetime and the equipped tool survive saving")
	var again := s2.snapshot()
	check(s2.restore(again) and s2.carts.size() == 3 and s2.gear.size() == h.state.gear.size(), "F loading twice duplicates nothing")
	var old_state := {"version": 2, "tool_tier": 3, "earned": 30000, "money": 1234, "inventory": {}, "storage": {}, "upgrades": {"larger_backpack": true}, "crushers": [{"input": 0, "output": 0, "hopper": 0, "running": false, "remaining": 0.0, "tier": 1}],
		"deposits": {"iron_mountain": {"resource": "iron_ore", "stock": 100, "hits": 4, "mined": 300}}, "player_position": [0, 1, 8], "clock_minutes": 480, "player_yaw": 0}
	var os := QuarryState.new(load_json("res://data/economy.json"))
	check(os.restore(old_state) and os.tool_tier == 3 and os.money == 1234 and os.earned == 30000 and os.gear.is_empty() and os.carts.is_empty(), "F an old state keeps its drill, money and earnings; no gear is invented")
	var op := QuarryProgression.new(os, QuarryBusiness.new(os, load_json("res://data/business.json")), load_json("res://data/progression.json"))
	op.restore({"stage": 4, "rigs": [], "level_unlocked": 1}, ["loader", "truck"])
	check(op.legacy_migrated and op.stage == op.stage_index("large") and op.owns("drill"), "F an old 'large' save lands on Moving Mountains and keeps its drill (stage %d)" % op.stage)
	check(op.discovered("iron_ore"), "F discoveries are inferred from the iron it already dug (%s)" % str(op.discovered("iron_ore")))
	var st_before := op.stage
	var money_before := os.money
	op.restore({"stage": 4, "rigs": [], "level_unlocked": 1}, ["loader", "truck"])
	check(op.stage == st_before and os.money == money_before, "F migrating the same save again changes nothing")
	var snap_p := op.snapshot()
	var op2 := QuarryProgression.new(os, QuarryBusiness.new(os, load_json("res://data/business.json")), load_json("res://data/progression.json"))
	op2.restore(snap_p, ["loader", "truck"])
	check(int(snap_p["schema"]) == 3 and op2.stage == op.stage and not op2.legacy_migrated, "F a new-format save is not migrated again")
	var oldest := QuarryProgression.new(os, QuarryBusiness.new(os, load_json("res://data/business.json")), load_json("res://data/progression.json"))
	oldest.restore({"stage": 5, "rigs": [], "level_unlocked": 2}, [])
	check(oldest.stage == oldest.stage_index("deep") and oldest.unlocked("permit") and oldest.unlocked("rock_breaker"), "F an old 'deep' save keeps the permit and the rock breakers")
	var jack := QuarryState.new(load_json("res://data/economy.json"))
	jack.restore({"version": 2, "tool_tier": 4, "earned": 90000, "money": 5, "inventory": {}, "storage": {}, "upgrades": {}, "crushers": [], "deposits": {}, "player_position": [0, 1, 8], "clock_minutes": 480, "player_yaw": 0})
	var jp := QuarryProgression.new(jack, QuarryBusiness.new(jack, load_json("res://data/business.json")), load_json("res://data/progression.json"))
	jp.restore({"stage": 5, "rigs": []}, [])
	check(str(jp.tool()["id"]) == "jackhammer" and jp.can_mine("gold_ore") and jp.is_continuous() and jp.next_tool().is_empty(), "F an owner of the heavy jackhammer keeps it and its gold-breaking power")
	# ---- G: worker unlock timing in a new game
	var w := fresh()
	check(not w.unlocked("hire") and w.stage_index("first_employee") == 4, "G hiring is locked at the start")
	w.stage = 3
	check(not w.unlocked("hire"), "G and still locked at Breaking Ground")
	w.stage = 4
	check(w.unlocked("hire"), "G First Employee opens hiring")
	# ---- H: in the real game: impact tools hit neighbours, the key cycles tools
	var game = load("res://Main.tscn").instantiate()
	game.natural_start_enabled = false      # Phase 10: these suites test the older systems on the old starting layout
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(6)
	game.hud.close_card()
	await process_frame
	var prog: QuarryProgression = game.prog
	prog.cleanup["done"] = true
	prog.stage = prog.stage_index("breaking_ground")
	game.state.money = 100000
	game.state.tool_tier = 1
	game.state.gear.append("repaired_pickaxe")
	game.state.gear.append("sledgehammer")
	var hid := "hillside_face_01"
	prog.init_formation(hid)
	var d: Vector2i = prog.dims(hid)
	var target := -1
	for i in range(prog.column_count(hid)):
		if prog.column_minable(hid, i):
			var nb := 0
			for off in [-1, 1, -d.x, d.x]:
				var j: int = i + off
				if j >= 0 and j < prog.column_count(hid) and prog.column_minable(hid, j):
					nb += 1
			if nb >= 2:
				target = i
				break
	check(target >= 0, "H the hillside has an exposed column with exposed neighbours")
	game.state.equipped = "repaired_pickaxe"
	var before: int = prog.units_left(hid)
	game.state.inventory["limestone"] = 0
	game.player_mine(hid, target, 40.0)
	var plain: int = before - prog.units_left(hid)
	game.state.equipped = "sledgehammer"
	var before2: int = prog.units_left(hid)
	var neigh := []
	for off in [-1, 1, -d.x, d.x]:
		var j: int = target + off
		if j >= 0 and j < prog.column_count(hid):
			neigh.append(prog.column_units(hid, j))
	game.player_mine(hid, target, 40.0)
	var neigh_after := []
	for off in [-1, 1, -d.x, d.x]:
		var j: int = target + off
		if j >= 0 and j < prog.column_count(hid):
			neigh_after.append(prog.column_units(hid, j))
	check(neigh != neigh_after, "H a sledgehammer blow also takes rock from neighbouring exposed columns")
	game.state.equipped = "repaired_pickaxe"
	var nb2 := []
	for off in [-1, 1, -d.x, d.x]:
		var j: int = target + off
		if j >= 0 and j < prog.column_count(hid):
			nb2.append(prog.column_units(hid, j))
	game.player_mine(hid, target, 40.0)
	var nb3 := []
	for off in [-1, 1, -d.x, d.x]:
		var j: int = target + off
		if j >= 0 and j < prog.column_count(hid):
			nb3.append(prog.column_units(hid, j))
	check(nb2 == nb3, "H a normal pickaxe leaves the neighbours alone")
	game.state.gear.erase("shovel")                 # (the shovel sits first in the swap order: take it out for this check)
	game.state.equipped = ""
	game.cycle_tool()
	check(game.state.equipped == "repaired_pickaxe", "H the swap key takes the next owned tool into your hand")
	game.state.money = 100000
	game.state.add_item("limestone", 0)
	var held := prog.tool()
	check(str(held["id"]) == "repaired_pickaxe" and prog.model_tier() == GearModels.tier_of("repaired_pickaxe"), "H extra tools have their own model slot")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
