extends Node3D
class_name HopperTopScreen
## The small slanted status window on top of the upgraded hoppers (tiers 1 and 2): the machine's live state at a glance, in the tier's own colours (HopperPlateScreen.SKINS).
## Line 1: SPEED n/s, with chevrons that run while material is going through; a bar: how full the queue is; line 2: QUEUE q / cap (tier 2 adds the material).
## Rendered once per change (the chevrons step a few times a second, never every frame).

const PX := Vector2i(260, 100)

var _vp: SubViewport
var _speed: Label
var _info: Label
var _bar: ColorRect
var _bar_bg: ColorRect
var _chev: Label
var _skin: Dictionary
var _step := 0
var _last := ""

func setup(size_m: Vector2, tier := 1) -> void:
	_skin = HopperPlateScreen.SKINS[clampi(tier, 0, HopperPlateScreen.SKINS.size() - 1)]
	var ink: Color = _skin["ink"]
	var acc: Color = _skin["accent"]
	_vp = SubViewport.new()
	_vp.size = PX
	_vp.transparent_bg = false
	_vp.disable_3d = true
	_vp.gui_disable_input = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_vp)
	var bg := ColorRect.new()
	bg.color = _skin["glass"]
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vp.add_child(bg)
	_speed = _lab(Rect2(8, 4, 170, 44), 34, ink, HORIZONTAL_ALIGNMENT_LEFT)
	_chev = _lab(Rect2(170, 4, 84, 44), 30, acc, HORIZONTAL_ALIGNMENT_RIGHT)
	_bar_bg = ColorRect.new()
	_bar_bg.color = _skin["bar_bg"]
	_bar_bg.position = Vector2(10, 52)
	_bar_bg.size = Vector2(PX.x - 20, 10)
	_vp.add_child(_bar_bg)
	_bar = ColorRect.new()
	_bar.color = acc
	_bar.position = Vector2(10, 52)
	_bar.size = Vector2(0, 10)
	_vp.add_child(_bar)
	var segs := int(_skin["segments"])
	for si in range(1, segs):
		var gap := ColorRect.new()
		gap.color = _skin["glass"]
		gap.position = Vector2(10.0 + (PX.x - 20.0) * float(si) / float(segs) - 1.0, 52)
		gap.size = Vector2(2, 10)
		_vp.add_child(gap)
	_info = _lab(Rect2(8, 64, PX.x - 16, 32), 20, Color(ink.r, ink.g, ink.b, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
	var scan := ColorRect.new()
	scan.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = ScreenFace.SCAN_SHADER
	sm.shader = sh
	scan.material = sm
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp.add_child(scan)
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size_m
	quad.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = _vp.get_texture()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	quad.material_override = m
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.rotation = Vector3(0, PI, 0)                                    # (the quad faces -Z in its own frame)
	add_child(quad)
	set_stats(0.0, 0, 20, false, "")

func _lab(r: Rect2, size: int, c: Color, align: int) -> Label:
	var l := Label.new()
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.add_theme_font_override("font", QuarryTheme.hud())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(c.r * 0.35, c.g * 0.6, c.b * 0.4, 0.45))
	l.add_theme_constant_override("outline_size", 3)
	_vp.add_child(l)
	return l

## speed: units per second; queue / cap: what waits; working: material is going through (the chevrons run); what: the material (shown on tier 2).
func set_stats(speed: float, queue: int, cap: int, working: bool, what: String) -> void:
	if _vp == null:
		return
	if working:
		_step = (_step + 1) % 4
	var sig := "%.0f|%d|%d|%s|%s|%d" % [speed, queue, cap, str(working), what, _step if working else -1]
	if sig == _last:
		return
	_last = sig
	_speed.text = "SPEED %.0f/s" % speed
	_chev.text = [">   ", ">>  ", ">>> ", "    "][_step] if working else ""
	_bar.size.x = (PX.x - 20.0) * clampf(float(queue) / float(maxi(cap, 1)), 0.0, 1.0)
	_info.text = ("QUEUE %d / %d" % [queue, cap]) + (("   " + what.to_upper()) if what != "" and str(_skin["badge"]) == "LV3" else "")
	if is_inside_tree():
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
