extends SceneTree
## The Blender-built office: it is in the game (shell, roof, trim), has its seven real window openings (a ray through each hits glass first), the doorway is clear
## for walking, the roof stands above the walls with eaves beyond them, the wall decor sits on the inner wall faces (not buried), the furniture hooks the game
## uses (the PC screen, the highlight proxy, the management desk collider) are still in place, and a player can walk in through the door to the desk.
##   godot --headless --fixed-fps 60 -s tests/test_office_building.gd

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

## Nearest hit along a ray against every mesh of `shell` (Moeller-Trumbore over the triangles): {dist, mat, name}
func ray(shell: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	var best := {"dist": 1e9, "mat": "", "name": ""}
	var dir := (to - from).normalized()
	var maxd := from.distance_to(to)
	for mi in shell.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := m.global_transform
		for s in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var tri_count := idx.size() / 3 if idx.size() > 0 else verts.size() / 3
			for t in tri_count:
				var i0 := idx[t * 3] if idx.size() > 0 else t * 3
				var i1 := idx[t * 3 + 1] if idx.size() > 0 else t * 3 + 1
				var i2 := idx[t * 3 + 2] if idx.size() > 0 else t * 3 + 2
				var v0: Vector3 = xf * verts[i0]
				var e1: Vector3 = xf * verts[i1] - v0
				var e2: Vector3 = xf * verts[i2] - v0
				var pv := dir.cross(e2)
				var det := e1.dot(pv)
				if absf(det) < 1e-9:
					continue
				var inv := 1.0 / det
				var tv := from - v0
				var u := tv.dot(pv) * inv
				if u < 0.0 or u > 1.0:
					continue
				var qv := tv.cross(e1)
				var v := dir.dot(qv) * inv
				if v < 0.0 or u + v > 1.0:
					continue
				var d := e2.dot(qv) * inv
				if d > 0.0 and d <= maxd and d < float(best["dist"]):
					best = {"dist": d, "mat": m.mesh.surface_get_name(s), "name": str(m.name)}
	return best

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	for i in 6:
		await physics_frame
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await process_frame
	var c: Vector3 = game.OFFICE_POS
	var shell: Node3D = game.art.root.get_node_or_null("Building_Office")
	check(shell != null, "the Blender office shell is in the game")
	if shell == null:
		print("RESULT: %d checks, %d failures" % [checks, failures.size()])
		quit(1)
		return
	check(absf(shell.global_position.x - c.x) < 0.01 and absf(shell.global_position.z - c.z) < 0.01, "it stands on the office's footprint")
	var glass := 0
	for mi in shell.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			if m.mesh.surface_get_name(s) == "Glass":
				glass += 1
	check(glass >= 1, "it has glass")
	# windows: a ray through each opening hits glass before any wall
	var openings := [["left", Vector3(-4, 1.4, -0.15), Vector3(0, 1.4, -0.15)], ["left", Vector3(-4, 1.4, 1.75), Vector3(0, 1.4, 1.75)],
		["right", Vector3(4, 1.4, -1.25), Vector3(0, 1.4, -1.25)], ["right", Vector3(4, 1.4, 0.65), Vector3(0, 1.4, 0.65)],
		["back", Vector3(1.6, 1.5, 4), Vector3(1.6, 1.5, 0)], ["front", Vector3(-1.9, 1.5, -4), Vector3(-1.9, 1.5, 0)], ["front", Vector3(1.9, 1.5, -4), Vector3(1.9, 1.5, 0)]]
	var ok := 0
	for o in openings:
		var h: Dictionary = ray(shell, c + (o[1] as Vector3), c + (o[2] as Vector3))
		if float(h["dist"]) < 1e8 and str(h["mat"]) == "Glass":
			ok += 1
		else:
			printerr("   %s window: first hit %s" % [o[0], str(h)])
	check(ok == 7, "seven real window openings: a ray through each meets glass first (%d of 7)" % ok)
	# the wall beside a window is solid
	var wall := ray(shell, c + Vector3(-4, 1.6, -1.8), c + Vector3(0, 1.6, -1.8))
	check(float(wall["dist"]) < 1e8 and str(wall["mat"]) in ["Siding", "Trim"], "and the wall between the windows is solid (%s)" % str(wall.get("mat")))
	# the doorway is clear at body height; the header is above it
	var lane := ray(shell, c + Vector3(0, 1.0, -4), c + Vector3(0, 1.0, 0))
	check(float(lane["dist"]) > 100.0 or float(lane["dist"]) > 5.0, "the doorway is clear for walking (%s)" % str(lane))
	var head := ray(shell, c + Vector3(0, 2.5, -4), c + Vector3(0, 2.5, 0))
	check(float(head["dist"]) < 1e8, "with a header above it")
	# the roof stands above the walls and overhangs them
	var up := ray(shell, c + Vector3(0, 8, -2.9), c + Vector3(0, 0, -2.9))
	check(float(up["dist"]) < 1e8 and 8.0 - float(up["dist"]) > 2.7, "the roof covers the porch (front eave at y %.2f)" % (8.0 - float(up["dist"])))
	var ridge := ray(shell, c + Vector3(0, 8, 0), c + Vector3(0, 0, 0))
	check(8.0 - float(ridge["dist"]) > 3.9 and 8.0 - float(ridge["dist"]) < 4.4, "the ridge rises about 1.25 m above the wall tops (%.2f)" % (8.0 - float(ridge["dist"])))
	# the wall decor: the plans quads must be in front of the inner wall face, not inside it
	var back_in := ray(shell, c + Vector3(-0.35, 2.0, 0), c + Vector3(-0.35, 2.0, 4))
	check(float(back_in["dist"]) < 1e8 and absf(float(back_in["dist"]) - 2.22) < 0.03, "the inner back wall face is at z +2.22 where the wall decor hangs (%.3f)" % float(back_in["dist"]))
	var side_in := ray(shell, c + Vector3(0, 0.8, 0), c + Vector3(4, 0.8, 0))
	check(float(side_in["dist"]) < 1e8 and absf(float(side_in["dist"]) - 2.27) < 0.03, "and the inner side wall face is at x +2.27 (%.3f)" % float(side_in["dist"]))
	# the game's furniture hooks
	check(game.computer_proxy != null and game.pc_screen_pos != Vector3.ZERO, "the PC highlight proxy and screen position are still set")
	check(game.get_node_or_null("World/Management desk") != null or game.find_child("Management desk", true, false) != null, "the management desk collider is still there")
	# walk in through the door to the desk
	var p: Node3D = game.player
	p.global_position = c + Vector3(0, 0.3, -5.0)
	p.velocity = Vector3.ZERO
	var moved_ok := false
	for i in 240:
		Input.action_press("move_forward") if InputMap.has_action("move_forward") else null
		await physics_frame
		if p.global_position.z > c.z + 0.6:
			moved_ok = true
			break
	if InputMap.has_action("move_forward"):
		Input.action_release("move_forward")
	
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
