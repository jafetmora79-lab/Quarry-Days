extends RefCounted
class_name PurchaseOffers
## Phase 8.4: turns an item of the shop (a vehicle, a tool, a machine) into the offer the purchase window shows: title, price,
## the model to turn, its important numbers and how it compares with what you already own. Numbers come from the same data the
## game plays with; nothing is invented here.

const HARDNESS := ["", "Stone and coal", "Up to iron", "Up to copper", "Anything, gold too"]

static func _row(label: String, value: String) -> Array:
	return [label, value]

static func _cmp(text: String, tone: String) -> Array:
	return [text, tone]

static func vehicle(game, type: String, on_buy: Callable) -> Dictionary:
	var f: QuarryFleet = game.fleet
	var sp: Dictionary = f.spec(type)
	var kind := f.kind(type)
	var stats := [_row("Cargo", "%d units" % int(sp["capacity"])),
		_row("Top speed", "%s  (%.1f m/s)" % [str(sp.get("speed_label", "")), float(sp["max_speed"])]),
		_row("Acceleration", str(sp.get("accel_label", "")))]
	if kind == "excavator":
		stats.append(_row("Digging", "%.0f damage a second, %s, reach %.1f m" % [float(sp.get("dig_dps", 0)), HARDNESS[clampi(int(sp.get("dig_hardness", 1)), 0, 4)].to_lower(), float(sp.get("dig_reach", 0))]))
	stats.append(_row("Best use", str(sp.get("best_use", ""))))
	var compare := []
	var best: Dictionary = {}
	for v in f.vehicles:
		if f.kind(str(v["type"])) == kind and (best.is_empty() or f.capacity(v) > f.capacity(best)):
			best = v
	if not best.is_empty():
		var diff := int(sp["capacity"]) - f.capacity(best)
		compare.append(_cmp("Your %s carries %d: this one carries %s%d %s" % [str(best.get("name", "machine")), f.capacity(best), "+" if diff >= 0 else "", diff, "more" if diff >= 0 else "fewer"], "good" if diff > 0 else ("bad" if diff < 0 else "flat")))
	else:
		compare.append(_cmp("You do not own a %s yet." % ("truck" if kind == "truck" else ("excavator" if kind == "excavator" else "loader")), "flat"))
	var reason := ""
	if not game.prog.unlocked(type):
		reason = "Unlocks at the %s stage" % game.prog.feature_stage_title(type)
	else:
		reason = f.buy_block_reason(type)
	return {"title": str(sp["title"]), "price": int(sp["price"]), "model": {"kind": "vehicle", "type": type}, "stats": stats, "compare": compare,
		"reason": reason, "on_buy": on_buy, "owned": _owned(f, type)}

static func _owned(f: QuarryFleet, type: String) -> int:
	var n := 0
	for v in f.vehicles:
		if str(v["type"]) == type:
			n += 1
	return n

static func tool_next(game, on_buy: Callable) -> Dictionary:
	var prog: QuarryProgression = game.prog
	var nt := prog.next_tool()
	if nt.is_empty():
		return {}
	var nxt: int = game.state.tool_tier + 1
	var stats := []
	if prog.is_continuous(nxt):
		stats.append(_row("Mining power", "%.0f damage a second, held down" % prog.tool_dps(nxt)))
	else:
		stats.append(_row("Mining power", "%.0f damage a swing" % prog.tool_power(nxt)))
		stats.append(_row("Swing speed", "%.1f swings a second" % (1.0 / prog.tool_interval(nxt) * prog.speed_mult())))
	stats.append(_row("Hardest rock", HARDNESS[clampi(int(nt.get("max_hardness", 1)), 0, 4)]))
	stats.append(_row("About", str(nt.get("desc", ""))))
	var cur: Dictionary = prog.tool()
	var gain := prog.tool_gain_percent(game.state.tool_tier, nxt)
	var compare := [_cmp("Mining power %.0f -> %.0f damage a second  (+%d%%)" % [prog.tool_dps(game.state.tool_tier), prog.tool_dps(nxt), gain], "good")]
	if int(nt.get("max_hardness", 1)) > int(cur.get("max_hardness", 1)):
		compare.append(_cmp("Breaks harder rock than your %s" % str(cur["title"]).to_lower(), "good"))
	var reason := prog.unlock_missing_text(str(nt["id"]))
	if reason == "" and game.state.money < int(nt["cost"]):
		reason = "Need %s more" % QuarryTheme.money_text(int(nt["cost"]) - game.state.money)
	return {"title": str(nt["title"]), "price": int(nt["cost"]), "model": {"kind": "tool", "tier": nxt}, "stats": stats, "compare": compare, "reason": reason, "on_buy": on_buy, "owned": 0}

## Stationary machines and rigs. key: crusher, output, conveyor, conveyor_left, conveyor_right, advanced_crusher, or a rig type.
static func machine(game, key: String, on_buy: Callable) -> Dictionary:
	var prog: QuarryProgression = game.prog
	var biz: QuarryBusiness = game.business
	var cfg: Dictionary = game.state.config
	var stats := []
	var compare := []
	var title := ""
	var price := 0
	var model := {}
	var reason := ""
	match key:
		"crusher":
			title = "Stone Crusher"
			price = int(cfg["crusher_price"])
			model = {"kind": "crusher", "tier": 1}
			stats = [_row("Crushes", "limestone into gravel"), _row("Batch", "%d stone every %d seconds" % [int(cfg.get("crusher_input_limit", 12)), int(cfg.get("crusher_seconds", 18))]),
				_row("Needs", "an operator, a hopper feed and an output storage")]
			compare = [_cmp("You own %d crusher%s." % [game.state.crushers.size(), "" if game.state.crushers.size() == 1 else "s"], "flat")]
		"advanced_crusher":
			var am := prog.machine("advanced_crusher")
			title = "Advanced Crusher"
			price = int(am["price"])
			model = {"kind": "crusher", "tier": 2}
			stats = [_row("Batch", "%d stone every %.0f seconds" % [int(cfg.get("crusher_input_limit", 12)) * int(am.get("capacity_mult", 2)), float(cfg.get("crusher_seconds", 18)) * float(am.get("speed_mult", 0.45))]),
				_row("Compared with the normal crusher", "double the batch in under half the time")]
			compare = [_cmp("About %.1fx the output of a stone crusher" % (float(am.get("capacity_mult", 2)) / float(am.get("speed_mult", 0.45))), "good")]
			if not prog.unlocked("advanced_crusher"):
				reason = "Unlocks at the %s stage" % prog.feature_stage_title("advanced_crusher")
		"output":
			title = "Output Storage"
			price = int(biz.cfg["output_storage_price"])
			model = {"kind": "output"}
			stats = [_row("Holds", "%d crushed stone" % biz.output_capacity()), _row("Fed by", "a crusher chute or a conveyor belt")]
			compare = [_cmp("You own %d." % biz.outputs.size(), "flat")]
		"conveyor", "conveyor_left", "conveyor_right":
			var bk := "straight" if key == "conveyor" else ("left" if key == "conveyor_left" else "right")
			title = {"straight": "Conveyor, Straight", "left": "Conveyor, Left Corner", "right": "Conveyor, Right Corner"}[bk]
			price = int(biz.cfg["conveyor_price"])
			model = {"kind": "conveyor", "belt": bk}
			stats = [_row("Speed", "%.1f items a second" % float(biz.cfg.get("conveyor_rate", 0.5))), _row("Holds", "%d items" % int(biz.cfg.get("conveyor_capacity", 3))),
				_row("Shape", "a 2 m belt" if bk == "straight" else "turns the material 90 degrees to the %s" % bk), _row("Connects", "snaps onto machine ports")]
			compare = [_cmp("You own %d belt%s." % [biz.conveyors.size(), "" if biz.conveyors.size() == 1 else "s"], "flat")]
			if not biz.conveyors_unlocked():
				reason = "Needs a crusher and an operator"
		_:
			var m := prog.machine(key)
			if m.is_empty():
				return {}
			title = str(m["title"])
			price = int(m["price"])
			model = {"kind": "rig", "type": key}
			var kind_text := "drilling rig" if str(m.get("kind", "drill")) == "drill" else "rock breaker"
			stats = [_row("Cutting", "%.0f damage a second" % float(m["dps"])), _row("Hardest rock", HARDNESS[clampi(int(m["max_hardness"]), 0, 4)]),
				_row("Output bin", "%d units" % int(m.get("bin", 40))), _row("Running cost", "$%.1f a minute" % float(m.get("cost_per_min", 0))), _row("Works", "from a drilling pad at the rock face")]
			var best := 0.0
			for r in prog.rigs:
				best = maxf(best, prog.rig_dps(r))
			if best > 0.0:
				var ratio := float(m["dps"]) / best
				compare = [_cmp("Your best rig cuts %.0f a second: this %s cuts %s" % [best, kind_text, ("%.1fx as fast" % ratio) if ratio >= 1.0 else ("%.0f%% as fast" % (ratio * 100.0))], "good" if ratio > 1.0 else "bad")]
			else:
				compare = [_cmp("You have no %s yet." % kind_text, "flat")]
			if not prog.unlocked(key):
				reason = "Unlocks at the %s stage" % prog.feature_stage_title(key)
	if reason == "" and game.state.money < price:
		reason = "Need %s more" % QuarryTheme.money_text(price - game.state.money)
	return {"title": title, "price": price, "model": model, "stats": stats, "compare": compare, "reason": reason, "on_buy": on_buy, "owned": 0}

## The tool in your hand when there is nothing left to buy.
static func tool_owned(game) -> Dictionary:
	var prog: QuarryProgression = game.prog
	var t: Dictionary = prog.tool()
	var tier: int = game.state.tool_tier
	var stats := []
	if prog.is_continuous(tier):
		stats.append(_row("Mining power", "%.0f damage a second, held down" % prog.tool_dps(tier)))
	else:
		stats.append(_row("Mining power", "%.0f damage a swing" % prog.tool_power(tier)))
		stats.append(_row("Swing speed", "%.1f swings a second" % (1.0 / prog.tool_interval(tier) * prog.speed_mult())))
	stats.append(_row("Hardest rock", HARDNESS[clampi(int(t.get("max_hardness", 1)), 0, 4)]))
	return {"title": str(t["title"]), "price": 0, "model": {"kind": "tool", "tier": tier}, "stats": stats, "compare": [_cmp("The best tool in the quarry: it breaks anything.", "good")], "reason": "", "owned_only": true, "on_buy": Callable(), "owned": 0}


## An extra tool, hauling aid or piece of equipment of the workbench ("gear" data).
static func gear(game, id: String, on_buy: Callable) -> Dictionary:
	var prog: QuarryProgression = game.prog
	var g: Dictionary = prog.gear_def(id)
	var kind := str(g.get("kind", "tool"))
	var stats := []
	var compare := []
	if kind == "cart":
		stats.append(_row("Carries", "+%d units in the bag" % int(g["capacity"])))
		stats.append(_row("Bag with it", "%d units (now %d)" % [game.state.capacity() - game.state.cart_capacity() + int(g["capacity"]), game.state.capacity()]))
		var diff: int = int(g["capacity"]) - game.state.cart_capacity()
		compare.append(_cmp("Fewer trips to sell or store: %s%d units against what you use now" % ["+" if diff >= 0 else "", diff], "good" if diff > 0 else "flat"))
	elif kind == "equipment":
		stats.append(_row("Effect", "powered tools work %d%% faster" % int(round((float(g.get("power_mult", 1.0)) - 1.0) * 100.0))))
		compare.append(_cmp("Helps the drill, powered hammer, pneumatic chisel and jackhammer.", "flat"))
	else:
		var cont := bool(g.get("continuous", false))
		var dps := float(g["dps"]) if g.has("dps") else float(g["power"]) / float(g["interval"])
		stats.append(_row("Type", str(g.get("class", "general")).capitalize()))
		stats.append(_row("Mining power", ("%.0f damage a second, held down" % dps) if cont else ("%.0f damage a swing, %.1f swings a second" % [float(g["power"]), 1.0 / float(g["interval"])])))
		stats.append(_row("Hardest rock", HARDNESS[clampi(int(g.get("max_hardness", 1)), 0, 4)]))
		if g.has("affinity"):
			var best := 0.0
			for k in g["affinity"]:
				best = maxf(best, float(g["affinity"][k]))
			stats.append(_row("Soft rock", "x%.1f damage on stone and coal" % best))
		if int(g.get("aoe", 0)) > 0:
			stats.append(_row("Area", "also hits %d neighbouring exposed blocks at %d%%" % [int(g["aoe"]), int(round(float(g["aoe_frac"]) * 100.0))]))
		var cur_dps := prog.tool_dps()
		compare.append(_cmp("In hand now: %s, %.0f damage a second" % [str(prog.tool()["title"]), cur_dps], "flat"))
		if int(g.get("max_hardness", 1)) > int(prog.tool().get("max_hardness", 1)):
			compare.append(_cmp("Breaks harder rock than your %s" % str(prog.tool()["title"]).to_lower(), "good"))
		stats.append(_row("Model", "uses the existing %s model" % ["hammer", "pickaxe", "reinforced pickaxe", "drill", "jackhammer"][clampi(int(g.get("model", 0)), 0, 4)]))
	stats.append(_row("About", str(g.get("desc", ""))))
	var reason := prog.gear_block_reason(id)
	return {"title": str(g["title"]), "price": int(g["cost"]), "model": {"kind": "tool", "tier": int(g.get("model", 0))}, "stats": stats, "compare": compare,
		"reason": "" if reason == "Already owned" else reason, "on_buy": on_buy, "owned": 1 if prog.owns(id) else 0}
