extends HBoxContainer
class_name QuarryHotbar
## The tool hotbar: one boxed slot per tool in reach (number key, icon, name), the one in hand lit in amber. Sits above the bottom plates, centred.

const SLOT := Vector2(74, 52)
var _sig := ""

func _init() -> void:
	name = "Hotbar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	alignment = BoxContainer.ALIGNMENT_CENTER

## slots: Array of {name, kind}; cur: index in hand.
func set_slots(slots: Array, cur: int) -> void:
	var sig := str(cur) + "|" + str(slots)
	if sig == _sig:
		return
	_sig = sig
	for c in get_children():
		remove_child(c)
		c.queue_free()
	for i in range(slots.size()):
		var on := i == cur
		var p := PanelContainer.new()
		p.name = "Slot%d" % (i + 1)
		p.custom_minimum_size = SLOT
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.30, 0.20, 0.08, 0.94) if on else Color(0.11, 0.09, 0.07, 0.82)
		sb.border_color = Color(1.0, 0.82, 0.36) if on else Color(0.45, 0.38, 0.28)
		sb.set_border_width_all(3 if on else 1)
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(3)
		p.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(v)
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(top)
		var key := Label.new()
		key.text = str(i + 1)
		key.add_theme_font_override("font", QuarryTheme.hud())
		key.add_theme_font_size_override("font_size", QuarryTheme.pixel_font_size(QuarryTheme.SMALL))
		key.add_theme_color_override("font_color", Color(1, 0.86, 0.45) if on else Color(0.75, 0.68, 0.55))
		top.add_child(key)
		var ic := HudIcon.new(str(slots[i].get("kind", "pick")), 24)
		ic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ic.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ic.custom_minimum_size = Vector2(24, 24)
		v.add_child(ic)
		var nm := Label.new()
		nm.text = str(slots[i].get("name", "")).to_upper()
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_font_override("font", QuarryTheme.hud())
		nm.add_theme_font_size_override("font_size", QuarryTheme.pixel_font_size(QuarryTheme.SMALL))
		nm.add_theme_color_override("font_color", Color(1, 0.9, 0.6) if on else Color(0.72, 0.66, 0.56))
		nm.clip_text = true
		v.add_child(nm)
		add_child(p)
