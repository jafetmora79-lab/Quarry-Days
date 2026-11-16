extends SceneTree
## The yard buildings: the office, Grandpa's house (cabin + living-room wing), the workshop and the storage shed are Blender models in the game, their doors
## are walkable for a person-sized capsule (a shape sweep through each doorway, no collider in the way), Grandpa's house has its living-room wing with a
## walkable doorway, the walls are still solid, and the furniture of the wing is solid too.
##   godot --headless --fixed-fps 60 -s tests/test_yard_buildings.gd

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

var space: PhysicsDirectSpaceState3D
var capsule: CapsuleShape3D

## True when a person-sized capsule (radius 0.3, height 1.7) can stand at every point from a to b (sampled every 0.1 m) without touching world geometry.
func walkable(game, a: Vector3, b: Vector3) -> bool:
	var n := int(a.distance_to(b) / 0.1) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / float(n))
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = capsule
		q.transform = Transform3D(Basis(), p)
		q.collision_mask = 1
		q.exclude = [game.player.get_rid()]
		var hits := space.intersect_shape(q, 4)
		for h in hits:
			var col = h["collider"]
			if col is StaticBody3D and not str(col.name).ends_with("door panel"):          # a closed door opens when you walk up to it
				return false
	return true

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	for i in 6:
		await physics_frame
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await process_frame
	await physics_frame
	space = game.get_world_3d().direct_space_state
	capsule = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	for nm in ["Office", "Home", "Workshop", "Shed"]:
		check(game.art.root.get_node_or_null("Building_" + nm) != null, "the Blender %s is in the game" % nm)
	var home: Vector3 = game.HOME_POS
	var tool: Vector3 = game.TOOLSHED_POS
	var shed: Vector3 = game.SHED_POS
	var office: Vector3 = game.OFFICE_POS
	# doors: walk in from the front along the doorway line, well inside the room
	var y := 1.15
	check(walkable(game, office + Vector3(0, y, -4.2), office + Vector3(0, y, -0.6)), "the office door is walkable")
	check(walkable(game, home + Vector3(0, y, -4.2), home + Vector3(0, y, 0.3)), "Grandpa's front door is walkable")
	check(walkable(game, tool + Vector3(0, y, -4.2), tool + Vector3(0, y, 0.5)), "the workshop door is walkable")
	check(walkable(game, shed + Vector3(0, y, -4.2), shed + Vector3(0, y, 0.8)), "the storage shed opening is walkable")
	# the living-room wing: through the doorway in the cabin's west wall and into the room
	check(game.world.get_node_or_null("Home left") == null and game.world.get_node_or_null("Home wing west") != null, "the cabin's west wall is split and the wing has its own walls")
	check(walkable(game, home + Vector3(-1.4, y, -0.12), home + Vector3(-4.4, y, -0.12)), "from the cabin through the wide doorway into the living room")
	check(walkable(game, home + Vector3(-4.4, y, -0.12), home + Vector3(-3.0, y, 0.0)), "and round the middle of the living room")
	# solid where it should be
	check(not walkable(game, home + Vector3(-1.4, y, 1.2), home + Vector3(-3.2, y, 1.2)), "the cabin's west wall is solid beside the doorway")
	check(not walkable(game, home + Vector3(-4.1, y, 0.8), home + Vector3(-4.1, y, 2.3)), "the sofa and the back wall of the wing are solid")
	check(not walkable(game, home + Vector3(-3.0, y, -1.0), home + Vector3(-3.2, y, -2.2)), "the TV cabinet and the front wall of the wing are solid")
	check(not walkable(game, office + Vector3(-4.0, y, -1.8), office + Vector3(-1.5, y, -1.8)), "the office wall is solid")
	# the wing is closed from the outside: nothing walks through its walls
	check(not walkable(game, home + Vector3(-7.0, y, 0.0), home + Vector3(-4.4, y, 0.0)), "the wing's west wall is solid")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
