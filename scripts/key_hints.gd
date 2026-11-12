extends HBoxContainer
class_name QuarryKeyHints
## Phase 8.4: the controls strip along the bottom. Each hint is a key cap and a plain description ("LEFT CLICK  Mine"), never an
## abbreviation. set_hints() only rebuilds when the list changes, and the strip eases in when it does.

var current: Array = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 14)
	alignment = BoxContainer.ALIGNMENT_CENTER

func set_hints(items: Array) -> void:
	if items == current:
		return
	current = items.duplicate(true)
	for c in get_children():
		remove_child(c)
		c.queue_free()
	for it in items:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 5)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cap := PanelContainer.new()
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.33, 0.25, 0.16, 0.95)
		s.border_color = Color(0.7, 0.55, 0.34)
		s.set_border_width_all(1)
		s.border_width_bottom = 3
		s.set_corner_radius_all(4)
		s.anti_aliasing = true
		s.content_margin_left = 6
		s.content_margin_right = 6
		s.content_margin_top = 1
		s.content_margin_bottom = 1
		cap.add_theme_stylebox_override("panel", s)
		cap.add_child(QuarryTheme.label(str(it[0]), QuarryTheme.SMALL, QuarryTheme.INK, false, true))
		h.add_child(cap)
		h.add_child(QuarryTheme.label(str(it[1]), QuarryTheme.SMALL, Color(0.9, 0.84, 0.7)))
		add_child(h)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
