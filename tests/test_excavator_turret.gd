extends SceneTree
## The excavator's upper body (cab, boom, stick, bucket) sits on its slewing ring and turns on its OWN vertical axis with the mouse while the tracks stay put. It used to be
## pulled down 0.78 m into the tracks (the engine-shake code wrote its height as an absolute value); now the shake is about its rest height. Checked on the machine you buy and
## on Grandpa's starter excavator: height over time (idle, digging, spinning), the spin follows the mouse, the tracks do not turn, the bucket circles the turret axis.
##   godot --headless --fixed-fps 60 -s tests/test_excavator_turret.gd

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

func exercise(game, ex: QuarryVehicle, label: String) -> void:
	check(ex != null and ex.rig != null and ex.turret != null, "%s: the Blender excavator with its turret" % label)
	var rest := ex.turret_rest_y
	check(rest > 0.5, "%s: the turret stands %.2f m up on its slewing ring" % [label, rest])
	await frames(120)
	check(absf(ex.turret.position.y - rest) < 0.01, "%s: idle, it keeps its height (%.3f vs %.3f)" % [label, ex.turret.position.y, rest])
	ex.digging = true
	await frames(180)
	check(absf(ex.turret.position.y - rest) < 0.012, "%s: digging, it keeps its height (%.3f)" % [label, ex.turret.position.y])
	ex.digging = false
	await frames(300)
	check(absf(ex.turret.position.y - rest) < 0.01, "%s: after the dig it is back on its ring (%.3f)" % [label, ex.turret.position.y])
	# the mouse spins the cab: drive it as the player does
	game.enter_vehicle(ex)
	await frames(30)
	var base_yaw := ex.rotation.y
	var y0 := ex.turret.rotation.y
	var p0 := ex.turret.position
	for i in 12:
		ex.rotate_camera(Vector2(-60.0, 0.0))                    # a sweep of the mouse
		await physics_frame
	await frames(60)
	var spun := angle_difference(y0, ex.turret.rotation.y)
	check(absf(spun) > 1.0, "%s: the mouse turns the upper body (%.2f rad)" % [label, spun])
	check(absf(angle_difference(base_yaw, ex.rotation.y)) < 0.02, "%s: while the tracks do not turn" % label)
	check(Vector2(ex.turret.position.x - p0.x, ex.turret.position.z - p0.z).length() < 0.01 and absf(ex.turret.position.y - rest) < 0.012, "%s: and it turns on its own axis, staying put on the ring" % label)
	# the arm goes round with it: the bucket stays the same distance from the turret axis (a circle), whatever the angle
	var axis := ex.turret.global_position
	var r1 := Vector2(ex.rig.bucket_tip().x - axis.x, ex.rig.bucket_tip().z - axis.z).length()
	for i in 8:
		ex.rotate_camera(Vector2(50.0, 0.0))
		await physics_frame
	await frames(60)
	var axis2 := ex.turret.global_position
	var r2 := Vector2(ex.rig.bucket_tip().x - axis2.x, ex.rig.bucket_tip().z - axis2.z).length()
	check(absf(r1 - r2) < 0.15 and r1 > 1.0, "%s: the boom and bucket swing round the turret's axis (reach %.2f m then %.2f m)" % [label, r1, r2])
	game.exit_vehicle()
	await frames(60)
	check(absf(ex.turret.position.y - rest) < 0.012, "%s: after getting out it is still at its height" % label)

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	game.safety.enabled = false
	var rec: Dictionary = game.fleet.give("compact_excavator", Vector3(40, 0.3, 45), 0.0)
	game._sync_vehicles()
	await frames(60)
	await exercise(game, game.vehicle_nodes.get(int(rec["id"])), "the machine you buy")
	game.prog.excavator_state().merge({"battery": true, "hose": true, "fuel": true, "started": true}, true)
	game._ensure_opening()
	var starter: QuarryVehicle = game._starter_vehicle()
	if starter != null:
		starter.global_position = Vector3(-6.0, 0.3, -16.0)
		await frames(60)
	await exercise(game, starter, "Grandpa's starter excavator")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
