extends SceneTree
## HUD overhaul: day phase and curfew hint, requirement checklist, toast de-duplication and queue limit, milestone
## banners, delivery and belt badges, contextual key hints.   godot --headless --fixed-fps 60 -s tests/test_hud.gd

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
	root.add_child(game)
	await process_frame
	await frames(4)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	await process_frame
	game.hud.close_card()
	await process_frame
	var hud = game.hud
	# ---- A: clock
	game.state.clock_minutes = 10.0 * 60.0
	await frames(3)
	await process_frame
	check(hud.time_label.text.contains("MORNING"), "A the clock names the part of the day (%s)" % hud.time_label.text)
	game.state.clock_minutes = 20.5 * 60.0
	await frames(3)
	await process_frame
	check(hud.time_label.text.contains("EVENING") or hud.time_label.text.contains("NIGHT"), "A in the evening it says so")
	check(hud.income_label.text.contains("22:00"), "A and warns that the day ends at 22:00 (%s)" % hud.income_label.text)
	game.state.clock_minutes = 9.0 * 60.0
	await frames(3)
	await process_frame
	check(not hud.income_label.text.contains("22:00"), "A the warning goes away in the morning")
	# ---- B: checklist
	hud.refresh_panels()
	check(hud.objective_detail.text.contains("[ ]") or hud.objective_detail.text.contains("[x]"), "B the objective is a checklist (%s)" % hud.objective_detail.text.replace("\n", " | "))
	game.state.earned = 100000
	hud.refresh_panels()
	check(hud.objective_detail.text.contains("[x]"), "B finished requirements are ticked and stay visible")
	# ---- C: toasts
	hud.toast_queue.clear()
	hud.toast_active = null
	hud.toast("Same", "a", "info")
	hud.toast("Same", "b", "info")
	check(hud.toast_queue.size() == 1, "C an identical notice is not queued twice")
	for i in range(8):
		hud.toast("News %d" % i, "x", "info")
	check(hud.toast_queue.size() <= 4, "C the queue stays short (%d)" % hud.toast_queue.size())
	hud.toast("Milestone: Test", "big news", "milestone")
	var has_ms := false
	for q in hud.toast_queue:
		if str(q[2]) == "milestone":
			has_ms = true
	check(has_ms, "C a milestone is never pushed out by older news")
	hud.toast_queue.clear()
	hud.toast("Milestone: Show", "banner", "milestone")
	await process_frame
	await process_frame
	check(hud.toast_active != null and str(hud.toast_active.get_meta("kind")) == "milestone", "C a milestone gets its own banner")
	var t0: float = hud.toast_t
	await frames(200)
	check(hud.toast_active != null, "C and it lingers longer than a normal notice (%.1f s on screen)" % hud.toast_t)
	# ---- D: badges
	var badges: Array = game.hud_badges()
	check(badges.is_empty(), "D no badges when nothing is pending")
	game.business.inventory["crusher"] = 1
	check(game.hud_badges().size() == 1 and str(game.hud_badges()[0][0]).contains("delivered"), "D a delivered machine waiting shows a badge")
	game.business.inventory.clear()
	var bi: int = game.business.add_conveyor(Vector3(6, 0, 7), 0.0, "straight")
	game.business.compute_links()
	var b2: Array = game.hud_badges()
	check(b2.size() == 1 and bool(b2[0][1]) and str(b2[0][0]).contains("not connected"), "D a belt that connects to nothing shows a warning")
	hud.refresh_panels()
	check(hud.badge_label.visible and hud.badge_label.text.contains("belt"), "D and it is on the HUD")
	# ---- E: hints
	check(game._hint_text().contains("WASD move"), "E the default key hint")
	game.placement = true
	check(game._hint_text().contains("rotate"), "E placing a machine shows the placement keys")
	game.placement = false
	game.construction = true
	check(game._hint_text().contains("construction"), "E construction mode has its own hint")
	game.construction = false
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
