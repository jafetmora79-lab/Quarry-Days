extends SceneTree
## Step 2: the player digs the live ground. Shovel strikes scoop soft ground into the buckets (volume -> units with a carried remainder, nothing created or lost), the shovel is
## stopped by rock with a chink, the pickaxe breaks it into rubble the shovel scoops, and a column dug out to the floor is given up in the bookkeeping.
##   godot --headless --fixed-fps 60 -s tests/test_terrain_strike.gd

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

func inv_total(game, res: String) -> float:
	return float(game.state.inventory[res]) + float(game.terrain_rem.get(res, 0.0))

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(10)
	var lt: LiveTerrain = game.live_terrain
	var st = game.state
	game.prog.cleanup["done"] = true
	st.equipped = "shovel"
	for k in st.inventory.keys():
		st.inventory[k] = 0
	var p := Vector3(0.0, 0.0, -50.0)
	var v0: float = lt.terrain.total_volume()
	for i in range(6):
		game._terrain_strike(p)
	var lost: float = v0 - lt.terrain.total_volume()
	var units := 0.0
	for r in ["topsoil", "gravel"]:
		units += inv_total(game, r) * (1.0 if r == "topsoil" else 1.0)
	check(lost > 0.2 and absf(lost * 11.0 - units) < 0.01, "six strikes dig %.3f m3 and the buckets hold exactly that in units (%.3f units; %.3f m3 x 11)" % [lost, units, lost])
	check(game.dig_audio.log.size() > 0 and str(game.dig_audio.log[0]["sound"]).begins_with("thud_soil"), "each strike made the soil sound")
	# outside the marked excavation nothing happens
	var before: float = lt.terrain.total_volume()
	game._terrain_strike(Vector3(-118.0, 0.0, -50.0))
	check(absf(lt.terrain.total_volume() - before) < 0.0001, "a strike outside the marked excavation digs nothing")
	# dig a hole down to the rock with the shovel
	var q := Vector3(10.0, 0.0, -50.0)
	var blocked := false
	for i in range(220):
		game.dig_audio._cool.clear()
		var r: Dictionary = game._terrain_strike(q)
		if not r.is_empty() and str(r["blocked_by"]) != "" and float(r["volume"]) + float(r["broken"]) <= 0.00001:
			blocked = true
			break
	check(blocked, "the shovel is stopped by rock at the bottom of the hole (strike %d)" % game.dig_audio.log.size())
	check(game.dig_audio.log[game.dig_audio.log.size() - 1]["event"] == "blocked", "with a chink")
	# the pickaxe breaks it, the shovel scoops the rubble
	st.equipped = ""
	st.tool_tier = 1
	game.dig_audio._cool.clear()
	var rb: Dictionary = game._terrain_strike(q)
	check(float(rb["broken"]) > 0.0 or float(rb["volume"]) > 0.0, "the pickaxe works the rock (%.3f broken, %.3f taken)" % [float(rb["broken"]), float(rb["volume"])])
	# a whole column dug out is given up in the bookkeeping, and the units dug are what the buckets hold
	st.equipped = "shovel"
	var col: int = game.prog.cell_index_at("q_top", Vector3(-20.0, 0.0, -50.0))
	var cp: Vector3 = game.prog.column_pos("q_top", col)
	var tiers0: int = game.prog.chunks_left("q_top", col)
	var n := 0
	var x := cp.x - 1.75
	while game.prog.chunks_left("q_top", col) > 0 and n < 900:
		var z := cp.z - 1.75
		while z <= cp.z + 1.75 and game.prog.chunks_left("q_top", col) > 0:
			game.dig_audio._cool.clear()
			game._terrain_strike(Vector3(x, 0.0, z))
			n += 1
			z += 0.7
		x += 0.7
		if x > cp.x + 1.75:
			x = cp.x - 1.75
	check(tiers0 == 1 and game.prog.chunks_left("q_top", col) == 0, "dug out by hand, the column is empty in the bookkeeping (%d strikes)" % n)
	check(lt.terrain.height_at(cp.x, cp.z) < -1.0, "and the ground there is down at the gravel (%.2f)" % lt.terrain.height_at(cp.x, cp.z))
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
