extends SceneTree
## Renders one picture per machine/station and one per worker from the real game (needs a GL display,
## e.g. xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 -s tools/render_gallery.gd).
const OUT := "res://build/gallery/"
var game
var cam: Camera3D

func _initialize() -> void:
	call_deferred("run")

func settle(n := 4) -> void:
	for i in range(n):
		await process_frame
	await RenderingServer.frame_post_draw

func shot(name: String, pos: Vector3, target: Vector3, fov := 38.0) -> void:
	cam.fov = fov
	cam.look_at_from_position(pos, target, Vector3.UP)
	cam.current = true
	await settle()
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("saved ", name, " ", img.get_size())

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tutorial_visible = false
	game.ui.visible = false
	game.player.visible = false
	cam = Camera3D.new()
	cam.far = 200.0
	root.add_child(cam)
	game.state.money = 9000
	game.state.clock_minutes = 12.0 * 60.0
	game.business.payroll_minute = 720
	# --- machines and stations
	game.state.new_crusher(Vector3(3, 0, 5), 0.0)
	game._create_crusher(0)
	var oi: int = game.business.add_output(Vector3(-5, 0, 3), 0.0)
	game._create_output(oi)
	game.business.outputs[oi]["items"]["crushed_stone"] = 20
	var ci: int = game.business.add_conveyor(Vector3(-1.5, 0, 4), 0.0)
	game._create_conveyor(ci)
	game.business.conveyors[ci]["items"] = 2
	game.business.conveyors[ci]["resource"] = "limestone"
	game.business.conveyors[ci]["progress"] = 0.35
	game.state.storage["limestone"] = 26
	game.state.storage["coal"] = 6
	game.ui_hire("rosa"); game.ui_hire("tomas"); game.ui_hire("bram"); game.ui_hire("petra")
	for e in game.business.employees:
		game.business.set_shift(int(e["id"]), 1000, 1100)   # off shift: they idle instead of walking off
	for i in range(30):
		await physics_frame
	for w in game.worker_nodes.values():
		w.visible = false                                  # keep the machine pictures clean
	await shot("1_crusher_with_hopper", Vector3(6.4, 2.6, 1.5), Vector3(3, 0.9, 5.2))
	await shot("2_output_storage_bin", Vector3(-2.4, 2.4, 0.4), Vector3(-5, 0.6, 3), 40.0)
	await shot("3_conveyor_belt", Vector3(-4.2, 1.7, 1.6), Vector3(-1.5, 0.25, 4), 34.0)
	await shot("4_storage_bin", Vector3(7.2, 2.5, 6.6), Vector3(10, 0.7, 10), 40.0)
	await shot("5_sales_booth_cash_register", Vector3(-4.6, 2.2, 5.6), Vector3(-7, 1.0, 10), 40.0)
	await shot("6_machinery_order_kiosk", Vector3(-3.4, 2.9, 6.6), Vector3(-2, 1.1, 10), 38.0)
	# --- workers: one per profession, posed standing, one at a time on an open spot
	game.set_physics_process(false)
	var stage := Vector3(-3, 0.05, 4.5)
	var names := {"miner": "7_worker_miner", "operator": "8_worker_machine_operator", "hauler": "9_worker_hauler", "clerk": "10_worker_sales_clerk"}
	for e in game.business.employees:
		for other in game.worker_nodes.values():
			other.visible = false
		var w = game.worker_nodes[int(e["id"])]
		w.visible = true
		w.global_position = stage
		w.rotation.y = 0.0
		w.facing = 0.0
		for i in range(40):
			w.rig.pose(0.05, "idle", 0.0, w.profession, false)
		await shot(names[w.profession], stage + Vector3(0.9, 1.25, -3.3), stage + Vector3(0, 0.95, 0), 30.0)
	quit()
