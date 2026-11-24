extends SceneTree
## The bucket is a container you put down: dirt dug near it fills the nearest bucket with room, E picks it up, the box and the Cash Hopper take it, and it is solid (no walking
## through it, no standing on it, no stepping over a fence on it).   Run through tools/run_tests.sh.
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
	game.cash_hopper_enabled = true
	root.add_child(game)
	await process_frame
	await frames(8)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	game.safety.enabled = false
	await frames(20)
	var st = game.state
	var pb: PlacedBuckets = game._buckets()
	var pp: Vector3 = game.player.global_position
	var ground := pp + Vector3(2.0, 0.0, 0.0)
	var gy := _ground_y(game, ground)
	ground.y = gy
	# ---- placing
	check(pb.why_not(ground, Vector3.UP, pp) == "", "a bucket can stand on open ground")
	check(pb.why_not(ground, Vector3(0.7, 0.7, 0.0).normalized(), pp) != "", "but not on a steep slope")
	check(pb.why_not(pp + Vector3(0.3, 0, 0), Vector3.UP, pp) != "", "and not under the player's own feet")
	var a := pb.place(ground, {}, 0.0)
	var b := pb.place(ground + Vector3(0.9, 0.0, 0.0), {}, 0.0)
	check(pb.items.size() == 2 and not a.is_empty() and not b.is_empty(), "as many as you like can be put down (%d)" % pb.items.size())
	await frames(3)
	check(pb.why_not(ground, Vector3.UP, pp) != "", "a second bucket cannot be put inside the first")
	var body: StaticBody3D = a["body"]
	check(str(body.get_meta("kind")) == "placed_bucket" and not body.has_meta("ground") and not body.has_meta("climbable"), "it is a solid, non-climbable object")
	var shape := (body.get_child(0) as CollisionShape3D).shape as CylinderShape3D
	check(shape.height >= 1.3 and shape.height > 0.9 + 0.3, "its collider is taller than a jump (%.1f m against a 0.9 m jump), so it is never a step" % shape.height)
	# ---- dug dirt fills the nearest bucket with room, then the next one, then the bag
	var bag0: int = st.total(st.inventory)
	game.mine_point_hint = ground
	game._terrain_yield({"topsoil": 1.0}, [])            # 11 units (they fly in from the dig point: the load shows as they land)
	await frames(110)
	check(pb.total_of(a["load"]) == 11 and st.total(st.inventory) == bag0, "dirt dug near a bucket goes into it, not the bag (%d)" % pb.total_of(a["load"]))
	game._terrain_yield({"topsoil": 1.0}, [])            # 11 more: 7 fit in the first, 4 go to the second
	await frames(110)
	check(pb.total_of(a["load"]) == 18 and pb.total_of(b["load"]) == 4, "a full bucket passes the rest to the next one (%d / %d)" % [pb.total_of(a["load"]), pb.total_of(b["load"])])
	pb.receive(pp, ground, "topsoil", 14)
	check(pb.total_of(b["load"]) == 18, "both are now full")
	var bag1: int = st.total(st.inventory)
	game._terrain_yield({"topsoil": 1.0}, [])
	await frames(110)
	check(st.total(st.inventory) == bag1 + 11, "with every bucket full the dirt goes to the bag as before")
	# a bucket out of reach does not take dirt
	var far: Dictionary = pb.place(ground + Vector3(30.0, 0.0, 0.0), {}, 0.0)
	check(pb.receive(pp, ground, "topsoil", 5) == 0 and pb.total_of(far["load"]) == 0, "a bucket far from the player takes nothing")
	pb.pick_up(far["body"])
	# ---- the fill is visible
	var fill: Node3D = a["fill"]
	check(fill != null and fill.get_child_count() >= 2, "a full bucket shows its contents (%d parts)" % fill.get_child_count())
	# ---- picking up and carrying
	st.hand_bucket = {}
	check(game.pick_up_bucket(body) and st.total(st.hand_bucket) == 18 and pb.items.size() == 1, "E picks the bucket up with its 18 units")
	var body_b: StaticBody3D = pb.items[0]["body"]
	check(not game.pick_up_bucket(body_b), "only one bucket fits in the hands")
	var slot_now: int = game.prog.hotbar_slot()
	game.select_tool_slot(0)
	check(game.prog.hotbar_slot() == slot_now, "while carrying a full bucket the tool cannot be swapped")
	# ---- delivering to the box
	var box0: int = st.total(st.storage)
	var moved: int = game.deliver_hand_to_storage()
	check(moved == 18 and st.total(st.storage) == box0 + 18 and st.hand_bucket.is_empty(), "the bucket is tipped into the box (%d)" % moved)
	game.select_tool_slot(0)
	# ---- delivering to the Cash Hopper
	var hs: Array = game.business.cash_hopper_indices()
	check(not hs.is_empty(), "the Cash Hopper is there")
	if not hs.is_empty():
		st.hand_bucket = {"limestone": 9, "topsoil": 3}
		var q0: int = game.business.cash_queue(int(hs[0]))
		var m2: int = game.deliver_hand_to_hopper(int(hs[0]))
		check(m2 == 12 and st.hand_bucket.is_empty() and game.business.cash_queue(int(hs[0])) >= q0, "a carried bucket tips into the Cash Hopper, which sells it (%d)" % m2)
	# ---- putting a bucket down keeps its contents
	st.hand_bucket = {"topsoil": 7}
	var kept: Dictionary = pb.place(ground + Vector3(0.0, 0.0, 1.2), st.hand_bucket, 0.0)
	st.hand_bucket = {}
	check(pb.total_of(kept["load"]) == 7, "a carried bucket put down keeps what is in it")
	# ---- saving and loading
	var snap: Array = pb.save()
	pb.restore(snap)
	check(pb.items.size() == snap.size() and pb.total_of(pb.items[pb.items.size() - 1]["load"]) == 7, "placed buckets and their loads survive a save (%d)" % snap.size())
	# ---- solid: walking into one does not go through it, and jumping at it does not put you on it
	for it in pb.items.duplicate():
		pb.pick_up(it["body"])
	var wall_pos: Vector3 = game.player.global_position + Vector3(0.0, 0.0, -4.0)
	wall_pos.y = _ground_y(game, wall_pos)
	var solid: Dictionary = pb.place(wall_pos, {}, 0.0)
	await frames(3)
	game.player.global_position = wall_pos + Vector3(0.0, 0.3, 1.6)
	game.player.rotation.y = 0.0                        # facing -Z, towards the bucket
	game.player.velocity = Vector3.ZERO
	await frames(4)
	var base_y: float = game.player.global_position.y
	var peak := 0.0
	var closest := 99.0
	Input.action_press("move_forward", 1.0)
	for i in range(240):
		if i % 20 == 0:
			Input.action_press("jump")
		elif i % 20 == 2:
			Input.action_release("jump")
		await physics_frame
		var pos: Vector3 = game.player.global_position
		closest = minf(closest, Vector2(pos.x - wall_pos.x, pos.z - wall_pos.z).length())
		peak = maxf(peak, pos.y - base_y)
	Input.action_release("move_forward")
	Input.action_release("jump")
	var pos2: Vector3 = game.player.global_position
	check(closest > 0.3, "the player cannot walk into the bucket (closest %.2f m, the bucket is 0.3 m wide)" % closest)
	check(pos2.y - base_y < 0.4 and peak < 1.2, "and cannot climb on it (rose %.2f m at most, ended %.2f m above where it started)" % [peak, pos2.y - base_y])
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)

func _ground_y(game, p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 6, 0), p - Vector3(0, 6, 0), 1)
	var h: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(q)
	return float(h["position"].y) if not h.is_empty() else p.y
