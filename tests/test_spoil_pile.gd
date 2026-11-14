extends SceneTree
## The spoil heap: a square highlighted pad whose pile grows with the soil dumped (cube-root growth), with a glowing amber border.
##   godot --headless --fixed-fps 60 -s tests/test_spoil_pile.gd
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
	game.natural_start_enabled = true
	root.add_child(game)
	await process_frame
	game.hud.close_card()
	var n: Node3D = game.spoil_node
	check(n != null and n.has_meta("mound") and n.has_meta("glow") and n.has_meta("label"), "the pad has a mound, a glowing border and a label")
	var mound: Node3D = n.get_meta("mound")
	game.state.soil_dumped = 0
	game._update_spoil()
	check(not mound.visible, "no soil dumped: no pile yet")
	game.state.soil_dumped = 5
	game._update_spoil()
	await frames(60)
	var s0 := mound.scale.y
	game.state.soil_dumped = 60
	game._update_spoil()
	await frames(60)
	var s1 := mound.scale.y
	game.state.soil_dumped = 500
	game._update_spoil()
	await frames(60)
	var s2 := mound.scale.y
	check(s0 < s1 and s1 < s2, "the pile grows with the soil dumped (%.2f < %.2f < %.2f)" % [s0, s1, s2])
	check(absf(s2 - 1.0) < 0.02, "a full heap reaches full size")
	check((n.get_meta("label") as Label3D).text.contains("500"), "the label counts the soil")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
