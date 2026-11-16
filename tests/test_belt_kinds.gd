extends SceneTree
## The short, inclined and splitter conveyors on the existing transfer system: they link to crushers, belts and bins at their real ends (a crusher -> incline -> bin
## chain, a crusher -> belt -> splitter -> two belts -> two bins layout), move material without creating or losing a unit, the splitter shares the flow between its two
## exits and skips a full one, a short belt bridges a gap, and all of it survives a save and load.
##   godot --headless --fixed-fps 60 -s tests/test_belt_kinds.gd

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

func total(biz, st) -> int:
	var n: int = biz.conveyor_total()
	for c in st.crushers:
		n += int(c["output"])
	for o in biz.outputs:
		n += int(o["items"].get("crushed_stone", 0))
	return n

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
	var st = game.state
	var biz = game.business
	# ---- 1. crusher -> incline -> bin
	var o := Vector3(40.0, 0.0, 40.0)
	st.new_crusher(o, 0.0, 1)
	game._create_crusher(0)
	var inc: int = biz.add_conveyor(o + Vector3(0, 0, -2.65), 0.0, "incline")
	game._create_conveyor(inc)
	var bin1: int = biz.add_output(o + Vector3(0, 0, -4.85), 0.0)
	game._create_output(bin1)
	biz.compute_links()
	check(str(biz.links[inc]["src"].get("type", "")) == "crusher" and str(biz.links[inc]["dst"].get("type", "")) == "output", "the incline links the crusher to the bin at its real ends (3 m belt)")
	check(is_equal_approx(QuarryBusiness.belt_half("incline"), 1.5) and is_equal_approx(QuarryBusiness.belt_half("short"), 0.5), "belt lengths: incline 3 m, short 1 m")
	st.crushers[0]["output"] = 9
	var t := 0.0
	var ok := true
	while t < 200.0 and int(biz.outputs[bin1]["items"].get("crushed_stone", 0)) < 9:
		biz.tick_conveyors(0.1)
		t += 0.1
		if total(biz, st) != 9:
			ok = false
	check(ok and int(biz.outputs[bin1]["items"].get("crushed_stone", 0)) == 9, "9 stones ride the incline into the bin, none lost or duplicated (%.0f s)" % t)
	# ---- 2. short belt bridging a gap
	var o2 := Vector3(-40.0, 0.0, 40.0)
	st.new_crusher(o2, 0.0, 1)
	game._create_crusher(1)
	var b_short: int = biz.add_conveyor(o2 + Vector3(0, 0, -1.55), 0.0, "short")
	game._create_conveyor(b_short)
	var b_long: int = biz.add_conveyor(o2 + Vector3(0, 0, -3.05), 0.0)
	game._create_conveyor(b_long)
	var bin2: int = biz.add_output(o2 + Vector3(0, 0, -5.55), 0.0)
	game._create_output(bin2)
	biz.compute_links()
	check(int(biz.links[b_short]["dst"].get("index", -1)) == b_long and str(biz.links[b_long]["dst"].get("type", "")) == "output", "crusher -> short belt -> straight belt -> bin are linked")
	st.crushers[1]["output"] = 6
	t = 0.0
	while t < 200.0 and int(biz.outputs[bin2]["items"].get("crushed_stone", 0)) < 6:
		biz.tick_conveyors(0.1)
		t += 0.1
	check(int(biz.outputs[bin2]["items"].get("crushed_stone", 0)) == 6, "the short belt carries its share")
	# ---- 3. crusher -> belt -> splitter -> two belts -> two bins
	var o3 := Vector3(0.0, 0.0, 70.0)
	st.new_crusher(o3, 0.0, 1)
	game._create_crusher(2)
	var ba: int = biz.add_conveyor(o3 + Vector3(0, 0, -2.0), 0.0)
	game._create_conveyor(ba)
	var sp: int = biz.add_conveyor(o3 + Vector3(0, 0, -4.0), 0.0, "splitter")
	game._create_conveyor(sp)
	var bl: int = biz.add_conveyor(o3 + Vector3(-2.0, 0, -4.0), PI * 0.5)
	game._create_conveyor(bl)
	var br: int = biz.add_conveyor(o3 + Vector3(2.0, 0, -4.0), -PI * 0.5)
	game._create_conveyor(br)
	var binl: int = biz.add_output(o3 + Vector3(-4.2, 0, -4.0), 0.0)
	game._create_output(binl)
	var binr: int = biz.add_output(o3 + Vector3(4.2, 0, -4.0), 0.0)
	game._create_output(binr)
	biz.compute_links()
	check(int(biz.links[ba]["dst"].get("index", -1)) == sp, "the feed belt ends at the splitter")
	var d1: Dictionary = biz.links[sp]["dst"]
	var d2: Dictionary = biz.links[sp].get("dst2", {})
	var exits := [int(d1.get("index", -1)), int(d2.get("index", -1))]
	check(exits.has(bl) and exits.has(br), "the splitter has its two exits on the two side belts (%s)" % str(exits))
	check(str(biz.links[bl]["dst"].get("type", "")) == "output" and str(biz.links[br]["dst"].get("type", "")) == "output", "each exit belt ends in its own bin")
	check(str(biz.links[ba]["resource"]) == "crushed_stone", "the chain through the splitter resolves its material")
	st.crushers[2]["output"] = 12
	var before := total(biz, st)
	ok = true
	t = 0.0
	while t < 300.0 and int(biz.outputs[binl]["items"].get("crushed_stone", 0)) + int(biz.outputs[binr]["items"].get("crushed_stone", 0)) < 12:
		biz.tick_conveyors(0.1)
		t += 0.1
		if total(biz, st) != before:
			ok = false
	var nl := int(biz.outputs[binl]["items"].get("crushed_stone", 0))
	var nr := int(biz.outputs[binr]["items"].get("crushed_stone", 0))
	check(ok and nl + nr == 12, "12 stones arrive, nothing lost or duplicated (%d + %d)" % [nl, nr])
	check(absi(nl - nr) <= 2, "the splitter shares the flow between its two exits (%d / %d)" % [nl, nr])
	# a full bin on one side: everything goes to the other
	biz.outputs[binl]["items"]["crushed_stone"] = biz.output_capacity()
	st.crushers[2]["output"] = 8
	var before2 := total(biz, st)
	t = 0.0
	while t < 120.0 and int(st.crushers[2]["output"]) + biz.conveyor_total() > 3:
		biz.tick_conveyors(0.1)
		t += 0.1
	check(int(biz.outputs[binl]["items"]["crushed_stone"]) == biz.output_capacity() and total(biz, st) == before2, "a full exit is skipped: the other bin takes the rest, nothing lost")
	var stuck: int = biz.conveyor_total()          # what was already on the left belt when its bin filled waits there (it cannot go anywhere else)
	check(stuck <= 3 and int(biz.outputs[binr]["items"]["crushed_stone"]) + stuck == nr + 8, "everything else went right (%d in the right bin, %d waiting on the blocked belt)" % [int(biz.outputs[binr]["items"]["crushed_stone"]) - nr, stuck])
	# ---- 4. save and load
	var kinds_before := []
	for c in biz.conveyors:
		kinds_before.append(str(c["kind"]))
	var snap: Dictionary = JSON.parse_string(JSON.stringify(biz.snapshot()))
	biz.restore(snap)
	var kinds_after := []
	for c in biz.conveyors:
		kinds_after.append(str(c["kind"]))
	check(kinds_before == kinds_after and kinds_after.has("splitter") and kinds_after.has("incline") and kinds_after.has("short"), "short, incline and splitter belts survive a save and load")
	check(biz.links[sp].has("dst2") and not biz.links[sp]["dst2"].is_empty() and int(biz.links[inc]["dst"].get("index", -2)) == bin1, "with their connections rebuilt")
	# ---- 5. the catalog sells them and the Build Inventory takes them
	st.money = 100000
	biz.milestones["mechanized"] = true
	biz.inventory.clear()
	for k in ["conveyor_short", "conveyor_incline", "conveyor_splitter"]:
		var price: int = game.catalog_unit_price(k)
		var m0: int = st.money
		game.catalog_buy(k, 2)
		check(price > 0 and int(biz.inventory.get(k, 0)) == 2 and st.money == m0 - 2 * price, "the catalog sells %s: 2 for $%d" % [k, 2 * price])
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
