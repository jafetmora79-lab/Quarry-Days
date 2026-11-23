extends SceneTree
## Character and tool polish: face frames (blink / talk / brows), head look and eye contact for Walter in the real game, blinking employees,
## per-tool camera kick, and no swings while a menu or dialogue has the input.
##   godot --headless --fixed-fps 60 -s tests/test_character_polish.gd

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

func frames(n: int) -> void:
	for i in range(n):
		await physics_frame

func visit(fa: FaceAnim, talking: bool, seconds: float, smile := false) -> Dictionary:
	var seen := {}
	var steps := int(seconds * 60.0)
	for i in steps:
		fa.update(1.0 / 60.0, talking, smile)
		seen[fa.current] = true
	return seen

func run() -> void:
	# ---- face frames on the real models
	for who in ["Marsh", "Rosa", "Dmitri", "Omar"]:           # (Walter is the Meshy model now: one mesh, no painted face frames)
		var body: Node3D = (load("res://assets/characters/CHR_QD_%s.glb" % who) as PackedScene).instantiate()
		root.add_child(body)
		var fa := FaceAnim.new()
		check(fa.setup(body, who, 3), "%s: face frames load and the head material is found" % who)
		if who == "Marsh":
			var head: MeshInstance3D = body.find_children("*_Head", "MeshInstance3D", true, false)[0]
			var shared_tex: Texture2D = (head.mesh.surface_get_material(0) as StandardMaterial3D).albedo_texture
			var talk := visit(fa, true, 14.0)
			check(talk.has("blink") and talk.has("m1") and talk.has("m2") and (talk.has("brow") or talk.has("browm1")), "Marsh talking: blinks, opens and closes the mouth and raises the brows (%s)" % str(talk.keys()))
			var quiet := visit(fa, false, 14.0)
			var only_rest := true
			for k in quiet:
				only_rest = only_rest and (k == "base" or k == "blink")
			check(quiet.has("blink") and only_rest, "Marsh idle: only blinks (%s)" % str(quiet.keys()))
			var smile := visit(fa, false, 1.0, true)
			check(smile.has("brow") or smile.has("blink"), "a greeting lifts the brows")
			check((head.get_active_material(0) as StandardMaterial3D) != head.mesh.surface_get_material(0) and (head.mesh.surface_get_material(0) as StandardMaterial3D).albedo_texture == shared_tex, "the shared model resource is untouched (own material per character)")
			var t0: Texture2D = (head.get_active_material(0) as StandardMaterial3D).albedo_texture
			fa._apply_frame("m2")
			check((head.get_active_material(0) as StandardMaterial3D).albedo_texture != t0, "changing frame changes the head texture")
		body.queue_free()
	# ---- head look in the rig
	var wb: Node3D = (load("res://assets/characters/CHR_QD_Walter.glb") as PackedScene).instantiate()
	root.add_child(wb)
	var sk: Skeleton3D = wb.find_children("*", "Skeleton3D", true, false)[0]
	var rig := VeilRig.new()
	rig.setup(sk, 1.0)
	for i in 90:
		rig.pose(1.0 / 60.0, "idle", 0.0, "miner", false)
	var head_i := rig.bone("Head")
	var rest_q := sk.get_bone_pose_rotation(head_i)
	rig.look_yaw = 40.0
	for i in 120:
		rig.pose(1.0 / 60.0, "idle", 0.0, "miner", false)
	var look_q := sk.get_bone_pose_rotation(head_i)
	check(rest_q.angle_to(look_q) > 0.25, "the head turns toward where it is told to look (%.2f rad)" % rest_q.angle_to(look_q))
	rig.look_yaw = 0.0
	for i in 200:
		rig.pose(1.0 / 60.0, "idle", 0.0, "miner", false)
	check(sk.get_bone_pose_rotation(head_i).angle_to(rest_q) < 0.12, "and it comes back to rest")
	wb.queue_free()
	# ---- Walter in the real game: eye contact + face
	var game = load("res://Main.tscn").instantiate()
	game.autosave_enabled = false
	game.curfew_enabled = false
	game.introductions_enabled = false
	root.add_child(game)
	await process_frame
	await frames(6)
	if game.walter_dialog:
		game.walter_dialog.skip()
	game.hud.close_card()
	game._cine_tween().kill()
	game._remove_walter()
	await process_frame
	game._spawn_walter(Vector3(0, 0, 40), Vector3.ZERO, "walter")
	game.walter_mode = "waiting"
	game.walter_pose = "idle"
	var w: Node3D = game.walter_node
	check(w != null and w.has_meta("rig"), "Walter spawns with his rig")
	w.rotation.y = 0.0
	game.player.global_position = Vector3(4.0, 0, 40.0)             # to his right (+X), 4 m away
	for i in 90:
		game._walter_tick(1.0 / 60.0)
	var rg: VeilRig = w.get_meta("rig")
	check(absf(rg.look_yaw) > 20.0 and absf(rg.look_yaw) <= 45.0, "he looks at the player, within a natural 45 degrees (%.0f)" % rg.look_yaw)
	# (Walter is the Meshy model now: one fixed painted face, so the mouth and brow frame checks that were here are gone)
	game.walter_pose = "talk"
	for i in 120:
		game._walter_tick(1.0 / 60.0)
	game.walter_pose = "idle"
	for i in 60:
		game._walter_tick(1.0 / 60.0)
	game.player.global_position = Vector3(4.0, 0, 70.0)             # far away: he looks ahead again
	for i in 200:
		game._walter_tick(1.0 / 60.0)
	check(absf(rg.look_yaw) < 1.0, "out of range he stops looking at the player")
	# ---- no swings while input is blocked
	var tv: QuarryToolView = game.player.tool_view
	game.menu = "sell"
	check(not game.gameplay_input_allowed() and not game._mine_button_down(), "an open menu blocks the mining button")
	game.menu = ""
	game.player.locked = true
	check(not game._mine_button_down(), "a locked player (dialogue, Quarry OS, cinematic) blocks the mining button")
	game.player.locked = false
	# ---- the camera kick follows the tool
	tv.equip(0, true)
	game.player.kick = 0.0
	game.player.impact_feedback(1.0)
	var hammer_kick: float = game.player.kick
	tv.equip(2, true)
	game.player.kick = 0.0
	game.player.impact_feedback(1.0)
	var pick_kick: float = game.player.kick
	check(hammer_kick > 0.0 and hammer_kick < pick_kick * 0.6, "the hammer barely shakes the camera, the heavy pick more (%.4f vs %.4f)" % [hammer_kick, pick_kick])
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
