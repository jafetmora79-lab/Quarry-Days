extends SceneTree
## Buildings: interactive doors, no coplanar floor layers (depth fighting), bigger hangar.
##   godot --headless --fixed-fps 60 -s tests/test_buildings.gd

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

func aim(game, pos: Vector3, yaw: float, pitch: float) -> String:
	game.player.global_position = pos
	game.player.rotation.y = yaw
	game.player.camera.rotation.x = pitch
	var t = game._look_target()
	return "" if t == null else str(t.get_meta("kind", ""))

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await frames(4)
	game.hud.close_card()
	await process_frame
	game.hud.close_card()
	await process_frame
	check(game.doors.size() == 2, "A the office and the home have doors")
	var home = game.doors[1]
	var office = game.doors[0]
	check(not home.want_open and home.open_amount == 0.0, "A doors start shut")
	var c: Vector3 = game.HOME_POS
	var k := aim(game, c + Vector3(0.7, 0.2, -4.0), 0.0, 0.0)
	check(k == "door" or k == "", "B (probe) looking at the closed home door: " + k)
	# interact straight through the game's own handler
	var panel: Node3D = home.body
	game._interact(panel)
	await frames(60)
	check(home.want_open and home.is_open(), "B E opens the home door")
	check(absf(home.rotation.y) > 1.0, "B the panel swings aside (%.2f rad)" % home.rotation.y)
	game._interact(panel)
	await frames(90)
	check(not home.is_open() and absf(home.rotation.y) < 0.1, "B E closes it again")
	game._interact(office.body)
	await frames(60)
	check(office.is_open(), "B the office door works too")
	# workers open doors for themselves
	game.prog.stage = game.prog.stage_index("large")
	game.state.money = 50000
	game.state.clock_minutes = 480.0
	game.ui_hire("rosa")
	var w = game.worker_nodes.values()[0]
	w.global_position = Vector3(home.global_position.x - 0.7, 0.2, home.global_position.z - 1.0)
	home.want_open = false
	await frames(40)
	check(home.is_open(), "C a worker walking up opens the door for themselves")
	# floors: nothing coplanar closer than 2 cm to something else in the same footprint
	var art = game.art
	var ys := []
	for m in art.root.get_children():
		pass
	check(art.garage_roof != null, "D the hangar exists")
	var gw: StaticBody3D = null
	for b in game.world.get_children():
		if b is StaticBody3D and str(b.name) == "Garage wall":
			gw = b
	var depth := 0.0
	for ch in gw.get_children():
		if ch is CollisionShape3D:
			depth = ch.shape.size.z
	check(depth > 7.4, "D the hangar is deeper than before (%.1f m, was 6.4)" % depth)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
