extends Control
class_name HudIcon
## Phase 8.4: tiny drawn icons for the HUD (coin, sun, moon, pickaxe, bag, flag), warm-coloured and crisp at any scale.

var kind := "coin"
var tint := Color(1, 1, 1, 1)

## HUD kinds that now have pixel art (assets/ui/icons); the others keep their drawn versions.
const ART := {"coin": "money", "sun": "sun", "flag": "milestones", "hammer": "hammer", "pick": "pickaxe", "bag": "bag"}

func _init(k := "coin", size_px := 14.0) -> void:
	kind = k
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	custom_minimum_size = Vector2(size_px, size_px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_kind(k: String) -> void:
	if k != kind:
		kind = k
		queue_redraw()

func _draw() -> void:
	var s := minf(size.x, size.y)
	if s < 4.0:
		return
	if ART.has(kind) and UiArt.has_icon(str(ART[kind])):
		draw_texture_rect(UiArt.icon(str(ART[kind]), s < 40.0), Rect2(Vector2((size.x - s) * 0.5, (size.y - s) * 0.5), Vector2(s, s)), false, tint)
		return
	var c := Vector2(size.x * 0.5, size.y * 0.5)
	var u := s / 16.0
	match kind:
		"coin":
			draw_circle(c, 7.0 * u, Color(0.55, 0.38, 0.1))
			draw_circle(c, 6.0 * u, Color(1.0, 0.82, 0.3))
			draw_arc(c, 4.2 * u, 0.0, TAU, 20, Color(0.78, 0.55, 0.12), 1.2 * u)
			draw_line(c + Vector2(0, -2.6 * u), c + Vector2(0, 2.6 * u), Color(0.7, 0.47, 0.1), 1.4 * u)
		"sun":
			draw_circle(c, 3.6 * u, Color(1.0, 0.86, 0.35))
			for i in range(8):
				var a := float(i) * TAU / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * 5.2 * u, c + Vector2(cos(a), sin(a)) * 7.2 * u, Color(1.0, 0.8, 0.3), 1.3 * u)
		"moon":
			draw_circle(c, 6.0 * u, Color(0.86, 0.88, 1.0))
			draw_circle(c + Vector2(2.6, -1.8) * u, 5.2 * u, Color(0.15, 0.115, 0.082))
		"pick":
			draw_line(Vector2(3, 14) * u, Vector2(12, 4) * u, Color(0.62, 0.45, 0.26), 1.8 * u)
			draw_arc(Vector2(10, 7) * u, 6.0 * u, deg_to_rad(200), deg_to_rad(340), 10, Color(0.8, 0.82, 0.86), 2.2 * u)
		"bag":
			draw_rect(Rect2(3 * u, 6 * u, 10 * u, 8 * u), Color(0.62, 0.45, 0.26))
			draw_rect(Rect2(3 * u, 6 * u, 10 * u, 2.4 * u), Color(0.78, 0.6, 0.36))
			draw_arc(Vector2(8, 5.5) * u, 3.0 * u, PI, TAU, 10, Color(0.45, 0.32, 0.18), 1.4 * u)
		"flag":
			draw_line(Vector2(4, 2) * u, Vector2(4, 14) * u, Color(0.8, 0.7, 0.5), 1.4 * u)
			draw_colored_polygon(PackedVector2Array([Vector2(4, 2) * u, Vector2(13, 4.5) * u, Vector2(4, 7.5) * u]), Color(0.98, 0.76, 0.34))
		"shovel":
			draw_line(Vector2(3, 14) * u, Vector2(10, 6) * u, Color(0.62, 0.45, 0.26), 1.8 * u)
			draw_colored_polygon(PackedVector2Array([Vector2(9, 7) * u, Vector2(11.5, 3.5) * u, Vector2(14.5, 5.5) * u, Vector2(13, 9.5) * u]), Color(0.78, 0.8, 0.84))
		"hammer":
			draw_line(Vector2(3, 14) * u, Vector2(11, 5) * u, Color(0.62, 0.45, 0.26), 1.8 * u)
			draw_rect(Rect2(8 * u, 2 * u, 6 * u, 4 * u), Color(0.75, 0.77, 0.8))
