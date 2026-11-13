extends SceneTree
## Living business: bin contents, employee identity and introductions, deliveries (queue, fallback), inventory, saves.
##   godot --headless --fixed-fps 60 -s tests/test_living.gd

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

func box(game, pos: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.6, 2.0, 4.6)
	cs.shape = sh
	b.add_child(cs)
	b.position = pos + Vector3(0, 1.0, 0)
	b.collision_layer = 1
	game.world.add_child(b)
	return b

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.natural_start_enabled = false      # Phase 10: these suites test the older systems on the old starting layout
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = true
	root.add_child(game)
	await process_frame
	await frames(4)
	game.hud.close_card()
	await process_frame
	game.hud.close_card()
	await process_frame
	game.prog.stage = game.prog.stage_index("large")
	game.state.money = 90000
	game.business.milestones["mechanized"] = true
	game.business.milestones["automated"] = true
	var biz: QuarryBusiness = game.business
	# ---- A: bins show what they hold
	game.state.storage["coal"] = 12
	game._update_structures()
	var sf: MeshInstance3D = game.storage_body.get_meta("fill")
	check(sf.material_override == MeshKit.mat("RockCoal"), "A a crate holding only coal shows coal, not white stone")
	var lbl: Label3D = game.storage_body.get_meta("fill_label")
	check(lbl.visible and lbl.text.to_lower().contains("coal"), "A and lists it (%s)" % lbl.text.replace("\n", ", "))
	game.state.storage["coal"] = 0
	game.state.storage["iron_ore"] = 9
	game.state.storage["copper_ore"] = 3
	game._update_structures()
	check(sf.material_override == MeshKit.mat("RockIron"), "A mixed iron + copper shows the dominant material, iron")
	check(lbl.text.to_lower().contains("copper") and lbl.text.to_lower().contains("iron"), "A and the label lists both")
	game.state.storage["iron_ore"] = 0
	game.state.storage["copper_ore"] = 0
	game.state.storage["limestone"] = 4
	game._update_structures()
	check(sf.material_override == MeshKit.mat("RockLimestone"), "A and stone is grey limestone again")
	# ---- B: identity
	game.state.clock_minutes = 600.0
	biz.payroll_minute = 600
	game.ui_hire("rosa")
	var e: Dictionary = biz.employees[0]
	check(QuarryBusiness.PERSONALITIES.has(str(e["personality"])) and int(e["variant"]) >= 0 and int(e["variant"]) < 4 and not bool(e["intro_done"]), "B a new hire has a personality, a look and a pending introduction (%s, look %d)" % [e["personality"], int(e["variant"])])
	var w = game.worker_nodes.values()[0]
	check(w.find_child("QD_Rosa_Body", true, false) != null, "B a named hire wears her own model (Rosa)")
	var old := {"id": 77, "profession": "miner", "name": "Old Timer", "skill": 2}
	QuarryBusiness.ensure_identity(old)
	check(bool(old["intro_done"]) and QuarryBusiness.PERSONALITIES.has(str(old["personality"])), "B older saves get a personality and never replay the introduction")
	# ---- C: introduction
	game.player.global_position = Vector3(2, 0.2, 18)
	await frames(2)
	# a busy player is not interrupted
	game.player.locked = true
	w.global_position = game.player.global_position + Vector3(0, 0, 2.0)
	await frames(30)
	check(game.dialog == null, "C a busy player is never pulled into a conversation")
	game.player.locked = false
	var started := false
	for i in range(900):
		await physics_frame
		if game.dialog != null:
			started = true
			break
	check(started, "C the new employee comes over and the introduction starts")
	check(game.player.locked and game.dialog_worker == w, "C the player is talking to them")
	game._end_intro("Daniel", false)
	await frames(2)
	check(str(biz.employees[0]["name"]) == "Daniel" and bool(biz.employees[0]["intro_done"]) and game.dialog == null, "C the chosen name is kept and the dialogue is over")
	check(not game.player.locked, "C and the player is free again")
	# persistence
	game._save()
	var pers: String = str(biz.employees[0]["personality"])
	var variant: int = int(biz.employees[0]["variant"])
	game._load()
	await frames(4)
	var e2: Dictionary = biz.employees[0]
	check(str(e2["name"]) == "Daniel" and str(e2["personality"]) == pers and int(e2["variant"]) == variant and bool(e2["intro_done"]), "C name, personality and look survive a save, and the introduction is not replayed")
	await frames(60)
	check(game.dialog == null, "C no dialogue after loading")
	# ---- D: deliveries
	var d: QuarryDelivery = game.delivery
	var bays := []
	for slot in game.fleet.cfg["parking"]:
		bays.append(Vector3(float(slot[0]), 0.05, float(slot[2])))
	var blockers := []
	for b in bays:
		blockers.append(box(game, b))
	await frames(2)
	var vehicles_before: int = game.fleet.vehicles.size()
	var msg: String = game.ui_buy_vehicle("loader")
	check(game.fleet.vehicles.size() == vehicles_before + 1 and msg.contains("apron"), "D with every bay blocked the machine is parked on the apron in front of the garage")
	var rec: Dictionary = game.fleet.vehicles.back()
	var fb := Vector3(float(rec["position"][0]), 0.05, float(rec["position"][2]))
	check(fb.z < 15.0, "D at a safe fallback spot (z %.1f)" % fb.z)
	d.finish_all()
	await frames(2)
	var v = game.vehicle_nodes[int(rec["id"])]
	check(v.global_position.distance_to(fb) < 0.4, "D and it ends there")
	# the delivery waits when someone stands where it would appear
	for b in blockers:
		b.free()
	game.player.global_position = Vector3(0.5, 0.2, 25.4)
	game.state.money = 90000
	var n0: int = game.fleet.vehicles.size()
	game.fleet.vehicles.erase(game.fleet.vehicles[0]) if game.fleet.vehicles.size() >= 4 else null
	game._sync_vehicles(true)
	await frames(2)
	game.ui_buy_vehicle("loader")
	var job: Dictionary = d.jobs[d.jobs.size() - 1]
	check(str(job["stage"]) == "queue" and not job["vehicle"].visible, "D a delivery never appears on top of the player: it waits out of sight")
	game.player.global_position = Vector3(10, 0.2, 8)
	await frames(30)
	check(str(job["stage"]) == "drive" and job["vehicle"].visible, "D and drives in once the gate is clear")
	d.finish_all()
	# ---- E: stationary machinery goes to the construction inventory
	var money0: int = game.state.money
	check(game.order_machine("conveyor_left"), "E ordering a corner belt succeeds")
	check(int(biz.inventory.get("conveyor_left", 0)) == 1 and game.state.money < money0, "E it is delivered to the construction inventory and paid for")
	var money1: int = game.state.money
	game._start_placement("conveyor_left")
	check(game.placement and game.placement_belt == "left" and int(biz.inventory.get("conveyor_left", 0)) == 0 and game.state.money == money1, "E placing it uses the delivered item, no second charge")
	game._cancel_placement()
	check(int(biz.inventory.get("conveyor_left", 0)) == 1 and game.state.money == money1, "E cancelling puts it back in the inventory")
	game._save()
	game._load()
	await frames(4)
	check(int(biz.inventory.get("conveyor_left", 0)) == 1, "E and the inventory survives a save without duplicating")
	var vcount: int = game.fleet.vehicles.size()
	game._save()
	game._load()
	await frames(4)
	check(game.fleet.vehicles.size() == vcount and game.vehicle_nodes.size() == vcount, "E vehicles are not duplicated by loading")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
