extends SceneTree
## The Blender-built Colossus (an original model, not THE VEIL's): it imports, faces +Z, stands on the ground, has its joints and its clips.   godot --headless -s tests/test_colossus_model.gd

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

func run() -> void:
	var ps := load("res://assets/creatures/CRT_QD_Colossus.glb") as PackedScene
	check(ps != null, "the GLB imports")
	var n := ps.instantiate() as Node3D
	root.add_child(n)
	await process_frame
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	check(ap != null, "it has an AnimationPlayer")
	var missing := []
	for c in ["Idle_Breathe", "Walk_Heavy", "Alert", "Attack_Strike", "Attack_Heavy"]:
		if ap == null or not ap.has_animation(c):
			missing.append(c)
	check(missing.is_empty(), "all five clips are there (missing %s)" % str(missing))
	var parts := []
	for nm in ["Body", "Chest", "Head", "Maw_L", "Maw_R", "Leg_FL_0", "Leg_HR_0", "T_DorsalL_01", "T_VentB_01", "Foot_FL"]:
		if n.find_child(nm, true, false) == null:
			parts.append(nm)
	check(parts.is_empty(), "the named joints exist (missing %s)" % str(parts))
	var low := 1e9
	var high := -1e9
	var zmin := 1e9
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		low = minf(low, bb.position.y)
		high = maxf(high, bb.end.y)
		zmin = minf(zmin, bb.position.z)
	check(absf(low) < 0.35 and high > 8.0 and high < 14.0, "it stands on the ground and is %.1f m tall (feet at %.2f)" % [high, low])
	var head := n.find_child("Head", true, false) as Node3D
	var rear := n.find_child("Rear", true, false) as Node3D
	check(head.global_position.z > rear.global_position.z, "it faces +Z: the head is ahead of the rear")
	ap.play("Alert")
	ap.seek(2.0, true)
	var maw := n.find_child("Maw_L", true, false) as Node3D
	check(absf(maw.rotation.y) > 0.3, "the Alert clip splits the jaws sideways (%.2f rad about the vertical)" % maw.rotation.y)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
