extends SceneTree
## Builds the reusable font resources (assets/fonts/qd_*.tres) from the packaged font files:
##   godot --headless -s tools/make_fonts.gd
## Pixelify Sans (variable weight) = displays/headings, Silkscreen = HUD labels, Nunito Sans (variable weight) = reading text, VT323 = machine readouts.
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
	var out := {
		"qd_display": variation("res://assets/fonts/PixelifySans-Variable.ttf", {"wght": 700}),
		"qd_heading": variation("res://assets/fonts/PixelifySans-Variable.ttf", {"wght": 600}),
		"qd_hud": variation("res://assets/fonts/Silkscreen.ttf", {}),
		"qd_body": variation("res://assets/fonts/NunitoSans-Variable.ttf", {"wght": 500, "opsz": 12}),
		"qd_body_bold": variation("res://assets/fonts/NunitoSans-Variable.ttf", {"wght": 800, "opsz": 12}),
		"qd_mono": variation("res://assets/fonts/VT323-Regular.ttf", {}),
	}
	for k in out:
		var err := ResourceSaver.save(out[k], "res://assets/fonts/%s.tres" % k)
		print("%s -> %d" % [k, err])
	quit()
