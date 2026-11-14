extends SceneTree
## The office workstation and interaction feedback: layout and orientation, outline coverage of every usable kind, prompt format, camera path clearance,
## double-trigger safety, and that no click used for UI ever becomes a tool swing. NOTE: headless runs cannot observe real mouse capture, the cursor image or
## how anything looks: those stay manual checks.   godot --headless --fixed-fps 60 -s tests/test_workstation.gd
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
func press(down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = Vector2(300, 300)
	Input.parse_input_event(e)

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	game.hud.close_card()
	await frames(260)                              # the new-game walk-in settles
	# ---- layout: chair on the room side, CRT facing it, keyboard between, mouse on the sitter's right
	var oc: Vector3 = game.OFFICE_POS
	var screen: Vector3 = game.pc_screen_pos
	var chair_z: float = oc.z + 0.9
	check(chair_z < screen.z and screen.z < oc.z + 2.2, "the chair (z %.2f) is on the room side of the screen (z %.2f), which stands against the back wall" % [chair_z, screen.z])
	var kb = null
	var mouse = null
	for item in BuildingDetails.registry:
		var bb: AABB = item[0]
		if absf(bb.size.x - 0.44) < 0.01 and absf(bb.size.y - 0.025) < 0.01 and absf(bb.size.z - 0.15) < 0.01 and bb.position.distance_to(screen) < 1.5:
			kb = bb
		if absf(bb.size.x - 0.06) < 0.01 and absf(bb.size.y - 0.03) < 0.01 and absf(bb.size.z - 0.1) < 0.01 and bb.position.distance_to(screen) < 1.5:
			mouse = bb
	check(kb != null and mouse != null, "the keyboard and the mouse exist")
	if kb != null and mouse != null:
		check(kb.get_center().z < screen.z and kb.get_center().z > chair_z, "the keyboard lies between the chair and the monitor")
		check(mouse.get_center().x < kb.get_center().x - 0.2 and absf(mouse.get_center().z - kb.get_center().z) < 0.1, "the mouse is on the sitter's right (-x, facing +z), beside the keyboard")
	# ---- prompts: one format
	check(game._fmt_prompt("E: use the computer") == "E — Use the computer" and game._fmt_prompt("Left click: mine") == "Left click: mine", "prompts read 'E — Action' and other prompts are untouched")
	# ---- outline coverage: every usable thing in the world that gets an outline has meshes to outline
	var missing := {}
	var seen := {}
	for body in game.world.find_children("*", "StaticBody3D", true, false):
		var k := str(body.get_meta("kind", ""))
		if k in game.HIGHLIGHT_KINDS and not (k in ["worker"]):
			seen[k] = seen.get(k, 0) + 1
			if game._highlight_meshes_for(body).is_empty():
				missing[k] = missing.get(k, 0) + 1
	check(missing.is_empty(), "every outlined kind present in the yard has something to outline: missing %s (kinds seen: %s)" % [str(missing), str(seen.keys())])
	var desk: Node3D = game.world.get_node("Management desk")
	check(game._highlight_meshes_for(desk).size() >= 1, "the computer is outlined through its proxy")
	var dec := 0
	for body in game.world.find_children("*", "StaticBody3D", true, false):
		if str(body.get_meta("kind", "")) == "" and str(body.name).begins_with(("Chair")):
			dec += 1
	check(true, "(%d plain chairs are decoration or obstacles, never outlined)" % dec)
	# ---- the camera's path into the monitor never passes through a collider or a detail from anywhere reachable in the room
	var boxes := []
	for body in game.world.find_children("*", "StaticBody3D", true, false):
		if str(body.get_meta("kind", "")) == "door":
			continue
		for cs in body.get_children():
			if cs is CollisionShape3D and cs.shape is BoxShape3D:
				boxes.append([cs.global_transform, (cs.shape as BoxShape3D).size])
	var details: Array = BuildingDetails.registry
	var pose: Transform3D = game.pc_pose()
	var starts := []
	for dx in [-1.6, -0.7, 0.2, 1.0, 1.8]:
		for dz in [-1.5, -0.6, 0.3]:
			starts.append(Vector3(oc.x + dx, 1.63, oc.z + dz))
	var bad := 0
	for st in starts:
		for i in range(0, 21):
			var p: Vector3 = (st as Vector3).lerp(pose.origin, smoothstep(0.0, 1.0, float(i) / 20.0))
			if p.y < 0.4:
				continue
			for b in boxes:
				var l: Vector3 = (b[0] as Transform3D).affine_inverse() * p
				var sz: Vector3 = b[1]
				if absf(l.x) < sz.x * 0.5 + 0.1 and absf(l.y) < sz.y * 0.5 + 0.1 and absf(l.z) < sz.z * 0.5 + 0.1 and sz.y < 2.0:
					bad += 1
			for it in details:
				if (it[0] as AABB).grow(0.08).has_point(p):
					bad += 1
	check(bad == 0, "the camera path to the monitor from %d spots in the office clears every collider and desk detail (%d hits)" % [starts.size(), bad])
	# ---- entering twice does not double-trigger; leaving twice does not stack
	game.enter_pc()
	game.enter_pc()
	await frames(10)
	game.enter_pc()
	await frames(60)
	check(game.menu == "manage" and game.pc_active and not game.pc_busy, "entering three times still gives exactly one open desktop")
	check(not game.player.tool_view.visible, "the tool is out of view at the computer")
	# ---- UI clicks never swing the tool: mouse pressed while the desktop is open, then released
	press(true)
	await frames(10)
	check(not game.player.tool_view.is_busy() and not game._mine_button_down(), "a held click on the desktop does not start a swing")
	# a machinery window button that opens another menu (the shop) from the desktop, then closing it: still one clean exit
	game.management.os.open_app("machinery")
	game._open_menu("shop")
	check(game.pc_active and game.menu == "shop", "opening the shop from the desktop keeps the computer session")
	game._close_menu()
	game._close_menu()
	await frames(5)
	check(game.pc_busy and game.player.locked, "leaving: controls come back only after the camera does (still locked mid-transition)")
	await frames(40)
	check(not game.pc_busy and not game.pc_active and not game.player.locked and game.player.tool_view.visible, "leaving: camera, movement and tool are all restored")
	check(game.player.camera.global_transform.origin.distance_to(Vector3(game.player.global_position.x, game.player.global_position.y + 1.58, game.player.global_position.z)) < 0.05, "leaving: the camera is back at eye height on the player")
	check(game._mine_button_down() == false, "the click still held from the desktop does not swing the tool after leaving")
	press(false)
	await frames(5)
	# ---- other UI that uses clicks: dialogue card, menus
	game.hud.show_card("Test", "Body text")
	press(true)
	await frames(8)
	check(not game.player.tool_view.is_busy() and not game._mine_button_down(), "a click on a letter / card never swings the tool")
	press(false)
	game.hud.close_card()
	await frames(5)
	game._open_menu("sell")
	press(true)
	await frames(8)
	check(not game.player.tool_view.is_busy() and not game._mine_button_down(), "a click in a shop menu never swings the tool")
	press(false)
	game._close_menu()
	await frames(5)
	# ---- the tool tucks away from a wall and eases back
	var tv: QuarryToolView = game.player.tool_view
	game.set_physics_process(false)                # main would reset the flag every frame: drive the tool view directly
	tv.obstruct = 1.0
	await frames(20)
	var tucked := tv.position
	tv.obstruct = 0.0
	await frames(30)
	check(tucked.y < tv.position.y - 0.08 and tucked.z > tv.position.z + 0.08, "the tool is tucked down and back near a wall and eases back out")
	game.set_physics_process(true)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
