extends SceneTree
var fails := 0
var n := 0
func check(c: bool, m: String) -> void:
	n += 1
	if not c:
		fails += 1
		print("FAIL: ", m)
func _init() -> void:
	for nm in ["panel_main", "btn_primary", "btn_main", "btn_danger", "btn_disabled", "frame_dialog", "bar_groove", "bar_fill_green", "keycap_small", "keycap_wide"]:
		check(UiSkin.has(nm), "art exists: " + nm)
		check(UiSkin.box(nm, null) is StyleBoxTexture, "skin box: " + nm)
	var fb := StyleBoxFlat.new()
	check(UiSkin.box("no_such_piece", fb) == fb, "missing art falls back to flat style")
	var d := DirAccess.get_files_at("res://assets/ui/hud/icons")
	check(d.size() >= 100, "icons are present")
	print("RESULT: %d checks, %d failures" % [n, fails])
	quit(1 if fails else 0)
