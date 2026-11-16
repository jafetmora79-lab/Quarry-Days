extends HBoxContainer
class_name QuarryHotbar
## The tool hotbar: five compact slots along the bottom centre. Each shows its number and a picture of the real item (a cached thumbnail rendered
## from the game's own 3D model, see ItemThumbs); the one in hand has an amber border. A slot with no item stays empty. While a picture is
## still being made (or cannot be made, as in the headless test runner) the slot shows the item's name in small letters instead of any
## substitute drawing, so it never shows the wrong item.

const SLOT := Vector2(48, 48)
const COUNT := 5
var thumbs: ItemThumbs                       ## set by the HUD
var _sig := ""
var _slots: Array = []
var _cur := 0

func _init() -> void:
	name = "Hotbar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	alignment = BoxContainer.ALIGNMENT_CENTER

## slots: Array of {name, kind, key (model key of the item)}; cur: index in hand. Fewer than five leaves the rest empty.
func set_slots(slots: Array, cur: int) -> void:
	_slots = slots
	_cur = cur
	var sig := str(cur) + "|" + str(slots) + "|" + str(thumbs.cache.keys() if thumbs != null else [])
	if sig == _sig:
		return
	_sig = sig
	for c in get_children():
		remove_child(c)
		c.queue_free()
	for i in range(COUNT):
		var item: Dictionary = slots[i] if i < slots.size() else {}
		var on := i == cur and not item.is_empty()
		var p := PanelContainer.new()
		p.name = "Slot%d" % (i + 1)
		p.custom_minimum_size = SLOT
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.22, 0.16, 0.06, 0.78) if on else Color(0.045, 0.04, 0.035, 0.6)
		sb.border_color = Color(1.0, 0.82, 0.36) if on else Color(0.95, 0.74, 0.32, 0.28)
		sb.set_border_width_all(2 if on else 1)
		sb.set_corner_radius_all(3)
		sb.set_content_margin_all(2)
		p.add_theme_stylebox_override("panel", sb)
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.custom_minimum_size = SLOT - Vector2(4, 4)
		p.add_child(holder)
		var key := Label.new()
		key.name = "Key"
		key.text = str(i + 1)
		key.add_theme_font_override("font", QuarryTheme.hud())
		key.add_theme_font_size_override("font_size", QuarryTheme.pixel_font_size(QuarryTheme.SMALL))
		key.add_theme_color_override("font_color", Color(1, 0.86, 0.45) if on else Color(0.8, 0.72, 0.58, 0.8))
		key.position = Vector2(3, 0)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(key)
		if not item.is_empty():
			p.tooltip_text = str(item.get("name", ""))
			var tex: Texture2D = null
			var mk := str(item.get("key", ""))
			if thumbs != null and mk == "ramp_plan":
				tex = thumbs.get_thumb("tool:ramp_miniature", Callable(QuarryHotbar, "ramp_miniature"))      # the item is a ramp: its picture is a little ramp
			elif thumbs != null and mk != "":
				tex = thumbs.get_thumb("tool:" + mk, func(): return ToolModels.load_tool(mk))
			if tex != null:
				var tr := TextureRect.new()
				tr.name = "Icon"
				tr.texture = tex
				tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				tr.offset_top = 3
				holder.add_child(tr)
			else:
				var nm := Label.new()                 # the labelled stand-in while the picture is made (never a different item's picture)
				nm.name = "Name"
				nm.text = str(item.get("name", "")).to_upper()
				nm.add_theme_font_override("font", QuarryTheme.hud())
				nm.add_theme_font_size_override("font_size", QuarryTheme.pixel_font_size(QuarryTheme.SMALL))
				nm.add_theme_color_override("font_color", Color(0.9, 0.82, 0.62, 0.85))
				nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				nm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				nm.offset_top = 8
				nm.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
				nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
				holder.add_child(nm)
			var q := int(item.get("qty", 0))
			if q > 0:
				var ql := Label.new()
				ql.name = "Qty"
				ql.text = str(q)
				ql.add_theme_font_override("font", QuarryTheme.hud())
				ql.add_theme_font_size_override("font_size", QuarryTheme.pixel_font_size(QuarryTheme.SMALL))
				ql.add_theme_color_override("font_color", Color(1, 1, 1))
				ql.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
				ql.offset_left = -20
				ql.offset_top = -14
				ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				ql.mouse_filter = Control.MOUSE_FILTER_IGNORE
				holder.add_child(ql)
		add_child(p)

## A thumbnail landed: rebuild the slots so it shows.
func refresh() -> void:
	_sig = ""
	set_slots(_slots, _cur)

## A miniature haul ramp (a wedge of packed earth with hazard-yellow edge rails and a striped marker post) for the ramp item's picture.
static func ramp_miniature() -> Node3D:
	var root := Node3D.new()
	var A := Vector3(-0.6, 0.0, -0.9)
	var B := Vector3(0.6, 0.0, -0.9)
	var C := Vector3(0.6, 0.0, 0.9)
	var D := Vector3(-0.6, 0.0, 0.9)
	var E := Vector3(-0.6, 0.55, 0.9)
	var F := Vector3(0.6, 0.55, 0.9)
	var earth := MeshKit.Soup.new()
	earth.quad(A, B, F, E)
	earth.quad(D, C, F, E)
	earth.tri(A, D, E)
	earth.tri(B, C, F)
	var mi := MeshInstance3D.new()
	mi.mesh = earth.mesh()
	var em := MeshKit.flat(Color(0.62, 0.45, 0.30)).duplicate() as StandardMaterial3D
	em.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = em
	root.add_child(mi)
	var slope := atan2(0.55, 1.8)
	for sx in [-0.56, 0.56]:
		var rail := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.1, 0.07, 1.9)
		rail.mesh = bm
		rail.position = Vector3(sx, 0.32, 0.0)
		rail.rotation.x = -slope
		rail.material_override = MeshKit.flat(Color(0.95, 0.76, 0.12))
		root.add_child(rail)
	for k in range(3):                                    # tread bars across the surface
		var z := -0.5 + 0.5 * k
		var bar := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(1.0, 0.04, 0.1)
		bar.mesh = bb
		bar.position = Vector3(0.0, (z + 0.9) / 1.8 * 0.55 + 0.03, z)
		bar.rotation.x = -slope
		bar.material_override = MeshKit.flat(Color(0.40, 0.29, 0.19))
		root.add_child(bar)
	var post := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.08, 0.5, 0.08)
	post.mesh = pm
	post.position = Vector3(0.45, 0.8, 0.8)
	post.material_override = MeshKit.flat(Color(0.95, 0.95, 0.9))
	root.add_child(post)
	var cap := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.09, 0.14, 0.09)
	cap.mesh = cm
	cap.position = Vector3(0.45, 0.95, 0.8)
	cap.material_override = MeshKit.flat(Color(0.85, 0.2, 0.15))
	root.add_child(cap)
	return root
