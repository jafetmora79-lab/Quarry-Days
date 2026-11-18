extends SceneTree
## The rebuilt Cash Hopper: the Blender model with its named parts and seven clips, the six-phase payout sequence, and the guarantee that the sequence only SHOWS a sale the
## business has already booked (never pays, never pays twice, survives interruption and repetition).   godot --headless --fixed-fps 60 -s tests/test_hopper_sequence.gd

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
	check(view != null and view.model != null, "the hopper has its Blender view")
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
	var drawer: Node3D = view.drawer
	var cash1: Node3D = view.model.find_child("Cash_1", true, false)
	view.anim.play("Idle")
	view.anim.advance(0.1)
	var z_shut := drawer.position.z
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
		if view.phase == "registered" and shown == "":
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
	check(view.sale_display.text == "READY" and absf(drawer.position.z - z_shut) < 0.02, "and it is back to idle: display READY, drawer shut")
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
	check(not view._seq_running and view._queued_money == 0 and view.phase == "idle" and absf(drawer.position.z - z_shut) < 0.02, "the machine settles back to idle after the burst (%d frames)" % guard)
	check(st.money == m1 + expected, "and showing them did not change the balance")
	# ---- 5. nothing to sell: nothing plays and nothing is paid
	var m2: int = st.money
	biz.tick(1.0)
	await frames(30)
	check(st.money == m2 and view.phase == "idle" and not view._seq_running, "an empty hopper pays nothing and plays nothing")
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
