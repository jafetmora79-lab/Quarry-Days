extends SceneTree
## Buckets instead of a bag: you carry as many buckets as you fill (18 each), the pail in your hand shows its load, every full bucket slows you a little, E at the starter box
## dumps one bucket (hold E for all), the box holds 100 and shows its contents when aimed at, and it empties into the Cash Hopper by itself.
##   godot --headless --fixed-fps 60 -s tests/test_buckets.gd

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
	game.cash_hopper_enabled = true
	root.add_child(game)
	await process_frame
	await frames(10)
	var st = game.state
	check(st.bucket_capacity() == 18 and st.capacity() == 18 * QuarryState.BUCKET_STACK, "a bucket holds 18 and any number can be carried (%d buckets)" % QuarryState.BUCKET_STACK)
	var bar: Array = game.prog.hotbar()
	check("bucket" in bar, "the bucket is a hotbar item like the pickaxe (%s)" % str(bar))
	game.prog.select_slot(bar.find("bucket"))
	for i in range(40):
		game.player.tool_view.equip(game.prog.model_tier())
		await physics_frame
	check(game.player.tool_view.model != null and game.player.tool_view.model.has_meta("fill"), "with it in hand you hold the Blender pail, its heap in a Fill holder")
	check(not game.hud.find_child("BagPlate", true, false).visible, "the bag badge is gone from the HUD")
	check(st.storage_capacity() >= 100, "the starter box holds 100 (%d)" % st.storage_capacity())
	# carrying
	for k in st.inventory.keys():
		st.inventory[k] = 0
	st.inventory["topsoil"] = 40
	check(st.buckets_carried() == 3, "40 units fill two buckets and part of a third (%d)" % st.buckets_carried())
	await frames(3)
	check(game.player.load_mult < 1.0 and game.player.load_mult > 0.8, "carrying them slows the walk a little (%.3f)" % game.player.load_mult)
	await frames(3)
	var fill: Node3D = game.player.tool_view.model.get_meta("fill")
	check(absf(fill.scale.y - lerpf(0.12, 1.0, 4.0 / 18.0)) < 0.02, "the heap in the pail shows the part-full bucket (%.2f)" % fill.scale.y)
	var qty: Label = game.hud.hotbar_view.find_child("Qty", true, false)
	check(qty != null and qty.text == "3", "the hotbar slot shows how many buckets are carried (%s)" % (qty.text if qty != null else "none"))
	# the box prompt
	var pr: String = game._storage_prompt()
	check(pr.contains("dump a bucket") and pr.contains("BOX:") and pr.contains("/ %d" % st.storage_capacity()), "aiming at the box says what it holds: '%s'" % pr)
	# dumping one bucket at a time
	var s0: int = st.total(st.storage)
	var m1: int = game.dump_bucket()
	check(m1 == 18 and st.total(st.storage) == s0 + 18 and st.inventory["topsoil"] == 22, "one dump moves one bucket (18) into the box")
	game.dump_bucket()
	var m3: int = game.dump_bucket()
	check(m3 == 4 and st.inventory["topsoil"] == 0, "the last, part-full bucket moves what it has (%d)" % m3)
	check(game._storage_prompt().contains("open the box"), "empty-handed, E opens the box menu")
	# pouring onto the ground puts the load back as loose material
	st.inventory["topsoil"] = 40
	var tvol: float = game.live_terrain.terrain.total_volume()
	var ground := Vector3(3.0, 0.0, -45.0)
	game.pour_at(ground)
	check(st.inventory["topsoil"] == 22 and absf(game.live_terrain.terrain.total_volume() - (tvol + 18.0 / 11.0)) < 0.01, "pouring a bucket on the ground puts 18 units back as %.3f m3 of loose topsoil" % (18.0 / 11.0))
	st.inventory["topsoil"] = 0
	# a full box refuses
	st.storage["topsoil"] = st.storage_capacity()
	st.inventory["topsoil"] = 18
	check(game.dump_bucket() == 0 and st.inventory["topsoil"] == 18, "a full box takes nothing and the load stays in the bucket")
	# the box feeds the hopper
	st.storage["topsoil"] = 30
	var h: int = game.business.cash_hopper_indices()[0]
	var money0: int = st.money
	for i in range(10):
		game.business.tick(1.0)
	check(st.total(st.storage) < 30 and (st.money > money0 or game.business.cash_queue(h) > 0), "the box empties into the Cash Hopper by itself (box %d, +$%d)" % [st.total(st.storage), st.money - money0])
	# conservation: nothing is lost between bucket, box and hopper
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
