extends SceneTree
## Phase 9.3: a deterministic progression simulation. It plays the early game with the REAL rules (data files, unlock evaluator,
## purchases, stage checks) and a simple model of the player's work: mining rate from tool damage and rock hit points, bag size,
## trips to the sales booth, a hand-fed crusher, hired miners (damage, strike speed, walking, wages). Reports the time to each
## stage and asserts the pacing targets.
##   godot --headless -s tests/test_progression_sim.gd

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

func load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

const TRIP := 12.0              ## seconds: face -> sales booth -> back (the same figure test_phase5 uses)
const CLEANUP_AT := 300.0       ## the site is cleared after about five minutes of work
const FEED_SECONDS := 8.0       ## player time to load/collect one crusher batch

## strategy: "manual" (tools and carts first), "crew" (hires as soon as allowed), "processing" (crusher first)
func simulate(strategy: String, horizon := 14400.0, start_late := false) -> Dictionary:
	var cfg := load_json("res://data/economy.json")
	var bcfg := load_json("res://data/business.json")
	var pcfg := load_json("res://data/progression.json")
	var s := QuarryState.new(cfg)
	s.money = int(pcfg["new_game_money"])
	var b := QuarryBusiness.new(s, bcfg)
	var p := QuarryProgression.new(s, b, pcfg)
	var times := {}
	if start_late:
		s.tool_tier = 4
		s.earned = 120000
		s.money = 30000
		s.crushers.append({})
		p.cleanup["done"] = true
		p.restore({"stage": 5, "rigs": [], "level_unlocked": 2, "schema": 2, "cleanup": {"done": true}}, ["truck", "loader"])
		return {"stage": p.stage, "times": {5: 0.0}, "t": 0.0}
	var t := 0.0
	var carry := 0.0
	var crush_t := 0.0
	var gear_order := ["pointed_chisel", "hand_cart", "repaired_pickaxe", "flat_chisel", "sledgehammer", "wheelbarrow", "steel_pickaxe", "hardened_pickaxe", "reinforced_wheelbarrow", "hand_splitter", "air_compressor", "powered_hammer"]
	var upgrades := ["larger_backpack", "faster_mining", "expanded_storage"]
	var hired := 0
	var worker_cd := 0.0
	var hp := func(r: String) -> float: return float(p.material(r)["hp"])
	while t < horizon:
		t += 1.0
		if t >= CLEANUP_AT:
			p.cleanup["done"] = true
		# --- the player's work: the best $ per second among the rock the tool can break (stone, coal, iron are all in the yard)
		var best := 0.0
		var best_res := "limestone"
		var bag := float(s.capacity() + s.cart_capacity())     # the load per trip: the bag plus the best cart
		for res in ["limestone", "coal", "iron_ore"]:
			if not p.can_mine(res):
				continue
			var tool_dps: float = p.tool_dps() * p.tool_modifier(res)
			var aoe := p.tool_aoe()
			tool_dps *= 1.0 + aoe.x * aoe.y * 0.5        # neighbours on average half of the time at an exposed face
			var units_per_s: float = tool_dps / hp.call(res)
			var price := s.unit_price(res)
			if res == "limestone" and s.crushers.size() > 0 and strategy != "manual_nocrush":
				price = s.unit_price("crushed_stone")
				units_per_s = minf(units_per_s, float(cfg.get("crusher_input_limit", 12)) / float(cfg.get("crusher_seconds", 18)))
			var cycle: float = bag / units_per_s + TRIP
			if res == "limestone" and s.crushers.size() > 0 and strategy != "manual_nocrush":
				cycle += FEED_SECONDS * bag / float(cfg.get("crusher_input_limit", 12))     # loading and collecting the batches
			var rate := bag * price / cycle
			if rate > best:
				best = rate
				best_res = res
				carry += best
		if OS.get_environment("SIMDBG") == strategy and int(t) % 900 == 0:
			print("  t=%d earned=%d money=%d best=%s %.4f tool=%s eq=%s crushers=%d stage=%d mult=%.3f emp=%d" % [int(t), s.earned, s.money, best_res, best, str(p.tool()["id"]), s.equipped, s.crushers.size(), p.stage, s.price_mult, b.employees.size()])
		# --- hired miners: the real crew damage and strike interval, walking and carrying (limestone from the yard stone formation)
		for e in b.employees:
			if str(e["profession"]) == "miner":
				var hits := b.stat(e, "hits")
				var dmg := p.crew_damage(hits, b.stat(e, "yield"))
				var load_n := b.stat(e, "carry")
				var mine_t: float = load_n * hp.call("limestone") / dmg * b.stat(e, "strike_interval")
				var cycle_w: float = mine_t + 2.0 * 20.0 / b.stat(e, "speed") + load_n * b.stat(e, "pickup_seconds")
				carry += load_n * s.unit_price("limestone") / cycle_w
				s.note_lifetime("mined", "limestone", 0)
		# wages (an in-game hour is 120 real seconds)
		for e in b.employees:
			carry -= b.wage(e) / 120.0
		if carry >= 1.0:
			var whole := int(floor(carry))
			carry -= float(whole)
			s.add_income(whole, "sale")
			var units := int(round(float(whole) / maxf(0.1, s.unit_price(best_res))))
			s.note_lifetime("sold", best_res, units)
			s.note_lifetime("mined", best_res, units)
			if best_res == "limestone" and s.crushers.size() > 0:
				s.note_lifetime("sold", "crushed_stone", units)
		elif carry < 0.0 and s.money > 0:
			var due := int(ceil(-carry))
			s.money = maxi(0, s.money - due)
			carry += float(due)
		# the player also runs the crusher once for the Power and Pressure delivery (30 crushed stone, about a minute of feeding)
		if s.crushers.size() > 0 and int(s.lifetime["sold"].get("crushed_stone", 0)) < 30 and int(t) % 26 == 0:
			s.note_lifetime("sold", "crushed_stone", 12)
		# --- purchases, in the strategy's order, using the real unlock rules
		if int(t) % 5 == 0:
			p.check_stages()
			for k in upgrades:
				if not s.upgrades[k] and s.money >= int(cfg["upgrades"][k]) and p.stage >= 1:
					if k == "larger_backpack" or s.earned > 400:
						s.buy_upgrade(k)
			var wants := []
			if strategy == "processing":
				wants.append("crusher")
				wants.append("hire")
			if strategy == "crew":
				wants.append("hire")
			if p.stage >= p.stage_index("breaking_ground") and strategy != "processing":
				wants.append("crusher")      # a stage requirement: every player buys it as soon as it opens, tools come after
			wants.append("ladder")
			for g in gear_order:
				wants.append(g)
			wants.append("crusher")
			wants.append("hire")
			for wnt in wants:
				var saving := false         # an unlocked item the player cannot afford yet: they save for it instead of spending on lesser things
				match wnt:
					"ladder":
						if not p.next_tool().is_empty() and p.unlocked(str(p.next_tool()["id"])):
							if s.money >= int(p.next_tool()["cost"]):
								p.buy_next_tool()
							elif int(p.next_tool()["cost"]) < s.money * 4:
								saving = true
					"crusher":
						if s.crushers.is_empty() and p.unlocked("crusher"):
							if s.money >= int(cfg["crusher_price"]):
								s.buy_crusher()
								s.crushers.append({})
							else:
								saving = true          # it is the next goal (and a stage requirement): the player saves for it
					"hire":
						if hired < 2 and p.unlocked("hire") and hired < 1 + (1 if strategy == "crew" else 0):
							var cand := "rosa" if hired == 0 else "dmitri"
							if b.hire_block_reason(cand) == "" and s.money >= b.hire_fee(b.candidate(cand)) + 100:
								b.hire(cand)
								hired += 1
							elif s.money < b.hire_fee(b.candidate(cand)) + 100:
								saving = true
					_:
						var why: String = p.gear_block_reason(str(wnt))
						if why == "":
							p.buy_gear(str(wnt))
						elif why.begins_with("Need $") and int(p.gear_def(str(wnt))["cost"]) < s.money * 4:
							saving = true
				if saving:
					break
			# one trade-off the player makes: keep the best specialist tool in hand (soft rock chisels vs iron picks)
			var best_hold := ""
			var best_val := p.tool_dps() * 1.0
			for id in p.held_options():
				s.equipped = id
				var v := p.tool_dps() * maxf(p.tool_modifier("limestone"), p.tool_modifier("coal")) if p.can_mine("coal") else 0.0
				var vi := p.tool_dps() * p.tool_modifier("iron_ore") if p.can_mine("iron_ore") else 0.0
				v = maxf(v * 0.5, vi) if p.can_mine("iron_ore") else v
				if v > best_val:
					best_val = v
					best_hold = id
			s.equipped = best_hold
			p.check_stages()
			for i in range(1, 12):
				if p.stage >= i and not times.has(i):
					times[i] = t
		if p.stage >= 5 and strategy != "full":
			break
	return {"stage": p.stage, "times": times, "t": t, "money": s.money, "earned": s.earned, "tool": str(p.tool()["id"]), "hired": hired}

func run() -> void:
	var results := {}
	for strat in ["manual", "crew", "processing"]:
		var r: Dictionary = simulate(strat)
		results[strat] = r
		var parts := []
		for i in range(1, 6):
			parts.append("S%d %s" % [i + 1, ("%.0f min" % (float(r["times"].get(i, -1.0)) / 60.0)) if r["times"].has(i) else "not reached"])
		print("SIM %-10s reached stage %d | %s | tool %s hired %d earned %d money %d" % [strat, int(r["stage"]) + 1, "  ".join(parts), str(r.get("tool", "")), int(r.get("hired", 0)), int(r.get("earned", 0)), int(r.get("money", 0))])
	var late := simulate("late", 100.0, true)
	print("SIM late-game save: starts at stage %d, power tools reached at %.0f min" % [int(late["stage"]) + 1, 0.0])
	for strat in results:
		var r: Dictionary = results[strat]
		check(r["times"].has(5), "%s player reaches Power and Pressure (stage 6)" % strat)
		if r["times"].has(5):
			var mins := float(r["times"][5]) / 60.0
			check(mins >= 110.0 and mins <= 200.0, "%s player needs about 2 to 3.3 hours for stages 1-5 and reaches Power and Pressure (%.0f min)" % [strat, mins])
	check(int(late["stage"]) >= 5, "an existing late-game save is already past Power and Pressure")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
