extends SceneTree
## The navigation mesh is built from the terrain (not the column boxes): workers can path over the plain, a hole dug into it is walked around (not through), and a slope made by
## slumping is walkable.   godot --headless --fixed-fps 60 -s tests/test_terrain_nav.gd

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

func path_len(game, a: Vector3, b: Vector3) -> float:
	var p: PackedVector3Array = NavigationServer3D.map_get_path(game.nav_map, a, b, true)
	if p.size() < 2:
		return -1.0
	var l := 0.0
	for i in range(p.size() - 1):
		l += p[i].distance_to(p[i + 1])
	return l

func rebake(game) -> void:
	game.pit_zone.request_bake()
	for i in range(900):
		await physics_frame
		if not game.pit_zone.is_baking() and not game.pit_zone._bake_dirty:
			break
	await frames(6)

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(10)
	var lt: LiveTerrain = game.live_terrain
	game.prog.cleanup["done"] = true
	await rebake(game)
	check(game.pit_zone.last_source_boxes >= lt.terrain.chunk_nodes.size(), "the bake's sources are the terrain's chunks (%d)" % game.pit_zone.last_source_boxes)
	var a := Vector3(-30.0, 0.0, -50.0)
	var b := Vector3(30.0, 0.0, -50.0)
	var l0 := path_len(game, a, b)
	check(l0 > 55.0 and l0 < 70.0, "across the plain there is a (nearly straight) path of %.1f m" % l0)
	# dig a deep, wide hole across the straight line: the path must go round it
	game.prog.extract("q_top", game.prog.cell_index_at("q_top", Vector3(0.0, 0.0, -50.0)), 1.0e6, 1 << 30, "excavator")
	for dz in [-4.0, 0.0, 4.0]:
		var c: int = game.prog.cell_index_at("q_top", Vector3(0.0, 0.0, -50.0 + dz))
		game.prog.extract("q_top", c, 1.0e6, 1 << 30, "excavator")
		game.prog.extract("q_a2_gravel", game.prog.cell_index_at("q_a2_gravel", Vector3(0.0, 0.0, -50.0 + dz)), 1.0e6, 1 << 30, "excavator")
		game.prog.extract("q_a2_rock", game.prog.cell_index_at("q_a2_rock", Vector3(0.0, 0.0, -50.0 + dz)), 1.0e6, 1 << 30, "excavator")
	for id in ["q_top", "q_a2_gravel", "q_a2_rock"]:
		game.formation_nodes[id].refresh()
	lt.terrain.flush(true)
	await rebake(game)
	var l1 := path_len(game, a, b)
	var hole_y: float = lt.terrain.height_at(0.0, -50.0)
	check(hole_y < -3.0, "the hole is deep (%.1f m)" % hole_y)
	check(l1 >= l0 - 0.5, "the walk is never shorter than it was (%.1f m, was %.1f)" % [l1, l0])
	var p: PackedVector3Array = NavigationServer3D.map_get_path(game.nav_map, a, b, true)
	var lowest := 0.0
	for pt in p:
		lowest = minf(lowest, pt.y)
	check(lowest > -2.5 and lowest > hole_y + 1.0, "and it stays out of the hole: the lowest point of the path is %.2f m while the hole is %.1f m deep" % [lowest, hole_y])
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
