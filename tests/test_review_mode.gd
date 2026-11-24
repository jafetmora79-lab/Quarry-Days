extends SceneTree
## F2 review mode: toggles, takes a note with what the crosshair points at and the game's context, saves it to a file, and the CLI file format is readable.
##   godot --headless --path . -s tests/test_review_mode.gd

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
	game.natural_start_enabled = false
	root.add_child(game)
	await frames(4)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	await frames(2)
	var rv: QuarryReviewMode = game.review
	check(rv != null and not rv.active, "1 review mode exists and starts off")
	rv.notes_path = "user://test_qd_notes.json"
	rv.shot_dir = "user://test_review"
	rv.capture_screenshots = false
	rv.notes = []
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F2
	ev.pressed = true
	rv._input(ev)
	check(rv.active, "2 F2 turns it on")
	var target := rv.point_at(game.player.camera.global_position, Vector3(0, -1, 0))
	check(target.has("name") and target.has("hit_position") and target.has("candidates"), "3 pointing at the ground names what is there (%s)" % str(target.get("name", "?")))
	var note := rv.add_note("bug", "  the rock should land in the bucket  ", {"target": target})
	check(int(note["id"]) == 1 and str(note["text"]) == "the rock should land in the bucket" and str(note["status"]) == "open", "4 a note is saved open with its text")
	check(note.has("context") and note["context"].has("day") and note["context"].has("tool") and note["context"].has("site_cleared"), "5 it carries the game's context (day, tool, site cleared...)")
	var note2 := rv.add_note("asset", "bucket model", {})
	check(int(note2["id"]) == 2, "6 ids count up")
	var f := FileAccess.open("user://test_qd_notes.json", FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text())
	check(d is Dictionary and (d["notes"] as Array).size() == 2, "7 the notes file holds both notes")
	rv._input(ev)
	check(not rv.active, "8 F2 turns it off again")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_qd_notes.json"))
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
