extends SceneTree
func _initialize():
	call_deferred("run")
func walk(n: Node, depth: int) -> void:
	if depth > 3: return
	var info := ""
	if n is Node3D:
		info = " pos=" + str((n as Node3D).position.snapped(Vector3(0.001,0.001,0.001))) + " rot=" + str((n as Node3D).rotation_degrees.snapped(Vector3(0.1,0.1,0.1)))
	print("TREE ", "  ".repeat(depth), n.name, info)
	for c in n.get_children():
		if c is Node3D and not (c is MeshInstance3D):
			walk(c, depth + 1)
func run():
	var rig := ExcavatorRig.new()
	root.add_child(rig)
	await process_frame
	walk(rig.model, 0)
	for k in ["Marker_Seat", "Marker_Eye", "Pin_BoomFoot", "Pin_Elbow", "Marker_ExhaustTip"]:
		var n := rig.model.find_child(k, true, false) as Node3D
		print("MARK ", k, " global ", n.global_position if n else "none")
	quit()
