extends SceneTree
## Yard / HUD / office pass: dirt and stone only, a dedicated tool shed, no sales stand or order kiosk, the office computer as a card grid,
## one typeface and two text sizes.   godot --headless --fixed-fps 60 -s tests/test_yard_hud_office.gd
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
	await frames(10)
	game.hud.close_card()
	var names := {}
	for b in game.world.get_children():
		names[str(b.name)] = b
	# ---- the ground: dirt and stone, nothing green that is not a weed
	var counts: Dictionary = game.natural_root.get_meta("counts") if game.natural_root != null else {}
	check(int(counts.get("scrub", 0)) == 0, "the opening ground has no scrub mounds (%s)" % str(counts))
	check(not names.has("Excavated rim"), "the old pit's stone rim slabs are gone from the new yard")
	var sp: Vector3 = game.spoil_node.global_position
	check(sp.z < -7.5, "the spoil heap is out in Area 1, not in the yard (z %.1f)" % sp.z)
	# ---- the tool shed
	var shed_ok := names.has("Tool shed left") and names.has("Tool shed back") and names.has("Tool shed roof")
	check(shed_ok, "the Tool shed is a building of its own")
	check(not names.has("Upgrade board"), "the office no longer holds the upgrade board")
	var wb = names.get("Workbench")
	check(wb != null and str(wb.get_meta("kind", "")) == "upgrades" and absf(wb.global_position.x - game.TOOLSHED_POS.x) < 2.0 and absf(wb.global_position.z - game.TOOLSHED_POS.z) < 2.4, "the workbench (tool upgrades) stands inside the tool shed")
	check(wb != null and wb.global_position.z > game.TOOLSHED_POS.z + 1.0, "against the back wall, so the doorway and the floor in front of it are clear")
	game._rebake_nav()
	await frames(8)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(game.nav_map, Vector3(game.TOOLSHED_POS.x, 0, game.TOOLSHED_POS.z - 5.0), Vector3(game.TOOLSHED_POS.x, 0, game.TOOLSHED_POS.z + 0.7), true)
	check(not path.is_empty() and Vector2(path[path.size() - 1].x - game.TOOLSHED_POS.x, path[path.size() - 1].z - (game.TOOLSHED_POS.z + 0.7)).length() < 0.8, "you can walk from the yard through the door to the workbench")
	# ---- no sales stand, no order kiosk
	check(not names.has("Selling station") and not names.has("Crusher order kiosk"), "the sales stand and the machinery order kiosk are gone")
	check(game.sell_body != null and not game.sell_body.visible and game.sell_body.collision_layer == 0, "the selling anchor is only a point (no object in the yard)")
	# ---- the office computer
	game._open_menu("manage")
	await frames(3)
	var m = game.management
	check(m.tab == "home", "the office computer opens on its card grid")
	var cards := 0
	for c in m.content.find_children("*", "Button", true, false):
		cards += 1
	check(cards == 7, "seven cards: employees, machinery, sales, production, upgrades, milestones, stats (%d)" % cards)
	var all_text := ""
	m._set_tab("staff")
	await frames(2)
	game.ui_hire("rosa")
	m.refresh()
	for l in m.content.find_children("*", "Label", true, false):
		all_text += str(l.text) + " "
	for bt in m.content.find_children("*", "Button", true, false):
		all_text += str(bt.text) + " "
	check(not all_text.contains("Shift") and not all_text.contains("shift"), "the crew page has no schedule controls")
	check(m.subtabs.visible, "employees has its sub-pages (crew, hire, payroll)")
	m._set_tab("equipment")
	await frames(2)
	var has_order := false
	for bt in m.content.find_children("*", "Button", true, false):
		if str(bt.text).begins_with("ORDER"):
			has_order = true
	check(has_order, "machinery has the order button (crushers, belts, rigs)")
	m._set_tab("sales")
	await frames(2)
	check(game.menu == "sell", "the sales card opens the sales window")
	game._close_menu()
	# ---- every new hire works the same day, 9 to 17
	var emp: Dictionary = game.business.employees[0]
	check(int(emp["shift_start"]) == 540 and int(emp["shift_end"]) == 1020, "new hires work 9:00 to 17:00 (%d to %d)" % [int(emp["shift_start"]), int(emp["shift_end"])])
	# ---- one typeface, two sizes
	check(QuarryTheme.head() == QuarryTheme.bold(), "headings use the same smooth typeface (no pixel font)")
	check(QuarryTheme.SMALL == QuarryTheme.BODY and QuarryTheme.HERO == QuarryTheme.HEAD, "two text sizes only")
	game.state.money = 50
	game.hud.refresh_panels()
	var detail: String = game.hud.objective_detail.text
	check(detail.split("\n").size() <= 5, "the objective box is compact (%d lines)" % detail.split("\n").size())
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
