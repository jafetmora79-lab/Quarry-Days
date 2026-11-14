extends SceneTree
## During a conversation (Grandpa, a new hire) or the opening shots the HUD plates, objective, hints and prompt step aside, the dialog sits at the bottom
## edge, and everything comes back when it ends.   godot --headless --fixed-fps 60 -s tests/test_conversation_hud.gd
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
func plates(game) -> float:
	var a := 0.0
	for nm in ["TopLeftPlate", "MapPlate", "ObjectivePlate"]:
		var pn := game.hud.get_node_or_null(nm) as CanvasItem
		if pn != null:
			a = maxf(a, pn.modulate.a)
	return maxf(a, game.hud.bottom.modulate.a)
func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await frames(30)
	check(plates(game) > 0.95 and not game.hud.conversation, "normally the HUD plates are fully shown")
	game._open_walter_dialog([{"speaker": "GRANDPA WALTER", "text": "Well, look who finally decided to show up.", "dur": 5.0}], func(_s): pass)
	await frames(40)
	check(game.hud.conversation and plates(game) < 0.05, "while Grandpa talks the plates, objective and bars fade out")
	check(not game.hud.hints.visible or game.hud.hints.modulate.a < 0.05, "and so does the hint bar")
	check(not game.hud.prompt_panel.visible, "and the prompt line")
	check(game.walter_dialog != null and game.walter_dialog.offset_bottom == -28.0, "the dialog sits at the bottom edge, clear of Grandpa")
	check(game.highlight_node == null, "nobody is outlined as an interactable while the conversation runs")
	game.walter_dialog.skip()
	await frames(40)
	check(not game.hud.conversation and plates(game) > 0.95, "when the conversation ends everything comes back")
	game.est_running = true
	await frames(40)
	check(game.hud.conversation and plates(game) < 0.05, "the opening shots hide the HUD too")
	game.est_running = false
	await frames(40)
	check(plates(game) > 0.95, "and it returns after them")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
