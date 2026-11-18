extends SceneTree
## Hand digging cannot sink a narrow vertical shaft, and the quarry is dug in benches: the step rule (a vertex may not go more than MAX_DROP under its highest neighbour), the bench floor
## (the lowest the ground may be dug to at a place) and the plain explanation the strike returns when digging cannot continue.   godot --headless --fixed-fps 60 -s tests/test_terrain_limits.gd

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

func steepest(t: QuarryTerrain, c: Vector2, r: float) -> float:
	var worst := 0.0
	var g := t.vertex_at(Vector3(c.x, 0, c.y))
	var n := int(r / QuarryTerrain.CELL)
	for j in range(g.y - n, g.y + n + 1):
		for i in range(g.x - n, g.x + n + 1):
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				worst = maxf(worst, absf(t.vheight(t.idx(i, j)) - t.vheight(t.idx(i + d.x, j + d.y))))
	return worst

func run() -> void:
	var geo := QuarryGeology.new()
	var t := QuarryTerrain.new()
	root.add_child(t)
	t.setup(Rect2(-16, -16, 32, 32), geo)
	t.flush(true)
	await frames(2)
	# ---- a spade at one spot: a bowl, never a shaft
	var last := ""
	var strikes := 0
	for i in range(80):
		var r := t.dig(Vector3(2, 0, 2), 0.38, 0.28, 0.09, 0, "scoop")
		strikes += 1
		if str(r["limit"]) != "":
			last = str(r["limit"])
		if float(r["volume"]) <= 0.0000001:
			break
	var depth := -t.height_at(2.0, 2.0)
	check(last == "step", "digging on one spot is eventually refused with the 'step' limit (%d strikes)" % strikes)
	check(depth > 0.3 and depth < 1.2, "the hole stops at a shallow depth (%.2f m), not a shaft" % depth)
	check(steepest(t, Vector2(2, 2), 3.0) <= QuarryTerrain.MAX_DROP + 0.001, "no wall of the hole is steeper than the step rule allows (%.2f m per 0.5 m)" % steepest(t, Vector2(2, 2), 3.0))
	# ---- widening it lets it go deeper
	for ring in range(1, 7):
		for a in range(12):
			var p := Vector3(2.0 + cos(float(a) / 12.0 * TAU) * float(ring) * 0.45, 0, 2.0 + sin(float(a) / 12.0 * TAU) * float(ring) * 0.45)
			for k in range(3):
				t.dig(p, 0.38, 0.28, 0.09, 0, "scoop")
	for i in range(30):
		t.dig(Vector3(2, 0, 2), 0.38, 0.28, 0.09, 0, "scoop")
	var depth2 := -t.height_at(2.0, 2.0)
	check(depth2 > depth + 0.3, "widening the hole lets it go deeper (%.2f m, was %.2f m)" % [depth2, depth])
	check(steepest(t, Vector2(2, 2), 4.0) <= QuarryTerrain.MAX_DROP + 0.001, "and it still has no vertical wall (%.2f)" % steepest(t, Vector2(2, 2), 4.0))
	# ---- loose heaps are never trapped by the rule
	var heap := QuarryTerrain.new()
	root.add_child(heap)
	heap.setup(Rect2(-16, -16, 32, 32), geo)
	heap.add_pile(0.0, 0.0, 2.0, 1.2, "gravel")
	heap.flush(true)
	var top0 := heap.height_at(0.0, 0.0)
	for i in range(40):
		heap.dig(Vector3(0, 0, 0), 0.38, 0.28, 0.09, 0, "scoop")
	check(heap.height_at(0.0, 0.0) < top0 - 0.3, "a heap can be shovelled down from its top (%.2f to %.2f)" % [top0, heap.height_at(0.0, 0.0)])
	# ---- the bench floor
	var b := QuarryTerrain.new()
	root.add_child(b)
	b.setup(Rect2(-16, -16, 32, 32), geo)
	b.flush(true)
	b.depth_floor = func(x: float, z: float) -> float: return -0.5 if x < 0.0 else NAN
	var lim := ""
	for ring in range(0, 9):
		for a in range(max(1, ring * 6)):
			var p := Vector3(-8.0 + cos(float(a) / float(max(1, ring * 6)) * TAU) * float(ring) * 0.4, 0, 0.0 + sin(float(a) / float(max(1, ring * 6)) * TAU) * float(ring) * 0.4)
			for k in range(5):
				var r := b.dig(p, 0.38, 0.28, 0.09, 0, "scoop")
				if str(r["limit"]) == "floor":
					lim = "floor"
	var low := 0.0
	for xi in range(-14, 0):
		low = minf(low, b.height_at(float(xi), 0.0))
	check(low >= -0.5 - 0.001, "the bench floor holds: nothing under it is cut (lowest %.2f m)" % low)
	check(lim == "floor", "and the strike says so with the 'floor' limit")
	var c := QuarryTerrain.new()
	root.add_child(c)
	c.setup(Rect2(-16, -16, 32, 32), geo)
	c.flush(true)
	c.depth_floor = func(x: float, z: float) -> float: return -0.5
	var cut := c.cut_box(Vector3(0, -3.0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), 1.1, 0.2, 1.4, 2.0, 1)
	check(c.height_at(0.0, 0.5) >= -0.5 - 0.001, "a machine's bucket stops at the bench floor too (%.2f)" % c.height_at(0.0, 0.5))
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
