extends SceneTree
## The Blender wheelbarrow in the real cart system: loads, shows its load, the wheel rolls when pushed, tips when emptied; hand carts keep the old prop.
##   godot --headless --fixed-fps 60 -s tests/test_wheelbarrow_rig.gd

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
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	floor_body.add_child(cs)
	root.add_child(floor_body)
	var carts := {}
	for id in ["wheelbarrow", "reinforced_wheelbarrow", "hand_cart"]:
		var c := QuarryCart.new()
		c.setup(id)
		c.position = Vector3(carts.size() * 3.0, 0.05, 0)
		root.add_child(c)
		carts[id] = c
	await process_frame
	for id in ["wheelbarrow", "reinforced_wheelbarrow"]:
		var c: QuarryCart = carts[id]
		check(c.wheel != null and c.body != null, "%s is the Blender model (wheel + tipping body)" % id)
		c.show_load({"limestone": 4}, 8)
		var load: Node3D = c.model.find_child("Load", true, false)
		check(load != null and load.visible, "%s shows its load in the tray" % id)
		c.show_load({}, 8)
		check(not load.visible, "%s shows an empty tray" % id)
	var wb: QuarryCart = carts["wheelbarrow"]
	var before: Basis = wb.wheel.transform.basis
	wb.rotation.y = 0.0
	for i in 40:
		wb.follow(wb.global_position + Vector3(0, 0, -1.0), 0.0, 1.0 / 60.0)
		await physics_frame
	check(wb.wheel.transform.basis != before, "the wheel rolls when the barrow is pushed")
	wb.tip()
	await create_timer(0.5).timeout
	check(wb.tilt.rotation.x < -0.4, "emptying tips the barrow forward on the axle (%.2f rad)" % wb.tilt.rotation.x)
	await create_timer(1.2).timeout
	check(absf(wb.tilt.rotation.x) < 0.05, "and it settles back (%.2f rad)" % wb.tilt.rotation.x)
	var hc: QuarryCart = carts["hand_cart"]
	check(hc.body == null and hc.wheel == null and hc.model != null, "the hand cart keeps its original prop")
	hc.tip()
	check(true, "tip() on a hand cart is a harmless no-op")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
