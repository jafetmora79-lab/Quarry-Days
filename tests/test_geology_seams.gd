extends SceneTree
## The ground under the quarry is geology, not a layer cake: ore lies in localized seams, lenses, veins and pockets inside the limestone, the loose layers change thickness, and what is
## where is the same every time.   godot --headless -s tests/test_geology_seams.gd

var checks := 0
var failures := []

func check(c: bool, label: String) -> void:
	checks += 1
	if not c:
		failures.append(label)
		printerr("FAIL: " + label)
	else:
		print("PASS: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var g := QuarryGeology.new()
	var g2 := QuarryGeology.new()
	var n := 0
	var cover := {"coal": 0, "iron_ore": 0, "copper_ore": 0, "gold_ore": 0}
	var shallow := {"coal": 0.0, "iron_ore": 0.0, "copper_ore": 0.0, "gold_ore": 0.0}
	var deep := {"coal": -99.0, "iron_ore": -99.0, "copper_ore": -99.0, "gold_ore": -99.0}
	var sigs := {}
	var contiguous := true
	var same := true
	var top_thick := []
	for xi in range(-50, 50):
		for zi in range(-45, 5):
			var x := float(xi) * 2.0
			var z := float(zi) * 2.0
			var L: Array = g.layers_at(x, z)
			if str(L) != str(g2.layers_at(x, z)):
				same = false
			n += 1
			var cur := float(L[0][0])
			var sig := ""
			var seen := {}
			for l in L:
				if absf(float(l[0]) - cur) > 0.0001 or float(l[1]) >= float(l[0]) + 0.0001:
					contiguous = false
				cur = float(l[1])
				var m := str(l[2])
				sig += m.substr(0, 2)
				if cover.has(m):
					seen[m] = true
					deep[m] = maxf(deep[m], float(l[0])) if deep[m] > -98.0 else float(l[0])
					shallow[m] = minf(shallow[m], float(l[1]))
			for m in seen:
				cover[m] += 1
			if absf(cur - g.bed_y) > 0.0001:
				contiguous = false
			sigs[sig] = true
			top_thick.append(float(L[0][0]) - float(L[0][1]))
	check(same, "the same ground gives the same geology every time")
	check(contiguous, "the layers are contiguous from the surface to the bedrock")
	for m in cover:
		var f := float(cover[m]) / float(n)
		check(f > 0.01 and f < 0.55, "%s is a localized body, present under %.0f%% of the ground (not everywhere, not nowhere)" % [m, f * 100.0])
	check(cover["gold_ore"] < cover["coal"], "gold is rarer than coal")
	check(sigs.size() >= 12, "the layer sequence changes from place to place (%d distinct columns)" % sigs.size())
	check(shallow["gold_ore"] <= -12.0, "gold lies deep (down to %.1f m)" % shallow["gold_ore"])
	var mn := 99.0
	var mx := -99.0
	for t in top_thick:
		mn = minf(mn, t)
		mx = maxf(mx, t)
	check(mx - mn > 0.4, "the topsoil changes thickness across the site (%.2f to %.2f m)" % [mn, mx])
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
