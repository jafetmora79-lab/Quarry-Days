extends Node
class_name HighlightOutline
## The "you can press E on this" outline: ONE thin line round the overall silhouette of the thing, never round each face or part.
## How: the parts of the target get a twin on visual layer 20 (MASK_LAYER) that only a second camera sees, drawn flat white into a SubViewport that shares the game's world and copies the
## player's camera. A full-screen pass over the finished picture then paints a line where that mask has an edge (the pixels just OUTSIDE the white shape). The player's camera does not
## see layer 20, so the twins are invisible in the normal picture. Inactive (no viewport, no pass) whenever nothing is highlighted.

const MASK_LAYER := 1 << 19
const WIDTH_PX := 2.0
const COLOR := Color(1.0, 0.82, 0.38, 1.0)

const SHADER := """shader_type canvas_item;
uniform sampler2D mask : filter_nearest;
uniform vec2 texel;
uniform float width = 2.0;
uniform vec4 col : source_color = vec4(1.0, 0.82, 0.38, 1.0);
void fragment() {
	float here = texture(mask, UV).a;
	float near = 0.0;
	for (int i = -3; i <= 3; i++) {
		for (int j = -3; j <= 3; j++) {
			vec2 o = vec2(float(i), float(j));
			if (length(o) <= width + 0.5) {
				near = max(near, texture(mask, UV + o * texel).a);
			}
		}
	}
	float edge = (1.0 - here) * near;
	COLOR = vec4(col.rgb, edge * col.a);
}
"""

var _cam: Camera3D
var _vp: SubViewport
var _layer: CanvasLayer
var _rect: ColorRect
var _mat: ShaderMaterial
var _twins: Array = []
var _source: Camera3D
var mask_layer := MASK_LAYER          ## each instance has its own mask layer, so two outlines (the E target, the cleanup markers) never show each other's shapes
var color := COLOR
var pulse := 0.0                      ## 0 steady; > 0 the line breathes between dim and bright at this many cycles a second
var _pt := 0.0

func setup(main_camera: Camera3D, layer := MASK_LAYER, col := COLOR, pulse_hz := 0.0) -> void:
	name = "HighlightOutline"
	mask_layer = layer
	color = col
	pulse = pulse_hz
	_source = main_camera
	_source.cull_mask = _source.cull_mask & ~mask_layer                       # the player's own camera never sees the mask twins
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.handle_input_locally = false
	_vp.gui_disable_input = true
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.cull_mask = mask_layer
	_vp.add_child(_cam)
	_layer = CanvasLayer.new()
	_layer.layer = -1                                                          # above the 3D picture, below every HUD layer
	add_child(_layer)
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_rect.material = _mat
	_rect.visible = false
	_layer.add_child(_rect)
	set_process(false)

func active() -> bool:
	return not _twins.is_empty()

## The meshes to outline: each gets a twin that only the mask camera sees.
func show_for(meshes: Array) -> void:
	clear()
	for mi in meshes:
		var m := mi as MeshInstance3D
		if m == null or m.mesh == null:
			continue
		var twin := MeshInstance3D.new()
		twin.name = "OutlineMask"
		twin.mesh = m.mesh
		twin.layers = mask_layer
		twin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var white := StandardMaterial3D.new()
		white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		white.albedo_color = Color(1, 1, 1, 1)
		white.cull_mode = BaseMaterial3D.CULL_DISABLED
		twin.material_override = white
		m.add_child(twin)
		_twins.append(twin)
	if _twins.is_empty():
		return
	_rect.visible = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	set_process(true)
	_sync()

func clear() -> void:
	for t in _twins:
		if is_instance_valid(t):
			(t as Node).queue_free()
	_twins.clear()
	_rect.visible = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	set_process(false)

func _process(delta: float) -> void:
	_pt += delta
	_sync()

func _sync() -> void:
	if _source == null or not is_instance_valid(_source):
		return
	var sz := _source.get_viewport().get_visible_rect().size
	var isz := Vector2i(maxi(2, int(sz.x)), maxi(2, int(sz.y)))
	if _vp.size != isz:
		_vp.size = isz
	_cam.global_transform = _source.global_transform
	_cam.fov = _source.fov
	_cam.near = _source.near
	_cam.far = _source.far
	_cam.keep_aspect = _source.keep_aspect
	_mat.set_shader_parameter("mask", _vp.get_texture())
	_mat.set_shader_parameter("texel", Vector2(1.0 / float(isz.x), 1.0 / float(isz.y)))
	_mat.set_shader_parameter("width", WIDTH_PX * maxf(1.0, float(isz.y) / 720.0))
	var c := color
	if pulse > 0.0:
		var k := 0.5 + 0.5 * sin(_pt * TAU * pulse)
		c = Color(color.r * (0.55 + 0.45 * k), color.g * (0.55 + 0.45 * k), color.b * (0.55 + 0.45 * k), color.a)
	_mat.set_shader_parameter("col", c)
