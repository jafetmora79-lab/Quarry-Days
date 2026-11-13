extends SceneTree
## Phase 6.2 tests: the site-cleanup tutorial (weeds, rubble heaps, Walt's gift, hillside unlock, saves).
##   godot --headless --fixed-fps 60 -s tests/test_phase6_2.gd

const HID := "hillside_face_01"
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

func aim_at(game, pos: Vector3, look: Vector3) -> void:
	game.player.global_position = pos
	var d := look - (pos + Vector3(0, 1.58, 0))
	game.player.rotation.y = atan2(-d.x, -d.z)
	game.player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	game.player.camera.rotation.x = game.player.pitch

func first(game, weed: bool) -> String:
	for id in game.cleanup_nodes:
		if str(id).begins_with("w") == weed:
			return str(id)
	return ""

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.natural_start_enabled = false      # Phase 10: these suites test the older systems on the old starting layout
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game.tutorial_visible = false
	var st: QuarryState = game.state
	var prog: QuarryProgression = game.prog
	var cfg: Dictionary = prog.cleanup_cfg()
	# ---- data and spawn
	check(prog.cleanup_total() == 26 and cfg["weeds_legacy"].size() == 18 and cfg["heaps_legacy"].size() == 8, "A the (old-layout) site starts with 18 weed clumps and 8 rubble heaps")
	check(game.cleanup_nodes.size() == 26 and prog.cleanup_active(), "A a new game spawns all of them")
	var clear := true
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	for id in game.cleanup_nodes:
		var body: StaticBody3D = game.cleanup_nodes[id]
		var cs: CollisionShape3D = body.get_child(0)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cs.shape
		q.transform = body.global_transform * cs.transform
		q.exclude = [body.get_rid()]
		q.collision_mask = 0xFFFF
		var hits: Array = space.intersect_shape(q, 4)
		var other := false
		for h in hits:
			if not h["collider"].has_meta("debris_id") and not h["collider"].has_meta("ground") and str(h["collider"].name) != "Quarry floor":
				other = true
		clear = clear and not other and not game.in_hillside_zone(body.position, 0.5)
		if other or game.in_hillside_zone(body.position, 0.5):
			var names := []
			for h in hits:
				names.append(str(h["collider"].name))
			print("INFO overlap ", id, " ", body.position, " ", names, " zone ", game.in_hillside_zone(body.position, 0.5))
	check(clear, "A no weed or heap overlaps a building, formation, the pit or the hillside")
	# ---- the hillside is closed until the site is clean
	var lock: String = prog.formation_locked(HID)
	check(lock != "" and lock.contains("26"), "B the hillside is locked: %s" % lock)
	var u0: int = prog.units_left(HID)
	var got: int = game.player_mine(HID, 6 * 5 + 5, 100.0, prog.column_pos(HID, 6 * 5 + 5))
	check(got == 0 and prog.units_left(HID) == u0 and game.message.contains("first"), "B cutting the locked hillside does nothing and says why")
	check(game.nearest_deposit("limestone", Vector3(-14, 0, -3)) != HID, "B staff do not go to the locked hillside")
	check(prog.rig_block_reason("drill_rig", HID) != "", "B no rig can be installed on the locked hillside")
	check(game.formation_nodes[HID].label.text.contains("CLEAR THE SITE"), "B the hillside label tells the player to clean up")
	check(game.hud_status_text().contains("Site cleanup 0/26"), "B the HUD shows cleanup progress")
	# ---- weeds with the starting hammer (power 4, weed hp 6: two swings)
	st.tool_tier = 0
	var wid := first(game, true)
	var wp: Vector2 = prog.cleanup_pos(wid)
	aim_at(game, Vector3(wp.x + 1.4, 0.05, wp.y), Vector3(wp.x, 0.5, wp.y))
	for i in range(3):
		await physics_frame
	var ray: Dictionary = game._mining_ray()
	check(not ray.is_empty() and ray["node"] == game.cleanup_nodes[wid], "C the crosshair finds the weed clump")
	game._on_swing_impact()
	check(not prog.cleanup["cleared"].get(wid, false), "C one hammer swing does not clear a clump")
	var money0: int = st.money
	game._on_swing_impact()
	check(prog.cleanup["cleared"].get(wid, false) and not game.cleanup_nodes.has(wid) and st.money == money0, "C the second swing clears it (counts toward the site, pays nothing)")
	check(prog.cleanup_left() == 25 and game.hud_status_text().contains("Site cleanup 1/26"), "C progress counts up")
	# ---- rubble heap: 5 stone, one per 10 damage, none lost when the bag is full
	var hid := first(game, false)
	var hp: Vector2 = prog.cleanup_pos(hid)
	aim_at(game, Vector3(hp.x + 1.6, 0.05, hp.y), Vector3(hp.x, 0.5, hp.y))
	for i in range(3):
		await physics_frame
	for k in st.inventory:
		st.inventory[k] = 0
	for i in range(6):
		game._on_swing_impact() # 6 x 4 = 24 damage -> 2 stone
	check(int(st.inventory["limestone"]) == 2 and prog.heap_units_left(hid) == 3, "D a heap yields 1 stone per 10 damage (2 stone, 3 left)")
	var cap: int = st.capacity()
	st.inventory["coal"] = cap - 2 # room for exactly 0 more stone after the 2 we hold
	for i in range(10):
		game._on_swing_impact()
	check(prog.heap_units_left(hid) == 3 and st.total(st.inventory) <= cap, "D a full bag takes nothing and loses no stone from the heap")
	st.inventory["coal"] = 0
	for i in range(14):
		game._on_swing_impact()
	check(prog.cleanup["cleared"].get(hid, false) and int(st.inventory["limestone"]) == 5, "D the heap is gone once its 5 stone are in the bag, none duplicated")
	# ---- save/load keeps what is left; loading twice duplicates nothing
	var w2 := ""
	for id in game.cleanup_nodes:
		if str(id).begins_with("h"):
			w2 = str(id)
			break
	prog.cleanup["units"][w2] = 2
	var left_before: int = prog.cleanup_left()
	game._save()
	game._load()
	await process_frame
	await process_frame
	check(prog.cleanup_left() == left_before and game.cleanup_nodes.size() == left_before and prog.heap_units_left(w2) == 2, "E loading restores exactly what is left (%d items, heap with 2 stone)" % left_before)
	game._load()
	for i in range(40):
		await physics_frame # let the finished items' fade-out tweens complete
	var live := 0
	for c in game.world.get_children():
		if str(c.name).begins_with("Debris_") and not c.is_queued_for_deletion():
			live += 1
	var live_names := []
	for c in game.world.get_children():
		if str(c.name).contains("Debris_") and not c.is_queued_for_deletion():
			live_names.append(str(c.name))
	check(live == left_before, "E loading twice does not duplicate debris (%d live, %d expected) %s" % [live, left_before, str(live_names.slice(0, 6))])
	# ---- finishing the site: Walt's letter, the gift once, the hillside opens
	game.hud.close_card()
	st.upgrades["larger_backpack"] = true
	st.upgrades["hauling_harness"] = true
	var money1: int = st.money
	for id in game.cleanup_nodes.keys():
		var node: Node3D = game.cleanup_nodes[id]
		for k in st.inventory:
			st.inventory[k] = 0
		game.hit_debris(node, 500.0, node.global_position)
		game.hit_debris(node, 500.0, node.global_position)
	check(prog.cleanup["done"] and prog.cleanup_left() == 0 and game.cleanup_nodes.is_empty(), "F clearing the last item completes the site")
	check(st.money == money1 + int(cfg["gift"]), "F Walt's gift of $%d is paid exactly once" % int(cfg["gift"]))
	check(game.hud.card_open() and game.hud.card_title.text.contains("WALT"), "F Walt's letter opens")
	game.hud.close_card()
	check(prog.formation_locked(HID) == "" and not game.formation_nodes[HID].label.text.contains("CLEAR THE SITE"), "F the hillside unlocks")
	var got2: int = game.player_mine(HID, 6 * 5 + 5, 100.0, prog.column_pos(HID, 6 * 5 + 5))
	check(got2 > 0 and prog.units_left(HID) < u0, "F the hillside can now be cut")
	for k in st.inventory:
		st.inventory[k] = 0
	game._save()
	var m: int = st.money
	game._load()
	await process_frame
	check(st.money == m and prog.cleanup["done"] and game.cleanup_nodes.is_empty() and prog.formation_locked(HID) == "", "F after loading, the site stays clean and no second gift is paid")
	# ---- old save (no cleanup block): nothing to clean, hillside open
	var f := FileAccess.open("user://quarry_save.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	data["phase5"].erase("cleanup")
	f = FileAccess.open("user://quarry_save.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	game._load()
	await process_frame
	check(prog.cleanup["done"] and game.cleanup_nodes.is_empty() and prog.formation_locked(HID) == "", "G a save from before the tutorial has no debris and an open hillside")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
