extends SceneTree
## Wheelbarrows and hand carts: wheels turn with the distance rolled (and not when still), the body leans into turns, the load stays in the tray, and
## unloading at the crate tips the barrow forward over its wheel and back. The transfer itself is the existing state logic.
##   godot --headless --fixed-fps 60 -s tests/test_cart_motion.gd
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
	for id in ["wheelbarrow", "reinforced_wheelbarrow", "hand_cart"]:
		var c := QuarryCart.new()
		c.setup(id)
		root.add_child(c)
		await frames(2)
		check(c.wheels.size() == (2 if id == "hand_cart" else 1), "%s has its turning wheel(s) (%d)" % [id, c.wheels.size()])
		var r0: float = c.rolled_total
		var floor_y := c.global_position.y
		for k in range(30):
			c.follow(c.global_position + Vector3(0, 0, -1.0), 0.0, 1.0 / 60.0)    # rolling forward (-Z)
			await physics_frame
		var rolled: float = c.rolled_total - r0
		var dist: float = absf(c.global_position.z)
		var radius: float = float(c.wheels[0].get_meta("radius"))
		check(rolled < 0.0 and absf(absf(rolled) * radius - dist) < dist * 0.25 + 0.1, "%s: the wheel turns the way it rolls, by the distance travelled (%.2f rad over %.2f m)" % [id, rolled, dist])
		var r1: float = (c.wheels[0] as Node3D).rotation.x
		c.velocity = Vector3.ZERO
		await frames(20)
		check(absf((c.wheels[0] as Node3D).rotation.x - r1) < 0.02, "%s: standing still, the wheel stands still" % id)
		# a hard turn leans the body
		var peak := 0.0
		for k in range(40):
			c.follow(c.global_position + Vector3(2.0, 0, -2.0), float(k) * 0.08, 1.0 / 60.0)
			peak = maxf(peak, absf(c.tilt.rotation.z))
			await physics_frame
		check(peak > 0.005 and peak <= 0.091, "%s: the body leans into a turn (%.3f rad)" % [id, peak])
		# tipping
		c.velocity = Vector3.ZERO
		await frames(40)
		c.show_load({"limestone": 20}, 40)
		var load_node: Node3D = c.model.get_node("Load")
		check(load_node.visible, "%s: the load sits in the tray" % id)
		c.tip()
		var deepest := 0.0
		var slid := 0.0
		for k in range(int(c.TIP_TIME * 60.0) + 30):
			await physics_frame
			deepest = minf(deepest, c.tilt.rotation.x)
			slid = minf(slid, load_node.position.z - float(load_node.get_meta("rest_z", load_node.position.z)))
		check(deepest < -0.5, "%s: unloading tips the barrow forward over the wheel (%.2f rad)" % [id, deepest])
		check(absf(c.tilt.rotation.x) < 0.05 and c.tip_t == 0.0, "%s: and it comes back level" % id)
		c.queue_free()
		await process_frame
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
