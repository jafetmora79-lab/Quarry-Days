extends SceneTree
## Heaps look like what they are made of: soil a smooth cone, rock a mound of chunks, ore a mound with its mineral showing; the terrain draws loose rock rough and loose soil smooth.
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
func tris(m: ArrayMesh) -> int:
	return m.surface_get_array_len(0) / 3
func run() -> void:
	check(PileModels.kind_of("topsoil") == "dirt" and PileModels.kind_of("limestone") == "rock" and PileModels.kind_of("gold_ore") == "ore", "each resource lies as its own kind of heap")
	var d := PileModels.dirt_mesh(3.0, 2.0, 5)
	var bb := d.get_aabb()
	check(absf(bb.size.y - 2.0) < 0.6 and bb.size.x > 5.0 and bb.size.x < 8.5, "a dirt heap is a broad cone (%.1f wide, %.1f high)" % [bb.size.x, bb.size.y])
	var r := PileModels.rock_mesh(1.5, 1.0, 5)
	check(tris(r) > 5 * tris(d) / 2 or tris(r) > 400, "a rock heap is built from many chunks (%d triangles against %d for the soil cone)" % [tris(r), tris(d)])
	check(r.get_aabb().size.y > 0.6 and r.get_aabb().size.y < 1.9, "and stays heap-sized (%.2f m high)" % r.get_aabb().size.y)
	var o := PileModels.ore_mesh(1.5, 1.0, 5)
	check(tris(o) > 20, "ore adds mineral chunks on the surface")
	var h := PileModels.heap("ore", 1.5, 1.0, 5, "RockIron", Color(0.9, 0.5, 0.3))
	check(h.get_child_count() == 2, "an ore heap is stone plus mineral")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
