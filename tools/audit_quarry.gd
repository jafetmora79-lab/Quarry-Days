extends SceneTree
## Dev tool: probes the pit with downward rays and prints an ASCII height map (pit-local coordinates).
##   godot --headless --fixed-fps 60 -s tools/audit_quarry.gd

const OFF := Vector2(0.37, 0.41)

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in range(n):
		await physics_frame

func ground_y(game, lx: float, lz: float, y_from := 8.0) -> float:
	var w: Vector3 = game.pit_zone.to_world(Vector3(lx, y_from, lz))
	var q := PhysicsRayQueryParameters3D.create(w, w + Vector3(0, -40.0, 0), 1)
	var h: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty():
		return -99.0
	return game.pit_zone.to_loc(h["position"]).y

func code(y: float) -> String:
	if y < -90.0: return "#"          # nothing under this point
	for p in [[0.0, "0"], [-3.6, "B"], [-7.2, "C"], [-10.8, "D"], [-14.4, "E"]]:
		if absf(y - p[0]) < 0.12: return p[1]
	if y > 0.2: return "^"
	return "~" if y > -14.0 else "v"   # sloped / odd

func dump(game, label: String, x0: float, x1: float, z0: float, z1: float, step := 1.0) -> void:
	print("== %s  (x %.0f..%.0f, z %.0f..%.0f, step %.1f)" % [label, x0, x1, z0, z1, step])
	var z := z0
	while z <= z1:
		var row := ""
		var x := x0
		while x <= x1:
			row += code(ground_y(game, x + OFF.x, z + OFF.y))
			x += step
		print("z%4.0f %s" % [z, row])
		z += step

func empty_all(game) -> void:
	var prog = game.prog
	for id in prog.cfg["formations"]:
		if not prog.fdef(id).get("frame", "") == "pit":
			continue
		prog.init_formation(id)
		var d: Dictionary = prog.state.deposits[id]
		for i in range(d["columns"].size()):
			d["columns"][i] = 0
		prog._sync_stock(d)
		game._refresh_deposit(id)

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game.prog.cleanup["done"] = true
	game._sync_pit_gate()
	await frames(4)
	var pz = game.pit_zone
	print("plateau z0=%.1f z1=%.1f basin zn=%.1f zs=%.1f hx=%.1f" % [pz.plateau_z0(), pz.plateau_z1(), pz.basin_zn(), pz.basin_zs(), pz.basin_w * 0.5])
	dump(game, "fresh, whole pit", -30, 30, pz.plateau_z1() - 2.0, pz.plateau_z0() + 4.0, 2.0)
	dump(game, "fresh, level pits", -29, -7, -69, -47, 1.0)
	empty_all(game)
	await frames(4)
	dump(game, "all pit rock removed, level pits", -29, -7, -69, -47, 1.0)
	# fine probe around the odd spot
	for z in [-54.6, -54.2, -53.8, -53.4]:
		var row := ""
		for xi in range(0, 21):
			row += code(ground_y(game, -11.0 + float(xi) * 0.1, z))
		print("fine z%.1f %s" % [z, row])
	quit(0)
