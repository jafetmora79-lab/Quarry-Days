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
var _dust_meshes := {}
## Dust takes the colour of the rock that was struck.
const DUST_COLORS := {"limestone": Color(0.80, 0.76, 0.66), "coal": Color(0.24, 0.25, 0.28), "iron_ore": Color(0.58, 0.38, 0.31),
	"crushed_stone": Color(0.68, 0.66, 0.60), "copper_ore": Color(0.52, 0.66, 0.55), "gold_ore": Color(0.88, 0.72, 0.32), "topsoil": Color(0.46, 0.33, 0.22), "gravel": Color(0.66, 0.62, 0.55)}

func _ready() -> void:
	name = "FX"
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

## Dust: a small burst of irregular specks (tiny faceted blobs, never flat quads) that fly off the surface,
## slow down with drag, shrink and fade. Mesh and colour are swapped per strike; 9 particles per burst.
func _dust_emitter(amount: int, life: float, _size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.lifetime_randomness = 0.45
	p.explosiveness = 0.95
	p.direction = Vector3(0, 1, 0)
	p.spread = 60.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, -1.6, 0)
	p.damping_min = 1.2
	p.damping_max = 2.6
	p.angular_velocity_min = -200.0
	p.angular_velocity_max = 200.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.06
	p.scale_amount_min = 0.45
	p.scale_amount_max = 1.5
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.25))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.9))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = grad
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

func _dust_mesh(res: String) -> Mesh:
	if not _dust_meshes.has(res):
		var m := MeshKit.rock(Vector3(0.1, 0.07, 0.09), 57 + res.length(), 2, 5)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = DUST_COLORS.get(res, DUST_COLORS["limestone"])
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.surface_set_material(0, mat)
		_dust_meshes[res] = m
	return _dust_meshes[res]

func _frag_mesh(res: String) -> Mesh:
	if not _frag_meshes.has(res):
		var m := MeshKit.rock(Vector3(0.14, 0.11, 0.12), 31 + res.length(), 2, 5)
		m.surface_set_material(0, MeshKit.mat(QuarryArt.ROCK_MAT.get(res, "RockLimestone")))
		_frag_meshes[res] = m
	return _frag_meshes[res]

func _fire(p: CPUParticles3D, at: Vector3, normal := Vector3.UP) -> void:
	p.global_position = at
	p.direction = normal
	p.restart()
	p.emitting = true

func _puff(at: Vector3, res: String, amount: int, normal: Vector3, spread: float) -> void:
	var d: CPUParticles3D = dust[_di]
	_di = (_di + 1) % POOL
	d.mesh = _dust_mesh(res)
	d.amount = amount
	d.spread = spread
	_fire(d, at + normal * 0.04, normal)

## Impact: a few rock chips and a burst of dust flying off the surface at the exact strike point.
## `normal` is the surface normal (dust leaves along it); power-tool ticks (strength < 0.8) make a smaller burst.
func impact(at: Vector3, res: String, strength := 1.0, normal := Vector3.UP) -> void:
	var n := normal.normalized() if normal.length() > 0.1 else Vector3.UP
	var g: CPUParticles3D = grit[_gi]
	_gi = (_gi + 1) % POOL
	g.mesh = _frag_mesh(res)
	g.amount = clampi(int(3 + 3 * strength), 2, 8)
	_fire(g, at + n * 0.03, n)
	_puff(at, res, 9 if strength >= 0.8 else 5, n, 58.0)

## A chunk breaking off: a burst of fragments and a wider dust burst.
func chunk_break(at: Vector3, res: String) -> void:
	var f: CPUParticles3D = fragments[_fi]
	_fi = (_fi + 1) % POOL
	f.mesh = _frag_mesh(res)
	_fire(f, at)
	_puff(at, res, 14, Vector3.UP, 80.0)
	if game_audio_break.is_valid():
		game_audio_break.call(at)

var game_audio_break: Callable
