extends SceneTree
# Run in isolated test project containing only candidate GLB and this script.
func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	assert(Engine.get_version_info().major == 4 and Engine.get_version_info().minor == 3)
	var packed = load("res://Dmitri_Candidate.glb") as PackedScene
	assert(packed != null)
	var candidate = packed.instantiate()
	root.add_child(candidate)
	var skels = candidate.find_children("*", "Skeleton3D", true, false)
	assert(skels.size() == 1)
	var sk = skels[0] as Skeleton3D
	assert(sk.get_bone_count() == 26)
	for side in ["Right", "Left"]:
		for bone in ["UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot", "Toes"]:
			assert(sk.find_bone(side + bone) >= 0)
	for socket in ["Socket_RightHand", "Socket_LeftHand", "Socket_Head", "Socket_Back"]:
		assert(sk.find_bone(socket) >= 0)
	var meshes = candidate.find_children("*", "MeshInstance3D", true, false)
	assert(meshes.size() == 1)
	var mi = meshes[0] as MeshInstance3D
	assert(mi.mesh.get_surface_count() == 1)
	assert(mi.skin != null)
	var mat = mi.mesh.surface_get_material(0) as StandardMaterial3D
	assert(mat != null and mat.albedo_texture != null)
	assert(mat.albedo_texture.get_width() == 256 and mat.albedo_texture.get_height() == 256)
	# The GLB exports NEAREST. Force nearest without mipmapping for the engine preview.
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	assert(mat.metallic == 0.0)
	var bounds = mi.get_aabb()
	assert(bounds.size.y > 1.8 and bounds.size.y < 1.95)
	assert(absf(bounds.position.y) < 0.001)
	var players = candidate.find_children("*", "AnimationPlayer", true, false)
	assert(players.size() == 1)
	var ap = players[0] as AnimationPlayer
	for clip in ["Idle", "Walk"]:
		assert(ap.has_animation(clip))
		ap.play(clip)
		for t in [0.0, 0.25, 0.5, 0.75]:
			ap.seek(t, true)
			sk.force_update_all_bone_transforms()
			for i in sk.get_bone_count():
				assert(sk.get_bone_global_pose(i).is_finite())
		ap.stop()
	# Exercise the existing, unmodified VeilRig on this candidate in the isolated harness.
	# Copy scripts/art/veil_rig.gd alongside this test before running it.
	var rig_script = load("res://veil_rig.gd")
	assert(rig_script != null)
	var driver = rig_script.new()
	driver.setup(sk, 0.0)
	var tool = Node3D.new()
	tool.name = "pickaxe"
	driver.add_tool(tool, {"name": "pickaxe", "hand": "Right", "gp": Vector3(0, 0, 0.05), "support": Vector3(0, 0, 0.25), "dir": Vector3(0, 0.25, 1), "up": Vector3.UP})
	var maximum_grip_error := 0.0
	for state in ["idle", "walk", "turn", "work", "pickup", "unload"]:
		for frame in 120:
			driver.pose(1.0 / 60.0, state, 2.0 if state == "walk" else 0.0, "miner", state == "unload", float(frame) / 119.0, 1.0 if state == "turn" else 0.0)
			sk.force_update_all_bone_transforms()
			for i in sk.get_bone_count():
				assert(sk.get_bone_global_pose(i).is_finite())
			var hx = driver._hand_xf("Right")
			var palm = hx.origin + hx.basis.y * 0.075
			maximum_grip_error = maxf(maximum_grip_error, palm.distance_to(tool.transform * Vector3(0, 0, 0.05)))
	assert(maximum_grip_error < 0.001)
	print("PASS unmodified VeilRig: idle, walk, turn, mining, pickup, unload; maximum right grip error m = ", maximum_grip_error)
	await process_frame
	print("PASS Godot ", Engine.get_version_info().string, " Compatibility import: 22 deform bones + 4 socket bones, one textured skinned surface, four sockets, Idle and Walk. Bounds ", bounds)
	candidate.free()
	await process_frame
	quit(0)
