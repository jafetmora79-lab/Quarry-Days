extends SceneTree
## Phase 3 tests (heavy machinery, construction management, expansion building).
##   godot --headless --fixed-fps 60 -s tests/test_phase3.gd

var checks := 0
var failures := []
var cfg: Dictionary
var bcfg: Dictionary
var vcfg: Dictionary

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)
	else:
		print("PASS: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func make(money := 20000) -> QuarryFleet:
	var s := QuarryState.new(cfg)
	s.money = money
	var b := QuarryBusiness.new(s, bcfg)
	b.milestones["mechanized"] = true
	b.milestones["automated"] = true
	b.expansion_unlocked = true
	return QuarryFleet.new(b, vcfg)

func run_tests() -> void:
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy.json"))
	bcfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/business.json"))
	vcfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/vehicles.json"))
	test_fleet_logic()
	test_construction_logic()
	await scene_tests()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

# ------------------------------------------------------------------ logic

func test_fleet_logic() -> void:
	var gate := QuarryFleet.new(QuarryBusiness.new(QuarryState.new(cfg), bcfg), vcfg)
	gate.state.money = 99999
	check(gate.buy("loader", Vector3.ZERO).is_empty() and gate.state.money == 99999, "loader locked until Mechanized Quarry; nothing charged")
	gate.business.milestones["mechanized"] = true
	check(not gate.buy("loader", Vector3.ZERO).is_empty() and gate.buy("truck", Vector3.ZERO).is_empty(), "truck still locked until Automated Business")
	var poor := make(2499)
	check(poor.buy("loader", Vector3.ZERO).is_empty() and poor.state.money == 2499, "cannot buy the loader without $2,500")
	var f := make()
	var loader := f.buy("loader", Vector3.ZERO)
	var truck := f.buy("truck", Vector3(5, 0, 0))
	check(f.state.money == 20000 - 2500 - 5000, "vehicle prices deducted exactly ($2,500 + $5,000)")
	var pile0 := int(f.piles["limestone_rubble"]["amount"])
	var got := f.scoop_pile(loader, "limestone_rubble")
	check(got == 6 and int(f.piles["limestone_rubble"]["amount"]) == pile0 - 6 and int(loader["cargo"]["limestone"]) == 6, "1 loader scoop removes exactly what enters the bucket")
	check(f.scoop_pile(loader, "limestone_rubble") == 0 and int(f.piles["limestone_rubble"]["amount"]) == pile0 - 6, "2 full bucket cannot scoop more")
	var small := make()
	var l2 := small.buy("loader", Vector3.ZERO)
	small.piles["coal_rubble"]["amount"] = 2
	check(small.scoop_pile(l2, "coal_rubble") == 2 and small.scoop_pile(l2, "coal_rubble") == 0 and small.cargo_total(l2) == 2, "1 cannot scoop material a pile does not have")
	check(f.scoop_pile(truck, "coal_rubble") == 0, "trucks cannot scoop")
	check(f.transfer(loader, truck) == 6 and f.cargo_total(loader) == 0 and int(truck["cargo"]["limestone"]) == 6, "4 loader dumps 6 into the truck bed")
	for i in range(3):
		f.piles["limestone_rubble"]["amount"] = 30
		f.scoop_pile(loader, "limestone_rubble")
		f.transfer(loader, truck)
	check(f.cargo_total(truck) == 20 and f.cargo_total(loader) == 4, "4 truck holds 20; extra stays in the bucket")
	var s0 := int(f.state.storage["limestone"])
	f.state.crushers.append({"position": [0, 0, 0], "yaw": 0.0, "input": 0, "output": 0, "running": false, "remaining": 0.0, "hopper": 0, "automated": false, "auto_done": 0})
	check(f.dump_to(truck, {"type": "crusher", "index": 0}) == 20 and int(f.state.crushers[0]["hopper"]) == 20 and f.cargo_total(truck) == 0, "5 truck unloads 20 limestone into a crusher hopper")
	check(not f.business.chain["fed"], "player-driven delivery does not fake the automation milestone")
	f.state.storage["coal"] = 0
	var coal_truck := {"id": 99, "type": "truck", "position": [0, 0, 0], "yaw": 0.0, "cargo": {"coal": 5}}
	check(f.dump_to(coal_truck, {"type": "crusher", "index": 0}) == 0 and int(coal_truck["cargo"]["coal"]) == 5, "3 crusher rejects coal; nothing lost")
	f.state.storage["limestone"] = f.state.storage_capacity() - 3
	check(f.dump_to(loader, {"type": "storage"}) == 3 and f.cargo_total(loader) == 1, "3 dumping into a nearly full crate moves exactly what fits")
	f.state.storage["limestone"] = s0
	# upgrades
	var base_cap := f.capacity(loader)
	var base_truck := f.capacity(truck)
	var base_accel := f.accel(truck)
	var base_speed := f.max_speed(truck)
	var m := f.state.money
	check(f.buy_upgrade("bucket") and f.capacity(loader) == base_cap + 4 and f.state.money == m - 900, "8 bucket upgrade: 6 -> 10 for $900")
	check(f.buy_upgrade("cargo") and f.capacity(truck) == base_truck + 12, "8 cargo upgrade: 20 -> 32")
	check(f.buy_upgrade("engine") and f.accel(truck) > base_accel * 1.39 and f.max_speed(truck) > base_speed * 1.19, "8 engine upgrade: +40% acceleration, +20% top speed")
	check(not f.buy_upgrade("engine"), "8 upgrades cannot be bought twice")
	truck["cargo"] = {"limestone": 32}
	var loaded := f.accel(truck)
	truck["cargo"] = {}
	check(loaded < f.accel(truck), "cargo weight reduces truck acceleration")
	# pile regrowth with accelerated time
	f.piles["coal_rubble"]["amount"] = 0
	f.pile_minute = int(f.state.clock_minutes)
	var every := int(vcfg["pile_regen_minutes"])
	f.state.clock_minutes += every * 10
	f.tick()
	check(int(f.piles["coal_rubble"]["amount"]) == 10, "rubble regrows 1 unit per %d in-game minutes (accelerated)" % every)
	var copy := QuarryFleet.new(f.business, vcfg)
	copy.restore(JSON.parse_string(JSON.stringify(f.snapshot())))
	check(copy.vehicles.size() == 2 and copy.upgrades["engine"] and copy.capacity(copy.vehicles[0]) == 10 and copy.cargo_total(copy.vehicles[0]) == 1, "7 ownership, cargo and upgrades survive save data")

func test_construction_logic() -> void:
	var s := QuarryState.new(cfg)
	s.money = 1000
	var b := QuarryBusiness.new(s, bcfg)
	s.new_crusher(Vector3(0, 0, 0), 0)
	s.new_crusher(Vector3(6, 0, 0), 0)
	b.add_output(Vector3(0, 0, -3), 0)
	var op := b.hire("tomas")
	b.assign(int(op["id"]), {"crusher": 1})
	var hauler := b.hire("bram")
	b.assign(int(hauler["id"]), {"src": {"type": "crusher", "index": 1}, "dst": {"type": "output", "index": 0}})
	s.crushers[0]["hopper"] = 5
	s.crushers[0]["input"] = 2
	s.crushers[0]["output"] = 3
	var before_lime := int(s.storage["limestone"])
	var before_crushed := int(s.storage["crushed_stone"])
	var m := s.money
	check(b.sell_structure("crusher", 0) == 42 and s.money == m + 42, "10 selling a crusher refunds 50% ($42)")
	check(int(s.storage["limestone"]) == before_lime + 7 and int(s.storage["crushed_stone"]) == before_crushed + 3, "11 crusher contents return to storage: 7 limestone + 3 crushed, no more, no less")
	check(s.crushers.size() == 1 and int(op["assignment"]["crusher"]) == 0 and int(hauler["assignment"]["src"]["index"]) == 0, "12 assignments follow the remaining crusher after the index shift")
	check(b.sell_structure("crusher", 0) == 42 and int(op["assignment"]["crusher"]) == -1 and not b.ep_valid(hauler["assignment"]["src"]), "12 assignments to a sold crusher are cleared, never pointing at another machine")
	b.outputs[0]["items"]["crushed_stone"] = 10
	s.storage["limestone"] = s.storage_capacity()
	s.inventory["limestone"] = s.capacity()
	check(b.sell_block_reason("output", 0).begins_with("No room") and b.sell_structure("output", 0) == -1 and b.outputs.size() == 1, "11 cannot sell a storage whose contents have nowhere to go")
	s.storage["limestone"] = 0
	s.inventory["limestone"] = 0
	var total_before := int(s.storage["crushed_stone"]) + 10
	check(b.sell_structure("output", 0) == 30 and int(s.storage["crushed_stone"]) == total_before, "10/11 output storage refunds $30 and returns its 10 crushed stone")
	check(not b.sell_block_reason("storage", 0).is_empty(), "the main storage crate cannot be sold")
	b.add_conveyor(Vector3(10, 0, 7.5), 0)
	b.conveyors[0]["items"] = 2
	b.conveyors[0]["resource"] = "limestone"
	var lime := int(s.storage["limestone"])
	check(b.sell_structure("conveyor", 0) == 10 and int(s.storage["limestone"]) == lime + 2 and b.conveyors.is_empty(), "10/11 conveyor refunds $10 and returns the 2 items on the belt")

# ------------------------------------------------------------------ scene

func frames(n: int, until: Callable = Callable()) -> int:
	for i in range(n):
		await physics_frame
		if until.is_valid() and until.call():
			return i
	return n

## Minimal autopilot: steer toward each waypoint in turn using the real controls.
func drive_route(game, v, points: Array, max_frames: int) -> bool:
	var state := {"i": 0}
	var done := await frames(max_frames, func():
		var target: Vector3 = points[state["i"]]
		var d: Vector3 = target - v.global_position
		if Vector2(d.x, d.z).length() < 2.0:
			state["i"] += 1
			if state["i"] >= points.size():
				v.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
				return true
			return false
		var want := atan2(-d.x, -d.z)
		var diff := wrapf(want - v.rotation.y, -PI, PI)
		v.input = {"throttle": 0.7 if absf(diff) < 0.6 else 0.35, "steer": clampf(-diff * 2.0, -1.0, 1.0), "brake": false}
		return false)
	return done < max_frames

func place(v, pos: Vector3, yaw: float) -> void:
	# Test setup only: position a parked vehicle at a known spot.
	v.global_position = pos
	v.rotation.y = yaw
	v.speed = 0.0
	v.velocity = Vector3.ZERO
	v.settled_frames = 0
	v.safe_position = pos

func scene_tests() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame
	game.tutorial_visible = false
	game.scripted_input = true
	game.state.money = 50000
	check(not game.placement_valid(Vector3(38, 0, 2), 0), "14 east expansion is not buildable while locked")
	game.business.milestones["first_employee"] = true
	game.business.milestones["mechanized"] = true
	game.business.chain = {"mined": true, "fed": true, "processed": true, "stored": true, "sold": true}
	game.business.auto_crushed_sold = game.business.sales_goal()
	game.business.check_milestones()
	await frames(3)
	check(game.business.expansion_unlocked and game.pile_nodes["iron_rubble_east"].visible, "expansion opens its rubble piles")
	# --- purchase & parking
	check(game.ui_buy_vehicle("loader").ends_with("parking area."), "front loader bought at the office")
	check(game.ui_buy_vehicle("truck").ends_with("parking area."), "dump truck bought at the office")
	check(game.state.money == 50000 - 7500, "office purchases charge $7,500 in total")
	var loader = null
	var truck = null
	for v in game.vehicle_nodes.values():
		if v.vtype == "loader":
			loader = v
		else:
			truck = v
	check(loader.global_position.distance_to(truck.global_position) > 3.0, "vehicles spawn in separate parking bays")
	await frames(10)
	check(loader.global_position.y > -0.2 and loader.global_position.y < 0.5 and loader.is_on_floor(), "parked loader rests on the ground")
	# --- enter, scoop, capacity
	game.enter_vehicle(loader)
	check(game.driving == loader and not game.player.visible, "E enters the loader")
	var pile_pos: Vector3 = game.pile_nodes["limestone_rubble"].global_position
	place(loader, Vector3(pile_pos.x, 0.05, pile_pos.z + 3.6), 0.0)
	await frames(5)
	var pile0 := int(game.fleet.piles["limestone_rubble"]["amount"])
	var got: int = game.loader_primary(loader)
	var rec: Dictionary = game.fleet.vehicle(loader.vehicle_id)
	check(got == 6 and int(game.fleet.piles["limestone_rubble"]["amount"]) == pile0 - 6 and game.fleet.cargo_total(rec) == 6, "1 loader in the world scoops 6 real limestone from the pile")
	game.loader_primary(loader) # lower
	check(game.loader_primary(loader) == 0 and game.fleet.cargo_total(rec) == 6, "2 full bucket scoops nothing more")
	# --- 6: cannot drive through the pile core
	loader.input = {"throttle": 1.0, "steer": 0.0, "brake": false}
	var front := {"min": 999.0}
	await frames(150, func():
		front["min"] = minf(front["min"], loader.global_position.z)
		return false)
	loader.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
	check(front["min"] > pile_pos.z + 0.7 + 1.5 - 0.15, "6 loader is stopped by the solid rubble pile (closest centre z %.2f)" % front["min"])
	# --- truck receives from the loader
	await frames(20)
	place(truck, Vector3(pile_pos.x + 4.0, 0.05, pile_pos.z + 2.6), PI / 2)
	place(loader, Vector3(pile_pos.x + 4.0, 0.05, pile_pos.z + 2.6 + 4.2), 0.0)
	await frames(5)
	var moved: int = game.vehicle_dump(loader)
	var trec: Dictionary = game.fleet.vehicle(truck.vehicle_id)
	check(moved == 6 and game.fleet.cargo_total(trec) == 6 and game.fleet.cargo_total(rec) == 0, "4 loader dumps its 6 limestone into the truck bed (moved %d)" % moved)
	# --- exit and drive the truck
	check(game.exit_vehicle() and game.player.visible and game.driving == null, "E exits the loader to a clear spot")
	var p: Vector3 = game.player.global_position
	check(p.distance_to(loader.global_position) > 1.0, "player is placed beside the vehicle, not inside it")
	game.enter_vehicle(truck)
	place(truck, Vector3(3.0, 0.05, 18.5), 0.0)
	await frames(5)
	var start: Vector3 = truck.global_position
	var reached := await drive_route(game, truck, [Vector3(5.5, 0, 12), Vector3(7, 0, 7.5), Vector3(20, 0, 7.5), Vector3(28, 0, 7), Vector3(32, 0, 2), Vector3(38, 0, 1)], 4000)
	check(reached, "vehicles reach the east expansion along the access road (at %s)" % str(truck.global_position))
	check(game.fleet.cargo_total(trec) == 6 and truck.global_position.distance_to(start) > 30.0, "4 truck transports its cargo")
	# --- 5: unload into the storage crate
	place(truck, Vector3(10, 0.05, 6.4), 0.0)
	await frames(5)
	var before := int(game.state.storage["limestone"])
	game.vehicle_dump(truck)
	var tilt := {"max": 0.0}
	await frames(240, func():
		tilt["max"] = maxf(tilt["max"], truck.bed_tilt)
		return false)
	check(int(game.state.storage["limestone"]) == before + 6 and game.fleet.cargo_total(trec) == 0, "5 truck unloads exactly 6 limestone into the storage crate")
	check(tilt["max"] > 0.5, "truck bed lifts while unloading")
	# --- 6: truck cannot drive through the storage crate
	place(truck, Vector3(10, 0.05, 15.5), 0.0)
	await frames(5)
	truck.input = {"throttle": 1.0, "steer": 0.0, "brake": false}
	var tmin := {"z": 999.0}
	await frames(200, func():
		tmin["z"] = minf(tmin["z"], truck.global_position.z)
		return false)
	truck.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
	check(tmin["z"] > 10.8 + 2.3 - 0.15, "6 truck is stopped by the storage crate (closest centre z %.2f)" % tmin["z"])
	# --- 8: engine upgrade measured on open ground
	var dist := []
	for pass_i in range(2):
		if pass_i == 1:
			game.ui_vehicle_upgrade("engine")
		place(truck, Vector3(-8, 0.05, 3.5), -PI / 2)
		await frames(5)
		var x0: float = truck.global_position.x
		truck.input = {"throttle": 1.0, "steer": 0.0, "brake": false}
		await frames(60)
		truck.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
		dist.append(truck.global_position.x - x0)
		await frames(90)
	check(dist[1] > dist[0] * 1.25, "8 engine upgrade measurably improves acceleration (%.2f m -> %.2f m in 60 frames)" % [dist[0], dist[1]])
	game.exit_vehicle()
	# --- 9/12: relocate a crusher; its operator follows and keeps working
	game.state.new_crusher(Vector3(-4, 0, 4), 0)
	game._create_crusher(game.state.crushers.size() - 1)
	var ci: int = game.state.crushers.size() - 1
	game.business.compute_links()
	game._rebake_nav()
	game.state.clock_minutes = 600.0
	game.business.payroll_minute = 600
	game.ui_hire("tomas")
	var op: Dictionary = game.business.employees[0]
	game.business.set_shift(int(op["id"]), 0, 1439)
	game.ui_assign(int(op["id"]), {"crusher": ci})
	game.construction = true
	check(game.start_relocation("crusher", ci), "9 construction mode detaches the crusher for moving")
	check(not game.crusher_nodes[ci].visible and game.placement, "9 original crusher hidden during the move preview")
	game.ghost.position = Vector3(4, 0, 4)
	game.placement_yaw = PI / 2
	game.ghost_valid = game.placement_valid(game.ghost.position, game.placement_yaw)
	game._place_ghost()
	var c: Dictionary = game.state.crushers[ci]
	check(Vector2(float(c["position"][0]), float(c["position"][2])).distance_to(Vector2(4, 4)) < 0.01 and game.crusher_nodes[ci].visible and is_equal_approx(game.crusher_nodes[ci].rotation.y, PI / 2), "9 crusher moved and rotated to the confirmed spot")
	game.state.crushers[ci]["hopper"] = 3
	var worked := await frames(4000, func(): return int(game.state.crushers[ci]["hopper"]) < 3)
	check(worked < 4000 and game.worker_nodes.values()[0].global_position.distance_to(Vector3(4, 0, 4)) < 3.2, "12 operator walks to the relocated crusher and resumes loading")
	# cancel a move keeps everything
	var money_before: int = game.state.money
	game.start_relocation("crusher", ci)
	game.ghost.position = Vector3(-10, 0, 2)
	game._cancel_placement()
	c = game.state.crushers[ci]
	check(Vector2(float(c["position"][0]), float(c["position"][2])).distance_to(Vector2(4, 4)) < 0.01 and game.crusher_nodes[ci].visible and game.crusher_nodes[ci].collision_layer == 1 and game.state.money == money_before, "cancelled move restores the crusher with no money change")
	# --- 13: conveyor from a relocated storage crate into the moved crusher
	game.start_relocation("storage", 0)
	game.ghost.position = Vector3(4, 0, 10)
	game.placement_yaw = 0.0
	game.ghost_valid = game.placement_valid(game.ghost.position, 0.0)
	check(game.ghost_valid, "storage crate can be moved to clear ground")
	game._place_ghost()
	check(game.business.storage_pos.distance_to(Vector3(4, 0, 10)) < 0.01 and game.storage_body.position.distance_to(Vector3(4, 0.65, 10)) < 0.01, "9 storage crate relocated")
	# crusher at (4,4) yaw PI/2 -> input port at (5.15,0,4); belt from crate side toward it
	game.business.add_conveyor(Vector3(4.6, 0, 7.6), 0.0) # start (4.6,0,8.6) near crate, end (4.6,0,6.6)
	game._create_conveyor(game.business.conveyors.size() - 1)
	game.business.add_conveyor(Vector3(5.15, 0, 5.6), 0.0)  # start (5.15,6.6) end (5.15,4.6)
	game._create_conveyor(game.business.conveyors.size() - 1)
	game.business.compute_links()
	var links: Array = game.business.links
	check(links[0]["src"].get("type") == "storage" and links[1]["dst"].get("type") == "crusher" and links[0]["resource"] == "limestone", "13 conveyors reconnect the moved crate to the moved crusher (%s)" % str(links))
	game.state.storage["limestone"] = 6
	var hop0 := int(game.state.crushers[ci]["hopper"]) + int(game.state.crushers[ci]["input"]) + int(game.state.crushers[ci]["output"])
	await frames(1200, func(): return int(game.state.storage["limestone"]) == 0 and game.business.conveyor_total() == 0)
	var hop1 := int(game.state.crushers[ci]["hopper"]) + int(game.state.crushers[ci]["input"]) + int(game.state.crushers[ci]["output"])
	check(int(game.state.storage["limestone"]) == 0 and hop1 - hop0 == 6, "13 conveyors still deliver exactly 6 limestone")
	# conveyors are crossable on foot but solid for vehicles
	var belt = game.conveyor_nodes[0]
	check(belt.collision_layer == 16 and (game.player.collision_mask & 16) == 0 and (game.worker_nodes.values()[0].collision_mask & 16) == 0 and (truck.collision_mask & 16) != 0, "conveyors: people step over, vehicles collide")
	await frames(3)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(game.nav_map, Vector3(2.0, 0, 7.6), Vector3(7.0, 0, 7.6), true)
	var length := 0.0
	for k in range(1, path.size()):
		length += path[k - 1].distance_to(path[k])
	check(path.size() > 0 and length < 6.5, "workers path straight across a conveyor (%.1f m for 5 m)" % length)
	# --- 10/11 in the world: selling with confirmation
	var out_i: int = game.business.add_output(Vector3(-4, 0, 2), 0)
	game._create_output(out_i)
	game.business.outputs[out_i]["items"]["crushed_stone"] = 4
	var crushed := int(game.state.storage["crushed_stone"])
	money_before = game.state.money
	check(game.request_sell("output", out_i) == -1 and game.business.outputs.size() == out_i + 1, "11 selling a storage with contents asks for confirmation first")
	check(game.request_sell("output", out_i) == 30 and game.state.money == money_before + 30 and int(game.state.storage["crushed_stone"]) == crushed + 4 and game.output_nodes.size() == game.business.outputs.size(), "10 confirmed sale refunds $30 and returns the 4 crushed stone")
	# --- 14: build in the expansion
	check(game.placement_valid(Vector3(38, 0, 2), 0) and game.conveyor_valid(Vector3(38, 0, -3), 0), "14 expansion ground accepts machines and conveyors")
	check(not game.placement_valid(Vector3(30, 0, 0), 0), "14 the cliff gap itself is not buildable")
	game.state.new_crusher(Vector3(38, 0, 2), 0)
	game._create_crusher(game.state.crushers.size() - 1)
	var east: int = game.business.add_output(Vector3(38, 0, -0.9), 0)
	game._create_output(east)
	game.business.compute_links()
	check(game.business.crusher_outputs[game.state.crushers.size() - 1] == east, "14 expansion crusher links to its output storage")
	# --- office UI: equipment tab builds and fits
	game._open_menu("manage")
	var frame: Control = game.management.get_child(0)
	var widest := 0.0
	for t in ["staff", "hire", "payroll", "production", "equipment", "milestones"]:
		game.management._set_tab(t)
		await process_frame
		widest = maxf(widest, frame.get_combined_minimum_size().x)
	check(game.management.content.get_child_count() > 0 and widest <= 880.0, "office EQUIPMENT tab builds; all six tabs fit the 960x540 canvas (widest %.0f px)" % widest)
	game._close_menu()
	# --- 15: save/load everything
	game.enter_vehicle(loader)
	place(loader, Vector3(-3, 0.05, 12.5), 0.4)
	loader.rotation.y = 0.4
	await frames(5)
	game.fleet.vehicle(loader.vehicle_id)["cargo"] = {"coal": 3}
	game._save()
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.fleet.snapshot()))
	var bsnap: Dictionary = JSON.parse_string(JSON.stringify(game.business.snapshot()))
	var crushers := JSON.stringify(game.state.crushers)
	var money_saved: int = game.state.money
	game.exit_vehicle()
	game.fleet.vehicles.clear()
	game.fleet.upgrades["engine"] = false
	game.state.money += 5000
	game.business.storage_pos = Vector3(10, 0, 10)
	game._load()
	var after: Dictionary = JSON.parse_string(JSON.stringify(game.fleet.snapshot()))
	check(JSON.stringify(after["vehicles"]) == JSON.stringify(snap["vehicles"]) and after["upgrades"] == snap["upgrades"] and after["piles"] == snap["piles"], "15 vehicles, positions, cargo, upgrades and piles restored")
	check(game.vehicle_nodes.size() == 2 and game.vehicles_root.get_child_count() >= 2 and game.driving != null and game.driving.vtype == "loader", "15 vehicles rebuilt once; player is back in the loader")
	check(absf(game.driving.rotation.y - 0.4) < 0.05 and game.driving.global_position.distance_to(Vector3(-3, 0.05, 12.5)) < 0.3, "15 vehicle position and orientation restored")
	check(game.business.storage_pos.distance_to(Vector3(4, 0, 10)) < 0.01 and game.storage_body.position.x == 4.0, "15 relocated storage crate restored")
	check(JSON.stringify(game.state.crushers) == crushers and game.state.money == money_saved, "15 machinery (incl. expansion crusher), production queues and money restored")
	check(JSON.stringify(game.business.snapshot()["conveyors"]) == JSON.stringify(bsnap["conveyors"]) and game.business.links[0]["src"].get("type") == "storage", "15 conveyors and their connections restored")
	await frames(2)
	game._load()
	await process_frame
	await process_frame
	check(game.vehicles_root.get_child_count() == 2 and game.state.money == money_saved, "15 repeated load does not duplicate vehicles or money")
	# --- Phase 2 save (no phase3 block) loads with no vehicles
	var f := FileAccess.open("user://quarry_save.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	data.erase("phase3")
	data["phase2"].erase("storage_pos")
	data["phase2"].erase("auto_crushed_sold")
	f = FileAccess.open("user://quarry_save.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	game._load()
	await process_frame
	await process_frame
	check(game.fleet.vehicles.is_empty() and game.vehicles_root.get_child_count() == 0 and game.driving == null and game.player.visible, "Phase 2 save loads with no vehicles and the player on foot")
	check(game.business.storage_pos == QuarryBusiness.STORAGE_POS and game.business.milestones["automated"], "Phase 2 save keeps its progress; crate at its original spot")
	game.queue_free()
	await process_frame
