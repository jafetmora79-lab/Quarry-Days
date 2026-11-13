extends Node3D
class_name QuarrySurvey
## Survey-guided quarry construction: thin dashed survey lines and small stakes on the ground mark the excavation target. No glowing slabs and
## no permanent debug outlines: the starter excavation is marked until its contract is done, the quarry levels that are open (and the one
## that opens next) are marked on the rock, deeper levels show only in the quarry plan on the office computer. Completed boundaries
## disappear, because the real excavated terrain is there instead.

const DASH := 1.3
const GAP := 0.9
const WIDTH := 0.14
const STAKE_EVERY := 12.0

var game
var signature := ""
var timer := 0.0
var rects := {}          ## label -> {"world": Node3D, "mesh": MeshInstance3D}

func setup(main_node) -> void:
	game = main_node
	name = "Survey"
	game.add_child(self)

## [{id, label, rect Rect2(x, z, w, d), frame "world"|"pit", y, state "active"|"next"}] for what is marked right now.
func targets() -> Array:
	var out := []
	var prog: QuarryProgression = game.prog
	if game.pit_zone == null:
		return out
	if prog.natural_start() and game.natural_start_enabled:
		var a := prog.area_def("area_1")
		if not a.is_empty() and not prog.area_complete("area_1"):
			var r: Array = a["rect"]
			out.append({"id": "area_1", "rect": Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1])), "frame": "world", "y": 0.05, "state": "active"})
	for lp in game.pit_zone.level_pits:
		var n := int(lp["n"])
		if n > prog.quarry_level + 1:
			continue
		out.append({"id": "level_%d" % n, "rect": lp["rect"], "frame": "pit", "y": float(lp["y_top"]) + 0.05, "state": "active" if n <= prog.quarry_level else "next"})
	return out

func _sig(t: Array) -> String:
	var s := ""
	for x in t:
		s += "%s:%s;" % [x["id"], x["state"]]
	return s

func refresh(force := false) -> void:
	var t := targets()
	var sg := _sig(t)
	if sg == signature and not force:
		return
	signature = sg
	for k in rects.keys():
		if is_instance_valid(rects[k]):
			rects[k].queue_free()
	rects.clear()
	for tg in t:
		var host: Node3D = game.pit_zone if str(tg["frame"]) == "pit" else self
		var mi := _build(tg)
		host.add_child(mi)
		rects[str(tg["id"])] = mi

func _build(tg: Dictionary) -> MeshInstance3D:
	var r: Rect2 = tg["rect"]
	var y := float(tg["y"])
	var soup := MeshKit.Soup.new()
	var stakes := MeshKit.Soup.new()
	var corners := [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)]
	for i in range(4):
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var d := (b - a)
		var len := d.length()
		var dir := d / len
		var yaw := atan2(dir.x, dir.y)       # the dash's long (z) axis runs along the line
		var t := 0.0
		while t < len:
			var seg := minf(DASH, len - t)
			var c := a + dir * (t + seg * 0.5)
			MeshKit.box_into(soup, Vector3.ZERO, Vector3(WIDTH, 0.02, seg), Vector2.ONE, Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, y, c.y)))
			t += DASH + GAP
		var s := 0.0
		while s <= len + 0.01:
			var p := a + dir * s
			MeshKit.box_into(stakes, Vector3(p.x, y + 0.45, p.y), Vector3(0.07, 0.9, 0.07))
			MeshKit.box_into(stakes, Vector3(p.x + 0.16, y + 0.82, p.y), Vector3(0.3, 0.14, 0.02))
			s += STAKE_EVERY
	var node := MeshInstance3D.new()
	node.name = "Survey_" + str(tg["id"])
	var active := str(tg["state"]) == "active"
	var col := Color(0.98, 0.82, 0.38) if active else Color(0.8, 0.76, 0.66)
	var mat := MeshKit.flat(col, 0.25 if active else 0.12)
	node.mesh = soup.mesh()
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var stake_node := MeshInstance3D.new()
	stake_node.mesh = stakes.mesh()
	stake_node.material_override = MeshKit.flat(Color(0.9, 0.5, 0.2) if active else Color(0.62, 0.58, 0.5), 0.2)
	stake_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(stake_node)
	return node

func _process(delta: float) -> void:
	timer += delta
	if timer >= 1.0 and game != null and game.prog != null:
		timer = 0.0
		refresh()
