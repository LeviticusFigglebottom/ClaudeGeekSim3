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
    chain = (1.0, 1.0, 1.0)
    _band(m, (0, 5.9, -0.45), 1.98, 0.95, 10, "tex:metal/chain", chain, reps=8, roll=0.55, scale=(1.2, 1, 0.85))
    _band(m, (0, 5.9, -0.45), 1.98, 0.95, 10, "tex:metal/chain", chain, reps=8, roll=-0.55, scale=(1.2, 1, 0.85))
    _band(m, (0, 4.3, -0.35), 1.9, 0.8, 10, "tex:metal/chain", chain, reps=8, scale=(1.2, 1, 0.85))
    # shoulders and arms
    for x in (-2.0, 2.0):
        m.sphere((x, 7.0, -0.55), 0.62, 3, 7, flesh, fc)
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
        for quad, under in ((fw, (0.6, 0.54, 0.48)), (hw, (0.52, 0.46, 0.42))):
            solid = [(p[0] * 0.93, p[1] * 0.93 - 0.015, p[2] * 0.93) for p in quad]
            _quadn(w, solid, (0, 1, 0), "flat", under, double=True)
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
        base = (sgn * 0.03, 0.24, 0.0)
        pts = [(sgn * (0.03 + 0.3 * math.cos(-PI / 2 + k / 6 * PI)), 0.24 + 0.22 * math.sin(-PI / 2 + k / 6 * PI), 0.0) for k in range(7)]
        for k in range(6):
            _trin(m, base, pts[k], pts[k + 1], (0, 0, -1), "flat", (0.84, 0.78, 0.94), double=True)
        m.card((sgn * 0.19, 0.25, -0.006), (0.34, 0.44), "tex:nature/leaves_pale", (0.92, 0.85, 1.0), yaw=PI)
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


# --------------------------------------------------------------------------
# offices (liminal office / waiting room; yellow-beige palette)
# --------------------------------------------------------------------------

BEIGE = (0.8, 0.72, 0.55)
OFFICE_GREY = (0.55, 0.55, 0.56)
METAL_DARK = (0.22, 0.22, 0.24)


def desk_office(rng):
    g = GLB("desk_office")
    m = MeshBuilder()
    m.box((0, 0.72, 0), (1.4, 0.05, 0.7), "flat", OFFICE_GREY)
    for x in (-0.65, 0.65):
        m.box((x, 0.35, 0), (0.05, 0.7, 0.65), "flat", BEIGE)
    m.box((0, 0.45, 0.3), (1.3, 0.5, 0.04), "flat", vary(rng, BEIGE, 0.03))
    mon = (0.82, 0.78, 0.68)
    m.box((0.3, 0.93, 0.12), (0.42, 0.38, 0.4), "flat", mon)
    m.box((0.3, 0.93, -0.085), (0.38, 0.34, 0.02), "flat", (0.25, 0.25, 0.25))
    m.box((-0.25, 0.755, -0.12), (0.45, 0.02, 0.16), "flat", (0.75, 0.72, 0.65))
    m.box((0.62, 0.75, -0.1), (0.06, 0.02, 0.1), "flat", (0.75, 0.72, 0.65))
    g.add("Desk", m, extras={"collision": "box"})
    s = MeshBuilder()
    s.card((0.3, 0.94, -0.105), (0.3, 0.24), "glow:#1a3a2a", WHITE, yaw=PI, double=False)
    g.add("Screen", s)
    return g


reg("desk_office", desk_office)


def chair_office(rng):
    m = MeshBuilder()
    pad = "tex:wall/carpet_office"
    m.box((0, 0.5, 0), (0.5, 0.09, 0.5), pad, (0.7, 0.7, 0.72))
    m.push(compose(mat_translate(0, 0.545, 0.22), mat_rot_x(0.12)))
    m.box((0, 0.27, 0), (0.46, 0.5, 0.07), pad, (0.75, 0.75, 0.78))
    m.pop()
    m.lathe([(0.035, 0.08), (0.03, 0.46)], 6, "flat", METAL_DARK, smooth=True)
    for i in range(5):
        m.push(mat_rot_y(i / 5 * TAU + PI / 2))
        m.box((0.15, 0.06, 0), (0.3, 0.04, 0.05), "flat", METAL_DARK)
        m.box((0.28, 0.035, 0), (0.05, 0.07, 0.06), "flat", (0.08, 0.08, 0.09))
        m.pop()
    for x in (-0.28, 0.28):
        m.box((x, 0.7, 0.02), (0.05, 0.03, 0.3), "flat", METAL_DARK)
        m.box((x, 0.6, 0.1), (0.04, 0.2, 0.04), "flat", METAL_DARK)
    return single("chair_office", m, {"collision": "box"})


reg("chair_office", chair_office)


def water_cooler(rng):
    m = MeshBuilder()
    white = (0.92, 0.92, 0.9)
    m.box((0, 0.5, 0), (0.36, 1.0, 0.36), "flat", white)
    m.box((0, 1.02, 0), (0.3, 0.04, 0.3), "flat", (0.8, 0.8, 0.8))
    m.box((-0.06, 0.72, -0.19), (0.05, 0.06, 0.03), "flat", (0.3, 0.45, 0.85))
    m.box((0.06, 0.72, -0.19), (0.05, 0.06, 0.03), "flat", (0.85, 0.3, 0.3))
    m.box((0, 0.82, -0.185), (0.2, 0.05, 0.02), "flat", (0.7, 0.7, 0.7))
    m.lathe([(0.06, 1.0), (0.17, 1.06), (0.17, 1.4), (0.13, 1.5), (0.07, 1.56), (0.0, 1.56)], 8, "glow:#6c8cd5", WHITE, smooth=True)
    return single("water_cooler", m, {"collision": "box"})


reg("water_cooler", water_cooler)


def filing_cabinet(rng):
    m = MeshBuilder()
    m.box((0, 0.65, 0), (0.45, 1.3, 0.6), "flat", (0.5, 0.52, 0.53))
    for i in range(4):
        y = 0.17 + i * 0.31
        m.box((0, y, -0.305), (0.41, 0.27, 0.03), "flat", vary(rng, (0.58, 0.6, 0.61), 0.02))
        m.box((0, y + 0.02, -0.33), (0.14, 0.03, 0.03), "flat", (0.8, 0.8, 0.82))
        m.box((0, y + 0.09, -0.328), (0.08, 0.04, 0.01), "flat", (0.95, 0.95, 0.9))
    return single("filing_cabinet", m, {"collision": "box"})


reg("filing_cabinet", filing_cabinet)


def fluorescent_light(rng):
    m = MeshBuilder()
    m.box((0, -0.04, 0), (1.2, 0.08, 0.3), "flat", (0.35, 0.35, 0.37))
    m.box((0, -0.08, 0), (1.1, 0.02, 0.22), "glow:#fff8dc", WHITE)
    return single("fluorescent_light", m, {"collision": "none"})


reg("fluorescent_light", fluorescent_light)


def vending_machine(rng):
    m = MeshBuilder()
    m.box((0, 0.95, 0), (0.9, 1.9, 0.8), "flat", (0.55, 0.12, 0.12))
    m.box((-0.12, 1.15, -0.405), (0.56, 1.2, 0.02), "glow:#c8ffc8", WHITE)
    cols = [(0.9, 0.3, 0.2), (0.2, 0.4, 0.8), (0.9, 0.8, 0.2), (0.3, 0.7, 0.3), (0.8, 0.5, 0.7)]
    for r in range(4):
        for c in range(4):
            m.box((-0.32 + c * 0.13, 0.68 + r * 0.28, -0.43), (0.1, 0.16, 0.02), "flat", cols[(r * 3 + c) % len(cols)])
    m.box((0.3, 1.45, -0.415), (0.16, 0.5, 0.02), "flat", (0.15, 0.15, 0.15))
    m.box((0.3, 1.6, -0.44), (0.05, 0.1, 0.02), "flat", (0.05, 0.05, 0.05))
    m.box((0.3, 1.3, -0.432), (0.1, 0.14, 0.01), "flat", (0.7, 0.7, 0.72))
    m.box((0, 0.3, -0.415), (0.5, 0.22, 0.02), "flat", (0.12, 0.12, 0.12))
    return single("vending_machine", m, {"collision": "box"})


reg("vending_machine", vending_machine)


def ticket_dispenser(rng):
    m = MeshBuilder()
    chrome = (0.8, 0.82, 0.85)
    m.lathe([(0.18, 0), (0.18, 0.03), (0.03, 0.04), (0.03, 1.1)], 8, "flat", chrome, smooth=True)
    m.box((0, 1.24, 0), (0.3, 0.26, 0.26), "flat", (0.75, 0.12, 0.1))
    m.card((0, 1.27, -0.14), (0.26, 0.13), "tex:signs/take_a_number", WHITE, yaw=PI, double=False)
    m.box((0, 1.14, -0.15), (0.07, 0.015, 0.06), "flat", (0.95, 0.95, 0.9))
    return single("ticket_dispenser", m, {"collision": "cylinder"})


reg("ticket_dispenser", ticket_dispenser)


def waiting_chairs(rng):
    m = MeshBuilder()
    metal = (0.25, 0.25, 0.27)
    m.box((0, 0.39, 0.05), (1.65, 0.05, 0.06), "flat", metal)
    for x in (-0.75, 0.75):
        m.box((x, 0.2, 0.05), (0.05, 0.4, 0.05), "flat", metal)
        m.box((x, 0.02, 0.05), (0.05, 0.04, 0.5), "flat", metal)
    orange = (0.85, 0.55, 0.3)
    for i in range(3):
        x = (i - 1) * 0.54
        m.box((x, 0.45, 0), (0.46, 0.05, 0.46), "flat", vary(rng, orange, 0.03))
        m.push(compose(mat_translate(x, 0.47, 0.21), mat_rot_x(0.15)))
        m.box((0, 0.2, 0), (0.46, 0.4, 0.05), "flat", vary(rng, orange, 0.03))
        m.pop()
    return single("waiting_chairs", m, {"collision": "box"})


reg("waiting_chairs", waiting_chairs)


def cubicle_wall(rng):
    m = MeshBuilder()
    frame = (0.6, 0.6, 0.62)
    m.box((0, 0.82, 0), (1.48, 1.5, 0.05), "tex:wall/carpet_office", (0.95, 0.92, 0.85), uv_scale=1.0)
    m.box((0, 1.6, 0), (1.54, 0.05, 0.08), "flat", frame)
    for x in (-0.75, 0.75):
        m.box((x, 0.8, 0), (0.04, 1.6, 0.08), "flat", frame)
        m.box((x, 0.02, 0), (0.05, 0.04, 0.34), "flat", frame)
    m.box((0, 0.05, 0), (1.46, 0.06, 0.07), "flat", frame)
    return single("cubicle_wall", m, {"collision": "box"})


reg("cubicle_wall", cubicle_wall)


def exit_sign(rng, tex="signs/exit"):
    m = MeshBuilder()
    m.box((0, -0.08, 0), (0.04, 0.16, 0.04), "flat", (0.2, 0.2, 0.22))
    m.box((0, -0.27, 0), (0.5, 0.22, 0.08), "glow:#2f8f4f", WHITE)
    m.card((0, -0.27, -0.05), (0.46, 0.19), "tex:" + tex, WHITE, yaw=PI, double=False)
    m.card((0, -0.27, 0.05), (0.46, 0.19), "tex:" + tex, WHITE, yaw=0.0, double=False)
    return single("exit_sign", m, {"collision": "none"})


reg("exit_sign", lambda r: exit_sign(r))
reg("exit_sign_wrong", lambda r: exit_sign(r, "signs/exit_wrong"))


def number_display(rng):
    """Wall-mounted: origin is the centre of the back face (like the pictures)."""
    m = MeshBuilder()
    m.box((0, 0, -0.06), (0.72, 0.38, 0.12), "flat", (0.08, 0.08, 0.09))
    m.card((0, 0, -0.13), (0.66, 0.33), "tex:signs/now_serving", WHITE, yaw=PI, double=False)
    return single("number_display", m, {"collision": "none", "mount": "wall"})


reg("number_display", number_display)


def phone_office(rng):
    m = MeshBuilder()
    beige = (0.82, 0.78, 0.66)
    m.box((0, 0.04, 0), (0.24, 0.08, 0.2), "flat", beige)
    m.push(compose(mat_translate(0, 0.08, 0), mat_rot_x(-0.25)))
    m.box((0, 0.02, 0), (0.24, 0.04, 0.2), "flat", vary(rng, beige, 0.02))
    m.box((0.04, 0.045, -0.02), (0.1, 0.01, 0.1), "flat", (0.3, 0.3, 0.32))
    m.pop()
    m.box((-0.08, 0.13, 0.0), (0.05, 0.05, 0.22), "flat", (0.75, 0.7, 0.6))
    for z in (-0.1, 0.1):
        m.box((-0.08, 0.125, z), (0.06, 0.06, 0.05), "flat", (0.75, 0.7, 0.6))
    return single("phone_office", m, {"collision": "none"})


reg("phone_office", phone_office)


def photocopier(rng):
    g = GLB("photocopier")
    m = MeshBuilder()
    m.box((0, 0.45, 0), (1.0, 0.9, 0.7), "flat", (0.8, 0.8, 0.78))
    m.box((0.6, 0.55, 0), (0.3, 0.04, 0.45), "flat", (0.7, 0.7, 0.68))
    m.box((0, 0.2, -0.355), (0.8, 0.25, 0.02), "flat", (0.65, 0.65, 0.63))
    m.box((-0.2, 0.93, -0.25), (0.45, 0.06, 0.16), "flat", (0.3, 0.3, 0.32))
    m.box((-0.1, 0.965, -0.25), (0.08, 0.02, 0.06), "glow:#6cd56c", WHITE)
    g.add("Body", m, extras={"collision": "box"})
    lid = MeshBuilder()
    lid.box((0, 0.03, -0.27), (0.9, 0.06, 0.5), "flat", (0.72, 0.72, 0.7))
    lid.box((0, 0.065, -0.5), (0.3, 0.02, 0.06), "flat", (0.5, 0.5, 0.5))
    g.add("Lid", lid, translation=(0.05, 0.91, 0.33))
    return g


reg("photocopier", photocopier)


def potted_plant_fake(rng):
    m = MeshBuilder()
    m.lathe([(0.16, 0.0), (0.2, 0.32), (0.17, 0.32), (0.17, 0.27)], 7, "flat", (0.5, 0.3, 0.25), smooth=False, cap_top=False)
    m.lathe([(0.17, 0.27), (0.0, 0.27)], 7, "flat", (0.2, 0.15, 0.1), smooth=False, cap_top=False, cap_bottom=False)
    m.cross_cards((0, 0.72, 0), (0.95, 0.85), "tex:nature/fern", (0.55, 0.88, 0.75), n=3)
    return single("plant_fake", m, {"collision": "none"})


reg("potted_plant_fake", potted_plant_fake)


# --------------------------------------------------------------------------
# catacombs
# --------------------------------------------------------------------------

BONE = (0.87, 0.82, 0.68)


def _skull(m, center, r=0.11, yaw=0.0, col=(0.88, 0.84, 0.72)):
    cx, cy, cz = center
    m.push(compose(mat_translate(cx, cy, cz), mat_rot_y(yaw)))
    m.sphere((0, 0, 0), r, 4, 7, "flat", col, squash=0.92)
    m.box((0, -r * 0.75, -r * 0.15), (r * 1.4, r * 0.7, r * 1.3), "flat", col)
    for x in (-0.42, 0.42):
        m.box((x * r, r * 0.1, -r * 0.92), (r * 0.45, r * 0.42, r * 0.25), DARK, WHITE)
    m.box((0, -r * 0.35, -r * 0.95), (r * 0.2, r * 0.3, r * 0.2), DARK, WHITE)
    m.pop()


def coffin(rng):
    g = GLB("coffin")
    wood = "tex:wood/planks_dark"
    pts = [(-0.3, -0.95), (0.3, -0.95), (0.4, 0.25), (0.25, 0.95), (-0.25, 0.95), (-0.4, 0.25)]
    m = MeshBuilder()
    m.prism(pts, 0.0, 0.45, wood, WHITE, uv_scale=1.0, cap=True)
    for x in (-0.41, 0.41):
        m.box((x, 0.22, 0.1), (0.05, 0.04, 0.25), "flat", (0.15, 0.13, 0.12))
    g.add("Body", m, extras={"collision": "box"})
    lid = MeshBuilder()
    lp = [(x * 1.04 + 0.42, z * 1.04) for x, z in pts]
    lid.prism(lp, 0.0, 0.08, wood, (0.9, 0.9, 0.9), uv_scale=1.0, cap=True, floor=True)
    lid.box((0.42, 0.09, 0.0), (0.09, 0.02, 1.5), "flat", (0.15, 0.13, 0.12))
    lid.box((0.42, 0.09, 0.35), (0.5, 0.02, 0.09), "flat", (0.15, 0.13, 0.12))
    g.add("Lid", lid, translation=(-0.42, 0.46, 0))
    return g


reg("coffin", coffin)


def bone_pile(rng):
    m = MeshBuilder()
    m.push(mat_scale(1.0, 0.4, 0.9))
    m.blob((0, 0.55, 0), 0.6, rng, rings=4, segments=8, mat="tex:organic/bones", color=(0.95, 0.92, 0.85), jitter=0.4)
    m.pop()
    for i in range(7):
        a = rng.random() * TAU
        d = rng.random() * 0.45
        x, z = math.cos(a) * d, math.sin(a) * d
        L = 0.25 + rng.random() * 0.25
        y = 0.14 + rng.random() * 0.2
        yaw = rng.random() * TAU
        tilt = (rng.random() - 0.5) * 0.6
        dx, dz = math.cos(yaw) * L / 2, math.sin(yaw) * L / 2
        a_ = (x - dx, y - math.sin(tilt) * L / 2, z - dz)
        b_ = (x + dx, y + math.sin(tilt) * L / 2, z + dz)
        r = 0.025 + rng.random() * 0.015
        col = vary(rng, BONE, 0.05)
        _limb(m, a_, b_, r, r, "flat", col, segs=4)
        for p in (a_, b_):
            m.sphere(p, r * 1.7, 2, 4, "flat", col)
    for i in range(2):
        a = i * 2.6 + rng.random()
        _skull(m, (math.cos(a) * 0.3, 0.3, math.sin(a) * 0.3), 0.09, rng.random() * TAU)
    _settle(m)
    return single("bone_pile", m, {"collision": "none"})


reg("bone_pile", bone_pile)


def skull(rng):
    m = MeshBuilder()
    r = 0.124
    _skull(m, (0, r * 1.1, 0), r)
    return single("skull", m, {"collision": "none"})


reg("skull", skull)


def altar(rng):
    m = MeshBuilder()
    stone = "tex:stone/blocks_dark"
    m.box((0, 0.47, 0), (1.6, 0.94, 0.8), stone, WHITE, uv_scale=1.0)
    m.box((0, 0.99, 0), (1.72, 0.1, 0.92), stone, (0.85, 0.85, 0.85), uv_scale=1.0)
    m.box((0, 1.055, 0), (0.5, 0.02, 0.94), "tex:fabric/cloth_red", WHITE)
    for z in (-0.48, 0.48):
        m.box((0, 0.86, z), (0.5, 0.36, 0.02), "tex:fabric/cloth_red", WHITE)
    for x in (-0.55, 0.55):
        _candle(m, (x, 1.04, 0), 0.03, 0.25)
    return single("altar", m, {"collision": "box"})


reg("altar", altar)


def urn(rng):
    m = MeshBuilder()
    clay = (0.58, 0.44, 0.34)
    band = (0.4, 0.3, 0.24)
    cols = [clay, clay, band, clay, band, clay, clay, clay]
    m.lathe([(0.14, 0), (0.12, 0.04), (0.22, 0.3), (0.25, 0.45), (0.25, 0.52), (0.18, 0.72), (0.12, 0.8), (0.16, 0.86), (0.16, 0.9)], 8, "flat", clay, smooth=True, colors=cols, cap_top=False)
    m.lathe([(0.16, 0.9), (0.12, 0.9), (0.12, 0.84)], 8, "flat", (0.3, 0.22, 0.18), smooth=False, cap_top=False, cap_bottom=False)
    for x in (-1, 1):
        m.box((x * 0.27, 0.55, 0), (0.06, 0.16, 0.08), "flat", clay)
    return single("urn", m, {"collision": "cylinder"})


reg("urn", urn)


def sarcophagus(rng):
    m = MeshBuilder()
    stone = "tex:stone/smooth_grey"
    m.box((0, 0.4, 0), (2.2, 0.8, 0.9), stone, (0.85, 0.85, 0.85), uv_scale=0.5)
    m.box((0, 0.885, 0), (2.3, 0.16, 1.0), stone, (0.7, 0.7, 0.72), uv_scale=0.5)
    rel = (1.0, 0.98, 0.95)
    m.sphere((-0.8, 1.04, 0), 0.16, 4, 7, stone, rel, squash=0.7)
    m.box((-0.15, 1.02, 0), (1.05, 0.14, 0.46), stone, rel, uv_scale=0.5)
    m.box((0.68, 1.01, 0), (0.62, 0.12, 0.38), stone, rel, uv_scale=0.5)
    for x, a in ((-0.25, 0.5), (-0.05, -0.5)):
        m.push(compose(mat_translate(x, 1.085, 0), mat_rot_y(a)))
        m.box((0, 0, 0), (0.45, 0.06, 0.1), stone, rel)
        m.pop()
    m.box((1.0, 0.99, 0), (0.1, 0.08, 0.4), stone, rel)
    return single("sarcophagus", m, {"collision": "box"})


reg("sarcophagus", sarcophagus)


def ossuary_lamp(rng):
    m = MeshBuilder()
    prof = [(0.16, 0.0), (0.16, 0.03), (0.05, 0.05)]
    for i in range(6):
        y = 0.05 + i * 0.12
        prof += [(0.04, y + 0.03), (0.075, y + 0.07), (0.04, y + 0.11)]
    prof += [(0.04, 0.8), (0.09, 0.84)]
    m.lathe(prof, 6, "flat", BONE, smooth=False)
    m.lathe([(0.09, 0.84), (0.16, 0.9), (0.15, 0.94), (0.1, 0.94), (0.1, 0.88)], 8, "flat", (0.8, 0.74, 0.6), smooth=False, cap_top=False, cap_bottom=False)
    m.lathe([(0.1, 0.885), (0.0, 0.885)], 8, "flat", (0.15, 0.1, 0.06), smooth=False, cap_top=False, cap_bottom=False)
    _flame(m, (0, 0.89, 0), 0.06, 0.25, outer="glow:#ff9a3c", inner="glow:#ffe0a0")
    return single("ossuary_lamp", m, {"collision": "cylinder"})


reg("ossuary_lamp", ossuary_lamp)


# --------------------------------------------------------------------------
# furnace
# --------------------------------------------------------------------------

def anvil(rng):
    m = MeshBuilder()
    iron = (0.22, 0.22, 0.25)
    m.box((0, 0.11, 0), (0.5, 0.22, 0.32), "flat", (0.18, 0.18, 0.2))
    m.box((0, 0.3, 0), (0.34, 0.18, 0.22), "flat", iron)
    m.box((0, 0.5, 0), (0.7, 0.2, 0.3), "flat", iron, colors={"py": (0.5, 0.5, 0.55)})
    m.push(compose(mat_translate(-0.5, 0.52, 0), mat_rot_z(PI / 2)))
    m.lathe([(0.11, -0.15), (0.0, 0.18)], 6, "flat", iron, smooth=False, cap_bottom=True, cap_top=False)
    m.pop()
    return single("anvil", m, {"collision": "box"})


reg("anvil", anvil)


def furnace_mouth(rng):
    m = MeshBuilder()
    stone = "tex:stone/blocks_furnace"
    for x in (-1.25, 1.25):
        m.box((x, 1.15, 0), (0.7, 2.3, 1.0), stone, WHITE, uv_scale=1.0)
    _arch(m, (0, 2.29, 0), 0.9, 1.6, 1.0, 7, stone, WHITE, uv_scale=1.0)
    m.box((0, 3.95, 0), (3.4, 0.2, 1.1), stone, (0.8, 0.8, 0.8), uv_scale=1.0)
    m.card((0, 1.65, 0.3), (1.9, 3.2), "glow:#ff5a1f", WHITE, yaw=PI, double=False)
    m.card((0, 0.55, -0.2), (1.85, 1.1), "tex:metal/grate", (0.6, 0.6, 0.62), yaw=PI)
    m.box((0, 0.06, -0.3), (3.4, 0.12, 1.6), stone, (0.7, 0.7, 0.7), uv_scale=1.0)
    return single("furnace_mouth", m, {"collision": "none"})


reg("furnace_mouth", furnace_mouth)


def iron_maiden(rng):
    g = GLB("iron_maiden")
    iron = "tex:metal/iron"
    m = MeshBuilder()
    m.box((0, 0.1, 0), (0.95, 0.2, 0.75), iron, (0.7, 0.7, 0.72), uv_scale=1.0)
    m.box((0, 1.15, 0.05), (0.8, 2.1, 0.55), iron, (0.85, 0.85, 0.88), uv_scale=1.0)
    m.box((0, 2.3, 0.05), (0.6, 0.3, 0.45), iron, (0.85, 0.85, 0.88), uv_scale=1.0)
    m.sphere((0, 2.45, 0.05), 0.28, 4, 8, iron, (0.8, 0.8, 0.82), squash=0.8)
    g.add("Body", m, extras={"collision": "box"})
    d = MeshBuilder()
    d.box((0.38, 0.95, -0.05), (0.74, 1.9, 0.1), iron, WHITE, uv_scale=1.0)
    for i in range(3):
        for j in range(5):
            d.push(compose(mat_translate(0.12 + i * 0.26, 0.25 + j * 0.35, -0.1), mat_rot_x(-PI / 2)))
            d.lathe([(0.045, 0.0), (0.0, 0.16)], 4, "flat", (0.35, 0.35, 0.38), smooth=False)
            d.pop()
    d.box((0.05, 0.95, -0.115), (0.03, 0.2, 0.03), "flat", (0.3, 0.3, 0.33))
    g.add("Door", d, translation=(-0.38, 0.2, -0.22))
    return g


reg("iron_maiden", iron_maiden)


def eye_stalk(rng):
    g = GLB("eye_stalk")
    m = MeshBuilder()
    m.push(mat_rot_z(0.08))
    m.lathe([(0.5, 0.0), (0.32, 0.5), (0.22, 1.5), (0.18, 2.2), (0.3, 2.5), (0.34, 2.72), (0.22, 2.92), (0.0, 3.0)], 8, "tex:organic/flesh", (1.0, 0.95, 0.92), smooth=True, uv_scale=(2.0, 0.7))
    m.pop()
    g.add("Stalk", m, extras={"collision": "cylinder"})
    e = MeshBuilder()
    e.card((0, 0, -0.34), (0.66, 0.66), "tex:organic/eye", WHITE, yaw=PI)
    g.add("Eye", e, translation=(-0.2, 2.66, 0))
    return g


reg("eye_stalk", eye_stalk)


def spike_cluster(rng):
    m = MeshBuilder()
    for i in range(7):
        a = i / 7 * TAU + rng.random()
        d = 0.15 + rng.random() * 0.4 if i else 0.0
        h = 0.7 + rng.random() * 0.8
        r = 0.12 + rng.random() * 0.1
        m.push(compose(mat_translate(math.cos(a) * d, -0.06, math.sin(a) * d), mat_rot_y(rng.random() * TAU), mat_rot_x((rng.random() - 0.5) * 0.5)))
        m.lathe([(r, 0.0), (r * 0.5, h * 0.5), (0.0, h)], 5, "flat", vary(rng, (0.16, 0.14, 0.15), 0.03), smooth=False, cap_top=False)
        m.pop()
    return single("spike_cluster", m, {"collision": "cylinder"})


reg("spike_cluster", spike_cluster)


def gallows(rng):
    m = MeshBuilder()
    wood = "tex:wood/planks_grey"
    m.box((0, 0.2, 0), (2.2, 0.4, 1.8), wood, WHITE, uv_scale=1.0)
    m.box((-0.85, 2.1, 0), (0.22, 3.4, 0.22), wood, (0.9, 0.9, 0.9), uv_scale=1.0)
    m.box((0.02, 3.7, 0), (2.0, 0.2, 0.2), wood, (0.9, 0.9, 0.9), uv_scale=1.0)
    _bar(m, (-0.74, 2.9, 0), (-0.1, 3.6, 0), 0.12, wood, (0.85, 0.85, 0.85))
    rope = (0.85, 0.7, 0.45)
    m.card((0.7, 3.05, 0), (0.08, 1.1), "tex:metal/chain", rope)
    m.push(compose(mat_translate(0.7, 2.35, 0), mat_rot_x(PI / 2)))
    _torus(m, (0, 0, 0), 0.15, 0.025, 8, 4, "flat", rope)
    m.pop()
    m.box((1.35, 0.1, -0.5), (0.5, 0.2, 0.7), wood, (0.85, 0.85, 0.85), uv_scale=1.0)
    return single("gallows", m, {"collision": "box"})


reg("gallows", gallows)


def meat_hook(rng):
    m = MeshBuilder()
    m.card((0, -0.5, 0), (0.1, 1.0), "tex:metal/chain", (0.8, 0.8, 0.85))
    iron = (0.35, 0.35, 0.38)
    pts = [(0, -1.0, 0), (0, -1.35, 0), (0.06, -1.46, 0), (0.16, -1.48, 0), (0.25, -1.4, 0), (0.27, -1.28, 0)]
    for a, b in zip(pts, pts[1:]):
        _bar(m, a, b, 0.05, "flat", iron)
    for p in pts[1:-1]:
        m.sphere(p, 0.03, 2, 5, "flat", iron)
    m.push(mat_translate(0.27, -1.28, 0))
    m.lathe([(0.03, 0.0), (0.0, 0.18)], 5, "flat", (0.5, 0.5, 0.55), smooth=False)
    m.pop()
    m.sphere((0, -1.0, 0), 0.05, 3, 6, "flat", iron)
    return single("meat_hook", m, {"collision": "none"})


reg("meat_hook", meat_hook)


# --------------------------------------------------------------------------
# cistern (poolrooms / bathhouse)
# --------------------------------------------------------------------------

CHROME = (0.85, 0.87, 0.9)


def pool_ladder(rng):
    m = MeshBuilder()
    for x in (-0.25, 0.25):
        _bar(m, (x, 0.0, 0), (x, 1.25, 0), 0.05, "flat", CHROME)
        _bar(m, (x, 1.25, 0), (x, 1.48, 0.22), 0.05, "flat", CHROME)
        _bar(m, (x, 1.48, 0.22), (x, 1.25, 0.5), 0.05, "flat", CHROME)
        for p in ((x, 1.25, 0), (x, 1.48, 0.22)):
            m.sphere(p, 0.03, 2, 5, "flat", CHROME)
    for y in (0.25, 0.55, 0.85, 1.12):
        _bar(m, (-0.25, y, 0), (0.25, y, 0), 0.045, "flat", CHROME)
    return single("pool_ladder", m, {"collision": "none"})


reg("pool_ladder", pool_ladder)


def lifeguard_chair(rng):
    m = MeshBuilder()
    white = (0.92, 0.92, 0.9)
    H = 1.85
    for x in (-1, 1):
        for z in (-1, 1):
            _bar(m, (x * 0.55, 0, z * 0.45), (x * 0.36, H, z * 0.3), 0.07, "flat", white)

    def wd(y):
        return 0.55 - 0.19 * (y / H), 0.45 - 0.15 * (y / H)
    for y in (0.65, 1.3):
        w, d = wd(y)
        for z in (-1, 1):
            _bar(m, (-w, y, z * d), (w, y, z * d), 0.06, "flat", white)
        for x in (-1, 1):
            _bar(m, (x * w, y, -d), (x * w, y, d), 0.06, "flat", white)
    for y in (0.33, 0.98, 1.62):
        w, d = wd(y)
        _bar(m, (-w, y, -d), (w, y, -d), 0.06, "flat", white)
    m.box((0, H + 0.03, 0), (0.8, 0.07, 0.7), "flat", white)
    m.push(compose(mat_translate(0, H + 0.06, 0.33), mat_rot_x(0.15)))
    m.box((0, 0.3, 0), (0.8, 0.6, 0.07), "flat", white)
    m.pop()
    for x in (-0.38, 0.38):
        m.box((x, H + 0.25, 0.05), (0.06, 0.05, 0.55), "flat", white)
        m.box((x, H + 0.14, -0.15), (0.05, 0.2, 0.05), "flat", white)
    return single("lifeguard_chair", m, {"collision": "box"})


reg("lifeguard_chair", lifeguard_chair)


def drain_grate(rng):
    m = MeshBuilder()
    m.lathe([(0.42, 0.0), (0.42, 0.035), (0.36, 0.035)], 12, "flat", (0.3, 0.3, 0.32), smooth=False, cap_top=False, cap_bottom=False)
    _disc(m, (0, 0.012, 0), 0.37, 12, DARK, WHITE, up=True)
    _disc(m, (0, 0.025, 0), 0.37, 12, "tex:metal/grate", (0.6, 0.6, 0.62), up=True, uv_scale=2.5)
    return single("drain_grate", m, {"collision": "none"})


reg("drain_grate", drain_grate)


def pool_float(rng):
    m = MeshBuilder()
    _torus(m, (0, 0.14, 0), 0.42, 0.14, 12, 6, "flat", WHITE, col_fn=lambda i: (0.95, 0.95, 0.92) if (i // 3) % 2 == 0 else (0.85, 0.15, 0.15))
    return single("pool_float", m, {"collision": "none"})


reg("pool_float", pool_float)


def tiled_bench(rng):
    m = MeshBuilder()
    m.box((0, 0.07, 0), (2.0, 0.14, 0.5), "tex:wall/tile_black", (0.7, 0.7, 0.72), uv_scale=1.0)
    m.box((0, 0.31, 0), (2.02, 0.34, 0.52), "tex:wall/tile_white", WHITE, uv_scale=2.0)
    return single("tiled_bench", m, {"collision": "box"})


reg("tiled_bench", tiled_bench)


def fountain_head(rng):
    """Wall-mounted lion head: origin at the wall (back face centre), water falls below."""
    m = MeshBuilder()
    stone = "tex:stone/statue"
    m.box((0, 0, -0.1), (0.6, 0.6, 0.2), stone, WHITE)
    m.box((0, 0.02, -0.33), (0.4, 0.4, 0.28), stone, (0.95, 0.95, 0.95))
    m.box((0, -0.06, -0.54), (0.26, 0.2, 0.16), stone, (0.9, 0.9, 0.9))
    for x in (-0.16, 0.16):
        m.box((x, 0.2, -0.3), (0.1, 0.12, 0.1), stone, (0.9, 0.9, 0.9))
        m.box((x * 0.6, 0.1, -0.475), (0.07, 0.05, 0.02), DARK, WHITE)
    for i in range(8):
        m.push(compose(mat_translate(0, 0.02, -0.22), mat_rot_z(i / 8 * TAU)))
        m.box((0.3, 0, 0), (0.16, 0.14, 0.1), stone, (0.85, 0.85, 0.85))
        m.pop()
    m.box((0, -0.14, -0.6), (0.1, 0.06, 0.06), DARK, WHITE)
    m.card((0, -0.62, -0.62), (0.12, 0.9), "tex:nature/water_cistern", (0.8, 0.95, 1.0))
    return single("fountain_head", m, {"collision": "none", "mount": "wall"})


reg("fountain_head", fountain_head)


def shower_head(rng):
    """Wall-mounted: origin at the wall where the arm leaves it; the riser and tap hang below."""
    m = MeshBuilder()
    _bar(m, (0, -0.95, -0.03), (0, 0.0, -0.03), 0.04, "flat", CHROME)
    m.box((0, 0, -0.03), (0.12, 0.12, 0.05), "flat", CHROME)
    _limb(m, (0, 0.0, -0.05), (0, 0.06, -0.36), 0.022, 0.022, "flat", CHROME, segs=6)
    m.push(compose(mat_translate(0, 0.06, -0.36), mat_rot_x(0.5), mat_translate(0, -0.12, 0)))
    m.lathe([(0.1, 0.0), (0.1, 0.02), (0.05, 0.07), (0.02, 0.12)], 8, "flat", CHROME, smooth=False, cap_top=False)
    m.pop()
    m.push(compose(mat_translate(0, -0.95, -0.05), mat_rot_x(-PI / 2)))
    m.lathe([(0.03, 0), (0.03, 0.06), (0.06, 0.07), (0.06, 0.09), (0.0, 0.09)], 8, "flat", CHROME, smooth=False)
    m.pop()
    return single("shower_head", m, {"collision": "none", "mount": "wall"})


reg("shower_head", shower_head)


# --------------------------------------------------------------------------
# slow sea (pastel dream dimension)
# --------------------------------------------------------------------------

def platform_disc(rng, d=4.0, segs=12):
    m = MeshBuilder()
    R = d / 2
    pink = (0.96, 0.78, 0.86)
    lilac = (0.72, 0.62, 0.84)
    prof = [(0.0, 0.0), (R * 0.55, 0.03), (R * 0.9, 0.2), (R, 0.36), (R, 0.5)]
    m.lathe(prof, segs, "tex:stone/blocks_sea", WHITE, smooth=False, cap_top=False, cap_bottom=False, colors=[lilac, lilac, (0.85, 0.7, 0.85), pink], uv_scale=(PI * d / 2, 0.5))
    _disc(m, (0, 0.5, 0), R, segs, "tex:stone/blocks_sea", (1.0, 0.9, 0.95), up=True, uv_scale=0.5)
    return single("platform", m, {"collision": "cylinder"})


reg("platform_disc_small", lambda r: platform_disc(r, 2.0, 8))
reg("platform_disc_medium", lambda r: platform_disc(r, 4.0, 10))
reg("platform_disc_large", lambda r: platform_disc(r, 8.0, 12))


def arch_pastel(rng):
    m = MeshBuilder()
    lilac, mint = (0.8, 0.7, 0.95), (0.7, 0.95, 0.85)
    _arch(m, (0, 1.99, 0), 1.5, 2.0, 0.5, 7, "flat", WHITE, colors=[lilac, mint])
    for x in (-1.75, 1.75):
        m.box((x, 1.0, 0), (0.5, 2.0, 0.5), "flat", mint if x < 0 else lilac)
        m.box((x, 0.1, 0), (0.7, 0.2, 0.7), "flat", (0.95, 0.9, 0.98))
    return single("arch_pastel", m, {"collision": "none"})


reg("arch_pastel", arch_pastel)


def orb(rng):
    m = MeshBuilder()
    m.sphere((0, 0.4, 0), 0.4, 6, 10, "glow:#fff3dd", WHITE)
    return single("orb", m, {"collision": "none"})


reg("orb", orb)


def cloud(rng):
    m = MeshBuilder()
    for i in range(5):
        x = -1.1 + i * 0.55 + (rng.random() - 0.5) * 0.2
        r = 0.55 + rng.random() * 0.35
        z = (rng.random() - 0.5) * 0.6
        m.blob((x, r * 0.9, z), r, rng, rings=4, segments=8, mat="glow:#fff3dd", color=WHITE, jitter=0.25)
    _settle(m)
    return single("cloud", m, {"collision": "none"})


reg("cloud", cloud)


def pillar_pastel(rng):
    m = MeshBuilder()
    pink, cream = (0.95, 0.7, 0.8), (1.0, 0.95, 0.85)
    prof = [(0.6, 0.0), (0.6, 0.25), (0.42, 0.35)]
    cols = [cream, cream]
    for i in range(10):
        prof.append((0.42, 0.35 + (i + 1) * 0.43))
        cols.append(pink if i % 2 == 0 else cream)
    prof += [(0.55, 4.75), (0.6, 5.0)]
    cols += [cream, cream]
    m.lathe(prof, 8, "flat", WHITE, smooth=True, colors=cols)
    return single("pillar_pastel", m, {"collision": "cylinder"})


reg("pillar_pastel", pillar_pastel)


def stair_pastel(rng):
    m = MeshBuilder()
    mint = (0.75, 0.95, 0.85)
    for i in range(8):
        m.box((0, i * 0.25 + 0.13, -0.225 - i * 0.35), (1.6, 0.24, 0.46), "tex:stone/blocks_sea", vary(rng, mint, 0.03), uv_scale=0.5)
    return single("stair", m, {"collision": "box"})


reg("stair_pastel", stair_pastel)


def shell(rng):
    m = MeshBuilder()
    cream, pink = (0.96, 0.9, 0.82), (0.95, 0.76, 0.8)
    # a snail-shell spiral in the XY plane: shrinking spheres along a log spiral
    for i in range(8):
        t = i * 0.95
        rho = 0.26 * (0.78 ** i)
        r = 0.27 * (0.8 ** i)
        m.sphere((math.cos(t) * rho, 0.42 + math.sin(t) * rho, -0.02 * i), r, 4, 7, "flat", cream if i % 2 else pink)
    m.push(compose(mat_translate(0.42, 0.12, 0), mat_rot_z(-1.3)))
    m.lathe([(0.2, 0.0), (0.26, 0.15), (0.05, 0.35)], 7, "flat", cream, smooth=False)
    m.pop()
    _settle(m)
    return single("shell", m, {"collision": "box"})


reg("shell", shell)


# --------------------------------------------------------------------------
# city / castle extras
# --------------------------------------------------------------------------

def _wheel(m, r=0.45, w=0.08, spokes=4, col=WHITE):
    """A spoked cart wheel in the local XZ plane (axis = local Y), centred at the origin."""
    wood = "tex:wood/planks_dark"
    m.lathe([(r * 0.82, -w / 2), (r, -w / 2), (r, w / 2), (r * 0.82, w / 2), (r * 0.82, -w / 2)], 8, wood, col, smooth=False, cap_top=False, cap_bottom=False)
    m.lathe([(r * 1.03, -w / 4), (r * 1.03, w / 4)], 8, "tex:metal/iron", WHITE, smooth=False, cap_top=False, cap_bottom=False)
    for i in range(spokes):
        m.push(mat_rot_y(i / spokes * PI))
        m.box((0, 0, 0), (2 * r * 0.86, w * 0.5, 0.05), wood, col)
        m.pop()
    m.lathe([(0.1, -w * 0.8), (0.1, w * 0.8)], 6, wood, col, smooth=False)


def cart_broken(rng):
    m = MeshBuilder()
    wood = "tex:wood/planks_grey"
    dark = "tex:wood/planks_dark"
    m.push(compose(mat_translate(0.75, 0, 0), mat_rot_z(0.2), mat_translate(-0.75, 0, 0)))
    m.box((0, 0.55, 0), (1.2, 0.1, 2.0), wood, WHITE, uv_scale=1.0)
    for x in (-0.6, 0.6):
        m.box((x, 0.75, 0), (0.06, 0.32, 2.0), dark, WHITE, uv_scale=1.0)
    m.box((0, 0.75, 0.98), (1.2, 0.32, 0.06), dark, WHITE, uv_scale=1.0)
    m.box((0, 0.72, -0.98), (1.2, 0.26, 0.06), dark, WHITE, uv_scale=1.0)
    m.box((0, 0.45, 0), (1.7, 0.08, 0.1), dark, (0.8, 0.8, 0.8))
    for x in (-0.4, 0.4):
        m.box((x, 0.52, -1.5), (0.07, 0.07, 1.1), dark, (0.9, 0.9, 0.9))
    m.box((0.2, 0.68, 0.3), (0.5, 0.16, 0.5), "tex:wood/crate", WHITE, uv_scale=2.0)
    m.push(compose(mat_translate(0.82, 0.45, 0), mat_rot_z(PI / 2)))
    _wheel(m, 0.45, 0.08)
    m.pop()
    m.pop()
    m.push(compose(mat_translate(-1.2, 0.045, 0.7), mat_rot_y(0.4)))
    _wheel(m, 0.45, 0.08, col=(0.9, 0.9, 0.9))
    m.pop()
    return single("cart", m, {"collision": "box"})


reg("cart_broken", cart_broken)


def signpost(rng, tex="wood/planks_grey", lean=0.0, boards=3, tint=WHITE):
    m = MeshBuilder()
    m.push(mat_rot_z(lean))
    m.box((0, 1.2, 0), (0.12, 2.4, 0.12), "tex:" + tex, tint, uv_scale=1.0)
    yaws = [0.35, 2.2, 4.0, 5.2]
    pts = [(-0.28, -0.09), (0.32, -0.09), (0.46, 0.0), (0.32, 0.09), (-0.28, 0.09)]
    for i in range(boards):
        m.push(compose(mat_translate(0, 1.55 + i * 0.32, 0), mat_rot_y(yaws[i] + rng.random() * 0.4)))
        m.push(compose(mat_translate(0.1, 0, -0.03), mat_rot_x(-PI / 2)))
        m.prism(pts, 0.0, 0.04, "tex:" + tex, vary(rng, (0.95, 0.9, 0.85), 0.05), uv_scale=1.0, cap=True, floor=True)
        m.pop()
        m.pop()
    m.pop()
    return single("signpost", m, {"collision": "cylinder"})


reg("signpost", lambda r: signpost(r))
reg("signpost_forest", lambda r: signpost(r, "wood/planks_dark", lean=0.12, boards=2, tint=(0.8, 0.85, 0.7)))


def market_stall(rng):
    m = MeshBuilder()
    wood = "tex:wood/planks_dark"
    m.box((0, 0.85, 0), (2.0, 0.08, 0.9), wood, WHITE, uv_scale=1.0)
    for x in (-0.9, 0.9):
        for z in (-0.35, 0.35):
            m.box((x, 0.4, z), (0.08, 0.8, 0.08), wood, (0.9, 0.9, 0.9))
    for x in (-1.0, 1.0):
        for z in (-0.5, 0.5):
            m.box((x, 1.15, z), (0.08, 2.3, 0.08), wood, (0.85, 0.85, 0.85))
    m.push(compose(mat_translate(0, 2.35, 0), mat_rot_x(-0.22)))
    for i in range(6):
        x = -1.0 + i * 0.4
        if i % 2 == 0:
            m.box((x, 0, 0), (0.4, 0.03, 1.4), "tex:fabric/cloth_red", WHITE)
        else:
            m.box((x, 0, 0), (0.4, 0.03, 1.4), "flat", (0.95, 0.9, 0.8))
    m.pop()
    m.box((-0.55, 1.0, 0.1), (0.5, 0.22, 0.4), "tex:wood/crate", WHITE, uv_scale=2.0)
    m.box((0.45, 0.92, -0.05), (0.5, 0.06, 0.36), wood, (0.8, 0.8, 0.8))
    for i in range(5):
        m.sphere((0.3 + (i % 3) * 0.14, 1.0, -0.15 + (i // 3) * 0.16), 0.06, 3, 6, "flat", (0.8, 0.15, 0.1))
    return single("market_stall", m, {"collision": "box"})


reg("market_stall", market_stall)


def gargoyle(rng):
    m = MeshBuilder()
    stone = "tex:stone/statue"
    c = (0.9, 0.9, 0.9)
    m.box((0, 0.08, 0), (0.7, 0.16, 0.7), stone, (0.8, 0.8, 0.8), uv_scale=1.0)
    m.box((0, 0.45, 0.02), (0.4, 0.42, 0.5), stone, c)
    m.box((0, 0.78, -0.15), (0.32, 0.26, 0.3), stone, c)
    m.box((0, 0.7, -0.33), (0.2, 0.12, 0.1), stone, c)
    for x in (-0.11, 0.11):
        m.box((x, 0.82, -0.31), (0.06, 0.05, 0.02), "glow:#ff5a1f", WHITE)
        m.push(compose(mat_translate(x, 0.9, -0.1), mat_rot_z(-x * 3)))
        m.lathe([(0.05, 0), (0.0, 0.18)], 4, stone, c, smooth=False)
        m.pop()
        m.box((x * 2.2, 0.32, -0.28), (0.12, 0.5, 0.14), stone, c)
        m.box((x * 2.2, 0.2, 0.2), (0.14, 0.26, 0.3), stone, c)
        m.push(compose(mat_translate(x * 1.9, 0.62, 0.15), mat_rot_z(-x * 4.5), mat_rot_x(0.4)))
        m.box((0, 0.22, 0), (0.05, 0.5, 0.35), stone, (0.85, 0.85, 0.9))
        m.pop()
    m.push(compose(mat_translate(0, 0.35, 0.28), mat_rot_x(0.9)))
    m.box((0, 0.15, 0), (0.06, 0.4, 0.06), stone, c)
    m.pop()
    return single("gargoyle", m, {"collision": "box"})


reg("gargoyle", gargoyle)


def rubble_pile(rng):
    m = MeshBuilder()
    for i in range(3):
        m.push(mat_scale(1.0, 0.55, 0.9))
        m.blob(((rng.random() - 0.5) * 0.9, 0.35, (rng.random() - 0.5) * 0.7), 0.45 + rng.random() * 0.2, rng, rings=3, segments=7, mat="tex:stone/smooth_grey", color=(0.85, 0.85, 0.85), jitter=0.5)
        m.pop()
    for i in range(6):
        s = (0.25 + rng.random() * 0.35, 0.2 + rng.random() * 0.25, 0.25 + rng.random() * 0.35)
        m.push(compose(mat_translate((rng.random() - 0.5) * 1.6, 0.1 + rng.random() * 0.35, (rng.random() - 0.5) * 1.2), mat_rot_y(rng.random() * TAU), mat_rot_x((rng.random() - 0.5) * 0.6), mat_rot_z((rng.random() - 0.5) * 0.6)))
        m.box((0, 0, 0), s, "tex:stone/blocks_city", vary(rng, (0.9, 0.9, 0.9), 0.08), uv_scale=1.0)
        m.pop()
    _settle(m)
    return single("rubble", m, {"collision": "box"})


reg("rubble_pile", rubble_pile)


def portcullis(rng):
    m = MeshBuilder()
    tint = (0.75, 0.75, 0.8)
    a, b, c, d = (-1.5, 0.25, 0), (1.5, 0.25, 0), (1.5, 3.5, 0), (-1.5, 3.5, 0)
    _quadn(m, [a, b, c, d], (0, 0, -1), "tex:metal/bars", tint, uvs=[(0, 1), (3, 1), (3, 0), (0, 0)])
    a, b, c, d = (-1.5, 0.25, 0.03), (1.5, 0.25, 0.03), (1.5, 3.5, 0.03), (-1.5, 3.5, 0.03)
    _quadn(m, [a, b, c, d], (0, 0, -1), "tex:metal/bars", tint, uvs=[(0, 0), (0, 1), (2.1, 1), (2.1, 0)])
    m.box((0, 3.55, 0.015), (3.2, 0.14, 0.14), "tex:metal/iron", WHITE, uv_scale=1.0)
    for i in range(6):
        m.push(compose(mat_translate(-1.25 + i * 0.5, 0.25, 0.015), mat_rot_x(PI)))
        m.lathe([(0.05, 0.0), (0.0, 0.25)], 4, "flat", (0.3, 0.3, 0.33), smooth=False)
        m.pop()
    return single("portcullis", m, {"collision": "box"})


reg("portcullis", portcullis)


def candelabra(rng):
    m = MeshBuilder()
    brass = "tex:metal/brass"
    m.lathe([(0.13, 0.0), (0.13, 0.02), (0.03, 0.04), (0.025, 0.36), (0.05, 0.4)], 7, brass, WHITE, smooth=True)
    m.box((0, 0.42, 0), (0.44, 0.03, 0.03), brass, WHITE)
    m.box((0, 0.5, 0), (0.03, 0.14, 0.03), brass, WHITE)
    for x, y in ((-0.2, 0.42), (0.0, 0.56), (0.2, 0.42)):
        m.push(mat_translate(x, y, 0))
        m.lathe([(0.03, 0.0), (0.045, 0.04), (0.045, 0.06), (0.03, 0.06)], 6, brass, WHITE, smooth=False)
        m.pop()
        _candle(m, (x, y + 0.06, 0), 0.022, 0.14)
    return single("candelabra", m, {"collision": "none"})


reg("candelabra", candelabra)


def lectern(rng):
    m = MeshBuilder()
    wood = "tex:wood/planks_dark"
    m.box((0, 0.04, 0), (0.5, 0.08, 0.5), wood, WHITE)
    m.box((0, 0.55, 0), (0.14, 0.95, 0.14), wood, (0.9, 0.9, 0.9))
    m.push(compose(mat_translate(0, 1.05, 0), mat_rot_x(-0.4)))
    m.box((0, 0.0, 0), (0.62, 0.05, 0.46), wood, WHITE)
    m.box((0, 0.045, -0.2), (0.62, 0.04, 0.04), wood, WHITE)
    m.box((0, 0.04, 0.0), (0.5, 0.025, 0.36), "flat", (0.4, 0.1, 0.1))
    for sgn in (-1, 1):
        pts = [(0.0, 0.065, 0.17), (sgn * 0.23, 0.085, 0.17), (sgn * 0.23, 0.085, -0.15), (0.0, 0.065, -0.15)]
        _quadn(m, pts, (0, 1, 0), "tex:wall/paper", WHITE, uvs=[(0, 1), (1, 1), (1, 0), (0, 0)])
    m.pop()
    return single("lectern", m, {"collision": "box"})


reg("lectern", lectern)


def chest(rng):
    g = GLB("chest")
    wood = "tex:wood/planks_dark"
    iron = "tex:metal/iron"
    m = MeshBuilder()
    m.box((0, 0.25, 0), (0.9, 0.5, 0.55), wood, WHITE, uv_scale=1.0)
    for x in (-0.3, 0.0, 0.3):
        m.box((x, 0.25, 0), (0.06, 0.51, 0.57), iron, (0.8, 0.8, 0.85), uv_scale=1.0)
    m.box((0, 0.42, -0.29), (0.12, 0.1, 0.03), "tex:metal/brass", WHITE)
    g.add("Body", m, extras={"collision": "box"})
    lid = MeshBuilder()
    lid.box((0, 0.05, -0.275), (0.9, 0.1, 0.55), wood, (0.9, 0.9, 0.9), uv_scale=1.0)
    lid.box((0, 0.13, -0.275), (0.9, 0.07, 0.4), wood, (0.9, 0.9, 0.9), uv_scale=1.0)
    for x in (-0.3, 0.0, 0.3):
        lid.box((x, 0.05, -0.275), (0.06, 0.12, 0.57), iron, (0.8, 0.8, 0.85), uv_scale=1.0)
        lid.box((x, 0.13, -0.275), (0.06, 0.09, 0.42), iron, (0.8, 0.8, 0.85), uv_scale=1.0)
    g.add("Lid", lid, translation=(0, 0.51, 0.275))
    return g


reg("chest", chest)


def hourglass_big(rng):
    m = MeshBuilder()
    brass = "tex:metal/brass"
    m.lathe([(0.55, 0.0), (0.55, 0.08), (0.45, 0.1)], 10, brass, WHITE, smooth=False)
    m.lathe([(0.45, 1.9), (0.55, 1.92), (0.55, 2.0)], 10, brass, WHITE, smooth=False)
    for i in range(4):
        a = i / 4 * TAU + PI / 4
        m.box((math.cos(a) * 0.48, 1.0, math.sin(a) * 0.48), (0.06, 1.82, 0.06), brass, WHITE)
    m.lathe([(0.42, 0.11), (0.1, 0.95), (0.05, 1.0)], 9, "glow:#f0e6c8", WHITE, smooth=True, cap_top=False)
    m.lathe([(0.05, 1.0), (0.1, 1.05), (0.42, 1.89)], 9, "flat", (0.78, 0.86, 0.9), smooth=True, cap_bottom=False)
    return single("hourglass_big", m, {"collision": "cylinder"})


reg("hourglass_big", hourglass_big)


def pendulum_big(rng):
    m = MeshBuilder()
    m.box((0, -2.75, 0), (0.08, 5.5, 0.08), "flat", (0.2, 0.2, 0.22))
    m.sphere((0, 0, 0), 0.1, 3, 6, "flat", (0.3, 0.3, 0.32))
    m.push(compose(mat_translate(0, -5.6, 0), mat_rot_x(PI / 2)))
    m.lathe([(0.6, -0.08), (0.6, 0.08)], 12, "tex:metal/brass", WHITE, smooth=False, uv_scale=(4.0, 1.0))
    m.lathe([(0.0, -0.09), (0.45, -0.09)], 12, "tex:metal/brass", (0.85, 0.85, 0.8), smooth=False, cap_top=False, cap_bottom=False)
    m.lathe([(0.45, 0.09), (0.0, 0.09)], 12, "tex:metal/brass", (0.85, 0.85, 0.8), smooth=False, cap_top=False, cap_bottom=False)
    m.pop()
    return single("pendulum_big", m, {"collision": "none"})


reg("pendulum_big", pendulum_big)


def gear_big(rng):
    m = MeshBuilder()
    m.card((0, 1.5, 0), (3.0, 3.0), "tex:metal/gear", (0.9, 0.9, 0.95))
    m.push(compose(mat_translate(0, 1.5, 0), mat_rot_x(PI / 2)))
    m.lathe([(0.22, -0.12), (0.22, 0.12)], 8, "tex:metal/iron", WHITE, smooth=False)
    m.pop()
    return single("gear_big", m, {"collision": "none"})


reg("gear_big", gear_big)


def clock_hand(rng):
    m = MeshBuilder()
    pts = [(-0.14, -0.6), (-0.03, -3.0), (0.03, -3.0), (0.14, -0.6), (0.12, 0.1), (-0.12, 0.1)]
    m.prism(pts, 0.02, 0.1, "flat", (0.12, 0.12, 0.14), cap=True, floor=True)
    m.lathe([(0.25, 0.0), (0.25, 0.12)], 8, "flat", (0.2, 0.18, 0.15), smooth=False)
    return single("clock_hand", m, {"collision": "none"})


reg("clock_hand", clock_hand)


def bell_tower_frame(rng):
    m = MeshBuilder()
    wood = "tex:wood/planks_dark"
    for z in (-0.9, 0.9):
        for x in (-1, 1):
            _bar(m, (x * 1.3, 0, z), (x * 0.2, 4.0, z), 0.18, wood, WHITE)
        _bar(m, (-0.85, 1.9, z), (0.85, 1.9, z), 0.12, wood, (0.9, 0.9, 0.9))
        m.box((0, 0.1, z), (2.9, 0.2, 0.3), wood, (0.85, 0.85, 0.85), uv_scale=1.0)
    m.box((0, 3.98, 0), (0.55, 0.25, 2.2), wood, WHITE, uv_scale=1.0)
    m.push(compose(mat_translate(0, 3.78, 0), mat_rot_x(PI / 2)))
    _torus(m, (0, 0, 0), 0.08, 0.02, 8, 4, "flat", (0.3, 0.3, 0.33))
    m.pop()
    return single("bell_frame", m, {"collision": "none"})


reg("bell_tower_frame", bell_tower_frame)


# --------------------------------------------------------------------------
# forest / tavern extras
# --------------------------------------------------------------------------

def hermit_hut(rng):
    """Round stone hut: wall from 7 prism segments (the front one left open as the
    doorway), thatched cone roof, chimney. collision none: the game handles walls."""
    m = MeshBuilder()
    stone = "tex:stone/cobble_grey"
    R, Ri, H = 1.75, 1.45, 2.4
    n = 8
    for s in range(n):
        if s == 6:
            continue
        a0 = -PI / 8 + s * TAU / n
        a1 = a0 + TAU / n
        pts = [(math.cos(a0) * R, math.sin(a0) * R), (math.cos(a1) * R, math.sin(a1) * R),
               (math.cos(a1) * Ri, math.sin(a1) * Ri), (math.cos(a0) * Ri, math.sin(a0) * Ri)]
        m.prism(pts, 0.0, H, stone, vary(rng, (0.95, 0.95, 0.95), 0.05), uv_scale=1.0, cap=True)
    m.box((0, H - 0.3, -1.55), (1.6, 0.25, 0.4), "tex:wood/planks_dark", WHITE, uv_scale=1.0)
    m.push(mat_rot_y(PI / 8))
    m.lathe([(2.35, H - 0.1), (0.15, H + 1.6)], n, "tex:wood/thatch", WHITE, smooth=False, cap_bottom=False, cap_top=True, uv_scale=(6.0, 1.0))
    m.lathe([(1.4, H - 0.1), (2.35, H - 0.1)], n, "tex:wood/thatch", (0.7, 0.7, 0.7), smooth=False, cap_top=False, cap_bottom=False)
    m.pop()
    m.box((0.9, H + 0.75, 0.6), (0.4, 1.1, 0.4), stone, (0.9, 0.9, 0.9), uv_scale=1.0)
    return single("hut", m, {"collision": "none"})


reg("hermit_hut", hermit_hut)


def shrine(rng):
    m = MeshBuilder()
    stone = "tex:stone/blocks_grey"
    m.box((0, 0.1, 0), (1.4, 0.2, 1.0), stone, WHITE, uv_scale=1.0)
    for x in (-0.45, 0.45):
        m.box((x, 0.7, 0), (0.25, 1.02, 0.25), stone, (0.9, 0.9, 0.9), uv_scale=1.0)
    m.box((0, 1.3, 0), (1.3, 0.2, 0.4), stone, WHITE, uv_scale=1.0)
    m.lathe([(0.2, 0.2), (0.28, 0.35), (0.25, 0.4), (0.18, 0.4), (0.18, 0.32)], 8, "tex:stone/smooth_grey", WHITE, smooth=False, cap_top=False, cap_bottom=False)
    m.lathe([(0.18, 0.33), (0.0, 0.33)], 8, "flat", (0.15, 0.12, 0.1), smooth=False, cap_top=False, cap_bottom=False)
    m.sphere((0, 0.37, 0), 0.07, 3, 6, "glow:#7ff5e6", WHITE)
    return single("shrine", m, {"collision": "box"})


reg("shrine", shrine)


def log(rng):
    m = MeshBuilder()
    bark = "tex:nature/bark_oak"
    m.push(compose(mat_translate(0, 0.33, 0), mat_rot_z(PI / 2)))
    m.lathe([(0.34, -1.5), (0.31, -0.5), (0.33, 0.5), (0.29, 1.5)], 7, bark, WHITE, smooth=True, uv_scale=(2.0, 0.6), cap_top=False, cap_bottom=False)
    m.lathe([(0.0, -1.5), (0.34, -1.5)], 7, "flat", (0.72, 0.58, 0.4), smooth=False, cap_top=False, cap_bottom=False)
    m.lathe([(0.29, 1.5), (0.0, 1.5)], 7, "flat", (0.72, 0.58, 0.4), smooth=False, cap_top=False, cap_bottom=False)
    m.pop()
    m.push(compose(mat_translate(0.4, 0.5, 0.1), mat_rot_z(-0.3), mat_rot_x(-0.9)))
    m.lathe([(0.09, 0), (0.05, 0.7)], 5, bark, (0.9, 0.9, 0.9), smooth=True, cap_bottom=False)
    m.pop()
    return single("log", m, {"collision": "box"})


reg("log", log)


def stump(rng):
    m = MeshBuilder()
    bark = "tex:nature/bark_oak"
    m.lathe([(0.44, 0.0), (0.37, 0.12), (0.34, 0.56)], 7, bark, WHITE, smooth=True, uv_scale=(2.0, 1.0), cap_top=False)
    light, dark = (0.8, 0.64, 0.42), (0.58, 0.42, 0.26)
    m.lathe([(0.34, 0.57), (0.28, 0.57), (0.22, 0.57), (0.16, 0.57), (0.1, 0.57), (0.04, 0.57), (0.0, 0.57)], 7, "flat", WHITE, smooth=False, colors=[dark, light, dark, light, dark, light], cap_top=False, cap_bottom=False)
    for i in range(4):
        m.push(mat_rot_y(i / 4 * TAU + 0.4))
        m.box((0.42, 0.06, 0), (0.3, 0.12, 0.14), bark, (0.9, 0.9, 0.9))
        m.pop()
    return single("stump", m, {"collision": "cylinder"})


reg("stump", stump)


def fireplace(rng):
    g = GLB("fireplace")
    stone = "tex:stone/cobble_grey"
    m = MeshBuilder()
    for x in (-0.75, 0.75):
        m.box((x, 0.7, 0), (0.5, 1.4, 0.6), stone, WHITE, uv_scale=1.0)
    m.box((0, 1.6, 0), (2.0, 0.4, 0.6), stone, WHITE, uv_scale=1.0)
    m.box((0, 2.4, 0.05), (2.0, 1.2, 0.5), stone, (0.9, 0.9, 0.9), uv_scale=1.0)
    m.box((0, 1.84, -0.05), (2.2, 0.08, 0.75), "tex:wood/planks_dark", WHITE, uv_scale=1.0)
    m.box((0, 0.7, 0.25), (1.0, 1.4, 0.1), "flat", (0.12, 0.11, 0.1))
    m.box((0, 0.03, -0.1), (2.0, 0.06, 0.8), stone, (0.7, 0.7, 0.7), uv_scale=1.0)
    for x, z in ((-0.2, 0.0), (0.15, 0.1)):
        m.push(compose(mat_translate(x, 0.14, z), mat_rot_z(PI / 2), mat_rot_x(0.3)))
        m.lathe([(0.08, -0.35), (0.08, 0.35)], 5, "tex:nature/bark_dead", (0.6, 0.5, 0.45), smooth=False)
        m.pop()
    g.add("Body", m, extras={"collision": "box"})
    fire = MeshBuilder()
    _flame(fire, (0, 0.1, 0.05), 0.35, 0.9)
    _flame(fire, (-0.25, 0.1, 0.0), 0.2, 0.55)
    _flame(fire, (0.25, 0.1, 0.05), 0.22, 0.6)
    g.add("Fire", fire)
    return g


reg("fireplace", fireplace)


def lute_prop(rng):
    m = MeshBuilder()
    m.push(mat_rot_x(0.3))
    _lute(m, 1.0)
    m.pop()
    _settle(m)
    return single("lute", m, {"collision": "none"})


reg("lute", lute_prop)


def tankard_rack(rng):
    """Wall-mounted: origin is the back centre of the board."""
    m = MeshBuilder()
    m.box((0, 0, -0.02), (1.2, 0.15, 0.04), "tex:wood/planks_dark", WHITE, uv_scale=1.0)
    cols = [(0.6, 0.6, 0.62), (0.55, 0.4, 0.25), (0.7, 0.68, 0.6), (0.45, 0.3, 0.2), (0.62, 0.62, 0.66)]
    for i in range(5):
        x = -0.48 + i * 0.24
        m.box((x, -0.06, -0.05), (0.02, 0.04, 0.06), "flat", (0.2, 0.2, 0.22))
        _mug(m, (x, -0.24, -0.09), cols[i], 0.055, 0.15)
    return single("tankard_rack", m, {"collision": "none", "mount": "wall"})


reg("tankard_rack", tankard_rack)


def wall_shelf(rng):
    """Wall-mounted: origin is the back centre of the shelf board."""
    m = MeshBuilder()
    wood = "tex:wood/planks_dark"
    m.box((0, 0, -0.125), (1.2, 0.04, 0.25), wood, WHITE, uv_scale=1.0)
    for x in (-0.45, 0.45):
        m.box((x, -0.1, -0.1), (0.04, 0.16, 0.2), wood, (0.85, 0.85, 0.85))
    cols = [(0.3, 0.6, 0.3), (0.5, 0.3, 0.2), (0.3, 0.35, 0.65), (0.85, 0.85, 0.8), (0.7, 0.2, 0.2)]
    for i in range(5):
        _bottle(m, (-0.44 + i * 0.22, 0.02, -0.13), cols[i], 0.055, 0.3 + (i % 2) * 0.06)
    return single("wall_shelf", m, {"collision": "none", "mount": "wall"})


reg("wall_shelf", wall_shelf)


def stage_small(rng):
    m = MeshBuilder()
    m.box((0, 0.18, 0), (3.0, 0.36, 2.0), "tex:wood/planks_warm", WHITE, uv_scale=1.0)
    m.box((0, 0.2, -1.01), (3.0, 0.3, 0.04), "tex:wood/planks_dark", WHITE, uv_scale=1.0)
    m.box((1.1, 0.09, -1.2), (0.8, 0.18, 0.4), "tex:wood/planks_dark", (0.9, 0.9, 0.9), uv_scale=1.0)
    return single("stage", m, {"collision": "box"})


reg("stage_small", stage_small)


# --------------------------------------------------------------------------
# house extras
# --------------------------------------------------------------------------

def attic_hatch(rng):
    m = MeshBuilder()
    wood = "tex:wood/planks_house"
    for sgn in (-1, 1):
        m.box((sgn * 0.37, -0.03, 0), (0.08, 0.06, 0.82), wood, WHITE)
        m.box((0, -0.03, sgn * 0.37), (0.66, 0.06, 0.08), wood, WHITE)
    m.box((0, -0.02, 0), (0.64, 0.03, 0.64), wood, (0.85, 0.85, 0.85))
    _bar(m, (0.2, -0.035, 0.1), (0.2, -0.45, 0.1), 0.02, "flat", (0.9, 0.88, 0.8))
    m.sphere((0.2, -0.47, 0.1), 0.03, 3, 6, "flat", (0.5, 0.35, 0.2))
    return single("attic_hatch", m, {"collision": "none"})


reg("attic_hatch", attic_hatch)


def dog_bowl(rng):
    m = MeshBuilder()
    m.lathe([(0.1, 0.0), (0.14, 0.06), (0.15, 0.07), (0.11, 0.07), (0.11, 0.02)], 8, "flat", (0.75, 0.15, 0.12), smooth=False, cap_top=False)
    m.lathe([(0.11, 0.035), (0.0, 0.035)], 8, "flat", (0.5, 0.35, 0.2), smooth=False, cap_top=False, cap_bottom=False)
    return single("dog_bowl", m, {"collision": "none"})


reg("dog_bowl", dog_bowl)


def kitchen_table(rng):
    m = MeshBuilder()
    wood = "tex:wood/table"
    m.box((0, 0.75, 0), (1.0, 0.05, 1.0), wood, WHITE, uv_scale=1.0)
    m.box((0, 0.68, 0), (0.9, 0.1, 0.9), wood, (0.85, 0.85, 0.85), uv_scale=1.0)
    for x in (-0.42, 0.42):
        for z in (-0.42, 0.42):
            m.box((x, 0.36, z), (0.07, 0.72, 0.07), wood, (0.9, 0.9, 0.9))
    return single("kitchen_table", m, {"collision": "box"})


reg("kitchen_table", kitchen_table)


def cupboard(rng):
    """Wall cupboard: origin is the back centre (mount it at ~1.5 m)."""
    m = MeshBuilder()
    wood = "tex:wood/planks_white"
    m.box((0, 0, -0.175), (0.9, 0.7, 0.35), wood, WHITE, uv_scale=1.0)
    for sgn in (-1, 1):
        m.box((sgn * 0.225, 0, -0.36), (0.42, 0.66, 0.02), wood, (0.92, 0.92, 0.9), uv_scale=1.0)
        m.sphere((sgn * 0.06, -0.05, -0.385), 0.025, 3, 6, "flat", (0.3, 0.25, 0.2))
    return single("cupboard", m, {"collision": "none", "mount": "wall"})


reg("cupboard", cupboard)


def bathroom_cabinet(rng):
    """Wall-mounted: origin is the back centre."""
    m = MeshBuilder()
    m.box((0, 0, -0.075), (0.6, 0.7, 0.15), "flat", (0.93, 0.93, 0.9))
    m.card((0, 0, -0.16), (0.5, 0.6), "tex:props/mirror", WHITE, yaw=PI, double=False)
    m.box((0, -0.44, -0.07), (0.6, 0.03, 0.14), "flat", (0.93, 0.93, 0.9))
    m.lathe([(0.03, -0.425), (0.03, -0.33)], 6, "flat", (0.6, 0.75, 0.8), smooth=False)
    return single("bathroom_cabinet", m, {"collision": "none", "mount": "wall"})


reg("bathroom_cabinet", bathroom_cabinet)


def shoe_pile(rng):
    m = MeshBuilder()
    cols = [(0.35, 0.22, 0.12), (0.1, 0.1, 0.1), (0.6, 0.15, 0.12), (0.2, 0.15, 0.1), (0.8, 0.8, 0.75)]
    for i in range(5):
        a = rng.random() * TAU
        m.push(compose(mat_translate((rng.random() - 0.5) * 0.5, 0.045 + (0.07 if i == 4 else 0), (rng.random() - 0.5) * 0.4), mat_rot_y(a)))
        m.box((0, 0, 0), (0.1, 0.09, 0.27), "flat", cols[i])
        m.box((0, 0.02, -0.16), (0.09, 0.05, 0.06), "flat", cols[i])
        m.pop()
    return single("shoes", m, {"collision": "none"})


reg("shoe_pile", shoe_pile)


def skirting_hole(rng):
    """A mouse hole at the foot of a wall: origin at the floor/wall junction."""
    m = MeshBuilder()
    wood = (0.9, 0.88, 0.8)
    r, ro, cy = 0.07, 0.1, 0.05
    for sgn in (-1, 1):
        m.box((sgn * 0.135, 0.06, -0.015), (0.07, 0.12, 0.03), "flat", wood)
        m.box((sgn * (r + 0.015), cy / 2, -0.015), (0.03, cy, 0.03), "flat", wood)
    _arch(m, (0, cy, -0.015), r, ro, 0.03, 5, "flat", wood)
    m.box((0, 0.145, -0.015), (0.34, 0.03, 0.03), "flat", vary(rng, wood, 0.03))
    # the arch is left open: what is behind it (a dark box through a carved wall,
    # or a lit crawl behind a real gap) is what the player sees
    return single("skirting_hole", m, {"collision": "none", "mount": "wall"})


reg("skirting_hole", skirting_hole)


def tape_measure_deco(rng):
    m = MeshBuilder()
    yellow = (0.95, 0.75, 0.1)
    oct_ = [(math.cos(a) * 0.085, math.sin(a) * 0.085) for a in [i / 8 * TAU + PI / 8 for i in range(8)]]
    m.push(compose(mat_translate(0, 0.085, 0.0), mat_rot_x(PI / 2)))
    m.prism(oct_, -0.04, 0.04, "flat", yellow, cap=True, floor=True)
    m.pop()
    m.box((0, 0.11, -0.045), (0.05, 0.05, 0.02), "flat", (0.1, 0.1, 0.1))
    m.box((0, 0.012, -1.06), (0.025, 0.008, 2.0), "flat", (0.95, 0.9, 0.55))
    m.box((0, 0.02, -2.07), (0.04, 0.03, 0.02), "flat", (0.6, 0.6, 0.62))
    return single("tape_measure", m, {"collision": "none"})


reg("tape_measure_deco", tape_measure_deco)


def boxes_moving(rng):
    m = MeshBuilder()
    tan = (0.72, 0.55, 0.35)
    tape = (0.5, 0.36, 0.22)
    for i, (s, y, yaw) in enumerate((((0.7, 0.45, 0.55), 0.225, 0.0), ((0.6, 0.4, 0.45), 0.66, 0.15), ((0.45, 0.35, 0.4), 1.04, -0.2))):
        m.push(compose(mat_translate(0, y, 0), mat_rot_y(yaw)))
        m.box((0, 0, 0), s, "flat", vary(rng, tan, 0.06))
        m.box((0, s[1] / 2 + 0.003, 0), (0.06, 0.006, s[2] + 0.01), "flat", tape)
        m.pop()
    return single("boxes", m, {"collision": "box"})


reg("boxes_moving", boxes_moving)


def phone_wall(rng):
    """Old wall phone: origin is the back centre (mount it at ~1.4 m)."""
    m = MeshBuilder()
    dark = (0.12, 0.12, 0.14)
    m.box((0, 0, -0.06), (0.22, 0.4, 0.12), "flat", dark)
    m.box((-0.15, 0.05, -0.08), (0.07, 0.26, 0.07), "flat", (0.15, 0.15, 0.17))
    m.push(compose(mat_translate(0, 0.05, -0.125), mat_rot_x(-PI / 2)))
    m.lathe([(0.065, 0.0), (0.065, 0.012)], 8, "flat", (0.85, 0.85, 0.82), smooth=False)
    m.pop()
    m.box((0, -0.12, -0.125), (0.1, 0.03, 0.01), "flat", (0.6, 0.6, 0.6))
    m.card((-0.15, -0.3, -0.08), (0.03, 0.45), "tex:metal/chain", (0.2, 0.2, 0.22))
    return single("phone_wall", m, {"collision": "none", "mount": "wall"})


reg("phone_wall", phone_wall)
