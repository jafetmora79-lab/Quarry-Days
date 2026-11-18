extends SceneTree
## The quarry ground overhaul: digging is only possible inside the marked excavation (by hand, machine, crew or dinosaur alike), the excavation is staked out with tape,
## loose ore is the Blender ore set, the topsoil carries clods of dug earth instead of flat patches, and the ore layers show ore on their top.
##   godot --headless --fixed-fps 60 -s tests/test_dig_zone.gd

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
	var prog: QuarryProgression = game.prog
	prog.cleanup["done"] = true                         # the site is clean: the only thing left that can stop a cut is the survey line
	# ---- the marked excavation
	var r: Array = prog.dig_rect("q_top")
	check(r.size() == 4 and float(r[0]) > -110.0 and float(r[2]) < 115.0 and float(r[1]) > -104.0, "the topsoil has a marked excavation (%s) that leaves the edges of the plain untouched" % str(r))
	var inside := -1
	var outside_near := -1
	var outside_side := -1
	for i in range(prog.column_count("q_top")):
		var p: Vector3 = prog.column_pos("q_top", i)
		if inside < 0 and absf(p.x) < 6.0 and p.z < float(r[3]) - 4.0 and p.z > float(r[1]) + 6.0:
			inside = i
		if outside_near < 0 and p.x > float(r[2]) + 6.0:
			outside_near = i
		if outside_side < 0 and p.x < float(r[0]) - 6.0:
			outside_side = i
	check(prog.column_in_dig_area("q_top", inside), "a column inside the survey line may be dug")
	check(not prog.column_in_dig_area("q_top", outside_near), "a column beyond the east survey line may not")
	check(prog.extraction_block("q_top", outside_near, "hand").begins_with("Outside the marked excavation"), "by hand it says so: %s" % prog.extraction_block("q_top", outside_near, "hand"))
	for src in ["excavator", "crew", "companion"]:
		check(prog.extraction_block("q_top", outside_near, src).begins_with("Outside the marked excavation"), "%s cannot dig outside it either" % src)
	check(not prog.extraction_block("q_top", inside, "hand").begins_with("Outside"), "inside it the block is gone (%s)" % prog.extraction_block("q_top", inside, "hand"))
	var before: int = prog.column_units("q_top", outside_near)
	game.player_mine("q_top", outside_near, 9999.0, prog.column_pos("q_top", outside_near))
	check(prog.column_units("q_top", outside_near) == before, "a swing at ground outside the line takes nothing")
	var before_side: int = prog.column_units("q_top", outside_side)
	game.player_mine("q_top", outside_side, 9999.0, prog.column_pos("q_top", outside_side))
	check(prog.column_units("q_top", outside_side) == before_side, "nor at the far side")
	# ---- the survey stakes and tape
	var vis: Node = game.pit_zone.get_node("PitZoneVisuals")
	check(vis.get_node_or_null("DigStakes") == null and vis.get_node_or_null("DigTape") == null, "the excavation line is the painted survey line only: no stakes or tape that can be walked through")
	# ---- the Blender ground set
	for res in ["limestone", "coal", "iron_ore", "copper_ore", "gold_ore", "gravel", "soil"]:
		var ok := true
		for v in range(3):
			ok = ok and WorldModels.ore_piece(res, v) != null
		check(ok, "ore set: three %s chunks" % res)
	var iron := WorldModels.ore_piece("iron_ore", 0)
	check(iron != null and iron.get_surface_count() >= 3, "an iron chunk has its rock, its red ore and its dark specks as separate surfaces (%d)" % (iron.get_surface_count() if iron != null else 0))
	check(WorldModels.mesh("dirt_clods") != null, "the clods of dug earth model exists")
	# ---- the topsoil decor: clods, not flat patches
	var top = game.formation_nodes["q_top"]
	var flat_discs := 0
	for g in top._decor_groups:
		var m: Mesh = (g["mm"] as MultiMesh).mesh
		if m != null and m.get_aabb().size.y < 0.02:
			flat_discs += 1
	check(flat_discs == 0, "no decoration on the topsoil is a flat, hard-edged disc (%d)" % flat_discs)
	# ---- ore on the ore layers
	var coal = game.formation_nodes["q_a3_coal"]
	check(coal._decor_groups.size() >= 1, "the coal bench shows lumps of coal on its top (%d groups)" % coal._decor_groups.size())
	var gold = game.formation_nodes["q_a5_gold"]
	check(gold._decor_groups.size() >= 1, "the gold bench shows nuggets in quartz on its top")
	# ---- a loose piece uses the model (no texture-less box, its own materials)
	var body := StaticBody3D.new()
	body.add_child(MeshInstance3D.new())
	game.add_child(body)
	game.art.dress_piece(body, "copper_ore", 1)
	var pm: MeshInstance3D = body.get_child(0)
	check(pm.mesh != null and pm.mesh.get_surface_count() >= 3 and pm.material_override == null, "a loose copper piece is the Blender chunk with its own malachite and copper surfaces")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
