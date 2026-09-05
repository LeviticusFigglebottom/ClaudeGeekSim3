"""
models — the prop catalogue for ANTEROOM (low-poly GLB, PlayStation spirit).

    python3 tools/gen_assets/models.py           # everything -> assets/models/*.glb
    python3 tools/gen_assets/models.py --only tree
    python3 tools/gen_assets/models.py --list

Each prop is a function (rng) -> GLB. Origins sit on the ground at the prop's
centre; props face -Z. Materials are named for src/kit/props.gd:
"tex:<texture>" (textured, tinted by vertex colour), "glow:#hex" (unshaded,
emissive) or a plain name (lit vertex colour). Node names like "Leaf", "Fire",
"Screen", "Pendulum", "Hand" are found by the game and animated.
"""
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from glb import GLB, MeshBuilder, compose, mat_rot_x, mat_rot_y, mat_rot_z, mat_scale, mat_translate, read_check  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "models"

CATALOG = {}


def reg(name, fn):
    CATALOG[name] = fn
    return fn


def rng_for(name, seed=7):
    h = 2166136261
    for ch in name.encode():
        h = ((h ^ ch) * 16777619) & 0xFFFFFFFF
    return np.random.default_rng((h ^ seed) & 0xFFFFFFFF)


def hexc(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def vary(rng, col, amt=0.08):
    return tuple(min(1.0, max(0.0, v + (rng.random() - 0.5) * 2 * amt)) for v in col)


def single(name, mesh, extras=None):
    g = GLB(name)
    g.add(name.capitalize(), mesh, extras=extras)
    return g


# --------------------------------------------------------------------------
# nature
# --------------------------------------------------------------------------

def _trunk(m, rng, base_r, height, bark, taper=0.55, segs=7, lean=0.0):
    prof = []
    n = 5
    for i in range(n + 1):
        t = i / n
        r = base_r * (1.0 - t * (1 - taper)) * (1.25 if i == 0 else 1.0)
        prof.append((r, t * height))
    m.push(mat_rot_z(lean))
    m.lathe(prof, segs, "tex:" + bark, (1, 1, 1), smooth=True, uv_scale=(2.0, 0.6), cap_bottom=False)
    m.pop()


def _roots(m, rng, base_r, bark, n=4, length=None):
    length = length or base_r * 2.2
    for i in range(n):
        a = i / n * math.tau + rng.random() * 0.6
        m.push(compose(mat_rot_y(a), mat_translate(base_r * 0.8, 0.0, 0.0)))
        m.push(mat_rot_z(-1.2))
        m.lathe([(base_r * 0.35, 0.0), (base_r * 0.12, length)], 5, "tex:" + bark, (0.9, 0.9, 0.9), smooth=True, uv_scale=(1.0, 0.6), cap_bottom=False)
        m.pop()
        m.pop()


def _canopy(m, rng, center, radius, leaf_tex, n=4, cols=None):
    cols = cols or [(0.75, 0.9, 0.7), (0.6, 0.8, 0.6), (0.9, 1.0, 0.85), (0.55, 0.7, 0.55)]
    for i in range(n):
        off = np.array([rng.random() - 0.5, (rng.random() - 0.5) * 0.5, rng.random() - 0.5]) * radius * 0.9
        c = tuple(center + off)
        r = radius * (0.55 + rng.random() * 0.35)
        m.blob(c, r, rng, rings=4, segments=7, mat="tex:" + leaf_tex, color=cols[i % len(cols)], jitter=0.35)


def tree_oak(rng, size=1.0, leaf="nature/leaves_dark"):
    m = MeshBuilder()
    h = 7.0 * size
    _trunk(m, rng, 0.45 * size, h * 0.62, "nature/bark_oak", taper=0.5, lean=(rng.random() - 0.5) * 0.12)
    _roots(m, rng, 0.45 * size, "nature/bark_oak", n=4)
    # two branches
    for a in (0.7, 3.4):
        m.push(compose(mat_translate(0, h * 0.5, 0), mat_rot_y(a + rng.random()), mat_rot_z(-0.9)))
        m.lathe([(0.16 * size, 0), (0.06 * size, 2.2 * size)], 5, "tex:nature/bark_oak", (1, 1, 1), uv_scale=(1.0, 0.6), cap_bottom=False)
        m.pop()
    _canopy(m, rng, np.array([0, h * 0.78, 0]), 2.6 * size, leaf, n=5)
    return single("tree", m, {"collision": "cylinder"})


reg("tree_oak_1", lambda r: tree_oak(r, 1.0))
reg("tree_oak_2", lambda r: tree_oak(r, 1.25))
reg("tree_oak_3", lambda r: tree_oak(r, 0.85, "nature/leaves_purple"))
reg("tree_giant", lambda r: tree_oak(r, 3.4))
reg("tree_autumn", lambda r: tree_oak(r, 1.1, "nature/leaves_autumn"))


def tree_dead(rng, size=1.0):
    m = MeshBuilder()
    h = 6.0 * size
    _trunk(m, rng, 0.35 * size, h, "nature/bark_dead", taper=0.25, segs=6)
    for i in range(5):
        y = h * (0.4 + 0.5 * rng.random())
        m.push(compose(mat_translate(0, y, 0), mat_rot_y(rng.random() * math.tau), mat_rot_z(-(0.5 + rng.random() * 0.9))))
        m.lathe([(0.1 * size, 0), (0.02 * size, (1.2 + rng.random() * 1.5) * size)], 4, "tex:nature/bark_dead", (0.85, 0.85, 0.85), uv_scale=(1.0, 0.6), cap_bottom=False)
        m.pop()
    return single("tree_dead", m, {"collision": "cylinder"})


reg("tree_dead_1", lambda r: tree_dead(r, 1.0))
reg("tree_dead_2", lambda r: tree_dead(r, 1.4))


def tree_pine(rng, size=1.0):
    m = MeshBuilder()
    h = 8.0 * size
    _trunk(m, rng, 0.3 * size, h * 0.5, "nature/bark_pine", taper=0.5, segs=6)
    for i, (y, r) in enumerate(((0.32, 2.4), (0.52, 1.9), (0.72, 1.4), (0.9, 0.9))):
        m.push(mat_translate(0, h * y, 0))
        m.lathe([(r * size, 0.0), (0.0, 2.6 * size)], 7, "tex:nature/leaves_dark", (0.7 + 0.1 * i, 0.85, 0.7), smooth=False, cap_bottom=True, cap_top=False)
        m.pop()
    return single("tree_pine", m, {"collision": "cylinder"})


reg("tree_pine_1", lambda r: tree_pine(r, 1.0))
reg("tree_pine_2", lambda r: tree_pine(r, 1.5))


def mushroom(rng, cap_tex, size=1.0, glow="#7ff5e6", stem_col=(0.9, 0.86, 0.78)):
    m = MeshBuilder()
    h = 1.0 * size
    m.lathe([(0.16 * size, 0), (0.12 * size, h * 0.7), (0.15 * size, h)], 7, "flat", stem_col, smooth=True, cap_bottom=False)
    # cap: dome
    prof = [(0.0, h * 0.95), (0.55 * size, h * 0.95), (0.6 * size, h * 1.05), (0.45 * size, h * 1.35), (0.0, h * 1.5)]
    m.lathe(prof, 9, "tex:" + cap_tex, (1, 1, 1), smooth=True, cap_bottom=False, cap_top=False, uv_scale=(1.0, 1.0))
    # glowing gills underneath
    m.lathe([(0.15 * size, h * 0.93), (0.52 * size, h * 0.93)], 9, "glow:" + glow, (1, 1, 1), smooth=False, cap_bottom=False, cap_top=False)
    return single("mushroom", m, {"collision": "cylinder"})


reg("mushroom_glow_small", lambda r: mushroom(r, "nature/mushroom_glow", 0.5))
reg("mushroom_glow_big", lambda r: mushroom(r, "nature/mushroom_glow", 2.2))
reg("mushroom_red", lambda r: mushroom(r, "nature/mushroom_red", 0.8, glow="#ffd0b0"))
reg("mushroom_pale", lambda r: mushroom(r, "nature/mushroom_pale", 1.3, glow="#c9c2b0", stem_col=(0.7, 0.68, 0.62)))


def rock(rng, size=1.0, tex="stone/smooth_grey"):
    m = MeshBuilder()
    m.push(mat_scale(1.0, 0.6, 0.85))
    m.blob((0, size * 0.35, 0), size * 0.7, rng, rings=4, segments=7, mat="tex:" + tex, color=(0.9, 0.9, 0.9), jitter=0.5)
    m.pop()
    return single("rock", m, {"collision": "box"})


reg("rock_1", lambda r: rock(r, 1.0))
reg("rock_2", lambda r: rock(r, 1.8))
reg("rock_3", lambda r: rock(r, 0.6))
reg("rock_pale", lambda r: rock(r, 1.4, "stone/smooth_pale"))
reg("boulder", lambda r: rock(r, 3.5))


def standing_stone(rng, size=1.0):
    m = MeshBuilder()
    pts = [(-0.5, -0.35), (0.45, -0.4), (0.5, 0.3), (-0.4, 0.38)]
    pts = [(x * size, z * size) for x, z in pts]
    m.prism(pts, 0.0, 3.2 * size, "tex:nature/stone_rune", (1, 1, 1), uv_scale=0.5)
    return single("standing_stone", m, {"collision": "box"})


reg("standing_stone", lambda r: standing_stone(r))
reg("standing_stone_tall", lambda r: standing_stone(r, 1.6))


def bush(rng, size=1.0, leaf="nature/leaves_dark"):
    m = MeshBuilder()
    for i in range(3):
        c = (rng.random() - 0.5) * 0.6 * size, 0.45 * size, (rng.random() - 0.5) * 0.6 * size
        m.blob(c, 0.55 * size, rng, rings=3, segments=6, mat="tex:" + leaf, color=(0.75, 0.9, 0.75), jitter=0.4)
    return single("bush", m, {"collision": "none"})


reg("bush_1", lambda r: bush(r, 1.0))
reg("bush_2", lambda r: bush(r, 1.6, "nature/leaves_purple"))


def fern_cluster(rng):
    m = MeshBuilder()
    for i in range(3):
        m.cross_cards((0, 0.45, 0), (1.1, 0.9), "tex:nature/fern", (1, 1, 1), n=2)
        m.push(mat_rot_y(0.7))
    for i in range(3):
        m.pop()
    return single("fern", m, {"collision": "none"})


reg("fern_cluster", fern_cluster)


# --------------------------------------------------------------------------
# architecture
# --------------------------------------------------------------------------

def door_frame(rng, door_tex="wood/door", frame_tex="wood/planks_dark", w=1.0, h=2.2, frame_col=(1, 1, 1)):
    g = GLB("door")
    f = MeshBuilder()
    t = 0.12
    # deeper than any wall it is set in (0.2, 0.25, 0.3), so its faces never
    # share a plane with the wall's
    f.box((-(w / 2 + t / 2 - 0.015), h / 2, 0), (t, h, 0.36), "tex:" + frame_tex, frame_col, uv_scale=0.5)
    f.box(((w / 2 + t / 2 - 0.015), h / 2, 0), (t, h, 0.36), "tex:" + frame_tex, frame_col, uv_scale=0.5)
    f.box((0, h + t / 2, 0), (w + 2 * t, t, 0.36), "tex:" + frame_tex, frame_col, uv_scale=0.5)
    g.add("Frame", f, extras={"collision": "none"})
    leaf = MeshBuilder()
    # the leaf pivots at its hinge (x = -w/2); geometry offset so the node origin is the hinge
    leaf.box((w / 2, h / 2, 0), (w, h, 0.06), "tex:" + door_tex, (1, 1, 1), uv_scale=1.0)
    # handle
    leaf.box((w - 0.12, h * 0.48, 0.06), (0.05, 0.05, 0.08), "flat", (0.8, 0.65, 0.2))
    leaf.box((w - 0.12, h * 0.48, -0.06), (0.05, 0.05, 0.08), "flat", (0.8, 0.65, 0.2))
    g.add("Leaf", leaf, translation=(-w / 2, 0, 0), extras={"hinge": True})
    return g


reg("door_wood", lambda r: door_frame(r))
reg("door_white", lambda r: door_frame(r, "wood/door_white", "wood/planks_white"))
reg("door_dark", lambda r: door_frame(r, "wood/door_dark", "wood/planks_dark"))
reg("door_red", lambda r: door_frame(r, "wood/door_red", "wood/planks_dark"))
reg("door_iron", lambda r: door_frame(r, "wood/door_iron", "metal/iron", 1.2, 2.6))
reg("door_big", lambda r: door_frame(r, "wood/door_dark", "stone/blocks_castle", 1.6, 3.2))


def pillar(rng, tex="stone/blocks_castle", h=4.0, r=0.4):
    m = MeshBuilder()
    m.lathe([(r * 1.4, 0), (r * 1.4, 0.25), (r, 0.35), (r, h - 0.4), (r * 1.35, h - 0.25), (r * 1.4, h)], 8, "tex:" + tex, (1, 1, 1), smooth=True, uv_scale=(2.0, 0.5))
    return single("pillar", m, {"collision": "cylinder"})


reg("pillar_castle", lambda r: pillar(r))
reg("pillar_nexus", lambda r: pillar(r, "stone/blocks_nexus", 6.0, 0.5))
reg("pillar_city", lambda r: pillar(r, "stone/blocks_city", 5.0, 0.45))
reg("pillar_broken", lambda r: pillar(r, "stone/blocks_city", 1.8, 0.45))
reg("pillar_marble", lambda r: pillar(r, "stone/marble_white", 5.0, 0.4))
reg("pillar_tiled", lambda r: pillar(r, "wall/tile_white", 4.0, 0.5))
reg("pillar_flesh", lambda r: pillar(r, "organic/flesh", 5.0, 0.6))


def gravestone(rng, tex):
    m = MeshBuilder()
    w, h, d = 0.7, 0.95, 0.16
    m.box((0, h / 2, 0), (w, h, d), "tex:stone/smooth_grey", (0.8, 0.8, 0.8), uv_scale=1.0)
    m.push(compose(mat_translate(0, h, 0), mat_rot_x(math.pi / 2)))
    m.lathe([(w / 2, -d / 2), (w / 2, d / 2)], 8, "tex:stone/smooth_grey", (0.8, 0.8, 0.8), smooth=False)
    m.pop()
    # engraved face
    m.card((0, h * 0.55, -d / 2 - 0.005), (w * 0.9, h * 0.95), "tex:" + tex, (1, 1, 1), yaw=math.pi, double=False)
    m.box((0, 0.06, 0), (w * 1.3, 0.12, d * 3), "tex:stone/smooth_grey", (0.7, 0.7, 0.7))
    return single("gravestone", m, {"collision": "box"})


for _n in ("elspeth", "morrow", "halden", "annis", "blank", "you"):
    reg("gravestone_%s" % _n, (lambda t: (lambda r: gravestone(r, "props/grave_" + t)))(_n))


def well(rng, tex="stone/cobble_grey"):
    m = MeshBuilder()
    m.lathe([(1.1, 0), (1.1, 0.9), (0.85, 0.9), (0.85, 0.05)], 10, "tex:" + tex, (1, 1, 1), smooth=False, uv_scale=(3.0, 1.0), cap_top=False, cap_bottom=False)
    m.lathe([(0.84, 0.06), (0.0, 0.06)], 10, "glow:#050409", (1, 1, 1), smooth=False, cap_bottom=False, cap_top=False)
    for x in (-1.0, 1.0):
        m.box((x, 1.4, 0), (0.15, 2.8, 0.15), "tex:wood/planks_dark", (1, 1, 1))
    m.box((0, 2.75, 0), (2.6, 0.12, 0.12), "tex:wood/planks_dark", (1, 1, 1))
    m.push(mat_translate(0, 2.8, 0))
    m.push(mat_rot_x(0.0))
    m.lathe([(1.6, 0.0), (0.0, 0.9)], 4, "tex:wood/thatch", (1, 1, 1), smooth=False, cap_bottom=False, twist=0.0)
    m.pop()
    m.pop()
    m.box((0, 1.9, 0), (0.3, 0.35, 0.3), "tex:wood/planks_dark", (0.8, 0.8, 0.8))
    return single("well", m, {"collision": "cylinder"})


reg("well", well)
reg("well_bone", lambda r: well(r, "organic/bones"))


def fountain(rng):
    m = MeshBuilder()
    m.lathe([(2.4, 0), (2.4, 0.7), (2.1, 0.7), (2.1, 0.1)], 12, "tex:stone/blocks_city", (1, 1, 1), smooth=False, uv_scale=(4.0, 1.0), cap_top=False, cap_bottom=False)
    m.lathe([(2.09, 0.45), (0.0, 0.45)], 12, "tex:nature/water_dark", (1, 1, 1), smooth=False, cap_bottom=False, cap_top=False)
    m.lathe([(0.35, 0.1), (0.25, 2.2), (0.9, 2.3), (0.9, 2.45), (0.0, 2.5)], 8, "tex:stone/blocks_city", (0.9, 0.9, 0.9), smooth=True, uv_scale=(2.0, 0.5))
    # a figure on top, faceless
    m.box((0, 3.1, 0), (0.5, 1.2, 0.35), "tex:stone/statue", (1, 1, 1))
    m.sphere((0, 3.9, 0), 0.22, 4, 7, "tex:stone/statue", (1, 1, 1))
    return single("fountain", m, {"collision": "cylinder"})


reg("fountain", fountain)


def statue_knight(rng, tex="stone/statue", size=1.0, kneeling=False):
    m = MeshBuilder()
    c = (1, 1, 1)
    s = size
    m.box((0, 0.15 * s, 0), (1.2 * s, 0.3 * s, 1.2 * s), "tex:" + tex, c)
    ly = 0.3 * s
    if kneeling:
        m.box((-0.2 * s, ly + 0.25 * s, 0), (0.3 * s, 0.5 * s, 0.35 * s), "tex:" + tex, c)
        m.box((0.2 * s, ly + 0.2 * s, -0.25 * s), (0.3 * s, 0.4 * s, 0.7 * s), "tex:" + tex, c)
        ty = ly + 0.5 * s
    else:
        for x in (-0.18, 0.18):
            m.box((x * s, ly + 0.45 * s, 0), (0.28 * s, 0.9 * s, 0.32 * s), "tex:" + tex, c)
        ty = ly + 0.9 * s
    m.box((0, ty + 0.45 * s, 0), (0.7 * s, 0.9 * s, 0.4 * s), "tex:" + tex, c)
    m.box((-0.5 * s, ty + 0.45 * s, 0), (0.22 * s, 0.85 * s, 0.25 * s), "tex:" + tex, c)   # arm w/ shield
    m.box((-0.72 * s, ty + 0.4 * s, 0), (0.1 * s, 0.7 * s, 0.5 * s), "tex:" + tex, (0.85, 0.85, 0.9))
    m.box((0.5 * s, ty + 0.45 * s, 0), (0.22 * s, 0.85 * s, 0.25 * s), "tex:" + tex, c)    # arm w/ sword
    m.box((0.5 * s, ty + 0.9 * s, -0.1 * s), (0.08 * s, 1.5 * s, 0.05 * s), "tex:" + tex, (0.85, 0.85, 0.9))
    m.box((0, ty + 1.15 * s, 0), (0.42 * s, 0.5 * s, 0.42 * s), "tex:" + tex, c)   # helm
    m.box((0, ty + 1.12 * s, -0.22 * s), (0.3 * s, 0.06 * s, 0.05 * s), "glow:#101014", c)  # visor slit
    m.box((0, ty + 1.5 * s, 0), (0.08 * s, 0.25 * s, 0.35 * s), "tex:" + tex, (0.6, 0.55, 0.7))  # crest
    return single("statue", m, {"collision": "box"})


reg("statue_knight", lambda r: statue_knight(r))
reg("statue_knight_big", lambda r: statue_knight(r, size=1.8))
reg("statue_kneeling", lambda r: statue_knight(r, kneeling=True))
reg("statue_knight_bone", lambda r: statue_knight(r, "organic/bones"))


def throne(rng):
    m = MeshBuilder()
    wood = "tex:wood/planks_dark"
    m.box((0, 0.3, 0), (1.3, 0.6, 1.2), wood, (1, 1, 1))
    m.box((0, 0.66, 0.05), (1.1, 0.12, 0.95), "tex:fabric/velvet", (1, 1, 1))
    m.box((0, 1.5, 0.5), (1.3, 2.4, 0.2), wood, (1, 1, 1))
    m.box((0, 1.5, 0.38), (0.9, 1.6, 0.06), "tex:fabric/velvet", (1, 1, 1))
    for x in (-0.6, 0.6):
        m.box((x, 0.9, 0), (0.12, 0.6, 1.0), wood, (1, 1, 1))
        m.box((x, 3.05, 0.5), (0.25, 0.7, 0.25), "flat", hexc("#c9a227"))
    m.box((0, 3.05, 0.5), (0.5, 0.4, 0.22), "flat", hexc("#c9a227"))
    return single("throne", m, {"collision": "box"})


reg("throne", throne)


def bell_large(rng, size=1.0):
    m = MeshBuilder()
    s = size
    m.lathe([(0.55 * s, 0.0), (0.62 * s, 0.05 * s), (0.5 * s, 0.35 * s), (0.36 * s, 0.9 * s), (0.2 * s, 1.15 * s), (0.0, 1.3 * s)], 10, "tex:metal/brass", (1, 1, 1), smooth=True, cap_bottom=False, uv_scale=(2.0, 1.0))
    m.lathe([(0.0, 0.05 * s), (0.34 * s, 0.05 * s), (0.34 * s, 0.9 * s), (0.0, 0.9 * s)], 10, "flat", (0.3, 0.25, 0.15), smooth=False, cap_top=False, cap_bottom=False)
    m.box((0, 0.2 * s, 0), (0.12 * s, 0.4 * s, 0.12 * s), "flat", (0.25, 0.22, 0.2))
    m.sphere((0, 0.05 * s, 0), 0.1 * s, 3, 6, "flat", (0.25, 0.22, 0.2))
    m.box((0, 1.4 * s, 0), (0.15 * s, 0.25 * s, 0.15 * s), "flat", (0.35, 0.3, 0.2))
    return single("bell", m, {"collision": "none"})


reg("bell_large", lambda r: bell_large(r, 1.0))
reg("bell_huge", lambda r: bell_large(r, 2.6))


def brazier(rng):
    g = GLB("brazier")
    m = MeshBuilder()
    m.lathe([(0.45, 0.9), (0.55, 1.0), (0.5, 1.25), (0.2, 1.3), (0.0, 1.3)], 8, "tex:metal/iron", (1, 1, 1), smooth=False, cap_bottom=True, cap_top=False)
    m.lathe([(0.0, 0.85), (0.44, 0.9)], 8, "tex:metal/iron", (1, 1, 1), smooth=False, cap_bottom=False, cap_top=False)
    for i in range(3):
        a = i / 3 * math.tau
        m.push(compose(mat_rot_y(a), mat_translate(0.35, 0, 0), mat_rot_z(0.15)))
        m.box((0, 0.45, 0), (0.07, 0.9, 0.07), "tex:metal/iron", (1, 1, 1))
        m.pop()
    m.lathe([(0.0, 1.05), (0.4, 1.1)], 8, "flat", (0.15, 0.1, 0.08), smooth=False, cap_bottom=False, cap_top=False)
    g.add("Brazier", m, extras={"collision": "cylinder"})
    fire = MeshBuilder()
    fire.lathe([(0.35, 1.1), (0.22, 1.5), (0.08, 1.9), (0.0, 2.1)], 6, "glow:#ff8a2f", (1, 1, 1), smooth=False, cap_bottom=False, cap_top=False, twist=0.4)
    fire.lathe([(0.2, 1.12), (0.12, 1.4), (0.0, 1.6)], 5, "glow:#ffd27f", (1, 1, 1), smooth=False, cap_bottom=False, cap_top=False, twist=-0.5)
    g.add("Fire", fire)
    return g


reg("brazier", brazier)


def torch_wall(rng):
    g = GLB("torch")
    m = MeshBuilder()
    m.box((0, 0.0, 0.08), (0.12, 0.4, 0.16), "tex:metal/iron", (1, 1, 1))
    m.push(mat_rot_x(-0.35))
    m.box((0, 0.35, 0), (0.07, 0.7, 0.07), "tex:wood/planks_dark", (1, 1, 1))
    m.pop()
    g.add("Torch", m, extras={"collision": "none"})
    fire = MeshBuilder()
    fire.lathe([(0.12, 0.6), (0.07, 0.85), (0.0, 1.05)], 5, "glow:#ff8a2f", (1, 1, 1), smooth=False, cap_bottom=False, cap_top=False, twist=0.5)
    fire.lathe([(0.06, 0.62), (0.0, 0.8)], 4, "glow:#ffd27f", (1, 1, 1), smooth=False, cap_bottom=False, cap_top=False)
    g.add("Fire", fire, translation=(0, 0, -0.22))
    return g


reg("torch_wall", torch_wall)


def lantern_hanging(rng, glow="#ffd27f", chain=1.0):
    g = GLB("lantern")
    m = MeshBuilder()
    m.card((0, -chain / 2, 0), (0.12, chain), "tex:metal/chain", (1, 1, 1), double=True)
    m.box((0, -chain - 0.05, 0), (0.18, 0.06, 0.18), "tex:metal/iron", (1, 1, 1))
    m.box((0, -chain - 0.55, 0), (0.18, 0.06, 0.18), "tex:metal/iron", (1, 1, 1))
    for x in (-0.09, 0.09):
        for z in (-0.09, 0.09):
            m.box((x, -chain - 0.3, z), (0.02, 0.5, 0.02), "tex:metal/iron", (1, 1, 1))
    m.box((0, -chain - 0.3, 0), (0.15, 0.4, 0.15), "glow:" + glow, (1, 1, 1))
    g.add("Lantern", m, extras={"collision": "none"})
    return g


reg("lantern_hanging", lambda r: lantern_hanging(r))
reg("lantern_hanging_long", lambda r: lantern_hanging(r, chain=3.0))
reg("lantern_hanging_cold", lambda r: lantern_hanging(r, glow="#9fd3c7"))


def lantern_post(rng, h=3.2, glow="#ffd27f", tex="metal/iron"):
    m = MeshBuilder()
    m.lathe([(0.18, 0), (0.18, 0.15), (0.08, 0.2), (0.07, h)], 6, "tex:" + tex, (1, 1, 1), smooth=True, uv_scale=(1.0, 0.5))
    m.box((0.25, h, 0), (0.55, 0.05, 0.05), "tex:" + tex, (1, 1, 1))
    m.box((0.5, h - 0.3, 0), (0.24, 0.06, 0.24), "tex:" + tex, (1, 1, 1))
    m.box((0.5, h - 0.75, 0), (0.24, 0.06, 0.24), "tex:" + tex, (1, 1, 1))
    m.box((0.5, h - 0.52, 0), (0.18, 0.4, 0.18), "glow:" + glow, (1, 1, 1))
    return single("lantern_post", m, {"collision": "cylinder"})


reg("lantern_post", lambda r: lantern_post(r))
reg("lantern_post_city", lambda r: lantern_post(r, 4.0, "#c9d8ff", "metal/rust"))


def chandelier(rng):
    m = MeshBuilder()
    m.card((0, 1.2, 0), (0.12, 2.4), "tex:metal/chain", (1, 1, 1), double=True)
    m.lathe([(0.9, -0.05), (0.9, 0.05)], 10, "tex:metal/iron", (1, 1, 1), smooth=False)
    m.lathe([(0.75, -0.02), (0.75, 0.02)], 10, "tex:metal/iron", (1, 1, 1), smooth=False, cap_top=False, cap_bottom=False)
    for i in range(8):
        a = i / 8 * math.tau
        x, z = math.cos(a) * 0.85, math.sin(a) * 0.85
        m.cylinder((x, 0.15, z), 0.03, 0.2, 5, "flat", (0.95, 0.9, 0.8))
        m.box((x, 0.3, z), (0.05, 0.08, 0.05), "glow:#ffd27f", (1, 1, 1))
    return single("chandelier", m, {"collision": "none"})


reg("chandelier", chandelier)


def banner(rng, tex="fabric/banner_key", h=2.4):
    m = MeshBuilder()
    m.box((0, 0, 0), (1.1, 0.06, 0.06), "tex:wood/planks_dark", (1, 1, 1))
    m.card((0, -h / 2 - 0.03, 0), (1.0, h), "tex:" + tex + ":double", (1, 1, 1), double=True)
    return single("banner", m, {"collision": "none"})


reg("banner_key", lambda r: banner(r))
reg("banner_eye", lambda r: banner(r, "fabric/banner_eye"))
reg("tapestry", lambda r: banner(r, "fabric/tapestry", 3.2))


def chain_hanging(rng, length=6.0):
    m = MeshBuilder()
    m.cross_cards((0, -length / 2, 0), (0.2, length), "tex:metal/chain", (1, 1, 1), n=2)
    return single("chain", m, {"collision": "none"})


reg("chain_hanging", lambda r: chain_hanging(r))
reg("chain_hanging_long", lambda r: chain_hanging(r, 14.0))


def cage(rng, size=1.6):
    m = MeshBuilder()
    s = size
    for yaw in (0, math.pi / 2, math.pi, -math.pi / 2):
        m.push(mat_rot_y(yaw))
        m.card((0, s * 0.75, -s / 2), (s, s * 1.5), "tex:metal/bars", (1, 1, 1), double=True)
        m.pop()
    m.box((0, 0.03, 0), (s, 0.06, s), "tex:metal/iron", (1, 1, 1))
    m.box((0, s * 1.5, 0), (s, 0.06, s), "tex:metal/iron", (1, 1, 1))
    m.card((0, s * 1.5 + 1.0, 0), (0.12, 2.0), "tex:metal/chain", (1, 1, 1), double=True)
    return single("cage", m, {"collision": "none"})


reg("cage", cage)


# --------------------------------------------------------------------------
# furniture
# --------------------------------------------------------------------------

def bed(rng, w=1.6, sheet="fabric/sheet", frame="wood/planks_dark"):
    m = MeshBuilder()
    L = 2.1
    m.box((0, 0.25, 0), (w, 0.3, L), "tex:" + frame, (1, 1, 1))
    m.box((0, 0.5, 0), (w - 0.1, 0.25, L - 0.1), "tex:fabric/mattress", (1, 1, 1))
    m.box((0, 0.68, 0.25), (w - 0.14, 0.14, L * 0.7), "tex:" + sheet, (1, 1, 1))
    m.box((0, 0.7, -L / 2 + 0.35), (w * 0.5, 0.16, 0.45), "flat", (0.95, 0.93, 0.88))
    m.box((0, 0.7, -L / 2 - 0.05), (w, 1.4, 0.1), "tex:" + frame, (1, 1, 1))
    for x, z in ((-w / 2 + 0.06, L / 2 - 0.06), (w / 2 - 0.06, L / 2 - 0.06)):
        m.box((x, 0.1, z), (0.1, 0.2, 0.1), "tex:" + frame, (1, 1, 1))
    return single("bed", m, {"collision": "box"})


reg("bed_double", lambda r: bed(r))
reg("bed_single", lambda r: bed(r, 1.0))
reg("bed_inn", lambda r: bed(r, 1.2, "fabric/cloth_red", "wood/planks_warm"))
reg("bed_iron", lambda r: bed(r, 1.0, "fabric/sheet", "metal/iron"))


def desk(rng, tex="wood/table", w=1.4):
    m = MeshBuilder()
    m.box((0, 0.74, 0), (w, 0.06, 0.7), "tex:" + tex, (1, 1, 1))
    for x in (-w / 2 + 0.05, w / 2 - 0.05):
        for z in (-0.3, 0.3):
            m.box((x, 0.36, z), (0.06, 0.72, 0.06), "tex:" + tex, (0.9, 0.9, 0.9))
    m.box((w / 2 - 0.25, 0.45, 0), (0.45, 0.5, 0.6), "tex:" + tex, (0.85, 0.85, 0.85))
    for y in (0.3, 0.5):
        m.box((w / 2 - 0.25, y, -0.31), (0.3, 0.03, 0.02), "flat", (0.8, 0.65, 0.2))
    return single("desk", m, {"collision": "box"})


reg("desk", lambda r: desk(r))
reg("desk_white", lambda r: desk(r, "wood/planks_white"))


def chair(rng, tex="wood/table"):
    m = MeshBuilder()
    m.box((0, 0.45, 0), (0.45, 0.05, 0.45), "tex:" + tex, (1, 1, 1))
    for x in (-0.18, 0.18):
        for z in (-0.18, 0.18):
            m.box((x, 0.22, z), (0.05, 0.45, 0.05), "tex:" + tex, (0.9, 0.9, 0.9))
    for x in (-0.18, 0.18):
        m.box((x, 0.7, 0.2), (0.05, 0.55, 0.05), "tex:" + tex, (0.9, 0.9, 0.9))
    m.box((0, 0.85, 0.2), (0.4, 0.18, 0.04), "tex:" + tex, (1, 1, 1))
    return single("chair", m, {"collision": "box"})


reg("chair", lambda r: chair(r))
reg("chair_white", lambda r: chair(r, "wood/planks_white"))


def stool(rng):
    m = MeshBuilder()
    m.lathe([(0.2, 0.42), (0.2, 0.48)], 7, "tex:wood/table", (1, 1, 1), smooth=False)
    for i in range(3):
        a = i / 3 * math.tau
        m.push(compose(mat_rot_y(a), mat_translate(0.14, 0, 0), mat_rot_z(0.12)))
        m.box((0, 0.22, 0), (0.05, 0.44, 0.05), "tex:wood/table", (0.85, 0.85, 0.85))
        m.pop()
    return single("stool", m, {"collision": "box"})


reg("stool", stool)


def table_round(rng):
    m = MeshBuilder()
    m.lathe([(0.55, 0.72), (0.55, 0.78)], 9, "tex:wood/table", (1, 1, 1), smooth=False)
    m.lathe([(0.3, 0), (0.3, 0.05), (0.08, 0.1), (0.08, 0.72)], 7, "tex:wood/table", (0.85, 0.85, 0.85), smooth=True)
    return single("table_round", m, {"collision": "cylinder"})


reg("table_round", table_round)


def table_long(rng, tex="wood/table", L=3.0):
    m = MeshBuilder()
    m.box((0, 0.76, 0), (L, 0.08, 1.0), "tex:" + tex, (1, 1, 1))
    for x in (-L / 2 + 0.15, L / 2 - 0.15):
        m.box((x, 0.36, 0), (0.12, 0.72, 0.8), "tex:" + tex, (0.85, 0.85, 0.85))
    m.box((0, 0.2, 0), (L - 0.4, 0.06, 0.1), "tex:" + tex, (0.85, 0.85, 0.85))
    return single("table_long", m, {"collision": "box"})


reg("table_long", lambda r: table_long(r))
reg("table_feast", lambda r: table_long(r, "wood/planks_dark", 6.0))
reg("bench", lambda r: table_long(r, "wood/table", 2.0))


def bookshelf(rng, tex="wood/planks_dark", w=1.2, h=2.2):
    m = MeshBuilder()
    d = 0.35
    m.box((0, h / 2, 0), (w, h, d), "tex:" + tex, (1, 1, 1))
    for i in range(4):
        y = 0.15 + i * (h - 0.3) / 4
        m.box((0, y + (h - 0.3) / 8, 0.02), (w - 0.1, (h - 0.3) / 4 - 0.05, d - 0.08), "tex:wood/book_spines", (1, 1, 1))
    return single("bookshelf", m, {"collision": "box"})


reg("bookshelf", lambda r: bookshelf(r))
reg("bookshelf_tall", lambda r: bookshelf(r, "wood/planks_dark", 1.6, 4.0))
reg("bookshelf_white", lambda r: bookshelf(r, "wood/planks_white", 0.9, 1.8))


def barrel(rng, on_side=False):
    m = MeshBuilder()
    if on_side:
        m.push(compose(mat_translate(0, 0.45, 0), mat_rot_x(math.pi / 2)))
        m.lathe([(0.38, -0.5), (0.46, 0.0), (0.38, 0.5)], 9, "tex:wood/planks_dark", (1, 1, 1), smooth=True, uv_scale=(2.0, 1.0))
        for y in (-0.35, 0.35):
            m.lathe([(0.44, y - 0.03), (0.44, y + 0.03)], 9, "tex:metal/iron", (1, 1, 1), smooth=False, cap_top=False, cap_bottom=False)
        m.pop()
    else:
        m.lathe([(0.38, 0), (0.46, 0.5), (0.38, 1.0)], 9, "tex:wood/planks_dark", (1, 1, 1), smooth=True, uv_scale=(2.0, 1.0))
        for y in (0.15, 0.85):
            m.lathe([(0.45, y - 0.03), (0.45, y + 0.03)], 9, "tex:metal/iron", (1, 1, 1), smooth=False, cap_top=False, cap_bottom=False)
    return single("barrel", m, {"collision": "box"})


reg("barrel", lambda r: barrel(r))
reg("keg", lambda r: barrel(r, True))


def crate(rng, s=0.9):
    m = MeshBuilder()
    m.box((0, s / 2, 0), (s, s, s), "tex:wood/crate", (1, 1, 1), uv_scale=1.0 / s)
    return single("crate", m, {"collision": "box"})


reg("crate", lambda r: crate(r))
reg("crate_small", lambda r: crate(r, 0.5))


def bar_counter(rng, L=4.0):
    m = MeshBuilder()
    m.box((0, 0.55, 0), (L, 1.1, 0.7), "tex:wood/bar_counter", (1, 1, 1), uv_scale=0.5)
    m.box((0, 1.13, 0), (L + 0.1, 0.06, 0.85), "tex:wood/table", (1, 1, 1), uv_scale=0.5)
    m.box((0, 0.9, -0.42), (L, 0.04, 0.04), "flat", hexc("#c9a227"))
    cols = [(0.3, 0.6, 0.3), (0.5, 0.3, 0.2), (0.3, 0.3, 0.6), (0.7, 0.6, 0.3)]
    for i in range(6):
        x = -L / 2 + 0.4 + i * (L - 0.8) / 5
        m.lathe([(0.06, 1.16), (0.06, 1.35), (0.025, 1.4), (0.025, 1.52)], 6, "flat", cols[i % 4], smooth=True)
    return single("bar", m, {"collision": "box"})


reg("bar_counter", bar_counter)


def bottle(rng, col=(0.3, 0.6, 0.3), glow=None):
    m = MeshBuilder()
    mat = "flat" if glow is None else "glow:" + glow
    m.lathe([(0.06, 0), (0.06, 0.2), (0.025, 0.25), (0.025, 0.36), (0.0, 0.36)], 6, mat, col, smooth=True)
    return single("bottle", m, {"collision": "none"})


reg("bottle", lambda r: bottle(r))
reg("bottle_moonlight", lambda r: bottle(r, (1, 1, 1), "#c9d8ff"))


def mug(rng):
    m = MeshBuilder()
    m.lathe([(0.06, 0), (0.06, 0.14), (0.05, 0.14), (0.05, 0.02)], 6, "flat", (0.55, 0.4, 0.25), smooth=False, cap_top=False)
    m.box((0.08, 0.07, 0), (0.03, 0.08, 0.02), "flat", (0.55, 0.4, 0.25))
    return single("mug", m, {"collision": "none"})


reg("mug", mug)


def tv_crt(rng):
    g = GLB("tv")
    m = MeshBuilder()
    m.box((0, 0.3, 0), (0.7, 0.6, 0.6), "flat", (0.25, 0.24, 0.22))
    m.box((0, 0.3, -0.3), (0.62, 0.52, 0.02), "flat", (0.12, 0.12, 0.12))
    m.box((0.26, 0.2, -0.31), (0.06, 0.06, 0.02), "flat", (0.6, 0.6, 0.6))
    m.box((0.26, 0.32, -0.31), (0.06, 0.06, 0.02), "flat", (0.6, 0.6, 0.6))
    m.box((0.15, 0.68, 0.1), (0.02, 0.35, 0.02), "flat", (0.6, 0.6, 0.6))
    m.box((-0.15, 0.68, 0.1), (0.02, 0.35, 0.02), "flat", (0.6, 0.6, 0.6))
    g.add("Body", m, extras={"collision": "box"})
    s = MeshBuilder()
    s.card((0, 0.31, -0.33), (0.5, 0.42), "tex:props/tv_static", (1, 1, 1), yaw=math.pi, double=False)
    g.add("Screen", s)
    return g


reg("tv_crt", tv_crt)


def sofa(rng):
    m = MeshBuilder()
    t = "tex:fabric/sofa"
    m.box((0, 0.25, 0), (2.0, 0.5, 0.9), t, (1, 1, 1))
    m.box((0, 0.7, 0.35), (2.0, 0.5, 0.25), t, (0.9, 0.9, 0.9))
    for x in (-0.9, 0.9):
        m.box((x, 0.6, 0), (0.2, 0.3, 0.9), t, (0.9, 0.9, 0.9))
    m.box((-0.45, 0.55, 0.05), (0.85, 0.12, 0.7), t, (1.05, 1.0, 0.95))
    m.box((0.45, 0.55, 0.05), (0.85, 0.12, 0.7), t, (1.05, 1.0, 0.95))
    return single("sofa", m, {"collision": "box"})


reg("sofa", sofa)


def fridge(rng):
    m = MeshBuilder()
    m.box((0, 0.9, 0), (0.75, 1.8, 0.7), "flat", (0.9, 0.9, 0.86))
    m.box((0, 1.25, -0.36), (0.7, 0.01, 0.02), "flat", (0.5, 0.5, 0.5))
    m.box((0.3, 1.5, -0.37), (0.04, 0.4, 0.03), "flat", (0.5, 0.5, 0.5))
    m.box((0.3, 0.8, -0.37), (0.04, 0.6, 0.03), "flat", (0.5, 0.5, 0.5))
    return single("fridge", m, {"collision": "box"})


reg("fridge", fridge)


def kitchen_counter(rng, L=2.0, top="wall/tile_white"):
    m = MeshBuilder()
    m.box((0, 0.42, 0), (L, 0.84, 0.6), "tex:wood/planks_white", (1, 1, 1), uv_scale=0.5)
    m.box((0, 0.87, 0), (L + 0.04, 0.06, 0.64), "tex:" + top, (1, 1, 1), uv_scale=1.0)
    for i in range(int(L)):
        x = -L / 2 + 0.5 + i
        m.box((x, 0.7, -0.31), (0.3, 0.02, 0.02), "flat", (0.5, 0.5, 0.5))
    return single("counter", m, {"collision": "box"})


reg("kitchen_counter", lambda r: kitchen_counter(r))
reg("kitchen_sink", lambda r: kitchen_counter(r, 1.2))


def stove(rng):
    m = MeshBuilder()
    m.box((0, 0.42, 0), (0.7, 0.84, 0.6), "flat", (0.85, 0.85, 0.82))
    m.box((0, 0.87, 0), (0.7, 0.05, 0.6), "flat", (0.25, 0.25, 0.25))
    for x in (-0.18, 0.18):
        for z in (-0.15, 0.15):
            m.lathe([(0.1, 0.9), (0.1, 0.92)], 8, "flat", (0.12, 0.12, 0.12), smooth=False)
    m.box((0, 0.4, -0.31), (0.5, 0.3, 0.02), "flat", (0.15, 0.15, 0.15))
    return single("stove", m, {"collision": "box"})


reg("stove", stove)


def toilet(rng):
    m = MeshBuilder()
    m.lathe([(0.2, 0), (0.22, 0.35), (0.28, 0.4), (0.28, 0.45), (0.0, 0.45)], 8, "flat", (0.92, 0.92, 0.9), smooth=True, cap_bottom=False)
    m.box((0, 0.65, 0.28), (0.45, 0.5, 0.2), "flat", (0.92, 0.92, 0.9))
    m.lathe([(0.0, 0.46), (0.2, 0.46)], 8, "flat", (0.2, 0.25, 0.3), smooth=False, cap_top=False, cap_bottom=False)
    return single("toilet", m, {"collision": "box"})


reg("toilet", toilet)


def bathtub(rng):
    m = MeshBuilder()
    m.box((0, 0.3, 0), (1.7, 0.6, 0.75), "flat", (0.92, 0.92, 0.9))
    m.box((0, 0.5, 0), (1.5, 0.25, 0.55), "flat", (0.15, 0.2, 0.22))
    m.box((0, 0.33, 0), (1.5, 0.02, 0.55), "tex:nature/water_dark", (1, 1, 1))
    m.box((0.7, 0.75, 0), (0.05, 0.3, 0.05), "flat", (0.6, 0.6, 0.65))
    return single("bathtub", m, {"collision": "box"})


reg("bathtub", bathtub)


def sink(rng):
    m = MeshBuilder()
    m.box((0, 0.7, 0), (0.55, 0.15, 0.45), "flat", (0.92, 0.92, 0.9))
    m.box((0, 0.35, 0), (0.12, 0.7, 0.12), "flat", (0.85, 0.85, 0.85))
    m.box((0, 0.78, 0), (0.4, 0.02, 0.3), "flat", (0.2, 0.25, 0.3))
    m.box((0, 0.9, 0.15), (0.04, 0.25, 0.04), "flat", (0.6, 0.6, 0.65))
    return single("sink", m, {"collision": "box"})


reg("sink", sink)


def mirror_wall(rng, w=0.8, h=1.0, frame="wood/planks_dark"):
    g = GLB("mirror")
    f = MeshBuilder()
    t = 0.06
    f.box((0, 0, 0), (w + 2 * t, h + 2 * t, 0.05), "tex:" + frame, (1, 1, 1))
    g.add("Frame", f, extras={"collision": "none"})
    s = MeshBuilder()
    s.card((0, 0, -0.04), (w, h), "tex:props/mirror", (1, 1, 1), yaw=math.pi, double=False)
    g.add("Surface", s)
    return g


reg("mirror_wall", lambda r: mirror_wall(r))
reg("mirror_tall", lambda r: mirror_wall(r, 0.9, 2.0, "metal/brass"))


def dresser(rng, tex="wood/planks_dark"):
    m = MeshBuilder()
    m.box((0, 0.5, 0), (1.2, 1.0, 0.5), "tex:" + tex, (1, 1, 1))
    for y in (0.25, 0.55, 0.85):
        m.box((0, y, -0.26), (0.9, 0.02, 0.02), "flat", (0.8, 0.65, 0.2))
    return single("dresser", m, {"collision": "box"})


reg("dresser", lambda r: dresser(r))
reg("wardrobe", lambda r: (lambda m: single("wardrobe", m, {"collision": "box"}))(_wardrobe(r)))


def _wardrobe(rng):
    m = MeshBuilder()
    m.box((0, 1.1, 0), (1.2, 2.2, 0.6), "tex:wood/planks_dark", (1, 1, 1))
    m.box((0, 1.1, -0.31), (0.02, 2.0, 0.02), "flat", (0.1, 0.08, 0.06))
    m.box((-0.1, 1.1, -0.32), (0.04, 0.12, 0.03), "flat", (0.8, 0.65, 0.2))
    m.box((0.1, 1.1, -0.32), (0.04, 0.12, 0.03), "flat", (0.8, 0.65, 0.2))
    return m


def lamp_floor(rng):
    m = MeshBuilder()
    m.lathe([(0.2, 0), (0.2, 0.04), (0.02, 0.05), (0.02, 1.5)], 6, "flat", (0.35, 0.3, 0.25), smooth=True)
    m.lathe([(0.15, 1.45), (0.3, 1.85)], 8, "glow:#ffd8a0", (1, 1, 1), smooth=False, cap_top=False, cap_bottom=False)
    return single("lamp", m, {"collision": "none"})


reg("lamp_floor", lamp_floor)


def lamp_desk(rng):
    m = MeshBuilder()
    m.lathe([(0.1, 0), (0.1, 0.02), (0.015, 0.03), (0.015, 0.35)], 6, "flat", (0.3, 0.3, 0.3), smooth=True)
    m.push(compose(mat_translate(0, 0.35, 0), mat_rot_x(0.6)))
    m.lathe([(0.03, 0), (0.1, 0.16)], 7, "glow:#ffd8a0", (1, 1, 1), smooth=False, cap_top=False, cap_bottom=True)
    m.pop()
    return single("lamp_desk", m, {"collision": "none"})


reg("lamp_desk", lamp_desk)


def picture(rng, tex, w=0.9, h=0.9, frame_col=(0.65, 0.5, 0.2)):
    g = GLB("picture")
    f = MeshBuilder()
    t = 0.05
    f.box((0, 0, 0.0), (w + 2 * t, h + 2 * t, 0.04), "flat", frame_col)
    g.add("Frame", f, extras={"collision": "none"})
    p = MeshBuilder()
    p.card((0, 0, -0.035), (w, h), "tex:" + tex, (1, 1, 1), yaw=math.pi, double=False)
    g.add("Picture", p)
    return g


for _k in ("landscape", "portrait", "door", "house"):
    reg("painting_%s" % _k, (lambda t: (lambda r: picture(r, "props/painting_" + t, 1.0, 1.0)))(_k))
for _i in range(5):
    reg("photo_%d" % _i, (lambda t: (lambda r: picture(r, "props/photo_%d" % t, 0.45, 0.45, (0.9, 0.88, 0.8))))(_i))
reg("frame_calendar", lambda r: picture(r, "props/calendar", 0.4, 0.4, (0.3, 0.25, 0.2)))
reg("frame_map", lambda r: picture(r, "props/map_scrap", 0.6, 0.6, (0.3, 0.25, 0.2)))


def coat_rack(rng):
    m = MeshBuilder()
    m.lathe([(0.25, 0), (0.25, 0.03), (0.03, 0.04), (0.03, 1.8)], 6, "flat", (0.3, 0.2, 0.12), smooth=True)
    for i in range(4):
        a = i / 4 * math.tau
        m.push(compose(mat_translate(0, 1.7, 0), mat_rot_y(a), mat_rot_z(-1.1)))
        m.box((0, 0.1, 0), (0.03, 0.2, 0.03), "flat", (0.3, 0.2, 0.12))
        m.pop()
    m.push(mat_translate(0.12, 1.55, 0))
    m.lathe([(0.02, 0), (0.22, -0.3), (0.2, -1.0)], 6, "tex:fabric/coat", (1, 1, 1), smooth=False, cap_bottom=False)
    m.pop()
    return single("coat_rack", m, {"collision": "cylinder"})


reg("coat_rack", coat_rack)


def telephone(rng):
    m = MeshBuilder()
    m.box((0, 0.05, 0), (0.22, 0.1, 0.18), "flat", (0.12, 0.12, 0.14))
    m.box((0, 0.14, 0), (0.24, 0.05, 0.06), "flat", (0.12, 0.12, 0.14))
    m.lathe([(0.05, 0.1), (0.05, 0.115)], 8, "flat", (0.9, 0.9, 0.9), smooth=False)
    return single("telephone", m, {"collision": "none"})


reg("telephone", telephone)


def clock_grandfather(rng):
    g = GLB("clock")
    m = MeshBuilder()
    m.box((0, 1.1, 0), (0.6, 2.2, 0.35), "tex:wood/planks_dark", (1, 1, 1))
    m.box((0, 0.8, -0.16), (0.4, 1.2, 0.02), "flat", (0.08, 0.06, 0.05))
    m.box((0, 2.3, 0), (0.7, 0.2, 0.4), "tex:wood/planks_dark", (0.9, 0.9, 0.9))
    g.add("Body", m, extras={"collision": "box"})
    f = MeshBuilder()
    f.card((0, 1.75, -0.19), (0.45, 0.45), "tex:metal/clock_face", (1, 1, 1), yaw=math.pi, double=False)
    g.add("Face", f)
    p = MeshBuilder()
    p.box((0, -0.45, 0), (0.02, 0.9, 0.02), "flat", hexc("#b58a3c"))
    p.lathe([(0.1, -0.98), (0.1, -0.92)], 8, "flat", hexc("#b58a3c"), smooth=False)
    g.add("Pendulum", p, translation=(0, 1.4, -0.12))
    return g


reg("clock_grandfather", clock_grandfather)


def plant_pot(rng):
    m = MeshBuilder()
    m.lathe([(0.18, 0), (0.22, 0.3), (0.2, 0.32), (0.15, 0.32)], 7, "flat", (0.6, 0.35, 0.25), smooth=True, cap_top=False)
    m.cross_cards((0, 0.65, 0), (0.8, 0.7), "tex:nature/fern", (1, 1, 1), n=2)
    return single("plant", m, {"collision": "none"})


reg("plant_pot", plant_pot)


def candle(rng, h=0.25):
    m = MeshBuilder()
    m.lathe([(0.035, 0), (0.035, h)], 6, "flat", (0.95, 0.9, 0.8), smooth=False)
    m.lathe([(0.02, h), (0.0, h + 0.08)], 4, "glow:#ffd27f", (1, 1, 1), smooth=False, cap_bottom=False, cap_top=False)
    return single("candle", m, {"collision": "none"})


reg("candle", lambda r: candle(r))
reg("candle_tall", lambda r: candle(r, 0.6))


def candle_cluster(rng):
    m = MeshBuilder()
    for i in range(7):
        a = rng.random() * math.tau
        d = rng.random() * 0.25
        h = 0.08 + rng.random() * 0.22
        x, z = math.cos(a) * d, math.sin(a) * d
        m.lathe([(0.03, 0), (0.03, h)], 5, "flat", (0.95, 0.9, 0.8), smooth=False)
        m.push(mat_translate(x, 0, z))
        m.lathe([(0.03, 0), (0.03, h)], 5, "flat", (0.95, 0.9, 0.8), smooth=False)
        m.lathe([(0.018, h), (0.0, h + 0.07)], 4, "glow:#ffd27f", (1, 1, 1), smooth=False, cap_bottom=False, cap_top=False)
        m.pop()
    return single("candles", m, {"collision": "none"})


reg("candle_cluster", candle_cluster)


def window_frame(rng, tex="props/window_night", w=1.2, h=1.4):
    g = GLB("window")
    f = MeshBuilder()
    t = 0.08
    f.box((-(w / 2 + t / 2), 0, 0), (t, h + 2 * t, 0.12), "tex:wood/planks_white", (1, 1, 1))
    f.box(((w / 2 + t / 2), 0, 0), (t, h + 2 * t, 0.12), "tex:wood/planks_white", (1, 1, 1))
    f.box((0, (h / 2 + t / 2), 0), (w, t, 0.12), "tex:wood/planks_white", (1, 1, 1))
    f.box((0, -(h / 2 + t / 2), 0), (w + 0.2, t, 0.2), "tex:wood/planks_white", (1, 1, 1))
    g.add("Frame", f, extras={"collision": "none"})
    p = MeshBuilder()
    p.card((0, 0, 0), (w, h), "tex:" + tex, (1, 1, 1), yaw=0.0, double=True)
    g.add("Pane", p)
    return g


reg("window_night", lambda r: window_frame(r))
reg("window_lit", lambda r: window_frame(r, "props/window_lit"))


def radiator(rng):
    m = MeshBuilder()
    for i in range(8):
        m.box((-0.42 + i * 0.12, 0.35, 0), (0.08, 0.6, 0.12), "flat", (0.8, 0.78, 0.72))
    m.box((0, 0.62, 0), (1.0, 0.04, 0.14), "flat", (0.8, 0.78, 0.72))
    m.box((0, 0.08, 0), (1.0, 0.04, 0.14), "flat", (0.8, 0.78, 0.72))
    return single("radiator", m, {"collision": "box"})


reg("radiator", radiator)


def rug(rng, tex="wall/carpet_red", w=2.0, L=3.0):
    m = MeshBuilder()
    m.box((0, 0.01, 0), (w, 0.02, L), "tex:" + tex, (1, 1, 1), uv_scale=0.5, faces=("py", "px", "nx", "pz", "nz"))
    return single("rug", m, {"collision": "none"})


reg("rug_red", lambda r: rug(r))
reg("rug_tavern", lambda r: rug(r, "wall/carpet_tavern", 2.5, 2.5))
reg("rug_house", lambda r: rug(r, "wall/carpet_house", 2.0, 3.0))


def signboard(rng, tex="signs/last_lamp", w=2.0, h=0.6, post=True):
    m = MeshBuilder()
    if post:
        m.box((0, 1.6, 0), (0.1, 3.2, 0.1), "tex:wood/planks_dark", (1, 1, 1))
        m.box((0.6, 3.2, 0), (1.3, 0.08, 0.08), "tex:wood/planks_dark", (1, 1, 1))
        m.card((0.85, 2.75, 0), (w * 0.7, h * 0.7), "tex:" + tex + ":double", (1, 1, 1), double=True)
        m.card((0.85, 3.12, 0), (0.05, 0.3), "tex:metal/chain", (1, 1, 1), double=True)
    else:
        m.card((0, h / 2, 0), (w, h), "tex:" + tex + ":double", (1, 1, 1), double=True)
    return single("sign", m, {"collision": "none"})


reg("sign_last_lamp", lambda r: signboard(r))
reg("sign_no_vacancy", lambda r: signboard(r, "signs/no_vacancy", 1.2, 0.6))
reg("sign_menu", lambda r: signboard(r, "signs/menu", 1.0, 0.75, False))


def _load_extra():
    """Extra prop batches live in models_extra*.py and register into CATALOG."""
    import importlib
    for mod in ("models_extra", "models_extra2"):
        try:
            importlib.import_module(mod)
        except ImportError:
            pass


def generate(only=None):
    _load_extra()
    written = []
    for name, fn in CATALOG.items():
        if only and only not in name:
            continue
        rng = rng_for(name)
        g = fn(rng)
        path = OUT / (name + ".glb")
        g.write(path)
        js = read_check(path)
        tris = sum(len(n["mesh"].prims and [1]) for n in g.nodes)
        written.append(path)
    return written


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default=None)
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args()
    if a.list:
        _load_extra()
        for n in CATALOG:
            print(n)
        return
    w = generate(a.only)
    total = sum(p.stat().st_size for p in w)
    print("wrote %d models (%.1f KB) to %s" % (len(w), total / 1024, OUT))


if __name__ == "__main__":
    main()
