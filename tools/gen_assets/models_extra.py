"""
models_extra — second prop batch for ANTEROOM: figures, keepsake items, the
offices, catacombs, furnace, cistern, slow sea, city/castle, forest/tavern and
house extras.

models.py imports this module automatically (see _load_extra) and every
generator registers itself into the shared CATALOG with reg(name, fn).
Conventions are the same as models.py: +Y up, the prop faces -Z, the origin is
the base centre on the ground (hanging props: the attachment point), metres,
low poly. Materials: "tex:<group>/<name>" (textured, tinted by vertex colour),
"glow:#rrggbb" (unshaded emissive), anything else = lit vertex colour. Child
nodes named "Head", "Hand", "Tail", "Wings", "Eye", "Screen", "Lid", "Fire",
"Door" are found by the game and animated. extras carry a collision hint.
"""
from __future__ import annotations

import math

import numpy as np

from glb import GLB, MeshBuilder, compose, mat_rot_x, mat_rot_y, mat_rot_z, mat_scale, mat_translate  # noqa: E402
from models import reg, single, hexc, vary, rng_for  # noqa: E402,F401

# When models.py runs as a script it is `__main__` and the line above imports a
# second copy of it; make sure the props also land in the live catalogue.
import sys as _sys  # noqa: E402

_main = _sys.modules.get("__main__")
if getattr(_main, "CATALOG", None) is not None and _main is not _sys.modules.get("models"):
    _reg_imported = reg

    def reg(name, fn):  # noqa: F811
        _reg_imported(name, fn)
        _main.CATALOG[name] = fn
        return fn

PI = math.pi
TAU = math.tau
DARK = "glow:#050409"
WHITE = (1.0, 1.0, 1.0)
SKIN = "tex:fabric/skin"


# --------------------------------------------------------------------------
# geometry helpers
# --------------------------------------------------------------------------

def _quadn(m, pts, want, mat="flat", col=WHITE, uvs=None, double=False):
    """Quad whose visible side faces roughly along `want` (winding fixed automatically)."""
    a, b, c, _ = [np.asarray(p, dtype=float) for p in pts]
    n = np.cross(b - a, c - a)
    if float(n @ np.asarray(want, dtype=float)) < 0:
        pts = [pts[0], pts[3], pts[2], pts[1]]
        if uvs is not None:
            uvs = [uvs[0], uvs[3], uvs[2], uvs[1]]
    m.quad(*pts, mat=mat, color=col, uvs=uvs, double=double)


def _trin(m, a, b, c, want, mat="flat", col=WHITE, uvs=None, double=False):
    a_, b_, c_ = [np.asarray(p, dtype=float) for p in (a, b, c)]
    n = np.cross(b_ - a_, c_ - a_)
    if float(n @ np.asarray(want, dtype=float)) < 0:
        b, c = c, b
        if uvs is not None:
            uvs = [uvs[0], uvs[2], uvs[1]]
    m.tri(a, b, c, mat, col, uvs)
    if double:
        m.tri(a, c, b, mat, col, None if uvs is None else [uvs[0], uvs[2], uvs[1]])


def _aim(a, b):
    """Matrix whose origin is `a` and whose +Y axis points at `b`; returns (M, length)."""
    a = np.asarray(a, dtype=float)
    b = np.asarray(b, dtype=float)
    d = b - a
    L = float(np.linalg.norm(d))
    u = d / L if L > 1e-9 else np.array([0.0, 1.0, 0.0])
    helper = np.array([1.0, 0.0, 0.0]) if abs(u[0]) < 0.9 else np.array([0.0, 0.0, 1.0])
    v1 = np.cross(helper, u)
    v1 /= np.linalg.norm(v1)
    v2 = np.cross(v1, u)
    M = np.eye(4)
    M[:3, 0], M[:3, 1], M[:3, 2], M[:3, 3] = v1, u, v2, a
    return M, L


def _bar(m, a, b, t, mat="flat", col=WHITE, tz=None, uv_scale=1.0):
    """A box of cross-section t x (tz or t) running from point a to point b."""
    M, L = _aim(a, b)
    m.push(M)
    m.box((0, L / 2, 0), (t, L, t if tz is None else tz), mat, col, uv_scale=uv_scale)
    m.pop()


def _limb(m, a, b, r0, r1, mat="flat", col=WHITE, segs=6, smooth=True, caps=True):
    """A tapered lathe (limb, branch, pipe) from point a to point b."""
    M, L = _aim(a, b)
    m.push(M)
    m.lathe([(r0, 0.0), (r1, L)], segs, mat, col, smooth=smooth, cap_bottom=caps, cap_top=caps)
    m.pop()


def _disc(m, center, R, segs=8, mat="flat", col=WHITE, up=True, uv_scale=1.0, r_in=0.0, a0=0.0):
    """A flat disc (or ring when r_in > 0) with planar UVs, facing up or down."""
    cx, cy, cz = center
    want = (0, 1, 0) if up else (0, -1, 0)

    def uv(p):
        return (p[0] * uv_scale, p[2] * uv_scale)
    for s in range(segs):
        t0 = a0 + s / segs * TAU
        t1 = a0 + (s + 1) / segs * TAU
        p0 = (cx + math.cos(t0) * R, cy, cz + math.sin(t0) * R)
        p1 = (cx + math.cos(t1) * R, cy, cz + math.sin(t1) * R)
        if r_in > 1e-6:
            q0 = (cx + math.cos(t0) * r_in, cy, cz + math.sin(t0) * r_in)
            q1 = (cx + math.cos(t1) * r_in, cy, cz + math.sin(t1) * r_in)
            _quadn(m, [q0, p0, p1, q1], want, mat, col, uvs=[uv(q0), uv(p0), uv(p1), uv(q1)])
        else:
            c = (cx, cy, cz)
            _trin(m, c, p0, p1, want, mat, col, uvs=[uv(c), uv(p0), uv(p1)])


def _arch(m, center, r_in, r_out, depth, segs=6, mat="flat", col=WHITE, colors=None, uv_scale=1.0, a0=0.0, a1=PI):
    """A ring segment in the XY plane (angles a0..a1, from +X over the top to -X),
    extruded along Z by `depth` and centred on `center`."""
    cx, cy, cz = center
    z0, z1 = cz - depth / 2, cz + depth / 2

    def P(p, z):
        return (p[0], p[1], z)

    def uvf(p):
        return (p[0] * uv_scale, p[1] * uv_scale)
    for s in range(segs):
        t0 = a0 + (a1 - a0) * s / segs
        t1 = a0 + (a1 - a0) * (s + 1) / segs
        c = colors[s % len(colors)] if colors else col
        i0 = (cx + math.cos(t0) * r_in, cy + math.sin(t0) * r_in)
        i1 = (cx + math.cos(t1) * r_in, cy + math.sin(t1) * r_in)
        o0 = (cx + math.cos(t0) * r_out, cy + math.sin(t0) * r_out)
        o1 = (cx + math.cos(t1) * r_out, cy + math.sin(t1) * r_out)
        _quadn(m, [P(i0, z0), P(o0, z0), P(o1, z0), P(i1, z0)], (0, 0, -1), mat, c, uvs=[uvf(i0), uvf(o0), uvf(o1), uvf(i1)])
        _quadn(m, [P(i0, z1), P(o0, z1), P(o1, z1), P(i1, z1)], (0, 0, 1), mat, c, uvs=[uvf(i0), uvf(o0), uvf(o1), uvf(i1)])
        mid = (t0 + t1) / 2
        nout = (math.cos(mid), math.sin(mid), 0)
        w = (t1 - t0) * r_out * uv_scale
        d = depth * uv_scale
        _quadn(m, [P(o0, z0), P(o1, z0), P(o1, z1), P(o0, z1)], nout, mat, c, uvs=[(0, 0), (w, 0), (w, d), (0, d)])
        _quadn(m, [P(i0, z0), P(i1, z0), P(i1, z1), P(i0, z1)], (-nout[0], -nout[1], 0), mat, c, uvs=[(0, 0), (w, 0), (w, d), (0, d)])
        if s == 0:
            _quadn(m, [P(i0, z0), P(o0, z0), P(o0, z1), P(i0, z1)], (math.sin(t0), -math.cos(t0), 0), mat, c)
        if s == segs - 1:
            _quadn(m, [P(i1, z0), P(o1, z0), P(o1, z1), P(i1, z1)], (-math.sin(t1), math.cos(t1), 0), mat, c)


def _torus(m, center, R, r, segs=12, psegs=6, mat="flat", col=WHITE, col_fn=None):
    """A ring (axis Y) built from quads so colour can vary around it."""
    cx, cy, cz = center

    def P(i, j):
        a = i / segs * TAU
        b = j / psegs * TAU
        rr = R + math.cos(b) * r
        return (cx + math.cos(a) * rr, cy + math.sin(b) * r, cz + math.sin(a) * rr)
    for i in range(segs):
        c = col_fn(i) if col_fn else col
        for j in range(psegs):
            a = (i + 0.5) / segs * TAU
            b = (j + 0.5) / psegs * TAU
            want = (math.cos(a) * math.cos(b), math.sin(b), math.sin(a) * math.cos(b))
            _quadn(m, [P(i, j), P(i + 1, j), P(i + 1, j + 1), P(i, j + 1)], want, mat, c)


def _band(m, center, R, h, segs=10, mat="tex:metal/chain", col=WHITE, reps=8.0, tilt=0.0, roll=0.0, scale=(1, 1, 1)):
    """A cylindrical band whose texture runs *around* the ring (chains wrapped round a body)."""
    m.push(compose(mat_translate(*center), mat_rot_x(tilt), mat_rot_z(roll), mat_scale(*scale)))
    for s in range(segs):
        t0, t1 = s / segs * TAU, (s + 1) / segs * TAU
        p = [(math.cos(t0) * R, -h / 2, math.sin(t0) * R), (math.cos(t1) * R, -h / 2, math.sin(t1) * R),
             (math.cos(t1) * R, h / 2, math.sin(t1) * R), (math.cos(t0) * R, h / 2, math.sin(t0) * R)]
        v0, v1 = s / segs * reps, (s + 1) / segs * reps
        mid = (t0 + t1) / 2
        _quadn(m, p, (math.cos(mid), 0, math.sin(mid)), mat, col, uvs=[(0, v0), (0, v1), (1, v1), (1, v0)])
    m.pop()


def _settle(m, y=0.0):
    """Shift every vertex so the lowest point sits at height y."""
    lo = min(float(np.min(np.array(p["pos"])[:, 1])) for p in m.prims.values() if p["pos"])
    dy = y - lo
    if abs(dy) < 1e-9:
        return
    off = np.array([0.0, dy, 0.0])
    for p in m.prims.values():
        p["pos"] = [np.asarray(v, dtype=float) + off for v in p["pos"]]


def _flame(m, center, r, h, outer="glow:#ff8a2f", inner="glow:#ffd27f", segs=5):
    cx, cy, cz = center
    m.push(mat_translate(cx, cy, cz))
    m.lathe([(r, 0.0), (r * 0.6, h * 0.45), (r * 0.22, h * 0.8), (0.0, h)], segs, outer, WHITE, smooth=False, cap_bottom=False, cap_top=False, twist=0.4)
    m.lathe([(r * 0.55, 0.01), (r * 0.3, h * 0.35), (0.0, h * 0.55)], segs, inner, WHITE, smooth=False, cap_bottom=False, cap_top=False, twist=-0.5)
    m.pop()


def _candle(m, center, r=0.03, h=0.2, col=(0.95, 0.9, 0.8), segs=6, flame=True):
    cx, cy, cz = center
    m.push(mat_translate(cx, cy, cz))
    m.lathe([(r, 0.0), (r, h)], segs, "flat", col, smooth=False)
    if flame:
        m.lathe([(r * 0.7, h), (r * 0.35, h + r * 2.2), (0.0, h + r * 3.2)], 4, "glow:#ffd27f", WHITE, smooth=False, cap_bottom=False, cap_top=False)
    m.pop()


def _bottle(m, center, col, r=0.06, h=0.36, glow=None):
    cx, cy, cz = center
    m.push(mat_translate(cx, cy, cz))
    m.lathe([(r, 0), (r, h * 0.55), (r * 0.42, h * 0.7), (r * 0.42, h), (0.0, h)], 6, "flat" if glow is None else "glow:" + glow, col, smooth=True)
    m.pop()


def _mug(m, center, col, r=0.06, h=0.14):
    cx, cy, cz = center
    m.push(mat_translate(cx, cy, cz))
    m.lathe([(r, 0), (r, h), (r * 0.8, h), (r * 0.8, 0.02)], 6, "flat", col, smooth=False, cap_top=False)
    m.box((r + 0.02, h * 0.5, 0), (0.03, h * 0.6, 0.02), "flat", col)
    m.pop()


# --------------------------------------------------------------------------
# figure helpers
# --------------------------------------------------------------------------

def _biped(m, h=1.8, top=("flat", (0.5, 0.45, 0.4)), legs=("flat", (0.25, 0.22, 0.2)), skin=(SKIN, WHITE),
           width=1.0, sleeves=False, hands=True, feet=True, arms=True, boots=(0.12, 0.1, 0.09)):
    """Blocky standing body (legs, torso, arms, neck, no head). Returns the neck-base height."""
    s = h / 1.8
    hip, sh = 0.85 * s, 1.42 * s
    tw, td = 0.42 * s * width, 0.24 * s * width
    lw = 0.16 * s * width
    tmat, tcol = top
    lmat, lcol = legs
    smat, scol = skin
    for x in (-0.1 * s * width, 0.1 * s * width):
        m.box((x, hip / 2 + 0.01, 0), (lw, hip, lw * 1.1), lmat, lcol)
        if feet:
            m.box((x, 0.04 * s, -0.04 * s), (lw * 1.05, 0.08 * s, lw * 1.7), "flat", boots)
    m.box((0, (hip + sh) / 2 + 0.03 * s, 0), (tw, sh - hip + 0.06 * s, td), tmat, tcol)
    ax = tw / 2 + 0.06 * s * width
    aw = 0.11 * s * width
    al = 0.62 * s
    if arms:
        for x in (-ax, ax):
            if not sleeves:
                m.box((x, sh - al / 2, 0), (aw, al, aw), tmat, tcol)
            else:
                m.box((x, sh - al * 0.25, 0), (aw, al * 0.5, aw), tmat, tcol)
                m.box((x, sh - al * 0.75, 0), (aw * 0.85, al * 0.5 + 0.01, aw * 0.85), smat, scol)
            if hands:
                m.box((x, sh - al - 0.06 * s, 0), (aw * 0.9, 0.12 * s, aw * 0.7), smat, scol)
    m.box((0, sh + 0.05 * s, 0), (0.1 * s, 0.1 * s, 0.1 * s), smat, scol)
    return sh + 0.08 * s


def _head_node(g, neck_y, r=0.125, mat=SKIN, col=WHITE, extra=None, parent=None, hair=None):
    hm = MeshBuilder()
    hm.sphere((0, r + 0.02, 0), r, 5, 8, mat, col)
    if hair is not None:
        hm.sphere((0, r + 0.05, 0.01), r * 1.05, 4, 8, "flat", hair, squash=0.55)
    if extra:
        extra(hm)
    return g.add("Head", hm, translation=(0, neck_y, 0), parent=parent)


def _lute(m, scale=1.0):
    """An upright lute: base at y=0, soundboard facing -Z, neck up and to +X. ~0.95 m tall."""
    s = scale
    m.push(compose(mat_translate(0, 0.27 * s, 0), mat_rot_x(PI / 2), mat_scale(s, s, s * 1.25)))
    m.lathe([(0.0, 0.0), (0.2, 0.0)], 8, "flat", (0.85, 0.7, 0.45), smooth=False, cap_bottom=False, cap_top=False)
    m.lathe([(0.2, 0.0), (0.21, 0.05), (0.15, 0.11), (0.0, 0.13)], 8, "tex:wood/planks_dark", WHITE, smooth=True, cap_bottom=False, cap_top=False)
    m.lathe([(0.0, -0.012), (0.05, -0.012)], 6, "flat", (0.1, 0.07, 0.05), smooth=False, cap_bottom=False, cap_top=False)
    m.pop()
    m.push(compose(mat_translate(0.02 * s, 0.5 * s, -0.02 * s), mat_rot_z(-0.28)))
    m.box((0, 0.2 * s, 0), (0.05 * s, 0.42 * s, 0.035 * s), "flat", (0.45, 0.3, 0.16))
    m.box((0, 0.44 * s, 0.01 * s), (0.06 * s, 0.1 * s, 0.05 * s), "flat", (0.2, 0.13, 0.08))
    m.pop()


# --------------------------------------------------------------------------
# figures
# --------------------------------------------------------------------------

def usher(rng):
    g = GLB("usher")
    coat = "tex:fabric/coat"
    m = MeshBuilder()
    for x in (-0.11, 0.11):
        m.box((x, 0.05, -0.05), (0.14, 0.1, 0.32), "flat", (0.08, 0.07, 0.08))
    m.lathe([(0.36, 0.08), (0.31, 0.8), (0.23, 1.55), (0.26, 2.02), (0.14, 2.1), (0.0, 2.1)], 8, coat, WHITE, smooth=True, uv_scale=(2.0, 1.0))
    m.box((0, 2.05, 0), (0.62, 0.12, 0.3), coat, (0.9, 0.9, 0.9))
    for x in (-0.33, 0.33):
        m.box((x, 1.6, 0), (0.11, 0.9, 0.13), coat, WHITE)
        m.box((x, 0.98, -0.02), (0.09, 0.36, 0.05), "flat", (0.92, 0.9, 0.86))
        m.box((x, 0.76, -0.02), (0.07, 0.1, 0.045), "flat", (0.9, 0.88, 0.84))
    g.add("Body", m, extras={"collision": "cylinder"})
    h = MeshBuilder()
    h.box((0, 0.2, 0.05), (0.26, 0.34, 0.1), "flat", (0.08, 0.08, 0.1))
    h.card((0, 0.21, -0.01), (0.34, 0.42), "tex:faces/usher", WHITE, yaw=PI)
    h.lathe([(0.46, 0.43), (0.46, 0.46), (0.2, 0.46), (0.2, 0.64), (0.0, 0.64)], 8, "flat", (0.07, 0.07, 0.08), smooth=False)
    g.add("Head", h, translation=(0, 2.1, 0))
    return g


reg("usher", usher)


def dog(rng):
    g = GLB("dog")
    fur = "tex:fabric/dog_fur"
    m = MeshBuilder()
    m.box((0, 0.4, 0.02), (0.3, 0.28, 0.6), fur, WHITE)
    m.box((0, 0.3, -0.2), (0.22, 0.1, 0.16), "flat", (0.93, 0.88, 0.78))
    for x in (-0.1, 0.1):
        for z in (-0.2, 0.22):
            m.box((x, 0.14, z), (0.1, 0.28, 0.11), fur, (0.9, 0.9, 0.9))
    m.box((0, 0.5, -0.24), (0.27, 0.05, 0.14), "flat", (0.75, 0.15, 0.12))
    g.add("Body", m, extras={"collision": "box"})
    h = MeshBuilder()
    h.box((0, 0.04, -0.1), (0.26, 0.24, 0.24), fur, WHITE)
    h.box((0, -0.03, -0.28), (0.15, 0.12, 0.14), fur, (0.95, 0.9, 0.85))
    h.box((0, 0.0, -0.37), (0.06, 0.05, 0.03), "flat", (0.08, 0.07, 0.07))
    for x in (-0.07, 0.07):
        h.box((x, 0.09, -0.225), (0.045, 0.045, 0.02), "flat", (0.08, 0.07, 0.07))
        h.box((x * 2.2, 0.06, -0.08), (0.06, 0.18, 0.11), fur, (0.7, 0.68, 0.65))
    g.add("Head", h, translation=(0, 0.5, -0.3))
    t = MeshBuilder()
    t.push(mat_rot_x(-0.7))
    t.box((0, 0, 0.15), (0.06, 0.06, 0.3), fur, (0.85, 0.85, 0.85))
    t.pop()
    g.add("Tail", t, translation=(0, 0.5, 0.3))
    return g


reg("dog", dog)


def patron_seated(rng):
    m = MeshBuilder()
    cloth = ("flat", (0.42, 0.38, 0.34))
    trous = ("flat", (0.24, 0.22, 0.2))
    hip = 0.45
    for x in (-0.1, 0.1):
        m.box((x, hip + 0.08, -0.22), (0.16, 0.16, 0.46), *trous)
        m.box((x, 0.24, -0.42), (0.14, 0.48, 0.14), *trous)
        m.box((x, 0.03, -0.46), (0.13, 0.06, 0.22), "flat", (0.12, 0.1, 0.09))
    m.box((0, 0.9, 0.0), (0.42, 0.6, 0.24), *cloth)
    for x in (-0.27, 0.27):
        m.box((x, 0.96, 0), (0.11, 0.42, 0.11), *cloth)
        m.box((x, 0.72, -0.16), (0.1, 0.1, 0.36), *cloth)
        m.box((x, 0.72, -0.37), (0.09, 0.09, 0.1), SKIN, WHITE)
    m.box((0, 1.24, 0), (0.1, 0.1, 0.1), SKIN, WHITE)
    m.sphere((0, 1.38, 0), 0.13, 5, 8, SKIN, WHITE)
    m.sphere((0, 1.42, 0.01), 0.135, 4, 8, "flat", (0.25, 0.17, 0.1), squash=0.55)
    return single("patron", m, {"collision": "box"})


reg("patron_seated", patron_seated)


def barkeep(rng):
    g = GLB("barkeep")
    m = MeshBuilder()
    shirt = ("flat", (0.55, 0.5, 0.42))
    neck = _biped(m, 1.8, top=shirt, legs=("flat", (0.22, 0.2, 0.18)), sleeves=True)
    m.box((0, 0.98, -0.14), (0.38, 0.34, 0.08), *shirt)
    m.box((0, 0.86, -0.21), (0.34, 0.92, 0.04), "flat", (0.94, 0.92, 0.86))
    m.box((0.2, 1.47, 0.0), (0.12, 0.05, 0.3), "flat", (0.94, 0.92, 0.86))
    g.add("Body", m, extras={"collision": "cylinder"})
    _head_node(g, neck)
    return g


reg("barkeep", barkeep)


def bard(rng):
    g = GLB("bard")
    m = MeshBuilder()
    tunic = ("flat", (0.36, 0.24, 0.5))
    neck = _biped(m, 1.75, top=tunic, legs=("flat", (0.42, 0.34, 0.22)), arms=False)
    s = 1.75 / 1.8
    sh = 1.42 * s
    # arms reaching forward to the lute
    _limb(m, (-0.27, sh, 0), (-0.33, 1.05, -0.18), 0.06, 0.05, *tunic)
    _limb(m, (-0.33, 1.05, -0.18), (-0.02, 0.92, -0.33), 0.05, 0.045, *tunic)
    m.box((0.0, 0.92, -0.34), (0.09, 0.09, 0.09), SKIN, WHITE)
    _limb(m, (0.27, sh, 0), (0.33, 1.08, -0.14), 0.06, 0.05, *tunic)
    _limb(m, (0.33, 1.08, -0.14), (0.44, 1.28, -0.26), 0.05, 0.045, *tunic)
    m.box((0.45, 1.29, -0.27), (0.09, 0.09, 0.09), SKIN, WHITE)
    m.push(compose(mat_translate(-0.2, 0.72, -0.24), mat_rot_z(-0.9)))
    _lute(m, 0.9)
    m.pop()
    g.add("Body", m, extras={"collision": "cylinder"})

    def hat(hm):
        hm.lathe([(0.2, 0.24), (0.2, 0.27), (0.13, 0.28), (0.11, 0.42), (0.0, 0.44)], 8, "flat", (0.22, 0.42, 0.24), smooth=False)
        _bar(hm, (0.1, 0.4, 0.05), (0.28, 0.72, 0.28), 0.035, "flat", (0.85, 0.22, 0.2))
    _head_node(g, neck, extra=hat)
    return g


reg("bard", bard)


def hermit(rng):
    m = MeshBuilder()
    robe = "tex:fabric/coat"
    tint = (0.8, 0.68, 0.54)
    m.lathe([(0.38, 0.04), (0.33, 0.7), (0.27, 1.15), (0.3, 1.3), (0.18, 1.36), (0.0, 1.36)], 8, robe, tint, smooth=True, uv_scale=(2.0, 1.0))
    # hood: a closed cone leaning forward, with a dark trapezoid on its front facet
    R, H = 0.3, 0.55
    m.push(compose(mat_translate(0, 1.27, -0.07), mat_rot_x(-0.32)))
    m.push(mat_rot_y(-PI / 8))
    m.lathe([(R, 0.0), (0.0, H)], 8, robe, tint, smooth=False, cap_bottom=True, cap_top=False)
    m.pop()
    c = math.cos(PI / 8)
    n = np.array([0.0, R * c, -H])
    n /= np.linalg.norm(n)

    def fp(t, x):
        p = np.array([x, t * H, -R * c * (1 - t)]) + n * 0.012
        return tuple(p)
    _quadn(m, [fp(0.05, -0.1), fp(0.05, 0.1), fp(0.55, 0.035), fp(0.55, -0.035)], tuple(n), DARK, WHITE)
    m.pop()
    # staff and the hand that holds it
    m.push(mat_translate(0.4, 0, -0.16))
    m.lathe([(0.03, 0), (0.025, 1.6), (0.05, 1.75), (0.0, 1.86)], 5, "flat", (0.32, 0.24, 0.16), smooth=True)
    m.pop()
    _limb(m, (0.24, 1.2, -0.06), (0.4, 1.02, -0.16), 0.07, 0.055, robe, tint)
    m.box((0.4, 1.0, -0.16), (0.09, 0.11, 0.09), SKIN, WHITE)
    return single("hermit", m, {"collision": "cylinder"})


reg("hermit", hermit)


def king_sleeping(rng):
    m = MeshBuilder()
    velvet = "tex:fabric/velvet"
    gold = "tex:metal/brass"
    # pillow, then the robe: a squashed tube lying along X (shoulders at -X, hem at +X)
    m.box((-0.75, 0.06, 0.05), (0.5, 0.12, 0.42), "flat", (0.9, 0.88, 0.8))
    m.push(compose(mat_translate(0.1, 0.25, 0), mat_scale(1.0, 0.72, 1.0), mat_rot_z(PI / 2)))
    m.lathe([(0.3, -0.7), (0.34, -0.2), (0.3, 0.4), (0.26, 0.7)], 8, velvet, WHITE, smooth=True, uv_scale=(2.0, 1.0))
    m.lathe([(0.32, -0.72), (0.32, -0.62)], 8, gold, WHITE, smooth=False, cap_top=False, cap_bottom=False)
    m.pop()
    for z, y in ((-0.1, 0.1), (0.06, 0.18)):
        m.box((0.92, y, z), (0.24, 0.1, 0.12), "flat", (0.15, 0.1, 0.08))
    # sleeve and hand in front
    _limb(m, (-0.5, 0.36, -0.18), (-0.05, 0.28, -0.36), 0.09, 0.08, velvet, WHITE)
    _limb(m, (-0.05, 0.28, -0.36), (0.3, 0.17, -0.32), 0.08, 0.07, velvet, WHITE)
    m.box((0.36, 0.14, -0.32), (0.12, 0.07, 0.12), SKIN, WHITE)
    # head, face card, crown
    m.push(compose(mat_translate(-0.62, 0.24, -0.02), mat_rot_z(PI / 2)))
    m.lathe([(0.08, 0.0), (0.08, 0.12)], 6, SKIN, WHITE, smooth=False)
    m.pop()
    m.sphere((-0.8, 0.22, -0.02), 0.16, 5, 8, SKIN, WHITE)
    m.card((-0.8, 0.23, -0.19), (0.3, 0.32), "tex:faces/king", WHITE, yaw=PI)
    m.push(compose(mat_translate(-0.9, 0.24, -0.02), mat_rot_z(PI / 2)))
    m.lathe([(0.115, 0.0), (0.13, 0.13)], 6, gold, WHITE, smooth=False, cap_top=False, cap_bottom=False)
    for i in range(6):
        m.push(mat_rot_y(i / 6 * TAU))
        m.box((0.13, 0.17, 0), (0.03, 0.08, 0.04), gold, WHITE)
        m.pop()
    m.pop()
    return single("king", m, {"collision": "box"})


reg("king_sleeping", king_sleeping)


def figure_shadow(rng):
    g = GLB("figure_shadow")
    m = MeshBuilder()
    d = (DARK, WHITE)
    neck = _biped(m, 1.9, top=d, legs=d, skin=d, width=0.82, feet=False)
    g.add("Body", m, extras={"collision": "cylinder"})
    _head_node(g, neck, r=0.115, mat=DARK)
    return g


reg("figure_shadow", figure_shadow)


def giant_chained(rng):
    g = GLB("giant")
    flesh = "tex:organic/flesh"
    fc = (0.95, 0.9, 0.88)
    m = MeshBuilder()
    for x in (-0.95, 0.95):
        m.box((x, 0.6, 0.6), (1.25, 1.2, 3.8), flesh, fc, uv_scale=0.5)
        m.box((x, 0.5, 2.9), (1.1, 0.9, 1.2), flesh, (0.9, 0.85, 0.85), uv_scale=0.5)
        m.box((x, 2.4, -1.35), (1.3, 2.8, 1.5), flesh, fc, uv_scale=0.5)
    m.push(compose(mat_translate(0, 3.4, -0.3), mat_rot_x(-0.08), mat_scale(1.2, 1.0, 0.85)))
    m.lathe([(1.5, 0.0), (1.75, 1.3), (1.8, 3.2), (1.5, 4.2), (0.9, 4.5), (0.0, 4.55)], 8, flesh, fc, smooth=True, uv_scale=(3.0, 0.5))
    m.pop()
    chain = (0.85, 0.85, 0.9)
    _band(m, (0, 5.9, -0.45), 1.95, 0.5, 10, "tex:metal/chain", chain, reps=10, roll=0.55, scale=(1.2, 1, 0.85))
    _band(m, (0, 5.9, -0.45), 1.95, 0.5, 10, "tex:metal/chain", chain, reps=10, roll=-0.55, scale=(1.2, 1, 0.85))
    _band(m, (0, 4.4, -0.35), 1.85, 0.45, 10, "tex:metal/chain", chain, reps=10, scale=(1.2, 1, 0.85))
    # shoulders and arms
    for x in (-2.0, 2.0):
        m.sphere((x, 7.0, -0.55), 0.62, 4, 8, flesh, fc)
    _limb(m, (2.1, 7.0, -0.6), (2.6, 4.9, -2.4), 0.55, 0.45, flesh, fc, segs=7)
    _limb(m, (2.6, 4.9, -2.4), (1.85, 2.45, -3.55), 0.45, 0.38, flesh, fc, segs=7)
    _limb(m, (-2.1, 7.0, -0.6), (-2.7, 4.6, -0.3), 0.55, 0.45, flesh, fc, segs=7)
    _limb(m, (-2.7, 4.6, -0.3), (-1.35, 3.9, -1.5), 0.45, 0.38, flesh, fc, segs=7)
    m.box((-1.2, 3.95, -1.65), (0.9, 0.3, 1.0), flesh, fc)
    g.add("Body", m, extras={"collision": "box"})
    h = MeshBuilder()
    h.sphere((0, 1.05, 0), 1.05, 5, 8, flesh, fc)
    for x in (-0.38, 0.38):
        h.box((x, 1.2, -0.99), (0.4, 0.07, 0.1), "flat", (0.5, 0.36, 0.36))
    h.box((0, 0.72, -1.02), (0.45, 0.06, 0.1), "flat", (0.5, 0.36, 0.36))
    g.add("Head", h, translation=(0, 7.85, -0.55))
    hand = MeshBuilder()
    hand.box((0, -0.15, 0), (1.0, 0.3, 1.0), flesh, fc)
    for i, x in enumerate((-0.36, -0.12, 0.12, 0.36)):
        _bar(hand, (x, -0.1, -0.5), (x - 0.06, 0.08 + 0.02 * i, -1.1), 0.2, flesh, fc)
    _bar(hand, (0.5, -0.12, -0.1), (0.9, 0.05, -0.45), 0.2, flesh, fc)
    g.add("Hand", hand, translation=(1.75, 2.5, -4.1))
    return g


reg("giant_chained", giant_chained)


def face_card(rng, tex, size=6.0, backing=True, back_col=(0.93, 0.78, 0.86)):
    m = MeshBuilder()
    m.card((0, size / 2, 0), (size, size), "tex:faces/" + tex, WHITE, yaw=PI)
    if backing:
        s = size * 0.86
        m.box((0, size / 2, 0.08), (s, s, 0.06), "flat", back_col)
    return single("face", m, {"collision": "none"})


reg("face_sea_sleep", lambda r: face_card(r, "sea_sleep", back_col=(0.85, 0.78, 0.95)))
reg("face_sea_awake", lambda r: face_card(r, "sea_awake", back_col=(0.95, 0.78, 0.86)))
reg("face_sea_sad", lambda r: face_card(r, "sea_sad", back_col=(0.8, 0.83, 0.95)))
reg("moon_face", lambda r: face_card(r, "moon", 4.0, backing=False))


def moth_giant(rng):
    g = GLB("moth")
    m = MeshBuilder()
    fuzz = [(0.5, 0.45, 0.4), (0.64, 0.6, 0.54), (0.44, 0.4, 0.36), (0.58, 0.52, 0.46), (0.48, 0.43, 0.4), (0.62, 0.58, 0.52), (0.4, 0.36, 0.34)]
    m.push(compose(mat_translate(0, 0.3, 0.1), mat_rot_x(-PI / 2)))
    m.lathe([(0.06, -0.9), (0.2, -0.5), (0.27, 0.0), (0.24, 0.35), (0.16, 0.5), (0.21, 0.62), (0.17, 0.76), (0.0, 0.82)], 7, "flat", WHITE, smooth=False, colors=fuzz)
    m.pop()
    for x in (-0.11, 0.11):
        m.box((x, 0.36, -0.68), (0.09, 0.09, 0.09), "flat", (0.1, 0.08, 0.1))
        _bar(m, (x, 0.42, -0.7), (x * 5.0, 0.75, -1.15), 0.04, "flat", (0.2, 0.17, 0.16))
    g.add("Body", m, extras={"collision": "none"})
    w = MeshBuilder()
    wing = "tex:nature/leaves_pale"
    for sgn in (-1, 1):
        fw = [(sgn * 0.2, 0.0, -0.45), (sgn * 1.55, 0.5, -0.85), (sgn * 1.5, 0.48, 0.1), (sgn * 0.2, 0.0, 0.0)]
        hw = [(sgn * 0.2, -0.02, -0.1), (sgn * 1.2, 0.35, 0.25), (sgn * 0.9, 0.28, 0.8), (sgn * 0.2, -0.02, 0.45)]
        _quadn(w, fw, (0, 1, 0), wing, (0.92, 0.86, 0.78), uvs=[(0, 1), (1, 1), (1, 0), (0, 0)], double=True)
        _quadn(w, hw, (0, 1, 0), wing, (0.8, 0.72, 0.68), uvs=[(0, 1), (1, 1), (1, 0), (0, 0)], double=True)
    g.add("Wings", w, translation=(0, 0.35, 0.05))
    return g


reg("moth_giant", moth_giant)


def cocoon(rng):
    m = MeshBuilder()
    m.card((0, -0.3, 0), (0.12, 0.6), "tex:metal/chain", (0.7, 0.7, 0.7))
    cols = [(0.86, 0.83, 0.76), (0.78, 0.76, 0.7), (0.9, 0.87, 0.8), (0.74, 0.72, 0.66), (0.84, 0.8, 0.74), (0.8, 0.78, 0.72)]
    m.lathe([(0.1, -0.6), (0.3, -0.9), (0.44, -1.4), (0.42, -1.9), (0.3, -2.4), (0.14, -2.7), (0.0, -2.8)], 8, "tex:fabric/sheet", WHITE, smooth=True, colors=cols, twist=0.12, uv_scale=(2.0, 1.0))
    return single("cocoon", m, {"collision": "none"})


reg("cocoon", cocoon)


# --------------------------------------------------------------------------
# keepsake items (small, on the ground at the origin; the game spins them)
# --------------------------------------------------------------------------

def item_lantern(rng):
    m = MeshBuilder()
    iron = ("flat", (0.2, 0.2, 0.22))
    brass = ("flat", (0.6, 0.45, 0.2))
    m.box((0, 0.02, 0), (0.22, 0.04, 0.22), *iron)
    m.box((0, 0.29, 0), (0.22, 0.03, 0.22), *iron)
    for x in (-0.095, 0.095):
        for z in (-0.095, 0.095):
            m.box((x, 0.165, z), (0.025, 0.25, 0.025), *iron)
    m.box((0, 0.165, 0), (0.16, 0.24, 0.16), "glow:#f2b134", WHITE)
    m.lathe([(0.15, 0.305), (0.04, 0.4), (0.04, 0.43), (0.0, 0.43)], 8, *brass, smooth=False)
    m.push(compose(mat_translate(0, 0.49, 0), mat_rot_x(PI / 2)))
    _torus(m, (0, 0, 0), 0.06, 0.012, 8, 4, *brass)
    m.pop()
    return single("item_lantern", m, {"collision": "none"})


reg("item_lantern", item_lantern)


def item_wings(rng):
    m = MeshBuilder()
    m.lathe([(0.0, 0.0), (0.03, 0.08), (0.035, 0.28), (0.02, 0.38), (0.0, 0.42)], 6, "flat", (0.35, 0.3, 0.3), smooth=True)
    for sgn in (-1, 1):
        m.push(mat_rot_y(-sgn * 0.55))
        m.card((sgn * 0.19, 0.25, 0), (0.34, 0.44), "tex:nature/leaves_pale", (0.92, 0.85, 1.0), yaw=PI)
        m.pop()
    return single("item_wings", m, {"collision": "none"})


reg("item_wings", item_wings)


def item_mouse(rng):
    m = MeshBuilder()
    tin = (0.72, 0.68, 0.6)
    m.push(compose(mat_translate(0, 0.1, 0.02), mat_rot_x(-PI / 2)))
    m.lathe([(0.0, -0.16), (0.09, -0.12), (0.1, -0.02), (0.08, 0.08), (0.04, 0.15), (0.0, 0.18)], 7, "flat", tin, smooth=True)
    m.pop()
    for x in (-0.06, 0.06):
        m.push(compose(mat_translate(x, 0.19, -0.06), mat_rot_x(-PI / 2)))
        m.cylinder((0, 0, 0), 0.04, 0.012, 6, "flat", (0.8, 0.7, 0.68))
        m.pop()
        m.box((x * 0.75, 0.14, -0.1), (0.025, 0.025, 0.02), "flat", (0.08, 0.07, 0.07))
    m.box((0, 0.1, -0.165), (0.03, 0.03, 0.02), "flat", (0.08, 0.07, 0.07))
    _bar(m, (0, 0.06, 0.18), (0.08, 0.16, 0.34), 0.018, "flat", (0.55, 0.5, 0.45))
    _bar(m, (0, 0.17, 0.02), (0, 0.27, 0.02), 0.015, "flat", (0.5, 0.48, 0.45))
    m.box((0, 0.275, 0.02), (0.09, 0.02, 0.015), "flat", (0.5, 0.48, 0.45))
    return single("item_mouse", m, {"collision": "none"})


reg("item_mouse", item_mouse)


def item_crown(rng):
    m = MeshBuilder()
    n, r = 8, 0.12
    greys = [(0.86, 0.85, 0.8), (0.7, 0.69, 0.66), (0.9, 0.89, 0.85), (0.6, 0.58, 0.56), (0.8, 0.79, 0.75)]
    for s in range(n):
        t0, t1 = s / n * TAU, (s + 1) / n * TAU
        p0 = (math.cos(t0) * r, 0.0, math.sin(t0) * r)
        p1 = (math.cos(t1) * r, 0.0, math.sin(t1) * r)
        q0, q1 = (p0[0], 0.1, p0[2]), (p1[0], 0.1, p1[2])
        mid = (t0 + t1) / 2
        want = (math.cos(mid), 0, math.sin(mid))
        col = greys[int(rng.random() * len(greys))]
        _quadn(m, [p0, p1, q1, q0], want, "flat", col, double=True)
        peak = (math.cos(mid) * r * 0.98, 0.22, math.sin(mid) * r * 0.98)
        _trin(m, q0, q1, peak, want, "flat", greys[int(rng.random() * len(greys))], double=True)
    return single("item_crown", m, {"collision": "none"})


reg("item_crown", item_crown)


def item_bell(rng):
    m = MeshBuilder()
    m.lathe([(0.1, 0.0), (0.11, 0.015), (0.085, 0.07), (0.055, 0.17), (0.035, 0.21), (0.0, 0.21)], 8, "tex:metal/brass", WHITE, smooth=True, uv_scale=(2.0, 2.0))
    m.lathe([(0.018, 0.21), (0.022, 0.3), (0.028, 0.37), (0.0, 0.37)], 6, "flat", (0.3, 0.2, 0.12), smooth=True)
    m.sphere((0, 0.035, 0), 0.025, 3, 6, "flat", (0.25, 0.22, 0.2))
    return single("item_bell", m, {"collision": "none"})


reg("item_bell", item_bell)


def item_knife(rng):
    m = MeshBuilder()
    m.prism([(-0.022, -0.17), (0.0, -0.24), (0.022, -0.18), (0.024, 0.03), (-0.024, 0.03)], 0.01, 0.022, "flat", (0.8, 0.82, 0.86), cap=True, floor=True)
    m.box((0, 0.028, 0.045), (0.05, 0.036, 0.03), "flat", (0.6, 0.6, 0.62))
    m.box((0, 0.028, 0.125), (0.045, 0.034, 0.14), "flat", (0.12, 0.1, 0.09))
    return single("item_knife", m, {"collision": "none"})


reg("item_knife", item_knife)


def item_umbrella(rng):
    m = MeshBuilder()
    s = 0.8
    m.lathe([(0.012, 0.0), (0.012, 0.06)], 5, "flat", (0.7, 0.7, 0.72), smooth=False)
    m.lathe([(0.015, 0.06), (0.06, 0.4), (0.05, 0.6), (0.018, 0.66)], 6, "flat", (0.08, 0.08, 0.1), smooth=False)
    m.lathe([(0.012, 0.66), (0.012, 0.8)], 5, "flat", (0.08, 0.08, 0.1), smooth=False)
    wood = (0.42, 0.28, 0.15)
    m.box((0.0, 0.84, 0), (0.028, 0.08, 0.028), "flat", wood)
    m.box((0.04, 0.88, 0), (0.1, 0.028, 0.028), "flat", wood)
    m.box((0.078, 0.84, 0), (0.028, 0.08, 0.028), "flat", wood)
    for p in m.prims.values():
        p["pos"] = [np.asarray(v, dtype=float) * s for v in p["pos"]]
    return single("item_umbrella", m, {"collision": "none"})


reg("item_umbrella", item_umbrella)


def item_hourglass(rng):
    m = MeshBuilder()
    wood = ("flat", (0.4, 0.27, 0.14))
    m.lathe([(0.1, 0.0), (0.1, 0.025)], 8, *wood, smooth=False)
    m.lathe([(0.1, 0.335), (0.1, 0.36)], 8, *wood, smooth=False)
    for i in range(3):
        a = i / 3 * TAU + 0.5
        m.box((math.cos(a) * 0.085, 0.18, math.sin(a) * 0.085), (0.018, 0.31, 0.018), *wood)
    m.lathe([(0.07, 0.03), (0.02, 0.17), (0.012, 0.18)], 7, "glow:#f0e6c8", WHITE, smooth=True, cap_top=False)
    m.lathe([(0.012, 0.18), (0.02, 0.19), (0.07, 0.33)], 7, "flat", (0.78, 0.86, 0.9), smooth=True, cap_bottom=False)
    return single("item_hourglass", m, {"collision": "none"})


reg("item_hourglass", item_hourglass)


def item_shard(rng):
    m = MeshBuilder()
    pts = [(-0.13, 0.0), (0.07, 0.0), (0.15, 0.14), (0.08, 0.42), (-0.06, 0.36), (-0.15, 0.2)]
    m.push(compose(mat_translate(0, 0.0, 0), mat_rot_x(0.2)))
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)

    def uv(p):
        return ((p[0] - x0) / (x1 - x0), 1 - (p[1] - y0) / (y1 - y0))
    for i in range(1, len(pts) - 1):
        a, b, c = pts[0], pts[i], pts[i + 1]
        _trin(m, (a[0], a[1], 0), (b[0], b[1], 0), (c[0], c[1], 0), (0, 0, -1), "tex:props/mirror", WHITE, uvs=[uv(a), uv(b), uv(c)], double=True)
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        _bar(m, (a[0], a[1], 0), (b[0], b[1], 0), 0.018, "glow:#a7f3f0", WHITE)
    m.pop()
    return single("item_shard", m, {"collision": "none"})


reg("item_shard", item_shard)


def item_tape(rng):
    m = MeshBuilder()
    yellow = (0.95, 0.75, 0.1)
    oct_ = [(math.cos(a) * 0.085, math.sin(a) * 0.085) for a in [i / 8 * TAU + PI / 8 for i in range(8)]]
    m.push(compose(mat_translate(0, 0.085, 0.0), mat_rot_x(PI / 2)))
    m.prism(oct_, -0.04, 0.04, "flat", yellow, cap=True, floor=True)
    m.pop()
    m.box((0, 0.11, -0.045), (0.05, 0.05, 0.02), "flat", (0.1, 0.1, 0.1))
    m.box((0, 0.03, -0.11), (0.03, 0.012, 0.06), "flat", (0.95, 0.9, 0.6))
    m.box((0, 0.035, -0.15), (0.04, 0.025, 0.018), "flat", (0.6, 0.6, 0.62))
    return single("item_tape", m, {"collision": "none"})


reg("item_tape", item_tape)


def item_coin(rng):
    m = MeshBuilder()
    m.push(compose(mat_translate(0, 0.14, 0), mat_rot_x(PI / 2)))
    m.lathe([(0.14, -0.015), (0.14, 0.015)], 10, "flat", (0.85, 0.7, 0.3), smooth=False, cap_top=False, cap_bottom=False)
    m.lathe([(0.0, -0.016), (0.135, -0.016)], 10, "glow:#9fd3c7", WHITE, smooth=False, cap_top=False, cap_bottom=False)
    m.lathe([(0.135, 0.016), (0.0, 0.016)], 10, "glow:#9fd3c7", WHITE, smooth=False, cap_top=False, cap_bottom=False)
    m.pop()
    return single("item_coin", m, {"collision": "none"})


reg("item_coin", item_coin)


def item_key(rng):
    m = MeshBuilder()
    iron = ("tex:metal/iron", (0.9, 0.9, 0.95))
    m.box((0, 0.17, 0), (0.03, 0.3, 0.03), *iron)
    m.push(compose(mat_translate(0, 0.33, 0), mat_rot_x(PI / 2)))
    m.lathe([(0.04, 0.02), (0.075, 0.02), (0.075, -0.02), (0.04, -0.02), (0.04, 0.02)], 8, *iron, smooth=False, cap_top=False, cap_bottom=False)
    m.pop()
    m.box((0.05, 0.045, 0), (0.07, 0.03, 0.03), *iron)
    m.box((0.05, 0.1, 0), (0.06, 0.03, 0.03), *iron)
    m.box((0, 0.015, 0), (0.03, 0.03, 0.03), *iron)
    return single("item_key", m, {"collision": "none"})


reg("item_key", item_key)


def item_photo(rng, tex="props/photo_1"):
    m = MeshBuilder()
    m.push(mat_rot_x(0.25))
    m.box((0, 0.17, 0.015), (0.32, 0.34, 0.01), "flat", (0.93, 0.9, 0.84))
    m.card((0, 0.175, 0.0), (0.27, 0.27), "tex:" + tex, WHITE, yaw=PI, double=False)
    m.pop()
    return single("item_photo", m, {"collision": "none"})


reg("item_photo", item_photo)


def item_biscuit(rng):
    m = MeshBuilder()
    tan = (0.8, 0.62, 0.38)
    m.box((0, 0.045, 0), (0.07, 0.06, 0.22), "flat", tan)
    for x in (-0.045, 0.045):
        for z in (-0.12, 0.12):
            m.sphere((x, 0.05, z), 0.048, 3, 6, "flat", tan)
    return single("item_biscuit", m, {"collision": "none"})


reg("item_biscuit", item_biscuit)


def item_page(rng):
    m = MeshBuilder()
    paper = "tex:wall/paper"
    a = [(-0.14, 0.01, 0.17), (0.0, 0.07, 0.16), (0.0, 0.07, -0.16), (-0.14, 0.01, -0.17)]
    b = [(0.0, 0.07, 0.16), (0.14, 0.025, 0.18), (0.14, 0.025, -0.15), (0.0, 0.07, -0.16)]
    _quadn(m, a, (0, 1, 0), paper, WHITE, uvs=[(0, 1), (0.5, 1), (0.5, 0), (0, 0)], double=True)
    _quadn(m, b, (0, 1, 0), paper, (0.92, 0.92, 0.9), uvs=[(0.5, 1), (1, 1), (1, 0), (0.5, 0)], double=True)
    return single("item_page", m, {"collision": "none"})


reg("item_page", item_page)


def item_candle(rng):
    m = MeshBuilder()
    m.lathe([(0.1, 0.0), (0.1, 0.015), (0.06, 0.025)], 8, "tex:metal/brass", WHITE, smooth=False)
    m.lathe([(0.055, 0.02), (0.06, 0.05), (0.05, 0.14), (0.055, 0.16), (0.0, 0.16)], 7, "flat", (0.1, 0.1, 0.12), smooth=True)
    m.box((0, 0.17, 0), (0.012, 0.03, 0.012), "flat", (0.1, 0.1, 0.1))
    _flame(m, (0, 0.17, 0), 0.03, 0.1, segs=4)
    return single("item_candle", m, {"collision": "none"})


reg("item_candle", item_candle)


def item_rose(rng):
    m = MeshBuilder()
    m.lathe([(0.012, 0.0), (0.01, 0.3)], 5, "flat", (0.3, 0.5, 0.25), smooth=False)
    for sgn in (-1, 1):
        m.push(compose(mat_translate(0, 0.12 + 0.03 * sgn, 0), mat_rot_y(sgn * 0.7), mat_rot_z(sgn * 0.6)))
        m.box((sgn * 0.05, 0, 0), (0.1, 0.01, 0.045), "flat", (0.32, 0.55, 0.28))
        m.pop()
    m.lathe([(0.02, 0.28), (0.07, 0.31), (0.0, 0.31)], 6, "flat", (0.35, 0.55, 0.3), smooth=False, cap_bottom=False)
    for r, y0, y1, col in ((0.1, 0.3, 0.41, (0.96, 0.84, 0.84)), (0.075, 0.32, 0.42, (0.98, 0.9, 0.9)), (0.05, 0.34, 0.43, (0.95, 0.8, 0.82))):
        m.lathe([(0.02, y0), (r, y1), (r * 0.9, y1), (0.02, y0 + 0.01)], 7, "flat", col, smooth=False, cap_top=False, cap_bottom=False)
    m.sphere((0, 0.41, 0), 0.035, 3, 6, "flat", (0.92, 0.72, 0.75))
    return single("item_rose", m, {"collision": "none"})


reg("item_rose", item_rose)
