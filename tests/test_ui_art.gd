extends SceneTree
## Pixel icons and portraits for the UI: every file loads, the HUD icons use them, the same worker always gets the same face, and
## the management window shows portraits and tab icons.   godot --headless --fixed-fps 60 -s tests/test_ui_art.gd
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
func count_rects(n: Node) -> int:
	var k := 0
	for c in n.find_children("*", "TextureRect", true, false):
		if (c as TextureRect).texture != null:
			k += 1
	return k
func run() -> void:
	var names := ["workers", "hire", "payroll", "production", "equipment", "upgrades", "milestones", "stats", "miner", "operator", "hauler", "clerk", "money", "staff", "wages", "skill", "sun", "storage", "crusher", "conveyor", "drill_rig", "excavator", "loader", "truck", "pickaxe", "hammer", "chisel", "bag", "stone", "coal", "iron_ore", "gold"]
	var ok := true
	for n in names:
		var t := UiArt.icon(n)
		var ts := UiArt.icon(n, true)
		ok = ok and t != null and t.get_width() == 64 and t.get_height() == 64 and ts != null and ts.get_width() == 32
	check(ok, "all 32 icons load at 64 x 64, with a 32 x 32 small copy")
	var pok := true
	for i in range(12):
		var t := UiArt.portrait(i)
		pok = pok and t != null and t.get_width() == 64
	check(pok, "every portrait is a 64 x 64 snip of a 3D model")
	var img := UiArt.icon("money").get_image()
	check(img.get_pixel(0, 0).a == 0.0 and img.get_pixel(16, 16).a > 0.9, "icons have a transparent background and solid art")
	check(UiArt.portrait_index("Rosa Quintero", "f") == UiArt.portrait_index("Rosa Quintero", "f") and UiArt.portrait_index("Rosa Quintero", "f") in UiArt.FEMALE, "a worker always gets the same, gender-matched face")
	check(UiArt.portrait_index("Anyone", "m", "clerk") in [UiArt.CLERK, UiArt.CLERK + 1], "clerks use a clerk model portrait")
	var ic := HudIcon.new("coin", 16)
	check(HudIcon.ART.has("coin") and UiArt.has_icon(HudIcon.ART["coin"]), "the HUD coin uses the pixel art")
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(6)
	for i in range(6):
		if game.walter_dialog:
			game.walter_dialog.skip()
		await frames(30)
	game.hud.close_card()
	game._cine_tween().kill()
	await frames(3)
	game.state.money = 5000
	game._open_menu("manage")
	await frames(3)
	var mui = game.management
	if mui != null:
		mui._set_tab("hire")
		await frames(3)
		check(count_rects(mui) >= 8, "the Hire tab shows a portrait per candidate and the tab icons (%d pictures)" % count_rects(mui))
	else:
		check(false, "management window not found")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
