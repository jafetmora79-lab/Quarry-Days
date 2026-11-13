extends SceneTree
## HUD polish: the corner map, the location banner, the vehicle plate, the road hint and the objective marker.
##   godot --headless --fixed-fps 60 -s tests/test_hud_polish.gd

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
	game.title_enabled = false
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(10)
	for i in range(6):
		if game.walter_dialog:
			game.walter_dialog.skip()
		await frames(20)
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await frames(3)
	var hud = game.hud
	var prog: QuarryProgression = game.prog
	# ---- the map
	var mm: QuarryMinimap = hud.minimap
	check(mm != null and mm.is_inside_tree() and mm.size.x >= 150.0 and mm.size.y >= 70.0, "the corner map exists (%s)" % str(mm.size))
	var snap: Dictionary = mm.snapshot()
	check(int(snap["levels_total"]) == 4 and int(snap["levels_open"]) == 0 and int(snap["roads_built"]) == 0, "it knows the four dug levels, none open, no road built (%s)" % str({"t": snap["levels_total"], "o": snap["levels_open"], "r": snap["roads_built"]}))
	check(int(snap["debris"]) > 0 and int(snap["vehicles"]) >= 1, "it shows the tutorial debris and the machines (%d / %d)" % [int(snap["debris"]), int(snap["vehicles"])])
	var p: Vector2 = snap["player"]
	check(Rect2(Vector2.ZERO, mm.size).has_point(p), "the player's arrow is inside the map (%.0f, %.0f)" % [p.x, p.y])
	check(mm.to_map(0.0, -50.0).y < mm.to_map(0.0, 20.0).y, "north is up: the quarry is drawn above the yard")
	var wm: Vector2 = snap["waypoint"]
	check(wm != Vector2.INF and Rect2(Vector2.ZERO, mm.size).has_point(wm), "the objective marker points at the next debris during the cleanup")
	var wp: Dictionary = game.hud_waypoint()
	check(str(wp.get("label", "")) == "Next debris", "its caption says what it is (%s)" % str(wp.get("label", "")))
	# map keeps up with progress
	game.state.money = 100000
	for i in range(prog.column_count("q_top")):
		if i % 2 == 0:
			prog.extract("q_top", i, 1.0e6, 1 << 30, "hand")
	prog.check_levels()
	prog.cleanup["done"] = true
	for id in prog.cleanup_ids():
		prog.cleanup["cleared"][str(id)] = true
	var wp2: Dictionary = game.hud_waypoint()
	check(str(wp2.get("label", "")).contains("road") and (wp2["pos"] as Vector3).distance_to(game.OFFICE_POS) < 0.1, "once level 2 is open the marker points at the office to build its road (%s)" % str(wp2.get("label", "")))
	check(game.hud_status_text().contains("build its road"), "and the status plate says so")
	prog.buy_road(2)
	var snap2: Dictionary = mm.snapshot()
	check(int(snap2["levels_open"]) >= 1 and int(snap2["roads_built"]) == 1 and game.hud_waypoint().is_empty(), "after the road is bought the map shows it built and the marker is gone")
	mm._draw_test_safe()
	# ---- location banner
	game.player.global_position = Vector3(0.0, 0.2, 14.0)
	check(game.hud_location() == "THE YARD", "standing in the yard: %s" % game.hud_location())
	game.player.global_position = Vector3(-60.0, 0.2, -50.0)
	check(game.hud_location().begins_with("QUARRY"), "standing on the quarry surface: %s" % game.hud_location())
	game.player.global_position = Vector3(-52.0, -3.5, -55.0)
	var loc2: String = game.hud_location()
	game.player.global_position = Vector3(-35.0, 0.2, 28.0)
	check(game.hud_location() == "THE WEST TUNNEL" or game.hud_location() == "THE YARD", "near the garage / tunnel end: %s" % game.hud_location())
	game.player.global_position = Vector3(0.0, 0.2, 14.0)
	await frames(30)
	hud._loc_text = ""
	hud._loc_check = 0.0
	hud._update_location(0.3)
	check(hud.loc_label.text == "THE YARD" and hud._loc_t > 2.0, "the banner shows the place when it changes")
	for i in range(240):
		hud._update_location(1.0 / 60.0)
	check(hud.loc_root.modulate.a < 0.05, "and fades away again")
	# ---- vehicle plate
	check(not hud.drive_plate.visible, "no vehicle plate on foot")
	game.state.money = 50000
	prog.stage = prog.stage_index("large")
	game.business.milestones["mechanized"] = true
	game.ui_buy_vehicle("loader")
	game.delivery.finish_all()
	var v = null
	for nd in game.vehicle_nodes.values():
		if nd.vtype == "loader":
			v = nd
	game.enter_vehicle(v)
	await frames(4)
	v.speed = 2.0
	hud._update_drive_plate()
	check(hud.drive_plate.visible and hud.drive_name.text != "" and hud.drive_speed_bar.value > 0.05 and hud.drive_speed_label.text.contains("m/s"), "driving shows the vehicle plate with a speed gauge (%s)" % hud.drive_speed_label.text)
	check(hud.drive_load_label.text.begins_with("BUCKET") and hud.drive_hint.text != "", "with its load and what the buttons do (%s)" % hud.drive_hint.text)
	check(not hud.bottom.get_node("ToolPlate").visible, "the hand-tool plate steps aside while driving")
	v.speed = 0.0
	await frames(30)
	game.exit_vehicle()
	await frames(4)
	hud._update_drive_plate()
	check(not hud.drive_plate.visible and hud.bottom.get_node("ToolPlate").visible, "and comes back on foot (plate %s tool %s driving %s)" % [hud.drive_plate.visible, hud.bottom.get_node("ToolPlate").visible, str(game.driving)])
	# ---- layout: no HUD piece sits on top of another (at the 960x540 base canvas), driving or not
	var HudScript = hud
	await frames(3)
	game.enter_vehicle(v)
	await frames(6)
	v.speed = 0.0
	hud.size = Vector2(960, 540)
	await frames(4)
	var named := {}
	for nm in ["TopLeftPlate", "MapPlate", "ObjectivePlate", "LocationBanner", "DrivePlate", "BagPlate", "KeyHints"]:
		var n := hud.find_child(nm, true, false) as Control
		if n != null and n.is_visible_in_tree():
			named[nm] = n.get_global_rect()
	var overlaps := []
	var keys := named.keys()
	for i in range(keys.size()):
		for j in range(i + 1, keys.size()):
			var a: Rect2 = named[keys[i]]
			var b: Rect2 = named[keys[j]]
			if a.grow(-1.0).intersects(b.grow(-1.0)):
				overlaps.append("%s / %s" % [keys[i], keys[j]])
	check(named.size() >= 5 and overlaps.is_empty(), "no HUD piece overlaps another while driving %s" % str(overlaps))
	game.exit_vehicle()
	await frames(4)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
