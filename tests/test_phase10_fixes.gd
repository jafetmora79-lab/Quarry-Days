extends SceneTree
## Phase 10 playtest fixes: the garage door ignores the player, a real tunnel and road lie behind it, Walter's truck drives off,
## Grandpa has his own look.   godot --headless --fixed-fps 60 -s tests/test_phase10_fixes.gd

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
	root.add_child(game)
	await process_frame
	await frames(6)
	for i in range(6):
		if game.walter_dialog:
			game.walter_dialog.skip()
		await frames(30)
	game.hud.close_card()
	game._cine_tween().kill()
	await frames(3)
	# the door never opens for the player, on foot or driving
	game.player.global_position = Vector3(QuarryDelivery.DOOR_X, 0.2, QuarryDelivery.DOOR_Z - 2.0)
	await frames(90)
	check(game.delivery.open_amount < 0.02, "the garage door stays shut with the player right at it")
	var gw = game.world.get_node_or_null("ServiceTunnel")
	check(gw != null and gw.get_child_count() > 20, "a tunnel with road, walls and lamps stands behind the portal")
	# the old truck waits by the excavator; when Grandpa leaves he walks to it, climbs in and drives out along the lane
	check(game.truck_node != null, "Walter's truck is still parked while Grandpa waits by the excavator")
	game._spawn_walter()
	game.walter_node.global_position = Vector3(-14.9, 0.0, 5.6)
	game._walter_leave()
	check(game.walter_mode == "to_truck", "Grandpa walks to his truck first")
	var min_sell := 99.0
	var south_ok := false
	var door_ok := true
	for i in range(1800):
		await physics_frame
		if game.truck_node != null and is_instance_valid(game.truck_node):
			var tp: Vector3 = game.truck_node.global_position
			min_sell = minf(min_sell, Vector2(tp.x, tp.z).distance_to(Vector2(-7.0, 10.0)))
			if game.truck_driving and tp.z > 10.0 and tp.z < 20.0 and absf(absf(game.truck_node.rotation.y) - PI) < 0.3:
				south_ok = true
			if tp.z > game.delivery.DOOR_Z - 0.5 and tp.z < game.delivery.DOOR_Z + 2.0 and not game.delivery.is_open() and game.delivery.open_amount < 0.7:
				door_ok = false
		if game.truck_node == null:
			break
	check(game.truck_node == null and game.walter_node == null, "the truck drove away with Grandpa in it")
	check(min_sell > 3.0, "it never went through the sales stand (closest %.1f m)" % min_sell)
	check(south_ok, "it faces the way it drives")
	check(door_ok, "and the garage door was up when it passed")
	# Grandpa
	game._spawn_walter()
	await frames(5)
	var g = game.walter_node
	check(g != null and g.find_child("GrandpaHead", true, false) != null, "Grandpa wears his own cap, glasses and moustache")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
