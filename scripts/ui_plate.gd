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
const FLAT_BG := Color(0.115, 0.088, 0.065, 0.86)            ## warm dark brown-charcoal (never cool slate), mostly opaque so it reads over sky and rock alike
const FLAT_EDGE := Color(0.70, 0.51, 0.27, 0.9)             ## thin bronze / muted amber border
const CORNER := Color(0.88, 0.68, 0.36, 0.9)                ## the small corner details

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
	if skinned:
		return
	# no coloured strip: a flat dark plate, a thin bronze border (see _init) and a small bright tick in each corner
	var w := size.x
	var h := size.y
	for c in [Vector2(2, 2), Vector2(w - 5, 2), Vector2(2, h - 5), Vector2(w - 5, h - 5)]:
		draw_rect(Rect2(c, Vector2(3, 3)), CORNER, true)

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
