extends SceneTree
## Dev tool: the permit excavation in the main yard. ASCII height map in world coordinates.
const OFF := Vector2(0.37, 0.41)

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in range(n):
		await physics_frame

func gy(game, x: float, z: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 8.0, z), Vector3(x, -30.0, z), 1)
	var h: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(q)
	return -99.0 if h.is_empty() else float(h["position"].y)

func code(y: float) -> String:
	if y < -90.0: return "#"
	if absf(y) < 0.12: return "0"
	if absf(y + 3.5) < 0.12: return "L"
	if y > 0.12: return "^"
	return "~"

func dump(game, label: String, x0: float, x1: float, z0: float, z1: float) -> void:
	print("== ", label)
	var z := z0
	while z <= z1:
		var row := ""
		var x := x0
		while x <= x1:
			row += code(gy(game, x + OFF.x, z + OFF.y))
			x += 1.0
		print("z%4.0f %s" % [z, row])
		z += 1.0

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	await frames(2)
	print("excavation exists: ", game.get("excavation") != null)
	dump(game, "closed", -9, 12, -22, -3)
	game.state.money = 99999
	game.prog.stage = 5
	print("buy_permit -> ", game.buy_permit())
	await frames(10)
	dump(game, "open", -9, 12, -22, -3)
	quit(0)
