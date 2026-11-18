extends Node3D
class_name ScreenFace
## Text that really sits INSIDE a little screen: the text is drawn into a small SubViewport (a dark glass background, phosphor-coloured letters with a soft halo), a scanline / vignette / glass-sheen
## layer is laid over it, and the result is a flat textured quad lying on the machine's own screen glass. Nothing floats in front of the model any more: the letters are part of the screen's picture,
## lit like it, cut off by its edge. `crt = false` makes a plain painted-lettering quad (a name plate): transparent background, no scanlines.
## `text` and `modulate` behave like a Label3D's, so callers only set text.

const SCAN_SHADER := """shader_type canvas_item;
void fragment() {
	float line = step(1.0, mod(FRAGCOORD.y, 2.0));
	vec2 d = (UV - vec2(0.5)) * vec2(1.0, 0.85);
	float vig = smoothstep(0.30, 0.78, length(d));
	float sheen = smoothstep(0.05, 0.75, 1.0 - UV.x - UV.y * 0.9) * 0.06;
	COLOR = vec4(vec3(sheen * 3.0), 0.20 * line + 0.50 * vig);
}
"""

var text := "" : set = _set_text
var modulate := Color(1, 1, 1, 1) : set = _set_modulate
var _vp: SubViewport
var _label: Label
var _quad: MeshInstance3D
var _bg: ColorRect
var _crt := true
var _ink := Color(0.55, 1.0, 0.62)
var _dirty := true

## size_m: the quad's size in metres; px: the viewport's size (keep the same aspect); font_px: text size in that viewport.
func setup(size_m: Vector2, px: Vector2i, font_px: int, ink: Color, align := HORIZONTAL_ALIGNMENT_CENTER, crt := true, glass := Color(0.02, 0.07, 0.04)) -> void:
	_crt = crt
	_ink = ink
	_vp = SubViewport.new()
	_vp.size = px
	_vp.transparent_bg = not crt
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_vp.gui_disable_input = true
	add_child(_vp)
	if crt:
		_bg = ColorRect.new()
		_bg.color = glass
		_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		_vp.add_child(_bg)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 6
	_label.offset_right = -6
	_label.offset_top = 4
	_label.offset_bottom = -4
	_label.horizontal_alignment = align
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.clip_text = true
	_label.add_theme_font_override("font", QuarryTheme.hud())
	_label.add_theme_font_size_override("font_size", font_px)
	_label.add_theme_color_override("font_color", ink)
	if crt:
		_label.add_theme_color_override("font_outline_color", Color(ink.r * 0.35, ink.g * 0.6, ink.b * 0.4, 0.45))          # the phosphor glow round the letters
		_label.add_theme_constant_override("outline_size", 3)
	else:
		_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 1.0))
		_label.add_theme_constant_override("outline_size", 2)
	_vp.add_child(_label)
	if crt:
		var scan := ColorRect.new()
		scan.set_anchors_preset(Control.PRESET_FULL_RECT)
		var sm := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = SCAN_SHADER
		sm.shader = sh
		scan.material = sm
		scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vp.add_child(scan)
	_quad = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size_m
	_quad.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = _vp.get_texture()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	if not crt:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.4
	_quad.material_override = m
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.rotation = Vector3(0, PI, 0)                                   # the quad faces -Z, like the machine's front
	add_child(_quad)
	_set_text(text)

func _set_text(t: String) -> void:
	if t == text and _label != null and _label.text == t:
		return
	text = t
	if _label != null:
		_label.text = t
		redraw()

func _set_modulate(c: Color) -> void:
	modulate = c
	if _label != null:
		_label.add_theme_color_override("font_color", Color(_ink.r * c.r, _ink.g * c.g, _ink.b * c.b, c.a))
		redraw()

## Draw the viewport once more (only when the text or its colour changed: nothing is re-rendered every frame).
func redraw() -> void:
	if _vp != null and is_inside_tree():
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
