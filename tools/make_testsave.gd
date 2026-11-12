extends SceneTree
## Dev tool: writes a save with everything unlocked and plenty of money, for testing shops and machines.
##   godot --headless -s tools/make_testsave.gd
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	for i in range(6):
		await physics_frame
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._remove_walter()
	var prog = game.prog
	game.state.money = 1000000
	game.state.earned = max(game.state.earned, 250000)
	game.state.tool_tier = 4
	game.state.clock_minutes = 8.0 * 60.0
	game.business.milestones["first_employee"] = true
	game.business.milestones["mechanized"] = true
	game.business.milestones["automated"] = true
	prog.stage = prog.stage_index("deep")
	prog.cleanup["done"] = true
	prog.level_unlocked = 2
	prog.quarry_level = 4
	prog.story["intro_seen"] = true
	prog.story["milestones"] = {}
	for m in prog.milestone_defs():
		prog.story["milestones"][str(m["id"])] = true      # no surprise bonuses in a test save
	prog.journal_add("handover")
	prog.check_stages()
	game.player.locked = false
	game.player.global_position = Vector3(0, 0.2, 8)
	game._sync_pit_gate()
	game._save(true)
	print("SAVED to ", ProjectSettings.globalize_path(game.SAVE_PATH))
	quit(0)
