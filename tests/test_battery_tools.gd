extends SceneTree
## The battery sits in a pocket cut into the excavator's hood; the office has no back window; the tool plate has no progress bar; and the workbench never offers a tool
## or cart you own or have outgrown.   godot --headless --fixed-fps 60 -s tests/test_battery_tools.gd
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
func titles(n: Node, out: Array) -> void:
	if n is Label and n.is_visible_in_tree():
		out.append((n as Label).text)
	for c in n.get_children():
		titles(c, out)
func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	for i in 10:
		await physics_frame
	var prog = game.prog
	var st = game.state
	# ---- the pocket: the battery's bottom is below the hood top and its sides are inside the opening
	var v: QuarryVehicle = game._starter_vehicle()
	prog.story["excavator"]["battery"] = true
	game._decorate_starter()
	var n: Node3D = v.turret.get_node("OpeningParts")
	var inside := false
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = (mi as MeshInstance3D).mesh.get_aabb()
		if bb.position.y < OpeningModels.POCKET_FLOOR + 0.02 and bb.end.y > 1.55:
			inside = true
	check(inside, "the fitted battery stands down in the pocket (its bottom on the pocket floor, its top above the hood)")
	check(OpeningModels.BATTERY_SIZE.x < OpeningModels.POCKET.size.x and OpeningModels.BATTERY_SIZE.z < OpeningModels.POCKET.size.y and OpeningModels.POCKET_FLOOR + OpeningModels.BATTERY_SIZE.y > 1.55, "it fits the opening with room to spare and stands proud of the hood")
	check(RepairSequence.SOCKET["battery"].x > 0.34 and RepairSequence.SOCKET["battery"].x < 0.78, "the repair lowers it into that pocket")
	# a bought excavator already has one
	var rec: Dictionary = game.fleet.give("compact_excavator", Vector3(0, 0, 50), 0.0)
	game._sync_vehicles()
	var ex: QuarryVehicle = game.vehicle_nodes[int(rec["id"])]
	check(ex.turret.get_node_or_null("OpeningParts") != null, "a bought excavator has its battery in the pocket from the start")
	# ---- no back window on the office
	var back_glass := 0
	for mi in game.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh != null and m.global_position.distance_to(game.OFFICE_POS + Vector3(1.8, 1.7, 2.4)) < 0.5 and str(m.material_override.resource_path if m.material_override else "").ends_with("Glass.tres"):
			back_glass += 1
	check(back_glass == 0, "the office has no window in its back wall")
	# ---- the tool plate has no progress bar
	check(not game.hud.power_bar.visible, "the tool plate shows no progress bar")
	# ---- the workbench
	st.money = 100000
	prog.stage = 5
	st.tool_tier = 2
	st.gear.append("pointed_chisel")
	st.carts.append("hand_cart")
	check(prog.gear_obsolete("flat_chisel") == false, "a faster chisel is still worth offering")
	st.tool_tier = 3
	st.gear.append("steel_pickaxe")
	st.gear.append("hardened_pickaxe")
	check(prog.gear_obsolete("repaired_pickaxe") and prog.gear_obsolete("sledgehammer"), "tools weaker than what you own are outgrown (the repaired pickaxe, the sledgehammer)")
	check(prog.gear_obsolete("wheelbarrow") == false and prog.gear_obsolete("hand_cart") == false, "a bigger cart is still offered; the owned one is not 'obsolete', it is owned")
	st.carts.append("wheelbarrow")
	check(prog.gear_obsolete("wheelbarrow") == false and prog.owns("wheelbarrow"), "owned things are owned")
	game._open_menu("upgrades", -1)
	await process_frame
	var out := []
	titles(game.panel, out)
	var all := " | ".join(out)
	check(not all.contains("Rock Hammer") and not all.contains("Pointed Chisel") and not all.contains("Hand Cart") and not all.contains("Repaired Pickaxe") and not all.contains("Sledgehammer"), "the workbench list no longer shows tools you own or have outgrown")
	check(all.contains("Reinforced Wheelbarrow") or all.contains("Hand Rock Splitter") or all.contains("Powered Hammer"), "but what is still ahead of you is there")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
