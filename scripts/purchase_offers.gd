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
	var reason := "" if game.state.money >= int(nt["cost"]) else "Need %s more" % QuarryTheme.money_text(int(nt["cost"]) - game.state.money)
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
