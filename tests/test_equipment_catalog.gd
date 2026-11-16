extends SceneTree
## The Equipment Catalog in Quarry OS: it is a desktop application, lists every placeable machine by category with a real price and the machinery stage
## gates, buys any quantity in ONE transaction (paid in full or not at all) into the Build Inventory (separate from the bag), refuses what is locked or
## unaffordable without taking money, and the Build Inventory survives a save and load.
##   godot --headless --fixed-fps 60 -s tests/test_equipment_catalog.gd

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

	var st = game.state
	var biz = game.business
	var os = game.management.os
	check(os != null and os.app_def("catalog").size() > 0, "Quarry OS has an Equipment Catalog application")
	check(os.icons.has("catalog"), "with a desktop shortcut")
	var cats: Array = game.catalog_categories()
	check(cats.has("Crushers") and cats.has("Conveyors") and cats.has("Storage"), "categories: %s" % str(cats))
	for e in game.CATALOG:
		check(game.catalog_unit_price(str(e[0])) > 0, "%s has a price ($%d)" % [e[1], game.catalog_unit_price(str(e[0]))])

	# unlock the machinery stage so crushers are buyable
	var prog = game.prog
	prog.stage = maxi(prog.stage, prog.stage_index(prog.gate_stage("crusher")) if prog.has_method("gate_stage") else prog.stage)
	var why_locked: String = game.catalog_reason("crusher", 1)
	if why_locked != "" and not why_locked.begins_with("Need"):
		# stage-locked in this save: open it the way the other suites do
		for s in range(prog.stages().size()):
			prog.stage = s
			if prog.unlocked("crusher"):
				break
	st.money = 100000
	biz.inventory.clear()
	var price: int = game.catalog_unit_price("crusher")
	var before: int = st.money
	var bag_before: int = int(st.inventory["limestone"])
	var msg: String = game.catalog_buy("crusher", 3)
	check(int(biz.inventory.get("crusher", 0)) == 3, "buying 3 crushers puts 3 in the Build Inventory (%s)" % msg)
	check(st.money == before - 3 * price, "and takes exactly 3 x $%d" % price)
	check(int(st.inventory["limestone"]) == bag_before and game.build_inventory_units() == 3, "the bag is untouched: the Build Inventory is separate")
	# multiple kinds
	game.catalog_buy("output", 2)
	check(int(biz.inventory.get("output", 0)) == 2 and game.build_inventory_units() == 5, "two output storages join them (5 units)")
	# conveyors need the milestone: either it is bought, or refused without cost
	var m1: int = st.money
	var msg2: String = game.catalog_buy("conveyor", 6)
	if biz.conveyors_unlocked():
		check(int(biz.inventory.get("conveyor", 0)) == 6 and st.money == m1 - 6 * game.catalog_unit_price("conveyor"), "six straight conveyors bought and paid (%s)" % msg2)
	else:
		check(int(biz.inventory.get("conveyor", 0)) == 0 and st.money == m1, "locked conveyors are refused and cost nothing (%s)" % msg2)
	# unaffordable: nothing moves
	st.money = price * 2 - 1
	var inv_before: int = int(biz.inventory.get("crusher", 0))
	var m2: int = st.money
	var msg3: String = game.catalog_buy("crusher", 2)
	check(int(biz.inventory.get("crusher", 0)) == inv_before and st.money == m2 and msg3.begins_with("Need"), "2 crushers with money for 1.99: refused, nothing taken (%s)" % msg3)
	# quantity clamps
	st.money = price * 500
	var q0: int = int(biz.inventory.get("crusher", 0))
	game.catalog_buy("crusher", 1000)
	check(int(biz.inventory.get("crusher", 0)) - q0 == 99, "a quantity is capped at 99 per order")
	biz.inventory["crusher"] = 3
	st.money = 50000

	# the page: the selected item, a quantity, a BUY button, the inventory list
	os.open_app("catalog")
	await process_frame
	await process_frame
	var w = os.window_of("catalog")
	check(w != null and w.page != null and w.page.tab == "catalog", "the Equipment Catalog window opens on its page")
	if w != null and w.page != null:
		var texts := []
		for l in w.page.content.find_children("*", "Label", true, false):
			texts.append((l as Label).text)
		var joined := " ".join(texts)
		check(joined.contains("BUILD INVENTORY"), "the page shows the Build Inventory")
		check(joined.contains("3 x Small Jaw Crusher"), "listing 3 x Small Jaw Crusher")
		check(joined.contains("CRUSHERS") and joined.contains("CONVEYORS"), "and the categories")

	# the Build Inventory survives a save and load
	var snap: Dictionary = JSON.parse_string(JSON.stringify(biz.snapshot()))
	biz.inventory.clear()
	biz.restore(snap)
	check(int(biz.inventory.get("crusher", 0)) == 3 and int(biz.inventory.get("output", 0)) == 2, "the Build Inventory persists through a save and load")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
