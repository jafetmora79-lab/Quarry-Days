extends SceneTree
## The three hauling tools are three different Blender models: the wheelbarrow, the clearly sturdier reinforced wheelbarrow, and the two-wheeled hand cart. Each turns
## its wheel(s) with the distance rolled, tips about its axle, carries a load pile in its tray, and the push carts show the player's gloved hands on the handle grips.
##   godot --headless --fixed-fps 60 -s tests/test_cart_models.gd

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

func aabb_of(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var b: AABB = m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

func run() -> void:
	var sizes := {}
	var counts := {}
	for id in ["wheelbarrow", "reinforced_wheelbarrow", "hand_cart"]:
		var c := QuarryCart.new()
		root.add_child(c)
		c.setup(id)
		await process_frame
		check(c.model != null and str(c.model.name) == "Gear_" + id and ResourceLoader.exists(QuarryCart.CART_GLBS[id]), "%s: the Blender model is used" % id)
		var want_wheels := 2 if id == "hand_cart" else 1
		check(c.wheels.size() == want_wheels, "%s: %d wheel(s) (%d)" % [id, want_wheels, c.wheels.size()])
		check(c.model.get_node_or_null("Load") != null, "%s: it has its load pile" % id)
		var box := aabb_of(c.model)
		sizes[id] = box.size
		counts[id] = c.model.find_children("*", "MeshInstance3D", true, false).size()
		check(box.size.x > 0.6 and box.size.z > 1.4 and box.size.y > 0.6 and box.size.y < 1.6, "%s: cart-sized (%s)" % [id, str(box.size.snapped(Vector3(0.01, 0.01, 0.01)))])
		# wheels turn with the distance rolled
		var r0 := c.rolled_total
		var start := c.global_position
		for i in 30:
			c.follow(start + Vector3(0, 0, -0.1 * float(i + 1)), 0.0, 1.0 / 60.0)
			await physics_frame
		var moved := start.distance_to(c.global_position)
		check(moved > 0.3 and absf(c.rolled_total - r0) > 0.3, "%s: the wheels turn as it rolls (%.2f m, %.2f rad)" % [id, moved, c.rolled_total - r0])
		# the gloved hands on the handles
		c.held = true
		c._animate(1.0 / 60.0)
		if id == "hand_cart":
			check(c.grip_hands == null, "%s: it is pulled from the bar, no hands on handles" % id)
		else:
			var gloves := c.grip_hands.find_children("Hand_*", "Node3D", true, false) if c.grip_hands != null else []
			check(c.grip_hands != null and c.grip_hands.visible and gloves.size() == 2, "%s: both gloved hands are on the handle grips while held (%d)" % [id, gloves.size()])
		c.held = false
		# it tips about the axle and settles again
		c.tip()
		var lowest := 0.0
		for i in 140:
			c._animate(1.0 / 60.0)
			lowest = minf(lowest, c.tilt.rotation.x)
		check(lowest < -0.3, "%s: it tips forward about the axle (%.2f rad)" % [id, lowest])
		for i in 60:
			c._animate(1.0 / 60.0)
		check(absf(c.tilt.rotation.x) < 0.05, "%s: and comes back level" % id)
		c.queue_free()
	# (the Meshy carts are one mesh each, so "parts" no longer tell the barrows apart: the reinforced one is the bigger, and the hand cart is the two-wheeled build)
	var vol := func(v: Vector3) -> float: return v.x * v.y * v.z
	check(vol.call(sizes["reinforced_wheelbarrow"]) > vol.call(sizes["wheelbarrow"]) and sizes["reinforced_wheelbarrow"].x > sizes["wheelbarrow"].x, "the reinforced barrow is wider and bigger than the basic one (%.2f vs %.2f m wide)" % [sizes["reinforced_wheelbarrow"].x, sizes["wheelbarrow"].x])
	check(sizes["hand_cart"].x > sizes["wheelbarrow"].x + 0.05 and sizes["hand_cart"].z > 1.2, "the hand cart is its own, wider two-wheeled build (%.2f m wide, %.2f long)" % [sizes["hand_cart"].x, sizes["hand_cart"].z])
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
