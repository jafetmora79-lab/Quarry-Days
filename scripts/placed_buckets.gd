extends Node3D
class_name PlacedBuckets
## Buckets standing on the ground. You put one down where you like (the bucket tool, click), shovel/dig near it and the dirt goes into it (the nearest bucket with room takes it first),
## then E picks a filled one up to carry it to the storage box or the Cash Hopper. As many as you want to place (MAX_PLACED), each holds one bucket's load.
## They are solid: the collider is a post taller than a jump (1.4 m against 0.9 m jump height) and is not climbable (no "ground" / "climbable" meta, so the mantle never takes it),
## so they cannot be walked through, stood on or used as steps over a fence.

const MAX_PLACED := 12
const REACH_FILL := 4.5               ## a bucket this close to the player takes the dirt that is dug
const COLLIDER_H := 1.4
const COLLIDER_R := 0.3
const VISUAL_H := 0.42

var items: Array = []                 ## {body: StaticBody3D, load: Dictionary, fill: Node3D}
var cap := 18                         ## one bucket's load (set by the game from state.bucket_capacity())
var _ghost: MeshInstance3D
var _next_id := 1

func _ready() -> void:
	name = "PlacedBuckets"

func total_of(load: Dictionary) -> int:
	var n := 0
	for k in load:
		n += int(load[k])
	return n

func main_res(load: Dictionary) -> String:
	var best := -1
	var r := ""
	for k in load:
		if int(load[k]) > best:
			best = int(load[k])
			r = str(k)
	return r

## Can a bucket stand here? "" when yes, else the reason. `avoid_from` is the player's position: not on their own feet.
func why_not(point: Vector3, normal: Vector3, avoid_from := Vector3.INF) -> String:
	if items.size() >= MAX_PLACED:
		return "That is enough buckets (%d)." % MAX_PLACED
	if normal.y < 0.85:
		return "Too steep for a bucket."
	if avoid_from != Vector3.INF and Vector2(point.x - avoid_from.x, point.z - avoid_from.z).length() < 0.75:
		return "Not under your own feet."
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = COLLIDER_R + 0.08
	sh.height = 0.6
	q.shape = sh
	q.transform = Transform3D(Basis(), point + Vector3(0, 0.45, 0))
	q.collision_mask = 1 | 4 | 8 | 16
	if not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
		return "No room for a bucket there."
	return ""

func _model() -> Node3D:
	return GearModels.bucket_tool()

## Puts a bucket (with `load`) on the ground at `point`. Returns the item, or {} when it could not be placed.
func place(point: Vector3, load: Dictionary, yaw := 0.0) -> Dictionary:
	var body := StaticBody3D.new()
	body.name = "Bucket%d" % _next_id
	_next_id += 1
	body.position = to_local(point)
	body.rotation.y = yaw
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("kind", "placed_bucket")
	body.set_meta("no_climb", true)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = COLLIDER_R
	cyl.height = COLLIDER_H
	cs.shape = cyl
	cs.position = Vector3(0, COLLIDER_H * 0.5, 0)
	body.add_child(cs)
	var model := _model()
	body.add_child(model)
	var box := _visual_box(model)
	var s := VISUAL_H / maxf(0.05, box.size.y)
	model.scale = Vector3.ONE * s
	model.position = Vector3(-(box.position.x + box.size.x * 0.5) * s, -box.position.y * s, -(box.position.z + box.size.z * 0.5) * s)
	add_child(body)
	var item := {"body": body, "load": load.duplicate(true), "model": model.get_meta("bucket_model"), "fill": model.get_meta("fill")}
	items.append(item)
	body.set_meta("bucket_index", items.size() - 1)
	refresh(item)
	return item

func _visual_box(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b: AABB = _rel_xf(m, model) * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

static func _rel_xf(n: Node3D, up_to: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node3D = n
	while cur != null and cur != up_to:
		xf = cur.transform * xf
		cur = cur.get_parent() as Node3D
	return xf

func refresh(item: Dictionary) -> void:
	var m: Node3D = item["model"]
	if m == null or not is_instance_valid(m):
		return
	BucketView.set_load(m, item["load"], cap)

func index_of(body: Node) -> int:
	for i in items.size():
		if items[i]["body"] == body:
			return i
	return -1

## Takes the bucket away (the caller carries it). Returns its load, or {} when there is no such bucket.
func pick_up(body: Node) -> Dictionary:
	var i := index_of(body)
	if i < 0:
		return {}
	var load: Dictionary = items[i]["load"]
	(items[i]["body"] as Node).queue_free()
	items.remove_at(i)
	for k in items.size():
		(items[k]["body"] as Node).set_meta("bucket_index", k)
	return load

## Dirt dug near `from` goes to the closest bucket (to the dig point `at`) that is within reach of `from` and has room. Returns the units taken.
func receive(from: Vector3, at: Vector3, res: String, n: int) -> int:
	var order := []
	for it in items:
		var p: Vector3 = (it["body"] as Node3D).global_position
		if Vector2(p.x - from.x, p.z - from.z).length() <= REACH_FILL and absf(p.y - from.y) < 2.5:
			order.append(it)
	order.sort_custom(func(a, b): return (a["body"] as Node3D).global_position.distance_to(at) < (b["body"] as Node3D).global_position.distance_to(at))
	var left := n
	for it in order:
		if left <= 0:
			break
		var room := cap - total_of(it["load"])
		if room <= 0:
			continue
		var put := mini(room, left)
		(it["load"] as Dictionary)[res] = int((it["load"] as Dictionary).get(res, 0)) + put
		left -= put
		refresh(it)
	return n - left

## Room left in a bucket, counting stones still in the air towards it.
func room_of(body: Node) -> int:
	var it := bucket_info(body)
	if it.is_empty():
		return 0
	return maxi(0, cap - total_of(it["load"]) - int(body.get_meta("pending", 0)))

## Units that have landed in the bucket (the stones thrown in from the bag).
func add_units(body: Node, res: String, n: int) -> int:
	var it := bucket_info(body)
	if it.is_empty():
		return 0
	var put := mini(n, maxi(0, cap - total_of(it["load"])))
	if put > 0:
		(it["load"] as Dictionary)[res] = int((it["load"] as Dictionary).get(res, 0)) + put
		refresh(it)
	return put

func bucket_info(body: Node) -> Dictionary:
	var i := index_of(body)
	return {} if i < 0 else items[i]

## The placing preview: a translucent bucket-sized cylinder at the aim point, green where it can stand and red where it cannot.
func show_ghost(point: Vector3, ok: bool) -> void:
	if _ghost == null:
		_ghost = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.26
		cm.bottom_radius = 0.2
		cm.height = VISUAL_H
		cm.radial_segments = 10
		_ghost.mesh = cm
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost.material_override = m
		_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ghost)
	(_ghost.material_override as StandardMaterial3D).albedo_color = Color(0.4, 0.9, 0.4, 0.45) if ok else Color(0.95, 0.35, 0.3, 0.45)
	_ghost.global_position = point + Vector3(0, VISUAL_H * 0.5, 0)
	_ghost.visible = true

func hide_ghost() -> void:
	if _ghost != null:
		_ghost.visible = false

func save() -> Array:
	var out := []
	for it in items:
		var p: Vector3 = (it["body"] as Node3D).global_position
		out.append({"pos": [p.x, p.y, p.z], "yaw": (it["body"] as Node3D).rotation.y, "load": (it["load"] as Dictionary).duplicate(true)})
	return out

func restore(data: Array) -> void:
	for it in items:
		(it["body"] as Node).queue_free()
	items.clear()
	for d in data:
		if d is Dictionary and d.get("pos") is Array and (d["pos"] as Array).size() >= 3:
			var p: Array = d["pos"]
			var load := {}
			for k in (d.get("load", {}) as Dictionary):
				load[str(k)] = maxi(0, int(d["load"][k]))
			place(Vector3(float(p[0]), float(p[1]), float(p[2])), load, float(d.get("yaw", 0.0)))
