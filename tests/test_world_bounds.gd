extends SceneTree
## The player cannot leave the property: every point along the yard's boundary is blocked, so nobody wanders out into the woodland (there is nothing there).
##   godot --headless --fixed-fps 60 -s tests/test_world_bounds.gd
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
func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	for i in 20:
		await physics_frame
	var space = game.get_world_3d().direct_space_state
	var hub: Rect2 = game.hub_rect()
	# east and south sides of the yard, and the quarry's other sides: walk outward from inside; there must be a wall (layer 1) within the next few metres
	var open := []
	var z := hub.position.y
	while z <= hub.end.y:
		var q := PhysicsRayQueryParameters3D.create(Vector3(hub.end.x - 3.0, 1.0, z), Vector3(hub.end.x + 30.0, 1.0, z), 1)
		if not space.intersect_ray(q):
			open.append("east z%.1f" % z)
		z += 0.5
	check(open.is_empty(), "the yard's east side is closed along its whole length (open at: %s)" % str(open.slice(0, 5)))
	var x := hub.position.x
	open = []
	while x <= hub.end.x:
		var q2 := PhysicsRayQueryParameters3D.create(Vector3(x, 1.0, hub.end.y - 3.0), Vector3(x, 1.0, hub.end.y + 30.0), 1)
		if not space.intersect_ray(q2):
			open.append("south x%.1f" % x)
		x += 0.5
	check(open.is_empty(), "the yard's south side is closed along its whole length (open at: %s)" % str(open.slice(0, 5)))
	# nothing lets a person walk to the far edge of the land: from the east fence a ray to x = 190 meets a wall
	var q3 := PhysicsRayQueryParameters3D.create(Vector3(hub.end.x - 2.0, 1.0, 12.0), Vector3(190.0, 1.0, 12.0), 1)
	var hit = space.intersect_ray(q3)
	check(hit and hit.position.x < hub.end.x + 2.0, "the gap that led out to the woodland is shut (first wall at x %.1f)" % (hit.position.x if hit else -1.0))
	# the quarry itself is still reachable through its gate
	var q4 := PhysicsRayQueryParameters3D.create(Vector3(0, 1.0, 10.0), Vector3(0, 1.0, -40.0), 1)
	check(not space.intersect_ray(q4), "the quarry gate is open: you can walk from the yard onto the quarry floor")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
