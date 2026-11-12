extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	for i in range(8):
		await physics_frame
	var space = game.get_world_3d().direct_space_state
	var holes := []
	var x := -24.0
	var total := 0
	while x <= 60.0:
		var z := -30.0
		while z <= 30.0:
			var q := PhysicsRayQueryParameters3D.create(Vector3(x + 0.13, 8.0, z + 0.17), Vector3(x + 0.13, -6.0, z + 0.17), 1)
			var h: Dictionary = space.intersect_ray(q)
			total += 1
			if h.is_empty():
				holes.append(Vector2(x, z))
			z += 0.5
		x += 0.5
	print("YARD cells ", total, " no ground: ", holes.size())
	# cluster print
	var grid := {}
	for p in holes:
		grid[Vector2i(int(p.x / 4.0), int(p.y / 4.0))] = grid.get(Vector2i(int(p.x / 4.0), int(p.y / 4.0)), 0) + 1
	for k in grid:
		print("  hole block ", k * 4, " count ", grid[k])
	quit(0)
