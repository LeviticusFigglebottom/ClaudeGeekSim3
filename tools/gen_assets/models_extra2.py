"""
models_extra2 — the props of the King's Dream: chess pieces, hedge blocks, the
paper roses of the garden, the carriage, the egg on the wall, the tea table,
the hung mallets and the signpost that disagrees with itself.

Loaded by models.py through _load_extra like models_extra. Conventions are the
same: +Y up, the prop faces -Z, the origin is the base centre on the ground
(hanging props: the attachment point), metres, low poly. Materials:
"tex:<group>/<name>" (textured, tinted by vertex colour), "glow:#rrggbb"
(unshaded emissive), anything else = lit vertex colour. Every piece is white
or cream so Props.place can tint it: the chess pieces come in red and white.
"""
from __future__ import annotations

import math

import numpy as np

from glb import GLB, MeshBuilder, compose, mat_rot_x, mat_rot_y, mat_rot_z, mat_scale, mat_translate  # noqa: E402
from models import single, vary  # noqa: E402
from models_extra import reg, _bar, _limb, _disc, _quadn, _trin, WHITE, PI, TAU, SKIN  # noqa: E402

CREAM = (0.97, 0.94, 0.86)
IVORY = (0.92, 0.9, 0.84)
DARK_WOOD = (0.32, 0.2, 0.12)
IRON = (0.24, 0.24, 0.27)
PAPER = "tex:wall/paper"


# --------------------------------------------------------------------------
# chess pieces (one metre tall; the game scales them)
# --------------------------------------------------------------------------

def _piece_base(m, col):
    m.lathe([(0.3, 0.0), (0.32, 0.06), (0.26, 0.1), (0.2, 0.14)], 10, "flat", col, smooth=True)


def chess_pawn(rng):
    m = MeshBuilder()
    _piece_base(m, IVORY)
    m.lathe([(0.2, 0.14), (0.12, 0.3), (0.1, 0.55), (0.16, 0.62), (0.1, 0.68)], 10, "flat", CREAM, smooth=True, cap_bottom=False)
    m.sphere((0, 0.84, 0), 0.16, 5, 10, "flat", CREAM)
    return single("chess_pawn", m, {"collision": "cylinder"})


reg("chess_pawn", chess_pawn)


def chess_queen(rng):
    m = MeshBuilder()
    _piece_base(m, IVORY)
    m.lathe([(0.2, 0.14), (0.12, 0.35), (0.09, 0.7), (0.17, 0.8), (0.11, 0.86), (0.15, 0.98)], 10, "flat", CREAM, smooth=True, cap_bottom=False)
    for i in range(7):
        a = i / 7 * TAU
        m.push(compose(mat_translate(math.cos(a) * 0.14, 0.98, math.sin(a) * 0.14), mat_rot_y(-a)))
        m.box((0, 0.05, 0), (0.05, 0.1, 0.04), "flat", IVORY)
        m.pop()
    m.sphere((0, 1.08, 0), 0.05, 3, 6, "flat", CREAM)
    return single("chess_queen", m, {"collision": "cylinder"})


reg("chess_queen", chess_queen)


def chess_king(rng):
    m = MeshBuilder()
    _piece_base(m, IVORY)
    m.lathe([(0.2, 0.14), (0.12, 0.35), (0.09, 0.72), (0.18, 0.84), (0.12, 0.9), (0.14, 1.0), (0.0, 1.0)], 10, "flat", CREAM, smooth=True, cap_bottom=False)
    # the cross
    m.box((0, 1.1, 0), (0.05, 0.2, 0.05), "flat", IVORY)
    m.box((0, 1.13, 0), (0.15, 0.05, 0.05), "flat", IVORY)
    return single("chess_king", m, {"collision": "cylinder"})


reg("chess_king", chess_king)


def chess_knight(rng):
    m = MeshBuilder()
    _piece_base(m, IVORY)
    m.lathe([(0.2, 0.14), (0.16, 0.3), (0.15, 0.42)], 8, "flat", CREAM, smooth=True, cap_bottom=False)
    # the horse: neck leaning forward (-Z), head, ears, mane
    m.push(compose(mat_translate(0, 0.42, 0.03), mat_rot_x(0.35)))
    m.box((0, 0.22, 0), (0.22, 0.44, 0.2), "flat", CREAM)
    m.pop()
    m.push(compose(mat_translate(0, 0.78, -0.1), mat_rot_x(-0.2)))
    m.box((0, 0.06, -0.08), (0.2, 0.18, 0.34), "flat", CREAM)
    m.box((0, 0.02, -0.28), (0.16, 0.12, 0.12), "flat", IVORY)
    for x in (-0.06, 0.06):
        m.box((x, 0.19, 0.02), (0.05, 0.1, 0.05), "flat", IVORY)
    m.pop()
    for i in range(4):
        m.box((0, 0.55 + i * 0.09, 0.14 - i * 0.02), (0.08, 0.06, 0.08), "flat", IVORY)
    return single("chess_knight", m, {"collision": "cylinder"})


reg("chess_knight", chess_knight)


# --------------------------------------------------------------------------
# the garden
# --------------------------------------------------------------------------

def hedge_block(rng):
    m = MeshBuilder()
    m.box((0, 1.5, 0), (2.0, 3.0, 2.0), "tex:nature/hedge", WHITE, uv_scale=0.6)
    m.box((0, 3.08, 0), (1.7, 0.16, 1.7), "tex:nature/hedge", (0.9, 1.0, 0.9), uv_scale=0.6)
    return single("hedge_block", m, {"collision": "box"})


reg("hedge_block", hedge_block)


def rose_paper_planted(rng):
    """A rose folded from a page, on a stem, planted. The page shows on every petal."""
    m = MeshBuilder()
    m.lathe([(0.014, 0.0), (0.011, 0.42)], 5, "flat", (0.34, 0.55, 0.28), smooth=False)
    for sgn in (-1, 1):
        m.push(compose(mat_translate(0, 0.16 + 0.05 * sgn, 0), mat_rot_y(sgn * 0.8 + rng.random() * 0.4), mat_rot_z(sgn * 0.55)))
        m.box((sgn * 0.06, 0, 0), (0.12, 0.01, 0.05), "flat", (0.36, 0.58, 0.3))
        m.pop()
    # petals: folded page quads leaning out in three rings
    for ring, (r, h, n, tilt) in enumerate(((0.035, 0.1, 5, 0.25), (0.07, 0.09, 6, 0.6), (0.1, 0.07, 7, 1.0))):
        for i in range(n):
            a = i / n * TAU + ring * 0.4
            m.push(compose(mat_translate(math.cos(a) * r * 0.5, 0.44 + ring * 0.01, math.sin(a) * r * 0.5), mat_rot_y(-a + PI / 2), mat_rot_x(-tilt)))
            m.quad((-0.035, 0, 0), (0.035, 0, 0), (0.04, h, 0), (-0.04, h, 0), PAPER, vary(rng, (0.98, 0.96, 0.9), 0.03),
                   uvs=[(0, 1), (0.3, 1), (0.3, 0.6), (0, 0.6)], double=True)
            m.pop()
    m.sphere((0, 0.47, 0), 0.03, 3, 6, PAPER, (0.95, 0.92, 0.86))
    return single("rose_paper_planted", m, {"collision": "none"})


reg("rose_paper_planted", rose_paper_planted)


def signpost_contradictory(rng):
    """Four arms that point four ways. The text goes on afterwards, in the game."""
    m = MeshBuilder()
    m.box((0, 1.4, 0), (0.14, 2.8, 0.14), "tex:wood/planks_white", (0.95, 0.9, 0.95), uv_scale=1.0)
    m.box((0, 2.86, 0), (0.24, 0.12, 0.24), "flat", (0.9, 0.7, 0.8))
    pts = [(-0.3, -0.1), (0.4, -0.1), (0.56, 0.0), (0.4, 0.1), (-0.3, 0.1)]
    cols = [(0.98, 0.8, 0.86), (0.8, 0.9, 1.0), (0.85, 1.0, 0.88), (1.0, 0.95, 0.75)]
    for i in range(4):
        m.push(compose(mat_translate(0, 1.5 + i * 0.34, 0), mat_rot_y(i * PI / 2 + 0.35)))
        m.push(compose(mat_translate(0.12, 0, -0.04), mat_rot_x(-PI / 2)))
        m.prism(pts, 0.0, 0.05, "flat", cols[i], cap=True, floor=True)
        m.pop()
        m.pop()
    return single("signpost_contradictory", m, {"collision": "cylinder"})


reg("signpost_contradictory", signpost_contradictory)


# --------------------------------------------------------------------------
# the carriage
# --------------------------------------------------------------------------

def carriage_seat(rng):
    m = MeshBuilder()
    plush = "tex:fabric/sofa"
    m.box((0, 0.24, 0), (1.2, 0.08, 0.5), "flat", DARK_WOOD)
    m.box((0, 0.42, 0.02), (1.2, 0.28, 0.56), plush, (0.75, 0.5, 0.45), uv_scale=0.8)
    m.box((0, 0.95, 0.24), (1.2, 0.8, 0.12), plush, (0.8, 0.55, 0.5), uv_scale=0.8)
    for x in (-0.55, 0.55):
        m.box((x, 0.12, 0), (0.08, 0.24, 0.44), "flat", DARK_WOOD)
        m.box((x, 0.75, 0.02), (0.1, 0.24, 0.52), "flat", DARK_WOOD)
    m.box((0, 1.42, 0.28), (1.2, 0.06, 0.16), "flat", (0.55, 0.45, 0.3))
    return single("carriage_seat", m, {"collision": "box"})


reg("carriage_seat", carriage_seat)


def carriage_window(rng):
    """A framed window with a pale pane; origin at the centre of the back face, mounted on a wall."""
    m = MeshBuilder()
    frame = (0.5, 0.35, 0.22)
    for x in (-0.5, 0.5):
        m.box((x, 0, -0.03), (0.08, 1.2, 0.06), "flat", frame)
    for y in (-0.6, 0.6):
        m.box((0, y, -0.03), (1.08, 0.08, 0.06), "flat", frame)
    m.box((0, 0.18, -0.03), (1.0, 0.05, 0.05), "flat", frame)
    m.box((0, -0.68, -0.08), (1.2, 0.06, 0.16), "flat", (0.55, 0.45, 0.3))
    return single("carriage_window", m, {"collision": "none", "mount": "wall"})


reg("carriage_window", carriage_window)


# --------------------------------------------------------------------------
# the wall
# --------------------------------------------------------------------------

def egg_large(rng):
    """Someone very round. Sits with his legs dangling; the origin is under him."""
    g = GLB("egg_large")
    m = MeshBuilder()
    m.push(compose(mat_translate(0, 0.95, 0), mat_scale(1.0, 1.3, 1.0)))
    m.sphere((0, 0, 0), 0.62, 7, 12, "flat", (0.97, 0.93, 0.84))
    m.pop()
    # a sash and a cravat
    m.push(mat_translate(0, 0.7, 0))
    m.lathe([(0.6, -0.05), (0.62, 0.0), (0.6, 0.05)], 12, "flat", (0.75, 0.25, 0.3), smooth=False, cap_top=False, cap_bottom=False)
    m.pop()
    m.box((0, 0.98, -0.6), (0.2, 0.16, 0.06), "flat", (0.3, 0.3, 0.6))
    # arms out to the sides, legs dangling in front
    for sgn in (-1, 1):
        _limb(m, (sgn * 0.5, 0.95, -0.1), (sgn * 0.95, 0.72, -0.25), 0.07, 0.05, "flat", (0.2, 0.2, 0.28))
        m.box((sgn * 1.0, 0.7, -0.27), (0.12, 0.1, 0.1), "flat", (0.97, 0.9, 0.82))
        _limb(m, (sgn * 0.25, 0.45, -0.35), (sgn * 0.3, -0.05, -0.5), 0.09, 0.07, "flat", (0.2, 0.2, 0.28))
        m.box((sgn * 0.3, -0.1, -0.56), (0.16, 0.1, 0.24), "flat", (0.12, 0.1, 0.1))
    g.add("Body", m, extras={"collision": "box"})
    f = MeshBuilder()
    f.card((0, 0, 0), (0.56, 0.56), "tex:faces/patron", WHITE, yaw=PI, double=False)
    g.add("Head", f, translation=(0, 1.15, -0.57))
    return g


reg("egg_large", egg_large)


# --------------------------------------------------------------------------
# the tea table
# --------------------------------------------------------------------------

def teapot_tall(rng):
    m = MeshBuilder()
    china = (0.96, 0.96, 0.92)
    blue = (0.55, 0.65, 0.85)
    m.lathe([(0.2, 0.0), (0.32, 0.1), (0.36, 0.45), (0.3, 0.85), (0.22, 1.0), (0.24, 1.05), (0.0, 1.05)], 10, "flat", china, smooth=True, colors=[china, blue, china, china, blue, china])
    m.lathe([(0.08, 1.05), (0.06, 1.16), (0.0, 1.2)], 6, "flat", blue, smooth=True, cap_bottom=False)
    _limb(m, (0.3, 0.45, 0), (0.62, 0.9, 0), 0.06, 0.035, "flat", china)
    _limb(m, (-0.32, 0.8, 0), (-0.52, 0.65, 0), 0.04, 0.04, "flat", china)
    _limb(m, (-0.52, 0.65, 0), (-0.3, 0.42, 0), 0.04, 0.04, "flat", china)
    return single("teapot_tall", m, {"collision": "cylinder"})


reg("teapot_tall", teapot_tall)


def teacup_stack(rng):
    m = MeshBuilder()
    china = (0.97, 0.96, 0.93)
    tints = [(0.95, 0.8, 0.85), (0.8, 0.9, 1.0), (0.9, 1.0, 0.9), (1.0, 0.95, 0.8), (0.9, 0.85, 1.0)]
    y = 0.0
    x = 0.0
    for i in range(6):
        m.push(compose(mat_translate(x, y, 0), mat_rot_z((rng.random() - 0.5) * 0.14)))
        m.lathe([(0.09, 0.0), (0.08, 0.02), (0.12, 0.12), (0.1, 0.12), (0.06, 0.03), (0.0, 0.03)], 8, "flat", china, smooth=False, colors=[tints[i % 5], china, china, china, china])
        _limb(m, (0.12, 0.05, 0), (0.17, 0.09, 0), 0.015, 0.015, "flat", china, segs=4)
        m.pop()
        y += 0.09
        x += (rng.random() - 0.5) * 0.04
    m.lathe([(0.17, 0.0), (0.17, 0.012), (0.0, 0.012)], 10, "flat", (0.9, 0.9, 0.95), smooth=False, cap_bottom=False)
    return single("teacup_stack", m, {"collision": "none"})


reg("teacup_stack", teacup_stack)


# --------------------------------------------------------------------------
# the croquet ground
# --------------------------------------------------------------------------

def mallet_hook(rng):
    """An iron hook with a croquet mallet hung by its head. Origin at the hook, on the wall."""
    m = MeshBuilder()
    m.box((0, 0, -0.05), (0.08, 0.16, 0.1), "flat", IRON)
    _limb(m, (0, 0, -0.1), (0, -0.06, -0.28), 0.02, 0.02, "flat", IRON, segs=5)
    _limb(m, (0, -0.06, -0.28), (0, 0.06, -0.3), 0.02, 0.015, "flat", IRON, segs=5)
    # the mallet: head hooked at the top, handle hanging
    stripe = (0.8, 0.2, 0.2)
    m.push(mat_translate(0, -0.1, -0.24))
    m.push(mat_rot_z(PI / 2))
    m.lathe([(0.06, -0.18), (0.06, -0.06), (0.06, 0.06), (0.06, 0.18)], 8, "flat", CREAM, smooth=False, colors=[stripe, CREAM, stripe])
    m.pop()
    m.lathe([(0.018, -1.05), (0.02, -0.02)], 6, "flat", (0.7, 0.55, 0.35), smooth=False)
    m.pop()
    return single("mallet_hook", m, {"collision": "none", "mount": "wall"})


reg("mallet_hook", mallet_hook)


# --------------------------------------------------------------------------
# the beanstalk, the vase, and the King as he is
# --------------------------------------------------------------------------

STALK = "tex:nature/stalk"
LEAF = (0.42, 0.7, 0.34)


def _leaf(m, base, length, width, yaw, tilt, col=LEAF):
    """A pointed leaf lying out from `base` along yaw, tilted up by tilt."""
    m.push(compose(mat_translate(*base), mat_rot_y(yaw), mat_rot_x(-tilt)))
    m.quad((-width * 0.5, 0, -length * 0.45), (width * 0.5, 0, -length * 0.45), (0, 0.02, -length), (0, 0.02, -length), "flat", col, double=True)
    m.quad((-width * 0.12, 0, 0), (width * 0.12, 0, 0), (width * 0.5, 0, -length * 0.45), (-width * 0.5, 0, -length * 0.45), "flat", col, double=True)
    m.pop()


def beanstalk_small(rng):
    """A sprout a little taller than a man: a twisting stem with a few leaves and a curl at the top."""
    m = MeshBuilder()
    pts = [(0, 0, 0)]
    for i in range(1, 8):
        a = i * 0.9
        pts.append((math.cos(a) * 0.12 * i / 7, i * 0.24, math.sin(a) * 0.12 * i / 7))
    for i in range(len(pts) - 1):
        _limb(m, pts[i], pts[i + 1], 0.06 - i * 0.005, 0.055 - i * 0.005, STALK, WHITE)
    # the curl
    top = pts[-1]
    for i in range(6):
        a = i * 0.7
        p0 = (top[0] + math.cos(a) * 0.12, top[1] + 0.06 * i, top[2] + math.sin(a) * 0.12)
        p1 = (top[0] + math.cos(a + 0.7) * 0.12, top[1] + 0.06 * (i + 1), top[2] + math.sin(a + 0.7) * 0.12)
        _limb(m, p0, p1, 0.02, 0.015, STALK, WHITE)
    for i, p in enumerate(pts[2:7]):
        _leaf(m, p, 0.5 + rng.random() * 0.2, 0.3, i * 1.9 + rng.random() * 0.5, 0.35)
    return single("beanstalk_small", m, {"collision": "none"})


reg("beanstalk_small", beanstalk_small)


def beanstalk_leaf(rng):
    """One great leaf, four metres long, to hang off the giant stalk."""
    m = MeshBuilder()
    _leaf(m, (0, 0, 0), 4.0, 2.2, 0.0, 0.2, vary(rng, LEAF, 0.05))
    _limb(m, (0, -0.02, 0), (0, 0.6, -3.6), 0.06, 0.02, STALK, WHITE)
    return single("beanstalk_leaf", m, {"collision": "none"})


reg("beanstalk_leaf", beanstalk_leaf)


def vase(rng):
    """A cream vase with a blue band, for three paper roses."""
    m = MeshBuilder()
    m.lathe([(0.1, 0.0), (0.15, 0.08), (0.14, 0.24), (0.08, 0.34), (0.1, 0.42)], 10, "flat", (0.94, 0.9, 0.84), smooth=True)
    m.lathe([(0.152, 0.12), (0.152, 0.17)], 10, "flat", (0.3, 0.42, 0.68), smooth=False, cap_top=False, cap_bottom=False)
    return single("vase", m, {"collision": "none"})


reg("vase", vase)


def king_coma(rng):
    """The Red King as he is: no crown, no colour, lying very still under a sheet."""
    m = MeshBuilder()
    sheet = "tex:fabric/sheet"
    pale = (0.92, 0.9, 0.86)
    m.box((-0.75, 0.06, 0.05), (0.5, 0.12, 0.42), "flat", (0.9, 0.88, 0.8))
    m.push(compose(mat_translate(0.1, 0.22, 0), mat_scale(1.0, 0.6, 1.0), mat_rot_z(PI / 2)))
    m.lathe([(0.3, -0.7), (0.34, -0.2), (0.3, 0.4), (0.26, 0.7)], 8, sheet, WHITE, smooth=True, uv_scale=(2.0, 1.0))
    m.pop()
    _limb(m, (-0.5, 0.3, -0.18), (0.05, 0.22, -0.3), 0.08, 0.07, sheet, WHITE)
    m.box((0.12, 0.2, -0.3), (0.12, 0.06, 0.12), SKIN, pale)
    m.push(compose(mat_translate(-0.62, 0.22, -0.02), mat_rot_z(PI / 2)))
    m.lathe([(0.08, 0.0), (0.08, 0.12)], 6, SKIN, pale)
    m.pop()
    m.sphere((-0.8, 0.2, -0.02), 0.16, 5, 8, SKIN, pale)
    m.card((-0.8, 0.21, -0.19), (0.3, 0.32), "tex:faces/king", pale, yaw=PI)
    return single("king_coma", m, {"collision": "box"})


reg("king_coma", king_coma)


def usher_king(rng):
    """The one in the bed at the end: half under a sheet, half in the coat, one hat brim, one face."""
    m = MeshBuilder()
    sheet = "tex:fabric/sheet"
    coat = "tex:fabric/coat"
    pale = (0.92, 0.9, 0.86)
    dark = (0.16, 0.15, 0.17)
    m.box((-0.75, 0.06, 0.05), (0.5, 0.12, 0.42), "flat", (0.9, 0.88, 0.8))
    for z, mat, col in ((-0.1, sheet, WHITE), (0.1, coat, dark)):
        m.push(compose(mat_translate(0.1, 0.22, z), mat_scale(1.0, 0.6, 0.5), mat_rot_z(PI / 2)))
        m.lathe([(0.3, -0.7), (0.34, -0.2), (0.3, 0.4), (0.26, 0.7)], 8, mat, col, smooth=True, uv_scale=(2.0, 1.0))
        m.pop()
    _limb(m, (-0.5, 0.3, -0.18), (0.05, 0.22, -0.3), 0.08, 0.07, sheet, WHITE)
    _limb(m, (-0.5, 0.3, 0.18), (0.05, 0.22, 0.3), 0.08, 0.07, coat, dark)
    m.box((0.12, 0.2, -0.3), (0.12, 0.06, 0.12), SKIN, pale)
    m.box((0.12, 0.2, 0.3), (0.12, 0.06, 0.12), "flat", (0.92, 0.9, 0.86))
    m.push(compose(mat_translate(-0.62, 0.22, -0.02), mat_rot_z(PI / 2)))
    m.lathe([(0.08, 0.0), (0.08, 0.12)], 6, SKIN, pale)
    m.pop()
    m.sphere((-0.8, 0.2, -0.02), 0.16, 5, 8, SKIN, pale)
    m.card((-0.8, 0.21, -0.19), (0.3, 0.32), "tex:faces/king", pale, yaw=PI)
    # the hat, on the coat side of the pillow, brim and crown
    m.box((-0.8, 0.3, 0.14), (0.4, 0.03, 0.22), "flat", (0.07, 0.07, 0.08))
    m.box((-0.8, 0.39, 0.14), (0.24, 0.16, 0.16), "flat", (0.07, 0.07, 0.08))
    return single("usher_king", m, {"collision": "box"})


reg("usher_king", usher_king)
