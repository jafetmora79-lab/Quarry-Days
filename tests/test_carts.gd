extends SceneTree
## Phase 9.6: functional carts. They are real containers: load, push or pull, unload, sell, save, with no unit created or lost.
##   godot --headless --fixed-fps 60 -s tests/test_carts.gd

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

func load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func new_state() -> QuarryState:
	var s := QuarryState.new(load_json("res://data/economy.json"))
	s.carts = ["hand_cart", "wheelbarrow", "reinforced_wheelbarrow"]
	s.money = 0
	return s

func overlapping(game, cart: QuarryCart) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cshape: CollisionShape3D
	for c in cart.get_children():
		if c is CollisionShape3D:
			cshape = c
	q.shape = cshape.shape
	q.transform = cshape.global_transform
	q.margin = -0.04                      # touching is fine, sinking in is not
	q.collision_mask = 1
	q.exclude = [cart.get_rid(), game.player.get_rid()]
	for h in game.get_world_3d().direct_space_state.intersect_shape(q, 8):
		var c = h["collider"]
		if c is StaticBody3D and not c.has_meta("ground"):
			return true
	return false

func run() -> void:
	# ---- A: pure state: capacities, conservation, limits
	var s := new_state()
	check(s.cart_cap("hand_cart") == 20 and s.cart_cap("wheelbarrow") == 40 and s.cart_cap("reinforced_wheelbarrow") == 70, "A the three carts hold 20, 40 and 70 units")
	s.inventory["limestone"] = 18
	s.inventory["coal"] = 10
	s.storage["iron_ore"] = 12
	var start := s.all_units()
	check(s.cart_load_from_bag("wheelbarrow", "limestone", 99) == 18 and s.cart_load_from_bag("wheelbarrow", "coal", 99) == 10, "A load takes everything the bag has (18 stone, 10 coal)")
	check(s.cart_total("wheelbarrow") == 28 and s.all_units() == start, "A the load is in the cart and the total is unchanged")
	check(s.cart_take("wheelbarrow", "iron_ore", 99) == 12 and s.cart_total("wheelbarrow") == 40 and s.cart_space("wheelbarrow") == 0, "A taking from the crate fills the cart exactly to its capacity (40)")
	check(s.cart_take("wheelbarrow", "iron_ore", 5) == 0 and s.cart_load_from_bag("wheelbarrow", "limestone", 5) == 0, "A a full cart takes nothing more")
	check(s.all_units() == start, "A conservation holds after every step (%d units)" % s.all_units())
	check(s.cart_unload_to_bag("hand_cart", "coal", 5) == 0 and s.cart_store("hand_cart", "coal", 5) == 0, "A an empty cart gives nothing")
	var b0 := s.total(s.inventory)
	check(s.cart_unload_to_bag("wheelbarrow", "limestone", 99) == 18 and s.total(s.inventory) == b0 + 18, "A unloading to the bag moves what fits")
	s.inventory["coal"] = s.capacity() - s.total(s.inventory) - 1
	var room := s.capacity() - s.total(s.inventory)
	check(s.cart_unload_to_bag("wheelbarrow", "coal", 99) == room and s.cart_units("wheelbarrow", "coal") == 10 - room, "A a nearly full bag takes only what fits; the rest stays in the cart")
	var u1 := s.all_units()
	var money0 := s.money
	var sold := s.cart_sell("wheelbarrow", "iron_ore", 12)
	check(sold == 12 and s.all_units() == u1 - 12 and s.money == money0 + int(round(12.0 * s.unit_price("iron_ore"))), "A selling from a cart removes exactly the units sold and pays the stage price")
	check(s.cart_sell("wheelbarrow", "iron_ore", 5) == 0, "A the same units cannot be sold twice")
	# random transfers: units are conserved apart from what was sold
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var t := new_state()
	t.inventory["limestone"] = 10
	t.inventory["coal"] = 6
	t.storage["limestone"] = 25
	var sold_total := 0
	var base := t.all_units()
	var ok := true
	for i in range(400):
		var id: String = t.carts[rng.randi() % 3]
		var key: String = ["limestone", "coal", "iron_ore"][rng.randi() % 3]
		var n := rng.randi_range(1, 25)
		match rng.randi() % 6:
			0: t.cart_load_from_bag(id, key, n)
			1: t.cart_unload_to_bag(id, key, n)
			2: t.cart_store(id, key, n)
			3: t.cart_take(id, key, n)
			4: sold_total += t.cart_sell(id, key, n)
			5: t.add_item(key, n) if false else null
		var step_ok: bool = t.all_units() == base - sold_total and t.cart_total(id) <= t.cart_cap(id) and t.total(t.inventory) <= t.capacity() and t.total(t.storage) <= t.storage_capacity()
		if not step_ok and ok:
			printerr("   step %d: all %d base-sold %d cart %d bag %d/%d store %d/%d" % [i, t.all_units(), base - sold_total, t.cart_total(id), t.total(t.inventory), t.capacity(), t.total(t.storage), t.storage_capacity()])
		ok = ok and step_ok
	check(ok, "A 400 random transfers: nothing created or lost, no container over capacity (sold %d)" % sold_total)
	# ---- B: save / load
	var cs := new_state()
	cs.cart_load["wheelbarrow"] = {"limestone": 15, "coal": 8}
	cs.cart_pos["wheelbarrow"] = [3.0, 0.0, 4.0, 1.2]
	var snap := cs.snapshot()
	var back := QuarryState.new(load_json("res://data/economy.json"))
	check(back.restore(snap) and back.cart_units("wheelbarrow", "limestone") == 15 and back.cart_units("wheelbarrow", "coal") == 8 and back.cart_pos["wheelbarrow"][3] == 1.2, "B contents and position survive saving")
	var again := back.snapshot()
	check(back.restore(again) and back.cart_total("wheelbarrow") == 23, "B loading twice does not duplicate anything")
	var bad := snap.duplicate(true)
	bad["cart_load"] = {"wheelbarrow": {"limestone": 9999}, "ghost_cart": {"coal": 50}, "hand_cart": {"gold_ore": -5, "magic": 7}}
	var fixed := QuarryState.new(load_json("res://data/economy.json"))
	fixed.restore(bad)
	check(fixed.cart_total("wheelbarrow") == 40 and not fixed.cart_load.has("ghost_cart") and fixed.cart_total("hand_cart") == 0, "B a damaged save cannot make a cart hold more than its capacity or carry unknown items")
	# ---- C: in the game
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
	game._cine_tween().kill()                 # the opening scene would otherwise keep walking the player
	game._remove_walter()
	await process_frame
	var prog: QuarryProgression = game.prog
	prog.cleanup["done"] = true
	prog.stage = prog.stage_index("deep")
	game.state.money = 100000
	game.safety.enabled = false
	for id in ["hand_cart", "wheelbarrow", "reinforced_wheelbarrow"]:
		prog.buy_gear(id) if id == "hand_cart" else null
	check(prog.buy_gear("wheelbarrow") and prog.buy_gear("reinforced_wheelbarrow"), "C the carts are bought through the normal unlock rules")
	game._refresh_workbench()
	await frames(3)
	check(game.cart_nodes.size() == 3, "C each bought cart stands in the yard as its own object (%d)" % game.cart_nodes.size())
	var wb: QuarryCart = game.cart_nodes["wheelbarrow"]
	check(str(wb.get_meta("kind")) == "cart" and wb.get_child_count() >= 2, "C a cart can be targeted and interacted with")
	game._interact(wb)
	check(game.menu == "cart", "C E on a cart opens its menu")
	game.state.inventory["limestone"] = 10
	game.state.inventory["coal"] = 6
	var all0: int = game.state.all_units()
	game.cart_move("load", "wheelbarrow", "limestone")
	game.cart_move("load", "wheelbarrow", "coal")
	check(game.state.cart_total("wheelbarrow") == 16 and game.state.all_units() == all0, "C loading from the bag through the menu moves 16 units")
	game._close_menu()
	# visible cargo
	var load_node: Node3D = wb.model.get_node("Load")
	var mat_stone: Material = (load_node.get_meta("pile") as MeshInstance3D).material_override
	var scale_20: float = load_node.scale.y
	game.cart_move("unload", "wheelbarrow", "limestone")
	var mat_coal: Material = (load_node.get_meta("pile") as MeshInstance3D).material_override
	check(load_node.visible and mat_coal != mat_stone and load_node.scale.y < scale_20, "C the cargo shows the material (stone, then coal) and shrinks as it is unloaded")
	game.cart_move("unload", "wheelbarrow", "coal")
	check(not load_node.visible, "C an empty cart shows no cargo")
	# pushing: smooth, held at the handles, slowed
	game.state.inventory["limestone"] = 0
	game.state.inventory["coal"] = 0
	game.player.locked = false
	game.player.global_position = Vector3(-4.0, 0.2, 16.0)
	game.player.rotation.y = -PI * 0.5            # facing +x
	print("   tp0 ", game.player.global_position)
	await physics_frame
	print("   tp1 ", game.player.global_position, " on_floor ", game.player.is_on_floor(), " vel ", game.player.velocity, " parent ", game.player.get_parent().name)
	await frames(2)
	wb.global_position = Vector3(-4.0 + 1.8, 0.05, 16.0)
	wb.rotation.y = game.player.rotation.y
	print("   state: sleeping %s driving %s locked %s pos %s" % [str(game.sleeping), str(game.driving), str(game.player.locked), str(game.player.global_position)])
	game.hold_cart("wheelbarrow")
	check(game.held_cart == wb and absf(game.player.speed_mult - 0.8) < 0.001, "C grabbing a cart slows the player a little")
	var last := wb.global_position
	var max_step := 0.0
	game.player.drive_wish = Vector3(1, 0, 0)
	for i in range(90):
		await physics_frame
		if i % 15 == 0:
			print("   push i=%d player %s cart %s held %s" % [i, str(game.player.global_position.snapped(Vector3(0.1, 0.1, 0.1))), str(wb.global_position.snapped(Vector3(0.1, 0.1, 0.1))), str(game.held_cart != null)])
		max_step = maxf(max_step, wb.global_position.distance_to(last))
		last = wb.global_position
	game.player.drive_wish = Vector3.ZERO
	await frames(10)
	var gap: float = Vector2(wb.global_position.x - game.player.global_position.x, wb.global_position.z - game.player.global_position.z).length()
	check(game.player.global_position.x > -1.0 and gap > 1.2 and gap < 2.6, "C the cart travels with the player and stays at the handles (gap %.2f m)" % gap)
	check(max_step < 0.2, "C it moves smoothly: at most %.3f m in a frame" % max_step)
	# collision: pushed into the storage crate it stops outside it
	game.player.global_position = Vector3(5.0, 0.2, 10.0)
	game.player.rotation.y = -PI * 0.5
	wb.global_position = Vector3(6.8, 0.05, 10.0)
	await frames(3)
	game.player.drive_wish = Vector3(1, 0, 0)
	for i in range(160):
		await physics_frame
	game.player.drive_wish = Vector3.ZERO
	await frames(5)
	check(not overlapping(game, wb), "C the cart cannot be pushed through the storage crate (it stops at x %.2f, the crate begins at 9.0)" % wb.global_position.x)
	check(wb.global_position.x < 9.0 or game.held_cart == null, "C and it never ends up on the far side")
	game.release_cart()
	check(game.held_cart == null and absf(game.player.speed_mult - 1.0) < 0.001, "C letting go restores the player's speed")
	# hand cart is pulled from the front
	var hc: QuarryCart = game.cart_nodes["hand_cart"]
	game.player.global_position = Vector3(2.0, 0.2, 19.0)
	game.player.rotation.y = -PI * 0.5
	hc.global_position = Vector3(0.0, 0.05, 19.0)
	hc.rotation.y = game.player.rotation.y
	await frames(3)
	game.hold_cart("hand_cart")
	game.player.drive_wish = Vector3(1, 0, 0)
	await frames(60)
	game.player.drive_wish = Vector3.ZERO
	await frames(10)
	check(hc.global_position.x < game.player.global_position.x - 1.2, "C the hand cart follows behind the player (pulled)")
	game.release_cart()
	# ---- D: stations
	var cart_id := "reinforced_wheelbarrow"
	var rw: QuarryCart = game.cart_nodes[cart_id]
	game.state.inventory["limestone"] = 30
	game.state.inventory["iron_ore"] = 0
	game.cart_move("load", cart_id, "limestone")
	var u0: int = game.state.all_units()
	rw.global_position = Vector3(-19.0, 0.05, 11.0)
	var money0b: int = game.state.money
	check(game.cart_move("sell", cart_id, "limestone") == 0 and game.state.money == money0b, "D far from the selling station nothing is sold")
	check(game.cart_move("store", cart_id, "limestone") == 0, "D and far from the crate nothing is stored")
	rw.global_position = game.sell_body.global_position + Vector3(0, -0.8, 2.5)
	var sold_n: int = game.cart_move("sell", cart_id, "limestone", 10)
	check(sold_n == 10 and game.state.all_units() == u0 - 10 and game.state.money == money0b + int(round(10.0 * game.state.unit_price("limestone"))), "D at the selling station the cart sells units and pays the stage price")
	rw.global_position = game.storage_body.global_position + Vector3(-2.5, -0.6, 0)
	var stored: int = game.cart_move_all("store", cart_id)
	check(stored == 20 and game.state.cart_total(cart_id) == 0 and int(game.state.storage["limestone"]) >= 20, "D at the crate the whole load goes into storage (%d units)" % stored)
	var taken: int = game.cart_move("take", cart_id, "limestone", 12)
	check(taken == 12 and game.state.cart_units(cart_id, "limestone") == 12, "D and it can be loaded from the crate")
	# ---- E: save and load through the real save file
	game.state.cart_load[cart_id] = {"limestone": 9, "coal": 7}
	rw.global_position = Vector3(-19.0, 0.05, 12.0)
	game.state.cart_pos[cart_id] = [-19.0, 0.05, 12.0, 0.5]
	var units_saved: int = game.state.all_units()
	game._save(true)
	game.state.cart_load[cart_id] = {"coal": 1}
	game.state.inventory["limestone"] = 77
	game._load(true)
	await frames(4)
	check(game.state.cart_units(cart_id, "limestone") == 9 and game.state.cart_units(cart_id, "coal") == 7 and game.state.all_units() == units_saved, "E the cart's contents come back from the save file exactly (%d units)" % game.state.all_units())
	check(game.cart_nodes.size() == 3 and absf(game.cart_nodes[cart_id].global_position.z - 12.0) < 0.6, "E the carts are back where they were left, one of each")
	game._load(true)
	await frames(3)
	check(game.state.all_units() == units_saved and game.cart_nodes.size() == 3, "E loading again changes nothing")
	# ---- F: unlocks unchanged
	var fresh_prog := QuarryProgression.new(QuarryState.new(load_json("res://data/economy.json")), QuarryBusiness.new(QuarryState.new(load_json("res://data/economy.json")), load_json("res://data/business.json")), load_json("res://data/progression.json"))
	check(fresh_prog.gear_block_reason("hand_cart").contains("Stage 2") and fresh_prog.gear_block_reason("wheelbarrow").contains("Stage 3"), "F cart unlocks are unchanged (hand cart at Better Tools, wheelbarrows at The Workshop)")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
