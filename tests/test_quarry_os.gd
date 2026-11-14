extends SceneTree
## QUARRY OS: the physical office computer and its windowed desktop.   godot --headless --fixed-fps 60 -s tests/test_quarry_os.gd
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
## Walkability, the level-design way: flood-fill the floor of a building on a 0.2 m grid from just inside its door, treating every box collider that overlaps a standing
## player's height (plus a 0.35 m radius) as blocked, and report which goals the player can reach.
func boxes_of(game) -> Array:
	var out := []
	for body in game.world.find_children("*", "StaticBody3D", true, false):
		if str(body.get_meta("kind", "")) == "door":
			continue                                     # doors open for anyone who walks up to them
		for cs in body.get_children():
			if cs is CollisionShape3D and cs.shape is BoxShape3D:
				out.append([cs.global_transform, (cs.shape as BoxShape3D).size])
	return out

func blocked(boxes: Array, p: Vector2) -> bool:
	for b in boxes:
		var xf: Transform3D = b[0]
		var sz: Vector3 = b[1]
		var top: float = xf.origin.y + sz.y * 0.5
		var bottom: float = xf.origin.y - sz.y * 0.5
		if top < 0.45 or bottom > 1.7:
			continue                                     # floors, ramps and ceilings do not stop a walking player
		var l: Vector3 = xf.affine_inverse() * Vector3(p.x, xf.origin.y, p.y)
		if absf(l.x) <= sz.x * 0.5 + 0.3 and absf(l.z) <= sz.z * 0.5 + 0.3:
			return true
	return false

func reachable(boxes: Array, c: Vector3, start: Vector2, goals: Array) -> Array:
	var step := 0.2
	var seen := {}
	var q := [start]
	seen[Vector2i(0, 0)] = true                       # cells are keyed by whole steps from the start (half-step rounding made neighbours alias)
	var missed := []
	while not q.is_empty():
		var p: Vector2 = q.pop_back()
		for d in [Vector2(step, 0), Vector2(-step, 0), Vector2(0, step), Vector2(0, -step)]:
			var n: Vector2 = p + d
			if absf(n.x - c.x) > 2.1 or absf(n.y - c.z) > 2.1:
				continue
			var k := Vector2i(roundi((n.x - start.x) / step), roundi((n.y - start.y) / step))
			if seen.has(k) or blocked(boxes, n):
				continue
			seen[k] = true
			q.append(n)
	for g in goals:
		var gp: Vector2 = g[0]
		var ok := false
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if seen.has(Vector2i(roundi((gp.x - start.x) / step) + dx, roundi((gp.y - start.y) / step) + dz)):
					ok = true
		if not ok:
			missed.append(str(g[1]))
	return missed

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false                  # the real new-game (blueprint) world
	game.autosave_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	game.hud.close_card()
	await frames(260)                           # the new-game walk-in settles first
	check(game.pc_screen_pos != Vector3.ZERO, "the office has a physical computer with a screen position")
	# --- E at the desk: the camera glides to the monitor (suspending the player), then the desktop opens with a cursor
	var start_cam: Transform3D = game.player.camera.global_transform
	game.enter_pc()
	check(game.pc_busy and game.player.locked and game.player.scripted_camera, "approach: the player is locked and the camera is scripted")
	check(not game.gameplay_input_allowed() and game._mine_button_down() == false, "approach: no mining while the camera moves")
	await frames(20)
	check(game.menu == "", "approach: the desktop is not open until the camera arrives")
	await frames(40)
	check(game.menu == "manage" and not game.pc_busy and game.pc_active, "the desktop opens when the camera has arrived")
	check(game.management.os.visible and game.management.visible, "the desktop is shown (mouse released)")
	var at_pc: Transform3D = game.player.camera.global_transform
	check(at_pc.origin.distance_to(game.pc_screen_pos) < 0.6, "the camera is at the monitor (%.2f m)" % at_pc.origin.distance_to(game.pc_screen_pos))
	var os: QuarryOS = game.management.os
	# --- the desktop: eight application shortcuts, a taskbar, the in-game clock
	check(os.icons.size() == 8, "eight desktop shortcuts")
	check(os.clock_label.text == "DAY %d  %s" % [int(game.state.clock_minutes) / 1440 + 1, game.fmt_time(int(game.state.clock_minutes))], "the taskbar clock shows the game clock: " + os.clock_label.text)
	game.state.clock_minutes += 95.0
	game.management.refresh()
	check(os.clock_label.text.ends_with(game.fmt_time(int(game.state.clock_minutes))), "the clock follows the game clock after it advances: " + os.clock_label.text)
	# --- windows: double-click opens, several at once, taskbar buttons
	for id in os.icons:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.double_click = true
		os._icon_input(ev, id)
	await frames(2)
	check(os.windows.size() == 8 and os.task_buttons.size() == 8, "double-clicking each shortcut opens its own window (8 windows, 8 taskbar buttons)")
	var empty := 0
	for w in os.windows:
		if w.page.content.get_child_count() == 0:
			empty += 1
	check(empty == 0, "every application page shows real content (%d empty)" % empty)
	# --- drag keeps the window on the desktop; z-order; minimise / restore / close
	var w1: Control = os.window_of("stats")
	w1.move_to(Vector2(5000, 5000))
	check(w1.position.x + w1.size.x <= os.size.x + 0.1 and w1.position.y + w1.size.y <= os.size.y - QuarryOS.TASKBAR_H + 0.1, "a window dragged far away stays inside the desktop")
	w1.move_to(Vector2(-300, -300))
	check(w1.position.x >= 0.0 and w1.position.y >= 0.0, "...and cannot be dragged off the top left")
	var w2: Control = os.window_of("sales")
	os.raise_window(w2)
	check(os.active == w2 and os.area.get_child(os.area.get_child_count() - 1) == w2, "raising brings a window to the front")
	os.minimize(w2)
	check(not w2.visible and os.active != w2, "minimise hides the window and focuses the next one")
	os.task_buttons[w2].pressed.emit()
	check(w2.visible and os.active == w2, "its taskbar button restores and raises it")
	os.task_buttons[w2].pressed.emit()
	check(not w2.visible, "the active window's taskbar button minimises it")
	os.close_window(w2)
	check(os.window_of("sales") == null and os.windows.size() == 7, "close removes the window and its taskbar button")
	# --- the Sales application sells through the game's own economy
	os.open_app("sales")
	game.state.inventory["limestone"] = 6
	var before: int = game.state.money
	var sales_page = os.window_of("sales").page
	sales_page.refresh()
	game.menu_act("sell", game.RESOURCE_ORDER.find("limestone"), false)
	game.management.refresh()
	check(game.state.money > before and int(game.state.inventory["limestone"]) == 0, "selling from the Sales app pays through the existing economy")
	# --- employees: tabs inside one window
	var emp = os.window_of("employees").page
	emp._set_tab("hire")
	check(emp.tab == "hire" and emp.content.get_child_count() > 0, "Employees has working tabs (hire page shows candidates)")
	# --- old API still works: _set_tab on the shell opens the application
	game.management._set_tab("milestones")
	check(os.active == os.window_of("milestones") and game.management.content == os.window_of("milestones").page.content, "the shell's old tab API opens and focuses the matching window")
	# --- the desktop at the window sizes the game really gets (canvas_items + expand: 960x540 base, wider on ultrawide): windows stay on the desktop
	for sz in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(1024, 768)]:
		root.size = sz
		await frames(2)
		os.open_desktop()
		var all_in := true
		for w in os.windows:
			var r := Rect2(w.position, w.size)
			if not Rect2(Vector2.ZERO, Vector2(os.size.x, os.size.y - QuarryOS.TASKBAR_H)).grow(0.5).encloses(r):
				all_in = false
		check(all_in and os.get_node("Taskbar").visible, "at %dx%d every window sits inside the desktop above the taskbar" % [sz.x, sz.y])
	root.size = Vector2i(1152, 648)
	# --- the buildings are walkable: every goal reachable from the door, nothing blocks the lane
	var boxes := boxes_of(game)
	var oc: Vector3 = game.OFFICE_POS
	var miss: Array = reachable(boxes, oc, Vector2(oc.x, oc.z - 1.7), [[Vector2(oc.x, oc.z + 0.55), "the desk"], [Vector2(oc.x + 1.5, oc.z + 1.3), "the bookcase"], [Vector2(oc.x - 1.4, oc.z + 0.2), "the filing cabinets"], [Vector2(oc.x + 1.5, oc.z - 0.4), "the window seat"]])
	check(miss.is_empty(), "office: the desk, bookcase and cabinets can all be reached from the door %s" % str(miss))
	var hc: Vector3 = game.HOME_POS
	miss = reachable(boxes, hc, Vector2(hc.x, hc.z - 1.7), [[Vector2(hc.x - 0.5, hc.z + 1.3), "the bed"], [Vector2(hc.x + 1.45, hc.z + 1.2), "the kitchen"], [Vector2(hc.x + 0.55, hc.z - 0.45), "the table"], [Vector2(hc.x - 1.55, hc.z - 1.4), "the bathroom"]])
	check(miss.is_empty(), "house: the bed, kitchen, table and bathroom can all be reached from the front door %s" % str(miss))
	var tc: Vector3 = game.TOOLSHED_POS
	miss = reachable(boxes, tc, Vector2(tc.x, tc.z - 1.7), [[Vector2(tc.x, tc.z + 0.9), "the workbench"], [Vector2(tc.x - 1.2, tc.z + 0.3), "the shelving"]])
	check(miss.is_empty(), "workshop: the workbench and shelving can be reached %s" % str(miss))
	var sc: Vector3 = game.SHED_POS
	miss = reachable(boxes, sc, Vector2(sc.x, sc.z - 1.7), [[Vector2(sc.x, sc.z + 0.6), "the back of the shed"], [Vector2(sc.x + 1.0, sc.z - 0.3), "the pallets"]])
	check(miss.is_empty(), "storage shed: the stock can be reached %s" % str(miss))
	# --- closing the computer: cursor and camera come back, controls return
	game._close_menu()
	check(game.pc_busy and game.player.locked, "leaving: controls stay suspended while the camera returns")
	await frames(40)
	check(not game.pc_busy and not game.pc_active and not game.player.locked and not game.player.scripted_camera, "leaving: movement and tools are restored")
	# (mouse capture itself cannot be observed headless: the dummy display driver keeps the mode VISIBLE)
	check(game.player.camera.global_transform.origin.distance_to(start_cam.origin) < 0.05, "leaving: the camera is back where it was")
	# --- clicking on the desktop while it is open never swings the tool
	game.enter_pc()
	await frames(60)
	Input.parse_input_event(InputEventMouseButton.new())
	check(not game.gameplay_input_allowed() and not game._mine_button_down(), "with the desktop open, mouse clicks are never mining input")
	game._close_menu()
	await frames(40)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
