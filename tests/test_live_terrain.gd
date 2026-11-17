extends SceneTree
## Step 1 of the digging integration: the heightfield terrain is the live ground of the filled quarry. People walk on it, cut columns lower it, locks protect what is outside the
## marked excavation, and the formation columns remain the bookkeeping underneath.   godot --headless --fixed-fps 60 -s tests/test_live_terrain.gd

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

func ray_y(x: float, z: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 20.0, z), Vector3(x, -30.0, z))
	q.collision_mask = 1
	var r: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(q)
	return float(r["position"].y) if not r.is_empty() else -999.0

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.title_enabled = false
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(12)
	var lt: LiveTerrain = game.live_terrain
	check(lt != null and lt.terrain != null, "the filled quarry has a live terrain")
	if lt == null:
		quit(1)
		return
	print("attach took %.0f ms, %d vertices, %d collision blocks" % [lt.attach_ms, lt.terrain.V * lt.terrain.VR, lt.terrain.coll_shapes.size()])
	check(lt.attach_ms < 4000.0, "building it costs under 4 s (%.0f ms)" % lt.attach_ms)
	var t := lt.terrain
	check(absf(t.height_at(0.0, -50.0)) < 0.001 and absf(ray_y(0.0, -50.0)) < 0.01, "untouched, the ground is at 0 and people stand on it")
	var q_top = game.formation_nodes["q_top"]
	check(q_top.collision_layer == 32 and not q_top.skin_mi.visible, "the topsoil formation's colliders are on the rays-only layer and its skin is hidden")
	check(t.body.get_meta("ground", false), "the terrain body is marked as ground for placement and conveyors")
	check(t.is_locked_at(-115.0, -50.0) and t.is_locked_at(0.0, -12.5) and not t.is_locked_at(0.0, -50.0), "outside the marked excavation the ground is locked, inside it is not")
	lt.lock_structures()
	check(lt.locked_structures >= 1 and t.is_locked_at(9.0, -13.5), "placed structures (the storage box) lock the ground under them (%d footprints)" % lt.locked_structures)
	check(not t.is_locked_at(0.0, -50.0), "and the marked excavation stays open")
	# a cut column lowers the ground under it
	game.prog.cleanup["done"] = true
	var col: int = game.prog.cell_index_at("q_top", Vector3(0.0, 0.0, -50.0))
	var cp: Vector3 = game.prog.column_pos("q_top", col)
	game.prog.extract("q_top", col, 1.0e6, 1 << 30, "excavator")
	game.formation_nodes["q_top"].refresh()
	t.flush(true)
	await frames(4)
	var h := t.height_at(cp.x, cp.z)
	var below: float = game.prog.column_pos("q_a2_gravel", game.prog.cell_index_at("q_a2_gravel", cp)).y + 1.2
	check(absf(h - below) < 0.05 and h < -1.0, "cutting the topsoil column lowers the terrain to the gravel's top (%.2f vs %.2f)" % [h, below])
	check(absf(ray_y(cp.x, cp.z) - h) < 0.03, "and the collision follows (ray %.3f, height %.3f)" % [ray_y(cp.x, cp.z), h])
	check(t.top_material(t.idx(roundi((cp.x - t.origin.x) / 0.5), roundi((cp.z - t.origin.y) / 0.5))) == "gravel", "the new surface is gravel")
	# a body dropped above the hole lands on the new ground, not on the old column box
	var cb := CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	cs.shape = cap
	cb.add_child(cs)
	cb.collision_mask = 1
	cb.position = Vector3(cp.x, 3.0, cp.z)
	game.add_child(cb)
	for i in range(120):
		cb.velocity.y -= 9.8 / 60.0
		cb.move_and_slide()
		await physics_frame
	check(absf(cb.global_position.y - (h + 0.8)) < 0.25, "a body falls into the cut and stands on the gravel (y %.2f, ground %.2f)" % [cb.global_position.y, h])
	# loading a save with cut columns: simulate by lowering another column before a re-sync
	var col2: int = game.prog.cell_index_at("q_top", Vector3(8.0, 0.0, -50.0))
	var cp2: Vector3 = game.prog.column_pos("q_top", col2)
	game.prog.extract("q_top", col2, 1.0e6, 1 << 30, "excavator")
	lt.refresh_column("q_top", col2)
	t.flush(true)
	check(t.height_at(cp2.x, cp2.z) < -1.0, "a column already cut when the terrain is (re)synced is lowered too")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
