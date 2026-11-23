extends SceneTree
## The Cash Hopper: its model (the Meshy rig when its models are in the project, else the Blender hopper with its named parts and seven clips), the six-phase payout
## sequence, and the guarantee that the sequence only SHOWS a sale the business has already booked (never pays, never pays twice, survives interruption and repetition).   godot --headless --fixed-fps 60 -s tests/test_hopper_sequence.gd

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

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	game.cash_hopper_enabled = true
	root.add_child(game)
	await process_frame
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await process_frame
	var st = game.state
	var biz = game.business
	var h: int = biz.cash_hopper_indices()[0]
	var view: CashHopperView = game.output_nodes[h].get_node_or_null("CashHopperView")
	check(view != null and view.model != null, "the hopper has its view")
	var rig = view.rig                                                           # the Meshy rig (null: the Blender fallback is shown)
	var drawer: Node3D = null
	var z_shut := 0.0
	var closed_now := func() -> bool:                                             # the tray rests shut (shutter down, tray pushed in) / the Blender drawer is flush
		if rig != null:
			return rig.tray_open < 0.02 and rig.shutter_open < 0.02
		return absf(drawer.position.z - z_shut) < 0.02
	if rig != null:
		# ---- 1. the Meshy rig: three tier models, the same seven clip names, the tray rests closed and opens and closes with the clips
		check(rig.model.get_node_or_null("Tier0") != null and rig.model.get_node_or_null("Tier1") != null and rig.model.get_node_or_null("Tier2") != null, "the rig holds all three tier models")
		var no_clip_r := []
		for c in ["Idle", "SaleRegistered", "Processing", "Counting", "DrawerOpen", "DrawerClose", "ReturnToIdle"]:
			rig.play(c, 1.0)
			if not MeshyHopperRig.CLIP_LEN.has(c):
				no_clip_r.append(c)
		check(no_clip_r.is_empty(), "all seven clip names are known to the rig (missing: %s)" % str(no_clip_r))
		rig.play("Idle")
		await frames(3)
		check(rig.tray_open < 0.01 and rig.shutter_open < 0.01, "at rest the tray is tucked in and the shutter is down")
		rig.play("DrawerOpen", 1.0)
		await frames(60)
		check(rig.shutter_open > 0.99 and rig.tray_open > 0.9, "DrawerOpen rolls the shutter up and slides the tray out (shutter %.2f, tray %.2f)" % [rig.shutter_open, rig.tray_open])
		rig.play("DrawerClose", 1.0)
		await frames(60)
		check(rig.tray_open < 0.01 and rig.shutter_open < 0.01, "DrawerClose puts the tray back and lowers the shutter")
	else:
		# ---- 1. the model: named parts and clips
		var names := ["Rim", "Brackets", "Panel", "SaleDisplay", "Lamp_Status", "Lamp_Status2", "Pivot_Funnel", "Pivot_Drawer", "Cash_1", "Cash_2", "Cash_3", "Cash_4", "Pivot_GearA", "Pivot_GearB", "Pivot_RollerA", "Pivot_RollerB", "Pivot_Flywheel", "Pivot_Flap", "Pivot_Piston"]
		var missing := []
		for nm in names:
			if view.model.find_child(nm, true, false) == null:
				missing.append(nm)
		check(missing.is_empty(), "every required named part is in the model (missing: %s)" % str(missing))
		var clips := ["Idle", "SaleRegistered", "Processing", "Counting", "DrawerOpen", "DrawerClose", "ReturnToIdle"]
		var no_clip := []
		for c in clips:
			if view.anim == null or not view.anim.has_animation(c):
				no_clip.append(c)
		check(no_clip.is_empty(), "all seven animation clips came through the GLB (missing: %s)" % str(no_clip))
		# ---- 2. the drawer: shut it is flush, open it comes out toward the front (-Z) and carries the cash
		drawer = view.drawer
		var cash1: Node3D = view.model.find_child("Cash_1", true, false)
		view.anim.play("Idle")
		view.anim.advance(0.1)
		z_shut = drawer.position.z
		check(drawer.position.y > 0.3 and cash1.scale.x < 0.01, "shut, the cash bundles are hidden (scale %.3f)" % cash1.scale.x)
		view.anim.play("DrawerOpen")
		view.anim.seek(view.anim.get_animation("DrawerOpen").length, true)
		var z_open := drawer.position.z
		check(z_open < z_shut - 0.25 and z_open > z_shut - 0.4, "DrawerOpen slides it toward the front by %.2f m" % (z_shut - z_open))
		check(cash1.scale.x > 0.9, "and the cash bundles are in view (scale %.2f)" % cash1.scale.x)
		view.anim.play("DrawerClose")
		view.anim.seek(view.anim.get_animation("DrawerClose").length, true)
		check(absf(drawer.position.z - z_shut) < 0.001 and cash1.scale.x < 0.01, "DrawerClose puts it back exactly and hides the cash")
		# the shut drawer's front is at most 3 cm proud of the cabinet face (z = -0.81), so nothing clips through it or hangs out
		var front_z := z_shut - 0.83 + 0.67                                         # (the drawer's front panel sits 0.16 m ahead of its pivot; the pivot is at -0.67 in the model)
		check(absf(front_z + 0.83) < 0.05, "shut, the drawer front is flush with the cabinet face")
	# ---- 3. one sale: booked once by the business, shown in six phases
	st.storage["crushed_stone"] = 14
	var m0: int = st.money
	game.cash_deposit(h, [], true)
	var seen := {}
	var order := []
	var shown := ""
	var money_during := []
	biz.tick(0.7)                                                               # 14 units at 24/s: sold within this one tick? (the business decides)
	var booked: int = st.money - m0
	check(booked > 0, "the business booked the sale first ($%d)" % booked)
	var t := 0.0
	while t < 6.0:
		await physics_frame
		t += 1.0 / 60.0
		if not order.has(view.phase) or order[order.size() - 1] != view.phase:
			order.append(view.phase)
		if rig != null:
			if view.phase == "payout":
				shown = rig.screen.shown_text()                                    # the plate has counted up to the booked amount by the time the tray opens
		elif view.phase == "registered" and shown == "":
			shown = view.sale_display.text
		money_during.append(st.money)
		if view.phase == "idle" and order.size() > 2 and not view._seq_running:
			break
	check(order.has("registered") and order.has("processing") and order.has("counting") and order.has("payout") and order.has("complete") and order[order.size() - 1] == "idle", "all six phases ran in order: %s" % str(order))
	check(shown == "+" + QuarryTheme.money_text(booked) or shown.begins_with("+$"), "the display showed the real amount (%s for $%d)" % [shown, booked])
	var flat := true
	for m in money_during:
		flat = flat and int(m) == m0 + booked
	check(flat and st.money == m0 + booked, "no frame of the animation paid anything: money stayed at +$%d throughout" % booked)
	check(t < 4.2, "the sequence took %.1f s (about 3 s)" % t)
	check(((rig.screen.is_idle() and rig.shutter_open < 0.02) if rig != null else view.sale_display.text == "READY") and closed_now.call(), "and it is back to idle: display idle, tray shut")
	# ---- 4. repeated sales and sales during a payout: summed, paid once, no state errors
	var m1: int = st.money
	for k in range(3):
		st.storage["crushed_stone"] = 5
		game.cash_deposit(h, [], true)
		biz.tick(0.5)
		await frames(20)
	var expected: int = st.money - m1
	check(expected == 3 * 5 * 7, "three more sales paid exactly 3 x 5 x $7 (+$%d)" % expected)
	var guard := 0
	while view._seq_running and guard < 600:
		await physics_frame
		guard += 1
	check(not view._seq_running and view._queued_money == 0 and view.phase == "idle" and closed_now.call(), "the machine settles back to idle after the burst (%d frames)" % guard)
	check(st.money == m1 + expected, "and showing them did not change the balance")
	# ---- 5. nothing to sell: nothing plays and nothing is paid
	var m2: int = st.money
	biz.tick(1.0)
	await frames(30)
	check(st.money == m2 and view.phase == "idle" and not view._seq_running, "an empty hopper pays nothing and plays nothing")
	# ---- 5b. it starts small, and each upgrade changes how it looks (and what it sells)
	var bundles := func() -> int:
		var n := 0
		for cn in view._cash_nodes:
			n += 1 if (cn as Node3D).visible else 0
		return n
	await frames(5)
	if rig != null:
		check(is_equal_approx(view.scale.x, 0.8) and rig.tier == 0 and rig.top_screen == null and biz.cash_tier_index(h) == 0, "it starts as the small old hopper: 80%% size, the tier 0 model, no status window (scale %.2f)" % view.scale.x)
	else:
		check(is_equal_approx(view.scale.x, 0.8) and not view.lamp2.visible and bundles.call() == 2 and biz.cash_tier_index(h) == 0, "it starts as the small old hopper: 80%% size, one lamp, two cash bundles (scale %.2f)" % view.scale.x)
	st.money = 6000
	check(biz.cash_upgrade(h) and biz.cash_rate(h) == 48.0, "the first upgrade (the Motorized Hopper) is bought for the price in the data and doubles the speed")
	await frames(15)
	if rig != null:
		check(is_equal_approx(view.scale.x, 0.92) and rig.tier == 1 and rig.top_screen != null, "and the machine looks different: bigger, the tier 1 model with its status window")
	else:
		check(is_equal_approx(view.scale.x, 0.92) and view.lamp2.visible and bundles.call() == 3, "and the machine looks different: bigger, both lamps, three bundles")
	check(biz.cash_upgrade(h) and biz.cash_rate(h) == 96.0, "the second upgrade (the Industrial Hopper) doubles it again")
	await frames(15)
	if rig != null:
		check(is_equal_approx(view.scale.x, 1.0) and rig.tier == 2, "and the Industrial one is full size with the tier 2 model")
	else:
		check(is_equal_approx(view.scale.x, 1.0) and bundles.call() == 4, "and the Industrial one is full size with four bundles")
	check(not biz.cash_upgrade(h), "there is no third upgrade")
	# ---- 5c. more hoppers can be bought and placed round the quarry; each is its own selling point with its own tier and view
	var offer: Dictionary = PurchaseOffers.machine(game, "cash_hopper", func(): pass)
	check(int(offer.get("price", 0)) == int(biz.cfg["cash_hopper"]["price"]) and int(biz.cfg["cash_hopper"]["price"]) > 0, "the shop sells a Cash Hopper ($%d)" % int(offer.get("price", 0)))
	var spot := QuarryBusiness.v3(biz.outputs[h]["position"]) + Vector3(8.0, 0.0, 0.0)
	var h2b: int = biz.add_output(spot, 0.0, "cash_hopper")
	game._create_output(h2b)
	await frames(10)
	var v2b: CashHopperView = game.output_nodes[h2b].get_node_or_null("CashHopperView")
	check(biz.cash_hopper_indices().size() == 2 and v2b != null and biz.cash_tier_index(h2b) == 0 and is_equal_approx(v2b.scale.x, 0.8), "a second Cash Hopper placed elsewhere starts small and independent (tier %d)" % biz.cash_tier_index(h2b))
	st.storage["crushed_stone"] = 6
	var mm: int = st.money
	game.cash_deposit(h2b, [], true)
	biz.tick(0.5)
	await frames(15)
	check(st.money == mm + 42 and v2b._seq_running and not view._seq_running, "it sells on its own and only its own machine plays the sequence")
	for k in range(6):
		biz.add_output(spot + Vector3(3.0 * float(k + 1), 0.0, 0.0), 0.0, "cash_hopper")
	check(game.machine_lock_reason("cash_hopper") != "", "the quarry can run only so many: ordering more is refused with a reason (\"%s\")" % game.machine_lock_reason("cash_hopper"))
	while v2b._seq_running:
		await physics_frame
	# ---- 6. a sale after all that works again; save and load keep the balance and the view
	st.storage["crushed_stone"] = 8
	game.cash_deposit(h, [], true)
	biz.tick(0.5)
	var m3: int = st.money
	await frames(10)
	game._save(true)
	game._load(true)
	await frames(10)
	var h2: int = game.business.cash_hopper_indices()[0]
	var view2: CashHopperView = game.output_nodes[h2].get_node_or_null("CashHopperView")
	check(game.state.money == m3 and view2 != null and view2.phase == "idle", "save/load keeps the money ($%d) and rebuilds the view idle" % game.state.money)
	game.state.storage["crushed_stone"] = 3
	var m4: int = game.state.money
	game.cash_deposit(h2, [], true)
	game.business.tick(0.5)
	await frames(30)
	check(game.state.money == m4 + 21 and view2._seq_running, "and a new sale after loading pays $21 once and plays the sequence")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
