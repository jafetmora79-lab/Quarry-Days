extends SceneTree
## Dev tool: flood-fills the yard from the garage with a vehicle-sized box and prints what a machine can reach.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	for i in range(8):
		await physics_frame
	var space = game.get_world_3d().direct_space_state
	var x0 := -24; var x1 := 56; var z0 := -26; var z1 := 36
	var free := {}
	for zi in range(z0, z1):
		for xi in range(x0, x1):
			var shape := BoxShape3D.new()
			shape.size = Vector3(4.0, 1.8, 4.0)
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = shape
			q.transform = Transform3D(Basis(), Vector3(xi, 1.0, zi))
			q.collision_mask = 1 | 4 | 8 | 16
			free[Vector2i(xi, zi)] = space.intersect_shape(q, 1).is_empty()
	var seen := {}
	var start := Vector2i(1, 17)
	var stack := [start]
	seen[start] = true
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n: Vector2i = c + d
			if free.get(n, false) and not seen.has(n):
				seen[n] = true
				stack.append(n)
	print("reach from the garage (R), free but unreachable (.), blocked (#); x %d..%d" % [x0, x1])
	for zi in range(z0, z1):
		var row := ""
		for xi in range(x0, x1):
			var k := Vector2i(xi, zi)
			row += "R" if seen.has(k) else ("." if free[k] else "#")
		print("z%4d %s" % [zi, row])
	quit(0)
