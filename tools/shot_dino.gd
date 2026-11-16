extends SceneTree
## Saves the dinosaur set (windowed run):  godot --path . --resolution 1000x640 -s tools/shot_dino.gd -- <dir>
func _initialize():
	call_deferred("run")

func shot(name: String, out: String) -> void:
	for i in 25:
		await physics_frame
		for c in root.find_children("*", "Camera3D", true, false):
			if c.name == "ShotCam":
				c.make_current()
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])

func look(cam: Camera3D, from: Vector3, to: Vector3) -> void:
	cam.global_position = from
	cam.look_at(to)

func run():
	var out := "."
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	Engine.set_meta("qd_skip_title", true)
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	for i in 10: await physics_frame
	if game.opening_scene != null:
		game.opening_scene.skip_all()
	for i in 10: await physics_frame
	game.hud.close_card()
	game.hud.visible = false
	game.item_tips.enabled = false
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 400.0
	cam.name = "ShotCam"
	root.add_child(cam)
	cam.current = true
	# --- the adult and the hatchling on open ground in the yard (it settles facing the player, who stands far off)
	var spot := Vector3(8.0, 0.0, 3.0)
	game.prog.story["companion"] = {"state": "alive", "born_day": -20, "name": "Pebble", "stage_seen": "adult"}
	game._spawn_companion()
	var d = game.companion_node
	game.companion_node = null                                    # the game no longer drives it: it stands where it is put
	game.prog.story["companion"] = {"state": "none"}
	d.global_position = spot
	d.rotation.y = 0.0
	game.player.global_position = spot + Vector3(0, 0, 60)
	for i in 10: await physics_frame
	var fwd: Vector3 = -d.global_transform.basis.z
	var rgt: Vector3 = d.global_transform.basis.x
	look(cam, spot + fwd * 3.0 - rgt * 2.4 + Vector3(0, 1.5, 0), spot + Vector3(0, 0.7, 0))
	await shot("dino_adult_3q", out)
	look(cam, spot + fwd * 4.2 + Vector3(0, 1.2, 0), spot + Vector3(0, 0.8, 0))
	await shot("dino_adult_front", out)
	look(cam, spot - rgt * 4.2 + Vector3(0, 1.1, 0), spot + Vector3(0, 0.8, 0))
	await shot("dino_adult_side", out)
	look(cam, spot - fwd * 3.0 + rgt * 2.4 + Vector3(0, 1.5, 0), spot + Vector3(0, 0.8, 0))
	await shot("dino_adult_rear", out)
	d.set_stage("hatchling")
	for i in 10: await physics_frame
	look(cam, spot + fwd * 1.3 - rgt * 0.9 + Vector3(0, 0.7, 0), spot + Vector3(0, 0.3, 0))
	await shot("dino_hatchling", out)
	# --- the egg in the incubator in the living room
	game.prog.story["companion"] = {"state": "egg", "egg_day": 0}
	game._ensure_incubator()
	game._spawn_egg("incubator")
	var ip: Vector3 = game.incubator_pos()
	look(cam, ip + Vector3(1.9, 1.3, 1.2), ip + Vector3(0, 0.7, 0))
	game.player.global_position = ip + Vector3(0, 0, 60)
	print("INC ", ip, " HOME ", game.HOME_POS)
	await shot("incubator", out)
	look(cam, ip + Vector3(0.1, 1.15, -1.0), ip + Vector3(0, 0.75, 0))
	await shot("incubator_close", out)
	game._remove_egg()
	game._spawn_egg("porch")
	var pp: Vector3 = game.egg_porch_pos()
	look(cam, pp + Vector3(0.0, 1.0, -1.6), pp + Vector3(0, 0.4, 0))
	game.player.global_position = pp + Vector3(0, 0, 60)
	await shot("egg_porch", out)
	# --- the fossil model on open ground (in the game it lies in the floor of the deepest cut)
	var fm: Dictionary = WorldModels.animal("fossil_nest")
	var fr: Node3D = fm["root"]
	root.add_child(fr)
	fr.global_position = Vector3(8.0, 0.0, 3.0)
	look(cam, fr.global_position + Vector3(-2.6, 2.6, -3.2), fr.global_position + Vector3(0, 0.2, 0))
	await shot("fossil", out)
	look(cam, fr.global_position + Vector3(0.6, 1.2, -1.8), fr.global_position + Vector3(0.1, 0.2, 0))
	await shot("fossil_close", out)
	quit()
