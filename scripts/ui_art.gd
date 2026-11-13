extends RefCounted
class_name UiArt
## Pixel icons and worker portraits for the UI (assets/ui, built by tools/build_ui_art.py from the generated sheets).
## Everything is drawn with nearest-neighbour filtering so the pixels stay crisp at any size.

const ICON_DIR := "res://assets/ui/icons/"
const PORTRAIT_DIR := "res://assets/ui/portraits/"
static var _cache := {}

## Portrait sheet order: 0 miner with lamp, 1 woman in bandana, 2 moustached miner, 3 bearded man in cap, 4 earmuffs and goggles, 5 woman in cap,
## 6 goggles and beard, 7 man in cap with gloves, 8 clerk with clipboard, 9 grandfather, 10 freckled young man, 11 freckled woman in hard hat.
const FEMALE := [1, 5, 11]
const MALE := [0, 2, 3, 4, 6, 7, 10]
const GRANDFATHER := 9
const CLERK := 8

## The icon art is drawn at 64 px (tools/draw_ui_icons.py) with a 32 px copy ("_s") for small lists and the HUD, so neither size is ever scaled by a fraction.
static func icon(name: String, small := false) -> Texture2D:
	return _tex(ICON_DIR + name + ("_s" if small else "") + ".png")

static func has_icon(name: String) -> bool:
	return ResourceLoader.exists(ICON_DIR + name + ".png")

## The named cast (tools/character_cast) has portraits rendered from their own 3D models, so the face in the UI is the
## person in the yard. They use indices NAMED_BASE + position in NAMED_IDS; everyone else keeps the sheet portraits.
const NAMED_DIR := "res://assets/ui/portraits/named/"
const NAMED_BASE := 100
const NAMED_IDS := ["walter", "marsh", "rosa", "dmitri", "ines", "nia", "tomas", "hana", "sofia", "bram", "lucia", "felix", "petra", "omar"]

static func named_index(id: String) -> int:
	var i := NAMED_IDS.find(id)
	return NAMED_BASE + i if i >= 0 and ResourceLoader.exists(NAMED_DIR + id + ".png") else -1

static func portrait(index: int) -> Texture2D:
	if index >= NAMED_BASE:
		return _tex(NAMED_DIR + str(NAMED_IDS[index - NAMED_BASE]) + ".png")
	return _tex(PORTRAIT_DIR + "p%d.png" % index)

## The same worker always gets the same face: it depends only on the name and gender. Clerks use the clerk portrait.
static func portrait_for(name: String, gender: String, profession := "") -> Texture2D:
	return portrait(portrait_index(name, gender, profession))

static func portrait_index(name: String, gender: String, profession := "", candidate := "") -> int:
	var named := named_index(candidate)
	if named >= 0:
		return named
	if profession == "clerk":
		return CLERK
	var pool: Array = FEMALE if gender == "f" else MALE
	return int(pool[absi(name.hash()) % pool.size()])

static func _tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]

## The icon on a small framed tile, the way the cards and lists show it: the 32 px art at exactly 2x (64 px) on a dark rounded plate, so every icon
## is crisp, evenly spaced and the same size, whatever its shape.
static func icon_plate(name: String, art_px := 64.0, pad := 6.0) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.075, 0.055, 0.95)
	s.border_color = Color(0.5, 0.38, 0.22)
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(pad)
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(art_px + pad * 2.0 + 4.0, art_px + pad * 2.0 + 4.0)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(icon_rect(name, art_px))
	return p

## A crisp icon node of a given pixel size.
static func icon_rect(name: String, px: float) -> TextureRect:
	return _rect(icon(name, px < 48.0), px)

static func portrait_rect(index: int, px: float) -> TextureRect:
	return _rect(portrait(index), px)

static func _rect(t: Texture2D, px: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR            # smooth, shaded art (not pixel art): bilinear keeps its edges clean at every size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
