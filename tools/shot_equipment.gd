extends SceneTree
## Builds a small production line in the real game world and saves what the player camera sees (windowed run, not headless):
##   godot --path . -s tools/shot_equipment.gd -- <out.png>
## Two crushers feed belts into a merger, a belt carries the stream to a bin; a splitter feeds two more bins; an incline lifts into a hopper.

func _initialize() -> void:
	call_deferred("run")

## A patch of flat free ground (nothing but the ground in `size` metres), searched from `start`, away from `avoid`.
func find_spot(game, size: Vector2, start: Vector2, avoid := Vector3(1e6, 0, 1e6)) -> Vector3:
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, 2.0, size.y)
	for gx in range(int(start.x), 90, 3):
		for gz in range(int(start.y), 8, 3):
			var c := Vector3(gx, 0, gz)
			if c.distance_to(avoid) < 12.0 or not game.in_build_area(c):
				continue
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = box
			q.transform = Transform3D(Basis(), Vector3(gx, 1.6, gz))
			q.collision_mask = 1 | 16
			var blocked := false
			for h in space.intersect_shape(q, 16):
				var col = h["collider"]
				if not (col.has_meta("ground") or str(col.name) in ["Quarry floor", "Expansion floor", "Player"]):
					blocked = true
			if not blocked:
				return c
	return Vector3(60, 0, 30)

func run() -> void:
	var out := "shot.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	for i in 10:
		await physics_frame
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	var st = game.state
	var biz = game.business
	for n in game.find_children("*", "", true, false):
		if n.get_script() != null and str(n.get_script().resource_path).contains("title_menu"):
			n.visible = false
	var o := find_spot(game, Vector2(13, 9), Vector2(-30, -20)) + Vector3(0, 0, 0)
	var o2 := find_spot(game, Vector2(13, 10), Vector2(-30, -20), o)
	print("ORIGIN ", o, " ", o2)
	st.new_crusher(o + Vector3(4.2, 0, 0), PI * 0.5, 1)
	game._create_crusher(st.crushers.size() - 1)
	st.new_crusher(o + Vector3(-4.2, 0, 0), -PI * 0.5, 2)
	game._create_crusher(st.crushers.size() - 1)
	var parts := [["output", o + Vector3(0, 0, -4.8), 0.0, ""], ["conveyor", o, 0.0, "merger"], ["conveyor", o + Vector3(0, 0, -2.0), 0.0, "straight"],
		["conveyor", o + Vector3(2, 0, 0), PI * 0.5, "straight"], ["conveyor", o + Vector3(-2.2, 0, 0), -PI * 0.5, "straight"]]
	for p in parts:
		if p[0] == "output":
			game._create_output(biz.add_output(p[1], p[2]))
		else:
			game._create_conveyor(biz.add_conveyor(p[1], p[2], p[3]))
	# a splitter line to the north with an incline into a hopper
	var s := o2 + Vector3(0, 0, 3)
	st.new_crusher(s + Vector3(0, 0, 0), 0.0, 1)
	game._create_crusher(st.crushers.size() - 1)
	game._create_conveyor(biz.add_conveyor(s + Vector3(0, 0, -2.0), 0.0, "straight"))
	game._create_conveyor(biz.add_conveyor(s + Vector3(0, 0, -4.0), 0.0, "splitter"))
	game._create_conveyor(biz.add_conveyor(s + Vector3(-2, 0, -4.0), PI * 0.5, "straight"))
	game._create_conveyor(biz.add_conveyor(s + Vector3(2, 0, -4.0), -PI * 0.5, "incline"))
	game._create_output(biz.add_output(s + Vector3(-4.2, 0, -4.0), 0.0))
	game._create_output(biz.add_output(s + Vector3(5.35, 0, -4.0), 0.0, "hopper"))
	biz.compute_links()
	for c in st.crushers:
		c["output"] = 6
	if game.menu != "":
		game._close_menu()
	game.hud.visible = false
	var cam := Camera3D.new()
	cam.fov = 60.0
	root.add_child(cam)
	cam.current = true
	for view in [["a", o + Vector3(0, 4.2, 11.0), o + Vector3(0, 0.6, 0)], ["b", o + Vector3(2, 3.8, -8.0), o + Vector3(0, 0.6, -2.0)], ["c", s + Vector3(0, 3.6, 8.0), s + Vector3(0, 0.6, -3.0)], ["d", s + Vector3(-7, 3.0, 5.0), s + Vector3(3, 0.8, -3.0)]]:
		cam.global_position = view[1]
		cam.look_at(view[2])
		for i in 30:
			await physics_frame
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out.replace(".png", "_%s.png" % view[0]))
	quit()
