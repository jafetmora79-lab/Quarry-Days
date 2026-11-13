"""Independent binary, texture, topology, skin and animation checks; no rendered images."""
import json,struct,io,sys
from pathlib import Path
import numpy as np
from PIL import Image
P=Path(__file__).resolve().parent
p=Path(sys.argv[1]) if len(sys.argv)>1 else P/'Dmitri_Candidate.glb'
b=p.read_bytes();magic,version,total=struct.unpack_from('<4sII',b);assert (magic,version,total)==(b'glTF',2,len(b))
n=struct.unpack_from('<I',b,12)[0];j=json.loads(b[20:20+n]);off=20+n;bl,bt=struct.unpack_from('<I4s',b,off);assert bt==b'BIN\0';binary=b[off+8:off+8+bl]
assert all('uri' not in x for x in j['buffers']+j['images'])
def acc(i):
 a=j['accessors'][i];v=j['bufferViews'][a['bufferView']];dt={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']];dim={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']];o=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',np.dtype(dt).itemsize*dim)
 arr=np.ndarray((a['count'],dim),dtype=dt,buffer=binary,offset=o,strides=(stride,np.dtype(dt).itemsize)).copy();assert np.isfinite(arr).all();return arr
pr=j['meshes'][0]['primitives'][0];a=pr['attributes'];pos=acc(a['POSITION']);idx=acc(pr['indices']).ravel();tri=pos[idx.reshape(-1,3)];area=np.linalg.norm(np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]),axis=1)/2
assert area.min()>1e-10,('degenerate',int((area<=1e-10).sum()))
norm=acc(a['NORMAL']);assert np.allclose(np.linalg.norm(norm,axis=1),1,atol=.001)
weights=acc(a['WEIGHTS_0']);assert np.allclose(weights.sum(1),1,atol=.001);assert weights.min()>=0
uv=acc(a['TEXCOORD_0']);assert uv.min()>=0 and uv.max()<=1
# Weld position duplicates introduced by UV/normal splits, then inspect edge valence and signed volume per island.
_,remap=np.unique(np.round(pos,6),axis=0,return_inverse=True);faces=remap[idx.reshape(-1,3)];N=int(remap.max()+1);parent=list(range(N))
def root(x):
 while parent[x]!=x:parent[x]=parent[parent[x]];x=parent[x]
 return x
edges={}
for f in faces:
 for x,y in zip(f,np.roll(f,-1)):
  parent[root(int(y))]=root(int(x));e=tuple(sorted([int(x),int(y)]));edges[e]=edges.get(e,0)+1
assert all(n==2 for n in edges.values()),'non manifold edge'
vols={}
for t,f in zip(tri,faces):
 r=root(int(f[0]));vols[r]=vols.get(r,0)+float(np.dot(t[0],np.cross(t[1],t[2])))/6
assert all(v>0 for v in vols.values()),('inward component',min(vols.values()))
# Each separate clothing/facial island is closed and sits against the figure; no detached body parts.
components={}
for i,v in enumerate(pos):components.setdefault(root(int(remap[i])),[]).append(v)
components=[np.array(v) for v in components.values()];connected={max(range(len(components)),key=lambda i:len(components[i]))}
while True:
 added=set()
 for i,A in enumerate(components):
  if i in connected:continue
  for k in connected:
   B=components[k]
   if np.max(np.maximum(A.min(0)-B.max(0),B.min(0)-A.max(0)))>.055:continue
   d=min(float(np.min(np.sum((A[z:z+64,None]-B[None])**2,axis=2))) for z in range(0,len(A),64))
   if d<.055**2:added.add(i);break
 if not added:break
 connected|=added
assert len(connected)==len(components),('detached islands',len(components)-len(connected))
for im in j['images']:
 v=j['bufferViews'][im['bufferView']];o=v.get('byteOffset',0);image=Image.open(io.BytesIO(binary[o:o+v['byteLength']]));assert image.size==(256,256);assert len(image.getcolors(65536))>16
assert len(j['materials'])==1 and len(j['meshes'])==1 and len(j['skins'])==1
assert j['samplers'][0]['magFilter']==9728
assert {x['name'] for x in j['animations']}=={'Idle','Walk'}
assert len(idx)//3<10000
report={'glb':p.name,'vertices_exported':len(pos),'triangles':len(idx)//3,'dimensions_m':(pos.max(0)-pos.min(0)).tolist(),'bounds_min':pos.min(0).tolist(),'bounds_max':pos.max(0).tolist(),'material_count':len(j['materials']),'embedded_atlas':'256x256 PNG','bones':len(j['skins'][0]['joints']),'animations':[x['name'] for x in j['animations']],'closed_authored_components':len(components),'all_components_in_contact_neighborhood':True,'minimum_triangle_area_m2':float(area.min()),'outward_closed_component_volumes':True,'normalized_skin_weights':True,'missing_external_files':False,'visual_approval':'Pending user inspection in published viewer'}
(P/'validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
