"""Cleans the skin weights of the Meshy Cash Hopper (WLD_QD_cash_hopper_meshy.glb).
Meshy's auto-weights smear the whole cabinet across the tray bones (sliding the tray tore the front plate), so each vertex is hardened to ONE bone:
the tray (every loose piece of the mesh that lies completely inside the tray's box: body, side rails, uprights, front lugs; the frame bar, bolts and gussets next to it do not move) -> Bone_006, the funnel bowl -> Bone_002, the grate -> Bone_003, everything else -> Bone_000.
usage: python3 tools/reweight_meshy_hopper.py <meshy original.glb> <out.glb> [tray half-width]"""
import json,struct,sys
import numpy as np
src=sys.argv[1]; dst=sys.argv[2]
box=(float(sys.argv[3]) if len(sys.argv)>3 else 0.36)
b=bytearray(open(src,'rb').read())
l=struct.unpack('<I',b[12:16])[0]
j=json.loads(bytes(b[20:20+l])); off=20+l+8
N=j['nodes']; sk=j['skins'][0]['joints']; names=[N[i]['name'] for i in sk]
def view(k):
  a=j['accessors'][k]; bv=j['bufferViews'][a['bufferView']]
  dt={5126:'<f4',5123:'<u2',5121:'u1',5125:'<u4'}[a['componentType']]; nc={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
  o=off+bv.get('byteOffset',0)+a.get('byteOffset',0)
  assert 'byteStride' not in bv or bv['byteStride'] in (None, nc*np.dtype(dt).itemsize)
  return np.frombuffer(b,dt,a['count']*nc,o).reshape(a['count'],nc)
pr=j['meshes'][0]['primitives'][0]
P=view(pr['attributes']['POSITION']).copy();J=view(pr['attributes']['JOINTS_0']);W=view(pr['attributes']['WEIGHTS_0'])
ix={n:k for k,n in enumerate(names)}
chain=[ix[n] for n in ('Bone_006','Bone_007','Bone_008','Bone_009','Bone_010','Bone_011','Bone_012')]
funnel=[ix[n] for n in ('Bone_001','Bone_002','Bone_003','Bone_004','Bone_005')]
x,y,z=P[:,0],P[:,1],P[:,2]
# the mesh is a pile of loose pieces (welded by position): a piece belongs to the tray only if ALL of it lies inside the tray's box
T=view(pr['indices']).reshape(-1,3)
key=np.round(P*1e4).astype(np.int64)
_,inv=np.unique(key,axis=0,return_inverse=True); inv=inv.reshape(-1)
par=list(range(int(inv.max())+1))
def find(a):
  while par[a]!=a:
    par[a]=par[par[a]]; a=par[a]
  return a
for t in T:
  a,b2,c=[int(inv[v]) for v in t]
  for u,w in ((a,b2),(b2,c)):
    ru,rw=find(u),find(w)
    if ru!=rw: par[ru]=rw
comp=np.array([find(int(inv[v])) for v in range(len(P))])
tray=np.zeros(len(P),bool)
for c in np.unique(comp):
  m=comp==c; lo=P[m].min(0); hi=P[m].max(0)
  if lo[0]>=-box and hi[0]<=box-0.03 and lo[1]>=0.14 and hi[1]<=0.465 and lo[2]>=0.24:
    tray|=m
dom=J[np.arange(len(J)),W.argmax(1)]
# funnel: dominant joint among Bone_002 / Bone_003 (hardened)
fb=(dom==ix['Bone_002'])|(dom==ix['Bone_003'])
newJ=np.zeros_like(J); newW=np.zeros_like(W)
newJ[:,0]=ix['Bone_000']; newW[:,0]=1.0
newJ[tray,0]=ix['Bone_006']
for k in (ix['Bone_002'],ix['Bone_003']):
  m=(dom==k)&~tray; newJ[m,0]=k
print('tray verts',tray.sum(),'bowl',(newJ[:,0]==ix['Bone_002']).sum(),'grate',(newJ[:,0]==ix['Bone_003']).sum())
J[:]=newJ; W[:]=newW
open(dst,'wb').write(bytes(b))
