extends SceneTree
## Chase camera (sphere probe, frame-rate-independent easing, window-size-independent mouse look), named physics layers and who collides with whom,
## and keyboard/gamepad focus in the office computer.   godot --headless --fixed-fps 60 -s tests/test_camera_ui_physics.gd

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
	# ---- camera: easing is frame-rate independent
	var goal := Vector3(0, 0, 10)
	var a := Vector3.ZERO
	for i in range(30):
		a = QuarryVehicle.ease_toward(a, goal, 7.0, 1.0 / 30.0)
	var b := Vector3.ZERO
	for i in range(144):
		b = QuarryVehicle.ease_toward(b, goal, 7.0, 1.0 / 144.0)
	check(absf(a.z - b.z) < 0.02, "the camera glides the same distance in one second at 30 and at 144 fps (%.3f / %.3f of 10)" % [a.z, b.z])
	# ---- camera: a sphere probe keeps the lens off a wall behind the machine, and eases back out when the wall is gone
	game.state.money = 50000
	game.prog.stage = game.prog.stage_index("large")
	game.business.milestones["mechanized"] = true
	game.ui_buy_vehicle("loader")
	game.delivery.finish_all()
	var v = null
	for nd in game.vehicle_nodes.values():
		if nd.vtype == "loader":
			v = nd
	check(v != null, "a loader to drive")
	v.global_position = Vector3(30.0, 0.1, 50.0)       # open ground in the yard's south-east
	v.rotation.y = 0.0
	v.speed = 0.0
	await frames(3)
	game.enter_vehicle(v)
	await frames(3)
	var wall := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(20.0, 6.0, 0.4)
	cs.shape = bs
	wall.add_child(cs)
	wall.collision_layer = 1
	game.world.add_child(wall)
	wall.global_position = Vector3(30.0, 3.0, 50.0 + 4.2)      # 4.2 m behind the loader, nearer than the 6.5 m chase distance
	await frames(2)
	v.cam_yaw = 0.0
	v._pull_camera_in()
	var gap: float = absf(v.camera.global_position.z - (50.0 + 4.2 - 0.2))
	check(v.camera.global_position.z < 50.0 + 4.0 and gap >= 0.25, "the lens stops short of the wall behind it (%.2f m clear of its face)" % gap)
	wall.queue_free()
	await frames(2)
	var pulled: float = v.camera.position.length()
	v._pull_camera_in(1.0 / 60.0)
	var one_step: float = v.camera.position.length()
	check(one_step > pulled and one_step < v.cam_distance() * 1.3, "with the wall gone it eases back out instead of jumping (%.2f -> %.2f)" % [pulled, one_step])
	game.exit_vehicle()
	await frames(2)
	# ---- mouse look does not depend on the window's stretch
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	game.player.locked = false
	var yaw0: float = game.player.rotation.y
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(10.0, 0.0)
	ev.screen_relative = Vector2(20.0, 0.0)
	game.player._unhandled_input(ev)
	var turned: float = yaw0 - game.player.rotation.y
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		check(absf(turned - 20.0 * QuarryPlayer.MOUSE_LOOK_SCALE * 0.0024) < 0.0005, "mouse look follows screen pixels, not the stretch-scaled motion (%.4f rad)" % turned)
	else:
		check(true, "mouse look (headless: the mouse cannot be captured here, skipped)")
	# ---- physics layers: named, and people walk through NPCs and loose scenery as intended
	check(str(ProjectSettings.get_setting("layer_names/3d_physics/layer_4", "")) == "vehicles" and str(ProjectSettings.get_setting("layer_names/3d_physics/layer_1", "")) == "world", "the physics layers have names (1 world ... 4 vehicles)")
	game._spawn_walter(Vector3(-14.9, 0.0, 5.6))
	var wn: StaticBody3D = game.walter_node
	check(wn.collision_layer == 32 and (game.player.collision_mask & 32) == 0 and (v.collision_mask & 32) == 0, "NPCs sit on layer 6, which neither the player nor any vehicle collides with")
	check((game.player.collision_mask & 8) != 0 and (v.collision_layer & 8) != 0, "the player collides with vehicles, and vehicles live on layer 4")
	game._remove_walter()
	# ---- office computer: a page always has something focused, and the focus outline differs from hover
	game._open_menu("manage")
	await frames(3)
	var mg = game.management
	var ok_all := true
	var pages := ["home", "staff", "equipment", "plan", "production", "upgrades", "milestones", "stats", "hire", "payroll"]
	var bad := []
	for pg in pages:
		mg._set_tab(pg)
		await frames(2)
		var fo: Control = mg.get_viewport().gui_get_focus_owner()
		if fo == null or not mg.is_ancestor_of(fo):
			ok_all = false
			bad.append(pg)
	check(ok_all, "every office page leaves a control focused for the keyboard / gamepad %s" % str(bad))
	var th: Theme = mg.theme if mg.theme != null else null
	var fb = th.get_stylebox("focus", "Button") if th != null else null
	var hb = th.get_stylebox("hover", "Button") if th != null else null
	check(fb is StyleBoxFlat and hb is StyleBoxFlat and (fb as StyleBoxFlat).border_color != (hb as StyleBoxFlat).border_color and (fb as StyleBoxFlat).border_width_left >= 3, "the focus outline is its own bright, thicker style, not the hover look")
	game._close_menu()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
