extends SceneTree
## The Blender excavator alone (windowed run):  godot --path . --resolution 1000x700 -s tools/shot_excavator_model.gd -- <dir>
func _initialize():
	call_deferred("run")
func shot(name: String, out: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
func run():
	var out := "."
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.65, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.72)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	root.add_child(sun)
	var rig := ExcavatorRig.new()
	root.add_child(rig)
	await process_frame
	var cam := Camera3D.new()
	cam.fov = 55
	root.add_child(cam)
	cam.current = true
	var views := [["right_front", Vector3(4.0, 3.2, -4.2), Vector3(0.5, 1.4, -0.5)], ["top", Vector3(0.1, 6.5, 0.4), Vector3(0.1, 1.4, 0.0)], ["left_cab", Vector3(-4.2, 2.6, -1.2), Vector3(-0.5, 1.5, 0.0)],
		["rear_right", Vector3(3.5, 3.0, 4.2), Vector3(0.4, 1.4, 0.4)], ["tank_close", Vector3(2.4, 2.2, -1.2), Vector3(0.9, 1.3, -0.5)]]
	for v in views:
		cam.global_position = v[1]
		cam.look_at(v[2])
		await shot(v[0], out)
	quit()
