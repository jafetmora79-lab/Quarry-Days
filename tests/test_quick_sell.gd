extends SceneTree
## The Quick Sell Station: it stands in the world (model, sign, collider, interaction), opens a compact panel, and sells atomically: the right money for the
## chosen quantity, never more than is owned, nothing sold twice, no negative stock, one sale for SELL ALL, an empty station sells nothing.
##   godot --headless --fixed-fps 60 -s tests/test_quick_sell.gd

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
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	for i in 6:
		await physics_frame
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await process_frame

	var kp: Vector3 = game.quicksell_pos()
	var body: Node = game.world.get_node_or_null("Quick sell station")
	check(body != null and str(body.get_meta("kind", "")) == "quicksell", "the station has an interaction body of kind quicksell")
	var kiosk: Node3D = null
	for n in game.art.root.get_children():
		if n is Node3D and str(n.name).contains("SellKiosk"):
			kiosk = n
	check(kiosk != null and absf(kiosk.global_position.x - kp.x) < 0.01 and absf(kiosk.global_position.z - kp.z) < 0.01, "the Blender kiosk stands at the station")
	var office: Vector3 = game.OFFICE_POS
	check(absf(kp.x - office.x) > 4.0 or absf(kp.z - office.z) > 4.5, "it is clear of the office footprint")

	# stock: bag, bin, output
	var st = game.state
	for k in game.RESOURCE_ORDER:
		st.inventory[k] = 0
		st.storage[k] = 0
	st.inventory["limestone"] = 6
	st.storage["limestone"] = 4
	st.inventory["coal"] = 5
	check(game.quicksell_total_units() == 15, "the station sees the bag and the bin (15 units)")
	var m0: int = st.money
	var expect: int = st.payout("limestone", 7)
	var got: int = game.quick_sell({"limestone": 7})
	check(got == expect and st.money == m0 + expect, "selling 7 limestone pays exactly the game's price (%d)" % got)
	check(int(st.inventory["limestone"]) == 0 and int(st.storage["limestone"]) == 3, "the bag is emptied first, then the bin (0 and 3 left)")
	check(int(st.inventory["coal"]) == 5, "other materials are untouched")
	# asking for more than owned sells only what is there; selling again pays nothing
	var m1: int = st.money
	var got2: int = game.quick_sell({"limestone": 999})
	check(got2 == st.payout("limestone", 3) and int(st.storage["limestone"]) == 0, "asking for more than owned sells only the 3 that were there")
	check(game.quick_sell({"limestone": 5}) == 0 and st.money == m1 + got2, "a second sale of the same stock pays nothing")
	var neg := false
	for k in game.RESOURCE_ORDER:
		if int(st.inventory[k]) < 0 or int(st.storage.get(k, 0)) < 0:
			neg = true
	check(not neg, "no stock goes negative")
	# SELL ALL in one transaction
	st.inventory["gravel"] = 9
	var before_money: int = st.money
	var want_all: int = st.payout("coal", 5) + st.payout("gravel", 9)
	var all: int = game.quick_sell_all()
	check(all == want_all and st.money == before_money + want_all, "SELL ALL pays every material once (%d)" % all)
	check(game.quicksell_total_units() == 0, "and leaves nothing to sell")
	var m3: int = st.money
	check(game.quick_sell_all() == 0 and st.money == m3, "an empty station sells nothing")
	# the panel opens through the interaction and draws its buttons
	st.inventory["limestone"] = 4
	game._interact(body)
	await process_frame
	check(game.menu == "quicksell", "interacting opens the quick sell panel")
	var btn: Button = game.panel.buttons.get("qs_sell_all") as Button
	check(btn != null and not btn.disabled, "SELL ALL is on the panel and enabled")
	var m4: int = st.money
	if btn != null:
		btn.pressed.emit()
	check(st.money == m4 + st.payout("limestone", 4) and int(st.inventory["limestone"]) == 0, "pressing SELL ALL sells the stock through the panel")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
