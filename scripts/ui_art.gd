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

static func icon(name: String) -> Texture2D:
	return _tex(ICON_DIR + name + ".png")

static func has_icon(name: String) -> bool:
	return ResourceLoader.exists(ICON_DIR + name + ".png")

static func portrait(index: int) -> Texture2D:
	return _tex(PORTRAIT_DIR + "p%d.png" % index)

## The same worker always gets the same face: it depends only on the name and gender. Clerks use the clerk portrait.
static func portrait_for(name: String, gender: String, profession := "") -> Texture2D:
	return portrait(portrait_index(name, gender, profession))

static func portrait_index(name: String, gender: String, profession := "") -> int:
	if profession == "clerk":
		return CLERK
	var pool: Array = FEMALE if gender == "f" else MALE
	return int(pool[absi(name.hash()) % pool.size()])

static func _tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]

## A crisp icon node of a given pixel size.
static func icon_rect(name: String, px: float) -> TextureRect:
	return _rect(icon(name), px)

static func portrait_rect(index: int, px: float) -> TextureRect:
	return _rect(portrait(index), px)

static func _rect(t: Texture2D, px: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
