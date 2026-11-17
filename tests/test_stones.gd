extends SceneTree
## Breaking the cleanup rubble drops loose stones beside the player (nothing goes into the bag by itself); a stone is picked up into the bag, or - with a bucket in reach - thrown into it;
## E on a bucket throws the bag's stones in with a toss; nothing is created or lost; stones survive a save.   Run through tools/run_tests.sh.
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
	await frames(8)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await frames(20)
	var st = game.state
	var pb: PlacedBuckets = game._buckets()
	check(st.capacity() == st.bucket_capacity(), "the bag is back: it holds one bucket's worth (%d)" % st.capacity())
	# ---- breaking a rubble heap
	var heap_id := ""
	for id in game.cleanup_nodes:
		if not str(id).begins_with("w"):
			heap_id = str(id)
			break
	check(heap_id != "", "there is a rubble heap to clear")
	var node: Node3D = game.cleanup_nodes[heap_id]
	var bag0: int = st.total(st.inventory)
	var left0: int = game.prog.heap_units_left(heap_id)
	game.hit_debris(node, 25.0, node.global_position)            # enough for two stones
	await frames(2)
	var broken: int = left0 - game.prog.heap_units_left(heap_id)
	check(broken >= 1 and game.debris_stones.size() == broken, "%d stone(s) broke off and lie on the ground" % broken)
	check(st.total(st.inventory) == bag0, "and none of them went into the bag by itself")
	var near := true
	for sid in game.debris_stones:
		near = near and (game.debris_stones[sid] as Node3D).global_position.distance_to(game.player.global_position) < 2.0
	check(near, "the stones land next to the player")
	# ---- pick one up into the bag (no bucket around)
	var first: Node3D = game.debris_stones.values()[0]
	game._interact(first)
	await frames(2)
	check(st.total(st.inventory) == bag0 + 1 and game.debris_stones.size() == broken - 1, "E on a stone puts it in the bag (%d)" % st.total(st.inventory))
	# ---- with a bucket in reach the stone is thrown into it
	var ground: Vector3 = game.player.global_position + game.player.global_transform.basis.x * 1.6
	ground.y = game._ground_y_at(ground)
	var b: Dictionary = pb.place(ground, {}, 0.0)
	await frames(3)
	var bag1: int = st.total(st.inventory)
	if game.debris_stones.size() > 0:
		game._interact(game.debris_stones.values()[0])
	else:
		game._drop_debris_stone()
		game._interact(game.debris_stones.values()[0])
	check(int(b["body"].get_meta("pending", 0)) == 1, "with a bucket in reach the stone is in the air towards it")
	await frames(60)
	check(pb.total_of(b["load"]) == 1 and st.total(st.inventory) == bag1, "it lands in the bucket (%d) and the bag is untouched" % pb.total_of(b["load"]))
	# ---- throw the bag's stones in
	st.inventory["limestone"] = 6
	st.inventory["topsoil"] = 0
	var total_before: int = st.total(st.inventory) + pb.total_of(b["load"])
	var moved: int = game.throw_bag_into_bucket(b["body"])
	check(moved == 6 and st.total(st.inventory) == 0, "E on the bucket throws the whole bag in (%d)" % moved)
	check(game.player.tool_view.throw_t >= 0.0, "the hand reaches to the hip and tosses")
	await frames(90)
	check(pb.total_of(b["load"]) + st.total(st.inventory) == total_before and int(b["body"].get_meta("pending", 0)) == 0, "every stone landed: nothing was created or lost (%d in the bucket)" % pb.total_of(b["load"]))
	# ---- a bucket with little room takes only what fits
	st.inventory["limestone"] = 30
	var room: int = pb.room_of(b["body"])
	var m2: int = game.throw_bag_into_bucket(b["body"])
	check(m2 == room and st.total(st.inventory) == 30 - room, "only what fits goes in (%d of 30), the rest stays in the bag" % m2)
	await frames(90)
	# ---- a bucket picked up while stones are in the air returns them to the bag
	var b2: Dictionary = pb.place(ground + Vector3(0, 0, 1.2), {}, 0.0)
	await frames(3)
	st.inventory["limestone"] = 5
	game.throw_bag_into_bucket(b2["body"])
	var total_mid: int = st.total(st.inventory)
	st.hand_bucket = {}
	game.pick_up_bucket(b2["body"])
	await frames(90)
	check(st.total(st.inventory) == 5 and st.total(st.hand_bucket) == 0, "stones still in the air when the bucket is lifted go back into the bag (%d)" % st.total(st.inventory))
	# ---- stones survive a save
	game._drop_debris_stone()
	var n_stones: int = game.debris_stones.size()
	game._save(true)
	game._load(true)
	await frames(10)
	check(game.debris_stones.size() == n_stones, "loose stones are saved and come back (%d)" % game.debris_stones.size())
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
