extends SceneTree
## Isolated test using the shipped animal GLBs, a real camera and occlusion.
var failures := 0
var checks := 0

class Viewer extends CharacterBody3D:
	var camera: Camera3D
	var locked := false

class Game extends Node3D:
	var player: Viewer
	var driving = null
	var menu := ""
	var sleeping := false

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
	else:
		print("PASS: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.player = Viewer.new()
	game.add_child(game.player)
	game.player.camera = Camera3D.new()
	game.player.add_child(game.player.camera)
	game.player.camera.position.y = 1.6
	game.player.camera.current = true
	var battle = load("res://scripts/forest_aura_battle.gd").new()
	game.add_child(battle)
	battle.setup(game)
	battle.set_process(false)
	battle.cinematic = false                  # the trigger / pose / occlusion logic is tested without the camera takeover
	check(battle.actors.size() == 2, "both original wildlife GLBs instantiate")
	check(battle.actors[0]["parts"].has("Antlers") and battle.actors[1]["parts"].has("LegB"), "real deer and rabbit animation hinges exist")
	game.player.position = Vector3(-121, 0, -58)
	game.player.camera.look_at(battle.global_position + Vector3(0, 1.2, 0))
	await physics_frame
	await physics_frame
	check(battle.watched(), "looking into clearing from left quarry fence qualifies")
	battle.step(1.9, true)
	check(battle.elapsed < 0, "a quick glance does not trigger the battle")
	battle.step(0.1, false)
	battle.step(1.9, true)
	check(battle.elapsed < 0, "looking away resets the stare timer")
	battle.step(0.2, true)
	check(battle.elapsed == 0.0, "a continuous two-second stare triggers it")
	battle.step(12.0, true)
	check(battle.pose_name(battle.elapsed) == "boat_roll", "sequence reaches wrist flick and roll")
	check(battle.actors[1]["parts"].has("PawL") and battle.actors[1]["parts"].has("PawR"), "rabbit has independent paws derived from its original mesh")
	var paw_l: Node3D = battle.actors[1]["parts"]["PawL"]
	var paw_r: Node3D = battle.actors[1]["parts"]["PawR"]
	check(paw_l.basis != paw_r.basis, "left and right paws perform different gestures")
	battle._pose(4.0)
	var six: Transform3D = battle.actors[0]["parts"]["LegFL"].transform
	battle._pose(17.0)
	check(six != battle.actors[0]["parts"]["LegFL"].transform, "six-seven and crossed forelegs have distinct silhouettes")
	battle._pose(21.0)
	check(battle.pose_name(21.0) == "pockets", "relaxed tucked-paw pose follows crossed stance")
	battle.step(5.0, true)
	check(battle.pose_name(battle.elapsed) == "crossed", "deadpan crossed-paw pose replaces the beam clash")
	battle.step(7.0, true)
	check(battle.elapsed < 0 and not battle.effects.visible and battle.cooldown > 0, "battle ends cleanly with a cooldown")
	check(battle.actors[0]["root"].position == battle.actors[0]["home"], "animal returns to original ground position")
	var restored := true
	for made in battle.actors:
		for key in made["parts"]:
			if made["parts"][key].transform != made["rest"][key]: restored = false
	check(restored, "all original and split-paw transforms restore after the dance")
	battle.step(2.1, true)
	check(battle.elapsed < 0, "continued watching cannot immediately retrigger")
	battle.step(20.0, false)
	battle.step(2.1, true)
	battle.step(1.0, false)
	check(battle.elapsed >= 0, "short glance away has grace time")
	battle.step(2.1, false)
	check(battle.elapsed < 0 and not battle.effects.visible, "leaving the viewpoint cancels and clears effects")
	game.player.camera.look_at(Vector3(-90, 1.6, -58))
	check(not battle.watched(), "looking away from the forest cannot trigger it")
	game.player.camera.look_at(battle.global_position + Vector3(0, 1.2, 0))
	game.menu = "pause"
	check(not battle.watched(), "menus cannot discover the Easter egg")
	game.menu = ""
	game.player.position.x = -80
	check(not battle.watched(), "player must be near the left boundary")
	game.player.position.x = -121
	var wall := StaticBody3D.new()
	wall.position = Vector3(-135, 2, -58)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 5, 12)
	collider.shape = box
	wall.add_child(collider)
	game.add_child(wall)
	await physics_frame
	await physics_frame
	wall.set_meta("fence", true)
	check(battle.watched(), "see-through fence movement collider does not hide the animals")
	wall.set_meta("fence", false)
	check(not battle.watched(), "solid scenery occludes the trigger")
	check(battle.find_children("*", "CollisionObject3D", true, false).is_empty(), "battle adds no collisions or combat bodies")
	game.free()
	# Real-world regression: the actual quarry fence must not prevent discovery,
	# and generated trees must leave the requested distant sightline open.
	var world = load("res://Main.tscn").instantiate()
	world.autosave_enabled = false
	world.title_enabled = false
	world.introductions_enabled = false
	world.curfew_enabled = false
	root.add_child(world)
	for i in 8:
		await physics_frame
	if world.walter_dialog:
		world.walter_dialog.skip()
	world._cine_stop()
	world._remove_walter()
	world.hud.close_card()
	world.player.global_position = Vector3(-121, 0.1, -58)
	world.player.locked = false
	var real = world.wildlife.aura_battle
	real.set_process(false)
	world.player.camera.look_at(real.global_position + Vector3(0, 1.2, 0))
	await physics_frame
	check(real.watched(), "actual quarry west fence allows discovery from playable ground")
	var clear := true
	for positions in [world.landscape.tree_positions, world.landscape.young_positions]:
		for p in positions:
			if real.in_clearing(Vector2(p.x, p.z)):
				clear = false
	check(clear, "real generated forest reserves the battle sightline")
	world.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
