extends Node
class_name ItemThumbs
## Item thumbnails made from the game's real 3D models: one small off-screen viewport renders each item once, from the same angle and light, on a
## transparent background; the picture is cached (ImageTexture) and the model is thrown away, so nothing 3D is drawn per frame. Used by the hotbar.
## `get_thumb(key, build)` returns the cached picture, or null while it is queued; `ready_key` fires when a new one lands. Where nothing can be
## rendered (the headless test runner) the key is marked failed (`failed`) and callers show their labelled fallback instead of a wrong picture.

signal ready_key(key: String)

const PX := 128                                ## picture size (drawn smaller with a smooth filter: crisp edges, no pixel stair-steps)
var cache := {}                                ## key -> ImageTexture
var failed := {}                               ## key -> true when it could not be rendered
var _queue: Array = []                         ## [key, Callable returning a Node3D]
var _busy := false
var _vp: SubViewport
var _cam: Camera3D
var _pivot: Node3D

func _ready() -> void:
	name = "ItemThumbs"
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		return
	_vp = SubViewport.new()
	_vp.size = Vector2i(PX, PX)
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.handle_input_locally = false
	_vp.gui_disable_input = true
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.74, 0.7)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(-35), 0)
	sun.light_energy = 1.15
	_vp.add_child(sun)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.near = 0.05
	_cam.far = 40.0
	_vp.add_child(_cam)
	_cam.current = true

## The cached picture of item `key`, or null (queued, or failed). `build` makes the model (called once, when its turn comes).
func get_thumb(key: String, build: Callable, mode := "tool", px := PX) -> Texture2D:
	if cache.has(key):
		return cache[key]
	if failed.has(key):
		return null
	if _vp == null:
		failed[key] = true
		return null
	for q in _queue:
		if q[0] == key:
			return null
	_queue.append([key, build, mode, px])
	return null

func _process(_delta: float) -> void:
	if _busy or _queue.is_empty() or _vp == null:
		return
	_busy = true
	var job: Array = _queue.pop_front()
	await _render(str(job[0]), job[1], str(job[2]), int(job[3]))
	_busy = false

func _render(key: String, build: Callable, mode: String, px: int) -> void:
	var model: Node3D = build.call()
	_vp.size = Vector2i(px, px)
	if model == null:
		failed[key] = true
		return
	_pivot.add_child(model)
	# "tool": the handle runs up to the right, the working end shows side-on; "view": a three-quarter view from above (machines, carts, crushers)
	if mode == "view":
		model.basis = Basis(Vector3.UP, deg_to_rad(-38))
	else:
		model.basis = Basis(Vector3.BACK, deg_to_rad(-42)) * Basis(Vector3.UP, deg_to_rad(90))     # turn it side-on first, then lay it diagonal in the picture plane
	await get_tree().process_frame
	var box := _bounds(model)
	var c := box.get_center()
	if mode == "view":
		_cam.size = maxf(0.4, box.size.length() * 0.66)
		_cam.position = c + Vector3(0.0, 0.6, 1.0).normalized() * 6.0
		_cam.look_at(c, Vector3.UP)
	else:
		_cam.size = maxf(0.2, maxf(box.size.x, box.size.y) * 1.18)
		_cam.position = Vector3(c.x, c.y, c.z + 3.0)
		_cam.look_at(c, Vector3.UP)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	var img: Image = _vp.get_texture().get_image()
	_pivot.remove_child(model)
	model.queue_free()
	if img == null or img.is_empty() or not _has_pixels(img):
		failed[key] = true
		return
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	cache[key] = tex
	ready_key.emit(key)

func _has_pixels(img: Image) -> bool:
	var n := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			if img.get_pixel(x, y).a > 0.2:
				n += 1
	return n > 12

func _bounds(root_node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in root_node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var b: AABB = m.global_transform * m.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out if not first else AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
