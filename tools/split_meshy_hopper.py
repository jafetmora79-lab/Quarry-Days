"""Splits a static Meshy Cash Hopper (one fused mesh, no rig) into the parts the game animates, and stands it in the game's units.
Output nodes: Body, Tray (the payout tray: every loose piece of the mesh lying completely inside the tray's box), Funnel (the bowl, its struts and rim).
The model is scaled so it is 1.7 units tall (the same as the rigged base hopper) and moved so its base sits at y = 0.
usage: python3 tools/split_meshy_hopper.py <in.glb> <out.glb>"""
import json, struct, sys
import numpy as np

src, dst = sys.argv[1], sys.argv[2]
b = bytearray(open(src, 'rb').read())
jl = struct.unpack('<I', b[12:16])[0]
j = json.loads(bytes(b[20:20 + jl]))
bin_off = 20 + jl + 8
bin_len = struct.unpack('<I', b[20 + jl:24 + jl])[0]
binary = bytearray(b[bin_off:bin_off + bin_len])

def view(k, buf):
    a = j['accessors'][k]; bv = j['bufferViews'][a['bufferView']]
    dt = {5126: '<f4', 5123: '<u2', 5121: 'u1', 5125: '<u4'}[a['componentType']]
    nc = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
    return np.frombuffer(buf, dt, a['count'] * nc, bv.get('byteOffset', 0) + a.get('byteOffset', 0)).reshape(a['count'], nc)

pr = j['meshes'][0]['primitives'][0]
P = view(pr['attributes']['POSITION'], binary)
T = view(pr['indices'], binary).reshape(-1, 3).astype(np.int64)
ymin = float(P[:, 1].min()); s = 1.7 / (float(P[:, 1].max()) - ymin)
P[:, 1] -= ymin
P *= np.float32(s)                                           # baked into the buffer (in place)
pa = j['accessors'][pr['attributes']['POSITION']]
pa['min'] = [float(v) for v in P.min(0)]; pa['max'] = [float(v) for v in P.max(0)]

# loose pieces (welded by position)
key = np.round(P * 1e4).astype(np.int64)
_, inv = np.unique(key, axis=0, return_inverse=True); inv = inv.reshape(-1)
par = list(range(int(inv.max()) + 1))
def find(a):
    while par[a] != a:
        par[a] = par[par[a]]; a = par[a]
    return a
for t in T:
    a, b2, c = [int(inv[v]) for v in t]
    for u, w in ((a, b2), (b2, c)):
        ru, rw = find(u), find(w)
        if ru != rw: par[ru] = rw
comp = np.array([find(int(inv[v])) for v in range(len(P))])
part = np.zeros(len(P), np.int8)                              # 0 body, 1 tray, 2 funnel
for c in np.unique(comp):
    m = comp == c; lo = P[m].min(0); hi = P[m].max(0)
    if lo[0] >= -0.42 and hi[0] <= 0.40 and lo[1] >= 0.14 and hi[1] <= 0.50 and lo[2] >= 0.2:
        part[m] = 1
    elif hi[2] >= 0.7 and lo[2] >= 0.2 and hi[1] <= 1.0:                # the tray is welded to a pipe / bracket here: take only the vertices inside the tray's box
        part[m & (P[:, 0] >= -0.42) & (P[:, 0] <= 0.40) & (P[:, 1] >= 0.14) & (P[:, 1] <= 0.465) & (P[:, 2] >= 0.2)] = 1
    elif hi[1] >= 1.45 or (lo[1] >= 1.17 and abs(lo[0]) < 0.36 and abs(hi[0]) < 0.36 and abs(lo[2]) < 0.55 and abs(hi[2]) < 0.55):
        part[m] = 2
print('verts: body %d tray %d funnel %d' % ((part == 0).sum(), (part == 1).sum(), (part == 2).sum()))
print('triangles straddling parts (left on the body):', int(((part[T[:, 0]] != part[T[:, 1]]) | (part[T[:, 1]] != part[T[:, 2]])).sum()))

binary = bytearray(bytes(binary))                             # (a fresh buffer: the numpy views above still pin the old one)
# one index accessor per part, appended to the binary buffer
names = ['Body', 'Tray', 'Funnel']
tri_part = np.where((part[T[:, 0]] == part[T[:, 1]]) & (part[T[:, 1]] == part[T[:, 2]]), part[T[:, 0]], 0)      # a triangle moves only if all three corners do
meshes, nodes = [], []
for pi, nm in enumerate(names):
    idx = T[tri_part == pi].reshape(-1).astype(np.uint32)
    while len(binary) % 4: binary.append(0)
    off = len(binary); binary += idx.tobytes()
    j['bufferViews'].append({'buffer': 0, 'byteOffset': off, 'byteLength': idx.nbytes, 'target': 34963})
    j['accessors'].append({'bufferView': len(j['bufferViews']) - 1, 'componentType': 5125, 'count': int(len(idx)), 'type': 'SCALAR', 'max': [int(idx.max())], 'min': [int(idx.min())]})
    prim = {'attributes': dict(pr['attributes']), 'indices': len(j['accessors']) - 1, 'material': pr.get('material', 0), 'mode': 4}
    meshes.append({'name': nm, 'primitives': [prim]})
    nodes.append({'name': nm, 'mesh': pi})
j['meshes'] = meshes; j['nodes'] = nodes
j['scenes'][0]['nodes'] = [0, 1, 2]
j['buffers'][0]['byteLength'] = len(binary)
js = json.dumps(j, separators=(',', ':')).encode()
while len(js) % 4: js += b' '
while len(binary) % 4: binary.append(0)
out = bytearray(b'glTF' + struct.pack('<II', 2, 12 + 8 + len(js) + 8 + len(binary)))
out += struct.pack('<I', len(js)) + b'JSON' + js
out += struct.pack('<I', len(binary)) + b'BIN\x00' + bytes(binary)
open(dst, 'wb').write(bytes(out))
print('wrote', dst, len(out))
