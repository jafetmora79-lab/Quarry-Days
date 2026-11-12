extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	for i in range(8):
		await physics_frame
	var space = game.get_world_3d().direct_space_state
	print("free = space for a 6x4 m vehicle (x across, z down); # blocked")
	for zi in range(0, 34):
		var z := -4.0 + zi * 1.5
		var row := ""
		for xi in range(0, 60):
			var x := -12.0 + xi * 1.0
			var shape := BoxShape3D.new()
			shape.size = Vector3(4.0, 1.8, 6.0)
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = shape
			q.transform = Transform3D(Basis(), Vector3(x, 1.0, z))
			q.collision_mask = 1 | 4 | 8 | 16
			row += "#" if not space.intersect_shape(q, 1).is_empty() else "."
		print("z%5.1f %s" % [z, row])
	quit(0)
