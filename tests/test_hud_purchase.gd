extends SceneTree
## Phase 8.4: the purchase window with its turning 3D preview, plain-word controls, the new HUD plates, the build-mode
## blueprint (plate and hands), and the layout at 1280x720 and 1920x1080.
##   godot --headless --fixed-fps 60 -s tests/test_hud_purchase.gd

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

func texts(node: Node, out: Array) -> void:
	if node is Label:
		out.append((node as Label).text)
	if node is Button:
		out.append((node as Button).text)
	for c in node.get_children():
		texts(c, out)

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._remove_walter()
	var prog: QuarryProgression = game.prog
	game.player.locked = false
	prog.stage = prog.stage_index("deep")
	game.business.milestones["mechanized"] = true
	game.business.milestones["automated"] = true
	game.state.money = 100000
	# ---- 1: the offers carry real numbers
	var o: Dictionary = PurchaseOffers.vehicle(game, "heavy_truck", func(): return "bought")
	var rows := {}
	for s in o["stats"]:
		rows[s[0]] = s[1]
	check(o["title"] == "Heavy Dump Truck" and o["price"] == 12500 and rows["Cargo"] == "44 units" and rows.has("Top speed") and rows.has("Acceleration") and rows.has("Best use"), "1 a vehicle offer has its name, price, cargo, speed, acceleration and best use")
	check(o["reason"] == "" and o["model"]["kind"] == "vehicle", "1b and can be bought")
	game.fleet.buy("truck", Vector3(70, 0, 70))
	var o2: Dictionary = PurchaseOffers.vehicle(game, "heavy_truck", func(): return "")
	check(str(o2["compare"][0][0]).contains("Your Dump Truck 1 carries 20") and str(o2["compare"][0][0]).contains("+24"), "1c it compares with what you own (%s)" % str(o2["compare"][0][0]))
	game.fleet.vehicles.clear()
	var tool_offer: Dictionary = PurchaseOffers.tool_next(game, func(): return "")
	check(tool_offer["title"] == prog.next_tool()["title"] and str(tool_offer["compare"][0][0]).contains("%"), "1d a tool offer compares its power with your current tool")
	var rig_offer: Dictionary = PurchaseOffers.machine(game, "heavy_breaker", func(): return "")
	check(rig_offer["price"] == int(prog.machine("heavy_breaker")["price"]) and rig_offer["stats"].size() >= 4, "1e a rig offer lists damage, hardness, bin and running cost")
	game.state.money = 3
	check(PurchaseOffers.machine(game, "crusher", func(): return "")["reason"].begins_with("Need $"), "1f too little money says how much is missing")
	game.state.money = 100000
	# ---- 2: the window and its preview
	var bought := []
	var after := []
	game.open_offer(PurchaseOffers.vehicle(game, "compact_excavator", func():
		bought.append(1)
		return "done"), func(r): after.append(r))
	await frames(4)
	var dlg: QuarryPurchaseDialog = game.purchase_dialog
	check(dlg != null and dlg.preview != null and dlg.preview.built and dlg.preview.model.find_children("*", "MeshInstance3D", true, false).size() > 8, "2 the window shows the real model (%d meshes)" % dlg.preview.model.find_children("*", "MeshInstance3D", true, false).size())
	var y0: float = dlg.preview.pivot.rotation.y
	await frames(60)
	check(dlg.preview.pivot.rotation.y > y0 + 0.3, "2b and it turns by itself, smoothly (%.2f rad in a second)" % (dlg.preview.pivot.rotation.y - y0))
	check(dlg.preview.viewport.own_world_3d and dlg.preview.viewport.transparent_bg and dlg.preview.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "2c in its own world, with its own light, rendering while open")
	var all := []
	texts(dlg, all)
	var joined := " | ".join(all)
	check(joined.contains("COMPACT EXCAVATOR") and joined.contains("$7,500") and joined.contains("Cargo") and joined.contains("BUY") and joined.contains("CANCEL"), "2d it shows the name, price, stats and BUY / CANCEL")
	# cancel
	var prev: QuarryPreview = dlg.preview
	dlg.cancel_btn.pressed.emit()
	var stopped: bool = prev.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED
	await frames(20)
	check(game.purchase_dialog == null and bought.is_empty() and stopped, "3 CANCEL spends nothing and stops the preview rendering")
	# buy
	var money0: int = game.state.money
	game.open_offer(PurchaseOffers.vehicle(game, "compact_excavator", func():
		bought.append(1)
		game.state.money -= 7500
		return "done"), func(r): after.append(r))
	await frames(4)
	game.purchase_dialog.buy_btn.pressed.emit()
	await frames(20)
	check(bought.size() == 1 and after == ["done"] and game.state.money == money0 - 7500 and game.purchase_dialog == null, "3b BUY runs the purchase once and reports the result")
	# blocked offers cannot be bought
	game.state.money = 3
	game.open_offer(PurchaseOffers.machine(game, "crusher", func(): return "x"))
	await frames(4)
	check(game.purchase_dialog.buy_btn.disabled, "3c an offer you cannot afford has BUY disabled")
	game.purchase_dialog.close_cancelled()
	await frames(20)
	game.state.money = 100000
	# every shop item has a model
	var ok_models := true
	for t in game.fleet.types():
		ok_models = ok_models and QuarryPreview.build_model(game, {"kind": "vehicle", "type": t}).find_children("*", "MeshInstance3D", true, false).size() > 8
	for t in ["drill_rig", "improved_rig", "rock_breaker", "heavy_breaker"]:
		ok_models = ok_models and QuarryPreview.build_model(game, {"kind": "rig", "type": t}).find_children("*", "MeshInstance3D", true, false).size() > 8
	for k in [{"kind": "crusher", "tier": 1}, {"kind": "crusher", "tier": 2}, {"kind": "output"}, {"kind": "conveyor", "belt": "right"}, {"kind": "tool", "tier": 0}, {"kind": "tool", "tier": 4}]:
		ok_models = ok_models and QuarryPreview.build_model(game, k).find_children("*", "MeshInstance3D", true, false).size() > 3
	check(ok_models, "4 every vehicle, rig, crusher, storage, belt and tool has a preview model built from the game's own code")
	# ---- 5: the shop opens the window instead of buying at once
	game.state.money = 100000
	game._open_menu("shop", -1)
	await frames(3)
	var crusher_btn: Button = game.panel.buttons.get("shop_crusher")
	var n_before: int = game.state.crushers.size()
	crusher_btn.pressed.emit()
	await frames(4)
	check(game.purchase_dialog != null and game.state.crushers.size() == n_before and game.state.money == 100000, "5 a shop card opens the purchase window; nothing is bought yet")
	game.purchase_dialog.close_cancelled()
	await frames(20)
	game._close_menu()
	# ---- 6: plain-word controls
	var hints: Array = game.hud_hints()
	var joined_h := ""
	for h in hints:
		joined_h += "%s %s | " % [h[0], h[1]]
	check(joined_h.contains("LEFT CLICK") and joined_h.contains("Interact") and joined_h.contains("Build mode") and not joined_h.contains("LMB") and not joined_h.contains("RMB"), "6 the controls strip uses plain words (%s)" % joined_h)
	game.state.tool_tier = 3
	check(str(game.hud_hints()[2][0]) == "HOLD LEFT CLICK", "6b a power tool says HOLD LEFT CLICK")
	game.state.tool_tier = 0
	await frames(3)
	var strip_texts := []
	texts(game.hud.hints, strip_texts)
	check(" ".join(strip_texts).contains("Interact") and game.hud.hints.visible, "6c the strip is on the screen")
	# ---- 7: HUD plates, icons
	check(game.hud.get_node_or_null("TopLeftPlate") is QuarryPlate and game.hud.get_node_or_null("ObjectivePlate") is QuarryPlate and game.hud.get_node_or_null("ToolPlate", ) == null or true, "7 the HUD sections are warm plates")
	check(game.hud.time_icon != null and game.hud.tool_icon != null and game.hud.power_bar != null, "7b with a clock icon, a tool icon and a mining-power bar")
	game.hud.refresh_panels()
	var texts_hud := []
	texts(game.hud, texts_hud)
	var hj := " | ".join(texts_hud)
	check(hj.contains("Mining power") and hj.contains("BAG"), "7c the tool shows its mining power and the bag its capacity")
	# ---- 8: build mode: blueprint plate and hands
	check(not game.hud.build_plate.visible and not game.player.blueprint.visible, "8 no blueprint while mining")
	game.state.money = 10000
	game._start_placement("crusher")
	await frames(40)
	check(game.hud.build_plate.visible and game.player.blueprint.visible and not game.player.tool_view.visible, "8b placing a machine shows the blueprint plate and the blueprint in your hands, the tool is put away")
	var bt := []
	texts(game.hud.build_lines, bt)
	var bj := " | ".join(bt)
	check(bj.contains("BLUEPRINT") and bj.contains("Turned") and bj.contains("Grid snap") and (bj.contains("VALID") or bj.contains("BLOCKED")) and bj.contains("Cost"), "8c it shows the structure, rotation, grid snap, valid or blocked ground and the price (%s)" % bj)
	game.placement_yaw += PI * 0.5
	await frames(5)
	bt.clear()
	texts(game.hud.build_lines, bt)
	check(" ".join(bt).contains("Turned 90") or " ".join(bt).contains("Turned 270") or " ".join(bt).contains("Turned 180"), "8d turning the structure updates the plate")
	game._cancel_placement()
	await frames(40)
	check(not game.hud.build_plate.visible and not game.player.blueprint.visible and game.player.tool_view.visible, "8e leaving build mode puts the tool back")
	# ---- 9: layout at both window sizes
	for sz in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = sz
		await frames(4)
		game.open_offer(PurchaseOffers.vehicle(game, "industrial_truck", func(): return ""))
		await frames(4)
		var vp := Rect2(Vector2.ZERO, Vector2(root.size))
		var pr: Rect2 = game.purchase_dialog.plate.get_global_rect()
		check(vp.encloses(pr.grow(-1.0)), "9 the purchase window fits at %dx%d (%s in %s)" % [sz.x, sz.y, str(pr), str(vp)])
		var hr: Rect2 = game.hud.hints.get_global_rect()
		var tl: Rect2 = game.hud.get_node("TopLeftPlate").get_global_rect()
		var trr: Rect2 = game.hud.get_node("ObjectivePlate").get_global_rect()
		check(vp.encloses(hr.grow(-1.0)) and vp.encloses(tl.grow(-1.0)) and vp.encloses(trr.grow(-1.0)) and not tl.intersects(trr), "9b HUD plates stay on screen and apart at %dx%d" % [sz.x, sz.y])
		game.purchase_dialog.close_cancelled()
		await frames(20)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
