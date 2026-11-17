extends SceneTree
## Dig prototype tests (headless, accelerated):  godot --headless --fixed-fps 60 -s tests/test_dig.gd

var checks := 0
var failures := []

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

func ray_down(game, x: float, z: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 12, z), Vector3(x, -6, z), 1)
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"].y if hit else -99.0

func place(game, pos: Vector3, yaw := 0.0) -> void:
	var l = game.loader
	l.global_position = pos
	l.rotation.y = yaw
	l.speed = 0.0
	l.velocity = Vector3.ZERO

func drive(game, throttle: float, dig: bool, dump: bool, n: int, until: Callable = Callable()) -> int:
	game.loader.driven = true
	game.loader.input = {"throttle": throttle, "steer": 0.0, "brake": false, "dig": dig, "dump": dump}
	var f := await frames(n, until)
	game.loader.input = {"throttle": 0.0, "steer": 0.0, "brake": true, "dig": false, "dump": false}
	return f

func max_slope_near(game, cx: float, cz: float, r: float) -> float:
	var t: DigTerrain = game.terrain
	var worst := 0.0
	var g: Vector2 = t.to_grid(Vector3(cx, 0, cz))
	var reach := int(r / t.CELL)
	for j in range(int(g.y) - reach, int(g.y) + reach):
		for i in range(int(g.x) - reach, int(g.x) + reach):
			if i < 1 or j < 1 or i >= t.N or j >= t.N:
				continue
			var h: float = t.vheight(t.idx(i, j))
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				worst = maxf(worst, absf(h - t.vheight(t.idx(i + d.x, j + d.y))) / t.CELL)
	return worst

func run_tests() -> void:
	var game = load("res://DigTest.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame
	var T0: float = game.accounted_total()
	var terrain: DigTerrain = game.terrain
	check(T0 > 100.0 and terrain.N == 80 and terrain.chunk_nodes.size() == 25, "1 arena built: %.1f m3 of material, 25 terrain chunks" % T0)
	check(game.loader != null and game.player != null and game.box_walls != null, "1 loader, player and collection box present")
	# --- collision follows the heightfield (also proves the 0.5 m heightmap scale is right)
	var hp := terrain.height_at(-8.0, -4.0)
	check(hp > 2.2 and absf(ray_down(game, -8.0, -4.0) - hp) < 0.06, "2 collision matches the dirt pile summit (%.2f m vs ray %.2f m)" % [hp, ray_down(game, -8.0, -4.0)])
	check(absf(ray_down(game, 0.0, 5.0)) < 0.05 and absf(ray_down(game, 12.3, 3.1) - terrain.height_at(12.3, 3.1)) < 0.06, "2 flat ground and an off-grid point also match")
	# --- shovel: exact volume, capacity, conservation
	game.player.global_position = Vector3(0, 0.3, 8.0)
	game.player.rotation.y = 0.0
	game.player.camera.rotation.x = -0.62
	await frames(3)
	var before: float = terrain.total_volume()
	var spot0: Vector3 = game.aim_point()
	var h_before: float = terrain.height_at(spot0.x, spot0.z)
	var got: float = game.shovel_dig()
	check(got > 0.0 and absf(game.shovel_total() - got) < 1e-5 and absf((before - terrain.total_volume()) - got) < 1e-3, "3 shovel dig removes %.3f m3 from the ground and puts exactly that on the shovel" % got)
	var spot := spot0
	for k in range(6):
		game.shovel_cooldown = 0.0
		game.shovel_dig()
	check(game.shovel_total() <= game.SHOVEL_CAPACITY + 1e-4 and game.shovel_total() > game.SHOVEL_CAPACITY - 0.01, "3 shovel fills to its capacity (%.3f of %.2f m3) and no further" % [game.shovel_total(), game.SHOVEL_CAPACITY])
	game.shovel_cooldown = 0.0
	check(game.shovel_dig() == 0.0, "3 a full shovel cannot dig more")
	check(terrain.height_at(spot.x, spot.z) < h_before - 0.04, "3 the ground is visibly lower where you dug")
	await frames(8)
	check(ray_down(game, spot.x, spot.z) < h_before - 0.03, "3 collision follows the hole (ray %.2f m, was %.2f m)" % [ray_down(game, spot.x, spot.z), h_before])
	check(absf(game.accounted_total() - T0) < 0.01, "3 total material unchanged by shovelling")
	# --- shovel into the box
	game.player.global_position = Vector3(0, 0.3, -8.0)
	game.player.camera.rotation.x = -0.12
	game.shovel_cooldown = 0.0
	await frames(3)
	game.shovel_cooldown = 0.0
	var held: float = game.shovel_total()
	var thrown: float = game.shovel_throw()
	check(held > 0.0 and absf(thrown - held) < 1e-5 and absf(game.box_total() - held) < 1e-5 and game.shovel_total() == 0.0, "4 aiming at the box throws the whole shovelful in (%.3f m3)" % game.box_total())
	check(absf(game.accounted_total() - T0) < 0.01, "4 total material unchanged after the throw")
	game.player.global_position = Vector3(18.0, 0.3, 17.0)         # out of the way of the loader tests
	# --- loader: scoop real volume, capacity, collision
	place(game, Vector3(-8.0, 0.15, 4.2), 0.0)
	await frames(10)
	var pile_h0 := terrain.height_at(-8.0, -1.0)
	await drive(game, 0.0, true, false, 90)
	await drive(game, 0.55, true, false, 420, func(): return game.loader.load_total() >= 1.58)
	var L: DigLoader = game.loader
	check(L.load_total() > 0.5, "5 loader scooped %.2f m3 by driving into the dirt pile" % L.load_total())
	check(L.load_total() <= L.BUCKET_CAPACITY + 1e-3, "5 bucket never exceeds its %.1f m3 capacity (%.3f)" % [L.BUCKET_CAPACITY, L.load_total()])
	check(absf(game.accounted_total() - T0) < 0.02, "5 loader digging conserves material (%.4f vs %.4f)" % [game.accounted_total(), T0])
	check(terrain.height_at(-8.0, -1.0) < pile_h0 - 0.05, "5 the pile got lower where the bucket cut (%.2f -> %.2f m)" % [pile_h0, terrain.height_at(-8.0, -1.0)])
	var z_before: float = L.global_position.z
	await drive(game, 0.7, true, false, 240)
	check(L.load_total() <= L.BUCKET_CAPACITY + 1e-3, "5 a full bucket stays at capacity while still driving into the pile")
	check(L.global_position.y > -0.5 and L.global_position.y < 4.0, "5 loader stays on top of the deformed ground (y %.2f)" % L.global_position.y)
	# --- loader collision with the solid box wall
	place(game, Vector3(0.0, 0.2, -4.0), 0.0)
	await frames(10)
	await drive(game, 1.0, false, false, 360)
	check(L.global_position.z < -10.6 and L.global_position.z > -11.7, "6 loader is stopped by the box wall, not through it (z %.2f)" % L.global_position.z)
	# --- dump into the box from the bucket
	var carried: float = L.load_total()
	place(game, Vector3(0.0, 0.2, -10.4), 0.0)
	L.arm_angle = L.RAISED
	await frames(10)
	var box_before: float = game.box_total()
	await drive(game, 0.0, false, true, 330)
	check(game.box_total() > box_before + 0.3, "7 pouring over the box fills it (%.2f m3 in the box)" % game.box_total())
	check(absf(game.accounted_total() - T0) < 0.02, "7 box + bucket + ground + shovel still equal the start (%.4f vs %.4f)" % [game.accounted_total(), T0])
	check(L.load_total() < carried - 0.3, "7 bucket emptied by exactly what the box received")
	# --- dump onto the ground forms a pile that slumps
	L.load_dirt = 1.4          # test setup: put material in the bucket (new baseline below)
	L.load_rock = 0.0
	var T1: float = game.accounted_total()
	place(game, Vector3(-4.0, 0.2, 8.0), 0.0)
	L.arm_angle = L.RAISED
	await frames(10)
	var lp := L.lip_position()
	var hbase := terrain.height_at(lp.x, lp.z - 0.35)
	await drive(game, 0.0, false, true, 300)
	await frames(240)
	var peak := 0.0
	for dz in range(-3, 3):
		for dx in range(-3, 3):
			peak = maxf(peak, terrain.height_at(lp.x + dx * 0.5, lp.z - 0.35 + dz * 0.5))
	check(peak > hbase + 0.25, "8 dumped dirt makes a pile on the ground (%.2f m high)" % (peak - hbase))
	check(absf(game.accounted_total() - T1) < 0.02, "8 pouring on the ground conserves material")
	check(max_slope_near(game, lp.x, lp.z - 0.35, 3.0) < DigTerrain.DIRT_SLOPE * 1.25, "8 the new pile slumps to a believable slope (max %.2f)" % max_slope_near(game, lp.x, lp.z - 0.35, 3.0))
	# --- rock digs as rock
	game.terrain.deposit(Vector3(-4.0, 0, 5.0), 1.2, L.load_total(), L.rock_fraction())   # empty the bucket onto the ground
	L.load_dirt = 0.0
	L.load_rock = 0.0
	place(game, Vector3(8.0, 0.15, 2.4), 0.0)
	await frames(10)
	await drive(game, 0.0, true, false, 90)
	await drive(game, 0.5, true, false, 360, func(): return L.load_total() >= 0.8)
	check(L.load_rock > 0.15 and L.stats["cut"] > 0.0, "9 digging the rock pile loads rock (%.2f m3 rock, %.2f m3 dirt)" % [L.load_rock, L.load_dirt])
	check(absf(game.accounted_total() - T1) < 0.03, "9 rock digging conserves material")
	# --- enter / exit
	game.player.global_position = L.global_position + Vector3(3.0, 0.0, 0.0)
	game.player.global_position.y = terrain.height_at(game.player.global_position.x, game.player.global_position.z) + 0.1
	check(game.enter_loader() and game.driving and not game.player.visible, "10 E enters the loader when standing next to it")
	L.speed = 0.0
	check(game.exit_loader() and not game.driving and game.player.visible, "10 E exits when stopped")
	check(game.player.global_position.distance_to(L.global_position) > 1.4, "10 the player is placed beside the loader, not inside it")
	# --- everything together
	check(absf(game.accounted_total() - T1) < 0.05, "11 after the whole session nothing was created or lost (%.4f vs %.4f m3)" % [game.accounted_total(), T1])
	# --- cost
	var t0 := Time.get_ticks_usec()
	terrain.dirty_chunks.clear()
	for key in terrain.chunk_nodes.keys():
		terrain._build_chunk(key.x, key.y)
	var full := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	terrain._build_chunk(2, 2)
	var one := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	terrain._update_collision()
	var col := (Time.get_ticks_usec() - t0) / 1000.0
	print("COST full mesh rebuild %.1f ms, one chunk %.2f ms, collision refresh %.2f ms" % [full, one, col])
	check(one < 8.0, "12 rebuilding one terrain chunk takes %.2f ms (budget 8 ms)" % one)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

