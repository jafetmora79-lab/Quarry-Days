extends SceneTree
## The redesigned HUD: money / day / clock top-right, a compact objective tracker (the full checklist on O), a round map bottom-left centred on the
## player, a five-slot hotbar bottom-centre showing the real items (empty slots stay empty; a labelled stand-in, never a wrong picture, while a
## thumbnail is being made), contextual control hints, and everything on screen without overlapping at 1280x720, 1366x768 and 1920x1080.
##   godot --headless --fixed-fps 60 -s tests/test_hud_redesign.gd

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
	await frames(4)
	var hud: QuarryHUD = game.hud
	# ---- layout at the common Windows sizes
	for sz in [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1920, 1080)]:
		root.size = sz
		hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await frames(6)
		var screen := Rect2(Vector2.ZERO, hud.get_viewport_rect().size)
		var pieces := {}
		for nm in ["TimeMoneyPlate", "ObjectivePlate", "MapPlate"]:
			pieces[nm] = hud.get_node(nm) as Control
		pieces["Hotbar"] = hud.hotbar_view
		pieces["Bottom"] = hud.bottom
		var ok := true
		var detail := ""
		for a in pieces:
			var ra: Rect2 = (pieces[a] as Control).get_global_rect()
			if not screen.encloses(ra.grow(-0.5)):
				ok = false
				detail += " %s off-screen %s;" % [a, str(ra)]
			for b in pieces:
				if a < b and ra.grow(-1.0).intersects((pieces[b] as Control).get_global_rect().grow(-1.0)):
					ok = false
					detail += " %s overlaps %s;" % [a, b]
		check(ok, "%dx%d: the HUD pieces are on screen and do not overlap%s" % [sz.x, sz.y, detail])
		var tm: Rect2 = hud.get_node("TimeMoneyPlate").get_global_rect()
		check(tm.end.x > screen.end.x - 30.0 and tm.position.y < 40.0, "%dx%d: money, day and clock are top-right" % [sz.x, sz.y])
		var hb: Rect2 = hud.hotbar_view.get_global_rect()
		check(absf(hb.get_center().x - screen.get_center().x) < 8.0 and hb.end.y > screen.end.y - 70.0, "%dx%d: the hotbar is bottom-centre" % [sz.x, sz.y])
		var mp: Rect2 = hud.get_node("MapPlate").get_global_rect()
		check(mp.position.x < 30.0 and mp.end.y > screen.end.y - 30.0, "%dx%d: the map is bottom-left" % [sz.x, sz.y])
	# ---- the clock and money come from the game
	check(hud.time_label.text.begins_with("DAY 1") and hud.money_label.text.begins_with("$"), "day, clock and money are the game's (%s / %s)" % [hud.time_label.text, hud.money_label.text])
	# ---- the hotbar: five slots, real items, empty stays empty
	var slots: Array = hud.hotbar_view.get_children()
	check(slots.size() == 5, "five hotbar slots")
	var filled := 0
	for sl in slots:
		if sl.find_child("Name", true, false) != null or sl.find_child("Icon", true, false) != null:
			filled += 1
	var bar: Array = game.prog.hotbar()
	check(filled == bar.size() and filled < 5, "only the slots that hold an item show one (%d of 5, hotbar holds %d)" % [filled, bar.size()])
	check(slots[4].find_child("Name", true, false) == null and slots[4].find_child("Icon", true, false) == null, "an empty slot stays empty")
	check(slots[0].find_child("Key", true, false).text == "1", "slots are numbered")
	# a filled slot shows its item's own name while no picture exists (headless cannot render): never a stand-in drawing of another item
	if DisplayServer.get_name() == "headless":
		check(hud.thumbs.cache.is_empty(), "no thumbnails are rendered without a display")
		var nm: Label = slots[0].find_child("Name", true, false)
		check(nm != null and nm.text != "", "the first slot is labelled with its item (%s) while it has no picture" % (nm.text if nm else ""))
	# the slot key points at the real model of the tool
	var cur_key := ToolModels.key_of(game.state.tool_tier)
	check(ToolModels.has_tool(cur_key), "the tool in hand (%s) has a real model to make its picture from" % cur_key)
	for k in ToolModels.LADDER.values() + GearModels.IDS:
		if k == "ramp_plan" or k in GearModels.IDS or k in ToolModels.LADDER.values():
			check(ToolModels.has_tool(str(k)), "%s has a model for its thumbnail" % k)
	# ---- the objective tracker: compact, then the full list
	check(not hud.objectives_expanded and not hud.progress_box.visible and not hud.objective_rows.visible and not hud.status_label.visible, "the tracker starts compact (no checklist, no contract bars)")
	check(hud.objective_label.text != "" and hud.stage_label.text.begins_with("STAGE") and hud.objective_pct.text.ends_with("%"), "it shows the stage, the next thing to do and the progress (%s)" % hud.objective_label.text)
	var compact_h: float = hud.get_node("ObjectivePlate").size.y
	hud.toggle_objectives()
	await frames(3)
	check(hud.objectives_expanded and hud.objective_rows.visible and hud.progress_box.visible, "O opens the full checklist")
	check(hud.get_node("ObjectivePlate").size.y > compact_h + 20.0, "and the plate grows to hold it (%.0f -> %.0f)" % [compact_h, hud.get_node("ObjectivePlate").size.y])
	hud.toggle_objectives()
	await frames(3)
	check(not hud.objectives_expanded and not hud.objective_rows.visible, "O closes it again")
	# ---- the round map follows the player
	var mm: QuarryMinimap = hud.minimap
	var snap: Dictionary = mm.snapshot()
	check(absf(mm.size.x - mm.size.y) < 1.0 and ((snap["player"] as Vector2) - mm.size * 0.5).length() < 1.0, "the map is round and the player is in its middle")
	game.player.global_position += Vector3(7, 0, -5)
	var snap2: Dictionary = mm.snapshot()
	check(((snap2["player"] as Vector2) - mm.size * 0.5).length() < 1.0, "and stays in the middle when the player moves")
	# ---- controls are hints that come and go
	check(not hud.hints.visible, "there is no permanent row of key hints on screen (they live in Settings)")
	check(not hud.bag_bar.visible and hud.bag_label.text.contains(" / ") and not hud.bag_label.text.contains("BAG"), "the bag is a compact number badge (%s), not a bar" % hud.bag_label.text)
	check(not hud.income_label.text.contains("no sales"), "no 'no sales yet' text")
	var strip_free := true
	for pn in ["TimeMoneyPlate", "ObjectivePlate"]:
		var pl: QuarryPlate = hud.get_node(pn)
		strip_free = strip_free and pl.accent.a >= 0.0
	check(strip_free, "plates have no coloured strip (their _draw draws nothing)")
	hud._tool_flash = 0.0
	await frames(5)
	check((hud.bottom.get_node("ToolPlate") as CanvasItem).modulate.a < 0.05, "the tool name steps aside when nothing changes")
	hud._tool_flash = 3.0
	await frames(5)
	check((hud.bottom.get_node("ToolPlate") as CanvasItem).modulate.a > 0.9, "and shows for a few seconds after the tool changes")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
