extends Node3D
class_name QuarryBlueprintHands
## Phase 8.4: build mode in first person. The tool is lowered and two hands raise a blueprint sheet in front of you, so it is
## obvious at a glance that you are building, not mining. Everything is camera-space geometry; nothing here affects gameplay.

var tool_view: Node3D
var active := false
var blend := 0.0
var paper: MeshInstance3D
var _t := 0.0

func _ready() -> void:
	name = "BlueprintHands"
	visible = false
	paper = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.50, 0.36)
	paper.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _sheet_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	paper.material_override = mat
	paper.rotation = Vector3(deg_to_rad(-62), 0, 0)
	add_child(paper)
	var skin := Color(0.82, 0.62, 0.48)
	var sleeve := Color(0.55, 0.38, 0.2)
	for sx in [-1.0, 1.0]:
		var hand := MeshInstance3D.new()
		var hb := BoxMesh.new()
		hb.size = Vector3(0.09, 0.05, 0.12)
		hand.mesh = hb
		hand.material_override = _flat(skin)
		hand.position = Vector3(sx * 0.27, -0.075, 0.03)
		hand.rotation = Vector3(deg_to_rad(-62), sx * deg_to_rad(8), 0)
		add_child(hand)
		var thumb := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(0.035, 0.035, 0.07)
		thumb.mesh = tb
		thumb.material_override = _flat(skin)
		thumb.position = Vector3(sx * 0.225, -0.045, -0.03)
		thumb.rotation = Vector3(deg_to_rad(-62), sx * deg_to_rad(-20), 0)
		add_child(thumb)
		var arm := MeshInstance3D.new()
		var ab := BoxMesh.new()
		ab.size = Vector3(0.1, 0.1, 0.4)
		arm.mesh = ab
		arm.material_override = _flat(sleeve)
		arm.position = Vector3(sx * 0.31, -0.28, 0.2)
		arm.rotation = Vector3(deg_to_rad(-40), sx * deg_to_rad(12), 0)
		add_child(arm)

func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

## A blue drawing sheet: white grid, a footprint outline with a diagonal, a title block.
func _sheet_texture() -> ImageTexture:
	var w := 160
	var h := 112
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.13, 0.32, 0.58))
	for x in range(0, w, 8):
		for y in range(h):
			img.set_pixel(x, y, Color(0.30, 0.50, 0.78))
	for y in range(0, h, 8):
		for x in range(w):
			img.set_pixel(x, y, Color(0.30, 0.50, 0.78))
	var line := Color(0.88, 0.94, 1.0)
	for x in range(36, 100):
		img.set_pixel(x, 28, line)
		img.set_pixel(x, 76, line)
	for y in range(28, 77):
		img.set_pixel(36, y, line)
		img.set_pixel(99, y, line)
	for i in range(0, 48):
		img.set_pixel(36 + int(i * 63.0 / 48.0), 28 + i, line)
	for x in range(108, 154):
		img.set_pixel(x, 82, line)
		img.set_pixel(x, 104, line)
	for y in range(82, 105):
		img.set_pixel(108, y, line)
		img.set_pixel(153, y, line)
	for x in range(6, w - 6):
		img.set_pixel(x, 5, line)
		img.set_pixel(x, h - 6, line)
	for y in range(5, h - 5):
		img.set_pixel(6, y, line)
		img.set_pixel(w - 7, y, line)
	return ImageTexture.create_from_image(img)

func set_active(on: bool) -> void:
	active = on

func _process(delta: float) -> void:
	_t += delta
	blend = move_toward(blend, 1.0 if active else 0.0, delta * 4.5)
	visible = blend > 0.01
	if tool_view:
		tool_view.visible = blend < 0.15 and not tool_view.suppressed
	var e := smoothstep(0.0, 1.0, blend)
	position = Vector3(0.0, lerpf(-0.75, -0.30, e) + sin(_t * 1.6) * 0.004 * e, -0.62)
