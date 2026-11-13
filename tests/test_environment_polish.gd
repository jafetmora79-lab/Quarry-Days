extends SceneTree
## Current integrated blueprint world: physical routes, represented boundaries, shop and motion. No renders.
var checks := 0
var failures: Array = []
var game

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		printerr("FAIL: " + text)
	else:
		print("PASS: " + text)

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in range(n): await physics_frame

func walk(route: Array, label: String) -> bool:
	var p: QuarryPlayer = game.player
	for wp in route:
		var destination := Vector3(wp.x, p.global_position.y, wp.y)
		var t := 0
		while t < 1100:
			var d := Vector3(destination.x - p.global_position.x, 0, destination.z - p.global_position.z)
			if d.length() < .3: break
			p.drive_wish = d
			await physics_frame
			t += 1
		p.drive_wish = Vector3.ZERO
		if t >= 1100:
			printerr("Route %s blocked at %s toward %s" % [label, p.global_position, wp])
			return false
	p.drive_wish = Vector3.INF
	return true

func ray(a: Vector3, b: Vector3) -> Dictionary:
	return game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1))

func run() -> void:
	for path in ["user://quarry_save.json", "user://quarry_save.bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await frames(8)
	for i in range(6):
		if game.walter_dialog: game.walter_dialog.skip()
		await frames(20)
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	game.safety.enabled = false
	game.player.locked = false
	game.player.blueprint.hide()
	check(game.blueprint and game.prog.cfg["stages"].size() == 12 and game.prog.levels().size() == 5, "integrated blueprint, twelve stages, surface plus four dug levels retained")
	check(game.HOME_POS == Vector3(17.625, 0, 17.5) and game.OFFICE_POS == Vector3(13.125, 0, 3.5) and game.GARAGE_DX == -8, "facility locations retained")
	for door in game.doors:
		door.want_open = true
	await frames(90)
	var hc: Vector3 = game.HOME_POS
	# Garden fence: all edges except the wide front opening collide, including corners.
	for offset in [Vector3(-3.5, .7, 0), Vector3(3.5, .7, 0), Vector3(0, .7, 3.5), Vector3(-2.5, .7, -2.6), Vector3(2.5, .7, -2.6)]:
		var c: Vector3 = hc + offset
		var d := Vector3(.6, 0, 0) if absf(offset.x) == 3.5 else Vector3(0, 0, .6)
		check(not ray(c - d, c + d).is_empty(), "home garden fence solid at %s" % offset)
	check(ray(hc + Vector3(0, .9, -3.2), hc + Vector3(0, .9, -2.3)).is_empty(), "home garden entrance is open and aligned with doorway")
	# Actual controller walks, not just point-to-point ray visibility.
	game.player.global_position = hc + Vector3(0, .25, -.6)
	game.player.velocity = Vector3.ZERO
	await frames(15)
	check(await walk([Vector2(hc.x, hc.z - 4.4), Vector2(hc.x, 11.5), Vector2(hc.x, -.2), Vector2(13.125, -.2), Vector2(13.125, 3.5)], "Home to office"), "player exits home/garden and enters office")
	check(await walk([Vector2(13.125, -.2), Vector2(0, -.2), Vector2(-17.125, -.2), Vector2(-17.125, 3.5)], "Office to workshop"), "office to workshop is traversable")
	check(await walk([Vector2(-17.125, -.2), Vector2(-19.5, -.2), Vector2(-19.5, 11.5), Vector2(-19.5, 25.4), Vector2(-15.0, 25.4)], "Workshop to garage/service lane"), "workshop to garage/service tunnel approach is traversable")
	# The service shutter is deliberately automatic, never remove it as an 'invisible wall'.
	game.delivery.set_physics_process(false)
	game.delivery.open_amount = 1.0
	game.delivery.body.get_child(0).disabled = true
	game.delivery.body.collision_layer = 0
	check(await walk([Vector2(-24, 25.4), Vector2(-32, 25.4)], "Open tunnel"), "open service tunnel is traversable")
	game.delivery.body.collision_layer = 1
	game.delivery.body.get_child(0).disabled = false
	await frames(2)
	check(not ray(Vector3(-25, 1, 25.4), Vector3(-27, 1, 25.4)).is_empty(), "closed tunnel shutter remains solid")
	game.player.global_position = Vector3(0, .25, 3)
	game.player.velocity = Vector3.ZERO
	await frames(10)
	check(await walk([Vector2(0, -8), Vector2(0, -16)], "Yard to Area 1"), "yard gate and starter quarry entrance are traversable")
	# Solid house walls remain solid; the controller cannot use mantle to cross them.
	check(not ray(hc + Vector3(1.8, 1, 0), hc + Vector3(3, 1, 0)).is_empty(), "solid house wall blocks movement")
	for x in [-200.0, 200.0]:
		check(not ray(Vector3(x - .5, 1, 35), Vector3(x + .5, 1, 35)).is_empty(), "visible property fence collision x=%d" % x)
		check(ray(Vector3(x - .5, 4, 35), Vector3(x + .5, 4, 35)).is_empty(), "no invisible nine-metre wall above property fence x=%d" % x)
	game._rebake_nav()
	await frames(12)
	for destination in [game.TOOLSHED_POS + Vector3(0, .16, .6), game.OFFICE_POS + Vector3(0, .16, .6), hc + Vector3(0, .16, -.6)]:
		var path: PackedVector3Array = NavigationServer3D.map_get_path(game.nav_map, Vector3(-18, 0, 25.4), destination, true)
		check(not path.is_empty() and Vector2(path[-1].x - destination.x, path[-1].z - destination.z).length() < .85, "worker nav connects service lane to %s" % destination)
	# Station selection uses the original E-interaction and purchase preview/confirmation.
	var shops: Array = []
	for body in game.world.get_children():
		if str(body.get_meta("kind", "")) == "shop": shops.append(body)
	check(shops.size() == 1, "one restored machinery ordering station, no competing shop")
	var station: Vector3 = game.machinery_station_position()
	game.player.global_position = station + Vector3(0, .2, -1.8)
	game.player.rotation.y = PI
	game.player.pitch = -.25
	game.player.camera.rotation.x = -.25
	game.player.velocity = Vector3.ZERO
	await frames(4)
	var target = game._look_target()
	check(target != null and str(target.get_meta("kind", "")) == "shop", "terminal is in reach of real interaction ray")
	game._interact(shops[0])
	await frames(4)
	check(game.menu == "shop" and game.panel.pane.visible, "E opens existing machinery shop with 3D preview")
	game.prog.stage = 11
	game.state.money = 100000
	game._draw_menu()
	await frames(3)
	var before: int = game.state.money
	var stock: int = game.business.inventory.get("crusher", 0)
	var price: int = game._placement_price("crusher")
	game.panel.pane.buy_btn.pressed.emit()
	await frames(4)
	check(game.state.money == before - price and game.business.inventory.get("crusher", 0) == stock + 1, "machinery confirmation charges exactly once and delivers to existing construction inventory")
	game._close_menu()
	# Exercise a real blueprint-world service delivery, not finish_all() teleportation.
	game.delivery.set_physics_process(true)
	game.delivery.open_amount = 0.0
	game.prog.cleanup["done"] = true
	game.business.milestones["mechanized"] = true
	game.business.milestones["automated"] = true
	var delivered_before: int = game.delivery.delivered
	var money_before_vehicle: int = game.state.money
	var vehicle_price: int = game.fleet.spec("loader")["price"]
	var order: String = game.ui_buy_vehicle("loader")
	check(game.delivery.jobs.size() == 1 and order.contains("being driven in"), "blueprint service-tunnel vehicle delivery starts")
	check(game.state.money == money_before_vehicle - vehicle_price, "vehicle order charges its existing price once")
	if not game.delivery.jobs.is_empty():
		var v = game.delivery.jobs[0]["vehicle"]
		var slot: Vector3 = game.delivery.jobs[0]["slot"]
		var opened := false
		for i in range(2400):
			opened = opened or game.delivery.is_open()
			if game.delivery.jobs.is_empty(): break
			await physics_frame
		check(opened and game.delivery.delivered == delivered_before + 1 and game.delivery.jobs.is_empty(), "real west shutter opens and delivery driver completes return route")
		check(v.global_position.distance_to(slot) < .5 and v.collision_layer == 8, "delivered loader occupies its original bay with normal collision")
		game.enter_vehicle(v)
		check(game.driving == v, "delivered vehicle can be entered")
		game.scripted_input = true
		for i in range(400):
			if v.global_position.z < 12.5: break
			v.input = {"throttle": .7, "steer": 0.0, "brake": false}
			await physics_frame
		check(v.global_position.z < 12.5, "loader drives out of its bay between solid garage columns")
		v.input = {"throttle": 0.0, "steer": 0.0, "brake": true}
		await frames(90)
		check(game.exit_vehicle(), "delivered vehicle can be exited after braking")
		game.scripted_input = false
		await frames(5)
	# Controller speed under actual physics, followed by braking and carrying multiplier.
	game.set_physics_process(false) # isolate controller from automatic cart-release bookkeeping
	game.player.global_position = Vector3(50, .25, 40)
	game.player.velocity = Vector3.ZERO
	game.player.drive_wish = Vector3(0, 0, 1)
	game.player.locked = false
	await frames(70)
	check(absf(Vector2(game.player.velocity.x, game.player.velocity.z).length() - 5.25) < .02, "walking is 5.25 m/s (+25%)")
	Input.action_press("sprint")
	await frames(70)
	check(absf(Vector2(game.player.velocity.x, game.player.velocity.z).length() - 7.5) < .02, "sprint is 7.5 m/s (+25%), including directed/controller input")
	Input.action_release("sprint")
	game.player.drive_wish = Vector3.ZERO
	await frames(30)
	check(Vector2(game.player.velocity.x, game.player.velocity.z).length() < .01, "smooth braking reaches rest")
	game.player.speed_mult = .8
	game.player.drive_wish = Vector3(1, 0, 0)
	await frames(60)
	check(absf(Vector2(game.player.velocity.x, game.player.velocity.z).length() - 4.2) < .02, "existing cart/carry movement multiplier retained")
	game.player.drive_wish = Vector3.INF
	game.player.speed_mult = 1.0
	check(game.art.root.find_child("NorthRange0", true, false) != null and game.art.root.find_child("TunnelMountain", true, false) != null, "continuous mountain and matching tunnel hillside geometry exists")
	check(game.world.get_node_or_null("Visible tunnel hillside") != null and game.world.get_node_or_null("Tunnel mountain") == null, "hidden rectangular mountain blockers replaced by collision from the visible mesh")
	for key in ["Asphalt", "Gravel", "Siding", "Metal", "Roof", "Trim", "Concrete", "Soil", "Grass"]:
		var m = load("res://assets/environment/M_%s.tres" % key)
		check(m != null and m.albedo_texture.get_width() == 256, "original restrained %s texture imported" % key)
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	game.free()
	await process_frame
	quit(1 if failures.size() > 0 else 0)
