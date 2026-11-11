extends Node3D
class_name QuarryFX
## Pooled, lightweight CPU particles (GL Compatibility friendly): rock fragments, dust puffs and
## drill grit. A handful of emitters are reused round-robin, so effects never allocate nodes at runtime.

const POOL := 6
var fragments: Array = []
var dust: Array = []
var grit: Array = []
var _fi := 0
var _di := 0
var _gi := 0
var _frag_meshes := {}
var _dust_mat: StandardMaterial3D

func _ready() -> void:
	name = "FX"
	_dust_mat = StandardMaterial3D.new()
	_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_dust_mat.vertex_color_use_as_albedo = true
	_dust_mat.albedo_color = Color(0.78, 0.72, 0.62, 0.55)
	_dust_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	for i in range(POOL):
		fragments.append(_emitter(10, 0.9, true))
		dust.append(_dust_emitter(9, 1.3, 0.9))
		grit.append(_emitter(5, 0.45, false))

func _emitter(amount: int, life: float, heavy: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.92
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 1.6 if heavy else 1.0
	p.initial_velocity_max = 3.6 if heavy else 2.2
	p.gravity = Vector3(0, -12.0, 0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 0.6 if heavy else 0.3
	p.scale_amount_max = 1.3 if heavy else 0.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(0.75, 0.9))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

func _dust_emitter(amount: int, life: float, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.8
	p.direction = Vector3(0, 1, 0)
	p.spread = 85.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.0
	p.gravity = Vector3(0, 0.25, 0)
	p.damping_min = 0.6
	p.damping_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _dust_mat
	p.mesh = q
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.4))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.65))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = grad
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

func _frag_mesh(res: String) -> Mesh:
	if not _frag_meshes.has(res):
		var m := MeshKit.rock(Vector3(0.14, 0.11, 0.12), 31 + res.length(), 2, 5)
		m.surface_set_material(0, MeshKit.mat(QuarryArt.ROCK_MAT.get(res, "RockLimestone")))
		_frag_meshes[res] = m
	return _frag_meshes[res]

func _fire(p: CPUParticles3D, at: Vector3) -> void:
	p.global_position = at
	p.restart()
	p.emitting = true

## Small impact: a few chips and a short puff.
func impact(at: Vector3, res: String, strength := 1.0) -> void:
	var g: CPUParticles3D = grit[_gi]
	_gi = (_gi + 1) % POOL
	g.mesh = _frag_mesh(res)
	g.amount = clampi(int(3 + 3 * strength), 2, 8)
	_fire(g, at)
	if strength >= 0.8:
		var d: CPUParticles3D = dust[_di]
		_di = (_di + 1) % POOL
		d.amount = 4
		_fire(d, at)

## A chunk breaking off: a burst of fragments and a bigger dust cloud.
func chunk_break(at: Vector3, res: String) -> void:
	var f: CPUParticles3D = fragments[_fi]
	_fi = (_fi + 1) % POOL
	f.mesh = _frag_mesh(res)
	_fire(f, at)
	var d: CPUParticles3D = dust[_di]
	_di = (_di + 1) % POOL
	d.amount = 9
	_fire(d, at)
	if game_audio_break.is_valid():
		game_audio_break.call(at)

var game_audio_break: Callable
