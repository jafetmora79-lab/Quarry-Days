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

## A bare stand-in for the game node: just what the building and machine builders read.
class Stub extends Node:
	var OFFICE_POS := Vector3.ZERO
	var SHED_POS := Vector3.ZERO
	var HOME_POS := Vector3.ZERO
	var world: Node3D
	func in_hillside_zone(_p: Vector3, _m := 0.0) -> bool:
		return false

func art_instance() -> QuarryArt:
	var a := QuarryArt.new()
	var st := Stub.new()
	st.world = Node3D.new()
	root.add_child(st)
	st.add_child(st.world)
	a.game = st
	a.root = Node3D.new()
	return a

func machinery() -> void:
	# crushers, hoppers, belts and storage: the same builders the game uses
	var items := {
		"jaw_crusher": func(a, n): a.crusher_model(n, 0.0, 1),
		"cone_crusher": func(a, n): a.crusher_model(n, 0.0, 2),
		"small_hopper": func(a, n): a.hopper_model(n, 0.0),
		"sorting_table": func(a, n): a.sorting_table_model(n, 0.0),
		"output_storage": func(a, n): a.output_model(n, 0.0),
		"conveyor": func(a, n): a.conveyor_model(n, 0.0),
		"conveyor_corner_left": func(a, n): a.conveyor_corner_model(n, 0.0, "left"),
		"conveyor_corner_right": func(a, n): a.conveyor_corner_model(n, 0.0, "right"),
		"storage_crate": func(a, n): a.storage_model(n, 0.0)}
	for k in items:
		var a := art_instance()
		var n := Node3D.new()
		n.name = k
		items[k].call(a, n)
		save(n, "machinery", k)
	# drilling rigs and breakers
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
	var ecfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy.json"))
	var bcfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/business.json"))
	var state := QuarryState.new(ecfg)
	var biz := QuarryBusiness.new(state, bcfg)
	var prog := QuarryProgression.new(state, biz, cfg)
	for rt in ["drill_rig", "improved_rig", "rock_breaker", "heavy_breaker"]:
		var r := QuarryRig.new()
		r.prog = prog
		r.rtype = rt
		r.rkind = str(prog.machine(rt).get("kind", "drill" if rt == "drill_rig" else "breaker"))
		r._build()
		r.name = rt
		save(r, "machinery", rt)

func buildings() -> void:
	for k in ["office", "shed", "home", "garage", "stations"]:
		var a := art_instance()
		a.call("_" + k)
		a._flush()
		a.root.name = k
		save(a.root, "buildings", k if k != "stations" else "sales_booth_and_order_kiosk")
		for c in a.game.world.get_children():
			c.queue_free()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
	machinery()
	buildings()
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
