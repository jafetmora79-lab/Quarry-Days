extends SceneTree
## Phase 10.2: soil excavation, the starter excavator's digging, the utility truck, the spoil heap, conservation and saving.
##   godot --headless --fixed-fps 60 -s tests/test_phase10_earthmoving.gd

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

func total_soil(game) -> int:
	var n: int = game.soil.total() + game.state.soil_dumped
	for rec in game.fleet.vehicles:
		n += int(rec["cargo"].get("soil", 0))
	return n

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await process_frame
	var prog: QuarryProgression = game.prog
	var st: QuarryState = game.state
	game.safety.enabled = false
	var soil: QuarrySoil = game.soil
	# ---- A: the field
	var cells := 0
	for i in range(soil.units.size()):
		cells += int(soil.active[i])
	check(soil != null and cells >= 40 and soil.total() == cells * soil.max_units(), "A the working ground starts as a soil field of %d cells, full depth (%d units)" % [cells, soil.total()])
	var shapes_ok := true
	var enabled := 0
	for i in range(soil.units.size()):
		var on: bool = not (soil.shapes[i] as CollisionShape3D).disabled
		shapes_ok = shapes_ok and on == (int(soil.active[i]) == 1)
		enabled += 1 if on else 0
	check(shapes_ok and soil.body.get_child_count() == soil.units.size(), "A collision is one body with one box per soil cell, on where there is soil (%d boxes on)" % enabled)
	check(soil.surface.mesh != null and soil.surface.mesh.get_surface_count() == 1, "A the surface is a single mesh")
	var hmax: float = soil.full_depth()
	check(absf(hmax - 0.9) < 0.001, "A soil is 0.9 m deep")
	# no soil under boulders or in the service area
	var clear := true
	for c in game.natural_root.get_children():
		if c is StaticBody3D:
			var ci: int = soil.cell_at(c.global_position)
			if ci >= 0 and int(soil.active[ci]) == 1:
				clear = false
	check(clear, "A no soil is placed under a boulder or outcrop")
	# ---- B: finish the repair the quick way and drive
	prog.excavator_state().merge({"battery": true, "hose": true, "fuel": true, "started": true}, true)
	game._ensure_opening()
	var ex: QuarryVehicle = game._starter_vehicle()
	var truck: QuarryVehicle
	for v in game.vehicle_nodes.values():
		if v.vtype == "starter_truck":
			truck = v
	check(ex != null and truck != null and truck.vkind == "truck" and game.fleet.capacity(game.fleet.vehicle(truck.vehicle_id)) == 10, "B Grandpa's utility truck stands by the workshop (capacity 10)")
	check(game.fleet.spec("starter_truck").get("starter", false) and not game.fleet.types().has("starter_truck"), "B and it is not for sale")
	# put the excavator in front of a soil cell
	var target_cell := -1
	for i in range(soil.units.size()):
		if int(soil.active[i]) == 1 and soil.cell_center(i).z < -14.0 and soil.cell_center(i).x > -14.0 and soil.cell_center(i).x < 4.0:
			target_cell = i
			break
	var cc: Vector3 = soil.cell_center(target_cell)
	ex.global_position = Vector3(cc.x, 0.2, cc.z + 4.2)
	ex.rotation.y = 0.0
	ex.speed = 0.0
	ex.velocity = Vector3.ZERO
	await frames(10)
	game.enter_vehicle(ex)
	game.scripted_input = true
	check(game.driving == ex and game.soil_target(ex) >= 0, "B the repaired excavator can be entered and has soil within reach of its bucket")
	var all0: int = total_soil(game)
	var rec: Dictionary = game.fleet.vehicle(ex.vehicle_id)
	var units_before: int = soil.total()
	var cell_before: int = soil.units[game.soil_target(ex)]
	# ---- C: digging
	ex.digging = true
	for i in range(240):
		game._excavator_dig(ex, 1.0 / 60.0)
		await physics_frame
	var in_bucket: int = int(rec["cargo"].get("soil", 0))
	check(in_bucket == game.fleet.capacity(rec) and in_bucket == 3, "C digging fills the small bucket (3 units) and stops there")
	check(soil.total() == units_before - in_bucket and total_soil(game) == all0, "C every unit in the bucket came out of the ground, none was created (%d)" % all0)
	var shapes_follow := true
	for i in range(soil.units.size()):
		shapes_follow = shapes_follow and ((soil.shapes[i] as CollisionShape3D).disabled == (soil.height(i) < 0.05))
	check(shapes_follow, "C collision follows the new surface")
	check(game.state.soil_units == Array(soil.units), "C the saved record follows the ground")
	ex.digging = true
	var more := 0
	for i in range(60):
		game._excavator_dig(ex, 1.0 / 60.0)
	check(int(rec["cargo"].get("soil", 0)) == 3 and soil.total() == units_before - 3, "C a full bucket takes nothing more")
	# ---- D: loading the truck and the spoil heap
	truck.global_position = ex.work_point() + Vector3(0, 0.1, 1.6)
	truck.rotation.y = 0.0
	await frames(8)
	var t: Dictionary = game.dump_target(ex.work_point(), 3.0, ex)
	check(t.has("truck"), "D the bucket can be emptied into the truck when it is close")
	var moved: int = game.vehicle_dump(ex)
	var trec: Dictionary = game.fleet.vehicle(truck.vehicle_id)
	check(moved == 3 and int(trec["cargo"].get("soil", 0)) == 3 and int(rec["cargo"].get("soil", 0)) == 0 and total_soil(game) == all0, "D the 3 units moved into the truck bed, exactly once")
	# fill the truck to its capacity, then try to overfill
	trec["cargo"]["soil"] = 9
	rec["cargo"]["soil"] = 3
	check(game.fleet.transfer(rec, trec) == 1 and int(trec["cargo"]["soil"]) == 10 and int(rec["cargo"]["soil"]) == 2, "D the truck respects its capacity: one unit fits, two stay in the bucket")
	trec["cargo"]["soil"] = 3
	rec["cargo"]["soil"] = 0
	var all1: int = soil.total() + game.state.soil_dumped + 3          # (the bucket test above edited cargo by hand: restate the total)
	var spoil_pos: Vector3 = game.spoil_node.global_position
	truck.global_position = spoil_pos + Vector3(0, 0.2, -2.5)         # its tailgate is over the heap
	truck.rotation.y = 0.0
	await frames(8)
	var dt: Dictionary = game.dump_target(truck.work_point(), 3.0, truck)
	check(dt.has("spoil"), "D a truck with soil that backs up to the marked spoil area can tip there")
	var dumped_before: int = game.state.soil_dumped
	game.vehicle_dump(truck)
	await frames(200)
	check(game.state.soil_dumped == dumped_before + 3 and int(trec["cargo"].get("soil", 0)) == 0 and soil.total() + game.state.soil_dumped + 0 == all1 - 3 + 3 - 0, "D the soil is tipped onto the heap and counted (%d dumped)" % game.state.soil_dumped)
	check((game.spoil_node.get_meta("mound") as MeshInstance3D).visible, "D the spoil heap shows the tipped soil")
	# ---- E: rock is out of reach for the starter excavator
	check(int(game.fleet.spec("starter_excavator")["dig_hardness"]) == 0, "E the starter excavator digs hardness 0 only")
	var rock_ids := []
	for id in ["hillside_face_01", "pit_band_01"]:
		rock_ids.append(id)
	var rock_ok := true
	for id in rock_ids:
		rock_ok = rock_ok and int(prog.material(str(prog.fdef(id)["resource"])).get("hardness", 1)) > 0
	check(rock_ok and not game.fleet.types().has("starter_excavator"), "E every rock has hardness 1 or more: the starter machine refuses it")
	# ---- F: nothing digs the ground out from under the player
	check(soil.surface_y(Vector3(cc.x, 0, cc.z)) <= soil.full_depth() + 0.001 and soil.remove(-1, 5) == 0 and soil.remove(target_cell, 0) == 0, "F the field only ever loses soil: bad requests change nothing")
	game._reset_driving()
	game.scripted_input = false
	# ---- G: saving
	var units_now: int = soil.total()
	var dumped_now: int = game.state.soil_dumped
	game.soil_sync_state()
	game._save(true)
	var saved_units: Array = Array(soil.units)
	for r in range(3):
		game._load(true)
		await frames(3)
	check(Array(game.soil.units) == saved_units and game.soil.total() == units_now and game.state.soil_dumped == dumped_now, "G the dug ground, the spoil count and the cargo survive three save/load rounds")
	var after: int = total_soil(game)
	check(after == total_soil(game) and game.fleet.vehicles.size() == 2, "G no soil, no machine duplicated (%d vehicles)" % game.fleet.vehicles.size())
	var shapes_after := true
	for i in range(game.soil.units.size()):
		shapes_after = shapes_after and ((game.soil.shapes[i] as CollisionShape3D).disabled == (game.soil.height(i) < 0.05))
	check(shapes_after, "G collision still follows the loaded surface")
	# ---- H: a legacy save has no soil
	prog.restore({"schema": 3, "stage": 2, "story": {"intro_seen": true}, "rigs": []}, [])
	game._ensure_opening()
	await frames(3)
	check(game.soil == null and game.spoil_node == null, "H an older save has no soil field or spoil heap")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
