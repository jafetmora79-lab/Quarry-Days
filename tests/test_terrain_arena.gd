extends SceneTree
## The on-foot arena over the real terrain: tools, hints and sounds follow the hardness rules, and every cubic metre stays accounted (ground + shovel + box).
##   godot --headless --fixed-fps 60 -s tests/test_terrain_arena.gd

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
	var arena: TerrainArena = load("res://TerrainArena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await frames(10)
	var t0: float = arena.initial_total
	check(arena.terrain != null and arena.player != null, "the arena builds its terrain and player")
	# shovel: scoops soft ground up to its capacity, accounting holds
	var p := Vector3(3.0, 0.0, 3.0)
	arena.strike(p)
	check(TerrainArena.total_of(arena.carry) > 0.01 and absf(arena.accounted_total() - t0) < 0.001, "a shovel strike scoops topsoil and the accounting holds (%.4f m3 on the shovel)" % TerrainArena.total_of(arena.carry))
	for i in range(8):
		arena.audio._cool.clear()
		arena.strike(p)
	check(TerrainArena.total_of(arena.carry) <= 0.0905, "the shovel never holds more than 0.09 m3 (%.4f)" % TerrainArena.total_of(arena.carry))
	check(arena.audio.log.size() > 0 and str(arena.audio.log[0]["sound"]).begins_with("thud_soil"), "soil makes the soil thud (%s)" % str(arena.audio.log[0]["sound"]))
	# throw it into the box
	arena.release_load(TerrainArena.BOX_CENTER, true)
	check(TerrainArena.total_of(arena.carry) < 0.0005 and TerrainArena.total_of(arena.box) > 0.05 and absf(arena.accounted_total() - t0) < 0.001, "thrown into the box: it left the shovel, entered the box, nothing lost")
	# dig down to rock with the shovel
	var q := Vector3(-3.0, 0.0, 4.0)
	var blocked := false
	# a spade cannot sink a narrow shaft (QuarryTerrain.MAX_DROP): digging down to the rock is a bowl, widened ring by ring round the spot
	for rd in range(16):
		for ring in range(0, 10):
			var n := maxi(1, ring * 6)
			for a in range(n):
				var pp := Vector3(q.x + cos(float(a) / float(n) * TAU) * float(ring) * 0.4, 0.0, q.z + sin(float(a) / float(n) * TAU) * float(ring) * 0.4)
				arena.audio._cool.clear()
				arena.cooldown = 0.0
				if arena.strike(pp).is_empty():
					arena.release_load(Vector3(-12, 0, 6), false)           # shovel full: empty it on the ground and go on
		for i in range(4):
			arena.audio._cool.clear()
			arena.cooldown = 0.0
			var r: Dictionary = arena.strike(q)
			if r.is_empty():
				arena.release_load(Vector3(-12, 0, 6), false)
				continue
			if str(r["blocked_by"]) != "" and float(r["volume"]) <= 0.00001:
				blocked = true
				break
		if blocked:
			break
	check(blocked, "the shovel digs down until the rock stops it")
	check(arena.audio.log[arena.audio.log.size() - 1]["event"] == "blocked" and str(arena.audio.log[arena.audio.log.size() - 1]["sound"]).begins_with("chink"), "and the blow chinks")
	check(arena.message.contains("pickaxe"), "the hint says to use the pickaxe: '%s'" % arena.message)
	check(absf(arena.accounted_total() - t0) < 0.002, "all digging so far is accounted (%.5f)" % (arena.accounted_total() - t0))
	# pickaxe breaks it
	arena._equip("pickaxe")
	arena.audio._cool.clear()
	var rb: Dictionary = arena.strike(q)
	check(float(rb["broken"]) > 0.0 and arena.audio.log[arena.audio.log.size() - 1]["event"] == "dig" and str(arena.audio.log[arena.audio.log.size() - 1]["sound"]).begins_with("crack_rock"), "the pickaxe breaks the rock with a crack (%.3f m3)" % float(rb["broken"]))
	arena._equip("shovel")
	arena.audio._cool.clear()
	var rs: Dictionary = arena.strike(q)
	check(float(rs["volume"]) > 0.0 and float(arena.carry.get("limestone", 0.0)) > 0.0, "the shovel can then scoop the broken limestone")
	check(absf(arena.accounted_total() - t0) < 0.002, "and the books still balance (%.5f)" % (arena.accounted_total() - t0))
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
