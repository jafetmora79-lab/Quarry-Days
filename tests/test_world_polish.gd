extends SceneTree
## World polish: home and sleep, two-card intro, hangar roof and chase camera, consistent ground, dressed cliff ring.
##   godot --headless --fixed-fps 60 -s tests/test_world_polish.gd

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

func frames(n: int, until: Callable = Callable()) -> int:
	for i in range(n):
		await physics_frame
		if until.is_valid() and until.call():
			return i
	return n

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for i in range(4):
		await physics_frame
	var st: QuarryState = game.state
	var prog: QuarryProgression = game.prog
	# ---- intro: the letter, then "your first day"
	check(game.hud.card_open() and game.hud.card_title.text.contains("GRANDPA") and game.hud.card_body.text.contains("house"), "A the letter mentions the little house")
	game.hud.close_card()
	await process_frame
	check(game.hud.card_open() and game.hud.card_title.text.contains("FIRST DAY") and game.hud.card_body.text.contains("sleep"), "A a second card explains the first day, including sleeping")
	check(not prog.story["intro_seen"], "A the intro is not finished until the second card is closed")
	game.hud.close_card()
	await process_frame
	check(prog.story["intro_seen"] and not game.hud.card_open() and not game.player.locked, "A closing the second card finishes the intro and frees the player")
	# ---- the house
	var bed: StaticBody3D = null
	var home_floor: StaticBody3D = null
	for b in game.world.get_children():
		if b is StaticBody3D and str(b.get_meta("kind", "")) == "bed":
			bed = b
		if b is StaticBody3D and str(b.name).begins_with("Home floor"):
			home_floor = b
	check(bed != null and home_floor != null, "B there is a house with a bed")
	var c: Vector3 = game.HOME_POS
	var ring_ok := true
	for dx in [-2.5, 2.5]:
		for dz in [-2.4, 2.4]:
			ring_ok = ring_ok and Vector2(c.x + dx, c.z + dz).length() < 24.3
	check(ring_ok, "B the house stands inside the cliff ring")
	check(c.x + 2.5 <= -4.7, "B and clear of the garage wall (x -4.7)")
	# ---- sleeping
	prog.cleanup["done"] = true
	st.clock_minutes = 12.0 * 60.0
	game.try_sleep()
	check(not game.sleeping and game.message.contains("not tired"), "C you cannot sleep at noon")
	st.clock_minutes = 19.5 * 60.0
	check(game.can_sleep(), "C you can sleep in the evening")
	game.player_mine("hillside_face_01", -1, 0.0) # no-op safety
	for i in range(6):
		st.deposits["hillside_face_01"]["columns"][6 * 5 + 5] = 0
	prog._sync_stock(st.deposits["hillside_face_01"])
	var cols_before: Array = (st.deposits["hillside_face_01"]["columns"] as Array).duplicate()
	st.money = 250
	st.inventory["limestone"] = 4
	game.business.milestones["first_employee"] = true
	game.try_sleep()
	check(game.sleeping and game.player.locked, "C going to bed starts the sleep (the screen fades)")
	await frames(240, func(): return not game.sleeping)
	var day := 1
	check(not game.sleeping and not game.player.locked, "C you wake up and can move again")
	check(absf(st.clock_minutes - (1440.0 + 420.0)) < 0.01, "C it is 07:00 the next morning (%.1f)" % st.clock_minutes)
	check(st.money == 250 and st.inventory["limestone"] == 4, "C money and the bag are untouched")
	check(str((st.deposits["hillside_face_01"]["columns"] as Array).map(func(v): return int(v))) == str(cols_before.map(func(v): return int(v))), "C excavated rock stays excavated after sleeping")
	check(game.business.payroll_minute >= int(floor(st.clock_minutes)) - 2, "C wages are settled up to the new time")
	check(FileAccess.file_exists("user://quarry_save.json"), "C sleeping saved the game")
	game.sleep_now()
	check(absf(st.clock_minutes - (2.0 * 1440.0 + 420.0)) < 0.01 or absf(st.clock_minutes - (1440.0 + 420.0)) < 0.01, "C sleeping at 07:00 never skips back or forward by more than a day")
	st.clock_minutes = 1440.0 + 3.0 * 60.0
	game.sleep_now()
	check(absf(st.clock_minutes - (1440.0 + 420.0)) < 0.01, "C sleeping after midnight wakes at 07:00 the same date")
	# ---- hangar: roof comes off and the chase camera stays in front of the back wall
	game.business.milestones["mechanized"] = true
	prog.stage = prog.stage_index("large")
	st.money = 50000
	game.ui_buy_vehicle("loader")
	game.delivery.finish_all()
	var v = game.vehicle_nodes.values()[0]
	v.global_position = Vector3(8.0, 0.1, 19.5)
	v.rotation.y = 0.0
	v.speed = 0.0
	await frames(3)
	check(game.art.garage_roof.visible, "D the hangar roof is on while nobody is driving")
	game.enter_vehicle(v)
	await frames(3)
	check(not game.art.garage_roof.visible, "D driving a vehicle inside the hangar takes the roof off")
	v.cam_yaw = 0.0
	v._pull_camera_in()
	check(v.camera.global_position.z < 22.4 and v.camera.position.length() > 1.7, "D the chase camera is pulled in front of the hangar's back wall (z %.1f)" % v.camera.global_position.z)
	game.exit_vehicle()
	await frames(3)
	check(game.art.garage_roof.visible, "D the roof returns when you get out")
	# ---- ground and walls
	var bad_ground := 0
	for m in game.art.root.get_children():
		if m is MeshInstance3D and (m as MeshInstance3D).material_override:
			var rp: String = (m as MeshInstance3D).material_override.resource_path
			if rp.contains("M_Road_DirtRoad") or rp.contains("M_Road_Gravel"):
				bad_ground += 1
	check(bad_ground == 0, "E roads and the yard use the same calm ground texture as the floor (%d patchwork meshes left)" % bad_ground)
	var undressed := 0
	for b in game.world.get_children():
		if b is StaticBody3D and not b.has_meta("ground"):
			var size := Vector3.ZERO
			for k in b.get_children():
				if k is CollisionShape3D and k.shape is BoxShape3D:
					size = k.shape.size
			if (absf(size.y - 6.0) < 0.05 or absf(size.y - 2.2) < 0.05) and maxf(size.x, size.z) >= 8.0 and b.visible:
				var art_child := false
				for k in b.get_children():
					art_child = art_child or (k is MeshInstance3D and k.has_meta("art"))
				if not art_child:
					undressed += 1
	check(undressed == 0, "E every cliff and rim block carries the natural cliff mesh (%d bare boxes)" % undressed)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
