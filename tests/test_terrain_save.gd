extends SceneTree
## Step 4 (saves): the terrain is saved as only what changed, comes back exactly, and loading twice duplicates nothing. Hand digging, machine digging, loose heaps and the
## carried unit remainders all survive.   Run through tools/run_tests.sh (it gives every job its own save folder).

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
	game.title_enabled = false
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(10)
	var lt: LiveTerrain = game.live_terrain
	var t: QuarryTerrain = lt.terrain
	var st = game.state
	game.prog.cleanup["done"] = true
	st.equipped = "shovel"
	for k in st.inventory.keys():
		st.inventory[k] = 0
	for i in range(30):
		game.dig_audio._cool.clear()
		game._terrain_strike(Vector3(4.0 + 0.4 * float(i % 5), 0.0, -50.0 + 0.4 * float(i / 5)))
	t.add_pile(12.0, -60.0, 2.0, 0.8, "gravel", 0.0)
	t.flush(true)
	var col: int = game.prog.cell_index_at("q_top", Vector3(-30.0, 0.0, -50.0))
	game.prog.extract("q_top", col, 1.0e6, 1 << 30, "excavator")
	game.formation_nodes["q_top"].refresh()
	t.flush(true)
	var total_a: float = t.total_volume()
	var loose_a: float = t.loose_volume()
	var h_a: float = t.height_at(4.4, -49.6)
	var h_col: float = t.height_at(-30.0, -50.0)
	var inv_a: int = st.total(st.inventory)
	var rem_a: Dictionary = game.terrain_rem.duplicate()
	game._save(true)
	# change everything, then load
	for i in range(20):
		game.dig_audio._cool.clear()
		game._terrain_strike(Vector3(20.0, 0.0, -55.0 + 0.3 * float(i)))
	t.add_pile(-10.0, -70.0, 2.0, 1.0, "topsoil", 0.0)
	game._load(true)
	await frames(6)
	lt = game.live_terrain
	t = lt.terrain
	t.flush(true)
	check(absf(t.total_volume() - total_a) < 0.01 and absf(t.loose_volume() - loose_a) < 0.01, "a loaded save has exactly the ground it was saved with (%.5f m3 apart)" % absf(t.total_volume() - total_a))
	check(absf(t.height_at(4.4, -49.6) - h_a) < 0.01 and absf(t.height_at(-30.0, -50.0) - h_col) < 0.01, "the hand-dug hole and the cut column are both back")
	check(st.total(st.inventory) == inv_a and game.terrain_rem.size() == rem_a.size(), "the buckets and the carried unit remainders are back (%d units)" % st.total(st.inventory))
	game._load(true)
	await frames(6)
	t = game.live_terrain.terrain
	t.flush(true)
	check(absf(t.total_volume() - total_a) < 0.01, "loading again duplicates nothing")
	var raw := FileAccess.get_file_as_string("user://quarry_save.json")
	check(raw.length() < 4000000, "the whole save stays small (%d KB)" % (raw.length() / 1024))
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
