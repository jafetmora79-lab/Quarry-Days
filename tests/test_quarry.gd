extends SceneTree

var checks := 0
var failures := []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: "+label)
	else:
		print("PASS: "+label)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy.json"))
	var s := QuarryState.new(cfg)
	check(s.money == 100 and s.capacity() == 18,"initial balance and weight capacity")
	check(s.add_item("limestone",4)==4 and s.total(s.inventory)==4,"mining pickup enters inventory")
	check(s.sell("limestone",2)==2 and s.money==110 and s.inventory["limestone"]==2,"selling removes exactly two and pays $10")
	check(s.buy_upgrade("reinforced_pickaxe") and s.required_hits()==2,"reinforced pickaxe changes hits")
	check(s.buy_upgrade("larger_backpack") and s.capacity()==34,"backpack expands capacity")
	check(not s.buy_upgrade("larger_backpack"),"upgrade cannot charge twice")
	check(s.deposit_item("limestone",2)==2 and s.withdraw_item("limestone",1)==1,"storage transfer preserves quantities")
	var s2 := QuarryState.new(cfg)
	s2.new_crusher(Vector3(3,0,5),0)
	s2.add_item("limestone",3)
	check(s2.load_crusher(0,2)==2 and s2.inventory["limestone"]==1,"crusher input deducts inventory")
	check(s2.start_crusher(0),"crusher starts with input")
	s2.tick(17)
	check(s2.crushers[0]["running"] and s2.crushers[0]["output"]==0,"crusher timer has real duration")
	s2.tick(1.1)
	check(not s2.crushers[0]["running"] and s2.crushers[0]["output"]==2,"crusher completes and produces output")
	check(s2.collect_crusher(0)==2 and s2.collect_crusher(0)==0,"output cannot be collected twice")
	check(is_equal_approx(s2.clock_minutes,489.05),"clock advances at 48-minute day rate")
	var restored := QuarryState.new(cfg)
	check(restored.restore(s2.snapshot()) and restored.crushers.size()==1 and restored.inventory["crushed_stone"]==2,"state round-trip restores crusher without duplication")
	var packed := load("res://Main.tscn")
	var game = packed.instantiate()
	game.natural_start_enabled = false      # Phase 10: older systems, old starting layout
	root.add_child(game)
	await process_frame
	check(game.player != null and game.deposit_nodes.size()==12,"project boots with player, eleven formations (three piles, the hillside, the basin bench, six level benches) and the hand-mining quarry face")
	check(not game.placement_valid(Vector3(-7,0,10),0) and game.placement_valid(Vector3(4,0,9),0),"placement rejects selling station and permits clear ground")
	# Phase 5: the starting rocks are enormous formations. Player mining goes straight into the bag;
	# staff mining drops loose pieces beside the column. Both draw from the same column units.
	var stone_max: int = game.prog.max_units("stone_mountain")
	var got: int = game.player_mine("stone_mountain", -1, 90.0)
	check(got == 3 and game.state.inventory["limestone"] == 3 and game.prog.units_left("stone_mountain") == stone_max - 3, "mining a formation puts 3 stone in the bag and takes 3 from its stock")
	game.worker_strike("stone_mountain", 1, 0, null)
	var dropped: int = game.ground_pieces.size()
	check(dropped >= 1 and game.prog.units_left("stone_mountain") == stone_max - 3 - dropped, "staff strikes drop exactly the units removed as loose pieces")
	var first_id: String = game.ground_pieces.keys()[0]
	game._interact(game.ground_pieces[first_id])
	check(game.state.inventory["limestone"] == 4 and game.ground_pieces.size() == dropped - 1, "E pickup removes one world piece")
	game.state.clock_minutes += 110
	game._physics_process(0.01)
	check(game.prog.units_left("stone_mountain") == stone_max - 3 - dropped and game.ground_pieces.size() == dropped - 1, "formations never regrow and loose pieces stay")
	game.state.new_crusher(Vector3(4,0,9),0)
	game._create_crusher(0)
	var money_saved: int = game.state.money
	game._save()
	game.state.money=9999
	game.state.inventory["limestone"]=99
	game._load()
	await process_frame
	check(game.state.money==money_saved and game.state.inventory["limestone"]==4 and game.crusher_nodes.size()==1 and game.ground_pieces.size()==dropped - 1 and game.prog.units_left("stone_mountain") == stone_max - 3 - dropped, "disk save restores machine, pickups and formation stock without duplication")
	game._load()
	await process_frame
	check(game.crusher_nodes.size()==1 and game.ground_pieces.size()==dropped - 1,"repeated load stays idempotent")
	print("RESULT: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
