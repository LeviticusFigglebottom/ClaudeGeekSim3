"""
glb — a minimal glTF 2.0 binary writer plus a low-poly mesh builder.

No dependencies beyond numpy. Produces .glb files that Godot 4 imports as
scenes. Meshes carry POSITION, NORMAL, TEXCOORD_0 and COLOR_0 so props can be
vertex-coloured, textured, or both.

Material naming convention (read by src/kit/props.gd at runtime):
    "tex:<group>/<name>"   -> replaced with the Kit's textured material
    "glow:<hex>"           -> unshaded emissive colour
    anything else          -> vertex-coloured lit material

Node names and `extras` survive import (extras become Godot node metadata), so
a prop can say {"collision": "box"} or name its door leaf "Leaf" for the game
to animate.
"""
from __future__ import annotations

import json
import math
import struct
from pathlib import Path

import numpy as np


# --------------------------------------------------------------------------
# transforms
# --------------------------------------------------------------------------

def mat_identity():
    return np.eye(4, dtype=np.float64)


def mat_translate(x, y, z):
    m = mat_identity()
    m[:3, 3] = (x, y, z)
    return m


def mat_scale(x, y=None, z=None):
    y = x if y is None else y
    z = x if z is None else z
    m = mat_identity()
    m[0, 0], m[1, 1], m[2, 2] = x, y, z
    return m


def mat_rot_x(a):
    c, s = math.cos(a), math.sin(a)
    m = mat_identity()
    m[1, 1], m[1, 2], m[2, 1], m[2, 2] = c, -s, s, c
    return m


def mat_rot_y(a):
    c, s = math.cos(a), math.sin(a)
    m = mat_identity()
    m[0, 0], m[0, 2], m[2, 0], m[2, 2] = c, s, -s, c
    return m


def mat_rot_z(a):
    c, s = math.cos(a), math.sin(a)
    m = mat_identity()
    m[0, 0], m[0, 1], m[1, 0], m[1, 1] = c, -s, s, c
    return m


def compose(*mats):
    m = mat_identity()
    for x in mats:
        m = m @ x
    return m


# --------------------------------------------------------------------------
# mesh builder
# --------------------------------------------------------------------------

class MeshBuilder:
    """Accumulates triangles per material. Coordinates: +Y up, -Z forward
    (Godot convention). Units are metres."""

    def __init__(self):
        self.prims = {}  # material -> dict(pos, nrm, uv, col, idx)
        self.stack = [mat_identity()]

    # -- transform stack ----------------------------------------------------
    def push(self, m):
        self.stack.append(self.stack[-1] @ m)

    def pop(self):
        self.stack.pop()

    @property
    def xf(self):
        return self.stack[-1]

    def _prim(self, mat):
        if mat not in self.prims:
            self.prims[mat] = dict(pos=[], nrm=[], uv=[], col=[], idx=[])
        return self.prims[mat]

    def _xf_point(self, p):
        v = self.xf @ np.array([p[0], p[1], p[2], 1.0])
        return v[:3]

    def _xf_normal(self, n):
        v = self.xf[:3, :3] @ np.asarray(n, dtype=np.float64)
        ln = np.linalg.norm(v)
        return v / ln if ln > 1e-9 else v

    # -- primitives -----------------------------------------------------------
    def tri(self, a, b, c, mat="flat", color=(1, 1, 1), uvs=None, normal=None):
        p = self._prim(mat)
        a, b, c = self._xf_point(a), self._xf_point(b), self._xf_point(c)
        if normal is None:
            n = np.cross(b - a, c - a)
            ln = np.linalg.norm(n)
            n = n / ln if ln > 1e-9 else np.array([0, 1, 0.0])
        else:
            n = self._xf_normal(normal)
        base = len(p["pos"])
        if uvs is None:
            uvs = [(0, 0), (1, 0), (1, 1)]
        for v, uv in zip((a, b, c), uvs):
            p["pos"].append(v)
            p["nrm"].append(n)
            p["uv"].append(uv)
            p["col"].append(color)
        p["idx"].extend([base, base + 1, base + 2])

    def quad(self, a, b, c, d, mat="flat", color=(1, 1, 1), uvs=None, normal=None, double=False):
        """Counter-clockwise quad a,b,c,d (front face toward viewer)."""
        if uvs is None:
            uvs = [(0, 0), (1, 0), (1, 1), (0, 1)]
        self.tri(a, b, c, mat, color, [uvs[0], uvs[1], uvs[2]], normal)
        self.tri(a, c, d, mat, color, [uvs[0], uvs[2], uvs[3]], normal)
        if double:
            self.tri(a, c, b, mat, color, [uvs[0], uvs[2], uvs[1]], None if normal is None else -np.asarray(normal))
            self.tri(a, d, c, mat, color, [uvs[0], uvs[3], uvs[2]], None if normal is None else -np.asarray(normal))

    def box(self, center, size, mat="flat", color=(1, 1, 1), uv_scale=1.0, faces=None, colors=None):
        """Axis-aligned box. `faces` may restrict to a subset of
        ('px','nx','py','ny','pz','nz'). `colors` may map face -> colour."""
        cx, cy, cz = center
        sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
        x0, x1, y0, y1, z0, z1 = cx - sx, cx + sx, cy - sy, cy + sy, cz - sz, cz + sz
        defs = {
            "pz": ([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], (size[0], size[1]), (0, 0, 1)),
            "nz": ([(x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0)], (size[0], size[1]), (0, 0, -1)),
            "px": ([(x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1)], (size[2], size[1]), (1, 0, 0)),
            "nx": ([(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)], (size[2], size[1]), (-1, 0, 0)),
            "py": ([(x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0)], (size[0], size[2]), (0, 1, 0)),
            "ny": ([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], (size[0], size[2]), (0, -1, 0)),
        }
        for f, (pts, (uw, uh), n) in defs.items():
            if faces is not None and f not in faces:
                continue
            col = colors.get(f, color) if colors else color
            uvs = [(0, 0), (uw * uv_scale, 0), (uw * uv_scale, uh * uv_scale), (0, uh * uv_scale)]
            self.quad(*pts, mat=mat, color=col, uvs=uvs, normal=n)

    def lathe(self, profile, segments=8, mat="flat", color=(1, 1, 1), smooth=True, uv_scale=1.0, cap_top=True, cap_bottom=True, colors=None, twist=0.0):
        """Revolve a profile [(radius, y), ...] (bottom to top) around Y."""
        p = self._prim(mat)
        rings = []
        for k, (r, y) in enumerate(profile):
            ring = []
            for s in range(segments + 1):
                a = (s / segments) * math.tau + twist * k
                ring.append(np.array([math.cos(a) * r, y, math.sin(a) * r]))
            rings.append(ring)
        # normals via neighbouring profile points
        for k in range(len(profile) - 1):
            r0, y0 = profile[k]
            r1, y1 = profile[k + 1]
            col = colors[k] if colors else color
            for s in range(segments):
                a0 = rings[k][s]
                a1 = rings[k][s + 1]
                b0 = rings[k + 1][s]
                b1 = rings[k + 1][s + 1]
                us, vs = (uv_scale, uv_scale) if not isinstance(uv_scale, (tuple, list)) else uv_scale
                u0, u1 = s / segments * us, (s + 1) / segments * us
                v0, v1 = y0 * vs, y1 * vs
                if smooth:
                    dy = y1 - y0
                    dr = r1 - r0
                    ln = math.hypot(dy, dr) or 1.0
                    ny, nr = dr / ln, dy / ln  # outward normal of the segment
                    def nrm(s_):
                        a = (s_ / segments) * math.tau
                        return self._xf_normal((math.cos(a) * nr, -ny, math.sin(a) * nr))
                    base = len(p["pos"])
                    for v, uv, n in ((a0, (u0, v0), nrm(s)), (a1, (u1, v0), nrm(s + 1)), (b1, (u1, v1), nrm(s + 1)), (b0, (u0, v1), nrm(s))):
                        p["pos"].append(self._xf_point(v))
                        p["nrm"].append(n)
                        p["uv"].append(uv)
                        p["col"].append(col)
                    if r0 > 1e-6:
                        p["idx"].extend([base, base + 2, base + 1])
                    if r1 > 1e-6:
                        p["idx"].extend([base, base + 3, base + 2])
                else:
                    if r0 > 1e-6:
                        self.tri(a0, b1, a1, mat, col, [(u0, v0), (u1, v1), (u1, v0)])
                    if r1 > 1e-6:
                        self.tri(a0, b0, b1, mat, col, [(u0, v0), (u0, v1), (u1, v1)])
        if cap_bottom and profile[0][0] > 1e-6:
            r, y = profile[0]
            c = np.array([0, y, 0.0])
            for s in range(segments):
                self.tri(c, rings[0][s], rings[0][s + 1], mat, colors[0] if colors else color, normal=(0, -1, 0))
        if cap_top and profile[-1][0] > 1e-6:
            r, y = profile[-1]
            c = np.array([0, y, 0.0])
            for s in range(segments):
                self.tri(c, rings[-1][s + 1], rings[-1][s], mat, colors[-1] if colors else color, normal=(0, 1, 0))

    def cylinder(self, center, radius, height, segments=8, mat="flat", color=(1, 1, 1), radius_top=None, smooth=True, uv_scale=1.0, caps=True):
        rt = radius if radius_top is None else radius_top
        self.push(mat_translate(*center))
        self.lathe([(radius, -height / 2), (rt, height / 2)], segments, mat, color, smooth, uv_scale, cap_top=caps, cap_bottom=caps)
        self.pop()

    def cone(self, center, radius, height, segments=8, mat="flat", color=(1, 1, 1)):
        self.push(mat_translate(*center))
        self.lathe([(radius, -height / 2), (0.0, height / 2)], segments, mat, color, smooth=False, cap_top=False)
        self.pop()

    def sphere(self, center, radius, rings=5, segments=8, mat="flat", color=(1, 1, 1), smooth=True, squash=1.0):
        prof = []
        for i in range(rings + 1):
            t = i / rings
            a = -math.pi / 2 + t * math.pi
            prof.append((math.cos(a) * radius, math.sin(a) * radius * squash))
        self.push(mat_translate(*center))
        self.lathe(prof, segments, mat, color, smooth, cap_top=False, cap_bottom=False)
        self.pop()

    def blob(self, center, radius, rng, rings=5, segments=8, mat="flat", color=(1, 1, 1), jitter=0.25):
        """A lumpy sphere (canopies, bushes, boulders)."""
        prof = []
        for i in range(rings + 1):
            t = i / rings
            a = -math.pi / 2 + t * math.pi
            r = math.cos(a) * radius * (1.0 + (rng.random() - 0.5) * jitter if 0 < i < rings else 1.0)
            prof.append((r, math.sin(a) * radius))
        self.push(mat_translate(*center))
        self.lathe(prof, segments, mat, color, smooth=False, cap_top=False, cap_bottom=False, twist=jitter * 0.3)
        self.pop()

    def card(self, center, size, mat, color=(1, 1, 1), yaw=0.0, double=True, tilt=0.0):
        """An upright textured quad (alpha-cut leaves, banners, faces)."""
        w, h = size
        self.push(compose(mat_translate(*center), mat_rot_y(yaw), mat_rot_x(tilt)))
        self.quad((-w / 2, -h / 2, 0), (w / 2, -h / 2, 0), (w / 2, h / 2, 0), (-w / 2, h / 2, 0), mat=mat, color=color,
                  uvs=[(0, 1), (1, 1), (1, 0), (0, 0)], normal=(0, 0, 1), double=double)
        self.pop()

    def cross_cards(self, center, size, mat, color=(1, 1, 1), n=2, tilt=0.0):
        for i in range(n):
            self.card(center, size, mat, color, yaw=math.pi / n * i, tilt=tilt)

    def prism(self, points_xz, y0, y1, mat="flat", color=(1, 1, 1), uv_scale=1.0, cap=True, floor=False):
        """Extrude a convex polygon (list of (x,z), CCW seen from above) between y0 and y1."""
        n = len(points_xz)
        for i in range(n):
            x0, z0 = points_xz[i]
            x1, z1 = points_xz[(i + 1) % n]
            w = math.hypot(x1 - x0, z1 - z0)
            self.quad((x1, y0, z1), (x0, y0, z0), (x0, y1, z0), (x1, y1, z1), mat, color,
                      uvs=[(0, 0), (w * uv_scale, 0), (w * uv_scale, (y1 - y0) * uv_scale), (0, (y1 - y0) * uv_scale)])
        if cap:
            cx = sum(p[0] for p in points_xz) / n
            cz = sum(p[1] for p in points_xz) / n
            for i in range(n):
                x0, z0 = points_xz[i]
                x1, z1 = points_xz[(i + 1) % n]
                self.tri((cx, y1, cz), (x1, y1, z1), (x0, y1, z0), mat, color, normal=(0, 1, 0),
                         uvs=[(cx * uv_scale, cz * uv_scale), (x1 * uv_scale, z1 * uv_scale), (x0 * uv_scale, z0 * uv_scale)])
        if floor:
            cx = sum(p[0] for p in points_xz) / n
            cz = sum(p[1] for p in points_xz) / n
            for i in range(n):
                x0, z0 = points_xz[i]
                x1, z1 = points_xz[(i + 1) % n]
                self.tri((cx, y0, cz), (x0, y0, z0), (x1, y0, z1), mat, color, normal=(0, -1, 0))

    def merge(self, other: "MeshBuilder", m=None):
        """Append another builder's geometry (optionally transformed)."""
        for mat, q in other.prims.items():
            p = self._prim(mat)
            base = len(p["pos"])
            for v, n, uv, c in zip(q["pos"], q["nrm"], q["uv"], q["col"]):
                if m is not None:
                    v4 = m @ np.array([v[0], v[1], v[2], 1.0])
                    v = v4[:3]
                    n = m[:3, :3] @ np.asarray(n)
                p["pos"].append(np.asarray(v))
                p["nrm"].append(np.asarray(n))
                p["uv"].append(uv)
                p["col"].append(c)
            p["idx"].extend([i + base for i in q["idx"]])

    def tri_count(self):
        return sum(len(p["idx"]) // 3 for p in self.prims.values())


# --------------------------------------------------------------------------
# glTF assembly
# --------------------------------------------------------------------------

def _pad4(b: bytes, fill=b"\x00") -> bytes:
    return b + fill * ((4 - len(b) % 4) % 4)


class GLB:
    """Assemble nodes (each with a MeshBuilder) into one .glb."""

    def __init__(self, name="prop"):
        self.name = name
        self.nodes = []   # dict(name, mesh, translation, extras, children)
        self.materials = {}
        self.mat_list = []

    def _material_index(self, name):
        if name in self.materials:
            return self.materials[name]
        idx = len(self.mat_list)
        base = [1.0, 1.0, 1.0, 1.0]
        m = {"name": name, "pbrMetallicRoughness": {"baseColorFactor": base, "metallicFactor": 0.0, "roughnessFactor": 1.0}}
        if name.startswith("glow:"):
            hexs = name[5:].lstrip("#")
            rgb = [int(hexs[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
            m["emissiveFactor"] = rgb
            m["pbrMetallicRoughness"]["baseColorFactor"] = rgb + [1.0]
        if name.startswith("tex:") and ("leaves" in name or "fern" in name or "chain" in name or "bars" in name or "grate" in name or "faces/" in name or "rune_ring" in name and "floor" not in name or "eye" in name or "graffiti" in name or "gear" in name):
            m["alphaMode"] = "MASK"
            m["alphaCutoff"] = 0.5
            m["doubleSided"] = True
        # every prop is double-sided: a roof seen from under it, the inside of a
        # hollow thing, the back of a card, all draw instead of vanishing
        m["doubleSided"] = True
        self.materials[name] = idx
        self.mat_list.append(m)
        return idx

    def add(self, name, mesh: MeshBuilder, translation=(0, 0, 0), extras=None, parent=None):
        node = dict(name=name, mesh=mesh, translation=list(translation), extras=extras or {}, children=[], parent=parent)
        self.nodes.append(node)
        return len(self.nodes) - 1

    def write(self, path: Path):
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        blob = bytearray()
        buffer_views = []
        accessors = []
        meshes = []
        gnodes = []

        def add_view(data: bytes, target=None):
            off = len(blob)
            blob.extend(data)
            while len(blob) % 4:
                blob.append(0)
            bv = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
            if target:
                bv["target"] = target
            buffer_views.append(bv)
            return len(buffer_views) - 1

        def add_accessor(arr: np.ndarray, ctype, atype, target=None, minmax=False):
            data = arr.astype(np.float32 if ctype == 5126 else np.uint32).tobytes()
            view = add_view(data, target)
            acc = {"bufferView": view, "componentType": ctype, "count": int(arr.shape[0]), "type": atype}
            if minmax:
                acc["min"] = [float(x) for x in arr.min(axis=0)]
                acc["max"] = [float(x) for x in arr.max(axis=0)]
            accessors.append(acc)
            return len(accessors) - 1

        for node in self.nodes:
            prims = []
            for mat, p in node["mesh"].prims.items():
                if not p["idx"]:
                    continue
                pos = np.array(p["pos"], dtype=np.float32).reshape(-1, 3)
                nrm = np.array(p["nrm"], dtype=np.float32).reshape(-1, 3)
                uv = np.array(p["uv"], dtype=np.float32).reshape(-1, 2)
                col = np.array([(c[0], c[1], c[2], 1.0) for c in p["col"]], dtype=np.float32).reshape(-1, 4)
                idx = np.array(p["idx"], dtype=np.uint32)
                prim = {
                    "attributes": {
                        "POSITION": add_accessor(pos, 5126, "VEC3", 34962, True),
                        "NORMAL": add_accessor(nrm, 5126, "VEC3", 34962),
                        "TEXCOORD_0": add_accessor(uv, 5126, "VEC2", 34962),
                        "COLOR_0": add_accessor(col, 5126, "VEC4", 34962),
                    },
                    "indices": add_accessor(idx, 5125, "SCALAR", 34963),
                    "material": self._material_index(mat),
                    "mode": 4,
                }
                prims.append(prim)
            mesh_index = None
            if prims:
                meshes.append({"name": node["name"] + "_mesh", "primitives": prims})
                mesh_index = len(meshes) - 1
            g = {"name": node["name"], "translation": node["translation"]}
            if mesh_index is not None:
                g["mesh"] = mesh_index
            if node["extras"]:
                g["extras"] = node["extras"]
            gnodes.append(g)
        # hierarchy
        roots = []
        for i, node in enumerate(self.nodes):
            if node["parent"] is None:
                roots.append(i)
            else:
                gnodes[node["parent"]].setdefault("children", []).append(i)
        gltf = {
            "asset": {"version": "2.0", "generator": "anteroom glb.py"},
            "scene": 0,
            "scenes": [{"name": self.name, "nodes": roots}],
            "nodes": gnodes,
            "meshes": meshes,
            "materials": self.mat_list,
            "accessors": accessors,
            "bufferViews": buffer_views,
            "buffers": [{"byteLength": len(blob)}],
        }
        js = _pad4(json.dumps(gltf, separators=(",", ":")).encode("utf-8"), b" ")
        bin_chunk = _pad4(bytes(blob))
        total = 12 + 8 + len(js) + 8 + len(bin_chunk)
        with open(path, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, total))
            f.write(struct.pack("<II", len(js), 0x4E4F534A))
            f.write(js)
            f.write(struct.pack("<II", len(bin_chunk), 0x004E4942))
            f.write(bin_chunk)
        return total


def read_check(path: Path) -> dict:
    """Parse a .glb header and JSON chunk (sanity check)."""
    with open(path, "rb") as f:
        magic, version, length = struct.unpack("<III", f.read(12))
        assert magic == 0x46546C67 and version == 2, "bad glb header"
        jl, jt = struct.unpack("<II", f.read(8))
        js = json.loads(f.read(jl).decode("utf-8"))
        bl, bt = struct.unpack("<II", f.read(8))
        assert bt == 0x004E4942
        assert 12 + 8 + jl + 8 + bl == length, "length mismatch"
    return js
