extends SceneTree
## Item thumbnails: made once from the real tool models and cached. With a display (run it windowed: godot --path . -s tests/test_item_thumbs.gd)
## every tool gets a picture with real content, each different, framed consistently; without one (the headless runner) nothing is rendered and the
## keys are reported as failed so the hotbar shows its labelled stand-in.

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

func run() -> void:
	var th := ItemThumbs.new()
	root.add_child(th)
	await process_frame
	var keys := []
	for k in ToolModels.LADDER.values():
		keys.append(str(k))
	for k in GearModels.IDS:
		keys.append(str(k))
	for k in keys:
		th.get_thumb("tool:" + k, func(): return ToolModels.load_tool(k))
	if DisplayServer.get_name() == "headless":
		await process_frame
		var all_failed := true
		for k in keys:
			all_failed = all_failed and th.failed.has("tool:" + k)
		check(all_failed and th.cache.is_empty(), "without a display nothing is rendered and every key is reported as failed (the hotbar shows labels)")
		print("RESULT: %d checks, %d failures" % [checks, failures.size()])
		quit(1 if failures.size() > 0 else 0)
		return
	var guard := 0
	while th.cache.size() + th.failed.size() < keys.size() and guard < 2000:
		await process_frame
		guard += 1
	check(th.failed.is_empty(), "every tool rendered (%d done, failed: %s)" % [th.cache.size(), str(th.failed.keys())])
	var sums := {}
	for k in th.cache:
		var img: Image = (th.cache[k] as ImageTexture).get_image()
		var n := 0
		var h := 0
		var minx := 999
		var maxx := -1
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				var c: Color = img.get_pixel(x, y)
				if c.a > 0.5:
					n += 1
					h = (h * 31 + int(c.r * 255) + 7 * int(c.g * 255) + 13 * int(c.b * 255) + x + 3 * y) % 1000003
					minx = mini(minx, x)
					maxx = maxi(maxx, x)
		check(n > 60 and n < img.get_width() * img.get_height() * 0.9, "%s: a picture with content (%d opaque pixels of %d)" % [k, n, img.get_width() * img.get_height()])
		check(maxx - minx > img.get_width() * 0.4, "%s: framed to fill the picture (spans %d of %d px)" % [k, maxx - minx, img.get_width()])
		sums[h] = true
	check(sums.size() == th.cache.size(), "every picture is different (%d distinct of %d)" % [sums.size(), th.cache.size()])
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
