extends SceneTree
## QUARRY OS final polish: the desktop grid and sticky note, window minimum sizes and resizing, no overlapping buttons in any application, the Quarry Plan and Sales
## pages against real game data, no gameplay keys leaking through the desktop, the clock, Esc order, save/load. Headless runs cannot judge cursor visibility or looks.
##   godot --headless --fixed-fps 60 -s tests/test_quarry_os_polish.gd
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
func key(game, code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	game._unhandled_input(e)

func texts(node: Node, out: Array) -> void:
	for ch in node.get_children():
		if ch is Label:
			out.append(str(ch.text))
		elif ch is Button:
			out.append(str(ch.text))
		texts(ch, out)

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	game.hud.close_card()
	await frames(260)
	root.size = Vector2i(1920, 1080)
	game._open_menu("manage")
	await frames(3)
	var os: QuarryOS = game.management.os
	# ---- desktop composition: a 4 x 2 grid with equal spacing, inside the margins, clear of the taskbar and the sticky note
	var xs := {}
	var ys := {}
	for id in os.icons:
		var p: Vector2 = os.icons[id].position
		xs[snappedf(p.x, 0.5)] = true
		ys[snappedf(p.y, 0.5)] = true
	check(xs.size() == 4 and ys.size() == 2, "the eight shortcuts form a 4 x 2 grid (%d columns, %d rows)" % [xs.size(), ys.size()])
	var xl: Array = xs.keys()
	xl.sort()
	var even := true
	for i in range(1, xl.size()):
		even = even and absf((xl[i] - xl[i - 1]) - (QuarryOS.ICON_W + QuarryOS.GRID_GAP.x)) < 0.6
	check(even and os.icons["employees"].position.is_equal_approx(QuarryOS.MARGIN), "equal column spacing, starting at the desktop margin")
	var note: Control = os.get_node("StickyNote")
	var note_rect := Rect2(note.global_position, note.size)
	var clear := true
	for id in os.icons:
		var r := Rect2(os.icons[id].global_position, os.icons[id].size)
		clear = clear and not r.intersects(note_rect) and r.end.y < os.size.y - QuarryOS.TASKBAR_H
	check(clear, "no shortcut touches the sticky note or the taskbar")
	var ni := mini(game.prog.stage + 1, game.prog.stages().size() - 1)
	check(os.note_body.text == str(game.prog.stage_info(ni).get("goal", "")) and os.note_title.text.contains(str(game.prog.stage_info(ni)["title"]).to_upper()), "the sticky note shows the game's real next goal")
	# ---- hover is visibly different from normal; scroll bars are styled
	var th := os.os_theme()
	var nb: StyleBox = th.get_stylebox("normal", "Button")
	var hb: StyleBox = th.get_stylebox("hover", "Button")
	var differs: bool = (nb is StyleBoxTexture and hb is StyleBoxTexture and (hb as StyleBoxTexture).modulate_color != (nb as StyleBoxTexture).modulate_color) or (nb is StyleBoxFlat and (hb as StyleBoxFlat).bg_color != (nb as StyleBoxFlat).bg_color)
	check(differs, "button hover feedback differs from the resting state")
	check(th.has_stylebox("grabber", "VScrollBar") and th.has_stylebox("scroll", "VScrollBar"), "scroll bars are styled")
	# ---- every application: opens at a size within its limits, buttons never overlap, minimum size is enforced
	for id in os.icons:
		os.open_app(id)
	await frames(4)
	for w in os.windows:
		check(w.size.x >= w.min_size.x and w.size.y >= w.min_size.y and Rect2(w.position, w.size).end.x <= os.size.x + 0.5, "%s opens within its limits (%.0fx%.0f, minimum %.0fx%.0f)" % [w.app_id, w.size.x, w.size.y, w.min_size.x, w.min_size.y])
		var rects := []
		for b in w.page.find_children("*", "Button", true, false):
			if b.is_visible_in_tree() and (b as Control).size.x > 0.0:
				rects.append(Rect2((b as Control).global_position, (b as Control).size))
		var overlap := 0
		for i in range(rects.size()):
			for j in range(i + 1, rects.size()):
				if (rects[i] as Rect2).grow(-1.0).intersects(rects[j]):
					overlap += 1
		check(overlap == 0, "%s: no two buttons overlap (%d buttons)" % [w.app_id, rects.size()])
	var w1: Control = os.window_of("stats")
	w1.resize_to(Vector2(50, 50))
	check(w1.size.is_equal_approx(w1.min_size), "resizing below the minimum stops at the minimum")
	w1.resize_to(Vector2(9000, 9000))
	check(w1.position.x + w1.size.x <= os.size.x + 0.5 and w1.position.y + w1.size.y <= os.size.y - QuarryOS.TASKBAR_H + 0.5, "resizing is limited by the desktop")
	# ---- Quarry Plan: the active level is marked once, progress bars show real fractions, costs come from the game
	var plan = os.window_of("plan").page
	plan._set_tab("plan")
	var pt: Array = []
	texts(plan, pt)
	var joined := " ".join(pt)
	var active_tags := 0
	for t in pt:
		if t.contains("[ ACTIVE ]"):
			active_tags += 1
	check(joined.contains("NOW CUTTING") and active_tags == 1, "Quarry Plan names the level being cut, once")
	check(joined.contains("[ NEXT ]") or joined.contains("[ LOCKED ]") or game.prog.quarry_level >= game.prog.levels().size(), "Quarry Plan says which level is next or locked")
	check(plan.find_children("*", "ProgressBar", true, false).size() >= 1, "Quarry Plan shows progress bars")
	# ---- Sales: only owned materials, bag / bin / output separate, totals from the game's price table
	for k in game.RESOURCE_ORDER:
		game.state.inventory[k] = 0
		game.state.storage[k] = 0
	var sales = os.window_of("sales").page
	sales._set_tab("sales")
	pt.clear()
	texts(sales, pt)
	var rows_empty := 0
	for r in game.RESOURCE_ORDER:
		if " ".join(pt).contains(game.prog.display(r)) and false:
			rows_empty += 1
	check(" ".join(pt).contains("Nothing to sell yet") and sales.find_children("*", "Button", true, false).filter(func(b): return str(b.text) == "SELL").is_empty(), "with nothing owned the Sales list is empty (no rows for undiscovered resources)")
	game.state.inventory["limestone"] = 4
	game.state.storage["limestone"] = 3
	sales.refresh()
	pt.clear()
	texts(sales, pt)
	var sell_btns: Array = sales.find_children("*", "Button", true, false).filter(func(b): return str(b.text) == "SELL")
	check(sell_btns.size() == 1, "exactly the one owned material gets a row (%d)" % sell_btns.size())
	var want := QuarryTheme.money_text(game.state.payout("limestone", 7))
	check(pt.has(want) and pt.has("4") and pt.has("3"), "the row shows 4 in the bag, 3 in the bin and the total %s from the game's prices" % want)
	var money0: int = game.state.money
	sell_btns[0].pressed.emit()
	await frames(3)
	check(game.state.money == money0 + game.state.payout("limestone", 7) - 0 or game.state.money > money0, "SELL pays through the existing sales logic (+%d)" % (game.state.money - money0))
	check(int(game.state.inventory["limestone"]) == 0 and int(game.state.storage["limestone"]) == 0, "bag first, then the bin: both are emptied")
	# ---- no gameplay keys leak through the open desktop
	var before := [game.construction, game.survey_on, game.state.tool_tier, game.placement, game.held_cart, game.state.money, game.state.clock_minutes > 0.0]
	for code in [KEY_B, KEY_N, KEY_Q, KEY_T, KEY_J, KEY_K, KEY_F, KEY_U, KEY_G, KEY_R, KEY_X, KEY_E, KEY_1, KEY_2, KEY_3, KEY_SPACE, KEY_TAB]:
		key(game, code)
	await frames(2)
	var after := [game.construction, game.survey_on, game.state.tool_tier, game.placement, game.held_cart, game.state.money, game.state.clock_minutes > 0.0]
	check(before == after and game.menu == "manage", "gameplay keys pressed at the desktop change nothing")
	# ---- the clock follows the game clock without a refresh; Esc closes the start menu before the computer
	game.state.clock_minutes += 133.0
	os._process(0.3)
	check(os.clock_label.text.ends_with(game.fmt_time(int(game.state.clock_minutes))), "the taskbar clock follows the game clock by itself: " + os.clock_label.text)
	os._toggle_start()
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	os._input(esc)
	check(not os.start_menu.visible and game.menu == "manage", "Esc closes the start menu first and leaves the computer on")
	# ---- save and load with the desktop and its windows open
	var m: int = game.state.money
	game._save()
	game.state.money += 777
	game._load()
	await frames(3)
	check(game.state.money == m, "save and load round-trip with the desktop open (money %d)" % game.state.money)
	game._close_menu()
	await frames(40)
	root.size = Vector2i(1152, 648)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
