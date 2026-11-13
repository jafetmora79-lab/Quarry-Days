"""Original polygon-authored Dmitri candidate. Blender 4.3+, no existing mesh copied.
Run blender -b --factory-startup -P experiments/dmitri-redesign/build_dmitri.py
No images of the model are rendered. Texture is authored pixel by pixel.
"""
import bpy, bmesh, math, os, json
from mathutils import Vector
from pathlib import Path
P=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
# A single 256-square atlas, 16 padded 64-square regions. Deliberate low-contrast clusters.
COLORS=[('canvas',(191,100,48)),('canvas_dark',(139,65,36)),('teal',(49,87,88)),('denim',(58,73,81)),('leather',(97,63,43)),('sole',(43,39,36)),('skin',(211,161,124)),('hair',(64,44,34)),('cream',(231,218,180)),('reflect',(206,209,183)),('eye',(241,227,198)),('iris',(78,108,112)),('dark',(41,37,33)),('lip',(139,78,61)),('brass',(166,129,66)),('blush',(190,120,91))]
img=bpy.data.images.new('Dmitri_PixelAtlas',width=256,height=256,alpha=False)
pixels=[0.0]*(256*256*4)
for i,(name,c) in enumerate(COLORS):
 for y in range(64):
  for x in range(64):
   # Sparse 2-pixel cloth stitches, with quiet leather scuffs. No random speckle.
   d=0
   if i in (0,1,2,3):
    if y%16==4 and x%16 in (4,5): d=6
    elif y%16==5 and x%16 in (4,5): d=-4
   if i==4 and y%23==9 and 14<x%32<20:d=8
   if i==7 and x%12 in (3,4):d=5
   k=(((i//4)*64+y)*256+(i%4)*64+x)*4
   pixels[k:k+4]=[max(0,min(255,v+d))/255 for v in c]+[1]
img.pixels.foreach_set(pixels);img.filepath_raw=str(P/'Dmitri_PixelAtlas.png');img.file_format='PNG';img.save();img.pack()
mat=bpy.data.materials.new('Dmitri_pixel_canvas');mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.88;bs.inputs['Metallic'].default_value=0
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img;tex.interpolation='Closest';tex.extension='EXTEND';mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
parts=[]; bone_specs={}
def bone(n,h,t,parent=None):bone_specs[n]=(Vector(h),Vector(t),parent)
bone('Hips',(0,0,.96),(0,0,1.07));bone('Spine',(0,0,1.07),(0,0,1.22),'Hips');bone('Chest',(0,0,1.22),(0,0,1.36),'Spine');bone('UpperChest',(0,0,1.36),(0,0,1.48),'Chest');bone('Neck',(0,0,1.48),(0,0,1.55),'UpperChest');bone('Head',(0,0,1.55),(0,0,1.80),'Neck')
for s,side in [(1,'Right'),(-1,'Left')]:
 bone(side+'Shoulder',(s*.07,0,1.44),(s*.225,0,1.43),'UpperChest')
 bone(side+'UpperArm',(s*.225,0,1.43),(s*.335,.012,1.18),side+'Shoulder')
 bone(side+'LowerArm',(s*.335,.012,1.18),(s*.39,.042,.96),side+'UpperArm')
 bone(side+'Hand',(s*.39,.042,.96),(s*.408,.06,.865),side+'LowerArm')
 bone(side+'UpperLeg',(s*.112,0,.96),(s*.12,.025,.54),'Hips');bone(side+'LowerLeg',(s*.12,.025,.54),(s*.125,0,.15),side+'UpperLeg')
 bone(side+'Foot',(s*.125,0,.15),(s*.125,.13,.065),side+'LowerLeg');bone(side+'Toes',(s*.125,.13,.065),(s*.125,.24,.065),side+'Foot')
# Explicit ring modelling, with welded loops and outward normals, UVs contained inside padded tiles.
def mesh(name,verts,faces,color,weights=None,smooth=True):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
 ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob);me.materials.append(mat)
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
 tile=next(i for i,(n,c) in enumerate(COLORS) if n==color)
 uv=me.uv_layers.new(name='PixelUV')
 # Local cylindrical coordinates for longitudinal surfaces. Polygon patches remain in their tile.
 zs=[v[2] for v in verts];z0,z1=min(zs),max(zs);cx=sum(v[0] for v in verts)/len(verts);cy=sum(v[1] for v in verts)/len(verts)
 for poly in me.polygons:
  us=[(math.atan2(verts[me.loops[li].vertex_index][1]-cy,verts[me.loops[li].vertex_index][0]-cx)/(2*math.pi))%1 for li in poly.loop_indices]
  if max(us)-min(us)>.5:us=[u+1 if u<.5 else u for u in us]
  for li,u in zip(poly.loop_indices,us):
   p=verts[me.loops[li].vertex_index];v=(p[2]-z0)/max(.001,z1-z0)
   uv.data[li].uv=((tile%4*64+4+56*(u%1))/256,(tile//4*64+4+56*v)/256)
  poly.use_smooth=smooth
 for i,p in enumerate(verts):
  w=weights(Vector(p)) if callable(weights) else {weights or 'Hips':1}
  for bn,val in w.items():
   vg=ob.vertex_groups.get(bn) or ob.vertex_groups.new(name=bn);vg.add([i],val,'REPLACE')
 parts.append(ob);return ob

def loft(name,rows,color,weight,n=12,smooth=True):
 # row=(x,y,z,half-width,half-depth); sculpted horizontal cross sections
 vs=[(x+rx*math.cos(j*math.tau/n),y+ry*math.sin(j*math.tau/n),z) for x,y,z,rx,ry in rows for j in range(n)]
 fs=[tuple(range(n-1,-1,-1))]
 for k in range(len(rows)-1):
  for j in range(n):fs.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
 fs.append(tuple((len(rows)-1)*n+j for j in range(n)))
 return mesh(name,vs,fs,color,weight,smooth)
def oval(name,c,r,color,bn,n=12):
 rows=[]
 for z,k in [(-.98,.15),(-.72,.69),(-.3,.95),(.3,.95),(.72,.69),(.98,.15)]:rows.append((c[0],c[1],c[2]+r[2]*z,r[0]*k,r[1]*k))
 return loft(name,rows,color,bn,n)
def tube(name,points,radii,color,bn,n=8):
 vs=[]
 for i,(p,rad) in enumerate(zip(points,radii)):
  p=Vector(p);d=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
  d.normalize();ref=Vector((0,1,0)) if abs(d.y)<.9 else Vector((0,0,1));a=d.cross(ref).normalized();b=d.cross(a).normalized()
  for j in range(n):vs.append(p+a*rad*math.cos(j*math.tau/n)+b*rad*math.sin(j*math.tau/n))
 fs=[tuple(range(n-1,-1,-1))]
 for k in range(len(points)-1):
  for j in range(n):fs.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
 fs.append(tuple((len(points)-1)*n+j for j in range(n)))
 return mesh(name,vs,fs,color,bn)
def patch(name,pts,color,bn,depth=.007):
 vs=pts+[(x,y-depth,z) for x,y,z in pts];N=len(pts);fs=[tuple(range(N)),tuple(range(2*N-1,N-1,-1))]+[(i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N)]
 return mesh(name,vs,fs,color,bn,False)
def torso_w(p):
 if p.z<1.1:return {'Hips':1}
 if p.z<1.25:return {'Spine':1}
 return {'Chest':.55,'UpperChest':.45}
# Tailored jacket: shaped hem, waist, chest and dropped shoulders; raised seams, collar and pockets.
loft('Jacket_tailored_shell',[(0,0,.96,.176,.112),(0,0,.98,.186,.118),(0,0,1.02,.177,.116),(0,0,1.10,.165,.113),(0,0,1.22,.19,.126),(0,0,1.34,.211,.131),(0,0,1.40,.226,.112),(0,0,1.45,.188,.095),(0,0,1.48,.085,.073)],'canvas',torso_w,16)
patch('Teal_shirt_inset',[(-.066,.095,1.48),(.066,.095,1.48),(.055,.134,1.26),(-.055,.134,1.26)],'teal','UpperChest')
for s in [-1,1]:
 patch('Collar_lapel',[(s*.073,.103,1.485),(s*.143,.110,1.435),(s*.10,.144,1.33),(s*.047,.14,1.39)],'canvas_dark','UpperChest')
 patch('Bellows_chest_pocket',[(s*.076,.139,1.32),(s*.163,.128,1.32),(s*.158,.139,1.22),(s*.08,.147,1.22)],'canvas_dark','Chest')
 patch('Pocket_flap',[(s*.071,.149,1.326),(s*.167,.139,1.326),(s*.155,.15,1.298),(s*.089,.156,1.294)],'canvas','Chest')
 oval('Pocket_snap',(s*.12,.157,1.308),(.006,.003,.006),'brass','Chest',8)
 patch('Hi_vis_shoulder_tape',[(s*.154,.121,1.39),(s*.181,.116,1.39),(s*.164,.141,1.05),(s*.136,.15,1.05)],'reflect',torso_w)
 patch('Hem_welt',[(s*.035,.127,1.01),(s*.15,.127,1.01),(s*.147,.136,1.037),(s*.035,.136,1.034)],'canvas_dark','Hips')
# Raised placket and small buttons.
patch('Jacket_placket',[(-.013,.139,1.28),(.013,.139,1.28),(.013,.127,.98),(-.013,.127,.98)],'canvas_dark',torso_w)
for z in [1.07,1.17,1.25]:oval('Button',(0,.148,z),(.005,.004,.005),'brass',torso_w,8)
loft('Neck',[(0,0,1.44,.068,.065),(0,0,1.57,.069,.068)],'skin','Neck')
# Pants pelvis is covered at the waistband, legs reach into boots, cuffs have visible volume.
loft('Trouser_seat',[(0,0,.84,.135,.096),(0,0,.90,.164,.114),(0,0,.98,.165,.112),(0,0,1.0,.16,.108)],'denim','Hips',12)
loft('Leather_belt',[(0,0,.976,.18,.121),(0,0,1.006,.178,.120)],'leather','Hips',16)
patch('Belt_buckle',[(-.025,.124,.98),(.025,.124,.98),(.025,.124,1.008),(-.025,.124,1.008)],'brass','Hips')
for s,side in [(1,'Right'),(-1,'Left')]:
 def aw(p,side=side):
  k=max(0,min(1,(1.22-p.z)/.085));return {side+'UpperArm':1-k,side+'LowerArm':k}
 loft(side+'_sleeve',[(s*.405,.04,.956,.043,.045),(s*.396,.039,.99,.052,.053),(s*.379,.025,1.06,.059,.059),(s*.347,.014,1.145,.063,.062),(s*.337,.012,1.18,.063,.064),(s*.332,.010,1.205,.072,.064),(s*.304,0,1.285,.075,.071),(s*.266,0,1.377,.079,.079),(s*.222,0,1.43,.080,.080)],'canvas',aw)
 loft(side+'_cuff',[(s*.403,.04,.95,.046,.047),(s*.403,.04,.965,.052,.053),(s*.399,.037,.993,.052,.054),(s*.397,.036,1.003,.046,.047)],'canvas_dark',side+'LowerArm')
 # An elbow gusset and fold ridge are geometry, not printed bands.
 oval(side+'_elbow_gusset',(s*.348,-.044,1.182),(.047,.014,.052),'canvas_dark',aw)
 tube(side+'_sleeve_fold',[(s*.324,.069,1.235),(s*.349,.08,1.22),(s*.374,.065,1.208)],[.005,.009,.004],'canvas_dark',aw)
 def lw(p,side=side):
  k=max(0,min(1,(.59-p.z)/.10));return {side+'UpperLeg':1-k,side+'LowerLeg':k}
 loft(side+'_trousers',[(s*.126,0,.17,.068,.071),(s*.126,0,.20,.079,.077),(s*.125,0,.24,.071,.073),(s*.122,0,.34,.073,.076),(s*.120,.018,.46,.077,.082),(s*.120,.024,.53,.081,.086),(s*.12,.012,.57,.084,.083),(s*.115,-.006,.72,.095,.095),(s*.111,0,.86,.099,.104),(s*.107,0,.93,.096,.102)],'denim',lw)
 oval(side+'_knee_panel',(s*.121,.09,.53),(.057,.012,.070),'teal',lw)
 tube(side+'_knee_fold',[(s*.064,.08,.44),(s*.12,.09,.455),(s*.174,.075,.447)],[.004,.007,.003],'denim',lw)
 # Toe and heel profile sculpted into each horizontal boot ring.
 x=s*.127
 loft(side+'_boot',[(x,.045,.0,.075,.151),(x,.047,.022,.087,.161),(x,.047,.046,.088,.161),(x,.046,.055,.083,.155)],'sole',side+'Foot',12)
 loft(side+'_boot_upper',[(x,.047,.048,.083,.153),(x,.049,.07,.085,.153),(x,.057,.10,.082,.145),(x,.036,.132,.071,.116),(x,.009,.153,.062,.075),(x,.0,.195,.061,.066),(x,.0,.215,.067,.071)],'leather',side+'Foot',12)
 for z in [.133,.152,.173]:tube(side+'_boot_lace',[(x-.031,.083,z),(x+.031,.083,z+.004)],[.003,.003],'cream',side+'Foot',6)
 # Fitted glove palm with four rounded two-bend fingers and an opposing thumb; wrist remains inside cuff.
 loft(side+'_glove_palm',[(s*.416,.062,.861,.037,.027),(s*.411,.06,.89,.043,.03),(s*.402,.049,.932,.043,.028),(s*.399,.044,.964,.038,.028)],'leather',side+'Hand',10)
 for k in range(4):
  x=s*(.381+k*.019);z=.866+(abs(1.5-k)*.005)
  tube(side+'_finger_'+str(k),[(x,.066,z+.02),(x,.083,z-.012),(x,.10,z-.025),(x,.116,z-.012)],[.010,.011,.010,.006],'leather',side+'Hand',6)
 tube(side+'_opposed_thumb',[(s*.372,.045,.922),(s*.353,.072,.904),(s*.357,.102,.883)],[.017,.014,.009],'leather',side+'Hand',8)
# Sculpted oval head with cheeks, jaw, chin; frontal feature surfaces sit on the actual face.
loft('Head_sculpted',[(0,.015,1.505,.045,.05),(0,.024,1.52,.075,.075),(0,.019,1.55,.099,.09),(0,.008,1.59,.118,.106),(0,.0,1.63,.125,.113),(0,-.005,1.67,.121,.11),(0,-.009,1.72,.116,.105),(0,-.01,1.76,.089,.082),(0,-.01,1.79,.035,.035)],'skin','Head',16)
# Beard follows jaw volume, retaining lips and cheeks.
loft('Beard_jaw',[(0,.025,1.501,.049,.052),(0,.025,1.514,.077,.076),(0,.018,1.542,.104,.092),(0,.010,1.565,.113,.10)],'hair','Head',16)
oval('Chin_beard',(0,.102,1.535),(.066,.017,.028),'hair','Head')
# Lips curve upward, eyes have sclera, colored iris, pupil and tiny highlight; no flat face tile.
for s in [-1,1]:
 oval('Ear',(s*.126,-.004,1.621),(.023,.022,.04),'skin','Head',10)
 oval('Ear_inner',(s*.141,.008,1.621),(.009,.012,.023),'blush','Head',8)
 oval('Cheek',(s*.073,.093,1.60),(.042,.016,.030),'skin','Head')
 oval('Eye_socket',(s*.048,.105,1.651),(.033,.011,.021),'canvas_dark','Head')
 oval('Eye_white',(s*.048,.113,1.653),(.029,.008,.016),'eye','Head')
 oval('Iris',(s*.045,.121,1.652),(.012,.004,.013),'iris','Head',10)
 oval('Pupil',(s*.045,.125,1.652),(.006,.002,.008),'dark','Head',8)
 oval('Eye_glint',(s*.042-.003,.128,1.657),(.003,.002,.003),'eye','Head',6)
 tube('Expressive_brow',[(s*.020,.112,1.679),(s*.047,.116,1.686),(s*.076,.104,1.68)],[.007,.009,.005],'hair','Head')
 tube('Mustache',[(s*.008,.132,1.582),(s*.025,.13,1.581),(s*.046,.115,1.575)],[.009,.011,.005],'hair','Head')
 tube('Smile',[(s*.004,.125,1.565),(s*.022,.124,1.566),(s*.035,.119,1.572)],[.003,.0035,.002],'lip','Head',6)
loft('Nose_bridge',[(0,.116,1.595,.018,.019),(0,.138,1.608,.024,.025),(0,.126,1.627,.017,.019),(0,.109,1.658,.012,.009)],'skin','Head',10)
oval('Nose_tip',(.003,.15,1.61),(.024,.018,.017),'skin','Head',10)
# Hair has shaped locks, but stays below the helmet shell.
loft('Hair_crop',[(0,-.023,1.679,.119,.092),(0,-.014,1.728,.12,.113),(0,-.01,1.772,.094,.092),(0,-.01,1.798,.04,.045)],'hair','Head',16)
for s in [-1,1]:
 oval('Sideburn',(s*.108,.027,1.649),(.014,.025,.043),'hair','Head',8)
 tube('Swept_hair_lock',[(s*.08,.08,1.724),(s*.05,.102,1.713),(s*.018,.104,1.727)],[.017,.019,.012],'hair','Head')
# Cream hardhat: shaped brim, low faceted dome, brow edge, longitudinal reinforcing rib.
loft('Helmet_brim',[(0,.011,1.733,.143,.163),(0,.015,1.745,.15,.172),(0,.012,1.757,.142,.163)],'canvas_dark','Head',20)
loft('Helmet_shell',[(0,-.006,1.747,.134,.139),(0,-.009,1.776,.135,.139),(0,-.012,1.813,.112,.12),(0,-.012,1.844,.07,.079),(0,-.012,1.858,.014,.026)],'cream','Head',16)
tube('Helmet_ridge',[(0,-.132,1.771),(0,-.103,1.817),(0,-.02,1.861),(0,.069,1.831),(0,.123,1.783)],[.009,.01,.012,.01,.008],'cream','Head',8)
patch('Helmet_badge',[(-.022,.133,1.769),(.022,.133,1.769),(.022,.128,1.802),(-.022,.128,1.802)],'teal','Head')
# One joined mesh and one material reduce draw calls. All authored islands retain descriptive vertex groups.
bpy.ops.object.select_all(action='DESELECT')
for ob in parts:ob.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();body=bpy.context.object;body.name='Dmitri_Candidate_Mesh'
# Consolidate identical material slots after joining.
for poly in body.data.polygons:poly.material_index=0
body.data.materials.clear();body.data.materials.append(mat)
arm=bpy.data.armatures.new('QD_Humanoid_Candidate');rig=bpy.data.objects.new('Dmitri_Rig',arm);bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
for name,(h,t,parent) in bone_specs.items():
 b=arm.edit_bones.new(name);b.head=h;b.tail=t
 if parent:b.parent=arm.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT');body.parent=rig;mod=body.modifiers.new('Humanoid_skin','ARMATURE');mod.object=rig
# Hand sockets: palm offset along local hand +Y, compatible with VeilRig's PALM=0.075.
for side in ['Right','Left']:
 ob=bpy.data.objects.new('Socket_'+side+'Hand',None);bpy.context.collection.objects.link(ob);ob.parent=rig;ob.parent_type='BONE';ob.parent_bone=side+'Hand';ob.location=(0,-.02,0)
for name,bn,loc in [('Socket_Head','Head',(0,0,0)),('Socket_Back','UpperChest',(0,-.12,-.10))]:
 ob=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(ob);ob.parent=rig;ob.parent_type='BONE';ob.parent_bone=bn;ob.location=loc
# Short independent preview clips; no existing game animation is edited.
rig.animation_data_create()
for clip,frames in [('Idle',61),('Walk',33)]:
 act=bpy.data.actions.new(clip);rig.animation_data.action=act
 for f in range(1,frames+1,4):
  phase=(f-1)/(frames-1)*math.tau
  for pb in rig.pose.bones:pb.rotation_mode='XYZ';pb.rotation_euler=(0,0,0)
  rig.pose.bones['Chest'].rotation_euler.x=.012*math.sin(phase)
  if clip=='Walk':
   for sign,side in [(1,'Right'),(-1,'Left')]:
    a=math.sin(phase)*sign
    rig.pose.bones[side+'UpperLeg'].rotation_euler.x=.33*a
    rig.pose.bones[side+'LowerLeg'].rotation_euler.x=-.38*max(0,-a)
    rig.pose.bones[side+'UpperArm'].rotation_euler.x=-.22*a
  else:
   rig.pose.bones['Head'].rotation_euler.z=.012*math.sin(phase)
  for pb in rig.pose.bones:pb.keyframe_insert('rotation_euler',frame=f,group=pb.name)
 act.use_fake_user=True
 track=rig.animation_data.nla_tracks.new();track.name=clip;strip=track.strips.new(clip,1,act);track.mute=True
rig.animation_data.action=None
for pb in rig.pose.bones:pb.rotation_euler=(0,0,0)
bpy.context.scene.frame_set(1);bpy.context.scene.render.fps=30
# Correct for any accidentally negative weights omitted by glTF.
for v in body.data.vertices:
 for g in list(v.groups):
  if g.weight<=.000001:body.vertex_groups[g.group].remove([v.index])
bpy.ops.wm.save_as_mainfile(filepath=str(P/'Dmitri_Candidate.blend'))
bpy.ops.export_scene.gltf(filepath=str(P/'Dmitri_Candidate.glb'),export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_yup=True,export_extras=True)
# Normalize sampler to nearest without mipmapping for cross-viewer pixel consistency.
import struct
q=P/'Dmitri_Candidate.glb';raw=q.read_bytes();jl=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+jl]);tail=raw[20+jl:]
for sampler in doc.get('samplers',[]):sampler['magFilter']=9728;sampler['minFilter']=9728
js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4)
q.write_bytes(struct.pack('<4sII',b'glTF',2,20+len(js)+len(tail))+struct.pack('<I4s',len(js),b'JSON')+js+tail)
# OBJ is a static neutral-pose interchange; the GLB and .blend retain the skeleton.
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
bpy.ops.wm.obj_export(filepath=str(P/'Dmitri_Candidate.obj'),export_selected_objects=True,forward_axis='NEGATIVE_Z',up_axis='Y',export_materials=True,path_mode='STRIP')
print('CANDIDATE_EXPORTED',len(body.data.vertices),'vertices',len(body.data.polygons),'polygons')
