extends SceneTree
## The Blender production equipment is what the game really uses (world machines, placement ghosts, catalog previews all contain the Blender model), it stands on
## the ground (lowest point within 0.12 m of it, nothing sunk), and it is PHYSICALLY CONNECTED: measured on the real meshes at the positions the snapping uses, a
## crusher's chute tip overlaps the start of a belt, a belt's end overlaps a crusher's feed lip and a bin's inlet spout, belts butt end to end, and an incline's
## exit hood is above a bin's rim.
##   godot --headless --fixed-fps 60 -s tests/test_equipment_alignment.gd

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

## AABB of every mesh below `n` (the visible static parts), in n's frame; holders (flywheels, jaw, caps) are skipped via `skip`.
func aabb_of(n: Node3D, skip := []) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var cur: Node = m
		var skipped := false
		while cur != null and cur != n:
			if skip.has(str(cur.name)):
				skipped = true
			xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		if skipped:
			continue
		var b := xf * m.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

func model(game, fn: String, arg = null) -> Node3D:
	var n := Node3D.new()
	root.add_child(n)
	if arg == null:
		game.art.call(fn, n, 0.0)
	else:
		game.art.call(fn, n, 0.0, arg)
	return n

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
	var caps := ["EndCap_In", "EndCap_Out"]
	var specs := {"crusher": ["crusher_model", 1], "crusher_adv": ["crusher_model", 2], "hopper": ["hopper_model", null], "bin": ["output_model", null], "storage": ["storage_model", null],
		"belt": ["conveyor_model", null], "belt_short": ["conveyor_short_model", null], "belt_incline": ["conveyor_incline_model", null], "belt_merger": ["conveyor_merger_model", null],
		"belt_splitter": ["conveyor_splitter_model", null]}
	var boxes := {}
	for k in specs:
		var n := model(game, specs[k][0], specs[k][1])
		check(n.find_child("Equip_*", true, false) != null, "%s: the art builds the Blender model" % k)
		var b := aabb_of(n, caps)
		boxes[k] = b
		check(b.position.y > -0.01 and b.position.y < 0.12, "%s: stands on the ground (lowest point %.3f m)" % [k, b.position.y])
		n.queue_free()
	for k in ["belt_left", "belt_right"]:
		var n := Node3D.new()
		root.add_child(n)
		game.art.conveyor_corner_model(n, 0.0, k.substr(5))
		check(n.find_child("Equip_*", true, false) != null, "%s: the art builds the Blender model" % k)
		var b := aabb_of(n, caps)
		check(b.position.y > -0.01 and b.position.y < 0.12, "%s: stands on the ground" % k)
		n.queue_free()
	# --- connections, measured on the meshes (flow runs toward -Z; the snapping puts a belt 2.0 m out from a crusher, 1.8 m in front of its feed side)
	var c1: AABB = boxes["crusher"]
	var belt: AABB = boxes["belt"]
	check(c1.position.z <= -1.04 and c1.position.z >= -1.12, "crusher: the chute tip reaches z %.2f" % c1.position.z)
	check(c1.position.z <= (-2.0 + belt.end.z) + 0.001 and c1.position.z - (-2.0 + belt.end.z) > -0.12, "crusher chute overlaps the start of the belt snapped 2.0 m out (gap %.3f)" % (c1.position.z - (-2.0 + belt.end.z)))
	check(c1.end.z >= (1.8 + belt.position.z) - 0.001 and c1.end.z - (1.8 + belt.position.z) < 0.15, "the feed lip (z %.2f) reaches the end of the belt snapped 1.8 m behind it" % c1.end.z)
	var adv: AABB = boxes["crusher_adv"]
	check(adv.position.z <= (-2.2 + belt.end.z) + 0.001 and adv.position.z - (-2.2 + belt.end.z) > -0.12, "advanced crusher chute meets its belt (%.2f)" % adv.position.z)
	check(adv.end.z >= (2.2 + belt.position.z) - 0.001 and adv.end.z - (2.2 + belt.position.z) < 0.15, "advanced crusher feed lip meets its belt (%.2f)" % adv.end.z)
	# belts butt end to end: a straight belt is exactly 2 m between end faces (rollers aside), so neighbours at 2.0 m spacing touch within a hair
	check(absf((belt.end.z - belt.position.z) - 2.0) < 0.12, "a straight belt is 2 m long (%.2f)" % (belt.end.z - belt.position.z))
	check(absf((boxes["belt_short"].end.z - boxes["belt_short"].position.z) - 1.0) < 0.12, "the short belt is 1 m long")
	check(absf((boxes["belt_incline"].end.z - boxes["belt_incline"].position.z) - 3.0) < 0.2, "the incline is 3 m long (%.2f)" % (boxes["belt_incline"].end.z - boxes["belt_incline"].position.z))
	var bin: AABB = boxes["bin"]
	check(-1.75 + 1.0 - bin.position.z >= -0.001 and (bin.position.z - (-0.75)) < 0.0, "a belt snapped 1.75 m from a bin ends inside its inlet spout (spout at z %.2f, belt end -0.75)" % bin.position.z)
	var sto: AABB = boxes["storage"]
	check(sto.end.x >= 1.1 and sto.end.x <= 1.2 and sto.end.z >= 0.86 and sto.end.z <= 0.95, "the storage container's spouts stand 0.1 m out on every side (x %.2f, z %.2f)" % [sto.end.x, sto.end.z])
	check(boxes["belt_incline"].end.y > bin.end.y + 0.1 and boxes["belt_incline"].end.y < bin.end.y + 0.6, "the incline's exit hood (%.2f m) is just above a bin's rim (%.2f m)" % [boxes["belt_incline"].end.y, bin.end.y])
	check(boxes["belt_incline"].end.y > boxes["hopper"].end.y, "and above the small hopper's rim (%.2f m)" % boxes["hopper"].end.y)
	# --- the real world, the ghost and the catalog preview use the same models
	var st = game.state
	st.new_crusher(Vector3(40, 0, 40), 0.0, 1)
	game._create_crusher(st.crushers.size() - 1)
	var bz: int = game.business.add_conveyor(Vector3(40, 0, 38), 0.0, "incline")
	game._create_conveyor(bz)
	var cn: Node3D = game.crusher_nodes[st.crushers.size() - 1]
	check(cn.find_child("Equip_crusher", true, false) != null and cn.has_meta("flywheels") and cn.get_meta("flywheels").size() == 2 and cn.has_meta("jaw"), "the crusher in the world is the Blender model with its flywheels and jaw wired to the animation")
	var bn: Node3D = game.conveyor_nodes[bz]
	check(bn.find_child("Equip_belt_incline", true, false) != null and bn.get_meta("belt", null) != null, "the incline in the world is the Blender model, with its belt surface")
	game.ghost = Node3D.new()
	game.world.add_child(game.ghost)
	game._crusher_visual(game.ghost, true, 1)
	check(game.ghost.find_child("Equip_crusher", true, false) != null, "the placement ghost is the Blender model")
	var spec_ok := true
	for spec in [{"kind": "crusher", "tier": 1}, {"kind": "conveyor", "belt": "incline"}, {"kind": "conveyor", "belt": "splitter"}, {"kind": "output"}, {"kind": "hopper"}]:
		var node: Node3D = QuarryPreview.build_model(game, spec)
		if node != null and node.find_child("Equip_*", true, false) == null:
			spec_ok = false
	check(spec_ok, "the catalog preview builds the Blender models")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
