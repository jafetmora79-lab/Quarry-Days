extends SceneTree
## Exports the game's procedurally built models (vehicles, tools, carts, props, repair parts) to glTF binaries for the
## asset preview page.   godot --headless -s tools/export_procedural_models.gd -- docs/models/procedural
## Writes <dir>/<category>__<name>.glb for each model.

var out_dir := "docs/models/procedural"

func _initialize() -> void:
	call_deferred("run")

func save(node: Node3D, category: String, name: String) -> void:
	root.add_child(node)
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_scene(node, st)
	if err == OK:
		err = doc.write_to_filesystem(st, "%s/%s__%s.glb" % [out_dir, category, name])
	print("%s %s/%s" % ["ok  " if err == OK else "FAIL", category, name])
	node.queue_free()

func vehicle(kind: String) -> Node3D:
	var pv := QuarryPreview.PreviewVehicle.new()
	pv.model_root = Node3D.new()
	pv.add_child(pv.model_root)
	match kind:
		"loader": VehicleModels.loader(pv)
		"excavator": VehicleModels.excavator(pv)
		_: VehicleModels.truck(pv)
	pv.name = kind
	return pv

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
	for k in ["loader", "excavator", "truck"]:
		save(vehicle(k), "vehicles", k)
	for id in cfg["gear"]:
		var g: Dictionary = cfg["gear"][id]
		var kind := str(g.get("kind", ""))
		var n: Node3D = null
		if kind == "cart" or id in ["hand_cart", "wheelbarrow", "reinforced_wheelbarrow", "air_compressor"]:
			n = GearModels.build_prop(id)
			save(n, "carts_and_props", id)
		else:
			n = GearModels.build_tool(id)
			save(n, "tools", id)
	for t in range(1, 4):
		save(GearModels.build_ladder(t), "tools", "ladder_%d" % t)
	for id in ["battery", "hose", "fuel"]:
		save(OpeningModels.part(id), "repair_parts", id)
	quit()
