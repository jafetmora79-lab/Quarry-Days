extends PanelContainer
class_name QuarryPlate
## Phase 8.4: the HUD's warm industrial plate. A softly rounded, antialiased panel with a lit top edge, a darker lower edge,
## small rivets in the corners and an optional coloured strip down the left side. Smooth, not pixelated; the fonts stay
## the same. Panels fade and slide in/out with show_plate()/hide_plate().

var accent := Color(0.98, 0.76, 0.34, 0.0)      ## alpha 0 = no strip
var rivets := true
var skinned := false                              ## the generated panel art draws the frame, light and rivets itself
var _target_alpha := 1.0

## The HUD's look since the redesign: small, flat, dark and translucent with a thin warm-amber edge and an optional coloured strip, no ornamental frame.
const FLAT_BG := Color(0.045, 0.04, 0.035, 0.66)
const FLAT_EDGE := Color(0.95, 0.74, 0.32, 0.5)

func _init(margin := 8, strip := Color(0, 0, 0, 0)) -> void:
	accent = strip
	var s := StyleBoxFlat.new()
	s.bg_color = FLAT_BG
	s.border_color = FLAT_EDGE
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.corner_detail = 3
	s.anti_aliasing = false
	s.content_margin_left = maxi(6, margin - 1)
	s.content_margin_right = maxi(6, margin - 1)
	s.content_margin_top = maxi(4, margin - 4)
	s.content_margin_bottom = maxi(4, margin - 4)
	skinned = false
	rivets = false
	add_theme_stylebox_override("panel", s)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if accent.a > 0.0 and size.y > 12.0:
		draw_rect(Rect2(0, 3, 2, size.y - 6), Color(accent.r, accent.g, accent.b, 0.85))        # a thin coloured strip down the left edge

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
