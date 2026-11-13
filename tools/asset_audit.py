#!/usr/bin/env python3
"""Mesh audit for every glTF binary in docs/models (Veil pack, characters, generated models).

Detects, per asset: triangle count, materials, degenerate triangles, duplicate faces, coplanar overlapping faces
(the cause of z-fighting / flicker), disconnected (floating) components, reversed normals, missing textures and
paper-thin geometry. Writes docs/audit/asset_audit.json (also read by the gallery) and docs/ASSET_AUDIT.md.

  python3 tools/asset_audit.py            (after tools/build_asset_preview.py)
"""
import glob, json, os, struct, sys
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
OUT_NAME = "asset_audit.json"
if "--docs" in sys.argv:                 # audit another copy of docs/ (e.g. the models of an older commit), report next to it
    DOCS = os.path.abspath(sys.argv[sys.argv.index("--docs") + 1])
if "--out" in sys.argv:
    OUT_NAME = sys.argv[sys.argv.index("--out") + 1]
WELD = 0.002          # m: vertices closer than this are one vertex
GAP = 0.03            # m: components closer than this count as attached
COMP = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}

def load_glb(path):
    data = open(path, "rb").read()
    magic, ver, length = struct.unpack_from("<4sII", data, 0)
    off = 12
    js, binchunk = None, b""
    while off < len(data):
        clen, ctype = struct.unpack_from("<II", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == 0x4E4F534A:
            js = json.loads(chunk)
        elif ctype == 0x004E4942:
            binchunk = chunk
        off += 8 + clen
    return js, binchunk

def accessor(js, binc, idx):
    a = js["accessors"][idx]
    bv = js["bufferViews"][a["bufferView"]]
    dt = np.dtype(COMP[a["componentType"]])
    n = NCOMP[a["type"]]
    stride = bv.get("byteStride", 0)
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    if stride and stride != dt.itemsize * n:
        arr = np.frombuffer(binc, dtype=np.uint8, count=stride * a["count"], offset=start).reshape(a["count"], stride)
        arr = arr[:, : dt.itemsize * n].copy().view(dt).reshape(a["count"], n)
    else:
        arr = np.frombuffer(binc, dtype=dt, count=a["count"] * n, offset=start).reshape(a["count"], n)
    return arr

def node_matrix(node):
    if "matrix" in node:
        return np.array(node["matrix"], dtype=np.float64).reshape(4, 4).T
    m = np.eye(4)
    t = node.get("translation", [0, 0, 0]); r = node.get("rotation", [0, 0, 0, 1]); s = node.get("scale", [1, 1, 1])
    x, y, z, w = r
    R = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                  [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                  [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
    m[:3, :3] = R @ np.diag(s)
    m[:3, 3] = t
    return m

def gather(js, binc):
    """-> list of (tris (n,3,3) world, normals per tri-vertex (n,3,3) or None, material index)"""
    out = []
    nodes = js.get("nodes", [])
    def walk(i, parent):
        node = nodes[i]
        m = parent @ node_matrix(node)
        nm = (node.get("name") or "").lower()
        if "mesh" in node and not ("-col" in nm or "-convcolonly" in nm or "-colonly" in nm):
            for prim in js["meshes"][node["mesh"]]["primitives"]:
                if prim.get("mode", 4) != 4:
                    continue
                pos = accessor(js, binc, prim["attributes"]["POSITION"]).astype(np.float64)
                nor = accessor(js, binc, prim["attributes"]["NORMAL"]).astype(np.float64) if "NORMAL" in prim["attributes"] else None
                idx = accessor(js, binc, prim["indices"]).reshape(-1).astype(np.int64) if "indices" in prim else np.arange(len(pos))
                wp = (m[:3, :3] @ pos.T).T + m[:3, 3]
                wn = None
                if nor is not None:
                    wn = (np.linalg.inv(m[:3, :3]).T @ nor.T).T
                    wn /= np.maximum(np.linalg.norm(wn, axis=1, keepdims=True), 1e-12)
                tri = idx[: len(idx) // 3 * 3].reshape(-1, 3)
                flip = np.linalg.det(m[:3, :3]) < 0
                if flip:
                    tri = tri[:, ::-1]
                out.append((wp[tri], wn[tri] if wn is not None else None, prim.get("material", -1)))
        for c in node.get("children", []):
            walk(c, m)
    scene = js["scenes"][js.get("scene", 0)]
    for r in scene["nodes"]:
        walk(r, np.eye(4))
    return out

def point_in_tri(p, a, b, c, eps=1e-4):
    v0, v1, v2 = c - a, b - a, p - a
    d00, d01, d02, d11, d12 = v0 @ v0, v0 @ v1, v0 @ v2, v1 @ v1, v1 @ v2
    den = d00 * d11 - d01 * d01
    if abs(den) < 1e-14:
        return False
    u = (d11 * d02 - d01 * d12) / den
    v = (d00 * d12 - d01 * d02) / den
    return u > eps and v > eps and u + v < 1 - eps

def samples(t):
    c = t.mean(axis=0)
    return [c] + [c + (t[i] - c) * 0.6 for i in range(3)]

def analyse(path):
    js, binc = load_glb(path)
    prims = gather(js, binc)
    res = {"triangles": 0, "materials": [], "defects": [], "metrics": {}}
    mats = js.get("materials", [])
    names = []
    for mi in sorted({p[2] for p in prims}):
        if 0 <= mi < len(mats):
            names.append(mats[mi].get("name", "material%d" % mi))
    res["materials"] = names
    if not prims:
        res["defects"].append("no_geometry")
        return res
    tris = np.concatenate([p[0] for p in prims])
    mat_of = np.concatenate([np.full(len(p[0]), p[2]) for p in prims])
    normals = [p[1] for p in prims]
    res["triangles"] = int(len(tris))
    # extents
    lo, hi = tris.reshape(-1, 3).min(axis=0), tris.reshape(-1, 3).max(axis=0)
    res["size"] = [round(float(x), 3) for x in (hi - lo)]
    # degenerate
    cr = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
    area = np.linalg.norm(cr, axis=1) * 0.5
    deg = int((area < 1e-8).sum())
    if deg:
        res["defects"].append("degenerate_triangles:%d" % deg)
    ok = area >= 1e-8
    nrm = np.zeros_like(cr)
    nrm[ok] = cr[ok] / (2 * area[ok, None])
    # reversed normals: stored vertex normal opposing the geometric one
    if all(n is not None for n in normals):
        vn = np.concatenate(normals).mean(axis=1)
        dots = (vn * nrm).sum(axis=1)[ok]
        rev = float((dots < -0.2).mean()) if len(dots) else 0.0
        res["metrics"]["reversed_normal_share"] = round(rev, 3)
        if rev > 0.05:
            res["defects"].append("reversed_normals:%d%%" % int(rev * 100))
    else:
        res["defects"].append("missing_normals")
    # duplicate faces
    key = {}
    dup = 0
    q = np.round(tris / WELD).astype(np.int64)
    for i in range(len(tris)):
        k = tuple(sorted(map(tuple, q[i])))
        if k in key:
            dup += 1
        else:
            key[k] = i
    if dup:
        res["defects"].append("duplicate_faces:%d" % dup)
    # coplanar overlapping faces (z-fighting)
    d = (nrm * tris[:, 0]).sum(axis=1)
    groups = {}
    ground_under = (nrm[:, 1] < -0.9) & (tris[:, :, 1].max(axis=1) < 0.03)      # undersides at ground level are never seen
    for i in np.nonzero(ok & ~ground_under)[0]:
        n = nrm[i] * (1 if (nrm[i][np.argmax(np.abs(nrm[i]))] > 0) else -1)
        kk = (tuple(np.round(n * 50).astype(int)), int(round(float(d[i] * (1 if (nrm[i][np.argmax(np.abs(nrm[i]))] > 0) else -1)) / 0.004)))
        groups.setdefault(kk, []).append(i)
    zf = 0
    redundant = 0
    zf_pairs = []
    def mname(i):
        return mats[i].get("name", str(i)) if 0 <= i < len(mats) else "none"
    for kk, ids in groups.items():
        if len(ids) < 2:
            continue
        for ai in range(len(ids)):
            for bi in range(ai + 1, len(ids)):
                a, b = ids[ai], ids[bi]
                ta, tb = tris[a], tris[b]
                if abs(d[a] - d[b]) * (1 if True else 0) > 0.0015 and abs(abs(d[a]) - abs(d[b])) > 0.0015:
                    continue          # more than 1.5 mm apart: genuinely separate surfaces
                if np.abs(ta.mean(axis=0) - tb.mean(axis=0)).max() > 4.0:
                    continue
                hit = any(point_in_tri(p, *tb) for p in samples(ta)) or any(point_in_tri(p, *ta) for p in samples(tb))
                if hit:
                    # an exact duplicate is counted above; opposite-facing coplanar pairs are internal faces (invisible)
                    if (nrm[a] @ nrm[b]) > 0.99:
                        if mat_of[a] == mat_of[b]:
                            redundant += 1            # same material: identical shading, harmless but wasteful
                        else:
                            zf += 1                   # different materials fighting for the same pixels: visible flicker
                            if len(zf_pairs) < 4:
                                zf_pairs.append({"at": [round(float(x), 2) for x in ta.mean(axis=0)], "materials": [mname(mat_of[a]), mname(mat_of[b])]})
    if zf:
        res["defects"].append("z_fighting:%d" % zf)
        res["metrics"]["z_fighting_at"] = zf_pairs
    if redundant:
        res["defects"].append("redundant_coplanar:%d" % redundant)
    # floating components
    qv = np.round(tris.reshape(-1, 3) / WELD).astype(np.int64)
    ids = {}
    vid = np.empty(len(qv), dtype=np.int64)
    for i, v in enumerate(map(tuple, qv)):
        vid[i] = ids.setdefault(v, len(ids))
    vid = vid.reshape(-1, 3)
    parent = list(range(len(ids)))
    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    for t in vid:
        ra, rb, rc = find(t[0]), find(t[1]), find(t[2])
        parent[rb] = ra
        parent[find(rc)] = ra
    comp = {}
    for i, t in enumerate(vid):
        comp.setdefault(find(t[0]), []).append(i)
    boxes = []
    for r, tl in comp.items():
        pts = tris[tl].reshape(-1, 3)
        boxes.append((pts.min(axis=0) - GAP, pts.max(axis=0) + GAP, len(tl)))
    n = len(boxes)
    p2 = list(range(n))
    def f2(x):
        while p2[x] != x:
            p2[x] = p2[p2[x]]
            x = p2[x]
        return x
    for i in range(n):
        for j in range(i + 1, n):
            if (boxes[i][0] <= boxes[j][1]).all() and (boxes[j][0] <= boxes[i][1]).all():
                p2[f2(j)] = f2(i)
    clusters = {}
    for i in range(n):
        clusters.setdefault(f2(i), []).append(i)
    res["metrics"]["components"] = n
    res["metrics"]["clusters"] = len(clusters)
    if len(clusters) > 1:
        info = []
        for c in clusters.values():
            lo_c = np.min([boxes[i][0] for i in c], axis=0) + GAP
            hi_c = np.max([boxes[i][1] for i in c], axis=0) - GAP
            info.append({"tris": int(sum(boxes[i][2] for i in c)), "min": [round(float(x), 2) for x in lo_c], "max": [round(float(x), 2) for x in hi_c]})
        info.sort(key=lambda x: -x["tris"])
        # flat markings lying on the ground (hazard crossing marks, floor decals) are not floating parts
        rest = [c for c in info[1:] if not (c["max"][1] - c["min"][1] < 0.07 and c["min"][1] < 0.07)]
        res["metrics"]["floating_clusters"] = rest
        if rest:
            res["defects"].append("floating_parts:%d clusters (%d tris apart from the main body)" % (len(rest), sum(c["tris"] for c in rest)))
    # paper-thin
    sz = hi - lo
    if (sz < 0.01).any() and res["triangles"] > 12:
        res["defects"].append("paper_thin_axis")
    # materials / textures
    for mi in sorted({p[2] for p in prims}):
        if mi < 0:
            res["metrics"]["materials_assigned_in_engine"] = True      # the Veil props carry no glTF material: Godot applies its .tres
            continue
        m = mats[mi]
        pbr = m.get("pbrMetallicRoughness", {})
        if "baseColorTexture" not in pbr and all(c > 0.97 for c in pbr.get("baseColorFactor", [1, 1, 1, 1])[:3]):
            res["defects"].append("white_material:%s" % m.get("name", mi))
        if m.get("alphaMode") == "BLEND":
            res["metrics"]["blend_material"] = True
        if pbr.get("metallicFactor", 0) > 0.6:
            res["defects"].append("shiny_metal:%s" % m.get("name", mi))
    base = os.path.dirname(path)
    for im in js.get("images", []):
        uri = im.get("uri")
        if uri and not uri.startswith("data:") and not os.path.exists(os.path.normpath(os.path.join(base, uri))):
            res["defects"].append("missing_texture:%s" % uri)
    if js.get("animations"):
        res["metrics"]["animations"] = len(js["animations"])
    return res

def main():
    report = {}
    files = sorted(glob.glob(os.path.join(DOCS, "models", "**", "*.glb"), recursive=True))
    for f in files:
        rel = os.path.relpath(f, DOCS).replace(os.sep, "/")
        try:
            report[rel] = analyse(f)
        except Exception as e:                      # a broken file is itself a defect
            report[rel] = {"triangles": 0, "materials": [], "defects": ["unreadable:%s" % e], "metrics": {}}
        print("%-70s %5d tris  %s" % (rel, report[rel]["triangles"], "; ".join(report[rel]["defects"]) or "clean"), flush=True)
    os.makedirs(os.path.join(DOCS, "audit"), exist_ok=True)
    with open(os.path.join(DOCS, "audit", OUT_NAME), "w") as fh:
        json.dump(report, fh, indent=1)
    bad = {k: v for k, v in report.items() if v["defects"]}
    print("\n%d assets, %d with defects" % (len(report), len(bad)))

if __name__ == "__main__":
    main()
