extends SceneTree
## Hired workers fidget while idle (look round, wipe the brow), each on their own timing; the idle pose is calm at rest times.
##   godot --headless --fixed-fps 60 -s tests/test_worker_idle.gd
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
	var a := VeilRig.new()
	a._seed = 1.7
	var b := VeilRig.new()
	b._seed = 8.5
	var peak_head := 0.0
	var peak_arm := 0.0
	var rest_ok := true
	var differ := false
	for i in range(0, 1700):
		var t := float(i) * 0.01
		var ga: Dictionary = a._target("idle", "miner", 0.0, t)
		var gb: Dictionary = b._target("idle", "miner", 0.0, t)
		peak_head = maxf(peak_head, absf(float(ga["head"])))
		peak_arm = maxf(peak_arm, float(ga["ru"]))
		if absf(float(ga["w"]) - float(gb["w"])) > 0.2:
			differ = true
	check(peak_head > 4.0, "an idle worker turns their head to look round (%.1f deg)" % peak_head)
	check(peak_arm > 40.0, "and lifts a hand to wipe their brow (%.0f deg)" % peak_arm)
	check(differ, "two workers do not fidget at the same moments")
	var e := VeilRig.new()
	e.elder = true
	var ge: Dictionary = e._target("idle", "miner", 0.0, 0.5)
	check(float(ge["w"]) == 0.0, "Grandpa's own idle is unchanged")
	var calm := a._target("idle", "miner", 0.0, 0.0 - a._seed * 3.1 + 0.5)
	check(float(calm["w"]) == 0.0 and float(calm["ru"]) == 0.0, "between fidgets the idle pose is at rest")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
