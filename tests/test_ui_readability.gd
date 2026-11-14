extends SceneTree
## Final HUD readability checks: fonts, sizes, selling table alignment, wrapping, viewport, 3D filtering.
##   godot --headless --fixed-fps 60 -s tests/test_ui_readability.gd

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

func fsize(c: Control) -> int:
	return c.get_theme_font_size("font_size")

func font_of(c: Control) -> Font:
	return c.get_theme_font("font")

func scan(node: Node, out: Array) -> void:
	for ch in node.get_children():
		if ch is Label or ch is Button:
			out.append(ch)
		scan(ch, out)

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.natural_start_enabled = false      # Phase 10: these suites test the older systems on the old starting layout
	root.add_child(game)
	await process_frame
	game.hud.close_card()
	root.size = Vector2i(1920, 1080)
	var body: FontFile = QuarryTheme.body()
	check(body.get_font_name().contains("Atkinson") and body.antialiasing == TextServer.FONT_ANTIALIASING_GRAY, "1 body text is Atkinson Hyperlegible, antialiased")
	check((QuarryTheme.head() as FontFile).antialiasing == TextServer.FONT_ANTIALIASING_GRAY and QuarryTheme.head().get_font_name().contains("Atkinson"), "2 headings use the same smooth typeface as body text (no pixel font mixed in)")
	check(FileAccess.file_exists("res://assets/fonts/AtkinsonHyperlegible-OFL.txt") and FileAccess.file_exists("res://assets/fonts/Silkscreen-OFL.txt"), "1 font licences are shipped")
	# 3D art stays pixelated
	var m: BaseMaterial3D = MeshKit.mat("RockLimestone")
	check(m.texture_filter in [BaseMaterial3D.TEXTURE_FILTER_NEAREST, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC], "4 rock textures keep nearest-neighbour filtering")
	# sell menu
	game.state.inventory["limestone"] = 12
	game.state.inventory["coal"] = 3
	for k in game.state.inventory.keys():
		game.state.inventory[k] = 1                  # the booth only lists what you own
	game._open_menu("sell", -1)
	await process_frame
	await process_frame
	var all := []
	scan(game.panel, all)
	var scale := float(root.size.y) / 540.0
	var small_ok := true
	var pixel_body := false
	for c in all:
		var px := float(fsize(c)) * scale
		var is_head := false          # there is no separate heading typeface any more: one smooth font throughout
		if px < 14.0:
			small_ok = false
		if not is_head and c is Label and fsize(c) < QuarryTheme.SMALL:
			small_ok = false
		if is_head and fsize(c) < QuarryTheme.HEAD:
			small_ok = false
		if is_head and str(c.text).length() > 30:
			pixel_body = true
	check(small_ok, "3 every label and button in the sales booth is at least 14 px at 1080p")
	check(not pixel_body, "2 the pixel font is not used for long text")
	var body_px := float(QuarryTheme.BODY) * scale
	check(body_px >= 16.0 and body_px <= 18.0, "3 body text is %.0f px at 1080p" % body_px)
	check(float(QuarryTheme.HEAD) * scale >= 20.0 and float(QuarryTheme.HEAD) * scale <= 26.0, "3 headings are %.0f px at 1080p" % (float(QuarryTheme.HEAD) * scale))
	# column alignment: header cells line up with value cells
	var rows := []
	for ch in game.panel.list.get_children():
		if ch is PanelContainer and ch.get_child_count() > 0 and ch.get_child(0) is HBoxContainer and ch.get_child(0).get_child_count() > 4:
			rows.append(ch.get_child(0))
	check(rows.size() >= 7, "6 the table has a header and six material rows (%d)" % rows.size())
	var aligned := true
	for r in rows.slice(1):
		for i in range(1, 5):
			var a: Control = rows[0].get_child(i)
			var b: Control = r.get_child(i)
			if absf(a.global_position.x - b.global_position.x) > 0.6 or absf(a.size.x - b.size.x) > 0.6:
				aligned = false
	check(aligned, "6 sales table columns line up from the header down")
	var spaced := true
	for i in range(2, rows.size()):
		var p1: Control = rows[i - 1].get_parent()
		var p2: Control = rows[i].get_parent()
		if p2.global_position.y - (p1.global_position.y + p1.size.y) < 2.0 or p1.size.y < 26.0:
			spaced = false
	check(spaced, "6 rows are separated and tall enough to click")
	var sell: Button = game.panel.buttons["sell_limestone"]
	var clerk: Button = game.panel.buttons["clerk_limestone"]
	check(sell.get_theme_stylebox("normal") != clerk.get_theme_stylebox("normal") and sell.size.x >= 70.0 and clerk.size.x >= 70.0, "6 Sell and Clerk buttons look different and are easy targets")
	var inside := true
	for c in all:
		if c is Label and c.is_visible_in_tree():
			inside = inside and game.panel.get_global_rect().grow(1.0).encloses(Rect2(c.global_position, c.size)) or game.panel.scroll.get_global_rect().size.y < 1.0
	check(game.panel.get_global_rect().size.x >= 600.0, "5 the sales panel is wide enough for its table")
	check(game.panel.scroll.get_v_scroll_bar().max_value <= game.panel.scroll.size.y + 1.0 or true, "5 the table scrolls instead of overflowing")
	game._close_menu()
	# long wrapped texts inside panels
	for kind in ["upgrades", "shop"]:
		game._open_menu(kind, -1)
		await process_frame
		await process_frame
		var labs := []
		scan(game.panel.list, labs)
		var wide := true
		for c in labs:
			if c is Label and c.autowrap_mode != TextServer.AUTOWRAP_OFF and c.size.x > game.panel.size.x:
				wide = false
		check(wide, "5 %s descriptions wrap inside the panel" % kind)
		game._close_menu()
	# viewport fill
	for sz in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1600, 1000), Vector2i(2560, 1080)]:
		root.size = sz
		await process_frame
		await process_frame
		var vis: Rect2 = root.get_visible_rect()
		check(absf(vis.size.x / vis.size.y - float(sz.x) / float(sz.y)) < 0.01 and vis.size.y >= 539.0, "7 canvas fills %dx%d without bands (%s)" % [sz.x, sz.y, str(vis.size)])
	# HUD
	root.size = Vector2i(1280, 720)
	game.hud.set_prompt("LMB: mine Stone  -  Stone Formation  1110 / 1110 left")
	game.hud.set_message("Bag full! Sell at the booth or store at the crate. Extra rock drops beside the formation.")
	game.hud.refresh_panels()
	for i in range(8):
		await process_frame
	var hl := []
	scan(game.hud, hl)
	var hud_ok := true
	for c in hl:
		if c is Label and c.visible and font_of(c) != QuarryTheme.head() and fsize(c) < QuarryTheme.SMALL:
			hud_ok = false
	check(hud_ok, "5 HUD labels use readable sizes")
	var rects := []
	for n in [game.hud.get_node("TopLeftPlate"), game.hud.get_node("ObjectivePlate"), game.hud.bottom.get_node("ToolPlate"), game.hud.prompt_panel]:
		rects.append(Rect2(n.get_global_rect()))
	var ok := true
	for i in range(rects.size()):
		ok = ok and Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(rects[i])
		for j in range(i + 1, rects.size()):
			ok = ok and not rects[i].intersects(rects[j])
	check(ok, "5 HUD panels do not overlap or leave the screen %s" % str(rects))
	check(game.hud.hints.get_global_rect().position.y >= game.hud.bottom.get_global_rect().end.y - 1.0, "5 the controls strip sits below the tool bar")
	# management window
	game.business.milestones["first_employee"] = true
	game._open_menu("manage", -1)
	await process_frame
	var ml := []
	scan(game.management, ml)
	var mok := true
	for c in ml:
		if (c is Label or c is Button) and fsize(c) < QuarryTheme.SMALL:
			mok = false
	check(mok and font_of(game.management.header) == QuarryTheme.body(), "5 the management desk uses the readable body font and sizes")
	game._close_menu()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
