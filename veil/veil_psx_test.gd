extends Node3D
## Isolated Veil test scene: Veil props on a Greyhaven-style dusk street, rendered in several looks.
## Run: godot --path . res://veil/veil_psx_test.tscn -- shots   (writes PNGs to the folder given by --out=)
const PROPS := [
	"02_Town/Street_Props/SP_Lamp_Commercial", "02_Town/Street_Props/SP_Bench_Wood", "02_Town/Street_Props/SP_Dumpster",
	"02_Town/Street_Props/SP_RoadBarrier", "02_Town/Street_Props/SP_TrafficCone", "02_Town/Street_Props/SP_UtilityPole_Streetlight",
	"02_Town/Fences/FN_MetalRailing_2.5m", "02_Town/Fences/FN_RetainingWall_2.5m", "02_Town/Vegetation/VG_Tree_Pine",
	"02_Town/Vegetation/VG_TreeStump", "02_Town/Vegetation/VG_RocksSmall", "02_Town/Utilities/UT_ElectricalCabinet",
	"03_Residential/Furniture/RES_Workbench", "04_Commercial/Shared_Props/COM_PalletStack", "04_Commercial/Shared_Props/COM_PalletRack",
]
const LOOKS := {
	"0_veil_plain": {}, "1_dither_only": {"dither": 1}, "2_psx_mild": {"psx": [320.0, 240.0, 0.0]},
	"3_psx_full": {"psx": [160.0, 120.0, 1.0]}, "4_psx_full_dither16": {"psx": [160.0, 120.0, 1.0], "depth": 15.0},
}
var _shader: Shader = load("res://veil/psx_spatial.gdshader")
var _dither: Texture2D = load("res://assets/shaders/psx/psxdither.png")
var _props: Array[Node3D] = []
var _cam: Camera3D
var _retro: ColorRect

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.45, 0.52)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.62)
	env.fog_enabled = true
	env.fog_light_color = Color(0.5, 0.53, 0.6)
	env.fog_density = 0.035
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, -40, 0); sun.light_color = Color(1, 0.85, 0.7); add_child(sun)
	var ground := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(60, 60); ground.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.3, 0.32, 0.3); ground.material_override = gm; add_child(ground)
	var i := 0
	for p in PROPS:
		var scn := load("res://THE_VEIL_ASSETS_V2/%s.glb" % p) as PackedScene
		if scn == null: push_warning("missing " + p); continue
		var n := scn.instantiate() as Node3D
		n.position = Vector3((i % 5) * 3.4 - 6.8, 0, -(i / 5) * 4.0)
		n.rotation.y = 0.5 + i * 0.4
		add_child(n); _props.append(n); i += 1
	_cam = Camera3D.new(); _cam.position = Vector3(0, 2.2, 6.5); _cam.rotation_degrees = Vector3(-12, 0, 0); _cam.fov = 60; add_child(_cam)
	var cl := CanvasLayer.new(); cl.layer = 5; add_child(cl)
	_retro = ColorRect.new(); _retro.set_anchors_preset(Control.PRESET_FULL_RECT); _retro.visible = false
	var rs := Shader.new()
	rs.code = load("res://assets/shaders/psx/retro_pass.gdshader").code
	var rm := ShaderMaterial.new(); rm.shader = rs; rm.set_shader_parameter("dither_tex", _dither); _retro.material = rm; cl.add_child(_retro)
	if "shots" in OS.get_cmdline_user_args(): _shoot.call_deferred()

func _apply(look: Dictionary) -> void:
	_retro.visible = look.has("dither")
	for n in _props:
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			for s in m.mesh.get_surface_count():
				if not look.has("psx"):
					m.set_surface_override_material(s, null)
					continue
				var orig := m.mesh.surface_get_material(s)
				var sm := ShaderMaterial.new()
				sm.shader = _shader
				var bm := orig as BaseMaterial3D
				sm.set_shader_parameter("albedo_tex", bm.albedo_texture if bm else null)
				sm.set_shader_parameter("tint", bm.albedo_color if bm else Color.WHITE)
				if bm: sm.set_shader_parameter("uv_scale", Vector2(bm.uv1_scale.x, bm.uv1_scale.y))
				var p: Array = look["psx"]
				sm.set_shader_parameter("snap_grid", Vector2(p[0], p[1]))
				sm.set_shader_parameter("affine", p[2])
				sm.set_shader_parameter("dither_tex", _dither)
				sm.set_shader_parameter("col_depth", look.get("depth", 31.0))
				m.set_surface_override_material(s, sm)

func _shoot() -> void:
	var out := "res://veil/shots"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
	for k in LOOKS:
		_apply(LOOKS[k])
		for view in 2:
			_cam.position = Vector3(0, 2.2, 6.5) if view == 0 else Vector3(-4.5, 1.3, 1.5)
			_cam.rotation_degrees = Vector3(-12, 0, 0) if view == 0 else Vector3(-8, 25, 0)
			await get_tree().process_frame; await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("%s/%s_v%d.png" % [out, k, view])
	get_tree().quit()
