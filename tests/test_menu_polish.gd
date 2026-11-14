extends SceneTree
## Menu polish: crisp, whole-multiple, distinct icons on plates; clean icon art; cards with a proper text layout; the sales bar docked where it cannot be cut off; the
## HUD plates stepping aside; stats listing only this quarry's layers.   godot --headless --fixed-fps 60 -s tests/test_menu_polish.gd

const ManagementScript = preload("res://scripts/management_ui.gd")
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

## Number of separate pieces of the picture that are smaller than 45% of the biggest one (stray fragments).
func stray_fragments(img: Image) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var seen := {}
	var sizes := []
	for y in range(h):
		for x in range(w):
			if seen.has(Vector2i(x, y)) or img.get_pixel(x, y).a < 0.16:
				continue
			var stack := [Vector2i(x, y)]
			seen[Vector2i(x, y)] = true
			var n := 0
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				n += 1
				for dx in [-1, 0, 1]:
					for dy in [-1, 0, 1]:
						var q := Vector2i(c.x + dx, c.y + dy)
						if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and not seen.has(q) and img.get_pixel(q.x, q.y).a >= 0.16:
							seen[q] = true
							stack.append(q)
			sizes.append(n)
	sizes.sort()
	var big: int = sizes[sizes.size() - 1] if not sizes.is_empty() else 0
	var strays := 0
	for s in sizes:
		if s < int(0.45 * float(big)):
			strays += 1
	return strays

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
	game.state.money = 12345
	await frames(3)
	# ---- icon art: no stray fragments, one icon per card
	var dirty := []
	var da := DirAccess.open("res://assets/ui/icons/")
	for f in da.get_files():
		if f.ends_with(".png"):
			var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/icons/" + f))
			if stray_fragments(img) > 0:
				dirty.append(f)
	check(dirty.is_empty(), "no UI icon carries stray fragments %s" % str(dirty))
	var names := []
	for c in ManagementScript.CARDS:
		names.append(str(c[3]))
	var uniq := {}
	for n in names:
		uniq[n] = true
	check(UiArt.has_icon("plan") and uniq.size() >= names.size() - 0 and names.has("plan"), "every office card has its own icon, the plan has a blueprint of its own (%d cards, %d distinct)" % [names.size(), uniq.size()])
	# ---- icons are shown at a whole multiple of their 32 px art, crisp; and smoothed when small
	var big_rect := UiArt.icon_rect("bag", 64.0)
	var small_rect := UiArt.icon_rect("bag", 16.0)
	check(big_rect.custom_minimum_size.x == 64.0 and big_rect.texture.get_width() == 64 and big_rect.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "the icon art is drawn at 64 px and shown at exactly 64 px, smooth")
	check(small_rect.texture.get_width() == 32 and UiArt.icon("bag", true).get_width() == 32, "small lists and the HUD use the 32 px copy, so nothing is scaled by a fraction")
	# ---- the office home page: cards built as icon plate + title + description
	game._open_menu("manage")
	await frames(4)
	var mg = game.management
	mg._set_tab("home")
	await frames(4)
	var cards: Array = mg.os.icons.values()
	check(cards.size() == ManagementScript.CARDS.size(), "the desktop shows all %d shortcuts (%d)" % [ManagementScript.CARDS.size(), cards.size()])
	var plates := 0
	var titled := 0
	for cb in cards:
		var img: TextureRect = (cb as Control).get_node("Img")
		if img.texture != null and img.texture.get_width() == 32:
			plates += 1                                        # a 32 x 32 native icon
		var cap: Label = (cb as Control).get_node("Caption")
		if cap.text != "" and (cb as Control).tooltip_text != "":
			titled += 1
	check(plates == cards.size() and titled == cards.size(), "each desktop icon has its 32 px picture, a name and a tooltip")
	# ---- hire page: roomy buttons, wage and fee in their own column
	mg._set_tab("hire")
	await frames(4)
	var hire_ok := false
	for b in mg.content.find_children("*", "Button", true, false):
		if (b as Button).text == "Hire" and (b as Button).custom_minimum_size.x >= 90.0:
			hire_ok = true
	check(hire_ok, "the Hire button has a proper width")
	# ---- stats: only this quarry's layers, as bars
	mg._set_tab("stats")
	await frames(4)
	var bars: int = mg.content.find_children("*", "ProgressBar", true, false).size()
	var in_world := 0
	for id in game.prog.formation_ids():
		if game.prog.formation_in_world(id) and game.state.deposits.has(id):
			in_world += 1
	var legacy_rows := 0
	for l in mg.content.find_children("*", "Label", true, false):
		if str((l as Label).text).begins_with("Hillside Face") or str((l as Label).text).begins_with("Coal Seam"):
			legacy_rows += 1
	check(bars == in_world and bars >= 1 and legacy_rows == 0, "stats lists this quarry's %d layers as progress bars and none of the old layout's (%d bars)" % [in_world, bars])
	# ---- the HUD steps aside while a menu is open
	for i in range(20):
		await physics_frame
		game.hud._process(0.05)
	var tl := game.hud.get_node("TopLeftPlate") as CanvasItem
	check(tl.modulate.a < 0.05 and game.hud.map_plate.modulate.a < 0.05, "the HUD plates fade away behind the open menu")
	game._close_menu()
	for i in range(20):
		game.hud._process(0.05)
	check(tl.modulate.a > 0.95, "and come back when it closes")
	# ---- sales: the action bar is docked (outside the scrolling list) and fully inside the panel
	game.state.inventory["limestone"] = 7
	game.state.storage["coal"] = 12
	game._open_menu("sell")
	await frames(6)
	var p = game.panel
	var bar: HBoxContainer = p.bar_box
	var pr: Rect2 = p.get_global_rect()
	var inside := bar.get_child_count() >= 2
	for ch in bar.get_children():
		if not pr.encloses((ch as Control).get_global_rect()):
			inside = false
	check(inside and not p.scroll.is_ancestor_of(bar), "SELL ALL and OFFICE COMPUTER sit in a docked bar inside the panel, never cut off by the list")
	game._close_menu()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
