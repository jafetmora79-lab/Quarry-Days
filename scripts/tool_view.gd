extends Node3D
class_name QuarryToolView
## First-person tool models (built with MeshKit in THE VEIL style) and their animation.
##  * Swing tools (hammer, pickaxes): wind-up -> fast strike -> recover. `swing()` calls `on_impact`
##    exactly when the head reaches the rock, so damage, sound and effects land on the visible hit.
##  * Power tools (drill, jackhammer): `operating` drives a continuous spin / hammer loop with vibration;
##    they ease in and out instead of snapping.
## Walking adds a gentle bob; equipping a new tool lowers the old one and raises the new one.

var tier := -1
var models := {}
var pivot: Node3D          # grip point the swing rotates around
var model: Node3D
var spinner: Node3D        # drill bit / jackhammer chisel / hammer ram
var lever: Node3D          # the hand splitter's lever
var phase := -1.0          # 0..1 while swinging, -1 idle
var duration := 0.5
var impact_done := true
var on_impact: Callable
var operating := false
var op_blend := 0.0
var equip_t := 1.0
var pending_tier := -1
var deflect_t := 0.0
var bob_t := 0.0
var moving := 0.0
var _t := 0.0
var kick_scale := 1.0        ## how hard this tool's blows shake the camera (the hammer barely, the heavy pick most): see Player.impact_feedback
var obstruct := 0.0         ## 0..1 set by the game: something solid (a wall, a desk) is right in front, so the tool is tucked down and back instead of poking through it
var _obs := 0.0
var shock := 0.0            ## 1 at the moment of a blow, decays: the tool shudders in the hands
var _slide := 0.0           ## how far the off hand has slid along the shaft (m, model space)
var suppressed := false     ## the game keeps the tool out of sight (at the computer): other code that shows or hides it respects this
var hands_rig: FPHands      ## the shared hands (see FPHands / FPTools): the tool decides where they close
var key := ""               ## model key of the tool in hand (ToolModels.key_of)
var _grips: Array = []
var payload: Node3D         ## the soil on the shovel's blade (ShovelPayload); null for other tools
var payload_res := ""       ## what is on the blade right now (set when a strike really collected something)
var _prev_rot := Vector3.ZERO
var _prev_off := Vector3.ZERO
var _from_rot := Vector3.ZERO
var _from_off := Vector3.ZERO
var _blend := 1.0           ## 0..1 blend from the pose we were in when a swing began (no snapping)
var _pause := 0.0           ## the short hold at the moment of a heavy impact
var tip_t := -1.0           ## the bucket tipping out (0..1), -1 idle
var throw_t := -1.0         ## the throw of the bag's stones into a bucket (0..1), -1 idle
var carry_load := 0.0       ## 0..1: how full the carried bucket is (its weight sags the pose)
var _clods: Array = []      ## soil leaving the blade: [{node, vel, life}]
signal payload_dumped(res: String)

## Per-tool first-person pose. Camera space: -Z is forward, +X right, +Y up. Swing tools hold their handle along +Y
## from the grip; `rest`/`wind`/`strike` are pitch angles (rad) about the grip (negative = working end forward).
## `tip` is the working point in model space: the pick point, the hammer face, the bit or chisel end.
## Power tools use `rest_rot` (euler) to aim their working end at the crosshair, and `model_pitch` leans the whole model.
const TOOL := {
	0: {"pause": 0.04, "rest_roll": -0.3, "grip": Vector3(0.22, -0.4, -0.5), "scale": 0.8, "rest": -0.95, "yaw": -0.2, "wind": 0.0, "strike": -1.35, "follow": 0.025, "roll": 0.06, "lunge": 0.55, "kick": 0.5, "tip": Vector3(0, 0.36, -0.1)},        # the hammer: a short, compact, controlled blow
	1: {"pause": 0.035, "rest_roll": -0.25, "grip": Vector3(0.2, -0.42, -0.5), "scale": 0.8, "rest": -1.2, "yaw": 0.55, "wind": 0.2, "lift": 0.03, "strike": -1.35, "follow": 0.11, "roll": 0.24, "lunge": 1.15, "kick": 1.0, "tip": Vector3(0, 0.48, -0.27)},    # the pickaxe: a higher overhead arc with a follow-through
	2: {"pause": 0.035, "rest_roll": -0.25, "grip": Vector3(0.2, -0.42, -0.5), "scale": 0.75, "rest": -1.2, "yaw": 0.55, "wind": 0.3, "lift": 0.05, "strike": -1.35, "follow": 0.13, "roll": 0.26, "lunge": 1.2, "kick": 1.15, "tip": Vector3(0, 0.52, -0.32)},    # reinforced: the heaviest wind-up
	3: {"grip": Vector3(0.28, -0.3, -0.5), "scale": 0.7, "power": true, "spin": "rotate", "amp": 0.006, "rest_rot": Vector3(0.12, 0.2, 0.0), "tip": Vector3(0, 0.12, -0.54)},
	4: {"grip": Vector3(0.3, -0.12, -0.5), "scale": 0.7, "power": true, "spin": "pump_y", "amp": 0.014, "rest_rot": Vector3(0.0, 0.3, 0.0), "model_pitch": 0.8, "tip": Vector3(0, -0.61, 0)},
}
const REACH_MIN := 0.85      # the working end meets the rock this far in front of the camera, at least...
const REACH_MAX := 1.6       # ...and at most (mining reach in main.gd is just beyond this)
const MAX_CORRECTION := 0.34

var target_dist := 1.2       # distance to the rock under the crosshair (set by the game when engaged)
var tip_cam := Vector3.ZERO  # working end in camera space after the last update (for tests)
var engage := 0.0            # 0..1 how much the working end is pulled onto the crosshair point

func _ready() -> void:
	pivot = Node3D.new()
	add_child(pivot)
	hands_rig = FPHands.new()
	pivot.add_child(hands_rig)

## The pose definition of a tool tier: the five ladder tools, or one of the Phase 9 tools (tier >= GearModels.TIER_BASE).
func _def(t: int) -> Dictionary:
	if t >= GearModels.TIER_BASE:
		var d: Dictionary = GearModels.SWING.duplicate()
		d.merge(GearModels.POSE.get(GearModels.id_of(t), {}), true)
		return d
	return TOOL.get(t, TOOL[0])

func equip(t: int, instant := false) -> void:
	if t == tier and pending_tier < 0:
		return
	if instant or tier < 0:
		_show(t)
		equip_t = 1.0
		return
	if pending_tier == t:
		return                                   # already swapping to it (the game asks every frame: never restart the swap)
	pending_tier = t
	equip_t = 0.0

func _show(t: int) -> void:
	tier = t
	kick_scale = float(_def(t).get("kick", 1.0))
	pending_tier = -1
	for k in models:
		models[k].visible = false
	if not models.has(t):
		models[t] = _build(t)
		pivot.add_child(models[t])
	model = models[t]
	model.scale = Vector3.ONE * float(_def(t).get("scale", 1.0))
	model.visible = true
	key = ToolModels.key_of(t)
	_grips = FPTools.grips(key)
	payload = null
	payload_res = ""
	if key == "shovel":
		payload = model.get_meta("payload") if model.has_meta("payload") else ShovelPayload.attach(model)
	spinner = model.get_meta("spinner") if model.has_meta("spinner") else null
	lever = model.get_meta("lever") if model.has_meta("lever") else null
	phase = -1.0
	impact_done = true

func is_busy() -> bool:
	return phase >= 0.0

## Starts one swing lasting `d` seconds; `impact` fires at the strike moment.
func swing(d: float, impact: Callable) -> void:
	duration = maxf(0.2, d * float(_def(tier).get("visual_scale", 1.0)))
	_from_rot = _prev_rot
	_from_off = _prev_off
	_blend = 0.0                                   # the new swing grows out of whatever pose the last one left (no snapping)
	if payload_res != "":
		_dump_payload(false)                       # a new dig starts: whatever was still on the blade falls off
	phase = 0.0
	impact_done = false
	on_impact = impact

## The strike really collected `res`: it sits on the blade from the moment the blade leaves the ground until it is tipped off. Only the shovel shows a payload.
func set_payload(res: String) -> void:
	if payload == null or res == "":
		return
	payload_res = res
	ShovelPayload.fill(payload, res)
	payload.visible = false

func has_payload() -> bool:
	return payload_res != ""

## The load leaves the blade: a few clods fall away from it (`animated`), the heap disappears.
func _dump_payload(animated: bool) -> void:
	var res := payload_res
	payload_res = ""
	if payload != null:
		if animated and payload.visible:
			var from := to_local(payload.global_position)
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			var mat := MeshKit.mat(BucketView.MATS.get(res, "ExcavatedDirt"))
			for i in range(7):
				var m := MeshInstance3D.new()
				m.mesh = MeshKit.box(Vector3.ONE * rng.randf_range(0.018, 0.034))
				m.material_override = mat
				m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(m)
				m.position = from + Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(0.0, 0.04), rng.randf_range(-0.05, 0.02))
				_clods.append({"node": m, "vel": Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.2, 0.1), rng.randf_range(-0.7, -0.25)), "life": 0.5})
		payload.visible = false
	payload_dumped.emit(res)

## The bucket in hand tips out (called when its load goes into the box or the hopper): it rotates about the hand on the bail and comes back.
func tip_bucket() -> void:
	tip_t = 0.0

## The toss of stones from the bag (the hand dips to the hip and swings out).
func throw_motion() -> void:
	throw_t = 0.0

## Tool bounces off rock that is too hard.
func deflect() -> void:
	deflect_t = 0.3

func _process(delta: float) -> void:
	_t += delta
	var target := 1.0 if operating else 0.0
	op_blend = move_toward(op_blend, target, delta * (6.0 if operating else 3.0))
	if pending_tier >= 0:
		equip_t += delta * 3.2
		if equip_t >= 0.5 and pending_tier >= 0 and tier != pending_tier:
			_show(pending_tier)
			equip_t = 0.5
		elif equip_t >= 0.5:
			pending_tier = -1
	elif equip_t < 1.0:
		equip_t = minf(1.0, equip_t + delta * 3.2)
	var lower := sin(clampf(equip_t, 0.0, 1.0) * PI) * 0.45 # 0 -> dip -> 0
	bob_t += delta * (2.0 + 7.0 * moving)
	var bob := Vector3(cos(bob_t) * 0.012, absf(sin(bob_t)) * 0.016, 0) * (0.3 + moving)
	var def: Dictionary = _def(tier)
	var is_power: bool = bool(def.get("power", false))
	var base: Vector3 = def["grip"]
	var rot := Vector3.ZERO
	var off := Vector3.ZERO
	var rest: float = def.get("rest", 0.0)
	var weight := 0.0
	var strike_p := -1.0
	if not is_power:
		rot.x = rest
		rot.y = float(def.get("yaw", 0.0))
		rot.z = float(def.get("rest_roll", 0.0))                      # the handle leans toward the middle of the screen (the reference pose)
		if phase >= 0.0:
			if _pause > 0.0:
				_pause -= delta                                  # the hold at the moment of a heavy impact
			else:
				phase += delta / duration
			var p := phase
			strike_p = p
			var wind: float = def["wind"]
			var strike: float = def["strike"]
			var ang := rest
			var scoop: bool = str(def.get("style", "")) == "scoop"
			var scoop_roll := 0.0
			var lg := float(def.get("lunge", 1.0))            # how far the head lunges forward into the blow
			if scoop:
				var sp := _scoop_pose(p, rest)
				ang = sp["ang"]
				off = sp["off"]
				weight = sp["weight"]
				scoop_roll = sp["roll"]
				if payload_res != "" and payload != null:
					payload.visible = p >= 0.38 and p < 0.8                           # on the blade from the moment it leaves the soil, until it is tipped off
					if p >= 0.8:
						_dump_payload(true)
			elif p < 0.42:                                  # wind-up: ease out, working end goes up and back
				var a := p / 0.42
				ang = lerpf(rest, wind, 1.0 - pow(1.0 - a, 3.0))
				off = Vector3(0.0, 0.07 + float(def.get("lift", 0.0)), -0.10 * lg) * a
			elif p < 0.58:                                # strike: accelerate onto the rock
				var a := (p - 0.42) / 0.16
				ang = lerpf(wind, strike, a * a)
				off = Vector3(0.0, lerpf(0.07 + float(def.get("lift", 0.0)), -0.03, a), lerpf(-0.10 * lg, -0.12 * lg, a))
				weight = a * a
			else:                                         # recover: ease back with a small settle
				var a := clampf((p - 0.58) / 0.42, 0.0, 1.0)
				var e := 1.0 - pow(1.0 - a, 3.0)
				ang = lerpf(strike, rest, e) + sin(a * PI) * float(def.get("follow", 0.05))        # the head carries on past the rock before it comes back
				off = Vector3(0.0, -0.03, -0.12 * lg).lerp(Vector3.ZERO, e)
				weight = 1.0 - clampf(a * 2.0, 0.0, 1.0)
			if p >= float(def.get("impact_p", 0.58)) and not impact_done:
				impact_done = true
				shock = 1.0
				_pause = float(def.get("pause", 0.0))
				if on_impact.is_valid():
					on_impact.call()
			rot.x = ang
			rot.y = float(def.get("yaw", 0.0)) * (1.0 - 0.7 * weight)
			rot.z = float(def.get("rest_roll", 0.0)) + (scoop_roll if scoop else float(def.get("roll", 0.2)) * sin(clampf(p, 0.0, 1.0) * PI))
			if phase >= 1.0:
				phase = -1.0
				if payload_res != "":
					_dump_payload(false)
	else:
		var rr: Vector3 = def["rest_rot"]
		rot = rr
	# equip / unequip: the tool tips toward the player as it drops out of view and comes back up level; a slow breath of sway while it is held;
	# a short shudder through the handle after every blow
	if _blend < 1.0:                                      # grow out of the previous pose
		_blend = minf(1.0, _blend + delta / 0.16)
		var bk := _blend * _blend * (3.0 - 2.0 * _blend)
		rot = _from_rot.lerp(rot, bk)
		off = _from_off.lerp(off, bk)
	if str(def.get("style", "")) == "carry":
		var sag := carry_load
		off.y -= 0.035 * sag
		rot.z += 0.06 * sag + sin(bob_t * 0.5) * 0.05 * moving * (0.4 + sag)             # a heavy bucket hangs lower and swings with the steps
		if tip_t >= 0.0:
			tip_t += delta / 0.9
			var tp := sin(clampf(tip_t, 0.0, 1.0) * PI)
			rot.z += -1.9 * tp * tp                                                       # tips about the hand on the bail
			off += Vector3(-0.04, 0.04, -0.06) * tp
			if tip_t >= 1.0:
				tip_t = -1.0
	if throw_t >= 0.0:                                    # the reach to the bag and the toss: dip, swing out, back
		throw_t += delta / 0.6
		var tk := sin(clampf(throw_t, 0.0, 1.0) * PI)
		rot.x += 0.55 * tk
		rot.z += -0.25 * tk
		off += Vector3(0.1, -0.14, 0.04) * tk
		if throw_t >= 1.0:
			throw_t = -1.0
	_prev_rot = rot
	_prev_off = off
	rot.x += lower * 1.0
	rot.z += lower * 0.35
	shock = maxf(0.0, shock - delta * 5.0)
	if not is_power:
		rot.z += sin(_t * 1.3) * 0.012 * (1.0 - moving) * (1.0 if phase < 0.0 else 0.0)
		off.y += sin(_t * 1.7) * 0.003 * (1.0 - moving)                                   # breathing
		rot.x += sin(_t * 1.7 + 0.6) * 0.004 * (1.0 - moving)
		rot.x += sin(_t * 75.0) * 0.03 * shock * shock
		off += Vector3(0.0, 0.01, 0.03) * shock * shock                                   # the blow's recoil comes back through the hands
	else:
		off.y += sin(_t * 1.7) * 0.002 * (1.0 - op_blend)
	_pose_hands(def, strike_p, delta)
	_obs = move_toward(_obs, obstruct, delta * 5.0)          # eased both ways: no pop when a wall comes or goes
	if _obs > 0.0:
		rot.x += 0.45 * _obs
		off += Vector3(0.03, -0.14, 0.14) * _obs
	if deflect_t > 0.0:
		deflect_t = maxf(0.0, deflect_t - delta)
		rot.x += sin(deflect_t / 0.3 * PI) * 0.5
		off += Vector3(0, 0.04, 0.06) * sin(deflect_t / 0.3 * PI)
	if lever:        # the hand splitter: the lever is pulled down and let up with every press
		var pull := 0.0
		if phase >= 0.0:
			pull = sin(clampf(phase, 0.0, 1.0) * PI)
		lever.rotation.x = -0.15 + pull * 0.55
	# power tools: vibration and push while running; the working end eases onto the crosshair point
	if is_power:
		var v := op_blend
		var amp := float(def.get("amp", 0.01))
		var spin := str(def.get("spin", "rotate"))
		off += Vector3(sin(_t * 91.0) * amp, sin(_t * 113.0) * amp * (2.2 if spin == "pump_y" else 1.0), -0.04 * v) * v
		weight = v * 0.85
		if phase >= 0.0:        # a powered tool that works in blows (the powered hammer): a lunge at the rock, the ram slams home
			phase += delta / duration
			var kick := sin(clampf(phase, 0.0, 1.0) * PI)
			off += Vector3(0.0, -0.01 * kick, -0.10 * kick)
			weight = maxf(weight, kick)
			if phase >= 0.5 and not impact_done:
				impact_done = true
				shock = 1.0
				if on_impact.is_valid():
					on_impact.call()
			if phase >= 1.0:
				phase = -1.0
			elif spinner and str(def.get("spin", "")) == "pump_z":
				spinner.position.z = -0.33 - 0.1 * kick
		if spinner:
			match spin:
				"rotate": spinner.rotate_z(delta * 40.0 * v)
				"pump_y": spinner.position.y = -0.42 - absf(sin(_t * 56.0)) * 0.035 * v
				"pump_z":
					if phase < 0.0:
						spinner.position.z = -0.33 - absf(sin(_t * 48.0)) * 0.05 * v
	if model and model.has_meta("striker"):
		_pose_striker(model.get_meta("striker"), strike_p)
	pivot.rotation = rot
	var placed := base + bob + off + Vector3(0, -lower, 0)
	# working end in camera space, then pull it toward the point on the crosshair ray where the rock is
	var tip_local: Vector3 = def["tip"]
	var tip_now := placed + pivot.transform.basis * (model.transform * tip_local) if model else placed
	var contact := Vector3(0, 0, -clampf(target_dist, REACH_MIN, REACH_MAX))
	var corr := (contact - tip_now)
	var cap := float(def.get("engage_cap", MAX_CORRECTION)) if not is_power else 0.1 # power tools stay in the hands: only a small nudge toward the rock
	if corr.length() > cap:
		corr = corr.normalized() * cap
	engage = weight
	position = placed + corr * weight
	tip_cam = tip_now + corr * weight
	_update_clods(delta)
	_pose_rig(def)

# ------------------------------------------------------------------ models (handle along +Y from the grip)

func _box(s: MeshKit.Soup, c: Vector3, size: Vector3, taper := Vector2.ONE) -> void:
	MeshKit.box_into(s, c, size, taper)

func _build(t: int, with_hands := true) -> Node3D:
	var bm := ToolModels.load_tool(ToolModels.key_of(t))
	if bm != null:                                 # the Blender-built model of this tool (tools/tool_models/build_tools.py)
		if t == 4 or GearModels.id_of(t) == "pneumatic_chisel":
			bm.rotation.x = float(_def(t).get("model_pitch", 0.0))      # the jackhammers lean forward so the chisel points down-range at the rock
		bm.rotation.y = float(_def(t).get("twist", 0.0))                # a twist about the handle (the shovel shows the face of its blade)
		if with_hands:
			_add_hands(bm, t)
		if GearModels.id_of(t) in ["pointed_chisel", "flat_chisel"]:
			_add_striker(bm, t)
		return bm
	if t >= GearModels.TIER_BASE:                  # Phase 9 tools: their own models
		var gn := GearModels.build_tool(GearModels.id_of(t))
		gn.rotation.x = float(_def(t).get("model_pitch", 0.0))      # the pneumatic chisel leans forward like the jackhammer
		_add_hands(gn, t)
		if GearModels.id_of(t) in ["pointed_chisel", "flat_chisel"]:
			_add_striker(gn, t)
		for gi in gn.find_children("*", "GeometryInstance3D", true, false):
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return gn
	if t >= 1 and t <= 3:                          # worn pickaxe, reinforced pickaxe, corded drill: upgraded models
		var ln := GearModels.build_ladder(t)
		_add_hands(ln, t)
		for gi in ln.find_children("*", "GeometryInstance3D", true, false):
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return ln
	var n := Node3D.new()
	n.name = "Tool%d" % t
	var wood := MeshKit.Soup.new()
	var steel := MeshKit.Soup.new()
	var paint := MeshKit.Soup.new()
	var dark := MeshKit.Soup.new()
	var paint_key := "PaintYellow"
	match t:
		0: # rock hammer: short handle, square steel head
			_box(wood, Vector3(0, 0.15, 0), Vector3(0.035, 0.36, 0.04))
			_box(steel, Vector3(0, 0.36, -0.01), Vector3(0.07, 0.08, 0.17))
			_box(dark, Vector3(0, 0.0, 0), Vector3(0.045, 0.1, 0.05))   # grip tape
		1: # basic pickaxe
			_box(wood, Vector3(0, 0.22, 0), Vector3(0.035, 0.56, 0.04))
			var prof := PackedVector2Array([Vector2(-0.27, -0.02), Vector2(-0.03, 0.03), Vector2(0.03, 0.03), Vector2(0.27, -0.02), Vector2(0.2, -0.045), Vector2(0.0, -0.015), Vector2(-0.2, -0.045)])
			MeshKit.extrude_into(steel, prof, 0.045, Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0))) # profile is in (z, y): the points run fore and aft
		2: # reinforced pickaxe: longer, steel collars, painted head with hardened tips
			_box(wood, Vector3(0, 0.24, 0), Vector3(0.04, 0.6, 0.045))
			for y in [0.06, 0.38]:
				_box(steel, Vector3(0, y, 0), Vector3(0.05, 0.035, 0.055))
			var prof := PackedVector2Array([Vector2(-0.32, -0.03), Vector2(-0.04, 0.04), Vector2(0.04, 0.04), Vector2(0.32, -0.03), Vector2(0.24, -0.06), Vector2(0.0, -0.02), Vector2(-0.24, -0.06)])
			MeshKit.extrude_into(paint, prof, 0.06, Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0)))
			_box(steel, Vector3(0, 0.52, -0.31), Vector3(0.05, 0.05, 0.06))
			_box(steel, Vector3(0, 0.52, 0.31), Vector3(0.05, 0.05, 0.06))
			paint_key = "PaintRed"
		3: # power drill: pistol grip, body pointing forward (-Z), chuck + spinning bit
			_box(paint, Vector3(0, 0.12, -0.04), Vector3(0.1, 0.13, 0.3))
			_box(dark, Vector3(0, 0.0, 0.05), Vector3(0.07, 0.17, 0.08), Vector2(0.9, 0.9))
			_box(paint, Vector3(0, -0.1, 0.06), Vector3(0.11, 0.06, 0.14))      # battery
			_box(steel, Vector3(0, 0.12, -0.22), Vector3(0.07, 0.07, 0.07))      # chuck
		4: # jackhammer: tall body, T-handle on top, chisel down
			_box(steel, Vector3(0, 0.0, 0), Vector3(0.36, 0.05, 0.05))           # T-handle
			for x in [-0.15, 0.15]:
				_box(dark, Vector3(x, 0.0, 0), Vector3(0.09, 0.065, 0.065))
			_box(paint, Vector3(0, -0.22, 0), Vector3(0.14, 0.36, 0.14), Vector2(0.85, 0.85))
			_box(steel, Vector3(0, -0.06, 0.08), Vector3(0.08, 0.1, 0.06))      # valve block
			paint_key = "PaintRed"
	for pair in [[wood, QuarryArt.M_WOOD], [steel, "SteelPlate"], [paint, paint_key], [dark, QuarryArt.M_RUBBER]]:
		var s: MeshKit.Soup = pair[0]
		if s.verts.size() > 0:
			MeshKit.inst(n, s.mesh(), MeshKit.mat(pair[1]))
	if t == 3:
		var bit := Node3D.new()
		bit.position = Vector3(0, 0.12, -0.25)
		n.add_child(bit)
		var b := MeshKit.Soup.new()
		MeshKit.frustum_into(b, Vector3.ZERO, 0.014, 0.004, 0.2, 5, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO))
		_box(b, Vector3(0, 0, -0.1), Vector3(0.03, 0.006, 0.18))            # flute (shows rotation)
		MeshKit.inst(bit, b.mesh(), MeshKit.mat("SteelPlate"))
		n.set_meta("spinner", bit)
	elif t == 4:
		var chisel := Node3D.new()
		chisel.position = Vector3(0, -0.42, 0)
		n.add_child(chisel)
		var c := MeshKit.Soup.new()
		_box(c, Vector3(0, -0.08, 0), Vector3(0.035, 0.22, 0.035), Vector2(0.4, 0.4))
		MeshKit.inst(chisel, c.mesh(), MeshKit.mat("SteelPlate"))
		n.set_meta("spinner", chisel)
		n.rotation.x = float(TOOL[4]["model_pitch"]) # lean the body forward so the chisel points down-range at the rock
	if with_hands:
		_add_hands(n, t)
	for gi in n.find_children("*", "GeometryInstance3D", true, false):
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


# ------------------------------------------------------------------ hands and forearms

## Where the fists close on each tool (model space: handle along +Y from the grip) and which way the forearm runs to
## the screen edge (camera space, -Z is forward). Hands and sleeves are children of the model, so they swing, bob and
## vibrate with it and the tool is always visibly held. Single grip on the hammer; two hands on the pickaxes, the drill
## (pistol grip + body) and the jackhammer (T-handle).
const HAND_R_DIR := Vector3(0.62, -0.74, 0.12)
const HAND_L_DIR := Vector3(-0.62, -0.74, 0.12)
const HANDS := {
	0: [["R", Vector3(0, 0.15, 0)]],
	1: [["L", Vector3(0, 0.17, 0)], ["R", Vector3(0, 0.37, 0)]],
	2: [["L", Vector3(0, 0.20, 0)], ["R", Vector3(0, 0.41, 0)]],
	3: [["R", Vector3(0, 0.0, 0.05)], ["L", Vector3(-0.12, 0.07, -0.12), Vector3.RIGHT]],      # pistol grip; the side handle runs along X
	4: [["R", Vector3(0.15, 0.0, 0), Vector3.RIGHT], ["L", Vector3(-0.15, 0.0, 0), Vector3.RIGHT]],   # the T-handle grips run along X
}
const SKIN := Color(0.80, 0.62, 0.48)
const GLOVE := Color(0.17, 0.18, 0.21)
const SLEEVE := Color(0.27, 0.30, 0.33)         # the slate work jacket (the first-person hands)
const BAND := Color(0.86, 0.86, 0.78)          # reflective cuff band

func _hand_frame(t: int) -> Array:
	var def: Dictionary = _def(t)
	var pivot_b := Basis.from_euler(def["rest_rot"]) if bool(def.get("power", false)) else Basis.from_euler(Vector3(float(def.get("rest", 0.0)), float(def.get("yaw", 0.0)), float(def.get("rest_roll", 0.0))))
	var model_b := Basis.from_euler(Vector3(float(def.get("model_pitch", 0.0)), float(def.get("twist", 0.0)), 0.0))
	return [(pivot_b * model_b).inverse(), 1.0 / float(def.get("scale", 1.0))]

func _add_hands(_n: Node3D, _t: int) -> void:
	return                                           # the hands are the shared rig (FPHands), not part of any tool model

func _add_hands_old(n: Node3D, t: int) -> void:
	var def: Dictionary = _def(t)
	var fr := _hand_frame(t)
	var list := []
	for h in (def["hands"] if def.has("hands") else HANDS[t]):
		var axis: Vector3 = h[2] if h.size() > 2 else Vector3.UP
		var hn := _hand(n, h[0] == "R", h[1], fr[0], fr[1], Vector3.ZERO, axis)
		if hn != null:
			list.append({"node": hn, "base": hn.position, "axis": axis, "right": h[0] == "R"})
	n.set_meta("hand_nodes", list)

## The off hand works along the shaft while swinging: it slides down toward the other hand as the head goes back, then rides out again through the blow.
func _pose_hands(def: Dictionary, p: float, delta: float) -> void:
	if model == null or bool(def.get("power", false)) or _grips.size() < 2:
		return
	var reach := float(def.get("slide", 0.06))
	var want := 0.0
	if p >= 0.0:
		if str(def.get("style", "")) == "scoop":
			want = -reach * (1.0 if p < 0.8 else (1.0 - (p - 0.8) / 0.2))
		elif p < 0.42:
			want = -reach * (1.0 - pow(1.0 - p / 0.42, 2.0))
		elif p < 0.58:
			want = lerpf(-reach, reach * 0.35, (p - 0.42) / 0.16)
		else:
			want = lerpf(reach * 0.35, 0.0, clampf((p - 0.58) / 0.3, 0.0, 1.0))
	_slide = lerpf(_slide, want, clampf(delta * 18.0, 0.0, 1.0))

## The shared hands for this frame: grips from FPTools, the forearms' anchors from the camera corners, all in the pivot's space.
func _pose_rig(def: Dictionary) -> void:
	if hands_rig == null or model == null or not model.visible or _grips.is_empty():
		if hands_rig != null:
			hands_rig.hide_all()
		return
	var inv := pivot.basis.inverse()
	var anchors := {"R": inv * (FPTools.ANCHOR_R - position), "L": inv * (FPTools.ANCHOR_L - position), "pole_R": (inv * Vector3(0.6, -1.0, 0.3)).normalized(), "pole_L": (inv * Vector3(-0.6, -1.0, 0.3)).normalized()}
	var toward_cam := (inv * (-position)).normalized()
	var grips: Array = []
	for g in _grips:
		var gg: Dictionary = g.duplicate()
		var xf := model.transform
		if g.has("node"):
			var nd := model.find_child(str(g["node"]), true, false) as Node3D
			if nd != null:
				xf = model.transform * nd.transform
		gg["xf"] = xf
		var sl := float(g.get("slide", 0.0))
		gg["slide_k"] = sl
		grips.append(gg)
	var slide := {"L": _slide, "R": 0.0}
	hands_rig.pose(grips, model.transform, anchors, toward_cam, clampf(shock, 0.0, 1.0), slide)

func _update_clods(delta: float) -> void:
	for i in range(_clods.size() - 1, -1, -1):
		var c: Dictionary = _clods[i]
		c["life"] = float(c["life"]) - delta
		var v: Vector3 = c["vel"]
		v.y -= 3.0 * delta
		c["vel"] = v
		var n: Node3D = c["node"]
		n.position += v * delta
		if float(c["life"]) <= 0.0:
			n.queue_free()
			_clods.remove_at(i)
		else:
			n.scale = Vector3.ONE * clampf(float(c["life"]) / 0.3, 0.2, 1.0)

## The shovel's digging cycle, as pitch about the grip (rest = the ready pose with the blade forward and down): anticipation (the blade lowers toward the soil), insertion (driven in with resistance:
## slow at first, then it bites at the impact moment), lever (the handle goes forward and down, the blade heaves up under the load), lift (blade level, load on it), carry (steady, a sway),
## dump (the blade tips forward and rolls, the load leaves), recovery (back to ready with a small settle). Returns ang, off, weight (contact with the ground) and roll.
func _scoop_pose(p: float, rest: float) -> Dictionary:
	var ang := rest
	var off := Vector3.ZERO
	var weight := 0.0
	var roll := 0.0
	if p < 0.16:                                                                   # anticipation
		var a := _ease_io(p / 0.16)
		ang = rest - 0.30 * a
		off = Vector3(0.0, -0.05, -0.08) * a
	elif p < 0.34:                                                                 # insertion: resistance, then the bite
		var a2 := pow((p - 0.16) / 0.18, 1.8)
		ang = rest - 0.30 - 0.14 * a2
		off = Vector3(0.0, lerpf(-0.05, -0.2, a2), lerpf(-0.08, -0.22, a2))
		weight = a2
	elif p < 0.52:                                                                 # lever: heavy, slow at the start
		var a3 := _ease_io((p - 0.34) / 0.18)
		ang = lerpf(rest - 0.44, rest + 0.1, a3)
		off = Vector3(0.0, lerpf(-0.2, -0.02, a3), lerpf(-0.22, -0.12, a3))
		weight = 1.0 - 0.45 * a3
	elif p < 0.68:                                                                 # lift
		var a4 := _ease_io((p - 0.52) / 0.16)
		ang = lerpf(rest + 0.1, rest + 0.5, a4)
		off = Vector3(0.0, lerpf(-0.02, 0.07, a4), lerpf(-0.12, -0.05, a4))
		weight = 0.55 * (1.0 - a4)
	elif p < 0.78:                                                                 # carry
		var a5 := (p - 0.68) / 0.1
		ang = rest + 0.5 + sin(a5 * PI) * 0.02
		off = Vector3(0.0, 0.07, -0.05)
		roll = sin(a5 * PI * 2.0) * 0.03
	elif p < 0.9:                                                                  # dump: forward and a roll
		var a6 := _ease_io((p - 0.78) / 0.12)
		ang = lerpf(rest + 0.5, rest - 0.2, a6)
		off = Vector3(0.0, lerpf(0.07, 0.06, a6), lerpf(-0.05, -0.1, a6))
		roll = 0.45 * a6
	else:                                                                          # recovery
		var a7 := (p - 0.9) / 0.1
		var e7 := 1.0 - pow(1.0 - a7, 3.0)
		ang = lerpf(rest - 0.2, rest, e7) + sin(a7 * PI) * 0.03
		off = Vector3(0.0, 0.06, -0.1).lerp(Vector3.ZERO, e7)
		roll = 0.45 * (1.0 - e7)
	return {"ang": ang, "off": off, "weight": weight, "roll": roll}

static func _ease_io(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

## One gloved fist with its cuff band and jacket sleeve, closed at `at` (model space) of `parent`; the sleeve runs toward the screen edge.
func _hand(n: Node3D, right: bool, at: Vector3, inv: Basis, inv_s: float, cam_dir := Vector3.ZERO, axis := Vector3.UP, procedural := false) -> Node3D:
	var base_dir: Vector3 = cam_dir if cam_dir != Vector3.ZERO else (HAND_R_DIR if right else HAND_L_DIR)
	if cam_dir == Vector3.ZERO and absf(axis.normalized().dot(Vector3.RIGHT)) > 0.9:
		base_dir = Vector3(0.3 if right else -0.3, -1.0, -0.35)           # a hand on a T-handle: the arm drops straight down out of the picture, never toward the camera
	var dir_m: Vector3 = (inv * base_dir).normalized()
	var gh: Node3D = null if procedural else ToolModels.load_hand(right)
	if gh != null and not procedural:
		# a Blender glove: fingers wrapped round the grip (its axis is `axis`), the forearm running toward the screen edge (perpendicular to the grip)
		var ya := axis.normalized()
		var za := dir_m - ya * dir_m.dot(ya)
		if za.length() < 0.05:
			za = ya.cross(Vector3.RIGHT)
		za = za.normalized()
		gh.basis = Basis(ya.cross(za).normalized(), ya, za).scaled(Vector3.ONE * inv_s)
		gh.position = at
		n.add_child(gh)
		return gh
	var basis := VeilRig.basis_zy(dir_m, Vector3.UP)
	# a real forearm: a tapered sleeve with a rolled cuff, a gloved fist with knuckles and a thumb, all rounded (cylinders, not boxes)
	var along := Basis(Quaternion(Vector3.UP, dir_m))      # +Y of this basis runs down the forearm, away from the grip
	var glove := MeshKit.flat(GLOVE)
	var fist_m := MeshKit.frustum(0.040 * inv_s, 0.036 * inv_s, 0.085 * inv_s, 10)
	var fist := MeshKit.inst(n, fist_m, glove, at - dir_m * 0.02 * inv_s)
	fist.basis = along
	var knuckle_m := MeshKit.frustum(0.022 * inv_s, 0.018 * inv_s, 0.09 * inv_s, 8)       # the row of knuckles across the back of the hand
	var knuckle := MeshKit.inst(n, knuckle_m, glove, at + (basis * Vector3(0.0, 0.03, 0.01)) * inv_s)
	knuckle.basis = Basis(Quaternion(Vector3.UP, basis * Vector3(1, 0, 0)))
	var thumb := MeshKit.inst(n, MeshKit.frustum(0.014 * inv_s, 0.011 * inv_s, 0.06 * inv_s, 6), MeshKit.flat(SKIN), at + (basis * Vector3(0.0, 0.038, -0.025)) * inv_s)
	thumb.basis = Basis(Quaternion(Vector3.UP, basis * Vector3(0, 0, 1)))
	var cuff := MeshKit.inst(n, MeshKit.frustum(0.046 * inv_s, 0.046 * inv_s, 0.022 * inv_s, 10), MeshKit.flat(BAND), at + dir_m * 0.066 * inv_s)
	cuff.basis = along
	var sleeve := MeshKit.inst(n, MeshKit.frustum(0.048 * inv_s, 0.064 * inv_s, 0.30 * inv_s, 10), MeshKit.flat(SLEEVE), at + dir_m * 0.085 * inv_s)
	sleeve.basis = along
	return null

## Chisels are held in one hand and struck with a small hammer in the other. The striker (hammer head, handle, fist and sleeve) is its own node:
## it draws back, drives onto the chisel's strike end exactly at the impact moment, and recovers (see _pose_striker).
const STRIKER_DIR := Vector3(0.85, -0.5, 0.15)     ## the striking forearm runs out to the right edge, away from the camera, so it never clips it
const STRIKE_POINT := Vector3(0, -0.075, 0)      ## the chisel's mushroomed strike end, model space
func _add_striker(n: Node3D, t: int) -> void:
	var fr := _hand_frame(t)
	var inv: Basis = fr[0]
	var inv_s: float = fr[1]
	var striker := Node3D.new()
	striker.name = "Striker"
	n.add_child(striker)
	var dir_m: Vector3 = (inv * STRIKER_DIR).normalized()
	var basis := VeilRig.basis_zy(dir_m, Vector3.UP)
	MeshKit.inst(striker, MeshKit.box(Vector3(0.07, 0.055, 0.07)), MeshKit.mat("SteelPlate"), Vector3.ZERO)
	MeshKit.inst(striker, MeshKit.box(Vector3(0.05, 0.012, 0.05)), MeshKit.mat("SteelPlate"), Vector3(0, 0.032, 0))
	var handle := MeshKit.inst(striker, MeshKit.box(Vector3(0.028, 0.028, 0.2)), MeshKit.mat(QuarryArt.M_WOOD), dir_m * 0.1)
	handle.basis = basis
	_hand(striker, true, dir_m * 0.17, inv, inv_s, STRIKER_DIR, Vector3.UP, true)
	n.set_meta("striker", striker)

## Striker position along the chisel's axis behind the strike end: drawn back during the wind-up, driving in over the strike stretch so the face meets the
## chisel at phase 0.58 (the frame the damage lands), then recovering. `p` is the swing phase, or -1 when idle (hovering just behind the chisel).
func _pose_striker(striker: Node3D, p: float) -> void:
	var d := 0.12
	if p >= 0.0:
		if p < 0.42:
			var a := p / 0.42
			d = lerpf(0.12, 0.24, 1.0 - pow(1.0 - a, 3.0))
		elif p < 0.58:
			var a2 := (p - 0.42) / 0.16
			d = lerpf(0.24, 0.0, a2 * a2)
		else:
			var a3 := clampf((p - 0.58) / 0.42, 0.0, 1.0)
			d = lerpf(0.0, 0.12, 1.0 - pow(1.0 - a3, 3.0))
	striker.position = STRIKE_POINT + Vector3(0, -0.03 - d, 0)
