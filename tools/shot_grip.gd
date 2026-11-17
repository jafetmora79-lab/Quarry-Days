extends SceneTree
## The hand rig on a plain shaft, from several sides (windowed): godot --path . --resolution 900x600 -s tools/shot_grip.gd -- <dir>
func _initialize():
	call_deferred("run")
func snap(path: String) -> void:
	for i in 3: await physics_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
func run():
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.7, 0.9)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment = e
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.8, 0.5, 0)
	world.add_child(light)
	var shaft := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.02
	cm.height = 0.9
	shaft.mesh = cm
	shaft.material_override = MeshKit.mat(QuarryArt.M_WOOD)
	shaft.position = Vector3(0, 0.3, 0)
	world.add_child(shaft)
	var rig := FPHands.new()
	world.add_child(rig)
	await process_frame
	var grips := [{"hand": "R", "at": Vector3(0, 0.45, 0), "axis": Vector3.UP, "r": 0.02, "preset": "striking", "xf": Transform3D.IDENTITY}, {"hand": "L", "at": Vector3(0, 0.12, 0), "axis": Vector3.UP, "r": 0.02, "preset": "striking", "xf": Transform3D.IDENTITY}]
	var anchors := {"R": Vector3(0.55, -0.3, 0.6), "L": Vector3(-0.55, -0.3, 0.6), "pole_R": Vector3(0.6, -1, 0.3).normalized(), "pole_L": Vector3(-0.6, -1, 0.3).normalized()}
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	cam.fov = 40
	var toward_cam := Vector3(0, 0, 1)
	rig.pose(grips, Transform3D.IDENTITY, anchors, toward_cam, 0.0, {})
	var views := {"front": Vector3(0, 0.3, 1.0), "side": Vector3(1.0, 0.3, 0.2), "back": Vector3(0.0, 0.3, -1.0), "top": Vector3(0.0, 1.2, 0.3)}
	for k in views:
		cam.global_position = views[k]
		cam.look_at(Vector3(0, 0.3, 0))
		await snap("%s/grip_%s.png" % [out, k])
	quit()
