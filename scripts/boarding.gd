extends RefCounted
class_name QuarryBoarding
## Climbing into and out of a machine, the way a person does it, in first person. The camera is the person's head:
##   (no climbing animation any more: a short eased camera move to the driver's seat and back out to the ground beside the machine)
## Everything is eased with Tween sine curves between keyframes (positions and orientations are interpolated, never snapped). Every vehicle with a
## cab (the meta "cab" built by CabInterior) uses the same sequence; the keyframes are computed from that vehicle's own door, steps and seat.

static var active := 0                  ## boarding / alighting moves running right now
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

## No climbing: entering is a short camera move from where the person stands to the driver's viewpoint (the DriverCamera marker: the cab's eye), a
## little arc over the sill so it never cuts through the body of the machine. [[pose, seconds, label], ...] in world space.
static func poses_in(v, from: Transform3D) -> Array:
	var c := cab(v)
	var ref: Node3D = c["ref"]
	var eye: Vector3 = ref.to_global(c["eye"])
	var fwd := -ref.global_transform.basis.z
	var mid := from.origin.lerp(eye, 0.55)
	mid.y = maxf(from.origin.y, eye.y) + 0.12
	return [
		[from, 0.0, "start"],
		[_pose(mid, eye + fwd * 1.5), 0.3, "approach"],
		[_pose(eye, eye + fwd * 2.0 + Vector3(0, -0.12, 0)), 0.3, "sit"],
	]

## Getting out: from the seat to the safe spot beside the machine (VehicleExitPoint = where the person's standing eye ends up).
static func poses_out(v, ground_pose: Transform3D) -> Array:
	var c := cab(v)
	var ref: Node3D = c["ref"]
	var eye: Vector3 = ref.to_global(c["eye"])
	var fwd := -ref.global_transform.basis.z
	var mid := eye.lerp(ground_pose.origin, 0.5)
	mid.y = maxf(eye.y, ground_pose.origin.y) + 0.1
	return [
		[_pose(eye, eye + fwd * 2.0), 0.0, "start"],
		[_pose(mid, ground_pose.origin + ground_pose.basis * Vector3(0, 0, -2.0)), 0.3, "turn to the door"],
		[ground_pose, 0.3, "ground"],
	]

## Plays keyframes on `camera`. `events` maps a keyframe label to a Callable run when that keyframe starts. Returns the tween.
static func play(game, camera: Camera3D, frames: Array, events: Dictionary, finished: Callable) -> Tween:
	var tool = game.player.tool_view
	game.player.scripted_camera = true
	active += 1                                       # (the game hides the tool and the hands for as long as a boarding move runs, and while a machine is driven)
	if tool != null:
		tool.hidden_by_vehicle = true
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
		active = maxi(0, active - 1)
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
