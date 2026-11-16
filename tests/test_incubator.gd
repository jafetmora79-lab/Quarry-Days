extends SceneTree
## The egg's home: Dr. Marsh's egg waits on the porch, goes into the incubator in Grandpa's living room when picked up, hatches there, and the incubator stays; the models and the story texts.
##   godot --headless --fixed-fps 60 -s tests/test_incubator.gd
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
	game.title_enabled = false
	game.autosave_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(5)
	if game.opening_scene != null:
		game.opening_scene.skip_all()
	await frames(5)
	game.hud.close_card()
	await frames(5)
	var prog: QuarryProgression = game.prog
	# the models
	for k in ["dino", "egg", "incubator", "fossil_nest"]:
		check(WorldModels.has(k), "the Blender model %s is in the game" % k)
	var eggm: Dictionary = WorldModels.animal("egg")
	for part in ["Shell", "Cracks", "ShellTop", "ShellBottom", "Nest"]:
		check(eggm["parts"].has(part), "the egg has its %s" % part)
	eggm["root"].free()
	var inc: Dictionary = WorldModels.animal("incubator")
	check(inc["parts"].has("Glass") and inc["parts"].has("Lamp"), "the incubator has a glass lid and a lamp")
	inc["root"].free()
	# the story texts
	var c: Dictionary = prog.companion_cfg()
	check(str(c["arrival_text"]).contains("incubator") and str(c["hatch_text"]).contains("incubator"), "the arrival and hatch texts are about the incubator")
	check(c["marsh"]["lines"].size() >= 4 and str(c["marsh"]["lines"][1]["text"]).contains("hot spring"), "Dr. Marsh explains where the egg came from")
	check(str(prog.fossil_cfg()["found_text"]).contains("nest") and str(prog.fossil_cfg()["found_text"]).contains("warm"), "the fossil is a mother on her nest with one warm egg")
	# pending -> the egg waits on the porch
	prog.story["fossil"] = "scientist"
	prog.story["companion"] = {"state": "pending", "ready_day": 0, "marsh_done": true}
	prog.current_day = 0
	game.state.clock_minutes = 10.0 * 60.0
	await frames(60)
	check(game.egg_node != null and str(game.egg_node.get_meta("where")) == "porch", "the egg waits on the porch")
	check(game.egg_node.global_position.distance_to(game.egg_porch_pos()) < 0.1, "...in its straw nest by the front door")
	check(game.incubator_node != null and game.incubator_node.global_position.distance_to(game.incubator_pos()) < 0.1, "Dr. Marsh's incubator is in the living room")
	check(game.incubator_pos().distance_to(game.HOME_POS) < 6.5, "...inside Grandpa's house")
	# picking it up puts it in the incubator
	game._take_egg()
	await frames(5)
	game.hud.close_card()
	check(str(prog.companion()["state"]) == "egg" and game.egg_node != null and str(game.egg_node.get_meta("where")) == "incubator", "picked up, the egg goes into the incubator")
	check(game.egg_node.global_position.y > game.incubator_pos().y + 0.5 and game.egg_node.global_position.distance_to(game.incubator_pos() + Vector3(0, 0.64, 0)) < 0.1, "it lies on the incubator's bed")
	check(prog.companion_hatch_in(0) == 2, "it hatches in two days")
	# it hatches in the incubator and climbs out
	game.hatch_wobble = false
	prog.current_day = 2
	game.state.clock_minutes = 2.0 * 1440.0 + 600.0
	await frames(80)
	check(str(prog.companion()["state"]) == "alive" and game.companion_node != null, "after two days it hatches")
	game.hud.close_card()
	check(game.incubator_node != null and is_instance_valid(game.incubator_node), "the incubator stays in the house")
	game.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
