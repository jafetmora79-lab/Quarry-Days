extends SceneTree
## Graphics budget and look: batched fence (no railing props, no rock enclosure), instanced decor that follows the soil, no per-glyph label shadows on plates,
## and a ceiling on separate mesh nodes.   godot --headless --fixed-fps 60 -s tests/test_graphics_budget.gd

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
	for i in range(6):
		if game.walter_dialog:
			game.walter_dialog.skip()
		await frames(20)
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await frames(3)
	var prog: QuarryProgression = game.prog
	# ---- fence: two merged meshes, no railing props, no rock enclosure
	var vis: Node = game.pit_zone.get_node("PitZoneVisuals")
	check(vis.get_node_or_null("FenceFrame") != null and vis.get_node_or_null("FenceWire") != null, "the quarry fence is two merged meshes (frame + wire band)")
	check(game.find_children("FN_MetalRailing*", "Node3D", true, false).is_empty(), "no per-module railing props on the fence")
	var mi_count: int = game.find_children("*", "MeshInstance3D", true, false).size()
	check(mi_count < 620, "the whole world uses fewer than 620 separate mesh nodes (%d; it was 948 before batching)" % mi_count)
	# ---- decor: instanced, a handful of batches, follows the soil
	var top = game.formation_nodes["q_top"]
	var groups: Array = top._decor_groups
	var mmis := 0
	for c in top.get_children():
		if c is MultiMeshInstance3D:
			mmis += 1
	check(mmis >= 3 and mmis <= 6 and groups.size() == mmis, "the surface decor is %d instanced batches, not hundreds of nodes" % mmis)
	var total := 0
	for g in groups:
		total += (g["col"] as Array).size()
	check(total > 300, "with plenty of variety on the soil (%d tufts, patches, stones and scrub)" % total)
	var g0: Dictionary = groups[0]
	var col: int = int((g0["col"] as Array)[0])
	var mm: MultiMesh = g0["mm"]
	check(bool(g0["on"][0]), "a decoration stands on its column")
	prog.cleanup["done"] = true
	prog.extract("q_top", col, 1.0e6, 1 << 30, "hand")
	top.refresh(true)
	check(not bool(g0["on"][0]), "and is switched off (scaled to nothing) when that column is dug out")
	# ---- HUD text: no per-glyph shadows on plates
	var shadowed := 0
	for l in game.hud.find_children("*", "Label", true, false):
		var lab := l as Label
		if lab.has_theme_color_override("font_shadow_color") and lab.get_theme_color("font_shadow_color").a > 0.01:
			shadowed += 1
	check(shadowed <= 4, "only floating text keeps a shadow (%d labels); plates give the contrast, so the HUD costs a fraction of the draw calls" % shadowed)
	check(QuarryTheme.theme().get_color("font_shadow_color", "Label").a < 0.01, "the theme default has no label shadow")
	# ---- ground: grass outside, bare soil inside (no single flat colour)
	var land := 0
	for n in game.art.root.get_children():
		if n is MultiMeshInstance3D and str(n.name).begins_with("LandDetail"):
			land += 1
	check(land == 4, "the land outside the fence has four instanced detail layers (%d)" % land)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
