extends RefCounted
class_name QuarryBoarding
## Climbing into and out of a machine, the way a person does it, in first person. The camera is the person's head:
##   in   walk up to the cab door (looking at the handle) -> the door swings open -> look down at the step, a foot goes up, the head rises ->
##        duck through the doorway -> sit down and look out through the windscreen -> the door pulls shut with a thunk
##   out  the door opens -> stand up and turn to the doorway -> step down onto the foot step -> down to the ground and look back along the machine
## Everything is eased with Tween sine curves between keyframes (positions and orientations are interpolated, never snapped). Every vehicle with a
## cab (the meta "cab" built by CabInterior) uses the same sequence; the keyframes are computed from that vehicle's own door, steps and seat.

const EYE := 1.65                       ## a standing person's eye height above the ground

static func cab(v) -> Dictionary:
	return v.get_meta("cab", {}) if v != null and v.has_meta("cab") else {}

static func has_cab(v) -> bool:
	return not cab(v).is_empty()

static func _pose(pos: Vector3, look_at: Vector3) -> Transform3D:
	var d := look_at - pos
	if d.length() < 0.001:
		d = Vector3.FORWARD
	return Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), pos)

## Keyframes of climbing in: [[pose, seconds, label], ...] starting from `from`. World space.
static func poses_in(v, from: Transform3D) -> Array:
	var c := cab(v)
	var ref: Node3D = c["ref"]
	var side: float = c["side"]
	var dc: Vector3 = c["door_c"]
	var step: Vector3 = c["step"]
	var out := Vector3(side, 0, 0)                                            # cab space: away from the door
	var ground: float = v.global_position.y
	var door_w := ref.to_global(dc)
	var approach := ref.to_global(dc + out * 1.3)
	approach.y = ground + EYE
	var handle := ref.to_global(dc + Vector3(0, 0.15, 0.12))
	var foot := ref.to_global(Vector3(step.x + side * 0.55, step.y, step.z))     # in front of the step
	foot.y = ground + EYE + (step.y - ground) * 0.15
	var step_top := ref.to_global(step + Vector3(side * 0.12, 0, 0))
	var sill := ref.to_global(Vector3(dc.x + side * 0.28, dc.y, dc.z))
	sill.y = ref.to_global(Vector3(0, dc.y, 0)).y + 0.5
	var eye: Vector3 = ref.to_global(c["eye"])
	var fwd := -ref.global_transform.basis.z
	var in_door := ref.to_global(Vector3(dc.x - side * 0.05, c["eye"].y - 0.04, dc.z))
	return [
		[from, 0.0, "start"],
		[_pose(approach, handle), 0.75, "approach"],
		[_pose(foot, step_top + Vector3(0, -0.15, 0)), 0.55, "look at the step"],
		[_pose(sill + Vector3(0, 0.0, 0), door_w + Vector3(0, 0.2, 0)), 0.5, "foot up"],
		[_pose(in_door, eye + fwd * 1.0), 0.45, "through the doorway"],
		[_pose(eye, eye + fwd * 2.0 + Vector3(0, -0.12, 0)), 0.6, "sit"],
	]

## Climbing out: the reverse, ending at `ground_pose` (the person's normal standing eye).
static func poses_out(v, ground_pose: Transform3D) -> Array:
	var c := cab(v)
	var ref: Node3D = c["ref"]
	var side: float = c["side"]
	var dc: Vector3 = c["door_c"]
	var step: Vector3 = c["step"]
	var eye: Vector3 = ref.to_global(c["eye"])
	var fwd := -ref.global_transform.basis.z
	var door_w := ref.to_global(dc)
	var ground: float = v.global_position.y
	var in_door := ref.to_global(Vector3(dc.x - side * 0.05, c["eye"].y - 0.04, dc.z))
	var sill := ref.to_global(Vector3(dc.x + side * 0.28, dc.y, dc.z))
	sill.y = ref.to_global(Vector3(0, dc.y, 0)).y + 0.5
	var step_top := ref.to_global(step + Vector3(side * 0.12, 0, 0))
	var foot := ref.to_global(Vector3(step.x + side * 0.55, step.y, step.z))
	foot.y = ground + EYE + (step.y - ground) * 0.15
	return [
		[_pose(eye, eye + fwd * 2.0), 0.0, "start"],
		[_pose(in_door, door_w + Vector3(side * 1.0, 0.1, 0)), 0.5, "turn to the door"],
		[_pose(sill, step_top + Vector3(side * 0.3, -0.5, 0)), 0.5, "out onto the sill"],
		[_pose(foot, step_top + Vector3(side * 0.2, -0.45, 0)), 0.5, "down the step"],
		[ground_pose, 0.55, "ground"],
	]

## Plays keyframes on `camera`. `events` maps a keyframe label to a Callable run when that keyframe starts. Returns the tween.
static func play(game, camera: Camera3D, frames: Array, events: Dictionary, finished: Callable) -> Tween:
	var tool = game.player.tool_view
	game.player.scripted_camera = true
	if tool != null:
		tool.visible = false                          # hands are busy with the door and the rail: the tool is out of view
	var tw: Tween = game.create_tween()
	camera.global_transform = frames[0][0]
	for i in range(1, frames.size()):
		var a: Transform3D = frames[i - 1][0]
		var b: Transform3D = frames[i][0]
		var label: String = frames[i][2]
		if events.has(label):
			tw.tween_callback(events[label])
		tw.tween_method(func(w: float): camera.global_transform = a.interpolate_with(b, w), 0.0, 1.0, float(frames[i][1])).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		game.player.scripted_camera = false
		if tool != null:
			tool.visible = true
		finished.call())
	return tw

## The door swinging: opens (`open` true) or shuts, eased; the shutting door thunks at the end.
static func swing_door(game, v, open: bool, secs := 0.5) -> void:
	var c := cab(v)
	if c.is_empty():
		return
	var door: Node3D = c["door"]
	var to: float = float(c["open"]) if open else 0.0
	var tw: Tween = game.create_tween()
	tw.tween_property(door, "rotation:y", to, secs).set_trans(Tween.TRANS_BACK if not open else Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if not open:
		tw.tween_callback(func(): game.sfx["hit_reinforced"].play())
	else:
		game.sfx["hit_pick"].play()

## Turn the key: the key rotates, the dashboard lamps come on (and the gauges' lamps flicker as the starter cranks).
static func key_turn(game, v, on: bool) -> void:
	var c := cab(v)
	if c.is_empty():
		return
	var key: Node3D = c["key"]
	var tw: Tween = game.create_tween()
	tw.tween_property(key, "rotation:z", -0.9 if on else 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): lamps(v, on))

static func lamps(v, on: bool) -> void:
	var c := cab(v)
	for l in c.get("lamps", []):
		var m: StandardMaterial3D = l["mat"]
		var col: Color = l["color"]
		m.albedo_color = col * (1.0 if on else 0.25)
		m.emission_enabled = on
		m.emission = col
		m.emission_energy_multiplier = 1.4 if on else 0.0
