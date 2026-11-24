extends SceneTree
## Thin dirt ridges left between dug patches fall in (clean floors); wide walls and pad edges are only trimmed; the survey line is the dig limit.
##   godot --headless --fixed-fps 60 -s tests/test_ridge_tidy.gd

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

func trench(t, x0: float, x1: float, z0: float, z1: float) -> void:
	for j in range(t.VR):
		for i in range(t.V):
			var x: float = t.origin.x + i * 0.5
			var z: float = t.origin.y + j * 0.5
			if z > z0 and z < z1 and x > x0 and x < x1:
				t.dug[t.idx(i, j)] += 0.9

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(30)
	var t = game.live_terrain.terrain
	# the starter soil pad (x -22..-4, z -73..-56) is 0.9 m of loose topsoil: two trenches leave a 2.5 m ridge
	trench(t, -21.0, -15.0, -71.0, -58.0)
	trench(t, -12.5, -6.0, -71.0, -58.0)
	check(t.height_at(-14.0, -65.0) > 0.7, "1 the wall between the trenches stands 0.9 m high")
	t.tidy_ridges(Vector3(-13.5, 0, -65.0), 8.0)
	check(t.height_at(-14.0, -65.0) < 0.12 and t.height_at(-13.0, -65.0) < 0.12, "2 a thin ridge between two dug patches is levelled to the floor (%.2f m)" % t.height_at(-14.0, -65.0))
	check(t.height_at(-17.0, -65.0) < 0.12 and t.height_at(-9.0, -65.0) < 0.12, "3 the dug floors stay clean")
	var gap: float = t.height_at(1.0, -65.0)
	check(gap < 0.1, "4 the ground between the two soil pads is untouched (%.2f)" % gap)
	# a wide wall (5.5 m) is a pad, not a ridge: its middle stays
	trench(t, 8.0, 12.0, -71.0, -58.0)
	trench(t, 17.5, 23.0, -71.0, -58.0)
	t.tidy_ridges(Vector3(14.5, 0, -65.0), 8.0)
	check(t.height_at(14.5, -65.0) > 0.6, "5 a wide wall is left standing (%.2f m)" % t.height_at(14.5, -65.0))
	# the marked area is the dig limit
	var dr: Array = game.prog.dig_rect("q_top")
	check(dr.size() == 4 and float(dr[0]) <= -120.0 and float(dr[2]) >= 120.0, "6 the dig area is the surveyed area (%s)" % str(dr))
	check(t.is_locked_at(0.0, -108.0) or t.is_locked_at(0.0, -105.0), "7 ground beyond the survey line is locked")
	check(t.is_locked_at(0.0, -20.0) and t.is_locked_at(-9.0, -15.0) and t.is_locked_at(9.0, -15.0) and not t.is_locked_at(0.0, -45.0), "8 the entrance plaza (gate road, hopper and storage side) is never dug, the ground beyond it is open")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
