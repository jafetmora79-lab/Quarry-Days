extends SceneTree
## First-person movement: jump height, no air jumps, landing, Space-mantle onto reachable ledges (and not onto too-high ones), input gating.
## Runs on a private arena far from the quarry so nothing else is in the way.   godot --headless --fixed-fps 60 -s tests/test_movement.gd
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
func box(game, pos: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	b.set_meta("ground", true)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	game.world.add_child(b)
	return b

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	game.hud.close_card()
	await frames(260)
	for k in range(6):                                  # the opening conversation, if any, is skipped: movement is only tested with the player in control
		if game.walter_dialog != null:
			game.walter_dialog.skip()
		if game.dialog != null:
			game.dialog.skip_btn.pressed.emit()
		if game.est_running:
			game._est_finish()
		await frames(30)
		game.hud.close_card()
	var p: QuarryPlayer = game.player
	check(game.gameplay_input_allowed(), "the player is in control")
	var A := Vector3(600, 0, 600)
	box(game, A + Vector3(0, -0.5, 0), Vector3(40, 1, 40))                       # the arena floor, top at y = 0
	box(game, A + Vector3(0, 0.6, -6.0), Vector3(4, 1.2, 2))                     # a 1.2 m ledge, front face at z = -5
	box(game, A + Vector3(10, 0.8, -6.0), Vector3(4, 1.6, 2))                    # a 1.6 m ledge: too high to climb
	p.global_position = A + Vector3(0, 0.05, 0)
	p.rotation.y = 0.0
	p.velocity = Vector3.ZERO
	await frames(20)
	check(p.is_on_floor(), "the player stands on the arena floor")
	# ---- jump: 0.9 m, one jump per landing
	var y0 := p.global_position.y
	p._jump_buf = 0.12
	var apex := y0
	var second_boost := false
	for i in range(60):
		await physics_frame
		apex = maxf(apex, p.global_position.y)
		if i == 12:
			var vy := p.velocity.y
			p._jump_buf = 0.12                              # a press in mid-air...
			await physics_frame
			second_boost = p.velocity.y > vy + 1.0          # ...must not add lift
	check(absf((apex - y0) - 0.9) < 0.12, "a jump lifts the feet about 0.9 m (%.2f)" % (apex - y0))
	check(not second_boost, "no jumping again in mid-air")
	check(p.is_on_floor(), "the player lands again")
	# ---- landing is soft: a small dip, no shake
	p.shake = 0.0
	p.velocity.y = 9.0
	await frames(70)
	check(p.shake == 0.0 and absf(p.kick) <= 0.031, "landing feedback is a small dip without shake (kick %.3f)" % p.kick)
	# ---- mantle: Space at a 1.2 m ledge climbs it smoothly
	p.global_position = A + Vector3(0, 0.05, -4.2)
	p.rotation.y = 0.0
	p.velocity = Vector3.ZERO
	await frames(10)
	p._jump_buf = 0.12
	await frames(4)
	check(p._mantle_t > 0.0, "Space at a 1.2 m ledge starts a climb")
	var ys := []
	for i in range(34):
		await physics_frame
		ys.append(p.global_position.y)
	var smooth := true
	for i in range(1, ys.size()):
		smooth = smooth and absf(ys[i] - ys[i - 1]) < 0.12
	check(smooth, "the climb moves smoothly (no jump of more than 12 cm in a frame)")
	await frames(20)
	check(p.global_position.y > 1.15 and p.global_position.y < 1.4 and p.global_position.z < A.z - 5.1 and p.is_on_floor() and p._mantle_t <= 0.0, "the player ends standing on the ledge with control back (%s)" % str(p.global_position - A))
	# ---- a 1.6 m ledge is too high: Space only jumps
	p.global_position = A + Vector3(10, 0.05, -4.2)
	p.velocity = Vector3.ZERO
	await frames(10)
	p._jump_buf = 0.12
	await frames(3)
	check(p._mantle_t <= 0.0, "a 1.6 m ledge is not climbable")
	await frames(60)
	check(p.global_position.y < 0.3, "the player is back on the floor in front of the high ledge")
	# ---- no jumping or climbing while a menu, dialogue or card has the input
	game._open_menu("sell")
	p.velocity = Vector3.ZERO
	p._jump_buf = 0.12
	await frames(8)
	check(p.global_position.y < 0.3 and not is_instance_valid(null), "no jump while a menu is open")
	game._close_menu()
	game.hud.show_card("Test", "text")
	p._jump_buf = 0.12
	await frames(8)
	check(p.global_position.y < 0.3, "no jump while a story card is open")
	game.hud.close_card()
	await frames(5)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
