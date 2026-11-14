extends SceneTree
## Saves QuarryTheme.theme() as the project's default theme (assets/ui/qd_theme.tres), so every Control that has no theme of its own (tooltips, popups, plain buttons)
## uses the game's fonts, sizes and colours.   godot --headless -s tools/make_theme.gd
func _initialize() -> void:
	var t: Theme = QuarryTheme.theme().duplicate()
	t.default_font_size = QuarryTheme.BODY                         # design (base-canvas) sizes, not the window-fitted ones
	t.set_font_size("font_size", "Button", QuarryTheme.BODY)
	for m in ["default_base", "button_base", "button_grid"]:
		t.remove_meta(m)
	var err := ResourceSaver.save(t, "res://assets/ui/qd_theme.tres")
	print("saved qd_theme.tres: ", err)
	quit()
