extends SceneTree
## Ctrl crouches: the eyes sink, the body shrinks and slows, and the player stays down under a low ceiling.
var fails := 0
func ok(c: bool, m: String) -> void:
	if not c:
		fails += 1
		print("FAIL: ", m)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var floor_body := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var fb := BoxShape3D.new()
	fb.size = Vector3(40, 1, 40)
	fs.shape = fb
	floor_body.add_child(fs)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	var p := QuarryPlayer.new()
	root.add_child(p)
	for i in 10: await physics_frame
	var stand_y := p.camera.position.y
	Input.action_press("crouch")
	for i in 40: await physics_frame
	ok(p.crouching and p.camera.position.y < stand_y - 0.5, "crouching lowers the eyes (%.2f -> %.2f)" % [stand_y, p.camera.position.y])
	ok(p._capsule.height < 1.3, "the body shrinks")
	# a low ceiling keeps the player down
	var ceil_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cb := BoxShape3D.new()
	cb.size = Vector3(10, 0.5, 10)
	cs.shape = cb
	ceil_body.add_child(cs)
	ceil_body.position.y = 1.6
	root.add_child(ceil_body)
	Input.action_release("crouch")
	for i in 40: await physics_frame
	ok(p.crouching, "stays crouched under a low ceiling")
	ceil_body.queue_free()
	for i in 40: await physics_frame
	ok(not p.crouching and absf(p.camera.position.y - stand_y) < 0.01, "stands up when there is room")
	print("RESULT: %d checks, %d failures" % [4, fails])
	quit(1 if fails > 0 else 0)
