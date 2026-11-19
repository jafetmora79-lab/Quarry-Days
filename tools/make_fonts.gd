extends SceneTree
## Builds the reusable font resources (assets/fonts/qd_*.tres) from the packaged font files:
##   godot --headless -s tools/make_fonts.gd
## Every role uses THE VEIL pixel font (VeilPixel.ttf).
func tag(n: String) -> int:
	return TextServerManager.get_primary_interface().name_to_tag(n)
func variation(base_path: String, axes: Dictionary, spacing := 0) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = load(base_path)
	var d := {}
	for k in axes:
		d[tag(k)] = axes[k]
	fv.variation_opentype = d
	fv.spacing_glyph = spacing
	return fv
func _init() -> void:
	# ONE typeface for every piece of text: THE VEIL's pixel font (assets/fonts/VeilPixel.ttf). It has a single weight, so every role is the same face;
	# the roles stay separate resources so a role can be restyled later without touching the code that uses it.
	var out := {}
	for k in ["qd_display", "qd_heading", "qd_hud", "qd_body", "qd_body_bold", "qd_mono"]:
		out[k] = variation("res://assets/fonts/VeilPixel.ttf", {})
	for k in out:
		var err := ResourceSaver.save(out[k], "res://assets/fonts/%s.tres" % k)
		print("%s -> %d" % [k, err])
	quit()
