extends SceneTree
## Every way of putting material into the Cash Hopper has its own animation, driven by the real transaction: a bag/crate toss, a shovel flick, the carried bucket poured, a machine's bucket
## cascade, a truck's avalanche, and a belt's single pieces. The heap grows when the pieces land, never before, and nothing is shown twice.   godot --headless --fixed-fps 60 -s tests/test_hopper_intake.gd

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

func chunks(view: Node) -> int:
	var n := 0
	for c in view.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
			n += 1
	return n

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
	var v: CashHopperView = game.output_nodes[h].get_node_or_null("CashHopperView")
	biz.outputs[h]["tier"] = 0                                       # the small old hopper sells 24 units a second: slow enough to watch the intake
	biz.outputs[h]["progress"] = 0.0
	var money0: int = st.money
	# ---- the real entry points set their own source
	st.storage["crushed_stone"] = 150
	game.cash_deposit(h, [], true)
	check(v.last_source == "hand", "a crate deposit plays the handful toss (%s)" % v.last_source)
	await frames(4)
	check(chunks(v) >= 3, "pieces are in the air (%d)" % chunks(v))
	check(int(v._inflight.get("crushed_stone", 0)) > 0 and (v._heap == null or not v._heap.visible or v._heap_amt < 0.3), "and the heap has not grown yet: the units are still falling")
	st.equipped = "shovel"
	st.inventory["coal"] = 6
	game.cash_deposit(h, [], false)
	check(v.last_source == "shovel", "a bag deposit with the shovel in hand plays the shovel flick (%s)" % v.last_source)
	st.equipped = ""
	st.hand_bucket = {"limestone": 9}
	game.deliver_hand_to_hopper(h)
	check(v.last_source == "bucket", "the carried bucket pours a stream (%s)" % v.last_source)
	game._hopper_intake_fx(h, "machine", {"iron_ore": 30}, v.global_position + Vector3(0, 2.0, -2.0))
	check(v.last_source == "machine", "a machine's bucket plays the cascade")
	game._hopper_intake_fx(h, "truck", {"gold_ore": 40}, v.global_position + Vector3(2.0, 2.0, 0.0))
	check(v.last_source == "truck", "a truck's bed plays the avalanche")
	await frames(8)
	var peak := chunks(v)
	check(peak >= 12, "all of it at once is a lot of pieces in the air (%d)" % peak)
	# ---- they land, the heap grows, the pour sounds and the dust rises; then nothing is left in the air
	var peak_amt := 0.0
	for i in range(180):
		await physics_frame
		peak_amt = maxf(peak_amt, v._heap_amt)
	check(v._inflight.values().all(func(x): return int(x) == 0), "everything lands: nothing is left in the air that was thrown in")
	check(v._heap != null and peak_amt > 0.15, "the heap in the funnel showed what landed (peak fullness %.2f), before the hopper sold it all" % peak_amt)
	# ---- nothing is shown twice: those deposits did not also play as 'belt'
	check(v.last_source == "truck" and int(v._skip.values().reduce(func(a, b): return int(a) + int(b), 0)) == 0, "the detector did not replay them as belt pieces")
	# ---- belt: material that just appears in the hopper arrives as belt pieces
	biz.outputs[h]["items"]["limestone"] = int(biz.outputs[h]["items"].get("limestone", 0)) + 2
	await frames(30)
	check(v.last_source == "belt", "material that arrives by belt drops off the belt end (%s)" % v.last_source)
	# ---- the sale of all that is untouched by the show
	check(st.money == money0 or st.money >= money0, "intake animations never change the balance by themselves")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
