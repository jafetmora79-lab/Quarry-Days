#!/usr/bin/env python3
"""Writes Quarry Days-specific repaired copies of static glTF props (the Veil pack is never modified).

For every mesh: drops degenerate triangles and exact duplicate faces, and where two materials have faces on the same
plane (z-fighting) grows the smaller connected part 4 mm toward the viewer so the surfaces are physically separate.
Overly metallic embedded materials are toned down. Deterministic. Output keeps the source folder layout so the
relative texture paths keep working:   THE_VEIL_ASSETS_V2/<rel>.glb  ->  assets/veil_qd/<rel>.glb

  python3 tools/repair_glb.py
"""
import glob, json, os, shutil, struct, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asset_audit import load_glb, accessor, point_in_tri, samples, WELD

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "THE_VEIL_ASSETS_V2")
DST = os.path.join(ROOT, "assets", "veil_qd")
LIFT = 0.004
PLANE = 0.0015

def tri_geom(P, idx):
    t = P[idx]
    cr = np.cross(t[:, 1] - t[:, 0], t[:, 2] - t[:, 0])
    ar = np.linalg.norm(cr, axis=1) * 0.5
    n = np.zeros_like(cr)
    ok = ar > 1e-8
    n[ok] = cr[ok] / (2 * ar[ok, None])
    return t, n, ok

def node_matrix(node):
    from asset_audit import node_matrix as nm
    return nm(node)

def is_collision(name):
    n = (name or "").lower()
    return "-col" in n or "-convcolonly" in n or "-colonly" in n

def flatten(js, binc):
    """Bakes every mesh node of the scene into world space, one primitive per material. None if the asset is skinned or animated."""
    if js.get("skins") or js.get("animations"):
        return None
    nodes = js.get("nodes", [])
    by_mat = {}
    js["_collision"] = []
    def walk(i, parent):
        node = nodes[i]
        m = parent @ node_matrix(node)
        if "mesh" in node and is_collision(node.get("name")):
            js["_collision"].append({"name": node["name"], "mesh": node["mesh"], "matrix": m.T.reshape(-1).tolist()})
        elif "mesh" in node:
            for pr in js["meshes"][node["mesh"]]["primitives"]:
                attrs = pr["attributes"]
                if pr.get("mode", 4) != 4 or "POSITION" not in attrs:
                    continue
                P = accessor(js, binc, attrs["POSITION"]).astype(np.float64)
                N = accessor(js, binc, attrs["NORMAL"]).astype(np.float64) if "NORMAL" in attrs else None
                U = accessor(js, binc, attrs["TEXCOORD_0"]).astype(np.float32) if "TEXCOORD_0" in attrs else None
                idx = accessor(js, binc, pr["indices"]).reshape(-1).astype(np.int64) if "indices" in pr else np.arange(len(P))
                idx = idx[: len(idx) // 3 * 3].reshape(-1, 3)
                if np.linalg.det(m[:3, :3]) < 0:
                    idx = idx[:, ::-1]
                Pw = (m[:3, :3] @ P.T).T + m[:3, 3]
                Nw = None
                if N is not None:
                    Nw = (np.linalg.inv(m[:3, :3]).T @ N.T).T
                    Nw /= np.maximum(np.linalg.norm(Nw, axis=1, keepdims=True), 1e-12)
                flat = idx.reshape(-1)
                d = by_mat.setdefault(pr.get("material"), {"P": [], "N": [], "U": []})
                d["P"].append(Pw[flat])
                d["N"].append(Nw[flat].astype(np.float32) if Nw is not None else None)
                d["U"].append(U[flat] if U is not None else None)
        for c in node.get("children", []):
            walk(c, m)
    for r in js["scenes"][js.get("scene", 0)]["nodes"]:
        walk(r, np.eye(4))
    prims = []
    for mat, d in by_mat.items():
        P = np.concatenate(d["P"])
        N = np.concatenate(d["N"]) if all(x is not None for x in d["N"]) else None
        U = np.concatenate(d["U"]) if all(x is not None for x in d["U"]) else None
        prims.append({"P": P, "N": N, "U": U, "idx": np.arange(len(P)).reshape(-1, 3), "mat": mat})
    return prims

def repair_core(prims):
    stats = {"dropped": 0, "lifted": 0}
    # 1. degenerate + duplicate faces
    seen = set()
    for pr in prims:
        t, n, ok = tri_geom(pr["P"], pr["idx"])
        keep = []
        q = np.round(t / WELD).astype(np.int64)
        for i in range(len(t)):
            key = tuple(sorted(map(tuple, q[i])))
            if not ok[i] or key in seen:
                stats["dropped"] += 1
                continue
            seen.add(key)
            keep.append(i)
        pr["idx"] = pr["idx"][keep]
    # 2. connected parts per primitive
    comps = []
    for pi, pr in enumerate(prims):
        t = pr["P"][pr["idx"]]
        q = np.round(t.reshape(-1, 3) / WELD).astype(np.int64)
        ids, parent = {}, []
        def find(x):
            while parent[x] != x:
                parent[x] = parent[parent[x]]
                x = parent[x]
            return x
        vid = []
        for v in map(tuple, q):
            if v not in ids:
                ids[v] = len(parent)
                parent.append(len(parent))
            vid.append(ids[v])
        vid = np.array(vid).reshape(-1, 3)
        for a, b, c in vid:
            ra = find(a)
            parent[find(b)] = ra
            parent[find(c)] = ra
        groups = {}
        for ti, v in enumerate(vid):
            groups.setdefault(find(v[0]), []).append(ti)
        pr["comp"] = np.zeros(len(vid), dtype=np.int64)
        for tl in groups.values():
            pts = t[tl].reshape(-1, 3)
            comps.append({"prim": pi, "tris": tl, "lo": pts.min(axis=0), "hi": pts.max(axis=0), "n": {}})
            pr["comp"][tl] = len(comps) - 1
    for _pass in range(5 if len(prims) > 1 else 0):
        found = False
        buckets = {}
        for pi, pr in enumerate(prims):
            t, n, ok = tri_geom(pr["P"], pr["idx"])
            for i in range(len(t)):
                if not ok[i]:
                    continue
                d = float(n[i] @ t[i, 0])
                nk = tuple(np.round(n[i] * 20).astype(int))
                slab = int(np.floor(d / (PLANE * 2)))
                cand = buckets.get((nk, slab), []) + buckets.get((nk, slab - 1), []) + buckets.get((nk, slab + 1), [])
                for (opi, oi, od, ot) in cand:
                    if opi == pi or abs(od - d) > PLANE:
                        continue
                    if np.abs(t[i].mean(axis=0) - ot.mean(axis=0)).max() > 6.0:
                        continue
                    if any(point_in_tri(p, *ot) for p in samples(t[i])) or any(point_in_tri(p, *t[i]) for p in samples(ot)):
                        ca, cb = pr["comp"][i], prims[opi]["comp"][oi]
                        vol = lambda c: np.prod(np.maximum(comps[c]["hi"] - comps[c]["lo"], 0.001))
                        loser = ca if vol(ca) <= vol(cb) else cb
                        comps[loser]["n"][nk] = n[i]
                        found = True
                buckets.setdefault((nk, slab), []).append((pi, i, d, t[i]))
        if not found:
            break
        for c in comps:
            if not c["n"]:
                continue
            pr = prims[c["prim"]]
            centre = (c["lo"] + c["hi"]) * 0.5
            vs = np.unique(pr["idx"][c["tris"]].reshape(-1))
            for v in vs:
                add = np.zeros(3)
                for nv in c["n"].values():
                    if (pr["P"][v] - centre) @ nv > -1e-4:
                        add += nv * LIFT
                pr["P"][v] += add
            c["n"] = {}
            lo_hi = pr["P"][np.unique(pr["idx"][c["tris"]].reshape(-1))]
            c["lo"], c["hi"] = lo_hi.min(axis=0), lo_hi.max(axis=0)
            stats["lifted"] += 1

    return prims, stats

def write_glb(js, binc, meshes_new, path):
    # the scene becomes one node with one mesh holding the repaired, world-space primitives
    mats = [p["mat"] for p in meshes_new]
    old_meshes = js.get("meshes", [])
    js["meshes"] = [{"name": os.path.splitext(os.path.basename(path))[0], "primitives": [({"attributes": {}, "material": m} if m is not None else {"attributes": {}}) for m in mats]}] + old_meshes
    keep = js.pop("_collision", [])
    # collision hulls (Godot imports "-convcolonly" nodes as colliders) keep their own meshes and transforms
    col_meshes = []
    for c in keep:
        col_meshes.append(c["mesh"])
    js["nodes"] = [{"name": os.path.splitext(os.path.basename(path))[0], "mesh": 0}] + [{"name": c["name"], "mesh": c["mesh"] + 1, "matrix": c["matrix"]} for c in keep]
    js["scenes"] = [{"nodes": list(range(len(js["nodes"])))}]
    js["scene"] = 0
    meshes_new = {0: meshes_new}
    blob = bytearray(binc)
    def add_view(arr, target):
        while len(blob) % 4:
            blob.append(0)
        off = len(blob)
        blob.extend(arr.tobytes())
        js["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": arr.nbytes, "target": target})
        return len(js["bufferViews"]) - 1
    def add_acc(arr, comp, typ, view, extra=None):
        a = {"bufferView": view, "componentType": comp, "count": int(len(arr)), "type": typ}
        if extra:
            a.update(extra)
        js["accessors"].append(a)
        return len(js["accessors"]) - 1
    for mi, prims in meshes_new.items():
        for pr_json, pr in zip(js["meshes"][mi]["primitives"], prims):
            P = pr["P"].astype(np.float32)
            used = np.unique(pr["idx"])
            attrs = {"POSITION": add_acc(P, 5126, "VEC3", add_view(P, 34962), {"min": P.min(axis=0).tolist(), "max": P.max(axis=0).tolist()})}
            if pr["N"] is not None:
                attrs["NORMAL"] = add_acc(pr["N"], 5126, "VEC3", add_view(pr["N"], 34962))
            if pr["U"] is not None:
                attrs["TEXCOORD_0"] = add_acc(pr["U"], 5126, "VEC2", add_view(pr["U"], 34962))
            idx = pr["idx"].reshape(-1).astype(np.uint32)
            pr_json["attributes"] = attrs
            pr_json["indices"] = add_acc(idx, 5125, "SCALAR", add_view(idx, 34963))
    js["buffers"][0]["byteLength"] = len(blob)
    for m in js.get("materials", []):
        pbr = m.get("pbrMetallicRoughness")
        if pbr and pbr.get("metallicFactor", 0) > 0.5:
            pbr["metallicFactor"] = 0.2
            pbr["roughnessFactor"] = max(pbr.get("roughnessFactor", 0.8), 0.8)
    jb = json.dumps(js, separators=(",", ":")).encode()
    while len(jb) % 4:
        jb += b" "
    while len(blob) % 4:
        blob.append(0)
    out = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(jb) + 8 + len(blob))
    out += struct.pack("<II", len(jb), 0x4E4F534A) + jb + struct.pack("<II", len(blob), 0x004E4942) + bytes(blob)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "wb").write(out)

def write_import(src_glb, dst_glb):
    """Same import settings as the Veil original (its materials are mapped to the Veil .tres files), new source path, fresh uid."""
    src = open(src_glb + ".import").read() if os.path.exists(src_glb + ".import") else None
    if src is None:
        return
    rel = "res://" + os.path.relpath(dst_glb, ROOT).replace(os.sep, "/")
    lines = []
    for l in src.split("\n"):
        if l.startswith("uid=") or l.startswith("path=") or l.startswith("dest_files="):
            continue
        if l.startswith("source_file="):
            l = 'source_file="%s"' % rel
        # the over-shiny Veil brushed metal is replaced by the Quarry Days version (same texture, matte)
        l = l.replace("res://THE_VEIL_ASSETS_V2/Materials_Godot/Furniture/M_Furn_MetalBrushed.tres", "res://assets/materials/M_QD_MetalBrushed.tres")
        lines.append(l)
    open(dst_glb + ".import", "w").write("\n".join(lines))

def main():
    total = {"files": 0, "dropped": 0, "lifted": 0}
    for f in sorted(glob.glob(os.path.join(SRC, "**", "*.glb"), recursive=True)):
        rel = os.path.relpath(f, SRC)
        js, binc = load_glb(f)
        prims = flatten(js, binc)
        out = os.path.join(DST, rel)
        if prims is None:
            shutil.copy2(f, out) if os.path.isdir(os.path.dirname(out)) else (os.makedirs(os.path.dirname(out), exist_ok=True), shutil.copy2(f, out))
            continue
        prims, st = repair_core(prims)
        write_glb(js, binc, prims, out)
        write_import(f, out)
        total["files"] += 1
        total["dropped"] += st["dropped"]
        total["lifted"] += st["lifted"]
        print("%-70s dropped %3d faces, separated %3d parts" % (rel, st["dropped"], st["lifted"]))
    # textures keep their relative folders
    for f in glob.glob(os.path.join(SRC, "**", "*.png"), recursive=True):
        dst = os.path.join(DST, os.path.relpath(f, SRC))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(f, dst)
    print(total)

if __name__ == "__main__":
    main()
