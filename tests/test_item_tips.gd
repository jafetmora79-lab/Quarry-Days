extends SceneTree
## The "what is this for?" cards: queued per item, shown one at a time when nothing else is going on, once per item (saved), closed with E, player locked while open, never in headless runs
## unless enabled.
##   godot --headless --fixed-fps 60 -s tests/test_item_tips.gd
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
func key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(5)
	if game.opening_scene != null:
		game.opening_scene.skip_all()                      # the opening is its own test: start from a free player
	await frames(5)
	game.hud.close_card()
	await frames(40)
	var tips: QuarryItemTips = game.item_tips
	check(tips != null and not tips.enabled, "cards are off in headless runs by default")
	tips.offer("gear:shovel")
	check(tips.queue.is_empty(), "a disabled system queues nothing")
	tips.enabled = true
	# the texts exist for every kind
	for id in ["tool:0", "tool:3", "gear:shovel", "gear:ramp_plan", "gear:hand_cart", "gear:air_compressor", "gear:pneumatic_chisel", "vehicle:truck", "vehicle:compact_excavator", "vehicle:loader",
			"vehicle:bulldozer", "machine:crusher", "machine:hopper", "machine:sorter", "machine:output", "machine:conveyor_left", "machine:advanced_crusher"]:
		var d := tips.info(id)
		check(not d.is_empty() and str(d["title"]) != "" and str(d["text"]) != "" and str(d["how"]) != "", "the card for %s has a title, a purpose and how to use it" % id)
	# one card at a time, the player is held, E closes it
	game.player.locked = false
	tips.offer("gear:ramp_plan")
	tips.offer("gear:shovel")
	tips.offer("gear:ramp_plan")
	check(tips.queue.size() == 2, "the same item is queued once")
	await frames(5)
	check(tips.panel != null and tips.current == "gear:ramp_plan" and game.player.locked, "the first card is up and the player is held")
	check(tips.queue.size() == 1, "the second waits its turn")
	tips._unhandled_key_input(key(KEY_E))
	check(tips.panel == null and not game.player.locked, "E closes it and gives control back")
	await frames(5)
	check(tips.panel != null and tips.current == "gear:shovel", "then the next card appears")
	tips._unhandled_key_input(key(KEY_SPACE))
	await frames(3)
	tips.offer("gear:shovel")
	check(tips.queue.is_empty() and bool(game.prog.story["tips"].get("gear:shovel", false)), "a card never comes twice (the flag is in the saved story)")
	# not while Walt talks or a menu is open
	tips.offer("machine:crusher")
	game.menu = "manage"
	await frames(10)
	check(tips.panel == null and tips.queue.size() == 1, "nothing pops up over a menu")
	game.menu = ""
	await frames(5)
	check(tips.panel != null, "it comes once the menu is closed")
	tips._close()
	# the ramp item's picture is a ramp
	var ramp := QuarryHotbar.ramp_miniature()
	check(ramp != null and ramp.get_child_count() >= 6, "the ramp item has its own miniature ramp model")
	ramp.free()
	game.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
