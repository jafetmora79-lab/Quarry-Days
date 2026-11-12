extends SceneTree
## Saves: a launch continues from the save, autosave and close-window save work, a damaged save falls back to the
## backup, and NEW GAME erases it.   godot --headless --fixed-fps 60 -s tests/test_saves.gd

const MAIN := preload("res://scripts/main.gd")
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

func boot(autosave: bool):
	var game = load("res://Main.tscn").instantiate()
	game.natural_start_enabled = false      # Phase 10: these suites test the older systems on the old starting layout
	game.autosave_enabled = autosave
	root.add_child(game)
	await process_frame
	await frames(4)
	return game

func run() -> void:
	for path in [MAIN.SAVE_PATH, MAIN.SAVE_BACKUP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	# ---- a first session
	var a = await boot(false)
	check(not FileAccess.file_exists(MAIN.SAVE_PATH), "A a headless-style session writes nothing on its own")
	if a.walter_dialog:
		a.walter_dialog.skip()
	a.hud.close_card()
	await process_frame
	a.hud.close_card()
	await process_frame
	a.prog.stage = a.prog.stage_index("large")
	a.state.money = 4321
	a.state.clock_minutes = 600.0
	a.business.payroll_minute = 600
	a.state.tool_tier = 1
	a.ui_hire("rosa")
	a.player.global_position = Vector3(3.5, 0.2, 6.0)
	a._save()
	check(FileAccess.file_exists(MAIN.SAVE_PATH), "A saving writes the save file")
	var money_a: int = a.state.money
	var staff_a: int = a.business.employees.size()
	a.queue_free()
	await process_frame
	# ---- relaunch: the game continues from the save, no letter, no fresh start
	var b = await boot(true)
	check(absi(b.state.money - money_a) <= 2 and b.state.tool_tier == 1, "B a new launch continues: money $%d (saved $%d), tool %d" % [b.state.money, money_a, b.state.tool_tier])
	check(b.business.employees.size() == staff_a and b.worker_nodes.size() == staff_a, "B the hired worker is back in the world")
	check(b.player.global_position.distance_to(Vector3(3.5, 0.2, 6.0)) < 0.6, "B and the player stands where they left off")
	check(b.prog.story["intro_seen"] and not b.hud.card_open() and b.walter_dialog == null and not b.walter_intro_running, "B the intro letter is not shown again")
	check(b.player.tool_view.tier == 1, "B the pickaxe is in hand")
	# ---- autosave
	b.state.money = 7777
	b.autosave_t = MAIN.AUTOSAVE_SECONDS
	await frames(3)
	check(b.autosave_t < 5.0, "C the autosave timer fired")
	var peek = b._read_save()
	check(peek is Dictionary and int(peek["money"]) == 7777, "C the autosave wrote the latest progress")
	# ---- closing the window keeps progress
	b.state.money = 8888
	b._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	peek = b._read_save()
	check(int(peek["money"]) == 8888, "C closing the window saves")
	# ---- a damaged save falls back to the backup
	var f := FileAccess.open(MAIN.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var rb = b._read_save()
	check(rb is Dictionary and int(rb["money"]) == 7777, "D a broken save file falls back to the previous good save (backup)")
	b.queue_free()
	await process_frame
	var c = await boot(true)
	check(c.state.money == 7777, "D and the game still starts from it (money $%d)" % c.state.money)
	# ---- NEW GAME erases it
	check(c._confirm_new == false, "E new game needs a second click")
	c.autosave_enabled = false
	for path in [MAIN.SAVE_PATH, MAIN.SAVE_BACKUP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	c.queue_free()
	await process_frame
	var d = await boot(true)
	check(d.state.money != 7777 and not d.prog.story["intro_seen"], "E with no save, a launch starts a fresh game with the letter")
	d.queue_free()
	for path in [MAIN.SAVE_PATH, MAIN.SAVE_BACKUP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
