"""QUARRY DAYS - 64 px UI portraits rendered from the named cast's own models (so the face in the HUD matches the person).

    blender -b --factory-startup -P tools/character_cast/render_portraits.py -- <out_dir_for_raw_renders>
    python tools/character_cast/finish_portraits.py <raw_dir>      (palette + outline -> assets/ui/portraits/named/)
"""
import bpy, math, os, sys
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
from cast_specs import CAST  # noqa: E402

RAW = sys.argv[sys.argv.index("--") + 1]
os.makedirs(RAW, exist_ok=True)
for name, sp in CAST.items():
    bpy.ops.wm.read_factory_settings(use_empty=True); sc = bpy.context.scene
    bpy.ops.import_scene.gltf(filepath=os.path.join(REPO, "assets", "characters", "CHR_QD_%s.glb" % name))
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    for o in bpy.data.objects:
        if o.type == 'MESH':
            for s in o.material_slots:
                for n in s.material.node_tree.nodes:
                    if n.type == 'TEX_IMAGE': n.interpolation = 'Closest'
    top = max((o.matrix_world @ v.co).z for o in bpy.data.objects if o.type == 'MESH' for v in o.data.vertices)
    # relaxed arms so the shoulders read in the bust
    bpy.context.view_layer.objects.active = arm; bpy.ops.object.mode_set(mode='POSE')
    for side, sx in (("Right", 1), ("Left", -1)):
        pb = arm.pose.bones[side + "UpperArm"]; b = pb.bone
        q = (b.tail_local - b.head_local).normalized().rotation_difference(Vector((sx * 0.25, 0.0, -1.0)).normalized())
        bq = b.matrix_local.to_quaternion(); pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = bq.inverted() @ q @ bq
    bpy.ops.object.mode_set(mode='OBJECT')
    for eng in ('BLENDER_EEVEE', 'BLENDER_EEVEE_NEXT'):
        try: sc.render.engine = eng; break
        except TypeError: continue
    sc.view_settings.view_transform = 'Standard'; sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = 64; sc.render.filter_size = 0.7
    w = bpy.data.worlds.new("W"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.52, 0.48, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 1.1
    for nm, rot, en, col in (("Key", (55, 0, 35), 3.4, (1.0, 0.90, 0.76)), ("Fill", (70, 0, -55), 1.1, (0.8, 0.85, 1.0)), ("Rim", (40, 0, 190), 2.0, (1.0, 0.85, 0.6))):
        l = bpy.data.lights.new(nm, 'SUN'); l.energy = en; l.color = col; o = bpy.data.objects.new(nm, l); sc.collection.objects.link(o)
        o.rotation_euler = [math.radians(a) for a in rot]
    c = bpy.data.cameras.new("C"); c.type = 'ORTHO'; c.ortho_scale = 0.40
    cam = bpy.data.objects.new("C", c); sc.collection.objects.link(cam)
    tz = top - 0.165
    cam.location = (0.42, 2.0, tz + 0.10); cam.rotation_euler = (Vector((0, 0, tz)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.camera = cam; sc.render.filepath = os.path.join(RAW, name.lower() + ".png")
    bpy.ops.render.render(write_still=True)
print("PORTRAITS_OK", len(CAST))
