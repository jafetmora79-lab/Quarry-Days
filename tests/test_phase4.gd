extends SceneTree
## Phase 4 tests: sustainable resources + art-overhaul integrity (no visual checks).
##   godot --headless --fixed-fps 60 -s tests/test_phase4.gd

var checks := 0
var failures := []
var cfg: Dictionary

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)
	else:
		print("PASS: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func frames(n: int, until: Callable = Callable()) -> int:
	for i in range(n):
		await physics_frame
		if until.is_valid() and until.call():
			return i
	return n

func run_tests() -> void:
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy.json"))
	test_stock_logic()
	await scene_resources()
	await scene_world()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

# ------------------------------------------------------------------ pure resource logic

func test_stock_logic() -> void:
	var s := QuarryState.new(cfg)
	var d := s.ensure_deposit("limestone", "limestone")
	check(int(d["stock"]) == 24 and not d["broken"], "deposit starts with a visible full stock")
	var taken := 0
	for i in range(10):
		taken += s.mine_yield("limestone", 4)
	check(taken == 24 and int(d["stock"]) == 0 and d["broken"], "stock depletes after exactly 24 units (6 breaks)")
	check(s.mine_yield("limestone", 4) == 0, "an empty deposit yields nothing")
	s.clock_minutes += 2.9
	s.regrow_deposits()
	check(int(d["stock"]) == 0, "nothing regrows before the interval")
	s.clock_minutes += 0.2
	s.regrow_deposits()
	check(int(d["stock"]) == 1 and not d["broken"], "one unit regrows after 3 in-game minutes and the deposit is minable again")
	s.clock_minutes += 300
	s.regrow_deposits()
	check(int(d["stock"]) == 24 and float(d["regrow_at"]) < 0.0, "a deposit refills to its cap and stops (no overflow)")
	var iron := s.ensure_deposit("iron_ore", "iron_ore")
	s.mine_yield("iron_ore", 8)
	s.clock_minutes += 36
	s.regrow_deposits()
	check(int(iron["stock"]) == 3, "rarer iron regrows more slowly (3 units in 36 min)")
	var face := s.ensure_deposit("limestone_face", "limestone", true)
	var total := 0
	for i in range(50):
		total += s.mine_yield("limestone_face", 2)
	check(total == 100 and not face["broken"], "quarry face never runs out")
	var old := QuarryState.new(cfg)
	old.deposits = {"coal": {"hits": 1, "ready_at": 900.0, "broken": true, "generation": 3}, "iron_ore": {"hits": 0, "ready_at": 0.0, "broken": false}}
	var c := old.ensure_deposit("coal", "coal")
	var i2 := old.ensure_deposit("iron_ore", "iron_ore")
	check(int(c["stock"]) == 0 and c["broken"] and int(c["generation"]) == 3 and int(i2["stock"]) == 8, "Phase 1-3 deposits migrate: broken -> empty and regrowing, intact -> full")
	old.clock_minutes += 6.5
	old.regrow_deposits()
	old.regrow_deposits()
	check(int(c["stock"]) == 1, "migrated empty deposit regrows")

# ------------------------------------------------------------------ in-game resources

func scene_resources() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.prog.stage = game.prog.stage_index("large") # Phase 5 stage gates (tested in test_phase5)
	await process_frame
	await physics_frame
	game.tutorial_visible = false
	check(game.player != null and game.deposit_nodes.has("limestone_face"), "1 game starts with the hand-mining quarry face")
	# Phase 5: the small regrowing rocks became finite formations; the quarry face is still the recovery path.
	var iron: int = game.prog.max_units("iron_mountain")
	game.state.tool_tier = 4
	var taken := 0
	for i in range(400):
		for k in game.state.inventory:
			game.state.inventory[k] = 0
		taken += game.player_mine("iron_mountain", -1, 200.0)
		if game.prog.units_left("iron_mountain") <= 0:
			break
	check(taken == iron and game.prog.units_left("iron_mountain") == 0, "2 hand mining takes exactly the formation's units (%d/%d)" % [taken, iron])
	var body = game.deposit_nodes["iron_mountain"]
	var enabled := 0
	for cs in body.shapes:
		enabled += 0 if cs.disabled else 1
	check(enabled == 0 and str(body.label.text).contains("CLEARED"), "2 a cleared formation has no colliders left and says so")
	check(game.player_mine("iron_mountain", -1, 200.0) == 0, "2 mining a cleared formation produces nothing")
	game.state.clock_minutes += 600.0
	await frames(2)
	check(game.prog.units_left("iron_mountain") == 0, "2 formations are finite: nothing regrows")
	# recovery from zero: no money, nothing loose, formations empty -> quarry face
	game.state.tool_tier = 0
	for id in game.ground_pieces.keys():
		game.ground_pieces[id].queue_free()
		game.ground_pieces.erase(id)
	game.state.money = 0
	for k in game.state.inventory:
		game.state.inventory[k] = 0
		game.state.storage[k] = 0
	for b in range(3):
		for n in range(5):
			game._strike("limestone_face")
	check(int(game.state.inventory["limestone"]) == 6, "3 broke player can still hand-mine the quarry face (3 breaks -> 6 stone)")
	check(game.state.sell("limestone", 99) == 6 and game.state.money == 30, "3 face limestone sells: $0 -> $30, recovery possible without free money")
	# staff draw from the same formation units, with conservation
	game.state.money = 2000
	game.state.clock_minutes = 480.0
	game.business.payroll_minute = 480
	game.ui_hire("rosa")
	var miner: Dictionary = game.business.employees[0]
	game.business.set_shift(int(miner["id"]), 0, 1439)
	check(game.nearest_deposit("limestone", Vector3.ZERO) == "stone_mountain", "4 miners target the stone formation, never the hand-mining face")
	Engine.time_scale = 4.0
	var d: Dictionary = game.state.deposits["stone_mountain"]
	var hd: Dictionary = game.state.deposits["hillside_face_01"]
	var mined0 := int(d.get("mined", 0)) + int(hd.get("mined", 0))
	var storage0 := int(game.state.storage["limestone"])
	await frames(5000, func(): return int(game.state.storage["limestone"]) >= storage0 + 4)
	var used := int(d.get("mined", 0)) + int(hd.get("mined", 0)) - mined0 # staff take the nearest face: the new hillside or the old pile
	check(int(game.state.storage["limestone"]) >= storage0 + 4 and used >= 4, "4 worker mining draws from the formation (%d used)" % used)
	var loose := 0
	for id in game.ground_pieces:
		if str(game.ground_pieces[id].get_meta("resource")) == "limestone":
			loose += 1
	var carried: int = game.business.carry_total(miner)
	check(int(game.state.storage["limestone"]) - storage0 + carried + loose == used, "4 limestone conserved: storage + carried + loose == units taken from the formation (%d)" % used)
	Engine.time_scale = 1.0
	game.queue_free()
	await process_frame

func aim(game, pos: Vector3, yaw: float, pitch: float) -> String:
	game.player.global_position = pos
	game.player.rotation.y = yaw
	game.player.camera.rotation.x = pitch
	var t = game._look_target()
	return "" if t == null else str(t.get_meta("kind", ""))

func path_ok(game, a: Vector3, b: Vector3) -> bool:
	var p: PackedVector3Array = NavigationServer3D.map_get_path(game.nav_map, a, b, true)
	return p.size() > 0 and Vector2(p[p.size() - 1].x, p[p.size() - 1].z).distance_to(Vector2(b.x, b.z)) < 1.0

func scene_world() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.prog.stage = game.prog.stage_index("large") # Phase 5 stage gates (tested in test_phase5)
	await process_frame
	await physics_frame
	await physics_frame
	game.tutorial_visible = false
	game.scripted_input = true
	# 1 startup with the art layer
	var meshes: Array = game.art.root.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() > 80 and game.art.lights.size() >= 4, "1 art layer built (%d meshes, %d practical lights)" % [meshes.size(), game.art.lights.size()])
	var dep_mesh: MeshInstance3D = game.deposit_nodes["coal_mountain"].chunks[0][0]
	check(dep_mesh.mesh is ArrayMesh and not (dep_mesh.mesh is BoxMesh), "1 deposits are modelled rock formations, not boxes")
	var floor_body = game.world.get_node("Quarry floor")
	check(not floor_body.get_child(0).visible and floor_body.collision_layer == 1, "1 placeholder floor hidden, its collision unchanged")
	# 7 building interactions still reachable through the new geometry
	check(aim(game, Vector3(-14, 0.05, 11.4), PI, -0.5) == "office", "7 management desk inside the office is interactable")
	check(aim(game, Vector3(-7, 0.05, 7.6), PI, -0.3) == "sell", "7 sales booth counter is interactable")
	check(aim(game, Vector3(-14, 0.05, 6.6), PI, 0.0) == "upgrades", "7 upgrade notice board is interactable")
	check(aim(game, Vector3(-2, 0.05, 7.8), PI, -0.3) == "shop", "7 machinery order kiosk is interactable")
	check(aim(game, Vector3(10, 0.05, 7.6), PI, -0.3) == "storage", "7 storage bin is interactable")
	# 8 worker navigation through the dressed quarry
	await frames(3)
	var spot: Vector3 = game.break_spot(0)
	check(path_ok(game, spot, Vector3(-7.0, 0, 12.0)), "8 break area -> sales booth is walkable")
	check(path_ok(game, spot, Vector3(-10.0, 0, -5.0)), "8 break area -> stone formation face is walkable")
	check(path_ok(game, spot, Vector3(10.0, 0, 7.8)), "8 break area -> storage bin is walkable")
	check(path_ok(game, Vector3(0, 0, 8), Vector3(5.5, 0, 12.5)) and path_ok(game, Vector3(5.5, 0, 12.5), Vector3(20.0, 0, 7.5)), "8 yard, garage apron and haul road are connected")
	# 6 vehicles: drive out of the garage bay, and cannot reverse through the garage back wall
	game.state.money = 50000
	game.business.milestones["mechanized"] = true
	check(game.ui_buy_vehicle("loader").ends_with("parking area."), "6 loader delivered into the garage bay")
	game.delivery.finish_all()
	var loader = game.vehicle_nodes.values()[0]
	game.enter_vehicle(loader)
	await frames(5)
	loader.input = {"throttle": -1.0, "steer": 0.0, "brake": false}
	var zmax := {"z": -99.0}
	await frames(180, func():
		zmax["z"] = maxf(zmax["z"], loader.global_position.z)
		return false)
	check(zmax["z"] < 22.4 - 0.125 - 1.5 + 0.15, "6 loader stops at the garage back wall (rear centre z %.2f)" % zmax["z"])
	loader.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
	await frames(30)
	loader.global_position = Vector3(-1.5, 0.05, 18.5)
	loader.rotation.y = 0.0
	loader.speed = 0.0
	loader.input = {"throttle": 1.0, "steer": 0.0, "brake": false}
	await frames(150, func(): return loader.global_position.z < 12.0)
	check(loader.global_position.z < 13.0, "6 loader drives out of its bay through the open garage front (z %.2f)" % loader.global_position.z)
	loader.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
	# 5 loader scoop + dump with the modelled rubble mound
	var pile: Vector3 = game.pile_nodes["coal_rubble"].global_position
	loader.global_position = Vector3(pile.x, 0.05, pile.z + 3.6)
	loader.rotation.y = 0.0
	loader.speed = 0.0
	await frames(5)
	var got: int = game.loader_primary(loader)
	check(got == 6 and int(game.fleet.piles["coal_rubble"]["amount"]) == 24, "5 loader scoops 6 coal from the modelled rubble mound")
	loader.global_position = Vector3(10, 0.05, 7.4)
	loader.rotation.y = PI
	await frames(5)
	var coal0 := int(game.state.storage["coal"])
	check(game.vehicle_dump(loader) == 6 and int(game.state.storage["coal"]) == coal0 + 6, "5 loader dumps 6 coal into the storage bin")
	game.exit_vehicle()
	# 9 Phase 3 save (no deposit stock fields) loads into Phase 4
	game._save()
	var f := FileAccess.open("user://quarry_save.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	# Rebuild it as a Phase 3 save: the three small deposits, no formations, no Phase 5 data.
	for k in data["deposits"].keys():
		if k != "limestone_face":
			data["deposits"].erase(k)
	data["deposits"]["coal"] = {"hits": 1, "broken": true, "generation": 3}
	data["deposits"]["iron_ore"] = {"hits": 0, "broken": false}
	data["deposits"].erase("limestone_face")
	for key in ["phase5", "tool_tier", "earned"]:
		data.erase(key)
	data["pieces"] = ["coal_3_0", "coal_3_1"]
	var coal_before := int(data["storage"]["coal"])
	f = FileAccess.open("user://quarry_save.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	game._load()
	await process_frame
	check(not game.state.deposits.has("coal") and not game.state.deposits.has("iron_ore") and game.prog.units_left("coal_mountain") == game.prog.max_units("coal_mountain"), "9 Phase 3 save migrates: small deposits replaced by full formations")
	check(int(game.state.storage["coal"]) == coal_before + 2 and game.ground_pieces.size() == 0, "9 loose pieces of the old deposits are returned to storage, not lost")
	check(game.state.tool_tier == 1 and game.prog.stage >= game.prog.stage_index("industry") and game.prog.story["intro_seen"], "9 old players keep their pickaxe, a stage matching their loader, and skip the intro")
	check(game.deposit_nodes.has("limestone_face") and game.state.deposits["limestone_face"]["infinite"], "9 old saves gain the quarry face")
	game._load()
	await process_frame
	await process_frame
	check(game.vehicles_root.get_child_count() == 1 and game.vehicle_nodes.size() == 1, "9 repeated load keeps one loader")
	game.queue_free()
	await process_frame
