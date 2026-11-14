extends PanelContainer
class_name QuarryPlate
## Phase 8.4: the HUD's warm industrial plate. A softly rounded, antialiased panel with a lit top edge, a darker lower edge,
## small rivets in the corners and an optional coloured strip down the left side. Smooth, not pixelated; the fonts stay
## the same. Panels fade and slide in/out with show_plate()/hide_plate().

var accent := Color(0.98, 0.76, 0.34, 0.0)      ## alpha 0 = no strip
var rivets := true
var skinned := false                              ## the generated panel art draws the frame, light and rivets itself
var _target_alpha := 1.0

func _init(margin := 8, strip := Color(0, 0, 0, 0)) -> void:
	accent = strip
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.15, 0.115, 0.082, 0.93)
	s.border_color = Color(0.52, 0.39, 0.25)
	s.set_border_width_all(2)
	s.border_width_top = 1
	s.border_width_bottom = 3
	s.set_corner_radius_all(7)
	s.corner_detail = 5
	s.anti_aliasing = true
	s.anti_aliasing_size = 0.9
	s.shadow_color = Color(0, 0, 0, 0.34)
	s.shadow_size = 5
	s.shadow_offset = Vector2(0, 2)
	s.content_margin_left = margin + (4 if strip.a > 0.0 else 0)
	s.content_margin_right = margin
	s.content_margin_top = margin - 2
	s.content_margin_bottom = margin - 1
	skinned = UiSkin.has("panel_main")
	if skinned:
		var m := 11
		add_theme_stylebox_override("panel", UiSkin.box("panel_main", s, [m + (3 if strip.a > 0.0 else 0), m - 3, m, m - 3]))
	else:
		add_theme_stylebox_override("panel", s)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x < 16.0 or r.size.y < 16.0:
		return
	if skinned:
		if accent.a > 0.0:
			draw_rect(Rect2(8, 11, 3, size.y - 22), accent)          # the coloured strip sits just inside the art's border
		return
	# a soft light falling from the top: a vertical gradient fading out over the upper half
	var inner := r.grow(-4.0)
	var h := minf(inner.size.y * 0.55, 26.0)
	var pts := PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), Vector2(inner.end.x, inner.position.y + h), Vector2(inner.position.x, inner.position.y + h)])
	var cols := PackedColorArray([Color(1, 0.92, 0.75, 0.10), Color(1, 0.92, 0.75, 0.10), Color(1, 0.92, 0.75, 0.0), Color(1, 0.92, 0.75, 0.0)])
	draw_polygon(pts, cols)
	draw_line(Vector2(7, 2.5), Vector2(size.x - 7, 2.5), Color(1, 0.88, 0.62, 0.30), 1.0)          # lit top edge
	if accent.a > 0.0:
		draw_rect(Rect2(5, 7, 3, size.y - 14), accent)
	if rivets:
		for p in [Vector2(5, 5), Vector2(size.x - 5, 5), Vector2(5, size.y - 6), Vector2(size.x - 5, size.y - 6)]:
			draw_circle(p, 1.4, Color(0.78, 0.62, 0.38, 0.8))
			draw_circle(p + Vector2(0.5, 0.5), 0.7, Color(0.25, 0.17, 0.1, 0.9))

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

## Smooth show/hide: fade with a small rise.
func show_plate() -> void:
	_target_alpha = 1.0
	visible = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.18)

func hide_plate() -> void:
	_target_alpha = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.14)
	tw.tween_callback(func(): if _target_alpha == 0.0: visible = false)
