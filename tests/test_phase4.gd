extends SceneTree
## Phase 4 tests: sustainable resources + art-overhaul integrity (no visual checks).
##   godot --headless --fixed-fps 60 -s tests/test_phase4.gd

var checks := 0
var failures := []
var cfg: Dictionary

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)
	else:
		print("PASS: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func frames(n: int, until: Callable = Callable()) -> int:
	for i in range(n):
		await physics_frame
		if until.is_valid() and until.call():
			return i
	return n

func run_tests() -> void:
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy.json"))
	test_stock_logic()
	await scene_resources()
	await scene_world()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

# ------------------------------------------------------------------ pure resource logic

func test_stock_logic() -> void:
	var s := QuarryState.new(cfg)
	var d := s.ensure_deposit("limestone", "limestone")
	check(int(d["stock"]) == 24 and not d["broken"], "deposit starts with a visible full stock")
	var taken := 0
	for i in range(10):
		taken += s.mine_yield("limestone", 4)
	check(taken == 24 and int(d["stock"]) == 0 and d["broken"], "stock depletes after exactly 24 units (6 breaks)")
	check(s.mine_yield("limestone", 4) == 0, "an empty deposit yields nothing")
	s.clock_minutes += 2.9
	s.regrow_deposits()
	check(int(d["stock"]) == 0, "nothing regrows before the interval")
	s.clock_minutes += 0.2
	s.regrow_deposits()
	check(int(d["stock"]) == 1 and not d["broken"], "one unit regrows after 3 in-game minutes and the deposit is minable again")
	s.clock_minutes += 300
	s.regrow_deposits()
	check(int(d["stock"]) == 24 and float(d["regrow_at"]) < 0.0, "a deposit refills to its cap and stops (no overflow)")
	var iron := s.ensure_deposit("iron_ore", "iron_ore")
	s.mine_yield("iron_ore", 8)
	s.clock_minutes += 36
	s.regrow_deposits()
	check(int(iron["stock"]) == 3, "rarer iron regrows more slowly (3 units in 36 min)")
	var face := s.ensure_deposit("limestone_face", "limestone", true)
	var total := 0
	for i in range(50):
		total += s.mine_yield("limestone_face", 2)
	check(total == 100 and not face["broken"], "quarry face never runs out")
	var old := QuarryState.new(cfg)
	old.deposits = {"coal": {"hits": 1, "ready_at": 900.0, "broken": true, "generation": 3}, "iron_ore": {"hits": 0, "ready_at": 0.0, "broken": false}}
	var c := old.ensure_deposit("coal", "coal")
	var i2 := old.ensure_deposit("iron_ore", "iron_ore")
	check(int(c["stock"]) == 0 and c["broken"] and int(c["generation"]) == 3 and int(i2["stock"]) == 8, "Phase 1-3 deposits migrate: broken -> empty and regrowing, intact -> full")
	old.clock_minutes += 6.5
	old.regrow_deposits()
	old.regrow_deposits()
	check(int(c["stock"]) == 1, "migrated empty deposit regrows")

# ------------------------------------------------------------------ in-game resources

func scene_resources() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.tutorial_visible = false
	check(game.player != null and game.deposit_nodes.has("limestone_face"), "1 game starts with the hand-mining quarry face")
	# deplete the limestone deposit by hand
	var spawned := 0
	for b in range(6):
		var before: int = game.ground_pieces.size()
		for n in range(game.state.required_hits()):
			game._strike("limestone")
		spawned += game.ground_pieces.size() - before
	var dep: Dictionary = game.state.deposits["limestone"]
	check(spawned == 24 and int(dep["stock"]) == 0 and dep["broken"], "2 hand mining takes exactly the 24-unit stock as pieces")
	var body = game.deposit_nodes["limestone"]
	check(body.visible and body.collision_layer == 1 and body.get_child(0).scale.x < 0.5, "2 depleted deposit stays visible and solid, shrunk")
	check(str(body.get_meta("status").text).contains("DEPLETED"), "2 deposit label shows it is depleted and when it regrows")
	var before: int = game.ground_pieces.size()
	for n in range(4):
		game._strike("limestone")
	check(game.ground_pieces.size() == before, "2 striking a depleted deposit produces nothing")
	# regrowth, then player mining again
	game.state.clock_minutes += 12.0
	await frames(2)
	check(int(dep["stock"]) == 4 and not dep["broken"], "2 deposit regrows 4 units in 12 in-game minutes")
	before = game.ground_pieces.size()
	for n in range(game.state.required_hits()):
		game._strike("limestone")
	check(game.ground_pieces.size() == before + 4 and int(dep["stock"]) == 0, "3 player mines the regrown deposit")
	# recovery from zero: no money, nothing loose, deposits empty -> quarry face
	for id in game.ground_pieces.keys():
		game.ground_pieces[id].queue_free()
		game.ground_pieces.erase(id)
	for k in game.state.deposits:
		if not game.state.deposits[k].get("infinite", false):
			game.state.deposits[k]["stock"] = 0
			game.state.deposits[k]["broken"] = true
	game.state.money = 0
	for k in game.state.inventory:
		game.state.inventory[k] = 0
		game.state.storage[k] = 0
	for b in range(3):
		for n in range(5):
			game._strike("limestone_face")
	check(game.ground_pieces.size() == 6, "3 broke player can still hand-mine the quarry face (3 breaks -> 6 pieces)")
	for id in game.ground_pieces.keys():
		game._interact(game.ground_pieces[id])
	check(game.state.sell("limestone", 99) == 6 and game.state.money == 30, "3 face limestone sells: $0 -> $30, recovery possible without free money")
	# workers share the same stock and leave player-broken pieces alone
	game.state.money = 2000
	game.state.deposits["limestone"]["stock"] = 24
	game.state.deposits["limestone"]["broken"] = false
	game._refresh_deposit("limestone")
	for n in range(game.state.required_hits()):
		game._strike("limestone")
	check(game.nearest_piece("limestone", Vector3(-8, 0, -9)) == null, "4 staff skip pieces the player just broke")
	game.state.clock_minutes = 480.0
	game.business.payroll_minute = 480
	game.ui_hire("rosa")
	var miner: Dictionary = game.business.employees[0]
	game.business.set_shift(int(miner["id"]), 0, 1439)
	check(game.nearest_deposit("limestone", Vector3.ZERO) == "limestone", "4 miners never target the hand-mining face")
	Engine.time_scale = 4.0
	var stock0 := int(game.state.deposits["limestone"]["stock"])
	var mined0 := int(game.state.deposits["limestone"].get("mined", 0))
	var storage0 := int(game.state.storage["limestone"])
	await frames(5000, func(): return int(game.state.storage["limestone"]) >= storage0 + 4)
	var used := stock0 - int(game.state.deposits["limestone"]["stock"])
	check(int(game.state.storage["limestone"]) >= storage0 + 4 and used >= 4, "4 worker mining draws from the same deposit stock (%d used)" % used)
	var loose := 0
	for id in game.ground_pieces:
		if str(game.ground_pieces[id].get_meta("resource")) == "limestone":
			loose += 1
	var carried: int = game.business.carry_total(miner)
	check(int(game.state.storage["limestone"]) - storage0 + carried + loose == int(game.state.deposits["limestone"]["mined"]) - mined0 + 4, "4 limestone conserved: storage + carried + loose == units taken from the stock (%d)" % (int(game.state.deposits["limestone"]["mined"]) - mined0))
	Engine.time_scale = 1.0
	game.queue_free()
	await process_frame

## Placeholder for the world/art checks (filled in by later Phase 4 steps).
func scene_world() -> void:
	pass
