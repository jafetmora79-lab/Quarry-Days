extends SceneTree
## The shared first-person hand rig and the shovel's payload: every tool has grips and its hands close ON its shaft (fingers touch the wood, none inside it), the forearms stay out of the
## camera, the shovel's soil appears only when a strike really collected something, it is the dug material, it leaves when tipped and no quantity is ever created or lost.
##   Run through tools/run_tests.sh.
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

func dist_to_axis(p: Vector3, c: Vector3, a: Vector3) -> float:
	var d := p - c
	return (d - a * d.dot(a)).length()

func run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var keys := []
	for t in range(5):
		keys.append([t, ToolModels.key_of(t)])
	for id in GearModels.IDS:
		keys.append([GearModels.tier_of(id), id])
	var bad_wrap := []
	var no_grips := []
	for kt in keys:
		var tv := QuarryToolView.new()
		holder.add_child(tv)
		tv.equip(int(kt[0]), true)
		for f in 4:
			tv._process(1.0 / 60.0)
		var grips: Array = FPTools.grips(str(kt[1]))
		if grips.is_empty():
			no_grips.append(kt[1])
			continue
		var visible_hands := 0
		for side in tv.hands_rig.hands:
			if (tv.hands_rig.hands[side]["root"] as Node3D).visible:
				visible_hands += 1
		check(visible_hands == grips.size(), "%s: %d hand(s) on the tool" % [kt[1], grips.size()])
		# every finger bone ends on the shaft (touching the wood, not inside it): its distance from the grip axis is between the shaft radius and a finger's reach beyond it
		for g in grips:
			var side: String = g["hand"]
			var h: Dictionary = tv.hands_rig.hands[side]
			var xf: Transform3D = tv.model.transform
			if g.has("node"):
				var nd := tv.model.find_child(str(g["node"]), true, false) as Node3D
				if nd != null:
					xf = tv.model.transform * nd.transform
			var c: Vector3 = xf * (g["at"] as Vector3)
			var a: Vector3 = (xf.basis * (g["axis"] as Vector3)).normalized()
			var r: float = float(g["r"]) * xf.basis.get_scale().x
			for finger in h["fingers"]:
				for b in finger:
					var d := dist_to_axis((b as Node3D).position, c, a)
					if d < r - 0.001 or d > r + 0.035:
						bad_wrap.append("%s %s bone at %.3f (shaft %.3f)" % [kt[1], side, d, r])
		tv.queue_free()
	check(no_grips.is_empty(), "every tool has grips (missing: %s)" % str(no_grips))
	check(bad_wrap.is_empty(), "fingers wrap the shaft: none inside the wood, none floating off it %s" % str(bad_wrap.slice(0, 3)))
	# ---- the shovel in the game
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(8)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await frames(20)
	var st = game.state
	game.state.equipped = "shovel"
	await frames(4)
	game.player.tool_view.equip(game.prog.model_tier(), true)
	var tv2: QuarryToolView = game.player.tool_view
	await frames(4)
	check(tv2.payload != null and not tv2.has_payload(), "the shovel starts with an empty blade")
	check(str(tv2._def(tv2.tier).get("style", "")) == "scoop", "and it is dug with its own scoop animation")
	# a strike that collects nothing leaves the blade empty
	tv2.swing(0.5, func(): pass)
	for i in 70:
		await physics_frame
	check(not tv2.has_payload(), "a swing that collected nothing shows no soil")
	# a strike that really collects soil: the units go where they always went, and the blade shows them
	var before: int = st.total(st.inventory)
	tv2.swing(0.5, func(): game._terrain_yield({"topsoil": 1.0}, []))
	var seen := false
	var seen_res := ""
	var visible_phase := false
	for i in 120:
		await physics_frame
		if tv2.has_payload():
			seen = true
			seen_res = tv2.payload_res
		if tv2.payload.visible:
			visible_phase = true
	check(st.total(st.inventory) == before + 11, "11 units were collected, exactly once (%d)" % (st.total(st.inventory) - before))
	check(seen and seen_res == "topsoil" and visible_phase, "the blade carried the collected material (%s) and showed it" % seen_res)
	check(not tv2.has_payload() and not tv2.payload.visible, "the soil is gone after the dump phase")
	check(st.total(st.inventory) == before + 11, "and the dump changed no quantity")
	# a different material shows its own heap
	ShovelPayload.fill(tv2.payload, "limestone")
	var kinds := tv2.payload.get_child(0).get_child_count()
	check(kinds >= 1, "rock has its own payload shape")
	# ---- the bucket's weight and tip
	game.state.equipped = "bucket"
	await frames(4)
	tv2.equip(game.prog.model_tier(), true)
	await frames(4)
	tv2.carry_load = 1.0
	tv2.tip_bucket()
	var min_z := 0.0
	for i in 60:
		await physics_frame
		min_z = minf(min_z, tv2.pivot.rotation.z)
	check(min_z < -0.8, "an emptied bucket tips about the hand on the bail (%.2f rad)" % min_z)
	check(tv2.tip_t < 0.0 and absf(tv2.pivot.rotation.z) < 0.4, "and comes back upright")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
