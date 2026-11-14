extends SceneTree
## Typography and branding: the game is called QUARRY DAYS everywhere it names itself, every font is assigned by role, pixel fonts land on their pixel grid at the common
## window sizes, and no text is smaller than 15 screen pixels at 1280x720, 1366x768, 1600x900 or 1920x1080. NOTE: this proves sizes and assignments, not looks: sharpness,
## contrast and line spacing still need an in-game look.   godot --headless --fixed-fps 60 -s tests/test_typography.gd
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

func texts_under(node: Node, out: Array) -> void:
	for ch in node.get_children():
		if ch is Label and ch.is_visible_in_tree():
			out.append(ch)
		elif ch is Button and ch.is_visible_in_tree() and str(ch.text) != "":
			out.append(ch)
		texts_under(ch, out)

func font_px(c: Control, scale: float) -> float:
	var cls := "Label" if c is Label else "Button"
	return float(c.get_theme_font_size("font_size", cls)) * scale

func run() -> void:
	check(str(ProjectSettings.get_setting("application/config/name")) == "Quarry Days", "the application (window) title is Quarry Days")
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = true
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(5)
	# ---- branding on the main menu
	var words := []
	var labs: Array = []
	texts_under(game.title, labs)
	for l in labs:
		words.append(str(l.text))
	var joined := " ".join(words)
	check(joined.contains("QUARRY") and joined.contains("DAYS"), "the main menu shows QUARRY DAYS")
	check(not joined.to_upper().contains("WALT"), "the main menu does not call the game 'Walt's Quarry'")
	var big := 0.0
	for l in labs:
		if str(l.text) in ["QUARRY", "DAYS"]:
			big = maxf(big, float(l.get_theme_font_size("font_size", "Label")))
	check(big >= 36.0, "the title is the largest text on the menu (%d base px)" % int(big))
	# ---- roles: which face each kind of text uses
	check(QuarryTheme.head().base_font.get_font_name().contains("Pixelify") and QuarryTheme.body().base_font.get_font_name().contains("Nunito"), "titles and buttons are Pixelify Sans, reading text is Nunito Sans")
	check(QuarryTheme.hud().get_font_name().contains("Silkscreen") and QuarryTheme.mono().get_font_name().contains("VT323"), "HUD labels are Silkscreen, readouts are VT323")
	var th: Theme = load("res://assets/ui/qd_theme.tres")
	check(th != null and th.default_font_size == QuarryTheme.BODY and th.get_font("font", "Button") == QuarryTheme.head(), "the project default theme carries the game's fonts and sizes (tooltips and popups included)")
	check(th.has_font_size("font_size", "TooltipLabel"), "tooltips have their own readable size")
	# ---- game on, desktop open with every window: collect the text of the HUD, the menu and the computer
	game._start_new_game_for_test() if game.has_method("_start_new_game_for_test") else null
	game.title.chosen.emit("new")
	await frames(30)
	game.hud.close_card()
	game._open_menu("manage")
	for id in game.management.os.icons:
		game.management.os.open_app(id)
	await frames(5)
	var all: Array = []
	texts_under(game.hud, all)
	texts_under(game.management, all)
	check(all.size() > 60, "enough text to check (%d labels and buttons)" % all.size())
	# ---- at each common window size
	for sz in [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		root.size = sz
		await frames(2)
		QuarryTheme.refresh_pixel_text(self)
		var sc := QuarryTheme.ui_scale()
		var tiny := []
		for c in all:
			if is_instance_valid(c) and font_px(c, sc) < 15.0:
				tiny.append("%s %.1f" % [str(c.text).left(18), font_px(c, sc)])
		check(tiny.is_empty(), "%dx%d (scale %.2f): no text under 15 px on screen %s" % [sz.x, sz.y, sc, str(tiny.slice(0, 4))])
		var off := []
		var pix := 0
		for n in get_nodes_in_group("pixel_text"):
			var l := n as Label
			var grid := int(l.get_meta("pixel_grid"))
			var px := float(l.get_theme_font_size("font_size", "Label")) * sc
			pix += 1
			var tol := 0.6 if sz.y in [720, 1080] else 1.3          # exact at 720p and 1080p, within about one pixel at 768p and 900p (the base size is a whole number)
			if absf(px - roundf(px / grid) * grid) > tol:
				off.append("%s %.1f" % [str(l.text).left(12), px])
		check(pix > 5 and off.is_empty(), "%dx%d: %d pixel-font labels sit on their pixel grid %s" % [sz.x, sz.y, pix, str(off.slice(0, 4))])
	# ---- the HUD plates keep inside the canvas and clear of each other at every size, with the fitted text in them
	game.hud.set_prompt("E — Use the computer")
	game.hud.set_message("Bag full! Sell at the booth or store at the crate. Extra rock drops beside the formation.")
	for sz in [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		root.size = sz
		QuarryTheme.refresh_pixel_text(self)
		game.hud.refresh_panels()
		await frames(6)
		var rects := []
		for n in [game.hud.time_label.get_parent().get_parent(), game.hud.stage_label.get_parent().get_parent(), game.hud.tool_label.get_parent().get_parent().get_parent(), game.hud.prompt_panel]:
			rects.append(Rect2(n.get_global_rect()))
		var cs := Vector2(960.0, 540.0)
		var inside := true
		var overlap := false
		for r in rects:
			inside = inside and Rect2(Vector2(-1, -1), cs + Vector2(2, 2)).encloses(r)
		for i in range(rects.size()):
			for j in range(i + 1, rects.size()):
				overlap = overlap or rects[i].intersects(rects[j])
		check(inside and not overlap, "%dx%d: HUD plates stay inside the canvas and do not overlap: %s" % [sz.x, sz.y, str(rects)])
	root.size = Vector2i(1152, 648)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
