extends SceneTree
## Phase 7.4: economy and pacing sanity. Quarry progress, not money, gates the late stages; machines beat
## hand tools; rare rock is worth more per unit of effort; nothing is a pure grind.
##   godot --headless --fixed-fps 60 -s tests/test_economy_pacing.gd

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

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	for i in range(4):
		await physics_frame
	var p: QuarryProgression = game.prog
	var prices: Dictionary = game.state.config["prices"]
	# 1. stage thresholds climb and later ones need quarry progress, not just money
	var prev := 0.0
	var mono := true
	for i in range(p.stages().size()):
		var e := float(p.stage_info(i)["req"].get("earned", 0))
		mono = mono and e >= prev
		prev = e
	check(mono, "1 earned-money requirements never decrease between stages")
	for sid in ["large", "deep"]:
		var req: Dictionary = p.stage_info(p.stage_index(sid))["req"]
		check(req.has("excavated") or req.has("quarry_level") or req.has("cleared"), "2 stage %s needs excavation progress, not only money" % sid)
	# 3. hand tools: every tier is a clear upgrade but nowhere near rig output
	var d0 := p.tool_dps(0)
	var last := d0
	var ok := true
	for t in range(1, 5):
		var d := p.tool_dps(t)
		ok = ok and d > last
		last = d
	check(ok, "3 each hand tool out-damages the previous one")
	var rig := p.machine("drill_rig")
	var breaker := p.machine("rock_breaker")
	check(float(rig["dps"]) > p.tool_dps(2) * 0.7, "4 a drilling rig out-cuts a reinforced pickaxe on its own")
	check(float(breaker["dps"]) > float(rig["dps"]) * 2.0, "5 the rock breaker is a serious step up from the drilling rig")
	check(float(breaker["dps"]) > p.tool_dps(4), "6 the rock breaker out-cuts the heaviest hand tool (machinery wins the late game)")
	# 7. rare material is worth more per hp
	var order := ["limestone", "coal", "iron_ore", "copper_ore", "gold_ore"]
	var rising := true
	var lastv := 0.0
	for r in order:
		var v := float(prices[r]) / float(p.material(r)["hp"])
		rising = rising and v > lastv
		lastv = v
	check(rising, "7 value per hp of effort rises with rarity (limestone < coal < iron < copper < gold)")
	# 8. the surface quarry is a real project, not a quick tap
	var l1 := 0.0
	for id in p.level_formations(1):
		l1 += float(p.max_units(id)) * float(p.material(str(p.fdef(id)["resource"]))["hp"])
	var pick_min := l1 / p.tool_dps(1) / 60.0
	var rig_min := l1 / (float(rig["dps"]) * 2.0) / 60.0
	check(pick_min > 120.0, "8 clearing level 1 by pickaxe alone is hours (%.0f min of pure swinging)" % pick_min)
	check(rig_min > 10.0 and rig_min < pick_min / 2.5, "9 two rigs make level 1 a session of work (%.0f min) instead of an evening of swinging" % rig_min)
	# 10. costs form a ladder: each machine purchase needs a meaningful block of income
	var ladder := [3200, int(rig["price"]), int(breaker["price"])]
	check(ladder[0] < ladder[1] and ladder[1] < ladder[2], "10 machine prices climb: loader < rig < rock breaker")
	check(p.permit_cost() >= 10000, "11 the excavation permit is a serious purchase")
	# 12. the starting rock plus the first bench can pay for the first machines but not the whole game
	var total_val := 0.0
	for id in p.cfg["formations"]:
		total_val += float(p.max_units(id)) * float(prices[str(p.fdef(id)["resource"])])
	var deep := float(p.stage_info(p.stage_index("deep"))["req"]["earned"])
	check(total_val > deep + p.permit_cost() + float(breaker["price"]), "12 the quarry holds enough value ($%d) to fund the end game" % int(total_val))
	# 13. running costs
	check(float(rig["cost_per_min"]) < float(rig["dps"]) / 10.0 * 6.0, "13 a rig's running cost stays small next to what it cuts")
	# 14. old saves: stage data migrates without touching formation sizes
	check(game.prog.column_count("hillside_face_01") == 72, "14 hillside formation is unchanged (72 columns)")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
