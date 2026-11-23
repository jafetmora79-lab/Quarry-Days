extends SceneTree
## The Meshy Cash Hopper rig and its screens (scripts/cash_hopper_rig.gd, hopper_plate_screen.gd, hopper_top_screen.gd), checked on their own, without the game:
## the cash is the real amount, the rig stands in three upgrade looks, the clips take the time they say, the tray starts closed and holds the cash before it opens,
## and the plate counts a sale up to its amount and names what was sold.
##   godot --headless --fixed-fps 60 -s tests/test_cash_hopper_rig.gd

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

func secs(t: float) -> void:
	await create_timer(t).timeout

func run() -> void:
	# ---- the cash is the amount, exactly
	for amount in [0, 1, 4, 5, 19, 20, 99, 100, 499, 500, 1865, 12345, 987654]:
		var sum := 0
		for e in MeshyHopperRig.breakdown(amount):
			sum += int(e[0]) * int(e[1])
		check(sum == amount, "breakdown of $%d adds up to $%d" % [amount, amount])
	check(MeshyHopperRig.breakdown_text(1865) == "3x$500  3x$100  3x$20  1x$5", "breakdown text for $1,865 lists the pieces, largest first")
	check(MeshyHopperRig.breakdown(1865)[0][0] == 500, "largest denomination first")

	# ---- the rig
	check(MeshyHopperRig.available(), "the tier 0 model is in the project")
	var rig := MeshyHopperRig.new()
	root.add_child(rig)
	check(rig.build(), "the rig builds all three tiers")
	await process_frame
	for ti in range(3):
		rig.set_tier(ti)
		check(rig.tier == ti and rig.screen != null, "tier %d: its model and plate screen are active" % ti)
		check((ti == 0) == (rig.top_screen == null), "tier %d: the status window exists only on the upgraded hoppers" % ti)
		var shown := 0
		for k in range(3):
			if (rig.model.get_node("Tier%d" % k) as Node3D).visible:
				shown += 1
		check(shown == 1, "tier %d: exactly one model is visible" % ti)
	check(absf(rig.play("DrawerOpen", 1.0) - 0.5) < 0.001 and absf(rig.play("DrawerClose", 2.0) - 0.225) < 0.001, "clip lengths follow the speed")
	check(rig.play("NoSuchClip") == 0.0, "an unknown clip takes no time")

	# ---- tray and cash: closed at rest, the cash is in it before it opens
	for ti in range(3):
		rig.set_tier(ti)
		rig.play("Idle")
		rig.tray_open = 0.0
		rig.shutter_open = 0.0
		await process_frame
		var cfg: Dictionary = MeshyHopperRig.CFG[ti]
		rig.pay_out(1865)
		await process_frame
		var bills := rig._bills
		check(bills.size() > 0, "tier %d: the cash is laid in the tray (%d pieces)" % [ti, bills.size()])
		var any_visible := false
		for e in bills:
			if (e["n"] as MeshInstance3D).visible:
				any_visible = true
		check(not any_visible, "tier %d: the cash stays hidden while the tray is closed" % ti)
		rig.tray_open = 1.0
		await process_frame
		any_visible = false
		for e in bills:
			if (e["n"] as MeshInstance3D).visible:
				any_visible = true
		check(any_visible, "tier %d: the cash shows once the tray is out" % ti)
		check(float(cfg["closed"]) < 0.0 and float(cfg["slide"]) > 0.0, "tier %d: the tray rests pushed in and slides out" % ti)
		rig.tray_open = 0.0
		rig.pay_out(7)
		check(rig._bills.size() == 3, "tier %d: $7 is one $5 bill and two $1 coins (%d pieces)" % [ti, rig._bills.size()])
		rig._clear_bills()

	# ---- the plate counts the sale up
	for ti in range(3):
		rig.set_tier(ti)
		var sc := rig.screen
		sc.back_to_idle()
		sc.set_idle("TIER", "READY", "TODAY $0")
		check(sc.is_idle(), "tier %d plate: idle page" % ti)
		sc.sale(1865, 14, [["Limestone", 9], ["Coal", 5]], 0.4)
		await secs(0.15)
		var mid := sc.shown_amount()
		check(mid > 0 and mid < 1865, "tier %d plate: the number is on its way (%d)" % [ti, mid])
		await secs(0.6)
		check(sc.shown_amount() == 1865 and sc.shown_text() == "+$1,865", "tier %d plate: it lands exactly on $1,865 (%s)" % [ti, sc.shown_text()])
		sc.paid(MeshyHopperRig.breakdown_text(1865))
		check(sc._foot.text == "3x$500  3x$100  3x$20  1x$5", "tier %d plate: the footer lists the bills and coins" % ti)
		sc.done()
		sc.back_to_idle()
		check(sc.is_idle(), "tier %d plate: back to idle" % ti)
	# a sale that rides an open drawer carries the number on from where it is
	var s2 := rig.screen
	s2.sale(500, 3, [["Gravel", 3]], 0.1)
	await secs(0.3)
	s2.sale(800, 5, [["Gravel", 5]], 0.1, s2.shown_amount())
	await secs(0.3)
	check(s2.shown_amount() == 800, "a second sale continues the same number up to the new total")

	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
