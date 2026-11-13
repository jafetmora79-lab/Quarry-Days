extends SceneTree
## The exact-blueprint world: layout, the tutorial inside the real quarry, a connected road network (reachability + order), permanent excavation and saves.
##   godot --headless --fixed-fps 60 -s tests/test_blueprint_world.gd

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

func rect_of(r: Array) -> Rect2:
	return Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))

## Reachability with order: starting at the central gate, with only the roads of levels <= n built, the level-n strip is reachable over touching road rects.
func road_reachable(prog: QuarryProgression, n: int) -> bool:
	var rects: Array = [Rect2(-4.0, -12.0, 8.0, 12.0)]       # the gate road, from the yard fence (local z 0) onto the surface
	for lv in range(2, n + 1):
		for r in prog.level_def(lv).get("roads", []):
			rects.append(rect_of(r))
	var seen := {0: true}
	var stack := [0]
	while not stack.is_empty():
		var i: int = stack.pop_back()
		for j in range(rects.size()):
			if not seen.has(j) and (rects[i] as Rect2).grow(0.2).intersects(rects[j]):
				seen[j] = true
				stack.append(j)
	var pit: Dictionary = prog.level_def(n).get("pit", {})
	var strip := Rect2()
	for r in prog.level_def(n).get("roads", []):
		var rr := rect_of(r)
		if absf(rr.size.x - float(pit.get("ramp_w", 8.0))) < 0.01 and rr.size.y > 11.0:
			strip = rr
	if strip.size == Vector2.ZERO:
		return false
	for j in seen.keys():
		if (rects[j] as Rect2).grow(0.2).intersects(strip) and (rects[j] as Rect2) != strip:
			return true
	return false

func run() -> void:
	for path in ["user://quarry_save.json", "user://quarry_save.bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(8)
	for i in range(6):
		if game.walter_dialog:
			game.walter_dialog.skip()
		await frames(20)
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	game.safety.enabled = false
	var prog: QuarryProgression = game.prog
	var pz: QuarryPitZone = game.pit_zone
	# ---- the quarry: wide, fenced, flat at the start, five nested centred areas
	var fence: Array = prog.pit_cfg().get("fence", [])
	var fw := float(fence[2]) - float(fence[0])
	var fd := float(fence[3]) - float(fence[1])
	check(game.blueprint and prog.filled_world() and fw / fd > 2.3 and fw / fd < 2.7, "the quarry is a wide fenced rectangle about 2.5:1 (%.0f x %.0f m)" % [fw, fd])
	check(pz != null and pz.flat, "it starts as flat ground (no hole, no pre-dug pit)")
	var lv := prog.levels()
	check(lv.size() == 5, "five areas / levels: surface plus four dug levels (%d)" % lv.size())
	var margins := []
	var centred := true
	var prev := Rect2(-122.0, -96.0, 244.0, 92.0)
	for n in range(2, 6):
		var pit: Dictionary = lv[n - 1]["pit"]
		var r := rect_of(pit["rect"])
		centred = centred and absf(r.get_center().x) < 0.01
		if n >= 3:
			margins.append(snappedf(prev.position.x - r.position.x, 0.01) * -1.0)
		prev = r
	check(centred, "every dug area is centred on the quarry's axis")
	var same := true
	for m in margins:
		same = same and absf(float(m) - float(margins[0])) < 0.01
	check(same and margins.size() == 3, "the nested areas shrink by one consistent margin (%s)" % str(margins))
	var floors := []
	for n in range(1, 6):
		floors.append(float(lv[n - 1]["floor_y"]))
	var down := true
	for i in range(1, floors.size()):
		down = down and floors[i] < floors[i - 1]
	check(down, "each level is deeper than the one above (%s)" % str(floors))
	var hard := []
	for n in range(2, 6):
		var h := 0
		for m in lv[n - 1]["materials"]:
			h = maxi(h, int(prog.material(str(m)).get("hardness", 0)))
		hard.append(h)
	var rising := true
	for i in range(1, hard.size()):
		rising = rising and int(hard[i]) >= int(hard[i - 1])
	check(rising and int(hard[hard.size() - 1]) > int(hard[0]), "hardness rises with depth (%s)" % str(hard))
	# ---- the yard: attached on the south, one central gate, nothing mineable in it, west tunnel, no starter excavation, no rock corridor
	var hub: Rect2 = game.hub_rect()
	check(absf(hub.position.y - float(fence[3]) - -8.0 + 0.0) < 8.5 and hub.position.y <= -7.9 and hub.position.y >= -8.1, "the yard starts directly at the quarry's south fence")
	var mineable_in_yard := 0
	for id in prog.formation_ids():
		if not prog.formation_active(id):
			continue
		for i in range(prog.column_count(id)):
			if prog.column_units(id, i) > 0:
				var p: Vector3 = prog.column_pos(id, i)
				if hub.has_point(Vector2(p.x, p.z)):
					mineable_in_yard += 1
	check(mineable_in_yard == 0, "the yard has no mineable terrain (%d columns)" % mineable_in_yard)
	check(game.hillside_rect().size == Vector2.ZERO and not game.formation_nodes.has("hillside_face_01") and not game.formation_nodes.has("pit_band_01"), "no starter excavation area and no rock corridor")
	check(game.delivery.west and game.delivery.gate_point().x < hub.position.x + 0.1, "the arrival tunnel is in the west, by the garage")
	var wy := float(game.OFFICE_POS.z)
	check(game.TOOLSHED_POS.x < 0.0 and game.OFFICE_POS.x > 0.0 and game.TOOLSHED_POS.z < 8.0 and wy < 8.0, "tool shed upper-left, office upper-right")
	check(game.HOME_POS.x > 0.0 and game.HOME_POS.z > 12.0, "the house is lower-right")
	var garage_x: float = 5.0 + game.GARAGE_DX
	check(garage_x < 0.0 and prog.cfg_for("world").has("hub"), "the machinery garage is lower-left")
	# ---- the tutorial happens inside the real quarry, on the original soil
	var in_a1 := 0
	for id in prog.cleanup_ids():
		var p := prog.cleanup_pos(str(id))
		if p.x > -122.0 and p.x < 122.0 and p.y > -104.0 and p.y < -12.0:
			in_a1 += 1
	check(in_a1 == prog.cleanup_total() and in_a1 > 0, "all %d tutorial weeds and heaps lie inside the quarry (Area 1)" % in_a1)
	var top0 := prog.units_left("q_top")
	for id in prog.cleanup_ids():
		var node: Node3D = game.cleanup_nodes.get(id)
		if node != null:
			for k in range(30):
				if is_instance_valid(node):
					game.hit_debris(node, 50.0, node.global_position)
				game.state.inventory["limestone"] = 0
	await frames(20)
	check(prog.cleanup["done"] and prog.units_left("q_top") == top0, "clearing the debris does not lower the terrain (topsoil %d -> %d, done %s)" % [top0, prog.units_left("q_top"), str(prog.cleanup["done"])])
	var col := prog.nearest_column("q_top", Vector3(0, 0, -20), true, INF, "hand")
	check(col >= 0, "the first excavation can start in the topsoil")
	# ---- the road network: connected, reachable in order, and not free
	for n in range(2, 6):
		check(road_reachable(prog, n), "the level-%d access road is reachable from the gate over the roads built so far" % n)
	game.state.money = 100000
	check(prog.road_block_reason(2) != "" and not prog.road_built(2), "no road exists for free: level 2 is not open and its road is not built")
	var cost_ok := true
	for n in range(3, 6):
		cost_ok = cost_ok and prog.road_cost(n) > prog.road_cost(n - 1)
	check(cost_ok and prog.road_cost(2) > 0, "the roads are a priced construction job that grows with depth")
	# ---- permanent excavation and saves
	var cleared := 0
	for i in range(prog.column_count("q_top")):
		if i % 2 == 0:
			prog.extract("q_top", i, 1.0e6, 1 << 30, "hand")
			cleared += 1
	prog.check_levels()
	check(prog.quarry_level >= 2 and prog.buy_road(2), "excavating the surface opens level 2 and its road is bought")
	await frames(60)          # the cleanup gift from Grandpa is paid a moment after the site is clean
	var money := int(game.state.money)
	var left := prog.units_left("q_top")
	game._save(true)
	game._load(true)
	await frames(10)
	check(game.state.money == money and prog.units_left("q_top") == left and prog.road_built(2) and prog.quarry_level >= 2, "after save and load the excavation, the road and the money are all kept (money %d/%d, topsoil %d/%d, road %s, level %d)" % [game.state.money, money, prog.units_left("q_top"), left, str(prog.road_built(2)), prog.quarry_level])
	for path in [game.SAVE_PATH, game.SAVE_BACKUP]:
		DirAccess.remove_absolute(path)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
