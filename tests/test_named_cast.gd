extends SceneTree
## The named cast (tools/character_cast): every candidate, Walter and Dr. Marsh load as their own rigged model with the
## shared 22-bone humanoid, the four sockets, the mesh naming the game relies on, a sane height and a portrait.
##   godot --headless --fixed-fps 60 -s tests/test_named_cast.gd

var checks := 0
var failures := []

func check(c: bool, label: String) -> void:
	checks += 1
	if not c:
		failures.append(label)
		printerr("FAIL: " + label)

const BONES := ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head", "LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes",
	"RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes"]
const SOCKETS := ["Socket_Head", "Socket_RightHand", "Socket_LeftHand", "Socket_Back"]

func _initialize() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/business.json"))
	var ids: Array = ["walter", "marsh"]
	for c in cfg["candidates"]:
		ids.append(str(c["id"]))
	check(ids.size() == 14, "14 people: Walter, Dr. Marsh and twelve candidates (%d)" % ids.size())
	for id in ids:
		var cap := str(id).substr(0, 1).to_upper() + str(id).substr(1)
		var path := "res://assets/characters/CHR_QD_%s.glb" % cap
		if id != "walter" and id != "marsh":
			check(QuarryWorker.named_model(id) == path, "%s: the worker code finds the named model" % cap)
		var ps: PackedScene = load(path)
		check(ps != null, "%s: model loads" % cap)
		if ps == null:
			continue
		var body: Node3D = ps.instantiate()
		get_root().add_child(body)
		var sks := body.find_children("*", "Skeleton3D", true, false)
		check(sks.size() == 1, "%s: one skeleton" % cap)
		if sks.is_empty():
			body.queue_free()
			continue
		var sk: Skeleton3D = sks[0]
		var missing := []
		for b in BONES + SOCKETS:
			if sk.find_bone(b) < 0:
				missing.append(b)
		check(missing.is_empty(), "%s: humanoid bones and sockets present %s" % [cap, str(missing)])
		for part in ["_Body", "_Head", "_Hair", "_Shoes"]:
			check(body.find_child("QD_%s%s" % [cap, part], true, false) is MeshInstance3D, "%s: mesh QD_%s%s" % [cap, cap, part])
		var top := 0.0
		for mi in body.find_children("*", "MeshInstance3D", true, false):
			var ab: AABB = (mi as MeshInstance3D).get_aabb()
			top = maxf(top, ab.position.y + ab.size.y)
		var head_y := sk.get_bone_global_rest(sk.find_bone("Head")).origin.y
		check(head_y > 1.3 and head_y < 1.75, "%s: head bone at a human height (%.2f m)" % [cap, head_y])
		check(UiArt.named_index(id) >= UiArt.NAMED_BASE and UiArt.portrait(UiArt.named_index(id)) != null, "%s: portrait from the model" % cap)
		body.queue_free()
	check(UiArt.portrait_index("Rosa Quintero", "f", "miner", "rosa") == UiArt.named_index("rosa"), "a candidate's portrait is their own")
	check(UiArt.portrait_index("Somebody", "f", "miner") in UiArt.FEMALE, "people without a candidate keep the sheet portraits")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
