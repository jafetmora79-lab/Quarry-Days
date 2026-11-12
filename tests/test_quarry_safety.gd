extends SceneTree
## Phase 8.1: the physical quarry is safe. Real physics (a capsule like the player's) walks every ramp and floor of all
## four levels, down and back up; nothing can be mined from under the player's feet; a pit that cannot be left is
## recovered from; excavated rock never comes back after a save.
##   godot --headless --fixed-fps 60 -s tests/test_quarry_safety.gd

const OFF := Vector2(0.37, 0.41)

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

func frames(n: int, until := Callable()) -> int:
	for i in range(n):
		await physics_frame
		if until.is_valid() and until.call():
			return i
	return n

var ignore: Array = []

func ground_y(game, lx: float, lz: float) -> float:
	var w: Vector3 = game.pit_zone.to_world(Vector3(lx, 8.0, lz))
	var q := PhysicsRayQueryParameters3D.create(w, w + Vector3(0, -40.0, 0), 1)
	q.exclude = ignore
	var h: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(q)
	return -99.0 if h.is_empty() else float(game.pit_zone.to_loc(h["position"]).y)

func fill_all(game) -> void:
	var prog = game.prog
	for id in prog.cfg["formations"]:
		if prog.fdef(id).get("frame", "") != "pit":
			continue
		prog.init_formation(id)
		var d: Dictionary = prog.state.deposits[id]
		for i in range(d["columns"].size()):
			d["columns"][i] = int(prog.column_max(id, i))
		prog._sync_stock(d)
		game._refresh_deposit(id)

func empty_all(game) -> void:
	var prog = game.prog
	for id in prog.cfg["formations"]:
		if prog.fdef(id).get("frame", "") != "pit":
			continue
		prog.init_formation(id)
		var d: Dictionary = prog.state.deposits[id]
		for i in range(d["columns"].size()):
			d["columns"][i] = 0
		prog._sync_stock(d)
		game._refresh_deposit(id)

## Walks the real player (same capsule, gravity, snap and ledge climbing) through pit-local waypoints (x, z).
func walk(game, route: Array, label: String) -> bool:
	var pz = game.pit_zone
	var pl = game.player
	for wp in route:
		var gl: Vector3 = pz.to_world(Vector3(wp.x, 0.0, wp.y))
		var t := 0
		var arrived := false
		while t < 1500:
			var d := Vector3(gl.x - pl.global_position.x, 0, gl.z - pl.global_position.z)
			if d.length() < 0.25:
				arrived = true
				break
			pl.drive_wish = d
			await physics_frame
			t += 1
			if pz.to_loc(pl.global_position).y < -17.0:
				pl.drive_wish = Vector3.INF
				printerr("   %s: fell out of the world near %s" % [label, str(wp)])
				return false
		pl.drive_wish = Vector3.ZERO
		if not arrived:
			pl.drive_wish = Vector3.INF
			var kc := KinematicCollision3D.new()
			var dd := Vector3(gl.x - pl.global_position.x, 0, gl.z - pl.global_position.z).normalized()
			var hit: bool = pl.test_move(pl.global_transform, dd * 0.3, kc)
			printerr("   %s: stuck before %s at %s; blocked by %s normal %s" % [label, str(wp), str(pz.to_loc(pl.global_position)), (kc.get_collider().name if hit and kc.get_collider() else "nothing"), str(kc.get_normal()) if hit else ""])
			return false
		var want := ground_y(game, wp.x, wp.y)
		var got: float = pz.to_loc(pl.global_position).y
		if absf(got - want) > 0.6:
			pl.drive_wish = Vector3.INF
			printerr("   %s: at %s the player is at y %.2f but the ground is %.2f" % [label, str(wp), got, want])
			return false
	pl.drive_wish = Vector3.INF
	return true

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.natural_start_enabled = false      # Phase 10: these suites test the older systems on the old starting layout
	root.add_child(game)
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._remove_walter()
	var prog: QuarryProgression = game.prog
	prog.cleanup["done"] = true
	game._sync_pit_gate()
	game.player.locked = true
	await frames(6)
	var pz = game.pit_zone
	# ---- 1: the ground is continuous (offset rays, so no ray falls exactly between two boxes)
	var holes := 0
	var low := 0
	var rects := [Rect2(-4, -66, 8, 66)]      # corridor-to-plateau strip, the basin ramp
	for lp in pz.level_pits:
		rects.append(lp["rect"])
	for r in rects:
		var x: float = r.position.x
		while x < r.end.x:
			var z: float = r.position.y
			while z < r.end.y:
				var y := ground_y(game, x + OFF.x * 0.5, z + OFF.y * 0.5)
				if y < -90.0:
					holes += 1
				elif y < pz.deepest_y - 0.5:
					low += 1
				z += 0.75
			x += 0.75
	check(holes == 0 and low == 0, "1 fresh quarry: no point of any level or ramp has no ground (%d holes, %d too low)" % [holes, low])
	empty_all(game)
	await frames(4)
	holes = 0
	for lp in pz.level_pits:
		var r: Rect2 = lp["rect"]
		var x: float = r.position.x + 0.1
		while x < r.end.x - 0.1:
			var z: float = r.position.y + 0.1
			while z < r.end.y - 0.1:
				if ground_y(game, x + OFF.x * 0.5, z + OFF.y * 0.5) < -90.0:
					holes += 1
				z += 0.75
			x += 0.75
	check(holes == 0, "2 with every level fully excavated there is still ground everywhere (%d holes)" % holes)
	# ---- 3: walk all four levels down and back up with a real capsule
	var route := [Vector2(0, -20), Vector2(0, -46), Vector2(0, -72), Vector2(-20, -60), Vector2(-54.5, -60), Vector2(-54.5, -80), Vector2(-54.5, -110), Vector2(-54.5, -143), Vector2(-15.5, -143),
		Vector2(-15.5, -112), Vector2(-15.5, -95), Vector2(-36.5, -92), Vector2(-36.5, -100), Vector2(-36.5, -130)]
	ignore = [game.player.get_rid()]
	game.player.locked = false
	game.safety.enabled = false
	game.player.global_position = pz.to_world(Vector3(0, 0.3, -12))
	await frames(10)
	var ok := await walk(game, route, "down")
	check(ok, "3 the player goes from the pit gate down the basin ramp and through the ramps of levels 2, 3 and 4")
	var lvl4 := ground_y(game, -36.5, -130)
	check(absf(pz.to_loc(game.player.global_position).y - lvl4) < 0.6 and lvl4 < -14.0, "3b it ends on the level 4 floor (y %.2f)" % pz.to_loc(game.player.global_position).y)
	var back := route.duplicate()
	back.reverse()
	ok = await walk(game, back, "up")
	check(ok and pz.to_loc(game.player.global_position).y > -0.5, "4 and walks all the way back up to the plateau (y %.2f)" % pz.to_loc(game.player.global_position).y)
	game.safety.enabled = true
	# ---- 5: nothing can be mined from under the player's feet
	var kind := "bench_l2_coal"
	game.state.deposits.erase(kind)
	prog.init_formation(kind)
	prog.quarry_level = 2
	prog.level_unlocked = 2
	var col := 3
	var top: Vector3 = prog.column_pos(kind, col)
	game.player.global_position = top + Vector3(0, 3.7, 0)
	game.player.velocity = Vector3.ZERO
	await frames(2)
	var before: int = prog.column_units(kind, col)
	check(game._column_has_player(kind, col), "5 the column under the player is protected")
	var ex: Dictionary = prog.extract(kind, col, 999.0)
	check(int(ex["units"]) == 0 and prog.column_units(kind, col) == before, "5b no tool, crew, rig or companion can take it out from under them")
	var mined: int = game.player_mine(kind, col, 999.0, top)
	check(mined == 0 and prog.column_units(kind, col) == before, "5c the player's own pick refuses it too")
	game.player.global_position = top + Vector3(6, 3.7, 0)
	check(not game._column_has_player(kind, col), "5d a column the player is not on is not protected")
	# ---- 6: a deep sealed pit is recovered from, a one-tier ledge is climbed
	fill_all(game)
	await frames(4)
	game.player.locked = false
	var s = game.safety
	var fk := "bench_l2_iron"
	var d: Dictionary = prog.state.deposits[fk]
	var hole_col := 8
	var next_col := 9
	var hole: Vector3 = prog.column_pos(fk, hole_col)
	d["columns"][hole_col] = 0
	game._refresh_deposit(fk)
	await frames(4)
	game.player.global_position = prog.column_pos(fk, next_col) + Vector3(0, 3.8, 0)
	game.player.velocity = Vector3.ZERO
	s.watching = false
	s.ring.clear()
	await frames(60)
	check(game.player.is_on_floor() and not s.ring.is_empty(), "6 the safeguard remembers firm ground (%d positions)" % s.ring.size())
	var safe_before: Vector3 = s.safe_pos()
	var top_y: float = game.player.global_position.y
	game.player.global_position = hole + Vector3(0, 4.9, 0)
	game.player.velocity = Vector3.ZERO
	var n_before: int = s.rescues
	await frames(50)
	check(game.player.global_position.y < top_y - 2.5, "6b the player drops three tiers into the sealed pit (y %.2f -> %.2f)" % [top_y, game.player.global_position.y])
	await frames(420)
	check(s.rescues == n_before + 1 and game.player.global_position.distance_to(safe_before) < 1.6, "6c with no way out they are lifted back to firm ground after a few seconds (%d rescues, %.1f m from the safe spot)" % [s.rescues, game.player.global_position.distance_to(safe_before)])
	# one tier deep: climbed out by walking
	d["columns"][hole_col] = int(prog.fdef(fk)["chunk_units"]) * 2
	prog._sync_stock(d)
	game._refresh_deposit(fk)
	await frames(4)
	game.player.global_position = hole + Vector3(0, 2.4, 0)
	game.player.velocity = Vector3.ZERO
	s.watching = false
	await frames(50)
	var y_in: float = game.player.global_position.y
	var out_dir: Vector3 = (prog.column_pos(fk, next_col) - hole).normalized()
	var climbed := false
	for i in range(240):
		game.player.drive_wish = out_dir
		await physics_frame
		if game.player.global_position.y > y_in + 0.9:
			climbed = true
			break
	game.player.drive_wish = Vector3.INF
	check(climbed, "6d one rock tier is a ledge the player can climb out of (y %.2f -> %.2f)" % [y_in, game.player.global_position.y])
	# a rock face taller than one tier is not climbable
	d["columns"][hole_col] = 0
	game._refresh_deposit(fk)
	await frames(4)
	game.player.global_position = hole + Vector3(0, 1.0, 0)
	game.player.velocity = Vector3.ZERO
	s.watching = false
	await frames(60)
	y_in = game.player.global_position.y
	climbed = false
	for i in range(120):
		game.player.drive_wish = out_dir
		await physics_frame
		if game.player.global_position.y > y_in + 0.9:
			climbed = true
			break
	game.player.drive_wish = Vector3.INF
	check(not climbed, "6e a three-tier wall cannot be climbed")
	# ---- 7: excavated rock never comes back
	empty_all(game)
	await frames(2)
	var mined_before := {}
	for id in prog.cfg["formations"]:
		if prog.fdef(id).get("frame", "") == "pit":
			mined_before[id] = (prog.state.deposits[id]["columns"] as Array).duplicate()
	game._save(true)
	game._load(true)
	await frames(6)
	var same := true
	var colliders_ok := true
	for id in mined_before:
		var cols: Array = prog.state.deposits[id]["columns"]
		if cols != mined_before[id]:
			same = false
		var node = game.formation_nodes[id]
		for i in range(cols.size()):
			if int(cols[i]) <= 0 and not node.shapes[i].disabled:
				colliders_ok = false
	check(same, "7 every excavated column is still excavated after a save and load")
	check(colliders_ok, "7b and its collision is still gone (no invisible rock)")
	game._load(true)
	await frames(4)
	same = true
	for id in mined_before:
		if (prog.state.deposits[id]["columns"] as Array) != mined_before[id]:
			same = false
	check(same, "7c loading twice changes nothing")
	# ---- 8: workers can reach every level by the navigation mesh, and come back
	empty_all(game)
	prog.quarry_level = 4
	game._sync_pit_gate()
	pz.request_bake()
	var waited := 0
	while (pz.is_baking() or pz.bake_count < 1) and waited < 1200:
		await physics_frame
		waited += 1
	await frames(5)
	var gate_w: Vector3 = pz.to_world(Vector3(0, 0.0, -10))
	var targets := {"the basin floor": Vector3(-6, -3.6, -58), "the level 2 floor": Vector3(-54.5, -7.2, -100), "the level 3 floor": Vector3(-15.5, -10.8, -100), "the level 4 floor": Vector3(-36.5, -14.4, -125)}
	for tname in targets:
		var tw: Vector3 = pz.to_world(targets[tname])
		var pth: PackedVector3Array = NavigationServer3D.map_get_path(game.nav_map, gate_w, tw, true)
		var reach: bool = pth.size() > 1 and pth[pth.size() - 1].distance_to(tw) < 1.3
		check(reach, "8 a worker can walk from the pit gate to %s (%d points)" % [tname, pth.size()])
		var rpth: PackedVector3Array = NavigationServer3D.map_get_path(game.nav_map, tw, gate_w, true)
		var rback: bool = rpth.size() > 1 and rpth[rpth.size() - 1].distance_to(gate_w) < 1.3
		check(rback, "8b and back out again from %s" % tname)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
