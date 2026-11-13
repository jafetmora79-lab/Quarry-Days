extends SceneTree
## Connected-quarry Phase A: the confirmed foundation fixes. Piece ids for columns of 100+, mineral pockets never lost, saved positions
## below ground, nav refresh after soil changes, same-level proximity, one extraction rule for every source, usable-save validation.
##   godot --headless --fixed-fps 60 -s tests/test_quarry_integrity.gd
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
	game.natural_start_enabled = false
	root.add_child(game)
	await process_frame
	await frames(6)
	for i in range(6):
		if game.walter_dialog:
			game.walter_dialog.skip()
		await frames(30)
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await frames(3)
	var prog: QuarryProgression = game.prog
	prog.cleanup["done"] = true
	var M = game.get_script()
	# ---- 1: piece ids for any column
	var ok := true
	for col in [0, 7, 99, 100, 150, 194, 999]:
		for gen in [1, 5, 120]:
			ok = ok and M.piece_column(M.piece_code(gen, col)) == col
	check(ok, "a loose piece's column survives its id for columns 100 and above")
	check(M.piece_column(7 * 100 + 42) == 42, "ids from older saves (generation * 100 + column) still decode")
	# ---- 2: mineral pockets are never lost
	var id := "hillside_face_01"
	var rec = game.fleet.give("compact_excavator", Vector3(-12, 0, -10), 0.0) if game.fleet.spec("compact_excavator").size() > 0 else {}
	var before: int = game.ground_pieces.size()
	var fake := {"veins": [{"res": "coal", "units": 4}, {"res": "iron_ore", "units": 3}]}
	var full := {"cargo": {"limestone": 999}, "id": 99, "type": "compact_excavator"}
	game.state.inventory["coal"] = 0
	game._vein_bonus(fake, id, 0, "bucket", full)
	check(game.ground_pieces.size() - before == 7, "pocket minerals that do not fit the bucket become loose pieces (%d)" % (game.ground_pieces.size() - before))
	var kinds := {}
	for pid in game.ground_pieces:
		var b: Node = game.ground_pieces[pid]
		if is_instance_valid(b) and str(b.get_meta("resource", "")) in ["coal", "iron_ore"]:
			kinds[str(b.get_meta("resource"))] = int(kinds.get(str(b.get_meta("resource")), 0)) + 1
	check(int(kinds.get("coal", 0)) >= 4 and int(kinds.get("iron_ore", 0)) >= 3, "and they are pieces of the right mineral %s" % str(kinds))
	# ---- 3: saved positions below ground
	game.player.position = Vector3(0.0, -3.6, 8.0)
	game._save(true)
	game.player.position = Vector3(0.0, 0.2, 8.0)
	game.autosave_enabled = false
	game._load(true)
	check(game.player.position.y < -3.0, "a position saved on a lower terrace is not lifted to the surface (y %.2f)" % game.player.position.y)
	var coal_after := 0
	for pid in game.ground_pieces:
		var b2: Node = game.ground_pieces[pid]
		if is_instance_valid(b2) and str(b2.get_meta("resource", "")) == "coal":
			coal_after += 1
	check(coal_after >= 4, "pocket pieces are saved with their mineral and come back as coal after a load (%d)" % coal_after)
	await frames(8)
	check(game.player.global_position.y > -20.0, "and with no ground there the player is put back on safe ground, not left falling")
	# ---- 4: same-level proximity
	check(game._flat_dist(Vector3(0, 0, 0), Vector3(1, 3.6, 0)) == INF and absf(game._flat_dist(Vector3(0, 0, 0), Vector3(1, 0.4, 0)) - 1.0) < 0.001, "material on another terrace is not 'close'")
	# ---- 5: nav refresh after soil changes
	if game.soil != null:
		game.nav_dirty = false
		var cell: int = game.soil.nearest_cell(Vector3(-10, 0, -20), 100.0)
		if cell >= 0:
			var ex = game.fleet.give("starter_excavator", game.soil.cell_center(cell) + Vector3(0, 0, 5), 0.0)
			await frames(5)
			for nd in game.vehicle_nodes.values():
				if nd.vkind == "excavator":
					nd.global_position = game.soil.cell_center(cell) + Vector3(0, 0.1, 4.5)
					nd.rotation.y = 0.0
					for k in range(120):
						game._excavator_dig(nd, 1.0 / 30.0)
			check(game.nav_dirty or game.nav_rebakes > 0, "removing soil marks the walkable surface for a rebake")
	# ---- 6: one extraction rule for every source
	prog.stage = prog.stage_index("deep") if prog.stage_index("deep") >= 0 else prog.stage
	var low := -1
	for i in range(prog.column_count(id)):
		var cl := prog.chunks_left(id, i)
		if cl > 0 and cl < prog.bench_level(id) and prog.column_minable(id, i) and low < 0:
			low = i
	check(low >= 0, "found an exposed column below the current bench")
	check(prog.extraction_block(id, low, "excavator", 9) != "" and prog.extraction_block(id, low, "crew") != "" and prog.extraction_block(id, low, "rig", 9) != "", "machines and staff must work the current bench")
	check(prog.extraction_block(id, low, "hand") == "", "hand tools may cut any exposed column")
	var srcs: Array = prog.fdef(id)["bench_sources"]
	prog.fdef(id)["bench_sources"] = []
	check(prog.extraction_block(id, low, "excavator", 9) == "", "the bench rule is data: with no bench sources the excavator may cut it")
	prog.fdef(id)["bench_sources"] = srcs
	check(prog.extraction_block(id, 9999, "hand") != "", "a column that does not exist is refused")
	check(prog.extraction_block(id, low, "hand") == "" and prog.extraction_block(id, low, "excavator", 0) != "", "an excavator too weak for the rock is refused by the same rule")
	# ---- 7: usable saves
	var f := FileAccess.open(game.SAVE_PATH, FileAccess.WRITE)
	f.store_string('{"pieces": []}')                       # valid JSON, but not a save
	f.close()
	check(game._save_usable(game.SAVE_PATH) == null, "a file that parses but holds no game state is not a usable save")
	game._save(true)
	check(game._save_usable(game.SAVE_PATH) != null, "a normal save is usable")
	var good_before: String = FileAccess.get_file_as_string(game.SAVE_PATH)
	var f2 := FileAccess.open(game.SAVE_PATH, FileAccess.WRITE)
	f2.store_string('{"pieces": [], "money": 1}')           # broken main save
	f2.close()
	var bf := FileAccess.open(game.SAVE_BACKUP, FileAccess.WRITE)
	bf.store_string(good_before)
	bf.close()
	check(game._read_save() != null and int(game._read_save().get("money", -1)) != 1, "a broken main save falls back to the good backup")
	game._save(true)
	check(game._save_usable(game.SAVE_BACKUP) != null, "saving over a broken file does not overwrite the good backup with it")
	for path in [game.SAVE_PATH, game.SAVE_BACKUP]:
		DirAccess.remove_absolute(path)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
