extends SceneTree
## Cast audit: for every character, run the rig through its states and measure (a) foot contact: how far the lowest foot is above/below its
## standing height while the body moves (a planted foot should stay within ~2 cm of the ground), (b) height and proportions (head, arm span, leg length vs
## height), (c) the hands in carry and work poses (distance from each wrist to its target).
##   godot --headless --path . -s tools/audit_cast.gd
const CAST := ["Walter", "Marsh", "Rosa", "Dmitri", "Omar", "Felix", "Hana", "Hauler", "Ines", "Lucia", "Miner", "Nia", "Operator", "Petra", "Sofia"]
var rows := []

func _initialize() -> void:
	call_deferred("run")

func gy(sk: Skeleton3D, n: String) -> float:
	return sk.get_bone_global_pose(sk.find_bone(n)).origin.y

func run() -> void:
	for who in CAST:
		var path := "res://assets/characters/CHR_QD_%s.glb" % who
		if not ResourceLoader.exists(path):
			continue
		var body: Node3D = (load(path) as PackedScene).instantiate()
		root.add_child(body)
		var sk: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
		var rig := VeilRig.new()
		rig.setup(sk, 1.0)
		for i in 30:
			rig.pose(1.0 / 60.0, "idle", 0.0, "miner", false)
		var stand := minf(gy(sk, "LeftToes"), gy(sk, "RightToes"))
		var height := gy(sk, "Head") + 0.12
		var leg := gy(sk, "LeftUpperLeg") - gy(sk, "LeftFoot")
		var arm := sk.get_bone_global_pose(sk.find_bone("RightUpperArm")).origin.distance_to(sk.get_bone_global_pose(sk.find_bone("RightHand")).origin)
		var line := "%-9s height %.2f leg %.2f (%.0f%%) arm %.2f (%.0f%%)" % [who, height, leg, 100.0 * leg / height, arm, 100.0 * arm / height]
		for st in [["walk", 1.4], ["walk", 2.6], ["work", 0.0], ["carry", 1.2]]:
			var lo := 9.0
			var hi := -9.0
			for i in 240:
				rig.pose(1.0 / 60.0, st[0], st[1], "miner", st[0] == "carry", fmod(i / 60.0, 1.0) if st[0] == "work" else -1.0)
				var d := minf(gy(sk, "LeftToes"), gy(sk, "RightToes")) - stand
				if i > 60:
					lo = minf(lo, d)
					hi = maxf(hi, d)
			line += " | %s%.1f foot %+.0f..%+.0f cm" % [st[0], st[1], lo * 100.0, hi * 100.0]
		rows.append(line)
		print(line)
		body.queue_free()
	quit(0)
