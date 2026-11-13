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
	# the old truck leaves once the intro is over
	game._finish_intro()
	await frames(900)
	check(game.truck_node == null, "Walter's truck drove away")
	check(game.world.get_node_or_null("WaltersTruck") == null, "and is gone from the yard")
	# Grandpa
	game._spawn_walter()
	await frames(5)
	var g = game.walter_node
	check(g != null and g.find_child("GrandpaHead", true, false) != null, "Grandpa wears his own cap, glasses and moustache")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
