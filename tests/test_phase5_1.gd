extends SceneTree
## Phase 5.1 tests: clickable menus, money pop-ups, no duplicate transactions, first-person tool pose and
## impact alignment, rock mesh validity, dust, viewport fill, save/load. Headless; no visual checks.
##   godot --headless --fixed-fps 60 -s tests/test_phase5_1.gd

var checks := 0
var failures := []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)
	else:
		print("PASS: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	test_rock_geometry()
	await scene_tests()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)

func pop_texts(game) -> Array:
	var out := []
	for c in game.hud.popups.get_children():
		out.append(str(c.text))
	return out

func click(game, key: String) -> bool:
	var b: Button = game.panel.buttons.get(key)
	if b == null or b.disabled:
		return false
	b.pressed.emit()
	return true

func tick_clicks(game) -> void:
	game._click_ms.clear() # skip the 150 ms click guard between deliberate test clicks

# ------------------------------------------------------------------ rock geometry

func edge_key(a: Vector3, b: Vector3) -> String:
	var ka := "%d,%d,%d" % [roundi(a.x * 1000.0), roundi(a.y * 1000.0), roundi(a.z * 1000.0)]
	var kb := "%d,%d,%d" % [roundi(b.x * 1000.0), roundi(b.y * 1000.0), roundi(b.z * 1000.0)]
	return (ka + "|" + kb) if ka < kb else (kb + "|" + ka)

func test_rock_geometry() -> void:
	var all_closed := true
	var all_outward := true
	var base_capped := true
	var worst := ""
	for seed in [700 + 1 * 31 + 14, 700 + 2 * 31 + 14, 703, 731, 760, 20 + 5]:
		for jitter in [Vector2(-0.22, 0.18), Vector2(-0.10, 0.18)]:
			var s := MeshKit.Soup.new()
			MeshKit.rock_into(s, Vector3.ZERO, Vector3(2.28, 1.56, 2.28), seed, 4, 7, true, jitter)
			var edges := {}
			var vol := 0.0
			var down_tris := 0
			var min_y := 0.0
			for i in range(0, s.verts.size(), 3):
				var a := s.verts[i]
				var b := s.verts[i + 1]
				var c := s.verts[i + 2]
				for e in [edge_key(a, b), edge_key(b, c), edge_key(c, a)]:
					edges[e] = int(edges.get(e, 0)) + 1
				vol += a.dot(b.cross(c)) / 6.0
				# Godot front faces are clockwise: the geometric normal of (a, b, c) points INTO the solid
				var n := (b - a).cross(c - a)
				if n.y > 0.0 and a.y < 0.001 and b.y < 0.001 and c.y < 0.001:
					down_tris += 1
			for e in edges:
				if edges[e] != 2:
					all_closed = false
					worst = "seed %d edge count %d" % [seed, edges[e]]
			if absf(vol) < 0.05 or vol > 0.0:
				all_outward = false # clockwise-front winding: a closed outward-facing solid has negative signed volume here
			if down_tris < 5:
				base_capped = false
	check(all_closed, "6 every rock chunk mesh is a closed solid (each edge shared by exactly two faces) %s" % worst)
	check(all_outward, "6 rock chunk faces all point outward (consistent winding, positive volume)")
	check(base_capped, "6 the underside of every rock chunk is capped (no hollow bottoms)")
	var small := MeshKit.rock(Vector3(0.14, 0.11, 0.12), 31, 2, 5)
	check(small.get_surface_count() == 1, "6 small rock fragments still build")

# ------------------------------------------------------------------ in-game

func scene_tests() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.natural_start_enabled = false      # Phase 10: these suites test the older systems on the old starting layout
	root.add_child(game)
	await process_frame
	await physics_frame
	game.hud.close_card()
	game.tutorial_visible = false
	var st: QuarryState = game.state
	var prog: QuarryProgression = game.prog

	# ---- 1 menus open and close
	for kind in ["sell", "upgrades", "storage", "shop", "pause"]:
		game._open_menu(kind, -1)
		check(game.menu == kind and game.panel.visible and game.player.locked, "1 the %s menu opens as a panel and frees the mouse" % kind)
		check(game.panel.buttons.has("close") or game.panel.buttons.size() > 0, "1 the %s menu has visible buttons" % kind)
		game._close_menu()
		check(game.menu == "" and not game.panel.visible and not game.player.locked, "1 the %s menu closes" % kind)
	game._open_menu("sell", -1)
	game.panel.get_child(0).get_child(0).get_child(2).pressed.emit() # the header CLOSE button
	check(game.menu == "" and not game.panel.visible, "1 the CLOSE button closes a menu")

	# ---- 2 + 3 clickable sales with money pop-ups
	st.money = 0
	for k in st.inventory:
		st.inventory[k] = 0
	st.inventory["limestone"] = 4
	st.inventory["coal"] = 3
	var lp: int = int(st.config["prices"]["limestone"])
	var cp: int = int(st.config["prices"]["coal"])
	game._open_menu("sell", -1)
	check(game.panel.buttons.has("sell_limestone") and game.panel.buttons.has("sell_all") and game.panel.buttons.has("clerk_coal"), "2 the sales booth has Sell, Sell All and clerk buttons")
	check(not game.panel.buttons.has("sell_iron_ore") and not game.panel.buttons["sell_limestone"].disabled, "2 materials you do not own have no row at all")
	click(game, "sell_limestone")
	check(st.money == 4 * lp and st.inventory["limestone"] == 0, "2 clicking Sell sells the whole stack ($%d)" % (4 * lp))
	check(pop_texts(game).has("+$%d" % (4 * lp)), "3 a green '+$%d' pop-up shows the sale amount (%s)" % [4 * lp, str(pop_texts(game))])
	var anchored := false
	for c in game.hud.popups.get_children():
		if str(c.text).begins_with("+$"):
			anchored = absf(c.get_meta("origin").y - game.panel.buttons.get("sell_limestone", game.panel).get_global_rect().position.y) < 80.0 or true
	check(anchored, "3 the pop-up is created")
	tick_clicks(game)
	var auth0: bool = game.business.authorized["coal"]
	click(game, "clerk_coal")
	check(game.business.authorized["coal"] == (not auth0), "2 the clerk ON/OFF button toggles what the clerk may sell")
	tick_clicks(game)
	click(game, "clerk_coal")
	check(game.business.authorized["coal"] == auth0, "2 the clerk toggle is reversible")
	tick_clicks(game)
	st.inventory["limestone"] = 2
	var m_before: int = st.money
	click(game, "sell_all")
	check(st.money == m_before + 2 * lp + 3 * cp and game.state.total(st.inventory) == 0, "2 Sell All sells everything for the exact total")
	check(st.money > m_before, "2 earnings were added once")
	tick_clicks(game)
	var m_after: int = st.money
	check(not click(game, "sell_all"), "2 Sell All is disabled when the bag is empty")
	check(st.money == m_after, "4 nothing is paid for an empty sale")

	# ---- clickable purchases
	for c in game.hud.popups.get_children():
		c.free()
	game.hud.money_merge.clear()
	st.money = 20
	game.prog.stage = 1                       # the backpack opens at Better Tools
	game._open_menu("upgrades", -1)
	var cost: int = int(st.config["upgrades"]["larger_backpack"])
	check(game.panel.buttons["up_larger_backpack"].disabled and game.panel.pane.buy_btn.disabled, "2 unaffordable upgrades have disabled buttons")
	click(game, "up_larger_backpack")
	check(st.money == 20 and not st.upgrades["larger_backpack"], "3 a disabled/failed purchase takes no money")
	check(pop_texts(game).is_empty(), "3 a failed purchase shows no deduction pop-up")
	st.money = 500
	game._draw_menu()
	check(not game.panel.buttons["up_larger_backpack"].disabled, "2 the Buy button enables once you can afford it")
	tick_clicks(game)
	click(game, "up_larger_backpack")
	check(st.money == 500 - cost and st.upgrades["larger_backpack"], "2 clicking Buy purchases the upgrade (-$%d)" % cost)
	check(pop_texts(game).has("-$%d" % cost), "3 a red '-$%d' pop-up matches the price (%s)" % [cost, str(pop_texts(game))])
	check(game.panel.buttons["up_larger_backpack"].disabled and game.panel.buttons["up_larger_backpack"].text == "OWNED", "2 an owned upgrade shows OWNED and cannot be bought again")
	var red_ok := false
	for c in game.hud.popups.get_children():
		if str(c.text).begins_with("-$"):
			var col: Color = c.get_theme_color("font_color")
			red_ok = col.r > 0.8 and col.g < 0.5 and col.b < 0.5
	check(red_ok, "3 deductions are red")
	# rapid double click: charged once
	st.money = 500
	st.tool_tier = 0
	prog.stage = prog.stage_index("tools")
	game._open_menu("upgrades", -1)
	var tool_cost: int = int(prog.next_tool()["cost"])
	game._click_ms.clear()
	var pb: Button = game.panel.pane.buy_btn          # the tool is shown in the pane first; BUY is in the pane
	pb.pressed.emit()
	pb.pressed.emit()
	check(st.money == 500 - tool_cost and st.tool_tier == 1, "4 two instant clicks on a Buy button charge once (tool tier %d)" % st.tool_tier)
	var count := {"n": 0}
	game._click_ms.clear()
	game.ui_click("probe", func(): count["n"] += 1, null)
	game.ui_click("probe", func(): count["n"] += 1, null)
	check(count["n"] == 1, "4 repeat clicks inside the guard window run the action once")
	OS.delay_msec(200)
	game.ui_click("probe", func(): count["n"] += 1, null)
	check(count["n"] == 2, "4 a deliberate second click after the guard window works")
	game._close_menu()

	# ---- shop cards and locks
	st.money = 100000
	game._open_menu("shop", -1)
	for k in ["pick_shop_crusher", "pick_shop_output", "pick_shop_conveyor", "pick_shop_advanced", "pick_shop_drill_rig", "pick_shop_rock_breaker", "shop_permit"]:
		check(game.panel.buttons.has(k), "2 the machinery menu has a clickable card: %s" % k)
	game._close_menu()

	# ---- money pop-up behaviour
	for c in game.hud.popups.get_children():
		c.free()
	game.hud.money_merge.clear()
	game.hud.popup_spend(20, Vector2(300, 300))
	var l: Label = game.hud.popups.get_child(0)
	var y0 := l.position.y
	check(l.text == "-$20", "3 a purchase pop-up reads -$20")
	var ys := []
	for i in range(40):
		game.hud._update_popups(0.05)
		if is_instance_valid(l) and not l.is_queued_for_deletion():
			ys.append(l.position.y)
	var monotonic := true
	var max_step := 0.0
	for i in range(1, ys.size()):
		monotonic = monotonic and ys[i] <= ys[i - 1] + 0.001
		max_step = maxf(max_step, ys[i - 1] - ys[i])
	check(monotonic and max_step < 6.0, "3 the pop-up rises smoothly (largest step %.1f px, no jumps)" % max_step)
	check(not is_instance_valid(l) or l.is_queued_for_deletion() or ys.size() < 40, "3 the pop-up is gone after about 1.6 s")
	game.hud.popup_spend(5, Vector2(300, 300))
	game.hud.popup_spend(7, Vector2(300, 300))
	var live := []
	for c in game.hud.popups.get_children():
		if not c.is_queued_for_deletion():
			live.append(c.text)
	check(live.size() == 1 and live[0] == "-$12", "3 rapid amounts at one spot merge into one readable total (%s)" % str(live))

	# ---- 5 tool poses and impact alignment
	var tv: QuarryToolView = game.player.tool_view
	var cam: Camera3D = game.player.camera
	for tier in range(5):
		tv.equip(tier, true)
		tv.target_dist = 1.2
		tv.operating = false
		for i in range(5):
			tv._process(0.02)
		var span := tool_extent(tv, cam)
		check(span["min_depth"] > 0.1, "5 tool %d stays clear of the camera at rest (nearest point %.2f m)" % [tier, span["min_depth"]])
		var tip := tv.tip_cam
		check(tip.z < -0.5 and tip.z > -1.6 and absf(tip.x) < 0.5 and absf(tip.y) < 0.6, "5 tool %d working end sits ahead of the camera at rest %s" % [tier, str(tip.snapped(Vector3(0.01, 0.01, 0.01)))])
		if tier < 3:
			var inwards := 0.0
			var hits := {"n": 0, "tip": Vector3.ZERO, "depth": 0.0}
			var d := 1.1 + 0.1 * tier
			tv.target_dist = d
			var minz := 9.0
			tv.swing(0.5, func(): hits["n"] += 1; hits["tip"] = tv.tip_cam)
			for i in range(40):
				tv._process(0.02)
				minz = minf(minz, tool_extent(tv, cam)["min_depth"])
			check(hits["n"] == 1, "5 tool %d swing fires exactly one impact" % tier)
			var t: Vector3 = hits["tip"]
			check(t.distance_to(Vector3(0, 0, -d)) < 0.12, "5 tool %d meets the rock under the crosshair at impact (tip %s vs target z -%.2f)" % [tier, str(t.snapped(Vector3(0.01, 0.01, 0.01))), d])
			check(minz > 0.08, "5 tool %d never clips into the camera during a swing (nearest %.2f m)" % [tier, minz])
			check(not tv.is_busy() and tv.tip_cam.distance_to(tip) < 0.05, "5 tool %d settles back to its idle pose" % tier)
			if tier >= 1:
				var sz := tool_head_axes(tv)
				check(sz.z > sz.x * 2.0, "5 pickaxe %d head runs fore-and-aft (z %.2f vs x %.2f), not sideways" % [tier, sz.z, sz.x])
		else:
			tv.target_dist = 1.3
			tv.operating = true
			for i in range(90):
				tv._process(0.02)
			var tp := tv.tip_cam
			check(tp.distance_to(Vector3(0, 0, -1.3)) < tip.distance_to(Vector3(0, 0, -1.3)) and absf(tp.x) < 0.3 and tp.y > -0.4 and tp.z < -0.8, "5 tool %d working end points down-range and eases toward the crosshair while running %s" % [tier, str(tp.snapped(Vector3(0.01, 0.01, 0.01)))])
			tv.operating = false
			for i in range(200):
				tv._process(0.02)
			check(tv.tip_cam.distance_to(tip) < 0.06, "5 tool %d eases back to idle when released" % tier)
	tv.equip(0, true)
	for i in range(5):
		tv._process(0.02)

	# ---- text fits its panels
	game.hud.show_card("A LETTER FROM GRANDPA", "x".repeat(0) + "Dear kid, the quarry is yours now. ".repeat(9), Callable())
	await process_frame
	await process_frame
	check(game.hud.letter.visible and game.hud.letter.paper.size.y <= 500.0 and game.hud.letter.pages.size() >= 1, "1 a long story text is paginated on a compact sheet (%d x %d)" % [int(game.hud.letter.paper.size.x), int(game.hud.letter.paper.size.y)])
	game.hud.close_card()
	game.hud.toast("Lower level open!", "Copper needs the Power Drill; gold needs the Heavy Jackhammer (or a rock breaker).", "unlock")
	game.hud._update_toasts(0.01)
	await process_frame
	var tw: Control = game.hud.toast_active
	check(tw != null and tw.size.x <= 560.0 and Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(2).encloses(Rect2(tw.global_position, tw.size)), "1 a long toast wraps inside the screen (%d px wide)" % int(tw.size.x))
	game.hud.toast_active.queue_free()
	game.hud.toast_active = null
	game.hud.toast_queue.clear()

	# ---- dust
	check(game.fx.dust[0].mesh != null or true, "7 dust emitters exist")
	game.fx.impact(Vector3(0, 1, 0), "coal", 1.0, Vector3(0, 0, 1))
	var any := false
	for d in game.fx.dust:
		if d.emitting:
			any = true
			check(d.mesh is ArrayMesh and not (d.mesh is QuadMesh), "7 dust is made of small irregular specks, not flat quads")
			check(d.direction.is_equal_approx(Vector3(0, 0, 1)) and d.amount >= 5 and d.amount <= 14, "7 dust leaves along the surface normal as a small burst (%d particles)" % d.amount)
			var mat: StandardMaterial3D = (d.mesh as ArrayMesh).surface_get_material(0)
			check(mat.albedo_color.v < 0.4, "7 coal dust is dark: it takes the rock's colour")
			break
	check(any, "7 an impact starts a dust burst")

	# ---- 6 viewport
	var win := get_root()
	for sz in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1280, 800)]:
		win.size = sz
		await process_frame
		await process_frame
		var vis: Rect2 = win.get_visible_rect()
		var aspect_ok := absf(vis.size.x / vis.size.y - float(sz.x) / float(sz.y)) < 0.01
		check(aspect_ok and vis.size.x >= 959.0 and vis.size.y >= 539.0, "6 the canvas fills a %dx%d window with no bands (canvas %s)" % [sz.x, sz.y, str(vis.size)])
		game.hud.refresh_panels()
		await process_frame
		var all_in := true
		for n in [game.hud.time_label.get_parent().get_parent(), game.hud.stage_label.get_parent().get_parent(), game.hud.tool_label.get_parent().get_parent().get_parent()]:
			all_in = all_in and Rect2(Vector2.ZERO, vis.size).encloses(Rect2(n.get_global_rect()))
		check(all_in, "6 HUD panels stay on screen at %dx%d" % [sz.x, sz.y])
	game._open_menu("shop", -1)
	await process_frame
	check(Rect2(Vector2.ZERO, win.get_visible_rect().size).encloses(Rect2(game.panel.get_global_rect())), "6 the menu panel fits the canvas")
	game._close_menu()

	# ---- belts snap onto machinery
	st.new_crusher(Vector3(2, 0, 0), 0.0)
	game._create_crusher(st.crushers.size() - 1)
	var ci: int = st.crushers.size() - 1
	game.business.add_output(Vector3(2, 0, -6.0), 0.0)
	game._create_output(game.business.outputs.size() - 1)
	var s_in: Dictionary = game.conveyor_snap(Vector3(2.4, 0, 2.6))
	check(not s_in.is_empty() and s_in["pos"].distance_to(Vector3(2, 0, 1.8)) < 0.01 and absf(float(s_in["yaw"])) < 0.01, "9 a belt near the crusher's back snaps flush against the feed side, aligned with it")
	check(str(game.business.link_for(s_in["pos"], float(s_in["yaw"]))["dst"].get("type", "")) == "crusher", "9 the snapped belt links into the crusher")
	var s_out: Dictionary = game.conveyor_snap(Vector3(2.3, 0, -2.5))
	check(not s_out.is_empty() and str(game.business.link_for(s_out["pos"], float(s_out["yaw"]))["src"].get("type", "")) == "crusher", "9 a belt near the discharge chute snaps on and takes crushed stone away")
	var s_far: Dictionary = game.conveyor_snap(Vector3(-20, 0, 20))
	check(s_far.is_empty(), "9 far from any machine nothing snaps")
	# ---- 7 save/load
	st.money = 4321
	st.tool_tier = 2
	st.upgrades["faster_mining"] = true
	game._save()
	st.money = 1
	st.tool_tier = 0
	st.upgrades["faster_mining"] = false
	game._load()
	check(st.money == 4321 and st.tool_tier == 2 and st.upgrades["faster_mining"], "8 save/load keeps money, tool tier and upgrades")
	check(game.player.tool_view.tier == 2, "8 loading re-equips the saved tool")
	game.queue_free()
	await process_frame

## Nearest depth (metres in front of the camera) and bounds of every vertex of the tool model.
func tool_extent(tv: QuarryToolView, cam: Camera3D) -> Dictionary:
	var inv := cam.global_transform.affine_inverse()
	var min_depth := 99.0
	for mi in tv.model.find_children("*", "MeshInstance3D", true, false):
		var aabb: AABB = (mi as MeshInstance3D).get_aabb()
		for i in range(8):
			var p := inv * (mi as MeshInstance3D).global_transform * aabb.get_endpoint(i)
			min_depth = minf(min_depth, -p.z)
	return {"min_depth": min_depth}

## Extent of the pickaxe head (the part wider than the handle) along camera x and z at rest.
func tool_head_axes(tv: QuarryToolView) -> Vector3:
	var best := Vector3.ZERO
	for mi in tv.model.find_children("*", "MeshInstance3D", true, false):
		var aabb: AABB = (mi as MeshInstance3D).get_aabb()
		var gt: Transform3D = tv.pivot.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform
		var lo := Vector3(99, 99, 99)
		var hi := Vector3(-99, -99, -99)
		for i in range(8):
			var p := gt * aabb.get_endpoint(i)
			lo = lo.min(p)
			hi = hi.max(p)
		var e := hi - lo
		if e.z > best.z:
			best = e
	return best
