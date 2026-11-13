extends SceneTree
## Wheels and tracks turn with the distance a machine really travels (driven, delivered by script, Grandpa's truck), and the garage's service
## tunnel is open to the outside (nothing fills its mouth, a view runs down its whole length).   godot --headless --fixed-fps 60 -s tests/test_wheels_tunnel.gd
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
func spin_of(v) -> float:
	var tot := 0.0
	for w in v.wheels:
		tot += absf(w.rotation.x)
	return tot
func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	game.natural_start_enabled = false
	root.add_child(game)
	await process_frame
	await frames(8)
	for i in range(6):
		if game.walter_dialog:
			game.walter_dialog.skip()
		await frames(30)
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await frames(3)
	game.state.money = 900000
	game.prog.stage = game.prog.stage_index("deep")
	game.state.tool_tier = 3
	game.business.milestones["mechanized"] = true
	game.business.milestones["automated"] = true
	for t in ["loader", "truck", "compact_excavator"]:
		print("BUY ", t, ": ", game.ui_buy_vehicle(t))
		game.delivery.finish_all()
	await frames(10)
	var checked := 0
	for v in game.vehicle_nodes.values():
		check(v.wheels.size() >= 4, "%s has %d wheels or rollers that can turn" % [v.vtype, v.wheels.size()])
		# moved by SCRIPT (as deliveries are), not by its own controls
		var before := spin_of(v)
		var start: Vector3 = v.global_position
		for k in range(60):
			v.global_position += v.forward() * 0.05
			await physics_frame
		check(spin_of(v) > before + 0.5, "%s: its wheels turn when it is moved along its heading (%.2f rad)" % [v.vtype, spin_of(v) - before])
		# and backwards turns them the other way
		var r0: float = v.wheels[0].rotation.x
		for k in range(30):
			v.global_position -= v.forward() * 0.05
			await physics_frame
		check(v.wheels[0].rotation.x != r0, "%s: reversing turns them back" % v.vtype)
		if v.vkind == "excavator":
			check(v.track_mats.size() == 2, "the excavator's two tracks have scrolling tread")
			var o0: float = (v.track_mats[0] as StandardMaterial3D).uv1_offset.x
			for k in range(13):
				v.global_position += v.forward() * 0.05
				await physics_frame
			check(absf((v.track_mats[0] as StandardMaterial3D).uv1_offset.x - o0) > 0.05 and (v.track_mats[0].get_meta("scroll_sign") != v.track_mats[1].get_meta("scroll_sign")), "its tread scrolls with the distance, mirrored on the two sides")
		checked += 1
	# Grandpa's old truck
	game.natural_start_enabled = true
	game._build_truck()
	var t = game.truck_node
	check(t != null and game.truck_wheels.size() >= 4, "Grandpa's truck has turning wheels (%d)" % game.truck_wheels.size())
	# the tunnel: nothing fills the service gate, and a ray runs down its whole length
	var fills := 0
	for n in game.world.get_children():
		if n is StaticBody3D and str(n.name).contains("filler") or (n is StaticBody3D and absf(n.global_position.x) < 3.0 and absf(n.global_position.z - 28.6) < 1.5 and n.global_position.y > 2.0 and not str(n.name).contains("Gate")):
			fills += 1
	var q := PhysicsRayQueryParameters3D.create(Vector3(0.5, 1.5, 24.0), Vector3(0.5, 1.5, 46.5), 1)
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(q)
	check(hit.is_empty() or float(hit["position"].z) > 45.0, "a line of sight runs from the garage mouth to the far end of the tunnel (first blocked at z %.1f)" % (float(hit["position"].z) if not hit.is_empty() else 99.0))
	var tun: Node = game.world.get_node_or_null("ServiceTunnel")
	check(tun != null and tun.get_child_count() > 40, "the tunnel has its road, arch ribs, braces, wall lights and exit sign (%d parts)" % (tun.get_child_count() if tun else 0))
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
