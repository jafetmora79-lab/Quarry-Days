extends RefCounted
class_name UiSkin
## The generated HUD artwork (assets/ui/hud/*.png, cut from the sprite sheets by tools/ui_sheet_cut.py) as nine-slice style boxes and plain textures.
## Every lookup has a fallback: when a file is missing the caller keeps its flat look, so the artwork can arrive piece by piece. No text or value is ever part of
## the art: labels, numbers, maps and bar amounts stay live in the game.

const DIR := "res://assets/ui/hud/"
## Nine-slice margins in game pixels: left, top, right, bottom (the plain edges between the corner ornaments stretch).
const MARGINS := {
	"panel_main": [11, 11, 11, 11], "panel_inset": [10, 10, 10, 10], "plate_title": [14, 8, 14, 8], "plate_prompt": [10, 7, 10, 7],
	"frame_dialog": [16, 14, 16, 14], "frame_portrait": [10, 10, 10, 10], "plate_toast": [10, 9, 10, 9], "plate_banner": [16, 10, 16, 10],
	"panel_vehicle": [11, 11, 11, 11], "plate_repair": [14, 8, 8, 8],
	"btn_primary": [9, 8, 9, 8], "btn_main": [9, 8, 9, 8], "btn_danger": [9, 8, 9, 8], "btn_disabled": [9, 8, 9, 8],
	"keycap_small": [7, 7, 7, 7], "keycap_small_hover": [7, 7, 7, 7], "keycap_small_pressed": [7, 7, 7, 7], "keycap_small_off": [7, 7, 7, 7], "keycap_wide": [9, 7, 9, 7],
	"bar_groove": [10, 5, 10, 5], "bar_fill_green": [4, 3, 4, 3], "bar_fill_gold": [4, 3, 4, 3], "bar_fill_red": [4, 3, 4, 3], "bar_fill_blue": [4, 3, 4, 3],
	"slot_empty": [8, 8, 8, 8], "slot_selected": [8, 8, 8, 8], "slot_ok": [8, 8, 8, 8], "slot_bad": [8, 8, 8, 8], "slot_locked": [8, 8, 8, 8],
}
static var _tex := {}
static var _boxes := {}
static var _missing := {}

static func has(name: String) -> bool:
	return tex(name) != null

static func tex(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var path := DIR + name + ".png"
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if t == null:
		_missing[name] = true
	_tex[name] = t
	return t

static func icon_tex(name: String) -> Texture2D:
	return tex("icons/" + name)

## A nine-slice style box from the artwork, or `fallback` (which may be null) when the piece is not there. `content` = extra content margins
## (left, top, right, bottom); by default the border thickness, so text never sits on the ornaments.
static func box(name: String, fallback: StyleBox = null, content: Variant = null, tint: Color = Color.WHITE) -> StyleBox:
	var key := "%s|%s|%s" % [name, str(content), tint.to_html()]
	if _boxes.has(key):
		return _boxes[key]
	var t := tex(name)
	var out: StyleBox = fallback
	if t != null and MARGINS.has(name):
		var m: Array = MARGINS[name]
		var sb := StyleBoxTexture.new()
		sb.texture = t
		sb.texture_margin_left = m[0]
		sb.texture_margin_top = m[1]
		sb.texture_margin_right = m[2]
		sb.texture_margin_bottom = m[3]
		sb.modulate_color = tint
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		var c: Array = content if content is Array else [m[0] - 2, m[1] - 2, m[2] - 2, m[3] - 2]
		sb.content_margin_left = c[0]
		sb.content_margin_top = c[1]
		sb.content_margin_right = c[2]
		sb.content_margin_bottom = c[3]
		out = sb
	_boxes[key] = out
	return out

## Files the code asked for that are not in the project (logged once by the startup check).
static func missing() -> Array:
	return _missing.keys()
