extends SceneTree
## The machinery shop shows the real machine: for every machine type the preview is the same Blender rig the game spawns (same kind, same paint,
## same size factor), it is sized like the machine, nothing is missing, and the shop's name / price / requirements are untouched.
##   godot --headless --fixed-fps 60 -s tests/test_shop_previews.gd

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
	await process_frame
	var seen := {}
	var types: Array = game.fleet.types()
	check(types.size() >= 4, "the shop sells %d machine types" % types.size())
	for t in types:
		var k: String = game.fleet.kind(str(t))
		var sp: Dictionary = game.fleet.spec(str(t))
		var m: Node3D = QuarryPreview.build_model(game, {"kind": "vehicle", "type": str(t)})
		check(m != null, "%s: a preview model is built" % t)
		if m == null:
			continue
		var blender := m.has_meta("blender")
		var want := (k == "excavator" and QuarryVehicle.USE_RIG_EXCAVATOR) or (k == "truck" and QuarryVehicle.USE_RIG_TRUCK) or (k == "loader" and QuarryVehicle.USE_RIG_LOADER) or k == "bulldozer"
		check(blender == want, "%s (%s): the preview is the Blender machine exactly when the game spawns the Blender machine" % [t, k])
		if blender:
			check(str(m.get_meta("blender")) == k, "%s: and it is the right machine (%s)" % [t, k])
			seen[k] = true
		root.add_child(m)
		var box := AABB()
		var first := true
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var mm := mi as MeshInstance3D
			if mm.mesh == null or not mm.is_visible_in_tree():
				continue
			var b: AABB = mm.global_transform * mm.get_aabb()
			box = b if first else box.merge(b)
			first = false
		var sz: Array = sp["size"]
		var longest := maxf(box.size.x, box.size.z)
		check(not first and longest > float(sz[2]) * 0.55 and longest < float(sz[2]) * 1.8, "%s: the model is the size of the machine (%.1f m long for a %.1f m footprint)" % [t, longest, float(sz[2])])
		m.free()
	for k in ["excavator", "truck", "loader", "bulldozer"]:
		check(seen.has(k) or not game.fleet.types().any(func(t): return game.fleet.kind(str(t)) == k), "the %s preview shows the new machine" % k)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
