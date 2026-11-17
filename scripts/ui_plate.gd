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
const FLAT_BG := Color(0.105, 0.078, 0.057, 0.93)            ## warm dark brown (never cool slate), mostly opaque so it reads over sky and rock alike
const FLAT_EDGE := Color(0.74, 0.53, 0.27, 1.0)             ## bronze edge
const INNER := Color(0.04, 0.03, 0.02, 0.85)                ## the dark line just inside the edge
const RIVET := Color(0.93, 0.74, 0.42, 1.0)                 ## the small rivets in the corners
const RIVET_SHADE := Color(0.25, 0.16, 0.07, 1.0)
var decorate := true                                          ## false: draws nothing of its own (the minimap's plate: that stays exactly as it was)

func _init(margin := 8, strip := Color(0, 0, 0, 0)) -> void:
	accent = strip
	var s := StyleBoxFlat.new()
	s.bg_color = FLAT_BG
	s.border_color = FLAT_EDGE
	s.set_border_width_all(2)
	s.set_corner_radius_all(5)
	s.corner_detail = 1                                         # one segment per corner: a chamfered (bevelled) corner, crisp
	s.anti_aliasing = false
	s.content_margin_left = maxi(9, margin + 1)
	s.content_margin_right = maxi(9, margin + 1)
	s.content_margin_top = maxi(6, margin - 2)
	s.content_margin_bottom = maxi(6, margin - 2)
	skinned = false
	rivets = false
	add_theme_stylebox_override("panel", s)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if skinned or not decorate:
		return
	# the bronze edge and bevelled corners come from the stylebox (see _init); here: a dark line just inside the edge and a rivet in each corner
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2(2, 2), Vector2(w - 4, h - 4)), INNER, false, 1.0)
	for c in [Vector2(6, 6), Vector2(w - 8, 6), Vector2(6, h - 8), Vector2(w - 8, h - 8)]:
		draw_rect(Rect2(c + Vector2(0, 1), Vector2(2, 2)), RIVET_SHADE, true)
		draw_rect(Rect2(c, Vector2(2, 2)), RIVET, true)

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
