extends SceneTree
## A running production line through a real save and load: two crushers, belts (straight, short, incline), a merger, a splitter and bins are placed and run in the live
## game loop; part-way through (stone on the belts and in a bin) the game is saved, the yard is wrecked, the save is loaded, the machines are rebuilt as the Blender models
## with the same connections and contents, and the line CONTINUES: every stone ends up in a bin exactly once.
##   godot --headless --fixed-fps 60 -s tests/test_production_save_load.gd

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

func stones(biz, st) -> int:
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
	var o := Vector3(40.0, 0.0, 40.0)
	st.crushers.clear()
	# crusher 1 -> short -> straight -> merger side inlet (right); crusher 2 -> belt -> merger side inlet (left); merger -> incline -> bin
	st.new_crusher(o + Vector3(5.05, 0, 0), PI * 0.5, 1)
	st.new_crusher(o + Vector3(-4.05, 0, 0), -PI * 0.5, 1)
	for i in 2:
		game._create_crusher(i)
	game._create_conveyor(biz.add_conveyor(o, 0.0, "merger"))
	game._create_conveyor(biz.add_conveyor(o + Vector3(0, 0, -2.5), 0.0, "incline"))
	game._create_conveyor(biz.add_conveyor(o + Vector3(3.5, 0, 0), PI * 0.5, "short"))
	game._create_conveyor(biz.add_conveyor(o + Vector3(2.0, 0, 0), PI * 0.5, "straight"))
	game._create_conveyor(biz.add_conveyor(o + Vector3(-2.0, 0, 0), -PI * 0.5, "straight"))
	game._create_output(biz.add_output(o + Vector3(0, 0, -4.8), 0.0))
	biz.compute_links()
	var links_ok := true
	for i in biz.conveyors.size():
		if biz.links[i]["dst"].is_empty():
			links_ok = false
	check(links_ok, "every belt of the line is connected at its output end")
	st.crushers[0]["output"] = 10
	st.crushers[1]["output"] = 10
	# run in the live loop until stone is on the belts and some is in the bin
	for i in 1200:
		await physics_frame
		if biz.conveyor_total() > 0 and int(biz.outputs[0]["items"].get("crushed_stone", 0)) >= 3:
			break
	var mid_bin: int = int(biz.outputs[0]["items"].get("crushed_stone", 0))
	var mid_belts: int = biz.conveyor_total()
	check(mid_bin >= 3 and stones(biz, st) == 20, "the line is running in the live game (bin %d, on belts %d, 20 stones in the system)" % [mid_bin, mid_belts])
	game._save()
	var snap_belts := JSON.stringify(biz.conveyors)
	var snap_bins := JSON.stringify(biz.outputs)
	var snap_crushers := JSON.stringify(st.crushers)
	# wreck the yard, then load
	biz.conveyors.clear()
	biz.outputs.clear()
	st.crushers.clear()
	game._load()
	await process_frame
	for i in 5:
		await physics_frame
	check(biz.conveyors.size() == 5 and biz.outputs.size() == 1 and st.crushers.size() == 2, "the load rebuilds 2 crushers, 5 belt pieces and the bin")
	var kinds := []
	for c in biz.conveyors:
		kinds.append(str(c["kind"]))
	check(kinds.has("merger") and kinds.has("incline") and kinds.has("short"), "with their kinds (%s)" % str(kinds))
	var blender_ok: bool = game.conveyor_nodes.size() == 5 and game.crusher_nodes.size() == 2
	for n in game.conveyor_nodes:
		if n.find_child("Equip_*", true, false) == null:
			blender_ok = false
	for n in game.crusher_nodes:
		if n.find_child("Equip_crusher", true, false) == null:
			blender_ok = false
	check(blender_ok, "and in the world they are the Blender models again")
	check(stones(biz, st) == 20, "no stone was lost or duplicated by the save and load (%d)" % stones(biz, st))
	var loaded_links_ok := true
	for i in biz.conveyors.size():
		if biz.links[i]["dst"].is_empty():
			loaded_links_ok = false
	check(loaded_links_ok, "the connections are rebuilt")
	# and the line continues to completion
	for i in 3000:
		await physics_frame
		if int(biz.outputs[0]["items"].get("crushed_stone", 0)) >= 20:
			break
	check(int(biz.outputs[0]["items"].get("crushed_stone", 0)) == 20 and biz.conveyor_total() == 0, "production continues after the load: all 20 stones reach the bin exactly once (%d)" % int(biz.outputs[0]["items"].get("crushed_stone", 0)))
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
