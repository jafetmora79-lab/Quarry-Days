extends Node3D
class_name QuarryDuel
## A rare forest-edge easter egg: a deer and a rabbit have an anime power-up showdown. They square up, their auras flare (golden for the deer, cold white-blue for the rabbit, with
## flickering flames, rising sparks and a rumbling ground), then three charges meet in the middle: each clash is a flash, a shockwave ring, a puff of dust, a shake you can feel
## if you are near, and both are knocked back in an arc. The last one is a head-to-head energy lock that ends in a big flash; the two bow to each other and wander off.
## Entirely visual: nothing here is saved or touches the game. `step(delta)` is driven by the wildlife node; `finished` becomes true when the scene is over.

const LENGTH := 34.0
var game
var deer: Node3D
var rabbit: Node3D
var dparts := {}
var rparts := {}
var centre := Vector3.ZERO
var axis := Vector3(1, 0, 0)            ## from the deer toward the rabbit
var t := 0.0
var finished := false
var _d_aura: Node3D
var _r_aura: Node3D
var _flash: OmniLight3D
var _ring: MeshInstance3D
var _ring_t := -1.0
var _dust: CPUParticles3D
var _sparks_d: CPUParticles3D
var _sparks_r: CPUParticles3D
var _last_clash := -1
var _lock_beam: MeshInstance3D
var _d_pos := Vector3.ZERO
var _r_pos := Vector3.ZERO
var _fade := 0.0

func setup(g, at: Vector3, facing: float) -> bool:
	game = g
	var d: Dictionary = WorldModels.animal("deer")
	var r: Dictionary = WorldModels.animal("rabbit")
	if d.is_empty() or r.is_empty():
		return false
	deer = d["root"]
	dparts = d["parts"]
	rabbit = r["root"]
	rparts = r["parts"]
	centre = at
	axis = Vector3(cos(facing), 0.0, sin(facing))
	name = "DeerRabbitDuel"
	add_child(deer)
	add_child(rabbit)
	_d_aura = _make_aura(Color(1.0, 0.72, 0.18), 1.5)
	_r_aura = _make_aura(Color(0.55, 0.85, 1.0), 0.75)
	deer.add_child(_d_aura)
	rabbit.add_child(_r_aura)
	_d_aura.position = Vector3(0, 0.9, 0)
	_r_aura.position = Vector3(0, 0.22, 0)
	_flash = OmniLight3D.new()
	_flash.light_energy = 0.0
	_flash.omni_range = 16.0
	_flash.light_color = Color(1.0, 0.95, 0.8)
	_flash.position = centre + Vector3(0, 1.0, 0)
	add_child(_flash)
	_ring = _make_ring()
	add_child(_ring)
	_ring.visible = false
	_dust = _make_particles(Color(0.62, 0.55, 0.42), 0.3, 24, 1.0, false)
	_dust.position = centre
	add_child(_dust)
	_sparks_d = _make_particles(Color(1.0, 0.8, 0.3), 0.07, 18, 1.6, true)
	_sparks_r = _make_particles(Color(0.7, 0.95, 1.0), 0.06, 14, 1.4, true)
	deer.add_child(_sparks_d)
	rabbit.add_child(_sparks_r)
	_sparks_d.position = Vector3(0, 0.2, 0)
	_sparks_r.position = Vector3(0, 0.05, 0)
	_d_pos = centre - axis * 4.2
	_r_pos = centre + axis * 4.2
	_place()
	return true

func _glow_mat(c: Color, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(c.r, c.g, c.b, a)
	m.no_depth_test = false
	return m

func _make_aura(c: Color, size: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Aura"
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size * 0.62
	sm.height = size * 1.5
	sm.radial_segments = 12
	sm.rings = 6
	core.mesh = sm
	core.material_override = _glow_mat(c, 0.22)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.name = "Core"
	root.add_child(core)
	for i in 9:                                                          # flames licking up round the body
		var f := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = size * 0.14
		cm.height = size * 1.3
		cm.radial_segments = 5
		f.mesh = cm
		f.material_override = _glow_mat(c, 0.34)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * float(i) / 9.0
		f.position = Vector3(cos(a) * size * 0.5, -size * 0.1, sin(a) * size * 0.5)
		f.name = "Flame%d" % i
		root.add_child(f)
	root.scale = Vector3.ZERO
	return root

func _make_ring() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 4
	m.mesh = tm
	m.material_override = _glow_mat(Color(1.0, 0.95, 0.85), 0.7)
	m.scale = Vector3(1, 0.1, 1)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = centre + Vector3(0, 0.15, 0)
	return m

func _make_particles(c: Color, size: float, n: int, life: float, up: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.emitting = false
	p.one_shot = false
	p.explosiveness = 0.0 if up else 0.9
	p.direction = Vector3.UP
	p.spread = 40.0 if up else 80.0
	p.initial_velocity_min = 1.0 if up else 1.5
	p.initial_velocity_max = 2.6 if up else 3.5
	p.gravity = Vector3(0, -1.0 if up else -6.0, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3(size, size, size)
	p.mesh = bm
	p.material_override = _glow_mat(c, 0.9) if up else _glow_mat(c, 0.5)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func _place() -> void:
	deer.position = _d_pos
	rabbit.position = _r_pos
	deer.rotation.y = atan2(-axis.x, -axis.z)                 # models face -Z: the deer looks along +axis
	rabbit.rotation.y = atan2(axis.x, axis.z)

func _aura(a: Node3D, k: float, flick: float) -> void:
	k = maxf(k, 0.0)
	a.scale = Vector3.ONE * k * (1.0 + 0.06 * sin(t * 18.0 + flick))
	var i := 0
	for c in a.get_children():
		if str(c.name).begins_with("Flame"):
			(c as Node3D).scale = Vector3(1.0, 0.7 + 0.7 * absf(sin(t * 9.0 + float(i) * 1.7 + flick)), 1.0)
			i += 1

func _clash(round_i: int) -> void:
	_ring_t = 0.0
	_ring.visible = true
	_flash.light_energy = 6.0
	_dust.restart()
	_dust.emitting = true
	if game != null and game.player != null and is_instance_valid(game.player):
		var d: float = game.player.global_position.distance_to(centre)
		if d < 45.0:
			game.player.shake = minf(0.03, game.player.shake + 0.02 * (1.0 - d / 45.0))

## One tick (seconds).
func step(delta: float) -> void:
	t += delta
	if t >= LENGTH:
		_end()
		return
	var tilt_d := 0.0
	var tilt_r := 0.0
	var hop_d := 0.0
	var hop_r := 0.0
	var dpos := centre - axis * 4.2
	var rpos := centre + axis * 4.2
	var aura_d := 0.0
	var aura_r := 0.0
	if t < 5.0:                                                  # the stare-down: auras swell, the ground shakes a little
		var k := t / 5.0
		aura_d = 0.5 * _ease(k)
		aura_r = 0.5 * _ease(k)
		hop_r = 0.05 * absf(sin(t * 6.0)) * k
		tilt_d = 0.06 * sin(t * 3.0)
	elif t < 9.5:                                                # powering up: bigger, faster, the deer rears and stamps, the rabbit bounces
		var k := (t - 5.0) / 4.5
		aura_d = lerpf(0.5, 1.5, _ease(k))
		aura_r = lerpf(0.5, 1.5, _ease(k))
		_sparks_d.emitting = true
		_sparks_r.emitting = true
		hop_r = (0.1 + 0.25 * k) * absf(sin(t * 11.0))
		tilt_d = -0.5 * absf(sin(t * 2.2)) * k                      # rearing up
		dpos += axis * 0.3 * sin(t * 40.0) * 0.02 * k
		if fmod(t, 1.1) < 0.1:
			if game != null and game.player != null and is_instance_valid(game.player) and game.player.global_position.distance_to(centre) < 35.0:
				game.player.shake = minf(0.02, game.player.shake + 0.006)
	elif t < 24.0:                                               # three charges
		var T := t - 9.5
		var cycle := 4.8
		var n := int(T / cycle)
		var u := fmod(T, cycle)
		aura_d = 1.5
		aura_r = 1.5
		var meet := centre
		if u < 0.5:                                              # the dash: ease-in toward the middle
			var k := _ease(u / 0.5)
			dpos = (centre - axis * 4.2).lerp(centre - axis * 0.9, k)
			rpos = (centre + axis * 4.2).lerp(centre + axis * 0.9, k)
			hop_r = 0.15 * sin(k * PI)
			tilt_d = 0.25 * k
		elif u < 1.3:                                            # the clash and the knock-back: thrown backward in an arc
			if _last_clash != n:
				_last_clash = n
				_clash(n)
			var k := (u - 0.5) / 0.8
			var back := _ease(k)
			dpos = (centre - axis * 0.9).lerp(centre - axis * 3.4, back)
			rpos = (centre + axis * 0.9).lerp(centre + axis * 3.4, back)
			hop_d = 0.9 * sin(k * PI)
			hop_r = 1.5 * sin(k * PI)
			tilt_d = -0.6 * sin(k * PI)
			tilt_r = -0.8 * sin(k * PI)
		else:                                                    # recovering: back to their marks, panting, auras flaring
			var k := _ease((u - 1.3) / 2.2)
			dpos = (centre - axis * 3.4).lerp(centre - axis * 4.2, k)
			rpos = (centre + axis * 3.4).lerp(centre + axis * 4.2, k)
			aura_d = 1.5 + 0.3 * sin(u * 8.0)
			aura_r = 1.5 + 0.3 * sin(u * 8.0 + 1.0)
			hop_r = 0.08 * absf(sin(u * 9.0))
	elif t < 29.0:                                               # the final energy lock: both run in, heads together, the auras merge into one blazing column
		var k := (t - 24.0) / 5.0
		var close := _ease(minf(k * 3.0, 1.0))
		dpos = (centre - axis * 4.2).lerp(centre - axis * 0.75, close)
		rpos = (centre + axis * 4.2).lerp(centre + axis * 0.75, close)
		aura_d = 1.5 + 1.5 * k
		aura_r = 1.5 + 1.5 * k
		hop_d = 0.03 * sin(t * 50.0)
		hop_r = 0.03 * sin(t * 50.0 + 1.0)
		tilt_d = 0.3
		tilt_r = 0.5
		_sparks_d.emitting = true
		_sparks_r.emitting = true
		_flash.light_energy = 1.5 + 2.5 * k
		if game != null and game.player != null and is_instance_valid(game.player) and game.player.global_position.distance_to(centre) < 40.0:
			game.player.shake = minf(0.03, game.player.shake + 0.002)
		if _last_clash != 99 and k > 0.97:
			_last_clash = 99
			_clash(3)
			_flash.light_energy = 10.0
	else:                                                        # spent: the auras fade, the two bow, then trot and hop away
		var k := (t - 29.0) / 5.0
		aura_d = maxf(0.0, 1.0 - k * 2.5)
		aura_r = maxf(0.0, 1.0 - k * 2.5)
		_sparks_d.emitting = false
		_sparks_r.emitting = false
		dpos = centre - axis * 0.75
		rpos = centre + axis * 0.75
		if k < 0.45:                                             # the bow
			tilt_d = 0.35 * sin(minf(k / 0.45, 1.0) * PI)
			tilt_r = 0.5 * sin(minf(k / 0.45, 1.0) * PI)
		else:
			var w := (k - 0.45) / 0.55
			dpos = (centre - axis * 0.75) - axis * 9.0 * w
			rpos = (centre + axis * 0.75) + axis * 9.0 * w
			deer.rotation.y = atan2(axis.x, axis.z)
			rabbit.rotation.y = atan2(-axis.x, -axis.z)
			hop_r = 0.25 * absf(sin(w * 30.0))
			hop_d = 0.05 * absf(sin(w * 14.0))
	deer.position = dpos + Vector3(0, hop_d, 0)
	rabbit.position = rpos + Vector3(0, hop_r, 0)
	if t < 29.0 + 5.0 * 0.45:
		deer.rotation.y = atan2(-axis.x, -axis.z)
		rabbit.rotation.y = atan2(axis.x, axis.z)
	deer.rotation.x = tilt_d
	rabbit.rotation.x = tilt_r
	_aura(_d_aura, aura_d, 0.0)
	_aura(_r_aura, aura_r, 2.0)
	if _flash.light_energy > 0.0 and t < 24.0 or t > 29.0:
		_flash.light_energy = move_toward(_flash.light_energy, 0.0, delta * 14.0)
	if _ring_t >= 0.0:
		_ring_t += delta
		var rk := _ring_t / 0.7
		_ring.scale = Vector3(1.0 + 9.0 * rk, 0.1, 1.0 + 9.0 * rk)
		(_ring.material_override as StandardMaterial3D).albedo_color.a = 0.7 * (1.0 - rk)
		if rk >= 1.0:
			_ring_t = -1.0
			_ring.visible = false

func _end() -> void:
	finished = true
	queue_free()
