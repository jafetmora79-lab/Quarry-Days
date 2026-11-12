extends SceneTree
## Phase 9.6: the Small Jaw Crusher, the Small Hopper and the Manual Sorting Table.   godot --headless --fixed-fps 60 -s tests/test_machinery.gd

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
	root.add_child(game)
	await process_frame
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await process_frame
	var prog: QuarryProgression = game.prog
	var biz: QuarryBusiness = game.business
	var st: QuarryState = game.state
	prog.cleanup["done"] = true
	game.safety.enabled = false
	# ---- A: unlock gating (data-driven, unchanged stages)
	prog.stage = 0
	check(not prog.unlocked("sorter") and not prog.unlocked("hopper"), "A both are locked at the start")
	prog.stage = prog.stage_index("breaking_ground")
	check(prog.unlocked("sorter") and not prog.unlocked("hopper"), "A the sorting table opens at Breaking Ground, the hopper later")
	prog.stage = prog.stage_index("first_employee")
	check(prog.unlocked("hopper"), "A the small hopper opens at First Employee")
	st.money = 100000
	# ---- B: the small jaw crusher is the existing crusher: model, animation, processing, belt ports
	st.new_crusher(Vector3(14.0, 0.0, 17.0), 0.0, 1)
	game._create_crusher(0)
	await frames(3)
	var cn: Node3D = game.crusher_nodes[0]
	var jaw = cn.get_meta("jaw") if cn.has_meta("jaw") else null
	var fly: Array = cn.get_meta("flywheels", [])
	var meshes := cn.find_children("*", "MeshInstance3D", true, false).size()
	check(jaw != null and fly.size() == 2 and meshes >= 10, "B the crusher model has a swing jaw, two flywheels, feed hopper, motor and chute (%d parts)" % meshes)
	st.inventory["limestone"] = 12
	var lime0: int = st.total(st.inventory) + int(st.crushers[0]["input"]) + int(st.crushers[0]["output"])
	st.load_crusher(0, 12)
	st.start_crusher(0)
	var rot0: float = jaw.rotation.x
	var moved := 0.0
	for i in range(90):
		await physics_frame
		moved = maxf(moved, absf(jaw.rotation.x - rot0))
	check(moved > 0.01, "B the jaw swings and the flywheels turn while it crushes (%.3f rad)" % moved)
	st.tick(30.0)
	check(int(st.crushers[0]["output"]) == 12 and int(st.crushers[0]["input"]) == 0, "B processing is unchanged: 12 stone in, 12 gravel out")
	var cpos: Vector3 = QuarryBusiness.v3(st.crushers[0]["position"])
	var out_spot: Vector3 = cpos + QuarryBusiness.forward(0.0) * 2.0           # where the belt snap puts a belt that carries away from the chute
	var linked := false
	var ci: int = biz.add_conveyor(out_spot, 0.0, "straight")
	var lk: Dictionary = biz.links[ci] if ci < biz.links.size() else {}
	linked = str(lk.get("src", {}).get("type", "")) == "crusher"
	biz.conveyors.remove_at(ci)
	biz.compute_links()
	check(linked, "B a belt snapped to the chute connects to the crusher's port")
	# ---- C: hopper
	var h: int = biz.add_output(Vector3(8.0, 0.0, 17.0), 0.0, "hopper")
	game._create_output(h)
	await frames(2)
	var hn: Node3D = game.output_nodes.back()
	check(str(hn.get_meta("variant")) == "hopper" and hn.find_children("*", "MeshInstance3D", true, false).size() >= 6, "C the hopper is built as a funnel on a frame, with its own model")
	check(biz.output_capacity_of(h) == 60 and biz.output_capacity() == 30, "C it holds 60 units where an output bin holds 30")
	var plain: int = biz.add_output(Vector3(2.0, 0.0, 17.0), 0.0)
	game._create_output(plain)
	check(biz.ep_space({"type": "output", "index": plain}, "limestone") == 0 and biz.ep_space({"type": "output", "index": h}, "limestone") == 60 and biz.ep_space({"type": "output", "index": h}, "coal") == 60, "C a bin takes only gravel; the hopper takes any material")
	var put := biz.ep_put({"type": "output", "index": h}, "limestone", 45, false) + biz.ep_put({"type": "output", "index": h}, "coal", 40, false)
	check(put == 60 and biz.output_total(h) == 60, "C it fills to exactly 60 and refuses the rest (%d accepted of 85)" % put)
	var fill_before: float = (hn.get_meta("fill") as MeshInstance3D).scale.y
	await frames(6)
	check((hn.get_meta("fill") as MeshInstance3D).visible and (hn.get_meta("fill") as MeshInstance3D).scale.y > 0.8, "C the heap in the funnel shows it is full (%.2f)" % (hn.get_meta("fill") as MeshInstance3D).scale.y)
	var took := biz.ep_take({"type": "output", "index": h}, "coal", 10)
	check(took == 10 and biz.output_total(h) == 50, "C material can be taken out again")
	# a belt placed against the hopper links to it
	var hl := false
	for k in range(4):                                  # the belt spots the snap offers around any output bin
		var yk := float(k) * PI * 0.5
		var spot: Vector3 = Vector3(8.0, 0.0, 17.0) - QuarryBusiness.forward(yk) * 1.75
		var ci2: int = biz.add_conveyor(spot, yk, "straight")
		var lk2: Dictionary = biz.links[ci2] if ci2 < biz.links.size() else {}
		hl = hl or (str(lk2.get("dst", {}).get("type", "")) == "output" and int(lk2["dst"].get("index", -1)) == h) or (str(lk2.get("src", {}).get("type", "")) == "output" and int(lk2["src"].get("index", -1)) == h)
		biz.conveyors.remove_at(ci2)
		biz.compute_links()
	check(hl, "C a belt snapped to the hopper connects to it")
	# ---- D: sorting table
	var so: int = biz.add_output(Vector3(-4.0, 0.0, 17.0), 0.0, "sorter")
	game._create_output(so)
	await frames(2)
	var sn: Node3D = game.output_nodes.back()
	check(sn.has_meta("arm") and sn.find_children("*", "MeshInstance3D", true, false).size() >= 8, "D the sorting table has a work surface, trays and a sweeping arm")
	st.inventory["limestone"] = 0
	st.inventory["limestone"] = 18
	var all0: int = st.total(st.inventory) + biz.output_total(so)
	var d1: int = game.output_deposit(so, "limestone")
	check(d1 == 18 and biz.ep_space({"type": "output", "index": so}, "crushed_stone") == 0, "D rock goes on the table by hand; gravel is not sortable")
	check(biz.sorter_start(so) and biz.sorter_busy(so) and biz.sorter_unsorted(so, "limestone") == 8, "D a batch of 10 starts sorting (8 stay unsorted)")
	check(not biz.sorter_start(so), "D only one batch at a time")
	var arm: Node3D = sn.get_meta("arm")
	var arm_move := 0.0
	for i in range(40):
		await physics_frame
		arm_move = maxf(arm_move, absf(arm.rotation.y))
	check(arm_move > 0.1, "D the arm sweeps while a batch is sorted (%.2f rad)" % arm_move)
	biz.tick_sorters(2.0)
	check(biz.sorter_sorted(so, "limestone") == 0, "D nothing is sorted before the batch is done")
	biz.tick_sorters(6.0)
	check(biz.sorter_sorted(so, "limestone") == 10 and not biz.sorter_busy(so), "D after 6 seconds 10 units are sorted")
	var money0: int = st.money
	var pay: int = biz.sorter_sell(so)
	var plain_value := int(round(10.0 * st.unit_price("limestone")))
	check(pay == int(round(10.0 * st.unit_price("limestone") * 1.3)) and st.money == money0 + pay, "D sorted rock sells for 130%% of the price: $%d instead of $%d" % [pay, plain_value])
	check(biz.output_total(so) == 8 and biz.sorter_sorted(so, "limestone") == 0, "D the 10 units sold left the table; the other 8 are still there, unsorted")
	check(biz.sorter_sell(so) == 0, "D the same units cannot be sold twice")
	biz.sorter_start(so)
	biz.tick_sorters(7.0)
	check(biz.sorter_sorted(so, "limestone") == 8 and biz.sorter_start(so) == false, "D a last batch of 8 is sorted; nothing left to sort")
	var taken: int = game.output_withdraw(so, "limestone")
	check(taken == 8 and biz.sorter_sorted(so, "limestone") == 0, "D taking sorted rock off the table removes the sorted mark with it")
	# ---- E: save and load
	game.output_deposit(so, "limestone")
	st.inventory["coal"] = 6
	game.output_deposit(so, "coal")
	biz.sorter_start(so)
	var snapb: Dictionary = biz.snapshot()
	var b2 := QuarryBusiness.new(st, load_json("res://data/business.json"))
	b2.restore(snapb)
	check(b2.variant_of(h) == "hopper" and b2.variant_of(so) == "sorter" and b2.variant_of(plain) == "output" and b2.output_total(h) == 50, "E variants and contents survive saving")
	check(b2.sorter_busy(so) and b2.output_total(so) == biz.output_total(so), "E a running batch survives saving")
	var tampered := snapb.duplicate(true)
	tampered["outputs"][so]["sorted"] = {"limestone": 999}
	tampered["outputs"][so]["variant"] = "bogus"
	var b3 := QuarryBusiness.new(st, load_json("res://data/business.json"))
	b3.restore(tampered)
	check(b3.variant_of(so) == "output" and b3.sorter_sorted(so, "limestone") == 0, "E a damaged save cannot invent sorted rock or unknown machines")
	# ---- F: selling a structure returns its contents
	var before_all: int = st.total(st.inventory) + st.total(st.storage) + biz.output_total(so) + biz.output_total(h)
	var refund: int = biz.sell_structure("output", so)
	var after_all: int = st.total(st.inventory) + st.total(st.storage) + biz.output_total(h) + biz.outputs.map(func(o): return st.total(o["items"])).reduce(func(a, b): return a + b, 0) - biz.output_total(h)
	check(refund == int(biz.cfg["sorter_price"]) / 2 and refund >= 0, "F selling a sorting table refunds half its price ($%d)" % refund)
	# ---- G: ordering and placing through the shop
	prog.stage = prog.stage_index("first_employee")
	st.money = 5000
	var m1: int = st.money
	check(game.order_machine("sorter") and st.money == m1 - 200 and int(biz.inventory.get("sorter", 0)) == 1, "G ordering the table costs $200 and it arrives in the construction inventory")
	check(game.order_machine("hopper") and int(biz.inventory.get("hopper", 0)) == 1, "G the hopper costs $1,000 and arrives the same way")
	game._start_placement("hopper")
	check(game.placement and game.placement_kind == "hopper", "G the hopper goes into placement (blueprint)")
	game.ghost.position = Vector3(16.0, 0.0, 20.0)
	game.ghost_valid = true
	var n0: int = biz.outputs.size()
	game._place_ghost()
	check(biz.outputs.size() == n0 + 1 and biz.variant_of(biz.outputs.size() - 1) == "hopper", "G placing it builds a hopper in the yard")
	# ---- H: shop previews with the real meshes and numbers
	var oh: Dictionary = PurchaseOffers.machine(game, "hopper", func(): pass)
	var os: Dictionary = PurchaseOffers.machine(game, "sorter", func(): pass)
	var ms: Node3D = QuarryPreview.build_model(game, os["model"])
	var mh: Node3D = QuarryPreview.build_model(game, oh["model"])
	var oc: Dictionary = PurchaseOffers.machine(game, "crusher", func(): pass)
	check(verts(ms) >= 300 and verts(mh) >= 300, "H the shop previews show the real table and hopper models")
	check(int(oh["price"]) == 1000 and int(os["price"]) == 200 and str(oc["title"]) == "Small Jaw Crusher" and oh["stats"].size() >= 3 and os["stats"].size() >= 3, "H previews list price, capacity, speed and benefit; the crusher is named Small Jaw Crusher")
	ms.free()
	mh.free()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)

func verts(n: Node3D) -> int:
	var v := 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m and m.get_surface_count() > 0:
			v += (m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return v

func load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
